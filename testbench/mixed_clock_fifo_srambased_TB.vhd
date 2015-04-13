library ieee;
use ieee.MATH_REAL.all;
use ieee.NUMERIC_STD.all;
use ieee.NUMERIC_STD_UNSIGNED.all;
use ieee.std_logic_1164.all;

library work;
use work.uart_tb_bfm_pkg.all;

entity mixed_clock_fifo_srambased_tb is
	-- Generic declarations of the tested unit
		generic(
		N : INTEGER := 8;
		L : INTEGER := 8);
end mixed_clock_fifo_srambased_tb;

architecture TB_ARCHITECTURE of mixed_clock_fifo_srambased_tb is

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal reset : STD_LOGIC := '0';
	signal read_clk : STD_LOGIC := '0';
	signal read : STD_LOGIC := '0';
	signal write_clk : STD_LOGIC := '0';
	signal write : STD_LOGIC := '0';
	signal write_data : STD_LOGIC_VECTOR(N-1 downto 0);
	-- Observed signals - signals mapped to the output ports of tested entity
	signal valid : STD_LOGIC;
	signal empty : STD_LOGIC;
	signal read_data : STD_LOGIC_VECTOR(N-1 downto 0);
	signal full : STD_LOGIC;	
	
	--FIFO IO Type
	type fifo_io is record 
		write : std_logic;
		read : std_logic;
		write_data : std_logic_vector(7 downto 0);
		read_data : std_logic_vector(7 downto 0);
		full : std_logic;
		empty : std_logic;
	end record;		
	
	signal f : fifo_io := (write => '0',
							read => '0',
							write_data => X"00",
							read_data => X"ZZ",
							full => 'Z',
							empty => 'Z');
	
	--procedure to write a data word into the FIFO
	procedure put_data(
		variable data : in byte_array;
		signal f : inout fifo_io ) is
	begin	   
		for i in 0 to data'length-1 loop
			wait until write_clk = '0';
			f.write_data <= data(i);
			f.write <= '1';
			wait until write_clk = '1';
			f.write <= '0';			   
		end loop;
	end procedure;	
	
	--procedure to read a data word from the FIFO
	procedure get_data(
		variable data : out byte_array;
		signal f : inout fifo_io ) is
	begin	 
		for i in 0 to data'length-1 loop
			wait until read_clk = '0';
			f.read <= '1';
			wait until read_clk = '0';
			f.read <= '0';			
			data(i) := f.read_data;
		end loop;
	end procedure;

	-- Add your code here ...
	constant clk1_period : time := 8 ns;  
	constant clk2_period : time := 15 ns;
begin

	-- Unit Under Test port map
	UUT : entity work.mixed_clock_fifo_srambased
		generic map (
			N => N,
			L => L
		)

		port map (
			reset => reset,
			read_clk => read_clk,
			read => f.read,
			valid => valid,
			empty => f.empty,
			read_data => f.read_data,
			write_clk => write_clk,
			write => f.write,
			full => f.full,
			write_data => f.write_data
		);

	-- Add your stimulus here ...	
	--Set read clock to 125 MHz
	process
	begin
		clk1: loop
			read_clk <= '1';
			wait for clk1_period/2;
			read_clk <= '0';
			wait for clk1_period/2;
		end loop;
	end process;
	
	--Set write clock to 66 MHz
	process
	begin
		clk2: loop
			write_clk <= '1';
			wait for clk2_period/2;
			write_clk <= '0';
			wait for clk2_period/2;
		end loop;
	end process;	 
	
	process		
		variable write_array : byte_array(0 to 7) := (X"01", X"02", X"03", X"04", X"05", X"06", X"07", X"08");
		variable read_array : byte_array(0 to 7) := (X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00");
	begin
		reset <= '1';
		wait for 40 ns;
		reset <= '0';
		
		--Test 1
		--Full from beginning
		put_data(write_array(0 to 6), f);  						  
		wait for 20 ns;
		assert f.full = '1' report "FIFO should be full" severity failure;
		get_data(read_array(0 to 6), f);	
		assert compare_array(write_array(0 to 6), read_array(0 to 6)) report "Data Mismatch Test 1" severity failure;
		report "Test 1 Pass" severity note;
		
		--Test 2
		--Full from middle
		write_array := (X"71", X"82", X"93", X"a4", X"b5", X"c6", X"e7", X"d8");
		put_data(write_array(0 to 3), f);
		wait for 20 ns;
		get_data(read_array(0 to 3), f);
		wait for 20 ns;
		put_data(write_array(0 to 6), f);
		get_data(read_array(0 to 6), f);
		assert compare_array(write_array(0 to 3), read_array(0 to 3)) report "Data Mismatch Test 2" severity failure;
		report "Test 2 Pass" severity note;
		
		--Test 3
		--Full from end
		write_array := (X"71", X"82", X"93", X"a4", X"b5", X"c6", X"e7", X"d8");
		put_data(write_array(0 to 5), f);
		wait for 20 ns;
		get_data(read_array(0 to 5), f);
		wait for 20 ns;
		put_data(write_array(0 to 6), f);
		get_data(read_array(0 to 6), f);
		assert compare_array(write_array(0 to 6), read_array(0 to 6)) report "Data Mismatch Test 3" severity failure;
		report "Test 3 Pass" severity note;
		
		--Test 4
		--Write past full
		write_array := (X"11", X"22", X"33", X"44", X"55", X"66", X"77", X"88");
		put_data(write_array(0 to 7), f);
		wait for 20 ns;
		get_data(read_array(0 to 6), f);
		assert compare_array(write_array(0 to 6), read_array(0 to 6)) report "Data Mismatch Test 4" severity failure;
		report "Test 4 Pass" severity note;
		
		
		
		report "All Tests Pass" severity failure;
		
		wait for 1 ms;
	end process;

end TB_ARCHITECTURE;

