--------------------------------------------------------------------------------
--
-- File: Baud Clock Gen
-- Author: Rob Baummer
--
-- Description: Generates the baud rate tick from 9600 to 57600 baud.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		

library work;

entity baud_clock_gen is
	generic (
		--Frequency of System Clock in Hz
		clock_frequency : integer);
	port (
		reset : in std_logic;
		sys_clk : in std_logic;
		--Baud rate selection
		--000 - 57.6
		--001 - 38.4
		--010 - 19.2
		--011 - 14.4
		--100 -  9.6
		baud_rate_sel : in std_logic_vector(2 downto 0);
		--Baud rate enable
		baud_enable : out std_logic
	);
end baud_clock_gen;

architecture behavorial of baud_clock_gen is
	--Calculate rollover value for 115.2k baud rate using specified clock frequency
	--The baud rates 9.6k to 56.6k are all evenly divisible from 115.2
	constant baud_rollover : integer := integer(real(clock_frequency)/(115200.0*8.0));
	constant counter_size : integer := integer(round(log2(real(baud_rollover))));
	--counter for 115.2k baud rate
	signal fast_baud_counter : std_logic_vector(counter_size-1 downto 0);
	--counter for selectable baud rate
	signal slow_baud_counter : std_logic_vector(3 downto 0);   
	signal slow_baud_rollover : std_logic_vector(3 downto 0);
	
	signal fast_baud_en : std_logic;
	signal slow_baud_en : std_logic;
begin
	--Counter for 115.2 baud rate
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or fast_baud_en = '1' then
				fast_baud_counter <= (others => '0');
			else
				fast_baud_counter <= fast_baud_counter + 1;
			end if;
		end if;
	end process;
	
	--Enable is high at 115.2 KHz rate
	fast_baud_en <= '1' when fast_baud_counter = std_logic_vector(to_unsigned(baud_rollover-1, counter_size)) else '0';
	
	--Counter for selectable baud rate
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or slow_baud_en = '1' then
				slow_baud_counter <= (others => '0');
			elsif fast_baud_en = '1' then
				slow_baud_counter <= slow_baud_counter + 1;
			end if;
		end if;
	end process;
	
	--Enable is high at selectable rate 9.6, 14.4, 19.1, 38.4 or 57.6 KHz
	slow_baud_en <= fast_baud_en when slow_baud_counter = slow_baud_rollover else '0';
	
	process (baud_rate_sel)
	begin
		case baud_rate_sel is
			--57.6 KHz
			when "000" => slow_baud_rollover <= X"1";
			--38.4 KHz
			when "001" => slow_baud_rollover <= X"2";
			--19.2 KHz
			when "010" => slow_baud_rollover <= X"5";
			--14.4 KHz
			when "011" => slow_baud_rollover <= X"7";
			--9.6 KHz
			when "100" => slow_baud_rollover <= X"B";
			--others defaults to 57.6 KHz
			when others => slow_baud_rollover <= X"1";
		end case;
	end process;
	
	--Output Enable for selected Baud rate
	baud_enable <= slow_baud_en;
	
end behavorial;
		


