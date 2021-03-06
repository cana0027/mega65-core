----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:30:37 12/10/2013 
-- Design Name: 
-- Module Name:    container - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity container is
  Port ( CLK_IN : STD_LOGIC;         
--         btnCpuReset : in  STD_LOGIC;
--         irq : in  STD_LOGIC;
--         nmi : in  STD_LOGIC;

         fpga_pins : out std_logic_vector(1 to 28) := (others => '1');
         fpga_pins31 : out std_logic_vector(31 to 43) := (others => '1');
         fpga_pins45 : out std_logic_vector(45 to 47) := (others => '1');
         fpga_pins49 : out std_logic_vector(49 to 52) := (others => '1');
         fpga_pins55 : out std_logic_vector(55 to 56) := (others => '1');
         fpga_pins60 : out std_logic_vector(60 to 82) := (others => '1');
         
         wifirx : out std_logic := '1';
         wifitx : out std_logic := '1';
         
         ----------------------------------------------------------------------
         -- VGA output
         ----------------------------------------------------------------------
         vga_vsync : out STD_LOGIC := '1';
         vga_hsync : out  STD_LOGIC := '1';
         vga_red : out  UNSIGNED (3 downto 0) := (others => '1');
         vga_green : out  UNSIGNED (3 downto 0) := (others => '1');
         vga_blue : out  UNSIGNED (3 downto 0) := (others => '1');

         ----------------------------------------------------------------------
         -- HyperRAM as expansion RAM
         ----------------------------------------------------------------------
         hr_d : inout unsigned(7 downto 0) := (others => '1');
         hr_rwds : inout std_logic := '1';
         hr_reset : out std_logic := '1';
         hr_clk_n : out std_logic := '1';
         hr_clk_p : out std_logic := '1';
         hr_cs0 : out std_logic := '1';
         hr_cs1 : out std_logic := '1';
                  
         -------------------------------------------------------------------------
         -- Lines for the SDcard interface itself
         -------------------------------------------------------------------------
         sdReset : out std_logic := '0';  -- must be 0 to power SD controller (cs_bo)
         sdClock : out std_logic := 'Z';       -- (sclk_o)
         sdMOSI : out std_logic := 'Z';      
         sdMISO : in  std_logic;

         ----------------------------------------------------------------------
         -- Flash RAM for holding config
         ----------------------------------------------------------------------
--         QspiSCK : out std_logic := '1';
         QspiDB : inout std_logic_vector(3 downto 0) := (others => 'Z');
         QspiCSn : out std_logic := '1';
         
         ----------------------------------------------------------------------
         -- Analog headphone jack output
         -- (amplifier enable is on an IO expander)
         ----------------------------------------------------------------------
         headphone_left : out std_logic := '1';
         headphone_right : out std_logic := '1';
         
         ----------------------------------------------------------------------
         -- Debug interfaces on TE0725
         ----------------------------------------------------------------------
         led : out std_logic := '1';

         ----------------------------------------------------------------------
         -- UART monitor interface
         ----------------------------------------------------------------------
         monitor_tx : out std_logic := '1';
         monitor_rx : in std_logic
         
         );
end container;

architecture Behavioral of container is

  component fpgatemp is
    Generic ( DELAY_CYCLES : natural := 480 ); -- 10us @ 48 Mhz
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           temp : out  STD_LOGIC_VECTOR (11 downto 0));
  end component;

  signal irq : std_logic := '1';
  signal nmi : std_logic := '1';
  signal restore_key : std_logic := '1';
  signal reset_out : std_logic := '1';
  signal cpu_game : std_logic := '1';
  signal cpu_exrom : std_logic := '1';
  
  signal buffer_vgared : unsigned(7 downto 0);
  signal buffer_vgagreen : unsigned(7 downto 0);
  signal buffer_vgablue : unsigned(7 downto 0);
  
  signal pixelclock : std_logic;
  signal cpuclock : std_logic;
  signal clock240 : std_logic;
  signal clock120 : std_logic;
  signal clock100 : std_logic;
  signal ethclock : std_logic;
  signal clock200 : std_logic;
  
  signal vgaredignore : unsigned(3 downto 0);
  signal vgagreenignore : unsigned(3 downto 0);
  signal vgablueignore : unsigned(3 downto 0);

  signal dummypins : std_logic_vector(1 to 100) := (others => '0');
  
begin

  dotclock1: entity work.dotclock100
    port map ( clk_in1 => CLK_IN,
               clock80 => pixelclock, -- 80MHz
               clock40 => cpuclock, -- 40MHz
               clock50 => ethclock,
               clock200 => clock200,
               clock100 => clock100,
               clock120 => clock120,
               clock240 => clock240
               );

  probe0: entity work.pinprober
    port map (clk => cpuclock,
              pins(1 to 28)  => fpga_pins(1 to 28),
              pins(29 to 30) => dummypins(29 to 30),
              pins(31 to 43)  => fpga_pins31(31 to 43),
              pins(44) => dummypins(44),
              pins(45 to 47)  => fpga_pins45(45 to 47),
              pins(48) => dummypins(48),
              pins(49 to 52)  => fpga_pins49(49 to 52),
              pins(53) => dummypins(53),
              pins(54) => dummypins(54),
              pins(55 to 56)  => fpga_pins55(55 to 56),
              pins(57 to 59) => dummypins(57 to 59),
              pins(60 to 82)  => fpga_pins60(60 to 82),
              pin_number => pin_number
              );
  
  process (cpuclock,clock120,cpuclock,pal50_select)
  begin
    if rising_edge(clock120) then
      -- VGA direct output
      vga_red <= buffer_vgared(7 downto 4);
      vga_green <= buffer_vgagreen(7 downto 4);
      vga_blue <= buffer_vgablue(7 downto 4);

    end if;

  end process;

  

  -- XXX Ethernet should be 250Mbit fibre port on this board  
  -- eth_clock <= cpuclock;
  
end Behavioral;
