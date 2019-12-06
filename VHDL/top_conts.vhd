library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_conts is
	port(
	ck, reset, selCPU: in std_logic;
	an: out STD_LOGIC_VECTOR(3 downto 0);
	dec_ddp: out STD_LOGIC_VECTOR(7 downto 0)
	);
end top_conts;

architecture Behavioral of top_conts is
	signal ce, rw, resetCPU: STD_LOGIC;
	signal addressCPU, data_outCPU: STD_LOGIC_VECTOR(31 downto 0);

begin

	processador: entity work.MIPSmulti_with_BRAMs port map(clock => ck, reset => reset, selCPU => selCPU,
		data_outCPU => data_outCPU, addressCPU => addressCPU, ce => ce, rw => rw, resetCPU => resetCPU, addressSERIAL => (others=>'0'));

	periferico: entity work.periferico port map(address => addressCPU, data => data_outCPU(3 downto 0),
		ce => ce, ck => ck, rst => resetCPU, rw => rw, an => an, dec_ddp => dec_ddp);

end Behavioral;
