--------------------------
-- left_rotate.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

ENTITY leftrotate IS
	PORT( rotin				: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			rotby				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			rotout			: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
END ENTITY leftrotate;

ARCHITECTURE Behaviour of leftrotate IS
SIGNAL rotmid : STD_LOGIC_VECTOR(63 DOWNTO 0);
BEGIN

PROCESS(rotin, rotby)
BEGIN

	rotmid <= std_logic_vector(unsigned(rotin & rotin) sll to_integer(unsigned(rotby)));

END PROCESS;

rotout <= rotmid(63 DOWNTO 32);

END Behaviour;
