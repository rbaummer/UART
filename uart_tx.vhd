--------------------------------------------------------------------------------
--
-- File: UART TX
-- Author: Rob Baummer
--
-- Description: A 8x oversampling UART transmitter from 9600 to 57600 baud.  Uses
-- 1 start bit, 1 stop bit and no parity.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		

library work;

entity uart_tx is
	port (
		--System Interface
		reset : in std_logic;
		sys_clk : in std_logic;
		
		--UART serial interface
		DOUT : out std_logic;
		
		--Transmitter interface
		baud_en : in std_logic;
		tx_fifo_empty : in std_logic;
		tx_byte : in std_logic_vector(7 downto 0);
		tx_valid : in std_logic
	);
end uart_tx;

architecture behavorial of uart_tx is
	signal cnt_rst : std_logic;
	signal cnt_en : std_logic;
	signal cnt : std_logic_vector(2 downto 0);
	signal bit_cnt_en : std_logic;
	signal bit_cnt : std_logic_vector(2 downto 0);
	signal data_reg: std_logic_vector(7 downto 0);
	signal send_start : std_logic;
	signal send_stop : std_logic;
	signal tx_fifo_read_i : std_logic;
	signal tx_fifo_read_reg : std_logic;	
	signal shift : std_logic;
	
	type statetype is (idle, start, data, stop);
	signal cs, ns : statetype;
begin
	--Sequential process for RX Statemachine
	--Baud_en is used as an enable to allow state machine to operate at proper 
	--frequency
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				cs <= idle;
			elsif baud_en = '1' then
				cs <= ns;
			end if;
		end if;
	end process;

	--Next State Combinatorial process
	process (cs, cnt, bit_cnt_en)
	begin
		--default values for output signals
		send_start <= '0';
		send_stop <= '0';
		tx_fifo_read_i <= '0';
		cnt_rst <= '0';
		cnt_en <= '0';
		bit_cnt_en <= '0';
		shift <= '0';
		case cs is
			--wait for next byte to transmit
			when idle =>
				cnt_rst <= '1';
				--when the transmit fifo isn't empty
				if tx_fifo_empty = '0' then
					ns <= start;
				else
					ns <= idle;
				end if;
			--send start bit and read transmit byte
			when start =>
				send_start <= '1';
				tx_fifo_read_i <= '1';
				--Using 8x baud counter from receiver so count 8 times
				if cnt = "111" then
					ns <= data;
				else
					ns <= start;
				end if;
			--send data bits
			when data =>
				--Using 8x baud counter from receiver so count 8 times
				if cnt = "111" then
					--shift out next serial bit
					shift <= '1';
					--increment bit counter
					bit_cnt_en <= '1';
					--if 8 bits sent, send stop bit
					if bit_cnt = "111" then
						ns <= stop;
					else
						ns <= data;
					end if;
				else
					shift <= '0';
					bit_cnt_en <= '0';
					ns <= data;
				end if;
			--send stop bit
			when stop =>
				send_stop <= '1';
				--Using 8x baud counter from receiver so count 8 times
				if cnt = "111" then
					ns <= idle;
				else
					ns <= stop;
				end if;			
			when others =>
				ns <= idle;
		end case;
	end process;
	
	--8x oversampling counter
	--oversampling counter is used to determine optimal sampling time of asynchronous DIN
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or cnt_rst = '1' then
				cnt <= "000";
			--baud_en allows counter to operate at proper baud rate
			elsif baud_en = '1' then
				cnt <= cnt + "001";
			end if;
		end if;
	end process;
	
	--bit counter
	--bit counter determines how many bits have been sent
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
	--shift out the tx_byte serially
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				data_reg <= X"00";
			--capture serial bit when commanded
			elsif shift = '1' and baud_en = '1' then
				data_reg <= '0' & data_reg(7 downto 1);
			end if;
		end if;
	end process;
	
	--TX Byte is sent LSB first
	--send_start forces output to 0 for start bit
	--send_stop muxes 1 to output for stop bit
	DOUT <= data_reg(0) and not send_start when send_stop = '0' else '1';
end behavorial;
	
