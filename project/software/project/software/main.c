/*
 * COE838 - MD5 SoC Application
 * All 32 engines working with corrected write address encoding.
 *
 * Eclipse Defined Symbols:
 *   (none)          -> SERIAL mode
 *   PARALLEL        -> PARALLEL mode
 *   DEBUG_MULTI     -> test engines 0-7 individually (diagnostic)
 *   RUN_SECONDS=5   -> override duration (default 10s)
 *
 * Compile examples:
 *   arm-linux-gnueabihf-gcc -O2            -o md5_serial   main.c
 *   arm-linux-gnueabihf-gcc -O2 -DPARALLEL -o md5_parallel main.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#include "hps_0.h"

/* ── Benchmark duration ──────────────────────────────────────────── */
#ifndef RUN_SECONDS
#define RUN_SECONDS 10
#endif

/* ── Hardware constants ──────────────────────────────────────────── */
#define LW_BRIDGE_BASE  0xFF200000UL
#define LW_BRIDGE_SPAN  0x00200000UL

#define NUM_ENGINES     32
#define MSG_WORDS       16     /* 512-bit block  = 16 x 32-bit words */
#define DIGEST_WORDS    4      /* 128-bit digest =  4 x 32-bit words */

/* Control slave offsets */
#define CTRL_START  0
#define CTRL_RESET  1
#define CTRL_DONE   2

/* ── Pointer helpers ─────────────────────────────────────────────── */
#define DATA_PTR(lw)  ((volatile unsigned int *)((char *)(lw) + MD5_DATA_0_BASE))
#define CTRL_PTR(lw)  ((volatile unsigned int *)((char *)(lw) + MD5_CONTROL_0_BASE))

/* ── Expected digest for MD5("abc") ─────────────────────────────── */
/*
 * RFC 1321: 900150983cd24fb0d6963f7d28e17f72
 * Converted to Little-endian 32-bit words (confirmed by DEBUG run):
 */
static const unsigned int EXPECTED[DIGEST_WORDS] = {
    0x98500190, 0xb04fd23c, 0x7d3f96d6, 0x727fe128
};

/* ── MD5 message padding ─────────────────────────────────────────── */
static void build_md5_block(const unsigned char *msg, int len,
                              unsigned int block[MSG_WORDS])
{
    unsigned char buf[64];
    unsigned long long bit_len;
    int i;

    memset(buf, 0, sizeof(buf));
    memcpy(buf, msg, len);
    buf[len] = 0x80;
    bit_len  = (unsigned long long)len * 8;
    memcpy(buf + 56, &bit_len, 8);

    for (i = 0; i < 16; i++)
        block[i] = (unsigned int) buf[i*4]
                 | ((unsigned int)buf[i*4+1] <<  8)
                 | ((unsigned int)buf[i*4+2] << 16)
                 | ((unsigned int)buf[i*4+3] << 24);
}

/* ── Address encoding ────────────────────────────────────────────── */
/*
 * WRITE address (9-bit total, sent to md5_data slave):
 *   bits [8:5] = engine / 2        (pair index,        0-15)
 *   bit  [4]   = engine % 2        (within-pair select, 0 or 1)
 *   bits [3:0] = word              (message word,       0-15)
 *
 * This matches md5_unit.vhd:
 *   m_write(0) <= wr AND NOT writeaddr(4);  -- within_pair=0
 *   m_write(1) <= wr AND     writeaddr(4);  -- within_pair=1
 *   wraddress  <= writeaddr(3 downto 0);    -- word index into MRAM
 *
 * Previous bug: addr = (engine/2)<<5 | word
 *   -> bit[4] was always 0 (word 0-15 never sets bit 4)
 *   -> odd engines (within_pair=1) NEVER got message data written
 *
 * Fixed:        addr = (engine/2)<<5 | (engine%2)<<4 | word
 *   -> bit[4] = within_pair selector, bits[3:0] = word index
 */
