------------------------------------------------------------------------
-- Title      : VME Core 64x wrapper for Verilog instantiation
------------------------------------------------------------------------
-- Description:
--
-- Different tools interpret verilog/vhdl parameters in different ways
-- This file is intended to use parameter types most commonly supported
-- and translate them to required VHDL values.
------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use work.wishbone_pkg.all;
use work.vme64x_pkg.all;

entity vme64x_core_verilog is
  generic (
    g_CLOCK_PERIOD    : natural;
    g_DECODE_AM       : natural := 1;
    g_ENABLE_CR_CSR   : natural := 1;
    g_USER_CSR_EXT    : natural := 0;
    g_VME32           : natural := 1;
    g_VME_2e          : natural := 0;
    g_WB_GRANULARITY  : string(1 to 4);
    g_MANUFACTURER_ID : std_logic_vector(23 downto 0);
    g_BOARD_ID        : std_logic_vector(31 downto 0);
    g_REVISION_ID     : std_logic_vector(31 downto 0);
    g_PROGRAM_ID      : std_logic_vector(7 downto 0);
    g_ASCII_PTR       : std_logic_vector(23 downto 0) := x"000000";
    g_BEG_USER_CR     : std_logic_vector(23 downto 0) := x"000000";
    g_END_USER_CR     : std_logic_vector(23 downto 0) := x"000000";
    g_BEG_CRAM        : std_logic_vector(23 downto 0) := x"000000";
    g_END_CRAM        : std_logic_vector(23 downto 0) := x"000000";
    g_BEG_USER_CSR    : std_logic_vector(23 downto 0) := x"07ff33";
    g_END_USER_CSR    : std_logic_vector(23 downto 0) := x"07ff5f";
    g_BEG_SN          : std_logic_vector(23 downto 0) := x"000000";
    g_END_SN          : std_logic_vector(23 downto 0) := x"000000";
    g_DECODER_0_ADEM  : std_logic_vector(31 downto 0) := x"ff000000";
    g_DECODER_0_AMCAP : std_logic_vector(63 downto 0) := x"00000000_0000ff00";
    g_DECODER_0_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_1_ADEM  : std_logic_vector(31 downto 0) := x"fff80000";
    g_DECODER_1_AMCAP : std_logic_vector(63 downto 0) := x"ff000000_00000000";
    g_DECODER_1_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_2_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_2_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_2_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_3_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_3_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_3_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_4_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_4_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_4_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_5_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_5_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_5_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_6_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_6_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_6_DAWPR : std_logic_vector(7 downto 0)  := x"84";
    g_DECODER_7_ADEM  : std_logic_vector(31 downto 0) := x"00000000";
    g_DECODER_7_AMCAP : std_logic_vector(63 downto 0) := x"00000000_00000000";
    g_DECODER_7_DAWPR : std_logic_vector(7 downto 0)  := x"84");
  port (
    clk_i           : std_logic;
    rst_n_i         : std_logic;
    rst_n_o         : out std_logic;
    vme_as_n_i      : std_logic;
    vme_rst_n_i     : std_logic;
    vme_write_n_i   : std_logic;
    vme_am_i        : std_logic_vector(5 downto 0);
    vme_ds_n_i      : std_logic_vector(1 downto 0);
    vme_ga_i        : std_logic_vector(5 downto 0);
    vme_lword_n_i   : std_logic;
    vme_data_i      : std_logic_vector(31 downto 0);
    vme_addr_i      : std_logic_vector(31 downto 1);
    vme_iack_n_i    : std_logic;
    vme_iackin_n_i  : std_logic;
    vme_iackout_n_o : out std_logic;
    vme_dtack_n_o   : out std_logic;
    vme_dtack_oe_o  : out std_logic;
    vme_lword_n_o   : out std_logic;
    vme_data_o      : out std_logic_vector(31 downto 0);
    vme_data_dir_o  : out std_logic;
    vme_data_oe_n_o : out std_logic;
    vme_addr_o      : out std_logic_vector(31 downto 1);
    vme_addr_dir_o  : out std_logic;
    vme_addr_oe_n_o : out std_logic;
    vme_retry_n_o   : out std_logic;
    vme_retry_oe_o  : out std_logic;
    vme_berr_n_o    : out std_logic;
    vme_irq_n_o     : out std_logic_vector(6 downto 0);
    wb_ack_i        : std_logic;
    wb_err_i        : std_logic;
    wb_rty_i        : std_logic;
    wb_stall_i      : std_logic;
    wb_dat_i        : t_wishbone_data;
    wb_cyc_o        : out std_logic;
    wb_stb_o        : out std_logic;
    wb_adr_o        : out t_wishbone_address;
    wb_sel_o        : out t_wishbone_byte_select;
    wb_we_o         : out std_logic;
    wb_dat_o        : out t_wishbone_data;
    int_i           : std_logic := '0';
    irq_ack_o       : out std_logic;
    irq_level_i     : std_logic_vector(2 downto 0) := (others => '0');
    irq_vector_i    : std_logic_vector(7 downto 0) := (others => '0');
    user_csr_addr_o : out std_logic_vector(18 downto 2);
    user_csr_data_i : std_logic_vector(7 downto 0) := (others => '0');
    user_csr_data_o : out std_logic_vector(7 downto 0);
    user_csr_we_o   : out std_logic;
    user_cr_addr_o  : out std_logic_vector(18 downto 2);
    user_cr_data_i  : std_logic_vector(7 downto 0) := (others => '0'));
    
  function nat_to_bool(X : natural)
              return boolean is
  begin
    if X = 0 then
      return false ;
    else
      return true ;
    end if;
  end nat_to_bool;

  function string_to_wb_grn(X : string(1 to 4))
              return t_wishbone_address_granularity is
  begin
    if X = "WORD" then
      return WORD ;
    end if;
    if X = "BYTE" then
      return BYTE ;
    end if;
  end string_to_wb_grn ;
