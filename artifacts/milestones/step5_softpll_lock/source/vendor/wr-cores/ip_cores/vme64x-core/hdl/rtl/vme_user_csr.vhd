--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     vme_user_csr
--
-- description:
--
--   This module implements the user CSR registers that were added to the
--   reserved area of the defined CSR in previous versions of this core.
--
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vme64x_pkg.all;

entity vme_user_csr is
  port (
    clk_i               : in  std_logic;
    rst_n_i             : in  std_logic;

    addr_i              : in  std_logic_vector(18 downto 2);
    data_i              : in  std_logic_vector( 7 downto 0);
    data_o              : out std_logic_vector( 7 downto 0);
    we_i                : in  std_logic;

    irq_vector_o        : out std_logic_vector( 7 downto 0);
    irq_level_o         : out std_logic_vector( 2 downto 0)
  );
end vme_user_csr;

architecture rtl of vme_user_csr is

  signal s_irq_vector   : std_logic_vector(7 downto 0);
  signal s_irq_level    : std_logic_vector(2 downto 0);

  -- Value for unused memory locations
  constant c_UNUSED     : std_logic_vector(7 downto 0) := x"ff";

  -- Addresses
  constant c_IRQ_VECTOR : integer := 16#0002f# / 4;
  constant c_IRQ_LEVEL  : integer := 16#0002b# / 4;
  constant c_ENDIAN     : integer := 16#00023# / 4;
-- Now unused.
--  constant c_TIME0_NS   : integer := 16#0001f# / 4;
--  constant c_TIME1_NS   : integer := 16#0001b# / 4;
--  constant c_TIME2_NS   : integer := 16#00017# / 4;
--  constant c_TIME3_NS   : integer := 16#00013# / 4;
--  constant c_TIME4_NS   : integer := 16#0000f# / 4;
--  constant c_BYTES0     : integer := 16#0000b# / 4;
--  constant c_BYTES1     : integer := 16#00007# / 4;
  constant c_WB32BITS   : integer := 16#00003# / 4;

begin
  -- Write
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        s_irq_vector <= x"00";
        s_irq_level  <= "000";
      else
        if we_i = '1' then
          case to_integer(unsigned(addr_i)) is
            when c_IRQ_VECTOR => s_irq_vector <= data_i;
            when c_IRQ_LEVEL  => s_irq_level  <= data_i(2 downto 0);
            when others       => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  irq_vector_o  <= s_irq_vector;
  irq_level_o   <= s_irq_level;

  -- Read
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        data_o <= x"00";
      else
        case to_integer(unsigned(addr_i)) is
          when c_IRQ_VECTOR => data_o <= s_irq_vector;
          when c_IRQ_LEVEL  => data_o <= "00000" & s_irq_level;
          when c_ENDIAN     => data_o <= x"00";
          when c_WB32BITS   => data_o <= x"01";
          when others       => data_o <= c_UNUSED;
        end case;
      end if;
    end if;
  end process;

end rtl;
