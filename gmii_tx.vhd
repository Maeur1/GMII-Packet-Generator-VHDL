----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Mayur Panchal
-- 
-- Create Date: 07.05.2016 22:14:27
-- Design Name: 
-- Module Name: gmii_tx - Behavioral
-- Project Name: gigabit_test
-- Target Devices: 
-- Tool Versions: 
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
use IEEE.NUMERIC_STD.ALL;

entity gmii_tx is
    Port ( clk         : in STD_LOGIC;
           phy_ready   : in STD_LOGIC;

           data        : in STD_LOGIC_VECTOR (7 downto 0);
           data_valid  : in STD_LOGIC;
           data_enable : in STD_LOGIC;
           data_error  : in STD_LOGIC;
           
           eth_txck    : out STD_LOGIC;
           eth_txctl   : out STD_LOGIC;
           eth_txd     : out STD_LOGIC_VECTOR (7 downto 0));
end gmii_tx;

architecture Behavioral of gmii_tx is

begin
	 
eth_txck <= clk;

eth_txctl <= data_valid;
	 
process(clk)
begin
	if rising_edge(clk) then
		if data_enable = '1' then
			eth_txd <= data;
		else
			eth_txd <= (others => '0');
		end if;
	end if;
end process;

end Behavioral;
