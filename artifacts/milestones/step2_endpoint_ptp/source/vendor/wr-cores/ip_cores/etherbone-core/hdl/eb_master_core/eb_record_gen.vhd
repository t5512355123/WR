--! @file eb_record_gen.vhd
--! @brief Parses WB Operations and generates meta data for EB records 
--!
--! Copyright (C) 2013-2014 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

--! Standard library
library IEEE;
--! Standard packages   
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;
use work.etherbone_pkg.all;
use work.genram_pkg.all;

entity eb_record_gen is
  port(
    clk_i           : in  std_logic;            -- WB Clock
    rst_n_i         : in  std_logic;            -- async reset

    slave_i         : in  t_wishbone_slave_in;  -- WB op. -> not WB compliant, but the record format is practical
    slave_stall_o   : out std_logic;            -- flow control    
    slave_ack_o     : out std_logic;
    
    rec_valid_o     : out std_logic;            -- latch signal for meta data
    rec_hdr_o       : out t_rec_hdr;            -- EB record header
    rec_adr_rd_o    : out t_wishbone_data;      -- EB write base address
    rec_adr_wr_o    : out t_wishbone_address;   -- EB read back address
    rec_ack_i       : in std_logic;             -- full flag from op fifo
    
    byte_cnt_o      : out unsigned(15 downto 0); 
    cfg_rec_hdr_i   : t_rec_hdr -- EB cfg information, eg read from cfg space etc

);   
end eb_record_gen;

architecture rtl of eb_record_gen is

function or_all(slv_in : std_logic_vector)
return std_logic is
variable I : natural;
variable ret : std_logic;
begin
  ret := '0';
  for I in 0 to slv_in'left loop
   ret := ret or slv_in(I);
  end loop;    
  return ret;
end function or_all;

--Helper functions
function is_inc(x : std_logic_vector; y : std_logic_vector)
  return boolean is
variable ret : boolean;
begin
  if(unsigned(x) = unsigned(y) + 4) then
    ret := true;
  else
    ret := false;
  end if;
  return ret;   
end; 

function to_unsigned(b_in : std_logic; bits : natural)
return unsigned is
variable ret : std_logic_vector(bits-1 downto 0) := (others=> '0');
begin
  ret(0) := b_in;
  return unsigned(ret);
end function to_unsigned;

function eq(x : std_logic_vector; y : std_logic_vector)
  return boolean is
variable ret : boolean;
begin
  if(x = y) then
    ret := true;
  else
    ret := false;
  end if;
  return ret;   
end; 

