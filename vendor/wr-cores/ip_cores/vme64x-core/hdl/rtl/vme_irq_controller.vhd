--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     vme_irq_controller
--
-- description:
--
--   This block implements the interrupt controller. It passes the interrupt
--   pulse from WB to the corresponding IRQ signal on the VME bus, until
--   the interrupt is acknowledged by the VME master.
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

entity vme_irq_controller is
  generic (
    g_RETRY_TIMEOUT : integer range 1024 to 16777215
  );
  port (
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;
    int_level_i     : in  std_logic_vector (2 downto 0);
    int_req_i       : in  std_logic;

    -- Set when an irq is pending (not yet acknowledged).
    irq_pending_o   : out std_logic;

    irq_ack_i       : in  std_logic;
    vme_irq_n_o     : out std_logic_vector (7 downto 1)
  );
end vme_irq_controller;

architecture rtl of vme_irq_controller is

  type t_retry_state is (WAIT_IRQ, WAIT_RETRY);

  signal retry_state      : t_retry_state;
  signal retry_count      : unsigned(23 downto 0);
  signal retry_mask       : std_logic;
  signal s_irq_pending    : std_logic;
begin
  irq_pending_o <= s_irq_pending;

  -- Interrupts are automatically masked for g_RETRY_TIMEOUT (i.e. 1 ms) once
  -- they are acknowledged by the interrupt handler until they are deasserted
  -- by the interrupter.
  p_retry_fsm : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        retry_mask  <= '1';
        retry_state <= WAIT_IRQ;
      else
        case retry_state is
          when WAIT_IRQ =>
            if s_irq_pending = '1' and int_req_i = '1' then
              retry_state <= WAIT_RETRY;
              retry_count <= (others => '0');
              retry_mask  <= '0';
            else
              retry_mask  <= '1';
            end if;

          when WAIT_RETRY =>
            if int_req_i = '0' then
              retry_state <= WAIT_IRQ;
            else
              retry_count <= retry_count + 1;
              if retry_count = g_RETRY_TIMEOUT then
                retry_state <= WAIT_IRQ;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  p_main : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        vme_irq_n_o     <= (others => '1');
        s_irq_pending   <= '0';
      else
        if s_irq_pending = '0' then
          vme_irq_n_o     <= (others => '1');

          if int_req_i = '1' and retry_mask = '1' then
            s_irq_pending <= '1';

            -- Explicit decoding
            case int_level_i is
              when "001" =>  vme_irq_n_o <= "1111110";
              when "010" =>  vme_irq_n_o <= "1111101";
              when "011" =>  vme_irq_n_o <= "1111011";
              when "100" =>  vme_irq_n_o <= "1110111";
              when "101" =>  vme_irq_n_o <= "1101111";
              when "110" =>  vme_irq_n_o <= "1011111";
              when "111" =>  vme_irq_n_o <= "0111111";
              when others =>
                --  Incorrect value for int_level_i, ignore it.
                vme_irq_n_o <= "1111111";
                s_irq_pending <= '0';
            end case;
          end if;
        else
          if irq_ack_i = '1' then
            s_irq_pending  <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;
