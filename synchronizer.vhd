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

entity synchronizer is	  
	port (
		clk : in std_logic;
		reset : in std_logic;
		I : in std_logic;
		O : out std_logic
	);
end synchronizer;

architecture behavioral of synchronizer is
	signal dff1 : std_logic;
	signal dff2 : std_logic;
begin
	--Dual synchronization registers
	process (clk)
	begin
		if clk = '1' and clk'event then
			if reset = '1' then
				dff1 <= '0';
				dff2 <= '0';
			else
				dff1 <= I;
				dff2 <= dff1;
			end if;
		end if;
	end process;
	
	--Synchronized output
	O <= dff2;
	
end behavioral;
