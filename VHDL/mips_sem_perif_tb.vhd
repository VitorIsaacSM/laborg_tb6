-------------------------------------------------------------------------
--  TOP CPU PROCESSOR SIMULATION TESTBENCH
-------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;          

entity CPU_tb is
end CPU_tb;

architecture cpu_tb of cpu_tb is
  signal ck, reset, selCPU, ce, rw, resetCPU : std_logic := '0';      	  
  signal addressCPU, data_outRAM, data_outCPU, addressSERIAL: std_logic_vector(31 downto 0); 
begin

  	top: 
		entity work.MIPSmulti_with_BRAMs  port map(clock=>ck, reset=>reset,
			selCPU=>selCPU, addressSERIAL=>addressSERIAL, ce=>ce, rw=>rw, 
			resetCPU=>resetCPU, addressCPU=>addressCPU, data_outRAM=>data_outRAM,
			data_outCPU=>data_outCPU);
			
    selCPU <= '0';  
	
	addressSERIAL <= (others=>'0');

	reset <= '1', '0' after 40 ns;       

	ck <= not ck after 5 ns;

end cpu_tb;
