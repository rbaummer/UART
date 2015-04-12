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
		proc_addr : in std_logic_vector(1 downto 0);
		proc_read : in std_logic;
		proc_write : in std_logic;
		proc_read_data : out std_logic_vector(7 downto 0);
		proc_write_data : in std_logic_vector(7 downto 0)
	);
end uart;

architecture behavorial of uart is
	signal baud_enable : std_logic;
	signal DIN_sync : std_logic;
	signal baud_rate_sel : std_logic_vector(2 downto 0);
	signal baud_en : std_logic;
	signal baud_rate_reg : std_logic_vector(2 downto 0);
	signal baud_rate_write : std_logic;
	signal rx_byte : std_logic_vector(7 downto 0);
	signal rx_valid : std_logic;	   
	signal rx_full : std_logic;
	signal rx_frame_error : std_logic;
	signal baud_locked : std_logic;
	signal baud_unlocked : std_logic;
	signal rx_break : std_logic;
	signal proc_rx_empty : std_logic;
	signal proc_valid : std_logic;
	signal proc_rx_read : std_logic;
	signal proc_rx_data : std_logic_vector(7 downto 0);
	signal rx_overflow : std_logic;
	signal tx_read : std_logic;
	signal tx_valid : std_logic;
	signal tx_empty : std_logic;
	signal tx_byte : std_logic_vector(7 downto 0);
	signal proc_tx_full : std_logic;
	signal proc_tx_write : std_logic;
	signal uart_status : std_logic_vector(5 downto 0);
	signal uart_status_sync : std_logic_vector(5 downto 0);
	signal rx_enable_sync : std_logic;
	signal baud_rate_reg_sync : std_logic_vector(2 downto 0);
	signal baud_rate_write_sync : std_logic;
	signal status_cs : std_logic;
	signal control_cs : std_logic;
	signal tx_cs : std_logic;
	signal rx_cs : std_logic;
	signal uart_control : std_logic_vector(4 downto 0);
	signal status_clear : std_logic;
	signal status_clear_sync : std_logic;
	signal proc_reset : std_logic;
	signal proc_reset_sync : std_logic;
	signal uart_reset : std_logic;
