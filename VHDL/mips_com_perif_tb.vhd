-------------------------------------------------------------------------
--  TOP CPU PROCESSOR SIMULATION TESTBENCH
-------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;          

entity conts_tb is
end conts_tb;

architecture conts_tb of conts_tb is
  signal ck, rst, selCPU : std_logic :='0';      	  
  signal an: std_logic_vector(3 downto 0);
  signal dec_ddp: std_logic_vector(7 downto 0);
begin
		
	inst_top_conts:
		entity work.top_conts
			port map (ck=>ck, reset=>rst, selCPU=>selCPU, an=>an, dec_ddp=>dec_ddp);
	  
	selCPU <= '0'; 
	rst <='1', '0' after 120 ns;       -- generates the reset signal 

	ck <= not ck  after 5 ns;

    
end conts_tb;