--signals
signal wb_fifo_q     : std_logic_vector(1+1+1+4+32+32-1 downto 0);
signal wb_fifo_d     : std_logic_vector(wb_fifo_q'left downto 0);
signal wb_fifo_push  : std_logic;
signal wb_fifo_pop   : std_logic;
signal wb_fifo_full  : std_logic;
signal wb_fifo_empty : std_logic;
signal dat           : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal adr           : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal we            : std_logic;
signal stb           : std_logic;
signal cyc           : std_logic;
signal sel           : std_logic_vector(c_wishbone_data_width/8-1 downto 0);
signal s_drop        : std_logic;
signal s_cmd         : std_logic;
signal s_push        : std_logic;
-- drop, cmd, we, sel, dat, adr
alias a_drop         : std_logic_vector(0  downto 0) is wb_fifo_q(70 downto 70);
alias a_cmd          : std_logic_vector(0  downto 0) is wb_fifo_q(69 downto 69);  
alias a_we           : std_logic_vector(0  downto 0) is wb_fifo_q(68 downto 68);
alias a_sel          : std_logic_vector(3  downto 0) is wb_fifo_q(67 downto 64);
alias a_dat          : std_logic_vector(31 downto 0) is wb_fifo_q(63 downto 32);
alias a_adr          : std_logic_vector(31 downto 0) is wb_fifo_q(31 downto 0);
--registers
signal r_drain       : std_logic;
signal s_stall,
       r_stall_out,
       r_ack         : std_logic;
signal r_wb_pop      : std_logic;
signal r_start       : std_logic;
signal r_sel         : std_logic_vector(3  downto 0);
signal r_drop        : std_logic_vector(0  downto 0);
signal r_cyc,
       r_cyc_in      : std_logic;
signal r_stb,
       r_stb_in      : std_logic;
signal r_we_in       : std_logic_vector(0 downto 0);  
signal r_adr,
       r_adr_in      : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_dat,
       r_dat_in      : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal r_sel_in      : std_logic_vector(c_wishbone_data_width/8-1 downto 0);

signal r_adr_wr      : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_adr_rd      : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_rec_hdr     : t_rec_hdr;
signal r_push_hdr    : std_logic;
signal r_rec_valid   : std_logic;
signal s_word_cnt    : unsigned(15 downto 0);

-- FSMs
type t_mode is (UNKNOWN, WR_FIFO, WR_NORM, RD_FIFO, RD_NORM, WR_SPLIT, RD_SPLIT);
type t_hdr_state is (s_START, s_WRITE, s_READ, s_OUTP, s_WAIT, s_WACK);
signal r_hdr_state   : t_hdr_state;
signal r_mode        : t_mode;
signal r_wait_return : t_hdr_state;
signal r_cnt_wait    : unsigned(4 downto 0);
 
begin
------------------------------------------------------------------------------
-- IO assignments
------------------------------------------------------------------------------
  cyc <= slave_i.cyc;
  stb <= slave_i.stb;
  we <=  slave_i.we;
  adr <= slave_i.adr;
  dat <= slave_i.dat;
  sel <= slave_i.sel;
  rec_valid_o     <= r_rec_valid;
  slave_stall_o   <= s_stall; 
  slave_ack_o     <= r_ack; 
------------------------------------------------------------------------------
-- Input fifo
------------------------------------------------------------------------------

  wb_fifo : generic_sync_fifo
    generic map(
      g_data_width             => 1+1+1+4+32+32, -- drop, cmd, we, sel, dat, adr
      g_size                   => 8,
      g_show_ahead             => true,
      g_with_empty             => true,
      g_with_full              => true,
      g_with_almost_full       => true,
      g_almost_full_threshold  => 6)
    port map(
      rst_n_i        => rst_n_i,
      clk_i          => clk_i,
      d_i            => wb_fifo_d,
      we_i           => wb_fifo_push,
      q_o            => wb_fifo_q,
      rd_i           => wb_fifo_pop,
      empty_o        => wb_fifo_empty,
      almost_full_o  => wb_fifo_full,
      count_o        => open
      );
      
      assert not (wb_fifo_full = '1' and wb_fifo_empty = '1') report "RGEN FIFO CORRUPT!" severity failure;
      
  s_push          <= (r_cyc_in and r_stb_in and not r_stall_out);  -- also delay stall 1 cycle!
  s_cmd           <= not s_push;
  s_drop          <= r_cyc_in and not cyc;
  wb_fifo_pop     <= r_wb_pop and not wb_fifo_empty;
  wb_fifo_push    <= s_push or s_drop;
  wb_fifo_d       <= s_drop & s_cmd & r_we_in & r_sel_in & r_dat_in & r_adr_in;
  s_stall         <= wb_fifo_full or r_drain;
               
------------------------------------------------------------------------------
-- Parser Aux Structures
------------------------------------------------------------------------------
--register IOs, End of Packet, Addres diff
  p_register_io : process (clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_dat       <= (others => '0'); 
      r_adr       <= (others => '0');
      r_drain     <= '0';
      r_sel       <= (others=> '0');
      r_drop      <= (others=> '0');
		rec_hdr_o.res1      	<= '0';
      rec_hdr_o.res2      	<= '0';
      rec_hdr_o.bca_cfg   	<= '1';
      rec_hdr_o.rd_fifo   	<= '0';
      rec_hdr_o.wr_fifo   	<= '0';  
      rec_hdr_o.sel       	<= x"00";
      rec_hdr_o.drop_cyc  	<= '0';      
      rec_hdr_o.rca_cfg   	<= '0';
      rec_hdr_o.rd_fifo   	<= '0';
      rec_hdr_o.wca_cfg   	<= '0'; 
		rec_hdr_o.wr_cnt 		<= (others=> '0');
      rec_hdr_o.rd_cnt 		<= (others=> '0');
		
		rec_adr_rd_o 			<= (others=> '0');
		rec_adr_wr_o 			<= (others=> '0');
    elsif rising_edge(clk_i) then
      
      r_cyc_in    <= cyc;
      r_stb_in    <= stb;
      r_dat_in    <= dat;
      r_adr_in    <= adr;
      r_we_in(0)  <= we;
      r_sel_in    <= sel;
      
      --let the buffer empty before starting new cycle
      r_drain <= (r_drain or a_drop(0)) and not wb_fifo_empty;
      
      if(r_push_hdr = '1') then -- the 'if' is not necessary but makes debugging easier
        rec_hdr_o     <= r_rec_hdr;
        rec_adr_rd_o  <= r_adr_rd;
        rec_adr_wr_o  <= r_adr_wr;
      end if; 
      
      if(wb_fifo_pop = '1') then
        r_dat  <= a_dat; 
        r_adr  <= a_adr;
        r_sel  <= a_sel;
        r_drop <= a_drop; 
      end if;
    end if;
  end process;
 
-- R/W ops counters
  p_cnt : process (clk_i, rst_n_i) is
  variable v_wr_inc,
           v_wr_sum,
           v_wr_g_zero,
           v_rd_inc,
           v_rd_sum,
           v_rd_g_zero : unsigned(7 downto 0);
  
  begin
    if rst_n_i = '0' then
      r_rec_hdr.wr_cnt <= (others => '0');
      r_rec_hdr.rd_cnt <= (others => '0');
      r_ack <= '0';
    elsif rising_edge(clk_i) then
      v_wr_inc    := "0000000" & unsigned(a_we and not a_cmd);
      v_wr_sum    := r_rec_hdr.wr_cnt + v_wr_inc;
      v_wr_g_zero := to_unsigned(or_all(std_logic_vector(v_wr_sum)), 8);
      
      v_rd_inc    := "0000000" & unsigned((not a_we) and not a_cmd);
      v_rd_sum    := r_rec_hdr.rd_cnt + v_rd_inc;
      v_rd_g_zero := to_unsigned(or_all(std_logic_vector(v_rd_sum)), 8);
      
      r_ack <= '0';
      if(r_push_hdr = '1') then
        r_rec_hdr.wr_cnt <= (others => '0');
        r_rec_hdr.rd_cnt <= (others => '0');
      elsif(wb_fifo_pop = '1') then
          --if a new entry is taken out of the fifo, inc rd & wr counters accordingly
          r_rec_hdr.wr_cnt <= v_wr_sum;
          r_rec_hdr.rd_cnt <= v_rd_sum;
          s_word_cnt <=    1
                        + (x"00" & v_wr_g_zero) 
                        + (x"00" & v_wr_sum)
                        + (x"00" & v_rd_g_zero)
                        + (x"00" & v_rd_sum); 
          r_ack <= not a_cmd(0);
      end if;
    end if;  
  end process; 
------------------------------------------------------------------------------
byte_cnt_o <= s_word_cnt(13 downto 0) & "00";

------------------------------------------------------------------------------
-- Parser FSM
------------------------------------------------------------------------------
  p_eb_rec_hdr_gen : process (clk_i, rst_n_i) is
  variable v_rec_hdr      : t_rec_hdr;
  variable v_cyc_falling  : boolean;
  variable v_cyc_rising   : boolean;
  variable v_state        : t_hdr_state;
  
  procedure wait_n_goto( cycles   : in natural := 1;
                       retState : in t_hdr_state   
                    ) is
  begin
    v_state       := s_WAIT;
    r_cnt_wait    <= (to_unsigned(cycles, 5) and "01111") -2;
    r_wait_return <= retState;
  end procedure wait_n_goto;
  
  begin
    if rst_n_i = '0' then
      r_hdr_state <= s_START;
      r_push_hdr  <= '0';
      r_adr_rd    <= (others => '0');
      r_adr_wr    <= (others => '0');
      r_mode      <= UNKNOWN;
      r_wb_pop    <= '0';
      r_rec_hdr.res1      <= '0';
      r_rec_hdr.res2      <= '0';
      r_rec_hdr.bca_cfg   <= '1';
      r_rec_hdr.rd_fifo   <= '0';
      r_rec_hdr.wr_fifo   <= '0';  
      r_rec_hdr.sel       <= x"00";
      r_rec_hdr.drop_cyc  <= '0';      
      r_rec_hdr.rca_cfg   <= '0';
      r_rec_hdr.rd_fifo   <= '0';
      r_rec_hdr.wca_cfg   <= '0'; 
     elsif rising_edge(clk_i) then
      v_state     := r_hdr_state;                    
      r_rec_valid <= '0';
      r_push_hdr  <= '0';
      r_wb_pop    <= '0';
      r_stall_out <= s_stall;
    case r_hdr_state is
      when s_START  =>  --register all cfg data
                        r_rec_hdr.res1      <= '0';
                        r_rec_hdr.res2      <= '0';
                        r_rec_hdr.bca_cfg   <= '1';
                        r_rec_hdr.rd_fifo   <= '0';
                        r_rec_hdr.wr_fifo   <= '0';  
                        r_rec_hdr.sel       <= x"0" & a_sel;
                        r_rec_hdr.drop_cyc  <= cfg_rec_hdr_i.drop_cyc;      
                        r_rec_hdr.rca_cfg   <= cfg_rec_hdr_i.rca_cfg;
                        r_rec_hdr.rd_fifo   <= cfg_rec_hdr_i.rd_fifo;
                        r_rec_hdr.wca_cfg   <= cfg_rec_hdr_i.wca_cfg;  
                        r_mode    <= UNKNOWN; 
                        if(wb_fifo_empty = '0') then
                          r_wb_pop <= '1'; 
                          if(a_cmd = "0") then
                            if(a_we = "1") then
                              --latch wr adr
                              r_adr_wr <= a_adr; 
                              wait_n_goto(1, s_WRITE); -- can be followed by reads
                            else
                               --latch rd adr
                              r_adr_rd <= a_dat; 
                              wait_n_goto(1, s_READ);
                            end if;
                          end if;
                        end if;
     
      when s_WRITE  =>  -- process write requests
                        --if the fifo just ran low, wait. If drop signal shows it was intentional, 
                        --finalise header. Could also insert a timeout here 
                                              
                        if(wb_fifo_empty = '1') then
                           if(r_drop = "1" or r_sel /= r_rec_hdr.sel(3 downto 0)) then
                                 r_rec_hdr.drop_cyc <= a_drop(0);
                                 wait_n_goto(1, s_OUTP);
                           else 
                              v_state := s_WRITE; 
                           end if;
                        else
                            if(a_cmd = "0") then
                               if(a_we = "0") then -- switch write -> read. get return address, push it out, go to read mode 
                                 r_adr_rd <= a_dat;
                                 v_state := s_READ;
                               else                              
                                 --set wr address mode                              
                                 if(r_mode = UNKNOWN) then
                                   if(eq(a_adr, r_adr)) then         -- constant dst address -> wr fifo
                                     r_mode <= WR_FIFO;
                                     r_rec_hdr.wr_fifo <= '1';
                                      r_wb_pop <= '1';
                                      wait_n_goto(1, s_WRITE);
                                   elsif(is_inc(a_adr, r_adr)) then  -- incrementing dst address -> wr norm
                                     r_mode <= WR_NORM;
                                     r_wb_pop <= '1';
                                     wait_n_goto(1, s_WRITE);               
                                   else                              -- arbitrary dst address -> wr norm and create new record
                                     r_mode <= WR_SPLIT;
                                     r_rec_hdr.wr_fifo <= '0';                                
                                     v_state := s_OUTP;
                                   end if;           
                                 else
                                   -- see if change in address requires new header
                                   if((r_mode = WR_FIFO and not eq(a_adr, r_adr))
                                   or (r_mode = WR_NORM and not is_inc(a_adr, r_adr))) then
                                       r_mode <= WR_SPLIT;
                                       wait_n_goto(1, s_OUTP);
                                   else
                                     -- stay in write state
                                    r_wb_pop <= '1';
                                    wait_n_goto(1, s_WRITE);                               
                                   end if;                              
                                 end if; -- if r_mode unknown
                                 
                               end if; -- if a_we = 0
                             else 
                               r_wb_pop <= '1';
                             end if; -- if a_cmd = 0
                             
                             if(a_drop = "1" or a_sel /= r_rec_hdr.sel(3 downto 0)) then
                                 r_rec_hdr.drop_cyc <= a_drop(0);
                                 wait_n_goto(1, s_OUTP);                      
                             end if; 
                        end if; --if fifo_empty = 0
                          
      when s_READ   =>  -- process read requests
      
                        --if the fifo just ran low, wait. If drop signal shows it was intentional, 
                        --finalise header. Could also insert a timeout here
                        if(wb_fifo_empty = '1') then
                           if(r_drop = "1" or r_sel /= r_rec_hdr.sel(3 downto 0)) then
                                 r_rec_hdr.drop_cyc <= a_drop(0);
                                 wait_n_goto(1, s_OUTP);
                           else 
                              v_state := s_READ; 
                           end if;
                        else
                           if(a_cmd = "0") then
                               if(a_we = "1") then
                                 v_state := s_OUTP;
                               else                              
                                 --set rba mode                              
                                 if(r_mode = UNKNOWN) then
                                   if(eq(a_dat, r_dat)) then       -- constant return address -> rd fifo
                                     r_mode <= RD_FIFO;
                                     r_rec_hdr.rd_fifo <= '1';
                                     r_wb_pop <= '1';
                                     wait_n_goto(1, s_READ);        
                                   elsif(is_inc(a_dat, r_dat)) then -- incrementing return address -> rd norm
                                     r_mode <= RD_NORM;
                                     r_wb_pop <= '1';
                                     wait_n_goto(1, s_READ);               
                                   else                              -- arbitrary return address -> rd norm and create new record      
                                     r_mode <= RD_SPLIT;
                                     r_rec_hdr.rd_fifo <= '0';                                
                                     v_state :=  s_OUTP;
                                   end if;           
                                 else
                                   -- see if change in data (return  requires new header
                                   if((r_mode = RD_FIFO and not eq(a_dat, r_dat))
                                   or (r_mode = RD_NORM and not is_inc(a_dat, r_dat))) then
                                       r_mode <= RD_SPLIT;
                                       v_state := s_OUTP;
                                   else
                                     -- stay in read state
                                      r_wb_pop <= '1';
                                      wait_n_goto(1, s_READ);                              
                                   end if;                              
                                 end if;
                               end if;
                             else
                               r_wb_pop <= '1';
                             end if;
                             if(a_drop = "1" or a_sel /= r_rec_hdr.sel(3 downto 0)) then
                              r_rec_hdr.drop_cyc <= a_drop(0);
                              wait_n_goto(1, s_OUTP);                      
                           end if; 
                        end if;
                        
        
      when s_WAIT   =>  if(r_cnt_wait(r_cnt_wait'left) = '1') then
                          v_state := r_wait_return;
                        else
                          r_cnt_wait <= r_cnt_wait-1;
                        end if;
                                              
      when s_OUTP   =>  -- signal the framer we got a valid header and adr for him 
                        v_state := s_WACK;
        
      when s_WACK   =>  -- since eb content is bigger than incoming wb ops stream, 
                        -- we must wait until the framer acks the header and adr we gave him
                         if(rec_ack_i = '1') then 
                          v_state := s_START;
                         end if;
                          
      when others   =>  v_state := s_START;
    
    end case;
    
      if(v_state = s_OUTP) then
        r_push_hdr <= '1';
      end if;
      
      if(v_state = s_WACK) then
        r_rec_valid <= '1';
      end if;
                                        
      r_hdr_state <= v_state;
    
    end if;
  end process;

end architecture;




