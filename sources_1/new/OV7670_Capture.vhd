library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity OV7670_Capture is
    port (
        -- Inputs
        i_Pixel_Clk   :   in  std_logic;
        i_HRef       :   in  std_logic;
        i_Pixel_Data  :   in  std_logic_vector(7  downto 0);
        -- Outputs
        o_En_a        :   out std_logic;        
        o_Adr_a       :   out std_logic_vector(9 downto 0);        
        o_Do          :   out std_logic_vector(11 downto 0)
    );
end OV7670_Capture;

architecture Behavioral of OV7670_Capture is
    
    -- Define the FSM states
    type t_Capture_State is (IDLE, CACHE, WRITE);
    signal State        :   t_Capture_State := IDLE;
    -- Internal signal declarations
    signal Addr         :   std_logic_vector(9 downto 0) := (others => '0');  -- RAM index to store pixel data
    signal Byte_Cache   :   std_logic_vector(11 downto 0) := (others => '0');        -- 1px = 2B, so we need to store the last byte of input 
    -- I/O Buffers
    signal Pixel_Clk    :   std_logic;
    signal HRef         :   std_logic;
    signal Pixel_Data   :   std_logic_vector(7 downto 0);
    signal En_a         :   std_logic := '0';
    
begin
    
    -- Connect IO
    Pixel_Clk   <= i_Pixel_Clk; 
    HRef        <= i_HRef;
    Pixel_Data  <= i_Pixel_Data;
    o_En_a      <= En_a;
    o_Adr_a     <= Addr;        -- Counter 'Addr' keeps count of the RAM address to write to (on PORT A) 
    o_Do        <= Byte_Cache;  -- Byte Cache collects the RGB bits and sends them to output
    
    State_Control: process(Pixel_Clk)
    begin
        if (rising_edge(Pixel_Clk)) then
            
            -- FSM controls the camera capture behaviour
            case State is
                -- State machine is idle when in blanking periods
                when IDLE =>
                    if (HRef = '1') then
                        State <= CACHE;
                    else
                        State <= IDLE;
                    end if;
                    
                -- Receive byte 2 of 2 and write it to memory. If it's the last pixel then go idle, otherwise cache the next byte.
                when CACHE =>
                    if (HRef = '1') then
                        State <= WRITE;
                    else
                        State <= IDLE;
                    end if;
                    
                -- Byte 1 of 2 needs to be cached before writing RGB bits to memory
                when WRITE =>
                    if (HRef = '1') then
                        State <= CACHE;
                    else
                        State <= IDLE;
                    end if;
                    
            end case;
        end if;
    end process;
    
    
    Capture: process(Pixel_Clk)
    begin
        if (rising_edge(Pixel_Clk)) then
            if( i_HRef = '1') then
                case State is
                
                    when IDLE =>
                        En_a    <= '0';
                        
                    when WRITE =>
                        En_a    <= '1';     -- Enable PORT A
                        Byte_Cache(7 downto 0) <= Pixel_Data(7 downto 4) & Pixel_Data(3 downto 0);   -- Load G[3:0] AND B[3:0] into cache
    
                    when CACHE =>
                        Byte_Cache(11 downto 8) <= Pixel_Data(3 downto 0);     -- Save R[3:0] into data cache
                        En_a    <= '0';     -- Disable RAM PORT A
                        if (unsigned(Addr) = 639) then
                            Addr    <= (others => '0');
                        else
                            Addr    <= std_logic_vector(unsigned(Addr) + 1);        -- Increment RAM pointer
                        end if;
                end case;
            end if;
        end if;
                    
    end process;
end Behavioral;