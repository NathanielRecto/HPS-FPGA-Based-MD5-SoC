--------------------------
-- md5_unit.vhd
-- COE838: Systems-on-Chip Design
-- Anita Tino
--------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

ENTITY md5_unit IS
	PORT( clk, wr							: IN STD_LOGIC;
			reset, start					: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			writedata						: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			writeaddr						: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			done								: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			digest0, digest1				: OUT STD_LOGIC_VECTOR(127 DOWNTO 0) := (OTHERS => '0'));
END ENTITY md5_unit;

ARCHITECTURE Behaviour of md5_unit IS

COMPONENT chunk_cruncher
	PORT( clk, reset, start				: IN STD_LOGIC;
			kdata, mdata					: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			sdata								: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			done								: OUT STD_LOGIC;
			gaddr								: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			iaddr								: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
			digest							: OUT STD_LOGIC_VECTOR(127 DOWNTO 0));
END COMPONENT;
--memory
COMPONENT krom 
	PORT(	address_a		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			address_b		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			clock				: IN STD_LOGIC  := '1';
			q_a				: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
			q_b				: OUT STD_LOGIC_VECTOR (31 DOWNTO 0));
END COMPONENT;

COMPONENT srom
PORT(	address_a		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
		clock				: IN STD_LOGIC  := '1';
		q_a				: OUT STD_LOGIC_VECTOR (4 DOWNTO 0);
		q_b				: OUT STD_LOGIC_VECTOR (4 DOWNTO 0));
END COMPONENT;

COMPONENT mram
PORT(	clock				: IN STD_LOGIC  := '1';
		data				: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		wren				: IN STD_LOGIC  := '0';
		q					: OUT STD_LOGIC_VECTOR (31 DOWNTO 0));
END COMPONENT;

SIGNAL m_write : STD_LOGIC_VECTOR(1 DOWNTO 0);
TYPE cci IS array (0 to 1) OF STD_LOGIC_VECTOR(5 DOWNTO 0);
TYPE ccg IS array (0 to 1) OF STD_LOGIC_VECTOR(3 DOWNTO 0);
TYPE ccd IS array (0 to 1) OF STD_LOGIC_VECTOR(127 DOWNTO 0);
TYPE ccm IS array (0 to 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
TYPE ccs IS array (0 to 1) OF STD_LOGIC_VECTOR(4 DOWNTO 0);

SIGNAL cc_iaddr : cci;
SIGNAL cc_gaddr : ccg;
SIGNAL cc_digest : ccd;
SIGNAL cc_mdata, cc_kdata : ccm;
SIGNAL cc_sdata : ccs;

BEGIN

gen_codeLabel: for i in 0 to 1 generate
BEGIN
cc : chunk_cruncher
	PORT MAP( clk => clk, reset => reset(i), start => start(i), 
			kdata => cc_kdata(i), mdata => cc_mdata(i), sdata => cc_sdata(i), 
			done => done(i), gaddr => cc_gaddr(i), iaddr	=> cc_iaddr(i), 
			digest => cc_digest(i));

mDataRAM : mram
PORT MAP(clock	=> clk, 	data => writedata, rdaddress => cc_gaddr(i),
			wraddress => writeaddr(3 DOWNTO 0), wren => m_write(i),	q => cc_mdata(i));		
END generate;

sDataROM : srom
PORT MAP(address_a => cc_iaddr(0), address_b	=> cc_iaddr(1), clock => clk,
			q_a => cc_sdata(0), q_b	=> cc_sdata(1));	

kDataROM : krom
PORT MAP(address_a => cc_iaddr(0), address_b	=> cc_iaddr(1), clock => clk,
			q_a => cc_kdata(0), q_b	=> cc_kdata(1));
			
m_write(0) <= wr AND NOT writeaddr(4);
m_write(1) <= wr AND writeaddr(4);
digest0 <= cc_digest(0);
digest1 <= cc_digest(1);

END Behaviour;
