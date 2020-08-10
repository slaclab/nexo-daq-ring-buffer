-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI Crossbar for all channels
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
      TPD_G : time := 1 ns);
   port (
      -- Application AXI Interface (axiClk domain)
      axiClk          : in  sl;
      axiRst          : in  sl;
      axiWriteMasters : in  AxiWriteMasterArray(23 downto 0);
      axiWriteSlaves  : out AxiWriteSlaveArray(23 downto 0);
      axiReadMasters  : in  AxiReadMasterArray(23 downto 0);
      axiReadSlaves   : out AxiReadSlaveArray(23 downto 0);
      -- DDR Memory Interface (ddrClk domain)
      ddrClk          : in  sl;
      ddrRst          : in  sl;
      ddrWriteMaster  : out AxiWriteMasterType;
      ddrWriteSlave   : in  AxiWriteSlaveType;
      ddrReadMaster   : out AxiReadMasterType;
      ddrReadSlave    : in  AxiReadSlaveType);
end RingBufferAxiXbar;

architecture mapping of RingBufferAxiXbar is

   signal writeMasters : AxiWriteMasterArray(5 downto 0);
   signal writeSlaves  : AxiWriteSlaveArray(5 downto 0);
   signal readMasters  : AxiReadMasterArray(5 downto 0);
   signal readSlaves   : AxiReadSlaveArray(5 downto 0);

begin

   GEN_VEC :
   for i in 5 downto 0 generate

      U_Pre : entity nexo_daq_ring_buffer.RingBufferAxiXbarPreWrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Interconnect Clock/Reset
            aclk             => axiClk,
            arst             => axiRst,
            -- Slaves
            sAxiClk          => axiClk,
            sAxiWriteMasters => axiWriteMasters(4*i+3 downto 4*i),
            sAxiWriteSlaves  => axiWriteSlaves(4*i+3 downto 4*i),
            sAxiReadMasters  => axiReadMasters(4*i+3 downto 4*i),
            sAxiReadSlaves   => axiReadSlaves(4*i+3 downto 4*i),
            -- Master
            mAxiClk          => axiClk,
            mAxiWriteMaster  => writeMasters(i),
            mAxiWriteSlave   => writeSlaves(i),
            mAxiReadMaster   => readMasters(i),
            mAxiReadSlave    => readSlaves(i));

   end generate GEN_VEC;

   U_Post : entity nexo_daq_ring_buffer.RingBufferAxiXbarPostWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Interconnect Clock/Reset
         aclk             => axiClk,
         arst             => axiRst,
         -- Slaves
         sAxiClk          => axiClk,
         sAxiWriteMasters => writeMasters,
         sAxiWriteSlaves  => writeSlaves,
         sAxiReadMasters  => readMasters,
         sAxiReadSlaves   => readSlaves,
         -- Master
         mAxiClk          => ddrClk,
         mAxiWriteMaster  => ddrWriteMaster,
         mAxiWriteSlave   => ddrWriteSlave,
         mAxiReadMaster   => ddrReadMaster,
         mAxiReadSlave    => ddrReadSlave);

end mapping;