begin
	--UART reset, can be reset from global reset or by processor
	uart_reset <= reset or proc_reset_sync;

	--Synchronizer for DIN
	d_sync : entity work.synchronizer
		port map (
			clk => sys_clk,
			reset => reset,
			I => DIN,
			O => DIN_sync);

	--Baud Rate Generator
	br_gen : entity work.baud_clock_gen 
		generic map (
			clock_frequency => clock_frequency)
		port map (
			reset => uart_reset,
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
			
	--Auto-Baud Rate Detection
	--Requires known Byte 0x0D (return) to be transmitted
	auto_br : entity work.uart_baud_rate_det
		port map (
			reset => uart_reset,
			sys_clk => sys_clk,
			--Processor override of auto baud rate detection
			baud_rate_override => baud_rate_reg_sync,
			baud_rate_write => baud_rate_write_sync,
			--baud detection interface
			rx_byte => rx_byte,
			rx_valid => rx_valid,
			rx_frame_error => rx_frame_error,
			baud_rate_sel => baud_rate_sel,
			baud_locked => baud_locked,
			baud_unlocked => baud_unlocked);
			
	----------------------------------------------------------------------------
	--							UART Receiver 								  --
	----------------------------------------------------------------------------
	--UART Receive Controller
	rx : entity work.uart_rx
		port map (
			reset => uart_reset,
			enable => rx_enable_sync,
			sys_clk => sys_clk,
			--UART serial interface
			DIN => DIN_sync,
			--Receiver Interface
			baud_en => baud_enable,
			rx_byte => rx_byte,
			rx_valid => rx_valid,
			rx_frame_error => rx_frame_error,
			rx_break => rx_break);
			
	--Receive FIFO
	rx_fifo : entity mixed_clock_fifo_srambased
		generic map (
			N => 8,
			L => 8)
		port map (
			reset => uart_reset,
			--Read Interface to processor
			read_clk => proc_clk,
			read => proc_rx_read,
			valid => proc_valid,
			empty => proc_rx_empty,
			read_data => proc_rx_data,
			--Write Interface to Receiver
			write_clk => sys_clk,
			write => rx_valid,
			full => rx_full,
			write_data => rx_byte);
			
	--Receiver overflow detection, sticky bit
	--Receive FIFO overflows if it is full and another valid byte arrives at the 
	--receiver
	process (sys_clk)
	begin
		if sys_clk = '1' and sys_clk'event then
			if uart_reset = '1' or status_clear_sync = '1' then
				rx_overflow <= '0';
			else
				rx_overflow <= rx_valid and rx_full;
			end if;
		end if;
	end process;
	
	----------------------------------------------------------------------------
	--							UART Transmitter							  --
	----------------------------------------------------------------------------
	--UART transmitter controller
	tx : entity work.uart_tx
		port map (
			reset => uart_reset,
			sys_clk => sys_clk,
			--UART serial Interface
			DOUT => DOUT,
			--Transmitter interface
			baud_en => baud_enable,
			tx_fifo_empty => tx_empty,
			tx_fifo_read => tx_read,
			tx_byte => tx_byte,
			tx_valid => tx_valid);
			
	--Transmit FIFO
	tx_fifo : entity work.mixed_clock_fifo_srambased
		generic map (
			N => 8,
			L => 8)
		port map (
			reset => uart_reset,
			--Read Interface to Transmitter
			read_clk => sys_clk,
			read => tx_read,
			valid => tx_valid,
			empty => tx_empty,
			read_data => tx_byte,
			--Write Interface to Processor
			write_clk => proc_clk,
			write => proc_tx_write,
			full => proc_tx_full,
			write_data => proc_write_data);
	
	----------------------------------------------------------------------------		
	--			Control and Status Registers for Processor					  --
	----------------------------------------------------------------------------
	--uart status signals on sys_clk domain
	uart_status <= baud_rate_sel & baud_unlocked & baud_locked & rx_overflow;
	
	--status clear on proc_clk domain
	status_clear <= status_cs and proc_read;
	
	--synchronize sys_clk domain status signals to proc_clk domain
	stat_sync : entity work.nbit_synchronizer
		generic map (
			N => 6)
		port map (
			clk => proc_clk,
			reset => reset,
			I => uart_status,
			O => uart_status_sync);
			
	clr_sync : entity work.synchronizer
		port map (
			clk => sys_clk,
			reset => reset,
			I => status_clear,
			O => status_clear_sync);
	
	--FIFO read/write signals
	proc_rx_read <= proc_read and rx_cs;
	proc_tx_write <= proc_write and tx_cs;
	
	--synchronized control signals
	cntrl0_sync : entity work.synchronizer
		port map (
			clk => sys_clk,
			reset => reset,
			I => uart_control(0),
			O => rx_enable_sync);
	
	cntrl31_sync : entity work.nbit_synchronizer
		generic map (
			N => 3)
		port map (
			clk => sys_clk,
			reset => reset,
			I => uart_control(3 downto 1),
			O => baud_rate_reg_sync);
	
	cntrl4_sync : entity work.synchronizer
		port map (
			clk => sys_clk,
			reset => reset,
			I => uart_control(4),
			O => baud_rate_write_sync);
	
	--Processor Read Data and Chip Selects
	process (proc_addr, uart_status_sync, proc_rx_data, uart_control, proc_rx_empty, proc_tx_full)
	begin
		status_cs <= '0';
		control_cs <= '0';
		tx_cs <= '0';
		rx_cs <= '0';					
		proc_read_data <= X"00";
		case proc_addr(1 downto 0) is
			--Status Register
			when "00" => 
				--  7:5		|		4		|	 3		|		2		|	  1		|	0	
				--baud_rate	| baud_unlock	| baud_lock	| rx_overflow	| tx_full	| rx_empty
				proc_read_data <= uart_status_sync & proc_tx_full & proc_rx_empty;
				status_cs <= '1';
			--Control Register
			when "01" =>
				-- 7	|	6:5 	|		4		|	  3:1		|	   0
				-- reset|	00		|	baud_write	|	baud_sel	|	rx_enable
				proc_read_data(4 downto 0) <= uart_control;
				control_cs <= '1';
			--Transmit FIFO
			when "10" =>
				tx_cs <= '1';
			--Receive FIFO
			when "11" =>
				proc_read_data <= proc_rx_data;
				rx_cs <= '1';
			when others =>
				proc_read_data <= X"00";
		end case;
	end process;
	
	--Control Register
	--Control Register
	-- 7:5 	|		4		|	  3:1		|	   0
	-- 000	|	baud_write	|	baud_sel	|	rx_enable
	process (proc_clk)
	begin
		if proc_clk = '1' and proc_clk'event then
			if reset = '1' or proc_reset = '1' then
				uart_control <= (others => '0');
			elsif control_cs = '1' and proc_write = '1' then
				uart_control <= proc_write_data(4 downto 0);
			end if;
		end if;
	end process;
	
	--Writing to bit 7 of control register generates a reset
	proc_reset <= control_cs and proc_write_data(7);
	
	rst_sync : entity work.synchronizer
		port map (
			clk => sys_clk,
			reset => reset,
			I => proc_reset,
			O => proc_reset_sync);
	
			
end behavorial;
	
