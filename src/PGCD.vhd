LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.all;

-------------------------------------------------------------------------------
-- Ce module determine le PGCD d'un nombre 2 nombres de 24 bits signes.
-- Ses E/S sont les busin et busout.
-- Il doit attandre (A) le premier 24 bits pour le premier operand et apres (B) le deuxieme
--
-- Input:
--   busin_data(23 DOWNTO  0) : operande 1 ou 2
--   busin_addr               : 00011
--
-- Output:
--   busout_data(23 DOWNTO  0)  : resulat
--   busout_status(25)          : V (overflow)
-------------------------------------------------------------------------------

ENTITY PGCD IS
    PORT(
        clk          : IN  STD_LOGIC;
        -- interface busin
        busin        : in  STD_LOGIC_VECTOR(31 DOWNTO 0);
        busin_valid  : in  STD_LOGIC;
        busin_eated  : out STD_LOGIC; 
        -- interface busout
        busout       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        busout_valid : OUT STD_LOGIC;
        busout_eated : IN  STD_LOGIC);
END PGCD;


ARCHITECTURE Montage OF PGCD IS
    TYPE T_CMD_R IS (NOOP, LOAD, LOAD_B, COMPUTE);


    -- les operandes A et B
    -- on les etend sur 24 bits
    SIGNAL CMD_AB :  T_CMD_R ; 
    SIGNAL R_INPUT,R_A,R_B:  STD_LOGIC_VECTOR (23 DOWNTO 0);

    -- l'adresse et le status
    SIGNAL CMD_Addr   :  T_CMD_R ; 
    SIGNAL CMD_Status :  T_CMD_R ; 
    SIGNAL R_Addr     :  STD_LOGIC_VECTOR ( 4 DOWNTO 0);
    SIGNAL R_Status   :  STD_LOGIC_VECTOR ( 2 DOWNTO 0);

    -- le resulat 
    SIGNAL CMD_Res :  T_CMD_R ; 
    SIGNAL R_Res   :  STD_LOGIC_VECTOR (23 DOWNTO 0);

	 -- calcul pgcd
    TYPE T_CMD_COMPUTE IS (NOOP, INIT, SWAP_AB, DECR_B_FROM_A);
    SIGNAL CMD_COMPUTE: T_CMD_COMPUTE;
	 
    -- signaux intermediaires
    SIGNAL a_tmp   : SIGNED (23 DOWNTO 0);
    SIGNAL b_tmp   : SIGNED (23 DOWNTO 0);
    SIGNAL c_tmp   : SIGNED (23 DOWNTO 0);
	 SIGNAL diff_a_b   : SIGNED (23 DOWNTO 0);
    -- SIGNAL p_tmp   : SIGNED (25 DOWNTO 0); -- for mult
    SIGNAL z_tmp   : STD_LOGIC;
	 SIGNAL b_tmp_is_zero:  STD_LOGIC;
	 SIGNAL b_tmp_bigger_than_a:  STD_LOGIC;
    -- les bus in & out
    SIGNAL busin_addr   : STD_LOGIC_VECTOR( 4 DOWNTO 0);
    SIGNAL busin_status : STD_LOGIC_VECTOR( 2 DOWNTO 0);
    SIGNAL busin_data   : STD_LOGIC_VECTOR(23 DOWNTO 0);
    SIGNAL busout_addr  : STD_LOGIC_VECTOR( 4 DOWNTO 0);
    SIGNAL busout_status: STD_LOGIC_VECTOR( 2 DOWNTO 0);
    SIGNAL busout_data  : STD_LOGIC_VECTOR(23 DOWNTO 0);

    --Description des états
    TYPE STATE_TYPE IS (ST_READ,
                        ST_READ_B, 
		ST_COMPUTE,  -- the loop for compute
		ST_SWAP_AB, -- swap AB
		ST_DECR_B_FROM_A,
		ST_WRITE_COPY, ST_WRITE_PGCD );
    SIGNAL state : STATE_TYPE;
    
BEGIN
			-- DECR_B_FROM_A WHEN ST_DECR_B_FROM_A

