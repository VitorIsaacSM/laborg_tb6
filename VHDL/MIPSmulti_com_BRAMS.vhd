-------------------------------------------------------------------------
--
--  MIPS-multicycle PROCESSOR   -  25/october/2005              
--	Ney Calazans / Fernando Moraes
--
--
--  NOV/2007  - VERSION WITH DATA AND INSTRUCTION MEMORIES
--  JUNE/2012 - Version where the processor is now a single
--		entity-architeture pair
-------------------------------------------------------------------------

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- package with basic types
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.Std_Logic_1164.all;

package p_MIPSmulti is  
    
        subtype reg32  is std_logic_vector(31 downto 0);
   
        -- inst_type defines the instructions decodeable by the control unit
        type inst_type is  
                ( ADDU, SUBU, AAND, OOR, XXOR, NNOR, SSLL, SLLV, SSRA, SRAV, SSRL, SRLV,
                ADDIU, ANDI, ORI, XORI, LUI, LBU, LW, SB, SW, SLT, SLTU, SLTI,
                SLTIU, BEQ, BGEZ, BLEZ, BNE, J, JAL, JALR, JR, MULTU, DIVU, MFHI, MFLO,
                invalid_instruction);
 
        type microinstruction is record
                CY1:   std_logic;       -- command of the first stage
                CY2:   std_logic;       --    "    of the second stage
                walu:  std_logic;       --    "    of the third stage
                wmdr:  std_logic;       --    "    of the fourth stage
                wpc:   std_logic;       -- PC write enable
                wreg:  std_logic;       -- register bank write enable
                ce:    std_logic;       -- Chip enable and R_W controls
                rw:    std_logic;
                bw:    std_logic;       -- Byte-word control (mem write only)
                i:     inst_type;       -- operation specification
                init_mul: std_logic;   -- command to start multiplication
                init_div: std_logic;   -- command to start division
        end record;
        
end p_MIPSmulti;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- register  
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.std_logic_1164.all;

