-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Top-Level
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;

library axi_pcie_core;
use axi_pcie_core.MigPkg.all;

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

library nexo_daq_compression;
use nexo_daq_compression.CompressionPkg.all;

library nexo_daq_trigger_decision;
use nexo_daq_trigger_decision.TriggerDecisionPkg.all;

entity RingBufferTop is
   generic (
      TPD_G                     : time    := 1 ns;
      SIMULATION_G              : boolean := false;
      CH_BOND_CLK_IS_CORE_CLK_G : boolean := false;
      TRIG_CLK_IS_CORE_CLK_G    : boolean := false;
      COMP_CLK_IS_CORE_CLK_G    : boolean := false;
      AXIL_CLK_IS_CORE_CLK_G    : boolean := false;
      AXIL_BASE_ADDR_G          : slv(31 downto 0));
   port (
      -- Core Clock/Reset
      coreClk           : in  sl;
      coreRst           : in  sl;
      -- DDR Memory Interface (ddrClk domain)
      ddrClk            : in  slv(3 downto 0);
      ddrRst            : in  slv(3 downto 0);
      ddrWriteMasters   : out AxiWriteMasterArray(3 downto 0);
      ddrWriteSlaves    : in  AxiWriteSlaveArray(3 downto 0);
      ddrReadMasters    : out AxiReadMasterArray(3 downto 0);
      ddrReadSlaves     : in  AxiReadSlaveArray(3 downto 0);
      -- Compression Inbound Interface (compClk domain)
      chBondClk         : in  sl;
      chBondRst         : in  sl;
      chBondMasters     : in  AxiStreamMasterArray(CH_BOND_TO_RING_LANES_C-1 downto 0);
      chBondSlaves      : out AxiStreamSlaveArray(CH_BOND_TO_RING_LANES_C-1 downto 0);
      -- Trigger Decision Interface (trigClk domain)
      trigClk           : in  sl;
      trigRst           : in  sl;
      trigReadoutMaster : in  AxiStreamMasterType;
      trigReadoutSlave  : out AxiStreamSlaveType;
      -- Compression Interface (compClk domain)
      compClk           : in  sl;
      compRst           : in  sl;
      compMasters       : out AxiStreamMasterArray(RING_TO_COMP_LANES_C-1 downto 0);
      compSlaves        : in  AxiStreamSlaveArray(RING_TO_COMP_LANES_C-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk           : in  sl;
      axilRst           : in  sl;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType);
end RingBufferTop;

architecture mapping of RingBufferTop is

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType);

begin

   chBondSlaves     <= (others => AXI_STREAM_SLAVE_FORCE_C);
   trigReadoutSlave <= AXI_STREAM_SLAVE_FORCE_C;
   compMasters      <= (others => AXI_STREAM_MASTER_INIT_C);

   ddrWriteMasters <= (others => AXI_WRITE_MASTER_INIT_C);
   ddrReadMasters  <= (others => AXI_READ_MASTER_INIT_C);

   -----------------------------------------
   -- Convert AXI-Lite bus to coreClk domain
   -----------------------------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => AXIL_CLK_IS_CORE_CLK_G,
         NUM_ADDR_BITS_G => 24)         -- PCIe BAR0 is 24-bits
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => sAxilReadMaster,
         sAxiReadSlave   => sAxilReadSlave,
         sAxiWriteMaster => sAxilWriteMaster,
         sAxiWriteSlave  => sAxilWriteSlave,
         -- Master Interface
         mAxiClk         => coreClk,
         mAxiClkRst      => coreRst,
         mAxiReadMaster  => axilReadMaster,
         mAxiReadSlave   => axilReadSlave,
         mAxiWriteMaster => axilWriteMaster,
         mAxiWriteSlave  => axilWriteSlave);

   axilReadSlave  <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
   axilWriteSlave <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;

end mapping;
