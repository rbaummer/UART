library ieee;
use ieee.MATH_REAL.all;
use ieee.NUMERIC_STD.all;
use ieee.NUMERIC_STD_UNSIGNED.all;
use ieee.std_logic_1164.all;

	-- Add your library and packages declaration here ...

entity mixed_clock_fifo_srambased_tb is
	-- Generic declarations of the tested unit
		generic(
		N : INTEGER := 16;
		L : INTEGER := 8);
end mixed_clock_fifo_srambased_tb;

architecture TB_ARCHITECTURE of mixed_clock_fifo_srambased_tb is
	-- Component declaration of the tested unit
	component mixed_clock_fifo_srambased
		generic(
		N : INTEGER;
		L : INTEGER );
	port(
		reset : in STD_LOGIC;
		read_clk : in STD_LOGIC;
		read : in STD_LOGIC;
		valid : out STD_LOGIC;
		empty : out STD_LOGIC;
		read_data : out STD_LOGIC_VECTOR(N-1 downto 0);
		write_clk : in STD_LOGIC;
		write : in STD_LOGIC;
		full : out STD_LOGIC;
		write_data : in STD_LOGIC_VECTOR(N-1 downto 0) );
	end component;

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

	-- Add your code here ...
	constant clk1_period : time := 8 ns;  
	constant clk2_period : time := 15 ns;
begin

	-- Unit Under Test port map
	UUT : mixed_clock_fifo_srambased
		generic map (
			N => N,
			L => L
		)

		port map (
			reset => reset,
			read_clk => read_clk,
			read => read,
			valid => valid,
			empty => empty,
			read_data => read_data,
			write_clk => write_clk,
			write => write,
			full => full,
			write_data => write_data
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
		--procedure to write a data word into the FIFO
		procedure put_data(word : in std_logic_vector(15 downto 0)) is
		begin
			wait until write_clk = '1';
			write_data <= word;
			write <= '1';
			wait until write_clk = '1';
			write <= '0';
		end procedure;
	begin
		reset <= '1';
		wait for 40 ns;
		reset <= '0'; 
		
		put_data(X"0001");	  
		put_data(X"0002");
		put_data(X"0003");
		put_data(X"0004");
		put_data(X"0005");
		put_data(X"0006");
		put_data(X"0007"); 
		put_data(X"0008");
		
		
		wait for 1 ms;
	end process;
	
	process			
		--procedure to read a data word from the FIFO
		procedure get_data is
		begin
			wait until read_clk = '1';
			read <= '1';
			wait until read_clk = '1';
			read <= '0';
		end procedure;
	begin
		wait for 300 ns;
		get_data;
		get_data;	
		wait for 16 ns;
		get_data;
		get_data;
		get_data;
		wait for 24 ns;
		get_data;
		get_data;	  
		get_data;
		
		wait for 1 ms;
	end process;

end TB_ARCHITECTURE;

configuration TESTBENCH_FOR_mixed_clock_fifo_srambased of mixed_clock_fifo_srambased_tb is
	for TB_ARCHITECTURE
		for UUT : mixed_clock_fifo_srambased
			use entity work.mixed_clock_fifo_srambased(behavioral);
		end for;
	end for;
end TESTBENCH_FOR_mixed_clock_fifo_srambased;

