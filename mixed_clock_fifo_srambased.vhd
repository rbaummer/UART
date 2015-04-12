--------------------------------------------------------------------------------
--
-- File: Mixed-Clock FIFO - Register Based
-- Author: Rob Baummer
--
-- Description: A mixed clock FIFO using SRAM as the memory element.  Based 
-- on R. Apperson, et al. A Scalable Dual-Clock FIFO for Data Transfers between
-- Arbitrary and Haltable Clock Domains
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;	   
use ieee.numeric_std_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;		   

library work;

entity mixed_clock_fifo_srambased is
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
end mixed_clock_fifo_srambased;

architecture behavioral of mixed_clock_fifo_srambased is
	constant addr_size : integer := integer(log2(real(L)));
	constant reserve : std_logic_vector(addr_size-1 downto 0) := std_logic_vector(to_unsigned(2,addr_size));
	signal write_addr : std_logic_vector(addr_size-1 downto 0);
	signal write_addr_gray : std_logic_vector(addr_size-1 downto 0);
	signal write_addr_gray_sync : std_logic_vector(addr_size-1 downto 0);
	signal write_addr_sync : std_logic_vector(addr_size-1 downto 0);
	signal read_addr : std_logic_vector(addr_size-1 downto 0);
	signal read_addr_gray : std_logic_vector(addr_size-1 downto 0);
	signal read_addr_gray_sync : std_logic_vector(addr_size-1 downto 0);
	signal read_addr_sync : std_logic_vector(addr_size-1 downto 0);
	signal write_difference : std_logic_vector(addr_size downto 0);
	signal empty_i : std_logic;
	signal full_i : std_logic;
	
	type ram is array(L-1 downto 0) of std_logic_vector(N-1 downto 0);
	shared variable dualport_sram : ram;

	function binary_to_gray(arg: std_logic_vector) return std_logic_vector is
		variable result: std_logic_vector(arg'range);
	begin
		result(arg'high) := arg(arg'high);		--gray(MSB) = binary(MSB)
		for i in arg'low to arg'high-1 loop
			result(i) := arg(i+1) xor arg(i);	--gray(i) = binary(i+1) + binary(i)
		end loop;
		return result;	
	end binary_to_gray;
	
	function gray_to_binary(arg: std_logic_vector) return std_logic_vector is
		variable result: std_logic_vector(arg'range);
	begin
		result(arg'high) := arg(arg'high);			--binary(MSB) = gray(MSB)
		for i in arg'high-1 downto arg'low loop
			result(i) := result(i+1) xor arg(i);	--binary(i) = binary(i+1) + gray(i)
		end loop;
		return result;	
	end gray_to_binary;
begin
	----------------------------------------------------------------------------
	--						Write Clock Domain Signals						  --
	----------------------------------------------------------------------------
	--Write address
	process (write_clk)
	begin
		if write_clk = '1' and write_clk'event then
			if reset = '1' then
				write_addr <= (others => '0');
			elsif write = '1' and full_i = '0' then
				write_addr <= write_addr + std_logic_vector(to_unsigned(1,addr_size-1));
			end if;
		end if;
	end process;
	
	--Convert binary encoding to gray encoding before crossing clock domains
	--only a single bit can change so the compare is at most 1 address off
	write_addr_gray <= binary_to_gray(write_addr);
	
	--Write address synced to read clock domain
	raddr_sync : entity work.nbit_synchronizer
		generic map (
			N => addr_size)
		port map (
			clk => read_clk,
			reset => reset,
			I => read_addr_gray,
			O => read_addr_gray_sync);
			
	--Binary encoded read address on read clock domain
	read_addr_sync <= gray_to_binary(read_addr_gray_sync);
	
	--full detection logic
	write_difference <= ('0' & write_addr) - ('0' & read_addr_sync) + reserve;
	--if MSB of write_difference is 1 then write_difference >= L and the fifo is full
	full_i <= '1' when write_difference(write_difference'high) = '1' else '0';
	full <= full_i;
	
	----------------------------------------------------------------------------
	--						Read Clock Domain Signals						  --
	----------------------------------------------------------------------------
	--Read address
	process (read_clk)
	begin
		if read_clk = '1' and read_clk'event then
			if reset = '1' then
				read_addr <= (others => '0');
			elsif read = '1' and empty_i = '0' then
				read_addr <= read_addr + std_logic_vector(to_unsigned(1,addr_size-1));
			end if;
		end if;
	end process;
	
	--Convert binary encoding to gray encoding before crossing clock domains
	--only a single bit can change so the compare is at most 1 address off
	read_addr_gray <= binary_to_gray(read_addr);

	--Write address synced to read clock domain
	waddr_sync : entity work.nbit_synchronizer
		generic map (
			N => addr_size)
		port map (
			clk => read_clk,
			reset => reset,
			I => write_addr_gray,
			O => write_addr_gray_sync);
			
	--Binary encoded write address on read clock domain
	write_addr_sync <= gray_to_binary(write_addr_gray_sync);
	
	--empty detection logic
	empty_i <= '1' when read_addr = write_addr_sync else '0';
	empty <= empty_i;
	
	--valid signal
	--unless fifo is empty valid is high 1 clock after read signal
	process (read_clk)
	begin
		if read_clk = '1' and read_clk'event then
			if reset = '1' then
				valid <= '0';
			else
				valid <= not empty and read;
			end if;
		end if;
	end process;
	
	----------------------------------------------------------------------------
	--								SRAM									  --
	----------------------------------------------------------------------------
	--Write Port
	process (write_clk)
	begin
		if write_clk = '1' and write_clk'event then
			if write = '1' and full_i = '0' then
				dualport_sram(to_integer(unsigned(write_addr))) := write_data;
			end if;
		end if;
	end process;
	
	--Read Port
	process (read_clk)
	begin
		if read_clk = '1' and read_clk'event then
			read_data <= dualport_sram(to_integer(unsigned(read_addr)));
		end if;
	end process;
	
	
end behavioral;
		
