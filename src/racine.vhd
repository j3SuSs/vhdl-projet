LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.all;

-------------------------------------------------------------------------------
-- Ce module fait la racine entiere d'un nombre de 24 bits non signes.
-- Ses E/S sont les busin et busout.
--
-- Input:
--   busin_data(23 DOWNTO  0) : nombre
--   busin_addr               : 00001
--
-- Output:
--   busout_data(11 DOWNTO  0)  : racine inferieur
--   busout_data(23 DOWNTO  12) : racine superieur

--   busout_status(26 DOWNTO 24) : status
--   busout_address(31 DOWNTO 27)  : adresse
-------------------------------------------------------------------------------


ENTITY racine IS
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
END racine;


ARCHITECTURE Montage OF racine IS
    TYPE T_CMD_R IS (NOOP, LOAD);
    
    TYPE T_CMD_OP IS (INIT, NOOP);
    SIGNAL CMD_OP : T_CMD_OP; 
    SIGNAL op:  STD_LOGIC_VECTOR (23 DOWNTO 0);

    -- l'adresse et le status
    SIGNAL CMD_Addr   :  T_CMD_R; 
    SIGNAL CMD_Status :  T_CMD_R; 
    SIGNAL R_Addr     :  STD_LOGIC_VECTOR (4 DOWNTO 0);
    SIGNAL R_Status   :  STD_LOGIC_VECTOR ( 2 DOWNTO 0);

    -- le resulat 
    SIGNAL racine_sup, racine_inf:  STD_LOGIC_VECTOR (11 DOWNTO 0);

    TYPE T_CMD_res IS (INIT, NOOP);
    SIGNAL CMD_res : T_CMD_res;
    SIGNAL res : UNSIGNED (23 DOWNTO 0);

    -- les bus in & out
    SIGNAL busin_addr   : STD_LOGIC_VECTOR( 4 DOWNTO 0);
    SIGNAL busin_status : STD_LOGIC_VECTOR( 2 DOWNTO 0);
    SIGNAL busin_data   : STD_LOGIC_VECTOR(23 DOWNTO 0);
    SIGNAL busout_addr  : STD_LOGIC_VECTOR( 4 DOWNTO 0);
    SIGNAL busout_status: STD_LOGIC_VECTOR( 2 DOWNTO 0);
    SIGNAL busout_data  : STD_LOGIC_VECTOR(23 DOWNTO 0);

    --Description des �tats
    TYPE STATE_TYPE IS (
        ST_READ, -- lire la donnee
        ST_WRITE_COPY, --passer data au suivant (adresse ne me concerne pas)
        ST_WRITE_RES, -- ecrire le r�sultat
        MLOOP
    );
    SIGNAL state : STATE_TYPE;
    
BEGIN

-------------------------------------------------------------------------------
--  Partie Opérative
-------------------------------------------------------------------------------
    racine_inf <= std_logic_vector(res)(11 DOWNTO 0);
    racine_sup <= std_logic_vector(res+1)(11 DOWNTO 0);

    busin_addr          <= busin(31 DOWNTO 27) ;
    busin_status        <= busin(26 DOWNTO 24) ;
    busin_data          <= busin(23 DOWNTO  0) ;
    busout(31 DOWNTO 27) <= busout_addr  ;
    busout(26 DOWNTO 24) <= busout_status;
    busout(23 DOWNTO  0) <= busout_data  ;
    
    PROCESS (clk)
    BEGIN IF clk'EVENT AND clk = '1' THEN
        -- registre res : INIT, SHIFT_RIGHT, ADD_ONE, NOOP
        res <= "000000000000000000000000";
    END IF; END PROCESS;
    
    busout_addr      <= R_Addr;
    busout_status(2) <= R_status(2) when state=ST_WRITE_COPY else '1';
    --TODO busout_status(1) <= R_status(1) when state=ST_WRITE_COPY else ov_tmp;
    --TODO busout_status(0) <= R_status(0) when state=ST_WRITE_COPY else z_tmp;
    busout_data(23 DOWNTO 12) <= busout_data(23 DOWNTO 12) when state=ST_WRITE_COPY else racine_sup;
    busout_data(11 DOWNTO  0) <= busout_data(11 DOWNTO  0) when state=ST_WRITE_COPY else racine_inf;

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
                  IF busin_valid  = '1' and busin_addr = "00100" THEN
                      state <= MLOOP;
                  ELSIF busin_valid  = '1' and busin_addr /= "00100" THEN
                      state <= ST_WRITE_COPY;
                  END IF; 

              WHEN MLOOP =>
                  state <= ST_WRITE_RES;

              WHEN ST_WRITE_RES =>
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
        '1'     WHEN   ST_WRITE_RES,
        '0'     WHEN   OTHERS; 

    WITH state  SELECT CMD_Addr <=
         LOAD   WHEN   ST_READ,
         NOOP   WHEN   OTHERS; 

    WITH state  SELECT CMD_Status <=
         LOAD   WHEN   ST_READ,
         NOOP   WHEN   OTHERS; 
			
    WITH state  SELECT CMD_res <= -- INIT, SHIFT_RIGHT, ADD_ONE, NOOP
        INIT   WHEN   ST_READ,
        NOOP   WHEN   OTHERS; 

END Montage;