-------------------------------------------------------------------------------
--  Partie Opérative
-------------------------------------------------------------------------------
    busin_addr          <= busin(31 DOWNTO 27) ;
    busin_status        <= busin(26 DOWNTO 24) ;
    busin_data          <= busin(23 DOWNTO  0) ;
    busout(31 DOWNTO 27) <= busout_addr  ;
    busout(26 DOWNTO 24) <= busout_status;
    busout(23 DOWNTO  0) <= busout_data  ;

	 -- if (b==0) goto ST_WRITE;
	 b_tmp_is_zero <= '1' WHEN b_tmp = 0 ELSE '0';
	 -- if (b>a) swap(a,b)
	 b_tmp_bigger_than_a <= '1' WHEN b_tmp > a_tmp ELSE '0';
	 diff_a_b = tmp_a - tmp_b;
	 
	 c_tmp <= a_tmp;
	 
    PROCESS (clk)
    BEGIN IF clk'EVENT AND clk = '1' THEN
        -- R_Aaddr
        if    ( CMD_Addr = LOAD ) then
            R_Addr <= busin_addr;
        end if;
        -- LOAD A 
        if    ( CMD_AB = LOAD ) then
				R_INPUT(23 DOWNTO 0) <= busin_data(23 DOWNTO 0);
				R_A(23 DOWNTO 0) <= busin_data(23 DOWNTO 0);
        end if;
		  -- LOAD B
        if    ( CMD_AB = LOAD_B ) then
				R_INPUT(23 DOWNTO 0) <= busin_data(23 DOWNTO 0);
				R_B(23 DOWNTO 0) <= busin_data(23 DOWNTO 0);
        end if;
		  -- INIT Compute
		  if (CMD_COMPUTE = INIT_COMPUTE) then
				a_tmp <= SIGNED(R_A);
				b_tmp <= SIGNED(R_B);
				c_tmp <= SIGNED(R_A);
		  end if;
		  -- SWAP A et B
		  if ( CMD_COMPUTE = SWAP_AB ) then
				a_tmp <= b_tmp;
				b_tmp <= c_tmp;
		  end if;
		  -- Decrement A from B
		  if ( CMD_COMPUTE = DECR_B_FROM_A ) then
				a_tmp <= a_tmp - b_tmp;
		  end if;
        -- R_Res
        if    ( CMD_Res = LOAD ) then
            R_Res <= std_logic_vector(a_tmp);
        end if;
		  -- 
    END IF; END PROCESS;
    
    busout_addr      <= R_Addr;
    busout_status <= busin_status;
    busout_data(23 DOWNTO 0) <= R_INPUT (11 DOWNTO 1) when state=ST_WRITE_COPY else R_Res ;

-------------------------------------------------------------------------------
-- Partie Controle
-------------------------------------------------------------------------------
-- Inputs:  busin_valid busout_eated
-- Outputs: busin_eated busout_valid, CMD_AB, CMD_Addr, CMD_Status, CMD_Res
-------------------------------------------------------------------------------

    -- fonction de transitition    
    PROCESS (clk)
    BEGIN
      IF clk'EVENT AND clk = '1' THEN
          CASE state IS
              WHEN ST_READ =>
                  IF busin_valid  = '1' and busin_addr = "00011" THEN
                      state <= ST_READ_B;
                  ELSIF busin_valid  = '1' and busin_addr /= "00011" THEN
                      state <= ST_WRITE_COPY;
                  END IF; 
						
              WHEN ST_READ_B =>
                  IF busin_valid  = '1' and busin_addr = "00011" THEN
                      state <= ST_INIT_COMPUTE;
                  ELSIF busin_valid  = '1' and busin_addr /= "00011" THEN
                      state <= ST_WRITE_COPY;
                  END IF; 

				  WHEN ST_COMPUTE =>
						IF b_tmp_is_zero ='1' THEN
							 state <= ST_WRITE_PGCD;
						END IF;
						IF b_tmp_bigger_than_a='1' THEN
							state <= ST_SWAP_AB;
						END IF;
						IF b_tmp_bigger_than_a='0' THEN
							state <= ST_DECR_B_FROM_A;
						END IF;
				  
				  WHEN ST_SWAP_AB =>
						state <= ST_COMPUTE;
					
				  WHEN ST_DECR =>
					   state <= ST_SWAP_AB;

				  WHEN ST_INIT_COMPUTE =>
						state <= ST_COMPUTE;						

						
              WHEN ST_WRITE_PGCD =>
                  IF busout_eated = '1' THEN
                      state  <= ST_READ;
                  END IF; 

              WHEN ST_WRITE_COPY =>
                  IF busout_eated = '1' THEN
                      state  <= ST_READ;
                  END IF; 
          END CASE;
      END IF;
    END PROCESS;

    -- fonction de sortie    
    WITH state  SELECT busin_eated <=
         '1'    WHEN   ST_READ,
         '0'    WHEN   OTHERS; 

    WITH state  SELECT busout_valid <=
        '1'     WHEN   ST_WRITE_COPY,
        '1'     WHEN   ST_WRITE_PGCD,
        '0'     WHEN   OTHERS; 

    WITH state  SELECT CMD_Addr <=
         LOAD   WHEN   ST_READ,
			LOAD   WHEN   ST_READ_B,
         NOOP   WHEN   OTHERS; 

    WITH state  SELECT CMD_Status <=
         LOAD   WHEN   ST_READ,
			LOAD   WHEN   ST_READ_B,
         NOOP   WHEN   OTHERS; 

    WITH state  SELECT CMD_AB <=
         LOAD   WHEN   ST_READ,
			LOAD_B   WHEN   ST_READ_B,
         NOOP   WHEN   OTHERS; 

    WITH state  SELECT CMD_Res <=
         COMPUTE   WHEN   ST_Compute,
         NOOP   WHEN   OTHERS; 
	
    WITH state  SELECT CMD_COMPUTE <=
			INIT_COMPUTE WHEN	ST_INIT_COMPUTE,
         SWAP_AB   WHEN   ST_SWAP_AB,
			DECR_B_FROM_A WHEN ST_DECR_B_FROM_A
         NOOP   WHEN   OTHERS; 
	

END Montage;
