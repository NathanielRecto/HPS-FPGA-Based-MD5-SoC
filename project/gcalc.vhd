--------------------------
-- gcalc.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
USE IEEE.std_logic_unsigned.ALL;

ENTITY gcalc IS
	PORT( i				: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			g				: OUT STD_LOGIC_VECTOR(3 DOWNTO 0));
END ENTITY gcalc;

ARCHITECTURE Behaviour of gcalc IS

SIGNAL doshift, sub : STD_LOGIC;
SIGNAL shiftby : STD_LOGIC_VECTOR( 1 DOWNTO 0);
SIGNAL addon : STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL shift_res, mult_res : STD_LOGIC_VECTOR(3 DOWNTO 0);

BEGIN
PROCESS(doshift, i, shiftby)
BEGIN
	IF(doshift = '1')THEN --shift to avoid multiplication
		shift_res <= std_logic_vector(unsigned(i(3 DOWNTO 0)) sll to_integer(unsigned(shiftby)));
	ELSE
		shift_res <= (OTHERS => '0');
	END IF;
END PROCESS;

PROCESS(sub, shift_res, i)
BEGIN
	IF(sub = '1')THEN
		mult_res <= shift_res - i(3 DOWNTO 0);
	ELSE 
		mult_res <= shift_res + i(3 DOWNTO 0);
	END IF;
END PROCESS;

PROCESS(i)
BEGIN
	CASE i(5 DOWNTO 4) IS
		WHEN "00" =>
			doshift <= '0';
			sub <= '0';
			shiftby <= (OTHERS => '0');
			addon <= (OTHERS => '0');
		WHEN "01" =>
			doshift <= '1';
			sub <= '0';
			shiftby <= "10";
			addon <= "001";
		WHEN "10" =>
			doshift <= '1';
			sub <= '0';
			shiftby <= "01";
			addon <= "101";
		WHEN "11" =>
			doshift <= '1';
			sub <= '1';
			shiftby <= (OTHERS => '1');
			addon <= (OTHERS => '0');
		WHEN OTHERS =>
			doshift <= '0';
			sub <= '0';
			shiftby <= (OTHERS => '0');
			addon <= (OTHERS => '0');
	END CASE;
END PROCESS;

g <= mult_res + addon;

END Behaviour;
