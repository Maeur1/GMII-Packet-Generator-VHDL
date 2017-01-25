----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- 
-- Module Name: gigabit_test - Behavioral
-- 
-- Dependencies: Testing how Gigabit ethernet PHY transmits data. 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity gigabit_test is
    Port ( clk100MHz : in    std_logic; -- system clock
           switches  : in    std_logic_vector(3 downto 0);
           
           -- Ethernet Control signals
           eth_rst_b : out   std_logic := '1'; -- reset
           -- Ethernet Management interface
           eth_mdc   : out   std_logic := '0'; 
           eth_mdio  : inout std_logic := '0';
			  eth_int_n : out	  std_logic := '0';
           -- Ethernet Receive interface
           eth_rxck  : in    std_logic; 
           eth_rxctl : in    std_logic;
           eth_rxd   : in    std_logic_vector(7 downto 0);
           -- Ethernet Transmit interface
           eth_txck  : out   std_logic := '0';
           eth_txctl : out   std_logic := '0';
           eth_txd   : out   std_logic_vector(7 downto 0) := (others => '0');
			  eth_txer	: out	  std_logic := '0'
    );
end gigabit_test;

architecture Behavioral of gigabit_test is
    signal max_count          : unsigned(26 downto 0)         := (others => '0');
    signal count              : unsigned(26 downto 0)         := (others => '0');
    signal speed              : STD_LOGIC_VECTOR (1 downto 0) := "11";
    signal adv_data           : STD_LOGIC := '1';
    signal CLK100MHz_buffered : STD_LOGIC := '0';

    signal de_count      : unsigned(6 downto 0)          := (others => '0');
    signal start_sending : std_logic                     := '0';
    signal reset_counter : unsigned(24 downto 0)         := (others => '0');
    signal debug         : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal phy_ready     : std_logic                     := '0';
    signal user_data     : std_logic                     := '0';

    component byte_data is
        Port ( clk             : in STD_LOGIC;
               start           : in  STD_LOGIC;
               busy            : out STD_LOGIC;
               
               advance         : in  STD_LOGIC;               
               
               data            : out STD_LOGIC_VECTOR (7 downto 0);
               data_user       : out STD_LOGIC;
               data_enable     : out STD_LOGIC;               
               data_valid      : out STD_LOGIC);
    end component;

    signal raw_data        : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal raw_data_user   : std_logic                     := '0';
    signal raw_data_valid  : std_logic                     := '0';
    signal raw_data_enable : std_logic                     := '0';

    component add_crc32 is
        Port ( clk             : in  STD_LOGIC;
        
               data_in         : in  STD_LOGIC_VECTOR (7 downto 0);
               data_valid_in   : in  STD_LOGIC;
               data_enable_in  : in  STD_LOGIC;
               
               data_out        : out STD_LOGIC_VECTOR (7 downto 0);
               data_valid_out  : out STD_LOGIC;
               data_enable_out : out STD_LOGIC);
    end component;

    signal with_crc        : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal with_crc_valid  : std_logic                     := '0';
    signal with_crc_enable : std_logic                     := '0';
    
    component add_preamble is
        Port ( clk             : in  STD_LOGIC;

               data_in         : in  STD_LOGIC_VECTOR (7 downto 0);
               data_valid_in   : in  STD_LOGIC;
               data_enable_in  : in  STD_LOGIC;
               
               data_out        : out STD_LOGIC_VECTOR (7 downto 0);
               data_valid_out  : out STD_LOGIC;
               data_enable_out : out STD_LOGIC);
    end component;

    signal fully_framed        : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal fully_framed_valid  : std_logic                     := '0';
    signal fully_framed_enable : std_logic                     := '0';
    signal fully_framed_err    : std_logic                     := '0';

    component gmii_tx is
    Port ( clk         : in STD_LOGIC;
           phy_ready   : in STD_LOGIC;

           data        : in  STD_LOGIC_VECTOR (7 downto 0);
           data_valid  : in  STD_LOGIC;
           data_enable : in  STD_LOGIC;
           data_error  : in  STD_LOGIC;

           eth_txck    : out STD_LOGIC;
           eth_txctl   : out STD_LOGIC;
           eth_txd     : out STD_LOGIC_VECTOR (7 downto 0));
    end component;
    
    signal rx_fully_framed        : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal rx_fully_framed_valid  : std_logic                     := '0';
    signal rx_fully_framed_enable : std_logic                     := '0';
    signal rx_fully_framed_err    : std_logic                     := '0';

    component gmii_rx is
    Port ( rx_clk           : in  STD_LOGIC;
           rx_ctl           : in  STD_LOGIC;
           rx_data          : in  STD_LOGIC_VECTOR (7 downto 0);
           data             : out STD_LOGIC_VECTOR (7 downto 0);
           data_valid       : out STD_LOGIC;
           data_enable      : out STD_LOGIC;
           data_error       : out STD_LOGIC);
    end component;
	 COMPONENT PLL_CLOCKS is
	 PORT(
		CLKIN1_IN : IN std_logic;
		RST_IN : IN std_logic;          
		CLKOUT0_OUT : OUT std_logic;
		CLKOUT1_OUT : OUT std_logic;
		LOCKED_OUT : OUT std_logic
		);
	 END COMPONENT;
	 
	 signal tx_ctl_int : std_logic;

    --------------------------------
    -- Clocking signals 
    -------------------------------- 
    signal clk125MHz   : std_logic;
	 signal clk25MHz   : std_logic;