static inline void write_msg_word(volatile unsigned int *data,
                                   int engine, int word, unsigned int val)
{
    unsigned int pair        = (unsigned int)(engine / 2);
    unsigned int within_pair = (unsigned int)(engine % 2);
    unsigned int addr        = (pair << 5) | (within_pair << 4)
                             | ((unsigned int)word & 0x0F);
    data[addr] = val;
}

/*
 * READ address (7-bit):
 *   bits [6:2] = engine (0-31)
 *   bits [1:0] = digest word (0-3)
 *
 * Double-read: first read presents readaddr to hardware and latches
 * readdata; second read returns the now-valid data.
 */
static inline unsigned int read_digest_word(volatile unsigned int *data,
                                              int engine, int word)
{
    unsigned int addr = ((unsigned int)(engine & 0x1F) << 2)
                      | ((unsigned int) word          &  0x3);
    (void)data[addr];   /* first:  set readaddr, latch readdata */
    return data[addr];  /* second: readdata now valid           */
}

/* ── Engine helpers ──────────────────────────────────────────────── */
static void reset_engines(volatile unsigned int *ctrl, unsigned int mask)
{
    volatile int i;
    ctrl[CTRL_RESET] = mask;
    for (i = 0; i < 16; i++);
    ctrl[CTRL_RESET] = 0;
}

static void load_message(volatile unsigned int *data, int engine,
                          const unsigned int msg[MSG_WORDS])
{
    int i;
    for (i = 0; i < MSG_WORDS; i++)
        write_msg_word(data, engine, i, msg[i]);
}

static inline void wait_done(volatile unsigned int *ctrl, unsigned int mask)
{
    while ((ctrl[CTRL_DONE] & mask) != mask);
}

static inline int digest_correct(const unsigned int d[DIGEST_WORDS])
{
    return d[0] == EXPECTED[0] && d[1] == EXPECTED[1]
        && d[2] == EXPECTED[2] && d[3] == EXPECTED[3];
}

static double elapsed_sec(const struct timespec *a, const struct timespec *b)
{
    return (b->tv_sec  - a->tv_sec)
         + (b->tv_nsec - a->tv_nsec) * 1e-9;
}

