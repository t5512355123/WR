library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity oserdes_4_to_1 is
generic
 (-- width of the data for the system
  sys_w       : integer := 1;
  -- width of the data for the device
  dev_w       : integer := 4);
port
 (
  -- from the device out to the system
  data_out_from_device    : in  std_logic_vector(dev_w-1 downto 0);
  data_out_to_pins        : out std_logic_vector(sys_w-1 downto 0);

-- input, output delay control signals
  delay_reset             : in  std_logic;                    -- active high synchronous reset for input delay
 
-- clock and reset signals
  clk_in                  : in  std_logic;                     
  pll_locked              : in  std_logic;
  clk_div_in              : in  std_logic;                    
  io_reset                : in  std_logic);                   -- reset signal for io circuit
end oserdes_4_to_1;

architecture xilinx of oserdes_4_to_1 is

  constant num_serial_bits     : integer := dev_w/sys_w;
  signal ioclk : std_logic;
  
  type serdarr is array (0 to 3) of std_logic_vector(sys_w-1 downto 0);
  -- array to use intermediately from the serdes to the internal
  --  devices. bus "0" is the leftmost bus
   --  * fills in from higher order
  signal oserdes_d             : serdarr := (( others => (others => '0')));
  signal serdesstrobe : std_logic;

  -- delay ctrl
  signal data_out_to_pins_predelay : std_logic_vector(sys_w-1 downto 0);
  signal data_delay                : std_logic_vector(sys_w-1 downto 0); 
  type loadarr is array (0 to 15) of std_logic_vector(4 downto 0);
  signal intap                 : loadarr := (( others => (others => '0')));
  signal outtap                : loadarr := (( others => (others => '0')));

begin
  
  bufpll_inst : bufpll
  generic map (
    divide => 4,         -- divclk divider (1-8)
    enable_sync => true  -- enable synchrnonization between pll and gclk (true/false)
  )
  port map (
    ioclk => ioclk,               -- 1-bit output: output i/o clock
    lock => open,                 -- 1-bit output: synchronized lock output
    serdesstrobe => serdesstrobe, -- 1-bit output: output serdes strobe (connect to iserdes2/oserdes2)
    gclk => clk_div_in,                 -- 1-bit input: bufg clock input
    locked => pll_locked,             -- 1-bit input: locked input from pll
    pllin => clk_in                -- 1-bit input: clock input from pll
  );

  -- we have multiple bits- step over every bit, instantiating the required elements
  pins: for pin_count in 0 to sys_w-1 generate 
  begin
    
    data_out_to_pins(pin_count) <= data_delay(pin_count);    
    iodelay2_inst : iodelay2
    generic map (
       counter_wraparound => "wraparound", -- "stay_at_limit" or "wraparound" 
       data_rate => "sdr",                 -- "sdr" or "ddr" 
       delay_src => "odatain",                  -- "io", "odatain" or "idatain" 
       idelay2_value => 0,                 -- delay value when idelay_mode="pci" (0-255)
       idelay_mode => "normal",            -- "normal" or "pci" 
       idelay_type => "default",           -- "fixed", "default", "variable_from_zero", "variable_from_half_max" 
                                           -- or "diff_phase_detector" 
       idelay_value => 0,                  -- amount of taps for fixed input delay (0-255)
       odelay_value => 33,                  -- amount of taps fixed output delay (0-255)
       serdes_mode => "none",              -- "none", "master" or "slave" 
       sim_tapdelay_value => 75            -- per tap delay used for simulation in ps
    )
    port map (
       busy => open, -- 1-bit output: busy output after cal
       dataout => open,  -- 1-bit output: delayed data output to iserdes/input register
       dataout2 => open, -- 1-bit output: delayed data output to general fpga fabric
       dout => data_delay(pin_count), -- 1-bit output: delayed data output
       tout => open,     -- 1-bit output: delayed 3-state output
       cal => '0',           -- 1-bit input: initiate calibration input
       ce => '0', -- 1-bit input: enable inc input
       clk => clk_div_in,         -- 1-bit input: clock input
       idatain => '0',   -- 1-bit input: data input (connect to top-level port or i/o buffer)
       inc => '0', -- 1-bit input: increment / decrement input
       ioclk0 => ioclk,     -- 1-bit input: input from the i/o clock network
       ioclk1 => '0',     -- 1-bit input: input from the i/o clock network
       odatain => data_out_to_pins_predelay(pin_count), -- 1-bit input: output data input from output register or oserdes2.
       rst => delay_reset,   -- 1-bit input: reset to zero or 1/2 of total delay period
       t => '0'              -- 1-bit input: 3-state input signal
    );

    -- instantiate the serdes primitive
    -- declare the oserdes
    oserdes2_inst : oserdes2
    generic map (
       bypass_gclk_ff => false,       -- bypass clkdiv syncronization registers (true/false)
       data_rate_oq => "sdr",         -- output data rate ("sdr" or "ddr")
       data_rate_ot => "sdr",         -- 3-state data rate ("sdr" or "ddr")
       data_width => 4,               -- parallel data width (2-8)
       output_mode => "single_ended", -- "single_ended" or "differential" 
       serdes_mode => "none",         -- "none", "master" or "slave" 
       train_pattern => 0             -- training pattern (0-15)
    )
    port map (
       oq => data_out_to_pins_predelay(pin_count), -- 1-bit output: data output to pad or iodelay2
       shiftout1 => open, -- 1-bit output: cascade data output
       shiftout2 => open, -- 1-bit output: cascade 3-state output
       shiftout3 => open, -- 1-bit output: cascade differential data output
       shiftout4 => open, -- 1-bit output: cascade differential 3-state output
       tq => open,               -- 1-bit output: 3-state output to pad or iodelay2
       clk0 => ioclk,           -- 1-bit input: i/o clock input
       clk1 => '0',           -- 1-bit input: secondary i/o clock input
       clkdiv => clk_div_in,       -- 1-bit input: logic domain clock input
       -- d1 - d4: 1-bit (each) input: parallel data inputs
       d1 => oserdes_d(3)(pin_count),
       d2 => oserdes_d(2)(pin_count),
       d3 => oserdes_d(1)(pin_count),
       d4 => oserdes_d(0)(pin_count),
       ioce => serdesstrobe,           -- 1-bit input: data strobe input
       oce => '1',             -- 1-bit input: clock enable input
       rst => io_reset,             -- 1-bit input: asynchrnous reset input
       shiftin1 => '1',   -- 1-bit input: cascade data input
       shiftin2 => '1',   -- 1-bit input: cascade 3-state input
       shiftin3 => '1',   -- 1-bit input: cascade differential data input
       shiftin4 => '1',   -- 1-bit input: cascade differential 3-state input
       -- t1 - t4: 1-bit (each) input: 3-state control inputs
       t1 => '0',
       t2 => '0',
       t3 => '0',
       t4 => '0',
       tce => '0',           -- 1-bit input: 3-state clock enable input
       train => '0'          -- 1-bit input: training pattern enable input
    );

    out_slices: for slice_count in 0 to num_serial_bits-1 generate begin
        -- this places the first data in time on the right
        oserdes_d(4-slice_count-1)(pin_count) <=
           data_out_from_device(slice_count);
        -- to place the first data in time on the left, use the
        --   following code, instead
        -- oserdes_d(slice_count) <=
        --    data_out_from_device(slice_count);

     end generate out_slices;

  end generate pins;

end xilinx;



