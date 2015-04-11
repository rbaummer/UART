--------------------------------------------------------------------------------
--
-- File: Synchronizer.vhd
-- Author: Rob Baummer
--
-- Description: Synchronizes I to clock using 2 flip flops
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nbit_synchronizer is	  
	generic (
		N : integer);
	port (
		clk : in std_logic;
		reset : in std_logic;
		I : in std_logic_vector(N-1 downto 0);
		O : out std_logic_vector(N-1 downto 0)
	);
end nbit_synchronizer;

architecture behavioral of nbit_synchronizer is
	signal dff1 : std_logic_vector(N-1 downto 0);
	signal dff2 : std_logic_vector(N-1 downto 0);
begin
	--Dual synchronization registers
	process (clk)
	begin
		if clk = '1' and clk'event then
			if reset = '1' then
				dff1 <= (others => '0');
				dff2 <= (others => '0');
			else
				dff1 <= I;
				dff2 <= dff1;
			end if;
		end if;
	end process;
	
	--Synchronized output
	O <= dff2;
	
end behavioral;
