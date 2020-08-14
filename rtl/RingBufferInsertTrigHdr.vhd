-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Inserts the trigger header into the inbound compression stream
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

entity RingBufferInsertTrigHdr is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      clk           : in  sl;
      rst           : in  sl;
      -- Trigger Header
      trigHdrMaster : in  AxiStreamMasterType;
      trigHdrSlave  : out AxiStreamSlaveType;
      -- Slave Port
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);
end RingBufferInsertTrigHdr;

architecture rtl of RingBufferInsertTrigHdr is

   type StateType is (
      IDLE_S,
      INSERT_S,
      MOVE_S);

   type RegType is record
      trigHdrSlave : AxiStreamSlaveType;
      sAxisSlave   : AxiStreamSlaveType;
      mAxisMaster  : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      trigHdrSlave => AXI_STREAM_SLAVE_INIT_C,
      sAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      mAxisMaster  => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (mAxisSlave, r, rst, sAxisMaster, trigHdrMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- AXI stream Flow Control
      v.trigHdrSlave.tReady := '0';
      v.sAxisSlave.tReady   := '0';
      if mAxisSlave.tReady = '1' then
         v.mAxisMaster.tValid := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Wait for both streams
            if (sAxisMaster.tValid = '1') and (trigHdrMaster.tValid = '1') then
               -- Next state
               v.state := INSERT_S;
            end if;
         ----------------------------------------------------------------------
         when INSERT_S =>
            -- Check if ready to move data
            if (v.mAxisMaster.tValid = '0') and (trigHdrMaster.tValid = '1') then

               -- Accept the data
               v.trigHdrSlave.tReady := '1';

               -- Copy the metadata from inbound stream
               v.mAxisMaster := sAxisMaster;

               -- Overwrite the tdata field
               v.mAxisMaster.tData := trigHdrMaster.tData;

               -- Check for EOF
               if (trigHdrMaster.tLast = '1') then
                  -- Next state
                  v.state := MOVE_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.mAxisMaster.tValid = '0') and (sAxisMaster.tValid = '1') then

               -- Accept the data
               v.sAxisSlave.tReady := '1';

               -- Move the data
               v.mAxisMaster := sAxisMaster;

               -- Check for EOF
               if (sAxisMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      trigHdrSlave <= v.trigHdrSlave;
      sAxisSlave   <= v.sAxisSlave;
      mAxisMaster  <= r.mAxisMaster;

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
