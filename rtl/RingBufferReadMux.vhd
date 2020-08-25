-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer's Read MUX
-------------------------------------------------------------------------------
-- Data Format Definitions: https://docs.google.com/spreadsheets/d/1EdbgGU8szjVyl3ZKYMZXtHn6p-MUJLZG59m6oqJuD-0/edit?usp=sharing
-------------------------------------------------------------------------------
-- This file is part of 'nexo-daq-ring-buffer'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'nexo-daq-ring-buffer', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity RingBufferReadMux is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl;
      -- Inbound Interface
      compMasters : in  AxiStreamMasterArray(1 downto 0);
      compSlaves  : out AxiStreamSlaveArray(1 downto 0);
      -- Outbound Interface
      compMaster  : out AxiStreamMasterType;
      compSlave   : in  AxiStreamSlaveType);
end RingBufferReadMux;

architecture rtl of RingBufferReadMux is

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      idx        : natural range 0 to 1;
      compSlaves : AxiStreamSlaveArray(1 downto 0);
      compMaster : AxiStreamMasterType;
      state      : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      idx        => 0,
      compSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      compMaster => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (compMasters, compSlave, r, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- AXI Stream Flow Control
      for i in 0 to 1 loop
         v.compSlaves(i).tReady := '0';
      end loop;
      if (compSlave.tReady = '1') then
         v.compMaster.tValid := '0';
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            for i in 0 to 1 loop

               -- Check for data
               if (compMasters(i).tValid = '1') then

                  -- Set the stream index
                  v.idx := i;

                  -- Next state
                  v.state := MOVE_S;

               end if;

            end loop;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (compMasters(i).tValid = '1') and (r.compMaster.tValid = '0') then

               -- Accept the data
               v.compSlaves(r.idx).tReady := '1';

               -- Move the data
               v.compMaster := compMasters(r.idx);

               -- Check for frame termination
               if (compMasters(r.idx).tLast = '1') then

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      compSlaves <= v.compSlaves;       -- comb (not registered) output
      compMaster <= r.compMaster;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
