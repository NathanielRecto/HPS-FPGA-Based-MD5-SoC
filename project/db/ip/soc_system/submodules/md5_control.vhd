-- md5_control.vhd
-- COE838: Systems-on-Chip Design
-- Avalon MM Control Slave for MD5 SoC
--
-- Register Map (avs_s0_address):
--   Write:
--     0x0 : start  - 32-bit, one bit per engine (write 1 to start engine N)
--     0x1 : reset  - 32-bit, one bit per engine (write 1 to reset engine N)
--   Read:
--     0x0 : start  - read back start register
--     0x1 : reset  - read back reset register
--     0x2 : done   - read done flags from md5_group (1 bit per engine)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity md5_control is
    port (
        -- Avalon MM Slave Interface
        avs_s0_address   : in  std_logic_vector(3 downto 0)  := (others => '0');
        avs_s0_write     : in  std_logic                     := '0';
        avs_s0_writedata : in  std_logic_vector(31 downto 0) := (others => '0');
        avs_s0_read      : in  std_logic                     := '0';
        avs_s0_readdata  : out std_logic_vector(31 downto 0);

        -- Clock and Reset
        clk              : in  std_logic := '0';
        reset            : in  std_logic := '0';

        -- MD5 Core Control Signals (connect to md5_group ports)
        md5_start        : out std_logic_vector(31 downto 0);  -- -> md5_group start
        md5_reset        : out std_logic_vector(31 downto 0);  -- -> md5_group reset
        md5_done         : in  std_logic_vector(31 downto 0) := (others => '0')  -- <- md5_group done
    );
end entity md5_control;

architecture rtl of md5_control is

    signal start_reg : std_logic_vector(31 downto 0);
    signal reset_reg : std_logic_vector(31 downto 0);

begin

    PROCESS(clk, reset)
    BEGIN
        IF (reset = '1') THEN
            start_reg        <= (others => '0');
            reset_reg        <= (others => '0');
            avs_s0_readdata  <= (others => '0');

        ELSIF (rising_edge(clk)) THEN

            -- Auto-clear start after one clock cycle (pulse behaviour)
            start_reg <= (others => '0');
            -- Auto-clear reset after one clock cycle
            reset_reg <= (others => '0');

            IF (avs_s0_write = '1') THEN
                CASE avs_s0_address IS
                    WHEN "0000" =>
                        start_reg <= avs_s0_writedata;  -- write start bits for engines
                    WHEN "0001" =>
                        reset_reg <= avs_s0_writedata;  -- write reset bits for engines
                    WHEN OTHERS =>
                        NULL;
                END CASE;

            ELSIF (avs_s0_read = '1') THEN
                CASE avs_s0_address IS
                    WHEN "0000" =>
                        avs_s0_readdata <= start_reg;   -- read back start register
                    WHEN "0001" =>
                        avs_s0_readdata <= reset_reg;   -- read back reset register
                    WHEN "0010" =>
                        avs_s0_readdata <= md5_done;    -- read done flags from all 32 engines
                    WHEN OTHERS =>
                        avs_s0_readdata <= (others => '0');
                END CASE;
            END IF;

        END IF;
    END PROCESS;

    -- Drive MD5 core control outputs
    md5_start <= start_reg;
    md5_reset <= reset_reg;

end architecture rtl;