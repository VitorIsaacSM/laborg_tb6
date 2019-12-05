/*************************************
*
*
*  PROGRAMA QUE LÊ O LOG DO SIMULADOR MARS E GERA UM VHDL COM A
*  INICIALIZAÇÃO DOS BLOCOS DE MEMÓRIA
*
*  FERNANDO GEHM MORAES     - 16/11/2007
*  Alterado para o MARS por
*  NEY LAERT VILAR CALAZANS - 16/11/2007
*  FERNANDO MORAES - 30/OUT/2012 - leitura de dois arquivos
*  FERNANDO MORAES - 01/jun/2013 - getline2 ao inves de getline
*  NEY CALAZANS - 12/jun/2013 - bugzinho documentacional no  help removido
*************************************/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <strings.h>
#include <time.h>

#define TAM 250

int separador(char car)
 {
  switch(car)
   { case ' ': case '\n': case '\t': case '\r':   case '/':
     case '*': case '=':  case ',':   case '.':  return 1;
     default: return 0;
   }
}


/***********************************
* Retorna uma string da linha lida *
***********************************/
int search_word(char *word, int *counter, char *token)
{
    int             k = 0;

    while (separador(word[*counter]))
        (*counter)++;
    while (!separador(word[*counter]) && word[*counter] != '\0')
        token[k++] = word[(*counter)++];
    token[k] = '\0';
    return k;
}




/**********************************************************************/
 // ROTINA PARA LER UMA LINHA - BY MORAES
/**********************************************************************/
int             getline2(word, limit, p1)
    char           *word;
    FILE           *p1;
    int             limit;
/**********************************************************************/
{   int             i = 0;
    char            c;

    while ((c = getc(p1)) != '\n') {
        if (c == EOF)
            return 0;
        word[i] = c;
        if(++i==TAM)
             { printf("\ERROR : line too large %s %d\n", word, (int) strlen(word));
               fflush(stdout);
               exit(1);
             }

    }

    word[i] = 0x00;   // TIRA O \n  DA STRING

    return 1;
}


