library ieee;
use ieee.MATH_REAL.all;
use ieee.NUMERIC_STD.all;
use ieee.NUMERIC_STD_UNSIGNED.all;
use ieee.std_logic_1164.all;

library work;
use work.uart_tb_bfm_pkg.all;

entity uart_tb is
end uart_tb;

architecture TB_ARCHITECTURE of uart_tb is

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal reset : STD_LOGIC;
	signal sys0_clk : STD_LOGIC := '0';
	signal sys1_clk : STD_LOGIC := '0';
	signal DIN : STD_LOGIC;
	signal DOUT : STD_LOGIC;

	constant sys_clk_period : time := 20 ns;  
	constant proc_clk_period : time := 8 ns;
	
	signal p0 : p_io := (p_addr => "00",
							p_read => '0',
							p_write => '0',
							p_read_data => X"ZZ",
							p_write_data => X"00");
	signal p1 : p_io := (p_addr => "00",
							p_read => '0',
							p_write => '0',
							p_read_data => X"ZZ",
							p_write_data => X"00");	   

begin

	--UUT_0 will be the transmitter
	UUT_0 : entity work.uart
		generic map (
			clock_frequency => 50000000)
		port map (
			reset => reset,
			sys_clk => sys0_clk,
			DIN => DIN,
			DOUT => DOUT,
			proc_clk => proc_clk,
			proc_addr => p0.p_addr,
			proc_read => p0.p_read,
			proc_write => p0.p_write,
			proc_read_data => p0.p_read_data,
			proc_write_data => p0.p_write_data
		);
		
	--UUT_1 will be the receiver
	UUT_1 : entity work.uart
		generic map (
			clock_frequency => 50000000)
		port map (
			reset => reset,
			sys_clk => sys1_clk,
			--Serial signals referenced respect to UUT_0
			DIN => DOUT,
			DOUT => DIN,
			proc_clk => proc_clk,
			proc_addr => p1.p_addr,
			proc_read => p1.p_read,
			proc_write => p1.p_write,
			proc_read_data => p1.p_read_data,
			proc_write_data => p1.p_write_data
		);
		
	--Generate Processor Clock
	process
	begin
		loop
			proc_clk <= '1';
			wait for proc_clk_period/2;
			proc_clk <= '0';
			wait for proc_clk_period/2;
		end loop;
	end process;
	
	--Generate sys0_clk
	process
	begin
		--add phase offset to clock
		wait for sys_clk_period/3;
		loop
			sys0_clk <= '1';
			wait for sys_clk_period/2;
			sys0_clk <= '0';
			wait for sys_clk_period/2;
		end loop;
	end process;
	
	--Generate sys1_clk
	process
	begin
		--add phase offset to clock
		wait for sys_clk_period/5;
		loop
			sys1_clk <= '1';
			wait for sys_clk_period/2;
			sys1_clk <= '0';
			wait for sys_clk_period/2;
		end loop;
	end process;
		
	--Main process for test bench
	process		  
		variable send_array : byte_array(0 to 3) := (X"01", X"02", X"03", X"f6");	
		variable return_array : byte_array(0 to 3) := (X"00", X"00", X"00", X"00");	 
		variable overflow_array : byte_array(0 to 7) := (X"01", X"02", X"03", X"04", X"05", X"06", X"07", X"08");
		variable return_array2 : byte_array(0 to 7) := ((others => (others => '0')));
		variable byte : std_logic_vector(7 downto 0) := X"00";
	begin
		reset <= '1';
		wait for 100 ns;	   
		reset <= '0';
		
		----------------------------------------------------------------------------
		--Initialize UART transmitter to 57.6k and test auto baud detect on receiver
		----------------------------------------------------------------------------
		report "Testing 57.6k baud" severity note;
		UART_init(576, p0, p1);
		
		--Send a packet
		processor_UART_write(send_array, p0);
		
		--Retreive packet
		processor_UART_read(return_array, p1);
		
		--Compare packets
		assert compare_array(send_array, return_array) report "Data Mismatch" severity failure;
		report "Data Match" severity note;
		
		--Reset receiver UART to test new baud rate
		UART_reset(p0);
		UART_reset(p1);
		
		----------------------------------------------------------------------------
		--Initialize UART transmitter to 38.4k and test auto baud detect on receiver
		----------------------------------------------------------------------------
		report "Testing 38.4k baud" severity note;
		UART_init(384, p0, p1);
		
		--Send a packet
		send_array := (X"BD", X"3F", X"A1", X"07");
		processor_UART_write(send_array, p0);
		
		--Retreive packet
		processor_UART_read(return_array, p1);
		
		--Compare packets
		assert compare_array(send_array, return_array) report "Data Mismatch" severity failure;
		report "Data Match" severity note;
		
		--Reset receiver UART to test new baud rate
		UART_reset(p0);
		UART_reset(p1);
		
		----------------------------------------------------------------------------
		--Initialize UART transmitter to 19.2k and test auto baud detect on receiver
		----------------------------------------------------------------------------
		report "Testing 19.2k baud" severity note;
		UART_init(192, p0, p1);
		
		--Send a packet
		send_array := (X"33", X"7A", X"29", X"52");
		processor_UART_write(send_array, p0);
		
		--Retreive packet
		processor_UART_read(return_array, p1);
		
		--Compare packets
		assert compare_array(send_array, return_array) report "Data Mismatch" severity failure;
		report "Data Match" severity note;
		
		--Reset receiver UART to test new baud rate
		UART_reset(p0);
		UART_reset(p1);
		
		----------------------------------------------------------------------------
		--Initialize UART transmitter to 14.4k and test auto baud detect on receiver
		----------------------------------------------------------------------------
		report "Testing 14.4k baud" severity note;
		UART_init(144, p0, p1);
		
		--Send a packet
		send_array := (X"65", X"FF", X"BC", X"13");
		processor_UART_write(send_array, p0);
		
		--Retreive packet
		processor_UART_read(return_array, p1);
		
		--Compare packets
		assert compare_array(send_array, return_array) report "Data Mismatch" severity failure;
		report "Data Match" severity note;
		
		--Reset receiver UART to test new baud rate
		UART_reset(p0);
		UART_reset(p1);
		
		----------------------------------------------------------------------------
		--Initialize UART transmitter to 9.6k and test auto baud detect on receiver
		----------------------------------------------------------------------------
		report "Testing 9.6k baud" severity note;
		UART_init(96, p0, p1);
		
		--Send a packet
		send_array := (X"66", X"4C", X"3E", X"D1");
		processor_UART_write(send_array, p0);
		
		--Retreive packet
		processor_UART_read(return_array, p1);
		
		--Compare packets
		assert compare_array(send_array, return_array) report "Data Mismatch" severity failure;
		report "Data Match" severity note;
		
		--Reset receiver UART to test new baud rate
		UART_reset(p0);
		UART_reset(p1);
		
		--End of Test																
		report "Tests Complete.  All baud rates verified" severity warning;
		
		----------------------------------------------------------------------------
		--Test Overflow Detection													
		----------------------------------------------------------------------------
		UART_init(576, p0, p1);
		
		--Send a packet, due to mixed clock domains 8 location FIFO will overflow at 8 words	
		send_array := overflow_array(0 to 3);
		processor_UART_write(send_array, p0);
		wait for 2 ms;									 
		--writes split up to avoid overflowing TX fifo
		send_array := overflow_array(4 to 7);
		processor_UART_write(send_array, p0);
		wait for 2 ms;
		
		--check overflow bit set
		processor_read(status_addr, byte, p1);
		assert byte(2) = '1' report "Receiver didn't catch overflow" severity failure;	 
		report "Overflow detected" severity note;
		
		--Retreive packet
		processor_UART_read(return_array2(0 to 6), p1);
		
		assert compare_array(overflow_array(0 to 6), return_array2(0 to 6)) report "Data Mismatch, expected 7 good bytes" severity failure;
		report "Data Match, received 7 good bytes" severity note;
		
		
		--end simulation
		report "Simulation Finished.  All tests passed." severity failure;
		
		
		wait for 1 ms;
	end process;
	

end TB_ARCHITECTURE;

