--------------------------
-- fcalc.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

ENTITY fcalc IS
	PORT( sel			: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			b, c, d		: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			f				: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
END ENTITY fcalc;

ARCHITECTURE Behaviour of fcalc IS
BEGIN
	PROCESS(sel, b, c, d)
	BEGIN
		CASE sel IS
			WHEN "00" =>
				f <= (b AND c) OR (NOT b AND d);
			WHEN "01" =>
				f <= (d AND b) OR (NOT d AND c);
			WHEN "10" =>
				f <= b XOR c XOR d;
			WHEN "11" =>
				f <= c XOR (b OR NOT d);
			WHEN OTHERS =>
				f <= (OTHERS => '0');
		END CASE;
	END PROCESS;
END Behaviour;
