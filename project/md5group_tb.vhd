library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

--declare a testbench
ENTITY md5group_tb IS
END md5group_tb;

ARCHITECTURE Behaviour of md5group_tb IS
	COMPONENT md5_group
	PORT( clk, wr							: IN STD_LOGIC;
			reset, start					: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writedata						: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writeaddr						: IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			readaddr							: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			done								: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			readdata							: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
	END COMPONENT;
	
	TYPE ts IS array (0 to 15) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL testsequence : ts;
	SIGNAL  writedata, reset, start, done, readdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL writeaddr	: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL i : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0');
	SIGNAL k : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
	SIGNAL readaddr : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL clk, wr : STD_LOGIC;
	SIGNAL digest : STD_LOGIC_VECTOR(127 DOWNTO 0);
	
	constant clk_period : time := 40 ns;
	constant expected : STD_LOGIC_VECTOR(127 DOWNTO 0) := x"baebddf861d3eb2714ba892c2ad26682";

	BEGIN
	UUT: md5_group
	PORT MAP(clk => clk, wr => wr, reset => reset, start => start, writedata => writedata,
				writeaddr => writeaddr, readaddr	=> readaddr, done => done, readdata => readdata);

	clk_process : process
	begin
		clk <= '0';
		wait for 20 ns;--clk_period/2;
		clk <= '1';
		wait for 20 ns;--clk_period/2;
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
	
		reset <= "00000000000000000000000000000001";
		wr <= '0'; i <= (OTHERS => '0');
		start <= (OTHERS => '0');
		writeaddr <= (OTHERS => '0');
		readaddr  <= (OTHERS => '0');
		wait for 60 ns;
		reset <= (OTHERS => '0');
		wr <= '1';
		
		gen1 : for j in 0 to 16 loop
			writeaddr <= i;
			writedata <= testsequence(to_integer(unsigned(i)));
			wait for 40 ns;
			i <= i + '1';
		end loop;
	
		
		wr <= '0';
		wait for 40 ns;
		start <= "00000000000000000000000000000001";
		wait for 40 ns;
		start <= (OTHERS => '0');
		
		
		wait until done = "11111111111111111111111111111111";
		--read digest
		--1
			wait for 30 ns; --setup time 10 ns
			readaddr <= k;		
			k <= k + "0000001";
			wait for 40 ns;
			digest(31 DOWNTO 0) <= readdata;
		--2
			readaddr <= k;		
			k <= k + "0000001";
			wait for 40 ns;
			digest(63 DOWNTO 32) <= readdata;

		--3
			readaddr <= k;		
			k <= k + "0000001";
			wait for 40 ns;
			digest(95 DOWNTO 64) <= readdata;
		--2
			readaddr <= k;	
			k <= k + "0000001";	
			wait for 30 ns;
			digest(127 DOWNTO 96) <= readdata;
			
			wait for 40 ns;
		
		
		
		--assert (digest0 = expected) report "With success" severity note;
	   assert false report "Exiting" severity error;
	end process;
	
END Behaviour;
