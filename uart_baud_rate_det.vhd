--------------------------------------------------------------------------------
--
-- File: UART Baud Rate Detection
-- Author: Rob Baummer
--
-- Description: Uses known information about transmitted byte to automatically
-- determine the baud rate.  Return Char 0x0D must be transmitted for auto rate
-- detection to work.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		

library work;

entity uart_baud_rate_det is
	port (
		--System Interface
		reset : in std_logic;
		sys_clk : in std_logic;
		baud_rate_override : in std_logic_vector(2 downto 0);
		baud_rate_write : in std_logic;
		
		--Baud detection interface
		rx_byte : in std_logic_vector(7 downto 0);
		rx_valid : in std_logic;
		rx_frame_error : in std_logic;
		baud_rate_sel : out std_logic_vector(2 downto 0);
		baud_locked : out std_logic;
		baud_unlocked : out std_logic
	);
end uart_baud_rate_det;

architecture behavorial of uart_baud_rate_det is
	type statetype is (idle, detect, locked, unlocked);
	signal cs, ns : statetype;
	signal cnt : std_logic_vector(1 downto 0);	 
	signal cnt_en : std_logic;
	signal cnt_rst : std_logic;
	signal baud_rate_reg : std_logic_vector(2 downto 0);
	signal reset_baud : std_logic;
	signal test_baud : std_logic;
	signal det_57_6 : std_logic;
	signal det_38_4 : std_logic;
	signal det_19_2 : std_logic;
	signal det_14_4 : std_logic;
	signal det_09_6 : std_logic;
	signal good_detect : std_logic;	  
	signal set_baud : std_logic;
begin
	baud_rate_sel <= baud_rate_reg;

	--sequential process for state machine
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' then
				cs <= idle;
			else
				cs <= ns;
			end if;
		end if;
	end process;
	
	--combinatorial processor for state machine
	process (cs, rx_byte, rx_valid, rx_frame_error, good_detect)
	begin
		--default values for control signals
		reset_baud <= '0';
		test_baud <= '0';
		baud_locked <= '0';
		baud_unlocked <= '0';	  
		set_baud <= '0';
		case cs is
			--wait for valid or invalid rx byte
			when idle =>
				--reset baud rate to default 57.6k
				reset_baud <= '1';
				--depending on transmitter baud the RX byte could have a frame error
				if rx_valid = '1' or rx_frame_error = '1' then
					ns <= detect;
				else
					ns <= idle;
				end if;
			--Receiver defaults to highest baud rate (57.6k)
			--Known transmitted character 0x0D will have different received value 
			--depending on transmitter baud rate
			when detect =>
				--if an expected character is detected
				if good_detect = '1' then
					cnt_en <= '0';
					set_baud <= '1';
					ns <= locked;
				--if not count failure, attempt 3 times before giving up
				else
					cnt_en <= '1';	
					set_baud <= '0';
					if cnt = "11" then
						ns <= unlocked;
					else
						ns <= idle;
					end if;
				end if;		
			--known character detected, save baud rate
			--if 3 frame errors occur in a row reset lock
			when locked =>
				baud_locked <= '1';
				--reset counter on a valid byte
				if rx_valid = '1' then
					cnt_rst <= '1';
				else
					cnt_rst <= '0';
				end if;
				
				--increment frame error counter on frame error
				if rx_frame_error = '1' then
					cnt_en <= '1';
				else
					cnt_en <= '0';
				end if;
				
				--resync baudrate if 3 frame errors in a row have been received
				if cnt = "11" then
					ns <= idle;
				else
					ns <= locked;
				end if;
			--baud rate detection failed
			when unlocked =>
				baud_unlocked <= '1';
				ns <= unlocked;			
			when others =>
				ns <= idle;
		end case;
	end process;
	
	--Counter for attempts at baud rate detection and frame errors during locked
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or cnt_rst = '1' then
				cnt <= "00";
			--increment when commanded
			elsif cnt_en = '1' then
				cnt <= cnt + "01";
			end if;
		end if;
	end process;
	
	--Possible values of TX_Byte = 0x0D when sent at various baud rates
	det_57_6 <= '1' when rx_byte = X"0D" else '0';
	det_38_4 <= '1' when rx_byte = X"E6" else '0';
	det_19_2 <= '1' when rx_byte = X"1C" else '0';
	det_14_4 <= '1' when rx_byte = X"78" else '0';
	det_09_6 <= '1' when rx_byte = X"E0" else '0';
	good_detect <= det_57_6 or det_38_4 or det_19_2 or det_14_4 or det_09_6;
	
	--Baud rate selection register
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if reset = '1' or reset_baud = '1' then
				baud_rate_reg <= "000";
			--Save detected baud rate
			elsif  set_baud = '1' then
				if det_57_6 = '1' then
					baud_rate_reg <= "000";
				elsif det_38_4 = '1' then
					baud_rate_reg <= "001";
				elsif det_19_2 = '1' then
					baud_rate_reg <= "010";
				elsif det_14_4 = '1' then
					baud_rate_reg <= "011";
				elsif det_09_6 = '1' then
					baud_rate_reg <= "100";
				end if;
			--processor override for baud rate
			elsif baud_rate_write = '1' then
				baud_rate_reg <= baud_rate_override;
			end if;
		end if;
	end process;

end behavorial;
