-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Top-Level (1 RingBufferAxiXbar per DDR4 DIMM)
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
use surf.AxiPkg.all;

library nexo_daq_ring_buffer;

entity RingBufferAxiXbar is
   generic (
      TPD_G       : time                  := 1 ns;
      AXIS_SIZE_G : positive range 1 to 8 := 8);
   port (
      -- Application AXI4 Interface (coreClk domain)
      coreClk          : in  sl;
      coreRst          : in  sl;
      sAxiWriteMasters : in  AxiWriteMasterArray(29 downto 0);
      sAxiWriteSlaves  : out AxiWriteSlaveArray(29 downto 0);
      sAxiReadMasters  : in  AxiReadMasterArray(29 downto 0);
      sAxiReadSlaves   : out AxiReadSlaveArray(29 downto 0);
      -- DDR Memory Interface (ddrClk domain)
      ddrClk           : in  sl;
      ddrRst           : in  sl;
      ddrWriteMaster   : out AxiWriteMasterType;
      ddrWriteSlave    : in  AxiWriteSlaveType;
      ddrReadMaster    : out AxiReadMasterType;
      ddrReadSlave     : in  AxiReadSlaveType);
end RingBufferAxiXbar;

architecture mapping of RingBufferAxiXbar is

begin

   GEN_7_STREAM : if (AXIS_SIZE_G < 8) generate

      U_AxiXbar : entity nexo_daq_ring_buffer.RingBufferAxiXbar7to1Wrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Slaves
            sAxiClk          => coreClk,
            sAxiRst          => coreRst,
            sAxiWriteMasters => sAxiWriteMasters(6 downto 0),
            sAxiWriteSlaves  => sAxiWriteSlaves(6 downto 0),
            sAxiReadMasters  => sAxiReadMasters(6 downto 0),
            sAxiReadSlaves   => sAxiReadSlaves(6 downto 0),
            -- Master
            mAxiClk          => ddrClk,
            mAxiRst          => ddrRst,
            mAxiWriteMaster  => ddrWriteMaster,
            mAxiWriteSlave   => ddrWriteSlave,
            mAxiReadMaster   => ddrReadMaster,
            mAxiReadSlave    => ddrReadSlave);

   end generate;

   GEN_8_STREAM : if (AXIS_SIZE_G = 8) generate

      U_AxiXbar : entity nexo_daq_ring_buffer.RingBufferAxiXbar8to1Wrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Slaves
            sAxiClk          => coreClk,
            sAxiRst          => coreRst,
            sAxiWriteMasters => sAxiWriteMasters(7 downto 0),
            sAxiWriteSlaves  => sAxiWriteSlaves(7 downto 0),
            sAxiReadMasters  => sAxiReadMasters(7 downto 0),
            sAxiReadSlaves   => sAxiReadSlaves(7 downto 0),
            -- Master
            mAxiClk          => ddrClk,
            mAxiRst          => ddrRst,
            mAxiWriteMaster  => ddrWriteMaster,
            mAxiWriteSlave   => ddrWriteSlave,
            mAxiReadMaster   => ddrReadMaster,
            mAxiReadSlave    => ddrReadSlave);

   end generate;

end mapping;