/* ═══════════════════════════════════════════════════════════════════ */
int main(void)
{
    int   fd;
    void *lw_base;
    volatile unsigned int *ctrl, *data;
    unsigned int msg[MSG_WORDS];
    struct timespec t0, tnow;
    long total_hashes   = 0;
    long correct_hashes = 0;
    double elapsed, hash_rate;
    int e, w;

    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    lw_base = mmap(NULL, LW_BRIDGE_SPAN,
                   PROT_READ | PROT_WRITE, MAP_SHARED,
                   fd, LW_BRIDGE_BASE);
    if (lw_base == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    ctrl = CTRL_PTR(lw_base);
    data = DATA_PTR(lw_base);

    build_md5_block((const unsigned char *)"abc", 3, msg);
    reset_engines(ctrl, 0xFFFFFFFF);

/* ════════════════════════════════════════════════════════════════════
 * DEBUG_MULTI — test engines 0-7 individually to verify all pass
 * ════════════════════════════════════════════════════════════════════ */
#ifdef DEBUG_MULTI

    printf("=== DEBUG_MULTI: engines 0-7 ===\n\n");
    printf("Expected: %08x%08x%08x%08x\n\n",
           EXPECTED[0], EXPECTED[1], EXPECTED[2], EXPECTED[3]);

    unsigned int d[DIGEST_WORDS];
    int pass_count = 0;

    for (e = 0; e < 8; e++) {
        unsigned int bit = 1u << e;
        reset_engines(ctrl, bit);
        load_message(data, e, msg);
        ctrl[CTRL_START] = bit;
        wait_done(ctrl, bit);
        ctrl[CTRL_START] = 0;
        for (w = 0; w < DIGEST_WORDS; w++)
            d[w] = read_digest_word(data, e, w);

        int ok = digest_correct(d);
        if (ok) pass_count++;
        printf("Engine %2d: %08x%08x%08x%08x  [%s]  pair=%d within_pair=%d\n",
               e, d[0], d[1], d[2], d[3],
               ok ? "PASS" : "FAIL", e/2, e%2);
    }
    printf("\n%d/8 engines passed.\n", pass_count);

#else

/* ════════════════════════════════════════════════════════════════════
 * BENCHMARK MODES (all 32 engines)
 * ════════════════════════════════════════════════════════════════════ */
    printf("Run duration   : %d second(s)\n", RUN_SECONDS);
    printf("Active engines : %d\n", NUM_ENGINES);

#ifndef PARALLEL
    /* ──────────────────────────────────────────────────────────────
     * SERIAL MODE — one engine at a time, cycle 0->31->0
     * ────────────────────────────────────────────────────────────── */
    printf("Mode           : SERIAL\n\n");

    unsigned int digest[DIGEST_WORDS];
    unsigned int bit;

    clock_gettime(CLOCK_MONOTONIC, &t0);
    e = 0;

    for (;;) {
        clock_gettime(CLOCK_MONOTONIC, &tnow);
        if (elapsed_sec(&t0, &tnow) >= RUN_SECONDS) break;

        bit = 1u << e;
        reset_engines(ctrl, bit);
        load_message(data, e, msg);
        ctrl[CTRL_START] = bit;
        wait_done(ctrl, bit);
        ctrl[CTRL_START] = 0;

        for (w = 0; w < DIGEST_WORDS; w++)
            digest[w] = read_digest_word(data, e, w);

        total_hashes++;
        if (digest_correct(digest))
            correct_hashes++;

        e = (e + 1) % NUM_ENGINES;
    }

    clock_gettime(CLOCK_MONOTONIC, &tnow);

#else
    /* ──────────────────────────────────────────────────────────────
     * PARALLEL MODE — all 32 engines simultaneously each round
     * ────────────────────────────────────────────────────────────── */
    printf("Mode           : PARALLEL\n\n");

    unsigned int digests[NUM_ENGINES][DIGEST_WORDS];
    int all_match = 1;

    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (;;) {
        clock_gettime(CLOCK_MONOTONIC, &tnow);
        if (elapsed_sec(&t0, &tnow) >= RUN_SECONDS) break;

        reset_engines(ctrl, 0xFFFFFFFF);

        for (e = 0; e < NUM_ENGINES; e++)
            load_message(data, e, msg);

        ctrl[CTRL_START] = 0xFFFFFFFF;
        wait_done(ctrl, 0xFFFFFFFF);
        ctrl[CTRL_START] = 0;

        for (e = 0; e < NUM_ENGINES; e++) {
            for (w = 0; w < DIGEST_WORDS; w++)
                digests[e][w] = read_digest_word(data, e, w);

            total_hashes++;
            if (digest_correct(digests[e]))
                correct_hashes++;
            else
                all_match = 0;
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &tnow);
#endif  /* PARALLEL */

    /* ── Final stats ───────────────────────────────────────────── */
    elapsed   = elapsed_sec(&t0, &tnow);
    hash_rate = (total_hashes > 0) ? (double)total_hashes / elapsed : 0.0;

    printf("Total hashes   : %ld\n",    total_hashes);
    printf("Correct hashes : %ld\n",    correct_hashes);
    printf("Elapsed time   : %.6f s\n", elapsed);
    printf("Hash rate      : %.2f hashes/s  (%.4f MH/s)\n",
           hash_rate, hash_rate / 1e6);
    if (total_hashes > 0)
        printf("Accuracy       : %.2f%%\n",
               100.0 * correct_hashes / total_hashes);
    printf("Result         : %s\n",
           (correct_hashes == total_hashes && total_hashes > 0)
           ? "PASS" : "FAIL");
#ifdef PARALLEL
    printf("Cross-engine   : %s\n",
           all_match ? "All engines agree (PASS)" : "Engine mismatch (FAIL)");
#endif

#endif  /* DEBUG_MULTI / benchmark */

    munmap(lw_base, LW_BRIDGE_SPAN);
    close(fd);
    return 0;
}
