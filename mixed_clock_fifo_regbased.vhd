--------------------------------------------------------------------------------
--
-- File: Mixed-Clock FIFO - Register Based
-- Author: Rob Baummer
--
-- Description: A mixed clock FIFO using registers targeting small FIFOs.  Based
-- on T. Chelcea, S. Nowick, A Low-Latency FIFO for Mixed-Clock Systems.  
-- NOTE: Ratio of RX Clock / TX Clock must be less than or equal to 3.  Read
-- errors will occur if this is violated.
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library work;

entity mixed_clock_fifo_regbased is
	generic (
		-- N is the size of a word in the FIFO
		N : integer;
		-- L is the length of the FIFO and must be a power of 2
		L : integer);
	port (				  
		reset : in std_logic;
		--Read Interface
		read_clk : in std_logic;
		read : in std_logic;
		valid : out std_logic;
		empty : out std_logic;
		read_data : out std_logic_vector(N-1 downto 0);
		
		--Write Interface
		write_clk : in std_logic;
		write : in std_logic;
		full : out std_logic;
		write_data : in std_logic_vector(N-1 downto 0)
		);
end mixed_clock_fifo_regbased;

architecture behavioral of mixed_clock_fifo_regbased is
	signal en_get : std_logic;
	signal e : std_logic_vector(L-1 downto 0);                    
	signal f : std_logic_vector(L-1 downto 0);
	signal v : std_logic_vector(L-1 downto 0);
	signal en_put : std_logic;
	signal req_put : std_logic;
	signal ptok : std_logic_vector(L-1 downto 0);
	signal gtok : std_logic_vector(L-1 downto 0);
	signal f_p : std_logic_vector(L-1 downto 0);
	signal full_p : std_logic;
	signal full_i : std_logic;
	signal e_p : std_logic_vector(L-1 downto 0);
	signal empty_p : std_logic;
	signal empty_i : std_logic;
	signal d_p : std_logic_vector(L-1 downto 0);
	signal deadlock_p : std_logic;
	signal deadlock_i : std_logic;
	signal valid_i : std_logic;

	function or_reduce(arg: std_logic_vector) return std_logic is
		variable result: std_logic;
	begin
		result := '0';
		for i in arg'range loop
			result := result or arg(i);
		end loop;
		return result;	
	end or_reduce;
	
	function nor_reduce(arg: std_logic_vector) return std_logic is
		variable result: std_logic;
	begin
		result := '0';
		for i in arg'range loop
			result := result nor arg(i);
		end loop;
		return result;	
	end nor_reduce;
begin
	--Array of cells which make up the FIFO
	--i=0 represents the right-most cell
	fifo_array : for i in 0 to L - 1 generate 
		--Generate the first cell in the FIFO
		--The tokens for this cell originate at the last cell of the FIFO
		first_cell : if i = 0 generate
			--FIFO Cell is a single word storage
			c0 : entity work.fifo_cell 
			generic map (
				N => N)
			port map (
				--Read Interface
				clk_get => read_clk,
				en_get => en_get,
				valid => valid_i,
				v => v(i),
				data_get => read_data,
				empty => e(i),
				
				--Write Interface
				clk_put => write_clk,
				en_put => en_put,
				req_put => write,
				data_put => write_data,
				full => f(i),
				
				--Token Interface
				--Tokens are passed right to left and wrap around at left-most cell
				ptok_in => ptok(L-1),
				gtok_in => gtok(L-1),
				ptok_out => ptok(i),
				gtok_out => gtok(i),
				
				reset => reset,
				init_token => '1'
			);
		end generate first_cell;
		
		--Generate the remaining cells in the FIFO
		--The tokens for this cell originate from the cell on the right (i-1)
		rem_cell : if i > 0 generate
			--FIFO Cell is a single word storage
			ci : entity work.fifo_cell 
			generic map (
				N => N)
			port map (
				--Read Interface
				clk_get => read_clk,
				en_get => en_get,
				valid => valid_i,
				v => v(i),
				data_get => read_data,
				empty => e(i),
				
				--Write Interface
				clk_put => write_clk,
				en_put => en_put,
				req_put => write,
				data_put => write_data,
				full => f(i),
				
				--Token Interface
				--Tokens are passed right to left and wrap around at left-most cell
				ptok_in => ptok(i-1),
				gtok_in => gtok(i-1),
				ptok_out => ptok(i),
				gtok_out => gtok(i),
				
				reset => reset,
				init_token => '0'
			);
		end generate rem_cell;
	end generate fifo_array;
	
	--control flags
	en_put <= (not full_i) and (deadlock_i or write);
	en_get <= (not empty_i) and read;
	
	--output flags
	full <= full_i;
	empty <= empty_i;
	valid <= (not empty_i) and valid_i and read; 
	
	--full detector
	--Due to the synchronizer delay full detection must occur when there is 1 empty cell
	--full is detected if there are no neighboring cells empty
	full_detector : for i in 0 to L-1 generate
		e_p(i) <= e(i) and e((i+1) mod (L-1));
	end generate full_detector;
	
	--full flag on read_clk domain
	--if any of the e_p flags are low, full is high
	full_p <= not or_reduce(e_p);
	
	--full flag synchronized to write_clk domain
	full_sync : entity work.synchronizer 
	port map (
		clk => write_clk,
		reset => reset,
		I => full_p,
		O => full_i
	);
		
	--empty detector
	--Due to the synchronizer delay empty detection must occur when there is 1 empty cell
	--empty is detected if there are no neighboring cells full
	empty_detector : for i in 0 to L-1 generate
		f_p(i) <= f(i) and f((i+1) mod (L-1));
	end generate empty_detector;
	
	--empty flag on write_clk domain
	--if any of the f_p flags are low, empty is high
	empty_p <= not or_reduce(f_p);
	
	--empty flag synchronized to read_clk domain
	empty_sync : entity work.synchronizer 
	port map (
		clk => read_clk,
		reset => reset,
		I => empty_p,
		O => empty_i
	);
	
	--deadlock detector
	--Deadlock detects when there is only 1 cell full
	deadlock_dector : for i in 0 to L-1 generate
		d_p(i) <= f(i) and v(i);
	end generate deadlock_dector;
	
	--deadlock on read_clock domain
	--deadlock occurs when empty is high and f and v is true for 1 cell
	deadlock_p <= or_reduce(d_p) and empty_p;
	
	--deadlock flag synchronized to write_clk domain
	deadlock_sync : entity work.synchronizer
	port map (
		clk => write_clk,
		reset => reset,
		I => deadlock_p,
		O => deadlock_i
	);
	
end behavioral;
		