entity regnbit is
           generic( INIT_VALUE : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0') );
           port(  ck, rst, ce : in std_logic;
                   D : in  STD_LOGIC_VECTOR (31 downto 0);
                   Q : out STD_LOGIC_VECTOR (31 downto 0)
               );
end regnbit;

architecture regn of regnbit is 
begin

  process(ck, rst)
  begin
       if rst = '1' then
              Q <= INIT_VALUE(31 downto 0);
       elsif ck'event and ck = '0' then
           if ce = '1' then
              Q <= D; 
           end if;
       end if;
  end process;
        
end regn;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Register Bank (R0..R31) - 31 GENERAL PURPOSE 16-bit REGISTERS
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.Std_Logic_1164.all;
use ieee.STD_LOGIC_UNSIGNED.all;   
use work.p_MIPSmulti.all;         
library UNISIM;
use UNISIM.vcomponents.all; 

entity reg_bank is
       port( ck, rst, wreg :    in std_logic;
             AdRs, AdRt, adRD : in std_logic_vector( 4 downto 0);
             RD : in reg32;
             R1, R2: out reg32 
           );
end reg_bank;

architecture reg_bank of reg_bank is
   type bank is array(0 to 31) of reg32;
   signal reg : bank ;                            
   signal wen : reg32 ;      
   signal address1, address2 : std_logic_vector( 4 downto 0) ;
begin            

    address1 <=  adRD when wreg='1' else AdRt; -- definio do endereo da primeira porta
	address2 <=  adRD when wreg='1' else AdRs; -- definio do endereo da primeira porta

--     banco: for i in 0 to 31 generate
--
--           M1: RAM32X1S
--                port map(
--                        WCLK=>ck,
--                        WE=>wreg,
--                        D=>RD(i),
--                        A0=>address1(0),   A1=>address1(1),   A2=>address1(2), A3=>address1(3), A4=>address1(4),
--                        O => R2(i));
--
--           M2: RAM32X1S
--                port map(
--                        WCLK=>ck,
--                        WE=>wreg,
--                        D=>RD(i),
--                        A0=>address2(0),   A1=>address2(1),   A2=>address2(2), A3=>address2(3), A4=>address2(4),
--                        O => R1(i));
--								
--    end generate banco;

     
    l1: for i in 0 to 31 generate   
        wen(i) <= '1' when i/=0 and adRD=i and wreg='1' else '0';
        rx: entity work.regnbit port map(ck => ck, rst => rst, ce => wen(i), D => RD, Q => reg(i));                    
    end generate l1;   
        
    R1 <= reg(CONV_INTEGER(AdRs));    -- source1 selection 

    R2 <= reg(CONV_INTEGER(AdRt));    -- source2 selection 
        
end reg_bank;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- ALU - operation depends only on the current instruction 
--       (decoded in the control unit)
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.p_MIPSmulti.all;

entity alu is
       port( op1, op2 : in reg32;
             outalu :   out reg32;   
             op_alu : in inst_type   
           );
end alu;

architecture alu of alu is 
   signal menorU, menorS : std_logic ;
begin
  
    menorU <=  '1' when op1 < op2 else '0';

    menorS <=  '1' when ieee.Std_Logic_signed."<"(op1,  op2) else '0' ; -- signed
        
    outalu <=  op1 - op2                                                                when  op_alu=SUBU                  else
               op1 and op2                                                              when  op_alu=AAND  or op_alu=ANDI  else 
               op1 or  op2                                                              when  op_alu=OOR   or op_alu=ORI   else 
               op1 xor op2                                                              when  op_alu=XXOR  or op_alu=XORI  else 
               op1 nor op2                                                              when  op_alu=NNOR                  else 
               to_StdLogicVector(to_bitvector(op1) sll CONV_INTEGER(op2(10 downto 6)))  when  op_alu=SSLL                  else 
               to_StdLogicVector(to_bitvector(op2) sll CONV_INTEGER(op1(5 downto 0)))   when  op_alu=SLLV                  else 
               to_StdLogicVector(to_bitvector(op1) sra CONV_INTEGER(op2(10 downto 6)))  when  op_alu=SSRA                  else 
               to_StdLogicVector(to_bitvector(op2) sra CONV_INTEGER(op1(5 downto 0)))   when  op_alu=SRAV                  else 
               to_StdLogicVector(to_bitvector(op1) srl CONV_INTEGER(op2(10 downto 6)))  when  op_alu=SSRL                  else 
               to_StdLogicVector(to_bitvector(op2) srl CONV_INTEGER(op1(5 downto 0)))   when  op_alu=SRLV                  else 
               op2(15 downto 0) & x"0000"                                               when  op_alu=LUI                   else
               (0=>menorU, others=>'0')                                                 when  op_alu=SLTU or op_alu=SLTIU  else   -- signed
               (0=>menorS, others=>'0')                                                 when  op_alu=SLT  or op_alu=SLTI   else   -- unsigned
               op1(31 downto 28) & op2(27 downto 0)                                     when  op_alu=J    or op_alu=JAL    else 
               op1                                                                      when  op_alu=JR   or op_alu=JALR   else 
               op1 + op2;                                                               -- default for ADDU,ADDIU,LBU,LW,SW,SB,BEQ,BGEZ,BLEZ,BNE    
end alu;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Multiplier - This is an implementation of a 32-bit serial multiplier
--              as proposed in Hennessy & Patterson textbook
--              - The implementation waits for a 1 clock cycle initialization 
--              input control signal, then it computes the multiplication in
--              the next 65 clock cycles, in the last of these generating a
--              1 clock cycle output signal (end_mul) to indicate
--              the end of the multiplication, which result is then 
--              available at the data outputs.
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity mult_serial is
         port(
                 clock : in STD_LOGIC;
                 start : in STD_LOGIC;            -- typically activated for exactly 1 clock cycle
                 Rs : in STD_LOGIC_VECTOR(31 downto 0);         -- multiplicand
                 B_Rt : in STD_LOGIC_VECTOR(31 downto 0);       -- multiplier 
                 end_mul : out STD_LOGIC;                                       -- end of multiplication, active for exactly 1 clock cycle
                 P_Hi : out STD_LOGIC_VECTOR(31 downto 0);      -- higher order word of result
                 A_Lo : out STD_LOGIC_VECTOR(31 downto 0)       -- lower order word of result
             );
end mult_serial;

architecture mult_serial of mult_serial is
type states is (Init, Sum, Displace);
signal PS, NS : states;
signal B, P_Hi_int, parcel : std_logic_vector(32 downto 0);
signal A_Lo_int : std_logic_vector(31 downto 0);
signal cont : std_logic_vector(4 downto 0);

begin                           
        
        P_Hi <= P_Hi_int(31 downto 0);
        A_Lo <= A_Lo_int;
        
        -- multiplication control state machine 
        process (clock)
        begin
                if clock'event and clock='1' then
                        PS <= NS;
                end if;
        end process;

        process (PS,start,cont)
        begin
                case PS is
                    when Init =>
                                if start='1' then NS <= Sum; else NS <= Init; end if;
                        when Sum =>
                                NS <= Displace;
                        when Displace =>
                                if (cont="00000") 
                                        then NS <= Init;
                                else NS <= Sum;
                                end if;
                        end case;               
        end process;
        
        -- combinational element of the datapath - conditional adder
        parcel <= P_Hi_int + ('0' & B_Rt) when A_Lo_int(0)='1' else P_Hi_int;

        -- sequential elements of the datapath
        -- P_Hi, A_Lo registers, cont counter, end_mul output
        process (clock)  
        begin
                if clock'event and clock='1' then
                        case PS is
                                when Init =>
                                        if start='1' then
                                                P_Hi_int <= (others=>'0');
                                                A_Lo_int <= Rs;
                                                cont <= (others=>'0');
                                        end if;
                                        end_mul <='0';
                                when Sum =>
                                        cont <= cont-1;
                                        P_Hi_int <= parcel;
                                when Displace =>
                                        if cont="00000" 
                                                then end_mul <='1';
                                        end if;
                                        P_Hi_int <= '0' & P_Hi_int (32 downto 1);
                                        A_Lo_int <= P_Hi_int (0)& A_Lo_int (31 downto 1);
                        end case;
                end if;
        end process;

end mult_serial;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Divider - This is an implementation of a 32-bit serial restoring
--              divider as proposed in Hennessy & Patterson textbook
--              - The implementation waits for a 1 clock cycle initialization 
--              input control signal, then it computes the multiplication in
--              the next XXX clock cycles, in the last of these generating a
--              1 clock cycle output signal (end_div) to indicate
--              the end of the diviSion, which result is then 
--              available at the data outputs.
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.Std_Logic_1164.all;
use IEEE.Std_Logic_unsigned.all;

entity div_serial is                  
      generic(size: integer := 32);
      port( reset, clock:               in  std_logic;
      	start: in  std_logic; 
      	Rs:    in  std_logic_vector((size-1) downto 0);
	B_Rt:  in  std_logic_vector((size-1) downto 0);
	end_div :    out std_logic;
	A_Lo, P_Hi : out std_logic_vector((size-1) downto 0));
end div_serial;

architecture div_serial of div_serial is   
   type State_type is (inicio, desloca, subtrai, esc_quoc, restaura, fim);
   signal EA, PE: State_type;
   
   signal regs_PA :             std_logic_vector( (size*2) downto 0); 
   -- concatenation of registers P e A:
   -- P - auxiliar reg that will contain the remainder at the end
   -- A - initially contains the dividend, at the end contains the quotient
   signal regB :                std_logic_vector( size downto 0);
   -- B - contains the divisor
   signal soma_sub :    std_logic_vector( size downto 0);
   -- control signal for add/subtract module: 0-add, 1-subtract
   signal cont :                integer;
     
begin      

   soma_sub <=  regs_PA(size*2 downto size) - regB   when EA=subtrai else 
                regs_PA(size*2 downto size) +  regB;   
   
   A_Lo   <= regs_PA( size-1 downto 0);
   P_Hi    <= regs_PA( size*2-1 downto size);
   
   end_div  <= '1' when EA=fim else '0';

   -- Process that implements registers regs_PA, regB and cont
   process(clock)
   begin    
     if clock'event and clock='1' then 
     
            if EA=inicio then 
                regs_PA(size*2 downto size) <= (others=>'0');
                regs_PA(size-1 downto 0) <= Rs;
                regB <= '0'& B_Rt;
                cont <= 0;
                
            elsif EA=desloca then  
                regs_PA(size*2 downto 0) <= regs_PA(((size*2)-1) downto 0) & '0';   
                                
            elsif EA=subtrai then
                regs_PA (size*2 downto size) <= soma_sub;

                        elsif EA=esc_quoc then
                                regs_PA(0) <= not regs_PA(size*2);

            elsif EA=restaura then
                                cont  <= cont + 1;
                                if regs_PA(size*2)='1' then
                                        regs_PA (size*2 downto size) <= soma_sub;
                                end if;
         end if;   
      end if;  
    end process;                                                                 
         
    -------------------------------------------------
    -- State machine to control the division process
    -------------------------------------------------

   process (reset, clock)
      begin
       if reset='1'then
                EA <= inicio; -- start by the idle state, called idle
       elsif clock'event and clock='1' then  
                EA <= PE;
      end if;
   end process;

   process (start, EA, cont)
      begin
         case EA is
            when inicio   =>  if start='1' then  PE <= desloca;  else   PE <= inicio;   end if;
                             
            when desloca  =>  PE <= subtrai;
            
            when subtrai  =>  PE <= esc_quoc;
            
            when esc_quoc =>  PE <= restaura; 
            
            when restaura =>  if cont=size-1 then  PE <= fim;  else  PE <= desloca; end if; 
                
            when fim     =>   PE <= inicio;
         end case; 
   end process;
   
end div_serial;

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Datapath structural description
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library IEEE;
use IEEE.Std_Logic_1164.all;
use IEEE.Std_Logic_signed.all; -- needed for comparison instructions SLTxx
use IEEE.Std_Logic_arith.all; -- needed for comparison instructions SLTxx
use work.p_MIPSmulti.all;
   
entity datapath is
      port(  ck, rst :     in std_logic;
             i_address :   out reg32;
             instruction : in reg32;
             d_address :   out reg32;
             data_in :        in reg32;  
             data_out :        out reg32;  
             uins :        in microinstruction;
             end_mul, end_div :        out std_logic;
             IR_OUT :      out reg32
          );
end datapath;

architecture datapath of datapath is

    signal incpc, pc, npc, IR,  result, R1, R2, RS, RT, RIN, ext16, cte_im, IMED, op1, op2, outalu, RALU, P_Hi,
            P_Lo, R_Hi, Q_Lo, MDR, mdr_int, dtpc, D_Hi, D_Lo,  Hi, Lo : reg32  ;

    signal adD, adS : std_logic_vector(4 downto 0);
    
    signal inst_branch, inst_grupo1, inst_grupoI, Hi_Lo_ce,  end_mul_int, end_div_int : std_logic;
    
    signal salta : std_logic;

begin

   -- auxiliary signals 
   inst_branch  <= '1' when uins.i=BEQ or uins.i=BGEZ or uins.i=BLEZ  or uins.i=BNE else 
                     '0';
                  
   inst_grupo1  <= '1' when uins.i=ADDU or uins.i=SUBU or uins.i=AAND or uins.i=OOR or uins.i=XXOR or uins.i=NNOR else
                     '0';

   inst_grupoI  <= '1' when uins.i=ADDIU or uins.i=ANDI or uins.i=ORI or uins.i=XORI else
                     '0';

   --==============================================================================
   -- first_stage
   --==============================================================================
  
   incpc <= pc + 4;
  
   RNPC: entity work.regnbit port map(ck => ck, rst => rst, ce => uins.CY1, D => incpc, Q => npc);     
           
   RIR: entity work.regnbit  port map(ck => ck, rst => rst, ce => uins.CY1, D => instruction, Q => IR);

   IR_OUT <= ir ;    -- IR is the datapath output signal to carry the instruction
             
   i_address <= pc;  -- connects PC output to the instruction memory address bus
    
   --==============================================================================
   -- second stage
   --==============================================================================
  
   -- signal to be written into the register bank
   RIN <= npc when (uins.i=JALR or uins.i=JAL) else result;
   
   -- register bank write address selection
   adD <= "11111"                  when uins.i=JAL else -- JAL writes in register $31
           IR(15 downto 11)        when inst_grupo1='1' or uins.i=SLTU or uins.i=SLT or uins.i=JALR or uins.i=MFHI or uins.i=MFLO else
           IR(20 downto 16);       -- inst_grupoI='1' or uins.i=SLTIU or uins.i=SLTI or uins.i=LW or  uins.i=LBU  or uins.i=LUI, or default
                
   -- The then clause is only used for logic shifts with shamt field       
   adS <= IR(20 downto 16) when uins.i=SSLL or uins.i=SSRA or uins.i=SSRL else 
           IR(25 downto 21)   ;               

   REGS: entity work.reg_bank port map
            (ck => ck, rst => rst, wreg => uins.wreg,  AdRs => adS, AdRt => ir(20 downto 16), adRD => adD,  RD => RIN, R1 => R1, R2 => R2);
    
   -- sign extension 
   ext16 <=  x"FFFF" & IR(15 downto 0) when IR(15)='1' else
             x"0000" & IR(15 downto 0);
    
   -- Immediate constant
   cte_im <= ext16(29 downto 0)  & "00"     when inst_branch='1'     else                    -- branch address adjustment for word frontier
             "0000" & IR(25 downto 0) & "00" when uins.i=J or uins.i=JAL else                -- J/JAL are word addressed. MSB four bits are defined at the ALU, not here!
             x"0000" & IR(15 downto 0) when uins.i=ANDI or uins.i=ORI  or uins.i=XORI else   -- logic instructions with immediate operand are zero extended
             ext16;                                                                          -- The default case is used by addiu, lbu, lw, sbu and sw instructions
             
   -- second stage registers
   REG_S: entity work.regnbit   port map(ck => ck, rst => rst, ce => uins.CY2, D => R1,     Q => RS);

   REG_T: entity work.regnbit   port map(ck => ck, rst => rst, ce => uins.CY2, D => R2,     Q => RT);
  
   REG_IM: entity work.regnbit  port map(ck => ck, rst => rst, ce => uins.CY2, D => cte_im, Q => IMED);
 
 
  --==============================================================================
   -- third stage
   --==============================================================================
                      
   -- select the first ALU operand                           
   -- op1 <= pc  when inst_branch='1' else  -- use this below for code generated with the PCSPIM simulator
   -- op1 <= npc  when inst_branch='1' else  -- use this below for code generated with the MARS simulator   
   op1 <= npc  when inst_branch='1' else 
          RS; 
     
   -- select the second ALU operand
   -- RT when grupo1 instructions or SLT/SLTU or JR or shifts with no shamt field
   op2 <= RT when inst_grupo1='1' or uins.i=SLTU or uins.i=SLT or uins.i=JR  or uins.i=SLLV or uins.i=SRAV or uins.i=SRLV else 
          IMED; 
                 
   -- ALU instantiation
   inst_alu: entity work.alu port map (op1 => op1, op2 => op2, outalu => outalu, op_alu => uins.i);
                                   
   -- ALU register
   REG_alu: entity work.regnbit   port map(ck => ck, rst => rst, ce => uins.walu, D => outalu, Q => RALU);               
 
   end_mul <= end_mul_int;
   
   -- Multiplier instantiation
   inst_mult: entity work.mult_serial    port map (clock=>ck, start=>uins.init_mul, Rs=>RS, B_Rt=>RT,
                                                         end_mul=>end_mul_int, P_Hi=>P_Hi, A_Lo=>P_Lo);

   end_div <= end_div_int;
   
   -- Divider instantiation
   inst_div: entity work.div_serial  port map (reset=>rst, clock=>ck, start=>uins.init_div, Rs=>RS, B_Rt=>RT,
                                                     end_div=>end_div_int, P_Hi=>R_Hi, A_Lo=>Q_Lo);
 
   -- select source for the Hi Register                           
   D_Hi <= P_Hi  when uins.i=MULTU else  R_Hi; 

   -- select source for the Lo Register                           
   D_Lo <= P_Lo  when uins.i=MULTU else  Q_Lo; 

   -- Hi and Lo registers write enable
   Hi_Lo_ce <= '1' when (uins.walu='1' and   ((uins.i=DIVU and end_div_int='1') or (uins.i=MULTU and end_mul_int='1'))) else     '0';
   
   -- Hi register
   REG_Hi: entity work.regnbit port map(ck=>ck, rst=>rst, ce=>Hi_Lo_ce, D=>D_Hi, Q=>Hi);               

   -- Lo register
   REG_Lo: entity work.regnbit port map(ck=>ck, rst=>rst, ce=>Hi_Lo_ce, D=>D_Lo, Q=>Lo);               

   -- evaluation of conditions to take the branch instructions
   salta <=  '1' when ( (RS=RT  and uins.i=BEQ)  or (RS>=0  and uins.i=BGEZ) or  (RS<=0  and uins.i=BLEZ) or (RS/=RT and uins.i=BNE) )  else
              '0';
                  
   result <=   Hi when uins.i=MFHI else
               Lo when uins.i=MFLO else
               MDR when uins.i=LW  or uins.i=LBU else
               RALU;
            
   --==============================================================================
   -- fourth stage
   --==============================================================================
     
   d_address <= RALU;
    
   data_out <= RT;  

   -- single byte reading from memory
   mdr_int <= data_in when uins.i=LW  else
              x"000000" & data_in(7 downto 0);
       
   RMDR: entity work.regnbit  port map(ck => ck, rst => rst, ce => uins.wmdr, D => mdr_int, Q => MDR);                 
                
   --==============================================================================
   -- fifth stage
   --==============================================================================
    
   dtpc <= result when (inst_branch='1' and salta='1') or uins.i=J 
           or uins.i=JAL or uins.i=JALR or uins.i=JR  else npc;
   
   --  Data memory starting address: beware of the OFFSET!
   -- rpc: entity work.regnbit generic map(INIT_VALUE => x"00400020")   use this below for code generated with the PCSPIM simulator
   -- rpc: entity work.regnbit generic map(INIT_VALUE => x"00400000")   use this below for code generated with the MARS simulator     
   rpc: entity work.regnbit generic map(INIT_VALUE => x"00400000")
                 port map(ck => ck, rst => rst, ce => uins.wpc, D => dtpc, Q => pc);

end datapath;

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--  Control Unit behavioral description 
--------------------------------------------------------------------------
--------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use work.p_MIPSmulti.all;

entity control_unit is
        port(   ck, rst : in std_logic;          
                uins : out microinstruction;
                end_mul, end_div : in std_logic;
                ir : in reg32
             );
end control_unit;
                   
architecture control_unit of control_unit is

   type type_state is (Sidle, Sfetch, Sreg, Salu, Swbk, Sld, Sst, Ssalta);
   -- only 8 states needed
                
   signal PS, NS : type_state;
   signal i : inst_type;      
begin
      
    ----------------------------------------------------------------------------------------
    -- BLOCK (1/3) - INSTRUCTION DECODING and ALU operation definition.
    -- This block generates 1 Output Function of the Control Unit
    ----------------------------------------------------------------------------------------
    i <=   ADDU   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100001" else
           SUBU   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100011" else
           AAND   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100100" else
           OOR    when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100101" else
           XXOR   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100110" else
           NNOR   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000100111" else
           SSLL   when ir(31 downto 21)="00000000000" and ir(5 downto 0)="000000" else
           SLLV   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000000100" else
           SSRA   when ir(31 downto 21)="00000000000" and ir(5 downto 0)="000011" else
           SRAV   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000000111" else
           SSRL   when ir(31 downto 21)="00000000000" and ir(5 downto 0)="000010" else
           SRLV   when ir(31 downto 26)="000000" and ir(10 downto 0)="00000000110" else
           ADDIU  when ir(31 downto 26)="001001" else
           ADDIU  when ir(31 downto 26)="001000" else  --- ADDI  tratado igual a adddiu - moraes 12/out
           ANDI   when ir(31 downto 26)="001100" else
           ORI    when ir(31 downto 26)="001101" else
           XORI   when ir(31 downto 26)="001110" else
           LUI    when ir(31 downto 26)="001111" else
           LW     when ir(31 downto 26)="100011" else
           LBU    when ir(31 downto 26)="100100" else
           SW     when ir(31 downto 26)="101011" else
           SB     when ir(31 downto 26)="101000" else
           SLTU   when ir(31 downto 26)="000000" and ir(5 downto 0)="101011" else
           SLT    when ir(31 downto 26)="000000" and ir(5 downto 0)="101010" else
           SLTIU  when ir(31 downto 26)="001011"                             else
           SLTI   when ir(31 downto 26)="001010"                             else
           BEQ    when ir(31 downto 26)="000100" else
           BGEZ   when ir(31 downto 26)="000001" else
           BLEZ   when ir(31 downto 26)="000110" else
           BNE    when ir(31 downto 26)="000101" else
           J      when ir(31 downto 26)="000010" else
           JAL    when ir(31 downto 26)="000011" else
           JALR   when ir(31 downto 26)="000000"  and ir(20 downto 16)="00000" and ir(10 downto 0) = "00000001001" else
           JR     when ir(31 downto 26)="000000" and ir(20 downto 0)="000000000000000001000" else
           MULTU  when ir(31 downto 26)="000000" and ir(15 downto 0)=x"0019" else
           DIVU   when ir(31 downto 26)="000000" and ir(15 downto 0)=x"001B" else
           MFHI   when ir(31 downto 16)=x"0000" and ir(10 downto 0)="00000010000" else
           MFLO   when ir(31 downto 16)=x"0000" and ir(10 downto 0)="00000010010" else
           invalid_instruction ; -- IMPORTANT: default condition is invalid instruction;
        
    assert i /= invalid_instruction
          report "******************* INVALID INSTRUCTION *************"
          severity error;
                   
    uins.i <= i;    -- this instructs the alu to execute its expected operation, if any

    ----------------------------------------------------------------------------------------
    -- BLOCK (3/3) - DATAPATH REGISTERS load control signals generation.
    ----------------------------------------------------------------------------------------
    uins.CY1   <= '1' when PS=Sfetch else
                  '0';
            
    uins.CY2   <= '1' when PS=Sreg else
                  '0';
  
    uins.init_mul  <= '1' when PS=Sreg and i=MULTU else
                  '0';
  
    uins.init_div  <= '1' when PS=Sreg and i=DIVU else
                  '0';
  
    uins.walu  <= '1' when PS=Salu else
                  '0';
                
    uins.wmdr  <= '1' when PS=Sld  else
                  '0';
  
    uins.wreg   <= '1' when PS=Swbk or (PS=Ssalta and (i=JAL or i=JALR)) else
                   '0';
   
    uins.rw    <= '0' when PS=Sst  else
                  '1';
                  
    uins.ce    <= '1' when PS=Sld or PS=Sst  else
                  '0';
    
    uins.bw    <= '0' when (PS=Sst and i=SB)  else
                  '1';
      
    uins.wpc   <= '1' when PS=Swbk or PS=Sst or PS=Ssalta 
                                                or (PS=Salu and ((i=DIVU and end_div='1') or (i=MULTU and end_mul='1')))  else
                  '0';
  
    ---------------------------------------------------------------------------------------------
    -- BLOCK (2/3) - Sequential part of the control unit - two processes implementing the
    -- Control Unit state register and the next-state (combinational) function
    --------------------------------------------------------------------------------------------- 
    process(rst, ck)
    begin
       if rst='1' then
            PS <= Sidle;
        -- Sidle is the state the machine stays while processor is being reset
       elsif ck'event and ck='1' then
       
            if PS=Sidle then
                  PS <= Sfetch;
            else
                  PS <= NS;
            end if;
                
       end if;
    end process;
     
     
    process(PS, i, end_mul, end_div)
        -- NEXT state: depends on the PRESENT state, on the current instruction
        -- and on the end_mul signal, that unlocks the control unit attribute the end of a
        -- multiplication operation
    begin
       case PS is         
      
            when Sidle => NS <= Sidle; -- reset being active, the processor do nothing!       

            --
            -- first stage:  read the current instruction 
            --
            when Sfetch => NS <= Sreg;  
     
            --
            -- second stage: read the register banck and store the mask (when i=stmsk)
            --
            when Sreg => NS <= Salu;  

             
            --
            -- third stage: alu operation 
            --
            when Salu  => if ((i=MULTU and end_mul='0') or (i=DIVU and end_div='0')) then
                                                                NS <= Salu;
                                                  elsif ((i=DIVU and end_div='1') or (i=MULTU and end_mul='1')) then  
                                                                NS <= Sfetch;
                                                  elsif i=LBU  or i=LW then 
                                NS <= Sld;  
                          elsif i=SB or i=SW then 
                                NS <= Sst;
                          elsif i=J or i=JAL or i=JALR or i=JR or i=BEQ
                                or i=BGEZ or i=BLEZ  or i=BNE then 
                                NS <= Ssalta;  
                          else 
                                NS <= Swbk; 
                          end if;
                         
            --                  
            -- fourth stage: data memory operation  
            --
            when Sld =>   NS <= Swbk; 
            
            --
            -- fifth clock cycle of most instructions  - GO BACK TO FETCH
            -- 
            when Sst | Ssalta | Swbk => NS <= Sfetch;
  
       end case;

    end process;
    
end control_unit;

--------------------------------------------------------------------------
-- Top-level instantiation of MIPS-multicycle Datapath and Control Unit
--------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use work.p_MIPSmulti.all;

entity MIPSmulti is
    port( clock, reset: in std_logic;
          ce, rw, bw: out std_logic;
          i_address, d_address: out std_logic_vector(31 downto 0);
          instruction: in std_logic_vector(31 downto 0);
          data_in: in std_logic_vector(31 downto 0);
			 data_out: out std_logic_vector(31 downto 0));
end MIPSmulti;

architecture MIPSmulti of MIPSmulti is
      signal IR: std_logic_vector(31 downto 0);
      signal uins: microinstruction;  
	  signal end_mul, end_div : std_logic;
 begin

     dp: entity work.datapath   
         port map( ck=>clock, rst=>reset, IR_OUT=>IR, uins=>uins, i_address=>i_address, 
                   instruction=>instruction, d_address=>d_address,  data_in=>data_in, 
                   data_out=>data_out, end_mul=>end_mul, end_div=>end_div);

     ct: entity work.control_unit port map( ck=>clock, rst=>reset, ir=>IR, uins=>uins, 
						end_mul=>end_mul, end_div=>end_div);
         
     ce <= uins.ce;
     rw <= uins.rw; 
     bw <= uins.bw;
     
end MIPSmulti;

--------------------------------------------------------------------------
-- Top-level instantiation of the MR4 Datapath and Control Unit
--------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use IEEE.Std_Logic_unsigned.all;
use work.p_MIPSmulti.all;  

entity MIPSmulti_with_BRAMs is
    port( clock, reset, selCPU: in std_logic;
          addressSERIAL: in reg32;
			 ce, rw, resetCPU: out std_logic;
			 addressCPU: out reg32;
          data_outCPU, data_outRAM: out reg32);
end MIPSmulti_with_BRAMs;

architecture MIPSmulti_with_BRAMs of MIPSmulti_with_BRAMs is
      signal IR: reg32;
      signal uins: microinstruction;
      signal ce_int, rw_int, bw, rst_cpu: std_logic;
    
      signal int_address : std_logic_vector(8 downto 0);    -- 9 bits endereveis : 512 words ---- 
  
      signal i_address, instruction, addressCPU_int, addressRAM, data_out_CPU, data_out_RAM : reg32;
    

 begin
	  addressCPU <= addressCPU_int;
	  ce <= ce_int; 
	  rw <= rw_int;
	  resetCPU <= rst_cpu; 
	  
     MIPS_multi: entity work.MIPSmulti
    		port map(clock=>clock, reset=>rst_cpu,
          	ce=>ce_int, rw=>rw_int, bw=>bw, i_address=>i_address, d_address=>addressCPU_int,
          	instruction=>instruction, data_out=>data_out_CPU,
          	data_in=>data_out_RAM);
     
     -----    
     ----  MEMRIA RAM COM AS INSTRUES
     ----
--   use the line below when running programs generated with PCSpim
--   int_address <=  i_address(10 downto 2)-8;  -- tira o deslocamento de 20H       
--   use the line below when running programs generated with Mars
--   int_address <=  i_address(10 downto 2); 
     int_address <=  i_address(10 downto 2);
     P_mem: entity work.program_memory  
        port map( clock=>clock, address=>int_address, instruction=>instruction);

     -----    
     ----  MEMORIA RAM COM OS DADOS
     ----   
     D_mem: entity work.data_memory 
		port map (clock=>clock, ce=>ce_int, we=>rw_int, bw=>bw, 
		address=>addressRAM(12 downto 2), data_in=>data_out_CPU, data_out=>data_out_RAM);
                                            
    addressRAM <=   addressCPU_int  when selCPU='0' else  addressSERIAL;
    
    rst_cpu <= reset or selCPU;
   
    data_outRAM <= data_out_RAM; -- what comes from memory 
    data_outCPU <= data_out_CPU; -- what comes from the processor 
    
end MIPSmulti_with_BRAMs;
