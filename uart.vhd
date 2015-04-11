--------------------------------------------------------------------------------
--
-- File: UART
-- Author: Rob Baummer
--
-- Description: A 8x oversampling UART operating from 9600 to 57600 baud.  Uses
-- 1 start bit, 1 stop bit and no parity.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		

library work;

entity uart is
	generic (
		--Frequency of System clock in Hz
		clock_frequency : integer);
	port (
		--System interface
		reset : in std_logic;
		sys_clk : in std_logic;
		
		--UART serial interface
		DIN : in std_logic;
		DOUT : out std_logic;
		
		--Processor interface
		proc_clk : in std_logic;
		--Receive
		read : in std_logic;
		valid : out std_logic;
		rx_data : out std_logic_vector(7 downto 0);
		empty : out std_logic;
		--Transmit
		write : in std_logic;
		tx_data : in std_logic_vector(7 downto 0);
		full : out std_logic
	);
end uart;

architecture behavorial of uart is
	signal baud_rate_sel : std_logic_vector(2 downto 0);
	signal baud_enable : std_logic;
	
begin
	--Baud Rate Generator
	br_gen : entity work.baud_clock_gen 
		generic map (
			clock_frequency => clock_frequency)
		port map (
			reset => reset,
			sys_clk => sys_clk,
			--baud rate selection
			--000 - 57.6k
			--001 - 38.4k
			--010 - 19.2k
			--011 - 14.4k
			--100 -  9.6k
			baud_rate_sel => baud_rate_sel,
			--baud enable
			baud_enable => baud_enable);

end behavorial;
	