end vme64x_core_verilog;

architecture wrapper of vme64x_core_verilog  is
begin
  inst : entity work.vme64x_core
    generic map (
      g_CLOCK_PERIOD     => g_CLOCK_PERIOD,
      g_DECODE_AM        => nat_to_bool(g_DECODE_AM),
      g_ENABLE_CR_CSR    => nat_to_bool(g_ENABLE_CR_CSR),
      g_USER_CSR_EXT     => nat_to_bool(g_USER_CSR_EXT),
      g_VME32            => nat_to_bool(g_VME32),
      g_VME_2e           => nat_to_bool(g_VME_2e),
      g_WB_GRANULARITY   => string_to_wb_grn(g_WB_GRANULARITY),
      g_MANUFACTURER_ID  => g_MANUFACTURER_ID,
      g_BOARD_ID         => g_BOARD_ID,
      g_REVISION_ID      => g_REVISION_ID,
      g_PROGRAM_ID       => g_PROGRAM_ID,
      g_ASCII_PTR        => g_ASCII_PTR,
      g_BEG_USER_CR      => g_BEG_USER_CR,
      g_END_USER_CR      => g_END_USER_CR,
      g_BEG_CRAM         => g_BEG_CRAM,
      g_END_CRAM         => g_END_CRAM,
      g_BEG_USER_CSR     => g_BEG_USER_CSR,
      g_END_USER_CSR     => g_END_USER_CSR,
      g_BEG_SN           => g_BEG_SN,
      g_END_SN           => g_END_SN,
      g_DECODER_0_ADEM   => g_DECODER_0_ADEM,
      g_DECODER_0_AMCAP  => g_DECODER_0_AMCAP,
      g_DECODER_0_DAWPR  => g_DECODER_0_DAWPR,
      g_DECODER_1_ADEM   => g_DECODER_1_ADEM,
      g_DECODER_1_AMCAP  => g_DECODER_1_AMCAP,
      g_DECODER_1_DAWPR  => g_DECODER_1_DAWPR,
      g_DECODER_2_ADEM   => g_DECODER_2_ADEM,
      g_DECODER_2_AMCAP  => g_DECODER_2_AMCAP,
      g_DECODER_2_DAWPR  => g_DECODER_2_DAWPR,
      g_DECODER_3_ADEM   => g_DECODER_3_ADEM,
      g_DECODER_3_AMCAP  => g_DECODER_3_AMCAP,
      g_DECODER_3_DAWPR  => g_DECODER_3_DAWPR,
      g_DECODER_4_ADEM   => g_DECODER_4_ADEM,
      g_DECODER_4_AMCAP  => g_DECODER_4_AMCAP,
      g_DECODER_4_DAWPR  => g_DECODER_4_DAWPR,
      g_DECODER_5_ADEM   => g_DECODER_5_ADEM,
      g_DECODER_5_AMCAP  => g_DECODER_5_AMCAP,
      g_DECODER_5_DAWPR  => g_DECODER_5_DAWPR,
      g_DECODER_6_ADEM   => g_DECODER_6_ADEM,
      g_DECODER_6_AMCAP  => g_DECODER_6_AMCAP,
      g_DECODER_6_DAWPR  => g_DECODER_6_DAWPR,
      g_DECODER_7_ADEM   => g_DECODER_7_ADEM,
      g_DECODER_7_AMCAP  => g_DECODER_7_AMCAP,
      g_DECODER_7_DAWPR  => g_DECODER_7_DAWPR)
 port map (
      clk_i           => clk_i,
      rst_n_i         => rst_n_i,
      rst_n_o         => rst_n_o,
      vme_as_n_i      => vme_as_n_i,
      vme_rst_n_i     => vme_rst_n_i,
      vme_write_n_i   => vme_write_n_i,
      vme_am_i        => vme_am_i,
      vme_ds_n_i      => vme_ds_n_i,
      vme_ga_i        => vme_ga_i,
      vme_lword_n_i   => vme_lword_n_i,
      vme_data_i      => vme_data_i,
      vme_addr_i      => vme_addr_i,
      vme_iack_n_i    => vme_iack_n_i,
      vme_iackin_n_i  => vme_iackin_n_i,
      vme_iackout_n_o => vme_iackout_n_o,
      vme_dtack_n_o   => vme_dtack_n_o,
      vme_dtack_oe_o  => vme_dtack_oe_o,
      vme_lword_n_o   => vme_lword_n_o,
      vme_data_o      => vme_data_o,
      vme_data_dir_o  => vme_data_dir_o,
      vme_data_oe_n_o => vme_data_oe_n_o,
      vme_addr_o      => vme_addr_o,
      vme_addr_dir_o  => vme_addr_dir_o,
      vme_addr_oe_n_o => vme_addr_oe_n_o,
      vme_retry_n_o   => vme_retry_n_o,
      vme_retry_oe_o  => vme_retry_oe_o,
      vme_berr_n_o    => vme_berr_n_o,
      vme_irq_n_o     => vme_irq_n_o,
      wb_ack_i        => wb_ack_i,
      wb_err_i        => wb_err_i,
      wb_rty_i        => wb_rty_i,
      wb_stall_i      => wb_stall_i,
      wb_dat_i        => wb_dat_i,
      wb_cyc_o        => wb_cyc_o,
      wb_stb_o        => wb_stb_o,
      wb_adr_o        => wb_adr_o,
      wb_sel_o        => wb_sel_o,
      wb_we_o         => wb_we_o,
      wb_dat_o        => wb_dat_o,
      int_i           => int_i,
      irq_ack_o       => irq_ack_o,
      irq_level_i     => irq_level_i,
      irq_vector_i    => irq_vector_i,
      user_csr_addr_o => user_csr_addr_o,
      user_csr_data_i => user_csr_data_i,
      user_csr_data_o => user_csr_data_o,
      user_csr_we_o   => user_csr_we_o,
      user_cr_addr_o  => user_cr_addr_o,
      user_cr_data_i  => user_cr_data_i);

end wrapper;
