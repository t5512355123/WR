-- WR system clock generator for the DE5a diagnostic design.
-- The WR core and firmware use a 62.5 MHz system clock. This wrapper
-- derives that clock from the DE5a 50 MHz oscillator.

library ieee;
use ieee.std_logic_1164.all;

entity wr_sys_clk_625 is
  port (
    i_clk_50  : in  std_logic;
    i_reset_n : in  std_logic;
    o_clk_625 : out std_logic;
    o_locked  : out std_logic
  );
end entity wr_sys_clk_625;

architecture rtl of wr_sys_clk_625 is
  component altpll
    generic (
      bandwidth_type          : string;
      clk0_divide_by          : natural;
      clk0_duty_cycle         : natural;
      clk0_multiply_by        : natural;
      clk0_phase_shift        : string;
      clk1_divide_by          : natural;
      clk1_duty_cycle         : natural;
      clk1_multiply_by        : natural;
      clk1_phase_shift        : string;
      compensate_clock        : string;
      inclk0_input_frequency  : natural;
      intended_device_family  : string;
      lpm_hint                : string;
      lpm_type                : string;
      operation_mode          : string;
      pll_type                : string;
      port_activeclock        : string;
      port_areset             : string;
      port_clkbad0            : string;
      port_clkbad1            : string;
      port_clkloss            : string;
      port_clkswitch          : string;
      port_configupdate       : string;
      port_fbin               : string;
      port_fbout              : string;
      port_locked             : string;
      port_pfdena             : string;
      port_phasecounterselect : string;
      port_phasedone          : string;
      port_phasestep          : string;
      port_phaseupdown        : string;
      port_pllena             : string;
      port_scanaclr           : string;
      port_scanclk            : string;
      port_scanclkena         : string;
      port_scandata           : string;
      port_scandataout        : string;
      port_scandone           : string;
      port_scanread           : string;
      port_scanwrite          : string;
      port_clk0               : string;
      port_clk1               : string;
      port_clk2               : string;
      port_clk3               : string;
      port_clk4               : string;
      port_clk5               : string;
      port_clk6               : string;
      port_clk7               : string;
      port_clk8               : string;
      port_clk9               : string;
      port_clkena0            : string;
      port_clkena1            : string;
      port_clkena2            : string;
      port_clkena3            : string;
      port_clkena4            : string;
      port_clkena5            : string;
      self_reset_on_loss_lock : string;
      using_fbmimicbidir_port : string;
      width_clock             : natural
    );
    port (
      areset : in  std_logic;
      clk    : out std_logic_vector(6 downto 0);
      inclk  : in  std_logic_vector(1 downto 0);
      locked : out std_logic
    );
  end component;

  signal pll_clk : std_logic_vector(6 downto 0);
  signal pll_in  : std_logic_vector(1 downto 0);
begin
  pll_in <= '0' & i_clk_50;
  o_clk_625 <= pll_clk(0);

  u_altpll : altpll
    generic map (
      bandwidth_type          => "AUTO",
      clk0_divide_by          => 4,
      clk0_duty_cycle         => 50,
      clk0_multiply_by        => 5,
      clk0_phase_shift        => "0",
      clk1_divide_by          => 1,
      clk1_duty_cycle         => 50,
      clk1_multiply_by        => 1,
      clk1_phase_shift        => "0",
      compensate_clock        => "CLK0",
      inclk0_input_frequency  => 20000,
      intended_device_family  => "Arria 10",
      lpm_hint                => "CBX_MODULE_PREFIX=wr_sys_clk_625",
      lpm_type                => "altpll",
      operation_mode          => "NORMAL",
      pll_type                => "AUTO",
      port_activeclock        => "PORT_UNUSED",
      port_areset             => "PORT_USED",
      port_clkbad0            => "PORT_UNUSED",
      port_clkbad1            => "PORT_UNUSED",
      port_clkloss            => "PORT_UNUSED",
      port_clkswitch          => "PORT_UNUSED",
      port_configupdate       => "PORT_UNUSED",
      port_fbin               => "PORT_UNUSED",
      port_fbout              => "PORT_UNUSED",
      port_locked             => "PORT_USED",
      port_pfdena             => "PORT_UNUSED",
      port_phasecounterselect => "PORT_UNUSED",
      port_phasedone          => "PORT_UNUSED",
      port_phasestep          => "PORT_UNUSED",
      port_phaseupdown        => "PORT_UNUSED",
      port_pllena             => "PORT_UNUSED",
      port_scanaclr           => "PORT_UNUSED",
      port_scanclk            => "PORT_UNUSED",
      port_scanclkena         => "PORT_UNUSED",
      port_scandata           => "PORT_UNUSED",
      port_scandataout        => "PORT_UNUSED",
      port_scandone           => "PORT_UNUSED",
      port_scanread           => "PORT_UNUSED",
      port_scanwrite          => "PORT_UNUSED",
      port_clk0               => "PORT_USED",
      port_clk1               => "PORT_UNUSED",
      port_clk2               => "PORT_UNUSED",
      port_clk3               => "PORT_UNUSED",
      port_clk4               => "PORT_UNUSED",
      port_clk5               => "PORT_UNUSED",
      port_clk6               => "PORT_UNUSED",
      port_clk7               => "PORT_UNUSED",
      port_clk8               => "PORT_UNUSED",
      port_clk9               => "PORT_UNUSED",
      port_clkena0            => "PORT_UNUSED",
      port_clkena1            => "PORT_UNUSED",
      port_clkena2            => "PORT_UNUSED",
      port_clkena3            => "PORT_UNUSED",
      port_clkena4            => "PORT_UNUSED",
      port_clkena5            => "PORT_UNUSED",
      self_reset_on_loss_lock => "OFF",
      using_fbmimicbidir_port => "OFF",
      width_clock             => 7
    )
    port map (
      areset => not i_reset_n,
      clk    => pll_clk,
      inclk  => pll_in,
      locked => o_locked
    );
end architecture rtl;