begin
   ---------------------------------------------------
   -- Strapping signals
   ----------------------------------------------------
   -- No pullups/pulldowns added
	eth_mdc <= '0';
	eth_txer <= '0';
	eth_int_n <= '0';
	speed <= "11";
	eth_rst_b <= '1';
 
   ----------------------------------------------------
   -- Data for the packet packet 
   ----------------------------------------------------
data: byte_data port map ( 
      clk        => clk125MHz,
      start       => start_sending,
      advance     => adv_data,
      busy        => open,
      data        => raw_data,
      data_user   => raw_data_user,
      data_enable => raw_data_enable,
      Data_valid  => raw_data_valid);

i_add_crc32: add_crc32 port map (
      clk             => clk125MHz,
      data_in         => raw_data,
      data_valid_in   => raw_data_valid,
      data_enable_in  => raw_data_enable,
      data_out        => with_crc,
      data_valid_out  => with_crc_valid,
      data_enable_out => with_crc_enable);

i_add_preamble: add_preamble port map (
      clk             => clk125MHz,
      data_in         => with_crc,
      data_valid_in   => with_crc_valid,
      data_enable_in  => with_crc_enable,
      data_out        => fully_framed,
      data_valid_out  => fully_framed_valid,
      data_enable_out => fully_framed_enable);

i_gmii_tx:    gmii_tx port map (
      clk         => clk125MHz,
      phy_ready   => '1', --phy_ready,

      data        => fully_framed,
      data_valid  => fully_framed_valid,
      data_enable => fully_framed_enable,
      data_error  => '0',

      eth_txck    => eth_txck, 
      eth_txctl   => eth_txctl,
      eth_txd     => eth_txd);

    ----------------------------------------
    -- Control reseting the PHY
    ----------------------------------------
control_reset: process(clk125MHz)
    begin
       if rising_edge(clk125MHz) then           
          if reset_counter(reset_counter'high) = '0' then
              reset_counter <= reset_counter + 1;
          end if; 
          phy_ready  <= reset_counter(reset_counter'high);
       end if;
    end process;
----------------------------------------------------------------------
-- The receive path
----------------------------------------------------------------------
i_gmii_rx: gmii_rx port map (
       rx_clk           => eth_rxck,
       rx_ctl           => eth_rxctl,
       rx_data          => eth_rxd,
       data             => rx_fully_framed,
       data_valid       => rx_fully_framed_valid,
       data_enable      => rx_fully_framed_enable,
       data_error       => rx_fully_framed_err);
       


CLK100MHz_buffered <= CLK100MHz;
   -------------------------------------------------------
   -- Generate a 25MHz and 50Mhz clocks from the 100MHz 
   -- system clock 
   ------------------------------------------------------- 
	
clocking: PLL_CLOCKS PORT MAP(
		CLKIN1_IN => CLK100MHz_buffered,
		RST_IN => '0',
		CLKOUT0_OUT => CLK125MHz,
		CLKOUT1_OUT => CLK25MHz,
		LOCKED_OUT => open
	);
	


 when_to_send: process(clk125MHz) 
    begin  
        if rising_edge(clk125MHz) then
            case switches(3 downto 0) is
                when "0000" => max_count <= to_unsigned(124_999_999,27);  -- 1 packet per second
                when "0001" => max_count <= to_unsigned( 62_499_999,27);  -- 2 packet per second
                when "0010" => max_count <= to_unsigned( 12_499_999,27);  -- 10 packets per second 
                when "0011" => max_count <= to_unsigned(  6_249_999,27);  -- 20 packet per second
                when "0100" => max_count <= to_unsigned(  2_499_999,27);  -- 50 packets per second 
                when "0101" => max_count <= to_unsigned(  1_249_999,27);  -- 100 packets per second
                when "0110" => max_count <= to_unsigned(    624_999,27);  -- 200 packets per second 
                when "0111" => max_count <= to_unsigned(    249_999,27);  -- 500 packets per second 
                when "1000" => max_count <= to_unsigned(    124_999,27);  -- 1000 packets per second 
                when "1001" => max_count <= to_unsigned(     62_499,27);  -- 2000 packets per second 
                when "1010" => max_count <= to_unsigned(     24_999,27);  -- 5000 packets per second 
                when "1011" => max_count <= to_unsigned(     12_499,27);  -- 10,000 packests per second 
                when "1100" => max_count <= to_unsigned(      6_249,27);  -- 20,000 packets per second
                when "1101" => max_count <= to_unsigned(      2_499,27);  -- 50,000 packets per second 
                when "1110" => max_count <= to_unsigned(      1_249,27);  -- 100,000 packets per second
                when others => max_count <= to_unsigned(          0,27);  -- as fast as possible 152,439 packets
            end case;

            if count = max_count then
                count <= (others => '0');
                start_sending <= '1';
            else
                count <= count + 1;
                start_sending <= '0';
            end if;
        end if;
    end process;

end Behavioral;