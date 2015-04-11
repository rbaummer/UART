--------------------------------------------------------------------------------
--
-- File: FIFO Cell for Mixed-Clock FIFO - Register Based
-- Author: Rob Baummer
--
-- Description: Individual cell for a word in the Mixed-Clock FIFO
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_cell is
	generic (
		N : integer);
	port (
		--Read Interface
		clk_get : in std_logic;
		en_get : in std_logic;
		valid : out std_logic;
		v : out std_logic;
		data_get : out std_logic_vector(N-1 downto 0);
		empty : out std_logic;
		
		--Write Interface
		clk_put : in std_logic;
		en_put : in std_logic;
		req_put : in std_logic;
		data_put : in std_logic_vector(N-1 downto 0);
		full : out std_logic;
		
		--Token Interface
		ptok_in : in std_logic;
		gtok_in : in std_logic;
		ptok_out : out std_logic;
		gtok_out : out std_logic;
		
		reset : in std_logic;
		init_token : in std_logic
	);
end fifo_cell;

architecture behavioral of fifo_cell is
	signal data_reg : std_logic_vector(N downto 0);
	signal ptok : std_logic;
	signal gtok : std_logic;
	signal S : std_logic;
	signal R : std_logic;
	
begin
	--Register for the data stored in the cell
	--MSB is a valid bit
	process (clk_put)
	begin
		if clk_put = '1' and clk_put'event then
			if reset = '1' then
				data_reg <= (others => '0');
			elsif ptok_in = '1' and en_put = '1' then
				data_reg <= req_put & data_put;				
			end if;
		end if;
	end process;
	
	--Output Tristate
	data_get <= data_reg(N-1 downto 0) when R = '1' else (others => 'Z');
	valid <= data_reg(N) when R = '1' else 'Z';
	v <= data_reg(N);
	
	--Put Token register
	process (clk_put)
	begin
		if clk_put = '1' and clk_put'event then
			if reset = '1' then
				ptok <= init_token;
			elsif en_put = '1' then
				ptok <= ptok_in;
			end if;
		end if;
	end process;
	
	--Put token is pased right to left
	ptok_out <= ptok;
	
	--Get Token register
	process (clk_get)
	begin
		if clk_get = '1' and clk_get'event then
			if reset = '1' then
				gtok <= init_token;
			elsif en_get = '1' then
				gtok <= gtok_in;
			end if;
		end if;
	end process;
	
	--Get token is pased right to left
	gtok_out <= gtok;
	
	--SR flip flop reset
	R <= en_get and gtok_in;
	--SR flip flop set
	S <= en_put and ptok_in;
	
	--Full/Empty SR flip flop
	process (S, R)
	begin
		if R = '1' or reset = '1' then
			empty <= '1';
			full <= '0';
		elsif S = '1' then
			empty <= '0';
			full <= '1';
		end if;
	end process;
			

end behavioral;
