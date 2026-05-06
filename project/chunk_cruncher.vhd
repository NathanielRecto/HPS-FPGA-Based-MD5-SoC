--------------------------
-- chunk_cruncher.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
USE IEEE.std_logic_unsigned.all;

ENTITY chunk_cruncher IS
	PORT( clk, reset, start				: IN STD_LOGIC;
			kdata, mdata					: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			sdata								: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			done								: OUT STD_LOGIC;
			gaddr								: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			iaddr								: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
			digest							: OUT STD_LOGIC_VECTOR(127 DOWNTO 0));
END ENTITY chunk_cruncher;

ARCHITECTURE Behaviour of chunk_cruncher IS
	COMPONENT fcalc
	PORT( sel			: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			b, c, d		: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			f				: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
	END COMPONENT;
	
	COMPONENT gcalc
	PORT( i				: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			g				: OUT STD_LOGIC_VECTOR(3 DOWNTO 0));
	END COMPONENT;
	
	COMPONENT leftrotate
	PORT( rotin				: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			rotby				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			rotout			: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
	END COMPONENT;
	
	constant INITA : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"67452301";
	constant INITB : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"efcdab89";	
	constant INITC : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"98badcfe";	
	constant INITD : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"10325476";	
	constant CRUNCH : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
	constant FINALIZE : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
	constant FINISHED : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
	SIGNAL stage, step	: STD_LOGIC_VECTOR(1 DOWNTO 0) := FINISHED;
	SIGNAL a0, b0, c0, d0, areg, breg, creg, dreg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL ireg	: STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
	SIGNAL f, freg, adda, addb, adds, t0, t1, rotated : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL inext : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
	
	BEGIN
	
	fc : fcalc
	PORT MAP(sel => ireg(5 DOWNTO 4), b => breg, c => creg, d => dreg, f => f);
	
	gc : gcalc
	PORT MAP(i => ireg, g => gaddr);
	
	lr : leftrotate
	PORT MAP( rotin => t0, rotby	=> sdata, rotout => rotated);
	
	PROCESS(adda, addb)
	BEGIN
		adds <= adda + addb;
	END PROCESS;
	
	PROCESS(ireg)
	BEGIN
		inext <= ireg + '1';
	END PROCESS;
	
	PROCESS(stage)
	BEGIN
		IF(stage = FINISHED)THEN
			done <= '1';
		ELSIF(stage = "11")THEN
			done <= '1';
		ELSE
			done <= '0';
		END IF;	
	END PROCESS;
	
	PROCESS(stage, step, areg, kdata, freg, creg, mdata, t0, t1, breg, rotated, a0, b0, c0, d0, dreg)
	BEGIN
		IF(stage = CRUNCH)THEN
			CASE step IS
				WHEN "00" =>
					adda <= areg;
					addb <= kdata;
				WHEN "01" =>
					adda <= freg;
					addb <= mdata;
				WHEN "10" =>
					adda <= t0;
					addb <= t1;
				WHEN "11" =>
					adda <= breg;
					addb <= rotated;
				WHEN OTHERS =>
					--adda <= (OTHERS => '0');
					--addb <= (OTHERS => '0');		
			END CASE;
		ELSIF(stage = FINALIZE)THEN
			CASE step IS
				WHEN "00" =>
					adda <= a0;
					addb <= areg;
				WHEN "01" =>
					adda <= b0;
					addb <= breg;
				WHEN "10" =>
					adda <= c0;
					addb <= creg;
				WHEN "11" =>
					adda <= d0;
					addb <= dreg;
				WHEN OTHERS =>
				--	adda <= (OTHERS => '0');
				--	addb <= (OTHERS => '0');		
			END CASE;
		ELSE
			adda <= (OTHERS => '0');
			addb <= (OTHERS => '0');		
		END IF;
	END PROCESS;
	
	PROCESS(clk, reset, stage, step)
	BEGIN
	IF(rising_edge(clk))THEN
		IF(reset = '1')THEN
			a0 <= INITA;
			b0 <= INITB;
			c0 <= INITC;
			d0 <= INITD;
			ireg <= (OTHERS => '0'); freg <= (OTHERS => '0'); 
			t1<= (OTHERS => '0'); t0<= (OTHERS => '0'); step <= (OTHERS => '0');
			areg<= (OTHERS => '0'); breg<= (OTHERS => '0');
			creg <= (OTHERS => '0'); dreg <= (OTHERS => '0'); 
			stage <= FINISHED;
			--digest <= (OTHERS => '0');
		ELSIF(start = '1')THEN
			areg <= a0;
			breg <= b0;
			creg <= c0;
			dreg <= d0;
			step <= (OTHERS => '0');
			stage <= CRUNCH;
		ELSE
			CASE stage IS
			WHEN CRUNCH =>
				CASE step IS
					WHEN "00" => 
						freg <= f;
						t0 <= adds;
						step <= "01";
					WHEN "01" => 
						t1 <= adds;
						step <= "10";
					WHEN "10" => 
						t0 <= adds;
						step <= "11";
						ireg <= inext;
					WHEN "11" => 
						areg <= dreg;
						breg <= adds;
						creg <= breg;
						dreg <= creg;
						IF(ireg /= "000000")THEN
							step <= "00";
						ELSE
							step <= (OTHERS => '0');
							stage <= FINALIZE;
						END IF;				
					WHEN OTHERS => 
				END CASE;
			WHEN FINALIZE =>
			CASE step IS
				WHEN "00" =>
					a0 <= adds;
					step <= "01";
				WHEN "01" =>
					b0 <= adds;
					step <= "10";
				WHEN "10" =>
					c0 <= adds;
					step <= "11";
				WHEN "11" =>
					d0 <= adds;
					stage <= FINISHED;
				WHEN OTHERS =>
			END CASE;
		WHEN FINISHED =>
		
		WHEN OTHERS =>
		END CASE;
		END IF;
		
	END IF;
	END PROCESS;
	digest <= d0 & c0 & b0 & a0;
	iaddr <= ireg;
	
	
END Behaviour;
