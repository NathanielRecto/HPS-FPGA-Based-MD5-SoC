--------------------------
-- md5_group.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

ENTITY md5_group IS
	PORT( clk, wr							: IN STD_LOGIC;
			reset, start					: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writedata						: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writeaddr						: IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			readaddr							: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			done								: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			readdata							: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
END ENTITY md5_group;

ARCHITECTURE Behaviour of md5_group IS
	COMPONENT md5_unit 
	PORT( clk, wr							: IN STD_LOGIC;
			reset, start					: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			writedata						: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writeaddr						: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			done								: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			digest0, digest1				: OUT STD_LOGIC_VECTOR(127 DOWNTO 0) := (OTHERS => '0'));
	END COMPONENT md5_unit;

	SIGNAL unit_write  : STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE da is array (0 to 31) of STD_LOGIC_VECTOR(127 DOWNTO 0);
	SIGNAL digest_arr : da;
	SIGNAL digest_sel: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL word_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL digest : STD_LOGIC_VECTOR(127 DOWNTO 0);
	
	BEGIN
	
	gen_Label: for i in 0 to 15 generate
		BEGIN
		md5_1 : md5_unit
		PORT MAP(clk => clk, wr => unit_write(i), 
			reset => reset(2*i + 1 DOWNTO 2*i), start => start(2*i + 1 DOWNTO 2*i),
			writedata => writedata, writeaddr => writeaddr(4 DOWNTO 0), 	
			done => done(2*i + 1 DOWNTO 2*i), digest0 => digest_arr(2*i), 
			digest1 => digest_arr(2*i + 1));
			
	END generate;
	
	PROCESS(digest, word_sel)
	BEGIN
		CASE word_sel IS
			WHEN "00" =>
				readdata <= digest(31 DOWNTO 0);
			WHEN "01" =>
				readdata <= digest(63 DOWNTO 32);
			WHEN "10" =>
				readdata <= digest(95 DOWNTO 64);
			WHEN "11" =>
				readdata <= digest(127 DOWNTO 96);
			WHEN OTHERS =>
				readdata <= (OTHERS => '0');
		END CASE;
	END PROCESS;

	PROCESS(writeaddr, wr) --write address 4 to 16 1 hot encoding
		VARIABLE write_decode  : STD_LOGIC_VECTOR(15 DOWNTO 0);
	BEGIN
		IF(wr = '1')THEN
		
				CASE writeaddr(8 DOWNTO 5) IS
					WHEN "0000" => 
						write_decode := "0000000000000001";
					WHEN "0001" => 
						write_decode := "0000000000000010";
					WHEN "0010" => 
						write_decode := "0000000000000100";
					WHEN "0011" => 
						write_decode := "0000000000001000";
					WHEN "0100" => 
						write_decode := "0000000000010000";
					WHEN "0101" => 
						write_decode := "0000000000100000";
					WHEN "0110" => 
						write_decode := "0000000001000000";
					WHEN "0111" => 
						write_decode := "0000000010000000";
					WHEN "1000" => 
						write_decode := "0000000100000000";
					WHEN "1001" => 
						write_decode := "0000001000000000";
					WHEN "1010" => 
						write_decode := "0000010000000000";
					WHEN "1011" => 
						write_decode := "0000100000000000";
					WHEN "1100" => 
						write_decode := "0001000000000000";
					WHEN "1101" => 
						write_decode := "0010000000000000";
					WHEN "1110" => 
						write_decode := "0100000000000000";
					WHEN "1111" =>
						write_decode := "1000000000000000";
					WHEN OTHERS =>
						write_decode := "0000000000000000";
				END CASE;
				
			   for i in 0 to 15 loop
					unit_write(i) <= wr AND write_decode(i);
				end loop;
				
			ELSE
				unit_write <= (OTHERS => '0');
			END IF;
		
	END PROCESS;
	
	digest_sel <= readaddr(6 DOWNTO 2);
	word_sel <= readaddr(1 DOWNTO 0);
	digest <= digest_arr(to_integer(unsigned(digest_sel)));
	
END Behaviour;
