--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   p2l_des
--
-- description: P2L deserializer. Takes the DDR P2L bus and converts to SDR
-- that is synchronous to the core clock. Spartan6 FPGAs version.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity p2l_des is
  port
    (
      ---------------------------------------------------------
      -- Reset and clock
      rst_a_i         : in std_logic;
      sys_clk_i       : in std_logic;
      io_clk_i        : in std_logic;
      serdes_strobe_i : in std_logic;

      ---------------------------------------------------------
      -- P2L clock domain (DDR)
      --
      -- P2L inputs
      p2l_valid_i  : in std_logic;
      p2l_dframe_i : in std_logic;
      p2l_data_i   : in std_logic_vector(15 downto 0);

      ---------------------------------------------------------
      -- Core clock domain (SDR)
      --
      -- Deserialized output
      p2l_valid_o  : out std_logic;
      p2l_dframe_o : out std_logic;
      p2l_data_o   : out std_logic_vector(31 downto 0)
      );
end p2l_des;


architecture rtl of p2l_des is


  -----------------------------------------------------------------------------
  -- Components declaration
  -----------------------------------------------------------------------------
  component serdes_1_to_n_data_s2_se
    generic (
      USE_PD : boolean := false;                                    -- Parameter to set generation of phase detector logic
      S      : integer := 2;                                        -- Parameter to set the serdes factor 1..8
      D      : integer := 16) ;                                     -- Set the number of inputs and outputs
    port (
      use_phase_detector : in  std_logic;                           -- Set generation of phase detector logic
      datain             : in  std_logic_vector(D-1 downto 0);      -- Input from se receiver pin
      rxioclk            : in  std_logic;                           -- IO Clock network
      rxserdesstrobe     : in  std_logic;                           -- Parallel data capture strobe
      reset              : in  std_logic;                           -- Reset line
      gclk               : in  std_logic;                           -- Global clock
      bitslip            : in  std_logic;                           -- Bitslip control line
      debug_in           : in  std_logic_vector(1 downto 0);        -- input debug data
      data_out           : out std_logic_vector((D*S)-1 downto 0);  -- Output data
      -- Debug bus, 2D+6 = 2 lines per input (from mux and ce) + 7, leave nc if debug not required
      debug              : out std_logic_vector((2*D)+6 downto 0)) ;
  end component serdes_1_to_n_data_s2_se;

  -----------------------------------------------------------------------------
  -- Comnstants declaration
  -----------------------------------------------------------------------------
  constant S : integer := 2;            -- Set the serdes factor to 2
  constant D : integer := 16;           -- Set the number of inputs and outputs

  -----------------------------------------------------------------------------
  -- Signals declaration
  -----------------------------------------------------------------------------

  -- SDR signals
  signal p2l_valid_t   : std_logic_vector(1 downto 0) := (others => '0');
  signal p2l_dframe_t  : std_logic_vector(1 downto 0) := (others => '0');

begin


  ------------------------------------------------------------------------------
  -- data inputs
  ------------------------------------------------------------------------------
  cmp_data_in : serdes_1_to_n_data_s2_se
    generic map(
      USE_PD => false,
      S      => S,
      D      => D)
    port map (
      use_phase_detector => '0',        -- '1' enables the phase detector logic
      datain             => p2l_data_i,
      rxioclk            => io_clk_i,
      rxserdesstrobe     => serdes_strobe_i,
      gclk               => sys_clk_i,
      bitslip            => '0',
      reset              => rst_a_i,
      data_out           => p2l_data_o,
      debug_in           => "00",
      debug              => open);

  ------------------------------------------------------------------------------
  -- dframe input
  ------------------------------------------------------------------------------
  cmp_dframe_in : serdes_1_to_n_data_s2_se
    generic map(
      USE_PD => false,
      S      => S,
      D      => 1)
    port map (
      use_phase_detector => '0',        -- '1' enables the phase detector logic
      datain(0)          => p2l_dframe_i,
      rxioclk            => io_clk_i,
      rxserdesstrobe     => serdes_strobe_i,
      gclk               => sys_clk_i,
      bitslip            => '0',
      reset              => rst_a_i,
      data_out           => p2l_dframe_t,
      debug_in           => "00",
      debug              => open);

  p2l_dframe_o <= p2l_dframe_t(0);

  ------------------------------------------------------------------------------
  -- valid input
  ------------------------------------------------------------------------------
  cmp_valid_in : serdes_1_to_n_data_s2_se
    generic map(
      USE_PD => false,
      S      => S,
      D      => 1)
    port map (
      use_phase_detector => '0',        -- '1' enables the phase detector logic
      datain(0)          => p2l_valid_i,
      rxioclk            => io_clk_i,
      rxserdesstrobe     => serdes_strobe_i,
      gclk               => sys_clk_i,
      bitslip            => '0',
      reset              => rst_a_i,
      data_out           => p2l_valid_t,
      debug_in           => "00",
      debug              => open);

  p2l_valid_o <= p2l_valid_t(0);

end rtl;
