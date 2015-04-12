library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

--Test Bench Package for UART 
--Provides procedures for the processor interface of the UART
package uart_tb_bfm_pkg is			  
	--clock signals
	constant proc_clk_period : time := 8 ns;
	signal proc_clk : std_logic := '0';
	
	--Register Addresses
	signal status_addr : std_logic_vector(1 downto 0) := "00";
	signal control_addr : std_logic_vector(1 downto 0) := "01";
	signal tx_addr : std_logic_vector(1 downto 0) := "10";
	signal rx_addr : std_logic_vector(1 downto 0) := "11";	
	
	--byte array for reading/writing
	type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
	--processor interface to uart
	type p_io is record
		p_addr : std_logic_vector(1 downto 0);
		p_read : std_logic;
		p_write : std_logic;
		p_read_data : std_logic_vector(7 downto 0);
		p_write_data : std_logic_vector(7 downto 0);
	end record;
	
	--Procedure for Processor Read
	procedure processor_read (
		signal addr : in std_logic_vector(1 downto 0);
		variable data : out std_logic_vector(7 downto 0);
		signal p : inout p_io);
		
	--Procedure for Processor Write
	procedure processor_write (
		signal addr : in std_logic_vector(1 downto 0);
		variable data : in std_logic_vector(7 downto 0);
		signal p : inout p_io);
		
	--Procedure for reading UART RX Data
	procedure processor_UART_read (
		variable read_data : out byte_array;
		signal p : inout p_io);
		
	--Procedure for writing UART TX Data
	procedure processor_UART_write (
		variable write_data : in byte_array;
		signal p : inout p_io);
		
	--Initialize the UART simulation
	--Set TX UART baud rate
	--Enable RX UART
	procedure UART_init (
		constant baud_rate : in integer;
		signal p0 : inout p_io;
		signal p1 : inout p_io);
	
	--Reset the UART via the processor	
	procedure UART_reset (
		signal p : inout p_io);
	
	--Compare the two input arrays and return true if they match
	function compare_array (
		array1 : byte_array;
		array2 : byte_array) return boolean;
end uart_tb_bfm_pkg;

package body uart_tb_bfm_pkg is
	--Procedure for Processor Read
	procedure processor_read (
		signal addr : in std_logic_vector(1 downto 0);
		variable data : out std_logic_vector(7 downto 0);
		signal p : inout p_io) is
	begin
		wait until proc_clk = '0';
		p.p_addr <= addr;
		p.p_read <= '1';
		wait until proc_clk = '0';
		p.p_read <= '0';
		data := p.p_read_data;
	end procedure;
	
	--Procedure for Processor Write
	procedure processor_write (
		signal addr : in std_logic_vector(1 downto 0);
		variable data : in std_logic_vector(7 downto 0);
		signal p : inout p_io) is
	begin
		wait until proc_clk = '0';
		p.p_addr <= addr;
		p.p_write <= '1';
		p.p_write_data <= data;
		wait until proc_clk = '0';
		p.p_write <= '0';
	end procedure;
	
	--Procedure for reading UART RX Data
	procedure processor_UART_read (
		variable read_data : out byte_array;
		signal p : inout p_io) is
		
		variable read_byte : std_logic_vector(7 downto 0);
		variable rx_empty : std_logic := '1';
	begin
		for i in 0 to read_data'length-1 loop
			--check RX status
			processor_read(status_addr, read_byte, p);
			rx_empty := read_byte(0);
			--Poll status register until UART RX data is ready
			while rx_empty = '1' loop
				wait for 100 us;
				--read status register
				processor_read(status_addr, read_byte, p);
				rx_empty := read_byte(0);
			end loop;
			
			--Read RX data
			processor_read(rx_addr, read_byte, p);
			--Save RX data
			read_data(i) := read_byte;
		end loop;
	end procedure;
	
	--Procedure for writing UART TX Data
	procedure processor_UART_write (
		variable write_data : in byte_array;
		signal p : inout p_io) is
		
		variable tx_full : std_logic := '0';
		variable read_byte : std_logic_vector(7 downto 0);
	begin
		for i in 0 to write_data'length-1 loop
			--Check TX full
			processor_read(status_addr, read_byte, p);
			tx_full := read_byte(1);
			--Poll Status register if TX FIFO full is high
			while tx_full = '1' loop
				--read status register
				processor_read(status_addr, read_byte, p);
				tx_full := read_byte(1);
				if tx_full = '1' then
					wait for 1 us;
				end if;
			end loop;
			
			--write next byte over UART
			processor_write(tx_addr, write_data(i), p);
		end loop;
	end procedure;
	
	--Initialize the UART simulation
	--Set TX UART baud rate
	--Enable RX UART
	procedure UART_init (
		constant baud_rate : in integer;
		signal p0 : inout p_io;
		signal p1 : inout p_io) is
		
		variable baud : std_logic_vector(2 downto 0) := "000";
		variable delay : time;
		variable byte : std_logic_vector(7 downto 0) := X"00";
		variable rx_empty : std_logic := '1';					 
		variable sync_pattern : byte_array(0 to 1);
	begin
		--Select the baud rate
		case baud_rate is
			when 576 => 
				baud := "000";
				delay := 700 us;
			when 384 => 
				baud := "001";
				delay := 1400 us;
			when 192 => 
				baud := "010";
				delay := 2100 us;
			when 144 => 
				baud := "011";
				delay := 2800 us;
			when 96 => 
				baud := "100";
				delay := 4200 us;
			when others => 
				baud := "000";
				delay := 700 us;
		end case;
		
		--TX UART Setup for processor 0
		byte(4) := '1';				--baud_write
		byte(3 downto 1) := baud;	--baud_rate
		processor_write(control_addr, byte, p0);  
		
		--RX UART Setup for processor 1	
		byte := X"01";
		processor_write(control_addr, byte, p1);
		
		--Send sync symbols (0x0D) for processor 0	   
		sync_pattern := (X"0D", X"0D");
		processor_UART_write(sync_pattern, p0);
		--pause to allow receiver to resync to valid start bit
		wait for delay;
		sync_pattern := (X"0D", X"0D");
		processor_UART_write(sync_pattern, p0);
		
		--wait for sending sync pattern
		wait for delay/2;
		
		--test rx sync on processor 1
		processor_read(status_addr, byte, p1);
		if byte(7 downto 5) = baud and byte(3) = '1' then
			report "UART RX Synced" severity note;
		else
			report "UART RX Failed to Sync" severity failure;
		end if;
		
		--Read sync symbols
		processor_read(status_addr, byte, p1);
		rx_empty := byte(0);
		while rx_empty = '0' loop
			--read sync character
			processor_read(rx_addr, byte, p1);
			--read status byte
			processor_read(status_addr, byte, p1);
			rx_empty := byte(0);
		end loop;
		report "UART INIT Finished" severity note;		
	end procedure;
	
	--Reset UART via the processor
	procedure UART_reset (
		signal p : inout p_io) is	  
	
		variable byte : std_logic_vector(7 downto 0);
	begin											 
		byte := X"80";
		processor_write(control_addr, byte, p);
	end procedure;
	
	--Compare Array contents, return true if they match else false
	function compare_array (
		array1 : byte_array;
		array2 : byte_array) return boolean is
	begin
		--Check array sizes match
		if array1'length /= array2'length then
			return false;
		end if;
		--Check array data
		for i in 0 to array1'length-1 loop
			if array1(i) /= array2(i) then
				return false;
			end if;
		end loop;
		
		return true;
	end function;
end uart_tb_bfm_pkg;
