library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

--declare a testbench
ENTITY md5unit_tb IS
END md5unit_tb;

ARCHITECTURE Behaviour of md5unit_tb IS
	COMPONENT md5_unit
	PORT( clk, wr							: IN STD_LOGIC;
			reset, start					: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			writedata						: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writeaddr						: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			done								: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			digest0, digest1				: OUT STD_LOGIC_VECTOR(127 DOWNTO 0));
	END COMPONENT;
	
	TYPE ts IS array (0 to 15) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL testsequence : ts;
	SIGNAL  writedata : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL writeaddr	: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL clk, reset, start, wr, done0, done1 : STD_LOGIC;
	SIGNAL digest0, digest1 : STD_LOGIC_VECTOR(127 DOWNTO 0);
	SIGNAL i : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
	constant clk_period : time := 20 ns;
	constant expected : STD_LOGIC_VECTOR(127 DOWNTO 0) := x"baebddf861d3eb2714ba892c2ad26682";

	BEGIN
	UUT: md5_unit
	PORT MAP(clk => clk, wr => wr, reset(0) => reset, reset(1) => reset, start(0) => start, start(1) => start, 
				writedata => writedata, writeaddr => writeaddr, done(0) => done0, done(1) => done1, 
				digest0 => digest0, digest1 => digest1);

	clk_process : process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	stimulus : process
	begin	
		 testsequence(0) <= x"01680208"; --x"8230bb08";--
		 testsequence(1) <= x"13ab80bb";--x"48c4be48";--
		 testsequence(2) <= x"cb8b2c30"; --x"82308230";--;
		 testsequence(3) <= x"b9657582"; --x"48c4be48"; --
		 testsequence(4) <= x"a3793c48";
		 testsequence(5) <= x"103f26be";
		 testsequence(6) <= x"0b78dac4";
		 testsequence(7) <= x"5c433348";
		 testsequence(8) <= x"4de99287";
		 testsequence(9) <= x"eff0be7c";
		 testsequence(10) <= x"00808533";
		 testsequence(11) <= x"00000000";
		 testsequence(12) <= x"00000000";
		 testsequence(13) <= x"00000000";
		 testsequence(14) <= x"00000150";
		 testsequence(15) <= x"00000000";
	
		reset <= '1';
		wr <= '0';
		start <= '0';
		writeaddr <= (OTHERS => '0');
		wait for 20 ns;
		reset <= '0';
		wr <= '1';
		
		gen1 : for j in 0 to 16 loop
			writeaddr <= i;
			writedata <= testsequence(to_integer(unsigned(i)));
			wait for 20 ns;
			i <= i + '1';
		end loop;
	
		wait for 20 ns;
		wr <= '0';
		start <= '1';
		wait for 20 ns;
		start <= '0';
		
		wait for 5200 ns;
		assert (done0 = '1') report "Done!" severity note;
		assert (digest0 = expected) report "With success" severity note;
	   assert false report "Exiting" severity error;
	end process;
	
END Behaviour;
