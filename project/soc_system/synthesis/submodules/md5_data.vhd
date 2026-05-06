-- md5_data.vhd
-- COE838: Systems-on-Chip Design
-- Avalon MM Data Slave for MD5 SoC
--
-- Write Address Map (avs_s0_address = 9 bits):
--   bits [8:5] = engine pair select (0-15), maps to md5_group writeaddr[8:5]
--   bits [4:0] = word select in MRAM (0-15), maps to md5_group writeaddr[4:0]
--
--   To write word W to engine E's MRAM:
--     avs_s0_address = (E/2)[3:0] & W[4:0]  (E/2 because each md5_unit has 2 engines)
--
-- Read Address Map (avs_s0_address = 9 bits, only lower 7 bits used for reads):
--   bits [6:2] = engine select (0-31), maps to md5_group readaddr[6:2]
--   bits [1:0] = digest word select (0-3), maps to md5_group readaddr[1:0]
--
--   To read digest word W from engine E:
--     avs_s0_address = E[4:0] & W[1:0]
--     word 0 = digest bits [31:0]
--     word 1 = digest bits [63:32]
--     word 2 = digest bits [95:64]
--     word 3 = digest bits [127:96]

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity md5_data is
    port (
        -- Avalon MM Slave Interface (9-bit address for write/read)
        avs_s0_address   : in  std_logic_vector(8 downto 0)  := (others => '0');
        avs_s0_write     : in  std_logic                     := '0';
        avs_s0_writedata : in  std_logic_vector(31 downto 0) := (others => '0');
        avs_s0_read      : in  std_logic                     := '0';
        avs_s0_readdata  : out std_logic_vector(31 downto 0);

        -- Clock and Reset
        clk              : in  std_logic := '0';
        reset            : in  std_logic := '0';

        -- MD5 Core Data Signals (connect directly to md5_group ports)
        md5_wr           : out std_logic;                            -- -> md5_group wr
        md5_writedata    : out std_logic_vector(31 downto 0);        -- -> md5_group writedata
        md5_writeaddr    : out std_logic_vector(8 downto 0);         -- -> md5_group writeaddr
        md5_readaddr     : out std_logic_vector(6 downto 0);         -- -> md5_group readaddr
        md5_readdata     : in  std_logic_vector(31 downto 0) := (others => '0')  -- <- md5_group readdata
    );
end entity md5_data;

architecture rtl of md5_data is

    signal wr_reg        : std_logic;
    signal writedata_reg : std_logic_vector(31 downto 0);
    signal writeaddr_reg : std_logic_vector(8 downto 0);
    signal readaddr_reg  : std_logic_vector(6 downto 0);

begin

    PROCESS(clk, reset)
    BEGIN
        IF (reset = '1') THEN
            wr_reg           <= '0';
            writedata_reg    <= (others => '0');
            writeaddr_reg    <= (others => '0');
            readaddr_reg     <= (others => '0');
            avs_s0_readdata  <= (others => '0');

        ELSIF (rising_edge(clk)) THEN

            -- Default: deassert write enable each cycle
            wr_reg <= '0';

            IF (avs_s0_write = '1') THEN
                -- Write a 32-bit word to an engine's MRAM
                -- avs_s0_address[8:5] selects the engine pair
                -- avs_s0_address[4:0] selects the word (0-15) in MRAM
                wr_reg        <= '1';
                writedata_reg <= avs_s0_writedata;
                writeaddr_reg <= avs_s0_address;   -- full 9-bit address passed through

            ELSIF (avs_s0_read = '1') THEN
                -- Read a 32-bit segment of the 128-bit digest from one engine
                -- avs_s0_address[6:2] selects the engine (0-31)
                -- avs_s0_address[1:0] selects the digest word (0-3)
                readaddr_reg    <= avs_s0_address(6 downto 0);
                avs_s0_readdata <= md5_readdata;   -- data comes from md5_group readdata mux

            END IF;

        END IF;
    END PROCESS;

    -- Drive MD5 core data outputs
    md5_wr        <= wr_reg;
    md5_writedata <= writedata_reg;
    md5_writeaddr <= writeaddr_reg;
    md5_readaddr  <= readaddr_reg;

end architecture rtl;