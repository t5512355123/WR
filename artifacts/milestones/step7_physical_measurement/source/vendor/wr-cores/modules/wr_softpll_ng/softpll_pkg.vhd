library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package softpll_pkg is

  constant c_softpll_max_aux_clocks : integer := 8;

  type t_softpll_channel_config is record
    oversample : boolean;
    divider : integer;
  end record;

  constant c_softpll_default_channel_config : t_softpll_channel_config :=
    ( oversample => false,
      divider => 1 );

  type t_softpll_channels_config_array is array(0 to c_softpll_max_aux_clocks-1) of t_softpll_channel_config;

  constant c_softpll_default_channels_config : t_softpll_channels_config_array := (others => c_softpll_default_channel_config);

  -- External 10 MHz input divider parameters. 
  constant c_softpll_ext_div_ref     : integer := 8;
  constant c_softpll_ext_div_fb      : integer := 50;
  constant c_softpll_ext_log2_gating : integer := 13;

  constant c_softpll_out_status_off      : std_logic_vector(3 downto 0) := "0000";
  constant c_softpll_out_status_locking  : std_logic_vector(3 downto 0) := "0001";
  constant c_softpll_out_status_locked   : std_logic_vector(3 downto 0) := "0010";
  constant c_softpll_out_status_aligning : std_logic_vector(3 downto 0) := "0011";
  constant c_softpll_out_status_holdover : std_logic_vector(3 downto 0) := "0100";

  function f_nonzero_vector(vector_width : integer) return integer;

end package;

package body softpll_pkg is

  -- Function f_nonzero_vector() is to be used in generating std_logic_vector
  -- in which the number of bits can be specified to be zero, e.g.
  -- (see xwr_softpll_ng)
  --
  --   clk_ext_mul_i        : in std_logic_vector(g_num_exts-1 downto 0);
  --
  -- There might not be any external clocks, i.e. g_num_exts. In such case,
  -- the code would not compile because std_logic_vector(-1 to 0) is not valid.
  -- This function is used to generate std_logic_vector(0 to 0) in the case
  -- when g_num_exts=0.
  --
  function f_nonzero_vector(vector_width : integer)
    return integer is
  begin
    if (vector_width > 0) then
      return vector_width;
    else
      return 1;
    end if;
  end function;

end softpll_pkg;
