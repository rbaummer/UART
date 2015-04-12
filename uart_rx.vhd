--------------------------------------------------------------------------------
--
-- File: UART RX
-- Author: Rob Baummer
--
-- Description: A 8x oversampling UART receiver from 9600 to 57600 baud.  Uses
-- 1 start bit, 1 stop bit and no parity.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		

library work;

entity uart_rx is
	port (
		--System Interface
		reset : in std_logic;
		enable : in std_logic;
		sys_clk : in std_logic;
		
		--UART serial interface
		DIN : in std_logic;
		
		--Receiver interface
		baud_en : in std_logic;
		rx_byte : out std_logic_vector(7 downto 0);
		rx_valid : out std_logic;
		rx_frame_error : out std_logic;
		rx_break : out std_logic
	);
end uart_rx;

architecture behavorial of uart_rx is
	signal cnt_rst : std_logic;
	signal cnt_en : std_logic;
	signal cnt : std_logic_vector(2 downto 0);
	signal bit_cnt_en : std_logic;
	signal bit_cnt : std_logic_vector(2 downto 0);
	signal data_reg: std_logic_vector(7 downto 0);
	signal frame_error : std_logic;
	signal frame_error_reg : std_logic;
	signal valid : std_logic;  
	signal valid_reg : std_logic;
	signal shift : std_logic;
	
	type statetype is (idle, start, data, stop, frame_err);
	signal cs, ns : statetype;
begin
	--RX Byte
	rx_byte <= data_reg;
	--Edge detection of valid signal
	rx_valid <= valid and not valid_reg;
	--Edge detection of frame error signal
	rx_frame_error <= frame_error and not frame_error_reg;

	--Sequential process for RX Statemachine
	--Baud_en is used as an enable to allow state machine to operate at proper 
	--frequency
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or enable = '0' then
				cs <= idle;
			elsif baud_en = '1' then
				cs <= ns;
			end if;
		end if;
	end process;

	--Next State Combinatorial process
	process (cs, cnt, bit_cnt_en, DIN)
	begin
		--default values for output signals
		cnt_rst <= '0';
		cnt_en <= '0';
		bit_cnt_en <= '0';
		frame_error <= '0';
		valid <= '0';	   
		shift <= '0';
		case cs is
			--wait for DIN = 0 which signals a start bit
			when idle =>
				cnt_rst <= '1';
				if DIN = '0' then
					ns <= start;
				else
					ns <= idle;
				end if;
			--potential start bit found, test at midpoint to verify start
			when start =>
				--test at midpoint of serial symbol
				if cnt = "011" then
					--reset 8x oversampling counter at centerpoint of start bit
					cnt_rst <= '1';
					--if input is a start bit DIN will still equal 0
					if DIN = '0' then
						ns <= data;
					--false start bit, return to idle and wait for valid start
					else
						ns <= idle;
					end if;
				else
					cnt_rst <= '0';
					ns <= start;
				end if;
			--valid start found, start sampling data at midpoint of bits
			when data =>
				--8 counts from center of start bit is the center of a data bit
				if cnt = "111" then
					--shift in next serial bit
					shift <= '1';
					--increment bit counter
					bit_cnt_en <= '1';
					--if 8 bits captured start looking for stop bit
					if bit_cnt = "111" then
						ns <= stop;
					else
						ns <= data;
					end if;
				--wait for center of data bit
				else
					shift <= '0';
					bit_cnt_en <= '0';
					ns <= data;
				end if;
			--check for valid stop bit
			when stop =>
				--sample DIN at center of stop bit
				if cnt = "111" then
					--valid stop bit if DIN = '1'
					if DIN = '1' then
						valid <= '1';
						--returning to idle allows resyncing of start bit
						ns <= idle;
					--generate frame error is stop bit is invalid
					else
						valid <= '0';
						ns <= frame_err;
					end if;
				--wait for center of stop bit
				else
					valid <= '0';
					ns <= stop;
				end if;		
			--invalid stop bit found, generate frame_error
			when frame_err =>
				frame_error <= '1';
				ns <= idle;			
			when others =>
				ns <= idle;
		end case;
	end process;
	
	--8x oversampling counter
	--oversampling counter is used to determine optimal sampling time of asynchronous DIN
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or (cnt_rst = '1' and baud_en = '1') then
				cnt <= "000";
			--baud_en allows counter to operate at proper baud rate
			elsif baud_en = '1' then
				cnt <= cnt + "001";
			end if;
		end if;
	end process;
	
	--bit counter
	--bit counter determines how many bits have been received
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				bit_cnt <= "000";
			--baud_en allows counter to operate at proper baud rate
			elsif baud_en = '1' and bit_cnt_en = '1' then
				bit_cnt <= bit_cnt + "001";				
			end if;
		end if;
	end process;
	
	--shift register
	--collect the serial bits as they are received
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				data_reg <= X"00";
			--capture serial bit when commanded
			elsif shift = '1' and baud_en = '1' then
				data_reg <= DIN & data_reg(7 downto 1);
			end if;
		end if;
	end process;
	
	--break detection
	rx_break <= '1' when data_reg = X"00" and frame_error = '1' else '0';
	
	--Edge detection registers
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				valid_reg <= '0';
				frame_error_reg <= '0';
			else
				valid_reg <= valid;
				frame_error_reg <= frame_error;
			end if;
		end if;
	end process;
end behavorial;
	