//-------------------------------------------------------------------------------
int main(int argc, char *argv[])
//-------------------------------------------------------------------------------
{
  FILE *fp, *out;
  int i,j, palavra, offset, b, DEBUG;
  char line[TAM], wd[TAM], memoria_dados[64][65],  ram0[64][65], ram1[64][65], ram2[64][65], ram3[64][65];
  time_t clock;

  clock = time(NULL);

  if (argc==1) {
     puts("*******************************************************************************");
     puts("*         PROGRAMA QUE LE DOIS ARQUIVOS: instrucoes e dados                  *");
   printf("*         uso: %12s <arquivo instrucoes> <arquivo dados> [d]            *\n", argv[0]);
     puts("*         [d] pode ser qualquer caracter. Eh opcional, se existir indica debug        *");
     puts("*         Please report all bugs to {fernando.moraes,ney.calazans}@pucrs.br   * ");
     puts("*******************************************************************************\n");
     return(0);
  }

  // inicializa os strings relativos à memória  (1 BRAM DE LARGURA 32 PARA AS INSTRUÇÕES E 4 BRAMS DE LARGURA 8 PARA OS DADDOS)
  for(i=0; i<64; i++)
    { for(j=0; j<64; j++)
           { memoria_dados[i][j]='0';
             ram0[i][j]='0';
             ram1[i][j]='0';
             ram2[i][j]='0';
             ram3[i][j]='0';
           }
      memoria_dados[i][64]='\0';
      ram0[i][64]='\0';
      ram1[i][64]='\0';
      ram2[i][64]='\0';
      ram3[i][64]='\0';
    }

  out = fopen("memory.vhd", "w");

  if (argc==4)  DEBUG=1;  else  DEBUG=0;

  //////////////////
  /////////////////    READ INSTRUCTION FILE
  /////////////////
  if ((fp = fopen(argv[1], "r")) == NULL) {
            printf("Erro abrindo o arquivo %s !\n", argv[1]);
            return 0;
        }

  puts("---------------------- PROCESSING INSTRUCTIONS ");

  offset = 56 ;
  palavra = 0;

  // verifies if the data file IS the data file
  getline2(line, TAM, fp);
  i = 0;
  search_word(line, &i, wd);
  if( strcmp(wd,"Address")) {
  	 printf("\nThe first word of the instruction file is %s and not Address - maybe you changed the order of the input files - REVIEW! - not generating the memory.vhd\n\n", wd);
  	 return(0);
   }

  while (getline2(line, TAM, fp))
    {
      i = 0;                         // aponta para o início da linha
      search_word(line, &i, wd);     // wd é ponteiro para próximo token

      if (wd[0]=='0' &&  wd[1]=='x' )   // a linha de programa começa com "0x" ==> endereço válido
           {
             if (DEBUG) printf("Endereco de programa  %10s   ", wd);

             search_word(line, &i, wd);      // código

             if (DEBUG) printf("com opcode %10s\n", wd);

             // TRANSFERE PARA A MEMÓRIA DE DADOS (geração da SAÍDA)
             for(b=0; b<8; b++)
                  memoria_dados[palavra][offset+b] = wd[b+2];   // o "+2" tira o 0x

              offset = offset - 8;
              if( offset < 0 )
                { offset = 56 ;    // deslocamento dentro da string relativa á memória - a string vai de 0 a 63
                  palavra ++ ;
                }
            }

     }

  fclose(fp);


  //////////////////
  /////////////////    READ DATA FILE
  /////////////////
  if ((fp = fopen(argv[2], "r")) == NULL) {
            printf("Erro abrindo o arquivo %s !\n", argv[2]);
            return 0;
        }

  puts("---------------------- PROCESSING DATA ");
  palavra = 0;

  while (getline2(line, TAM, fp))
    {
      i = 0;                         // aponta para o início da linha
      search_word(line, &i, wd);     // wd é ponteiro para próximo token

      if (wd[0]=='0' &&  wd[1]=='x' )   // a linha de dados começa com "0x" ==> endereço válido
           {
             if (DEBUG) printf("\nEndereco de dados %10s\n", wd);

             /// word tem o formato 0 x 1 2 3 4 5 6 7 8
             /// indices            0 1 2 3 4 5 6 7 8 9 10

             wd[10] = '\0';                   //  coloca nova linha após o último dígito
             sscanf(wd+6, "%X", &offset);     //  transforma para int a partir do quarto caracter
             offset /= 4;                     // divide por 4 para obter o endereçamento em word

             palavra = offset / 32;            // a divisão do endereço dá o indice na memória

             if( palavra > 63 ) continue;   // evita estouro na matriz

             offset -= palavra*32; // resto

             //     índices de  wd:   2 3 4 5 6 7 8 9     exemplo: 12345678

             while ( search_word(line, &i, wd))     // lê o restante da linha
                if (wd[0]=='0' &&  wd[1]=='x')
                  {  if (DEBUG) printf("p%d o%d %s\n", palavra, offset, wd);
                     ram3[palavra][63-offset*2-1] = wd[2];       // se offset=0   62
                     ram3[palavra][63-offset*2]   = wd[3];       //               63
                     ram2[palavra][63-offset*2-1] = wd[4];
                     ram2[palavra][63-offset*2]   = wd[5];
                     ram1[palavra][63-offset*2-1] = wd[6];
                     ram1[palavra][63-offset*2]   = wd[7];
                     ram0[palavra][63-offset*2-1] = wd[8];
                     ram0[palavra][63-offset*2]   = wd[9];
                     offset += 1;
                  }
            }
     }
   fclose(fp);

    puts("---------------------- GENERATING VHDL FILE  memory.vhd ");


   fprintf(out,"--\n--  GERADO AUTOMATICAMENTE  -  FERNANDO GEHM MORAES  -- %s--\n\n", ctime(&clock) );

   fprintf(out,"--------------------------------------------------------------------------\n");
   fprintf(out,"--  MEMÓRIA DE PROGRAMA   - UMA MEMÓRIA DE 512 X 32 bits   (16384 BYTES)\n");
   fprintf(out,"--------------------------------------------------------------------------\n");
   fprintf(out,"library IEEE;\n");
   fprintf(out,"use IEEE.Std_Logic_1164.all;\n");
   fprintf(out,"library UNISIM;\n");
   fprintf(out,"use UNISIM.vcomponents.all; \n");
   fprintf(out,"\n");
   fprintf(out,"entity program_memory is\n");
   fprintf(out,"    port( clock: in std_logic;\n");
   fprintf(out,"          address: in std_logic_vector(8 downto 0);\n");
   fprintf(out,"          instruction: out std_logic_vector(31 downto 0));\n");
   fprintf(out,"end program_memory;\n");
   fprintf(out,"\n");
   fprintf(out,"architecture a1 of program_memory is     \n");
   fprintf(out,"begin\n");
   fprintf(out,"           \n");
   fprintf(out,"   programa : RAMB16_S36\n");
   fprintf(out,"   generic map (\n");
   for(i=0 ; i<16; i++)
         fprintf(out,"        INIT_0%X => X\"%s\",\n", i, memoria_dados[i]);
   for(i=16 ; i<63; i++)
         fprintf(out,"        INIT_%X => X\"%s\",\n", i, memoria_dados[i]);
   fprintf(out,"        INIT_%X => X\"%s\")\n", i, memoria_dados[i]);
   fprintf(out,"   port map (\n");
   fprintf(out,"            CLK     => clock,\n");
   fprintf(out,"            ADDR    => address,\n");
   fprintf(out,"            EN      => '1',\n");
   fprintf(out,"            WE      => '0',\n");
   fprintf(out,"            DI      => x\"00000000\",\n");
   fprintf(out,"            DIP     => x\"0\",\n");
   fprintf(out,"            DO      => instruction,\n");
   fprintf(out,"            SSR     => '0'\n");
   fprintf(out,"            );\n");
   fprintf(out,"\n");
   fprintf(out,"end a1;\n");




   fprintf(out,"\n\n\n--------------------------------------------------------------------------\n");
   fprintf(out,"--  MEMÓRIA DE DADOS - 4 memórias de 2048 * 8 bits ( 657536 BYTES)    \n");
   fprintf(out,"--\n");
   fprintf(out,"--   supondo na memória de dados:   00 00 00 00 \n");
   fprintf(out,"--                                  10 00 00 AA\n");
   fprintf(out,"--                                  20 00 BB 00\n");
   fprintf(out,"--                                  30 CC 00 00\n");
   fprintf(out,"--\n");
   fprintf(out,"--  As inicializaçães ficam como segue:\n");
   fprintf(out,"--\n");
   fprintf(out,"-- mem 3-  INIT_00 => X\"0000000000000000000000000000000000000000000000000000000030201000\",\n");
   fprintf(out,"-- mem 2-  INIT_00 => X\"00000000000000000000000000000000000000000000000000000000CC000000\",\n");
   fprintf(out,"-- mem 1-  INIT_00 => X\"0000000000000000000000000000000000000000000000000000000000BB0000\",\n");
   fprintf(out,"-- mem 0-  INIT_00 => X\"000000000000000000000000000000000000000000000000000000000000AA00\",\n");
   fprintf(out,"--\n");
   fprintf(out,"--------------------------------------------------------------------------\n");
   fprintf(out,"library IEEE;\n");
   fprintf(out,"use IEEE.Std_Logic_1164.all;\n");
   fprintf(out,"library UNISIM;\n");
   fprintf(out,"use UNISIM.vcomponents.all; \n");
   fprintf(out,"\n");
   fprintf(out,"entity data_memory is\n");
   fprintf(out,"    port( clock, ce, we, bw: in std_logic;\n");
   fprintf(out,"          address: in std_logic_vector(10 downto 0);    -- 11 bits - 2048 palavras endereçáveis\n");
   fprintf(out,"          data_in: in std_logic_vector(31 downto 0);\n");
   fprintf(out,"          data_out: out std_logic_vector(31 downto 0));\n");
   fprintf(out,"end data_memory;\n");
   fprintf(out,"\n");
   fprintf(out,"architecture a1 of data_memory is \n");
   fprintf(out,"    signal we3, we2, we1, we0 : std_logic;\n");
   fprintf(out,"begin\n");
   fprintf(out,"\n");
   fprintf(out,"    we3 <= '1' when we='0' and bw='1' else '0';\n");
   fprintf(out,"    we2 <= '1' when we='0' and bw='1' else '0';\n");
   fprintf(out,"    we1 <= '1' when we='0' and bw='1' else '0';\n");
   fprintf(out,"    we0 <= '1' when we='0'            else '0';\n");

   fprintf(out,"\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"   -- bytes 31 a 24\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"    mem_3 : RAMB16_S9\n");
   fprintf(out,"         generic map (\n");
   for(i=0 ; i<16; i++)
         fprintf(out,"        INIT_0%X => X\"%s\",\n", i, ram3[i]);
   for(i=16 ; i<63; i++)
         fprintf(out,"        INIT_%X => X\"%s\",\n", i, ram3[i]);
   fprintf(out,"        INIT_%X => X\"%s\")\n", i, ram3[i]);
   fprintf(out,"  port map (\n");
   fprintf(out,"         CLK     => clock,\n");
   fprintf(out,"         ADDR    => address,\n");
   fprintf(out,"         EN      => '1',\n");
   fprintf(out,"         WE      => we3,\n");
   fprintf(out,"         DI      => data_in(31 downto 24),\n");
   fprintf(out,"         DIP     => \"0\",\n");
   fprintf(out,"         DO      => data_out(31 downto 24),\n");
   fprintf(out,"         SSR     => '0'\n");
   fprintf(out,"         );\n");


   fprintf(out,"\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"   -- bytes 23 a 16\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"    mem_2 : RAMB16_S9\n");
   fprintf(out,"         generic map (\n");
   for(i=0 ; i<16; i++)
         fprintf(out,"        INIT_0%X => X\"%s\",\n", i, ram2[i]);
   for(i=16 ; i<63; i++)
         fprintf(out,"        INIT_%X => X\"%s\",\n", i, ram2[i]);
   fprintf(out,"        INIT_%X => X\"%s\")\n", i, ram2[i]);
   fprintf(out,"  port map (\n");
   fprintf(out,"         CLK     => clock,\n");
   fprintf(out,"         ADDR    => address,\n");
   fprintf(out,"         EN      => '1',\n");
   fprintf(out,"         WE      => we3,\n");
   fprintf(out,"         DI      => data_in(23 downto 16),\n");
   fprintf(out,"         DIP     => \"0\",\n");
   fprintf(out,"         DO      => data_out(23 downto 16),\n");
   fprintf(out,"         SSR     => '0'\n");
   fprintf(out,"         );\n");


   fprintf(out,"\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"   -- bytes 15 a 8\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"    mem_1 : RAMB16_S9\n");
   fprintf(out,"         generic map (\n");
   for(i=0 ; i<16; i++)
         fprintf(out,"        INIT_0%X => X\"%s\",\n", i, ram1[i]);
   for(i=16 ; i<63; i++)
         fprintf(out,"        INIT_%X => X\"%s\",\n", i, ram1[i]);
   fprintf(out,"        INIT_%X => X\"%s\")\n", i, ram1[i]);
   fprintf(out,"  port map (\n");
   fprintf(out,"         CLK     => clock,\n");
   fprintf(out,"         ADDR    => address,\n");
   fprintf(out,"         EN      => '1',\n");
   fprintf(out,"         WE      => we3,\n");
   fprintf(out,"         DI      => data_in(15 downto 8),\n");
   fprintf(out,"         DIP     => \"0\",\n");
   fprintf(out,"         DO      => data_out(15 downto 8),\n");
   fprintf(out,"         SSR     => '0'\n");
   fprintf(out,"         );\n");



   fprintf(out,"\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"   -- bytes 7 a 0\n");
   fprintf(out,"   ----------------------------------------------------------------------------------\n");
   fprintf(out,"    mem_0 : RAMB16_S9\n");
   fprintf(out,"         generic map (\n");
   for(i=0 ; i<16; i++)
         fprintf(out,"        INIT_0%X => X\"%s\",\n", i, ram0[i]);
   for(i=16 ; i<63; i++)
         fprintf(out,"        INIT_%X => X\"%s\",\n", i, ram0[i]);
   fprintf(out,"        INIT_%X => X\"%s\")\n", i, ram0[i]);
   fprintf(out,"  port map (\n");
   fprintf(out,"         CLK     => clock,\n");
   fprintf(out,"         ADDR    => address,\n");
   fprintf(out,"         EN      => '1',\n");
   fprintf(out,"         WE      => we3,\n");
   fprintf(out,"         DI      => data_in(7 downto 0),\n");
   fprintf(out,"         DIP     => \"0\",\n");
   fprintf(out,"         DO      => data_out(7 downto 0),\n");
   fprintf(out,"         SSR     => '0'\n");
   fprintf(out,"         );\n");

   fprintf(out,"\n");
   fprintf(out,"end a1;\n");

   fclose(out);

   return(1);

}
