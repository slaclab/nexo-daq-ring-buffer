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
      chBondMasters     : in  AxiStreamMasterArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0);
      chBondSlaves      : out AxiStreamSlaveArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0);
      -- Trigger Decision Interface (trigClk domain)
      trigClk           : in  sl;
      trigRst           : in  sl;
      trigReadoutMaster : in  AxiStreamMasterType;
      trigReadoutSlave  : out AxiStreamSlaveType;
      -- Compression Interface (compClk domain)
      compClk           : in  sl;
      compRst           : in  sl;
      compMasters       : out AxiStreamMasterArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0);
      compSlaves        : in  AxiStreamSlaveArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk           : in  sl;
      axilRst           : in  sl;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType);
end RingBufferTop;

architecture mapping of RingBufferTop is

   constant NUM_AXIL_MASTERS_C : positive := (6*16);  -- 96 = 6 x 16 > NUM_SYSTEM_COMP_ENGINE_C

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 20, 12);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal writeMasters : AxiLiteWriteMasterArray(5 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal writeSlaves  : AxiLiteWriteSlaveArray(5 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal readMasters  : AxiLiteReadMasterArray(5 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal readSlaves   : AxiLiteReadSlaveArray(5 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal axiWriteMasters : AxiWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_WRITE_MASTER_INIT_C);
   signal axiWriteSlaves  : AxiWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_WRITE_SLAVE_INIT_C);
   signal axiReadMasters  : AxiReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_READ_MASTER_INIT_C);
   signal axiReadSlaves   : AxiReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)   := (others => AXI_READ_SLAVE_INIT_C);

   signal trigRdMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal trigRdSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal trigRdMasters : AxiStreamMasterArray(5 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal trigRdSlaves  : AxiStreamSlaveArray(5 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal trigMasters : AxiStreamMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal trigSlaves  : AxiStreamSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal chMasters : AxiStreamMasterArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal chSlaves  : AxiStreamSlaveArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal cpMasters : AxiStreamMasterArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cpSlaves  : AxiStreamSlaveArray(NUM_SYSTEM_COMP_ENGINE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

begin

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

   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 6,
         MASTERS_CONFIG_G   => genAxiLiteConfig(6, AXIL_BASE_ADDR_G, 20, 16))
      port map (
         axiClk              => coreClk,
         axiClkRst           => coreRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => writeMasters,
         mAxiWriteSlaves     => writeSlaves,
         mAxiReadMasters     => readMasters,
         mAxiReadSlaves      => readSlaves);

   ---------------------------------------------
   -- Convert AXI stream buses to coreClk domain
   ---------------------------------------------
   ASYNC_TRIG : if (TRIG_CLK_IS_CORE_CLK_G = false) generate
      U_ASYNC_FIFO : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => 0,
            -- FIFO configurations
            MEMORY_TYPE_G       => "distributed",
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 5,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => TRIG_DECISION_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => TRIG_DECISION_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => trigClk,
            sAxisRst    => trigRst,
            sAxisMaster => trigReadoutMaster,
            sAxisSlave  => trigReadoutSlave,
            -- Master Port
            mAxisClk    => coreClk,
            mAxisRst    => coreRst,
            mAxisMaster => trigRdMaster,
            mAxisSlave  => trigRdSlave);
   end generate;

   SYNC_TRIG : if (TRIG_CLK_IS_CORE_CLK_G = true) generate
      trigRdMaster     <= trigReadoutMaster;
      trigReadoutSlave <= trigRdSlave;
   end generate;

   ----------------------
   -- AXI Stream Repeater
   ----------------------
   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => 6,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk      => coreClk,
         axisRst      => coreRst,
         -- Slave
         sAxisMaster  => trigRdMaster,
         sAxisSlave   => trigRdSlave,
         -- Masters
         mAxisMasters => trigRdMasters,
         mAxisSlaves  => trigRdSlaves);

   --------------------------
   -- Bus Expanders/Repeaters
   --------------------------
   GEN_SUB :
   for i in 5 downto 0 generate

      U_XBAR : entity surf.AxiLiteCrossbar
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => 16,
            MASTERS_CONFIG_G   => genAxiLiteConfig(16, AXIL_CONFIG_C(i*16).baseAddr, 16, 12))
         port map (
            axiClk              => coreClk,
            axiClkRst           => coreRst,
            sAxiWriteMasters(0) => writeMasters(i),
            sAxiWriteSlaves(0)  => writeSlaves(i),
            sAxiReadMasters(0)  => readMasters(i),
            sAxiReadSlaves(0)   => readSlaves(i),
            mAxiWriteMasters    => axilWriteMasters(i*16+15 downto i*16),
            mAxiWriteSlaves     => axilWriteSlaves(i*16+15 downto i*16),
            mAxiReadMasters     => axilReadMasters(i*16+15 downto i*16),
            mAxiReadSlaves      => axilReadSlaves(i*16+15 downto i*16));

      U_Repeater : entity surf.AxiStreamRepeater
         generic map (
            TPD_G                => TPD_G,
            NUM_MASTERS_G        => 6,
            INPUT_PIPE_STAGES_G  => 0,
            OUTPUT_PIPE_STAGES_G => 1)
         port map (
            -- Clock and reset
            axisClk      => coreClk,
            axisRst      => coreRst,
            -- Slave
            sAxisMaster  => trigRdMasters(i),
            sAxisSlave   => trigRdSlaves(i),
            -- Masters
            mAxisMasters => trigMasters(i*16+15 downto i*16),
            mAxisSlaves  => trigSlaves(i*16+15 downto i*16));

   end generate GEN_SUB;

   GEN_ENGINE_VEC :
   for i in NUM_SYSTEM_COMP_ENGINE_C-1 downto 0 generate

      ASYNC_CH : if (CH_BOND_CLK_IS_CORE_CLK_G = false) generate
         U_ASYNC_FIFO : entity surf.AxiStreamFifoV2
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => 0,
               PIPE_STAGES_G       => 0,
               -- FIFO configurations
               MEMORY_TYPE_G       => "distributed",
               GEN_SYNC_FIFO_G     => false,
               FIFO_ADDR_WIDTH_G   => 5,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => TRIG_DECISION_AXIS_CONFIG_C,
               MASTER_AXI_CONFIG_G => TRIG_DECISION_AXIS_CONFIG_C)
            port map (
               -- Slave Port
               sAxisClk    => trigClk,
               sAxisRst    => trigRst,
               sAxisMaster => chBondMasters(i),
               sAxisSlave  => chBondSlaves(i),
               -- Master Port
               mAxisClk    => coreClk,
               mAxisRst    => coreRst,
               mAxisMaster => chMasters(i),
               mAxisSlave  => chSlaves(i));
      end generate;

      ASYNC_CH : if (CH_BOND_CLK_IS_CORE_CLK_G = true) generate
         chMasters(i)    <= chBondMasters(i);
         chBondSlaves(i) <= chSlaves(i);
      end generate;

      U_Engine : entity nexo_daq_ring_buffer.RingBufferEngine
         generic map (
            TPD_G        => TPD_G,
            SIMULATION_G => SIMULATION_G)
         port map (
            clk               => coreClk,
            rst               => coreRst,
            -- Compression Inbound Interface
            chBondMaster      => chMasters(i),
            chBondSlave       => chSlaves(i),
            -- Trigger Decision Interface
            trigReadoutMaster => trigMasters(i),
            trigReadoutSlave  => trigSlaves(i),
            -- Compression Interface
            compMaster        => cpMasters(i),
            compSlave         => cpSlaves(i),
            -- AXI4 Interface
            axiWriteMaster    => axiWriteMasters(i),
            axiWriteSlave     => axiWriteSlaves(i),
            axiReadMaster     => axiReadMasters(i),
            axiReadSlave      => axiReadSlaves(i),
            -- AXI-Lite Interface
            axilReadMaster    => axilReadMasters(i),
            axilReadSlave     => axilReadSlaves(i),
            axilWriteMaster   => axilWriteMasters(i),
            axilWriteSlave    => axilWriteSlaves(i));

      ASYNC_COMP : if (COMP_CLK_IS_CORE_CLK_G = false) generate
         U_ASYNC_FIFO : entity surf.AxiStreamFifoV2
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => 0,
               PIPE_STAGES_G       => 0,
               -- FIFO configurations
               MEMORY_TYPE_G       => "distributed",
               GEN_SYNC_FIFO_G     => false,
               FIFO_ADDR_WIDTH_G   => 5,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => RING_AXIS_CONFIG_G,
               MASTER_AXI_CONFIG_G => COMP_AXIS_CONFIG_C)
            port map (
               -- Slave Port
               sAxisClk    => coreClk,
               sAxisRst    => coreRst,
               sAxisMaster => cpMasters(i),
               sAxisSlave  => cpSlaves(i),
               -- Master Port
               mAxisClk    => compClk,
               mAxisRst    => compRst,
               mAxisMaster => compMasters(i),
               mAxisSlave  => compSlaves(i));
      end generate;

      ASYNC_COMP : if (COMP_CLK_IS_CORE_CLK_G = true) generate

         U_AxiStreamResize : entity surf.AxiStreamResize
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               PIPE_STAGES_G       => 0,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => RING_AXIS_CONFIG_G,
               MASTER_AXI_CONFIG_G => COMP_AXIS_CONFIG_C)
            port map (
               -- Clock and reset
               axisClk     => coreClk,
               axisRst     => coreRst,
               -- Slave Port
               sAxisMaster => cpMasters(i),
               sAxisSlave  => cpSlaves(i),
               -- Master Port
               mAxisMaster => compMasters(i),
               mAxisSlave  => compSlaves(i));

      end generate;

   end generate GEN_ENGINE_VEC;

   GEN_AXI_XBAR :
   for i in 3 downto 0 generate
      U_AxiXbar : entity nexo_daq_ring_buffer.RingBufferAxiXbar
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Application AXI Interface (axiClk domain)
            axiClk          => coreClk,
            axiRst          => coreRst,
            axiWriteMasters => axiWriteMasters(24*i+23 downto 24*i),
            axiWriteSlaves  => axiWriteSlaves(24*i+23 downto 24*i),
            axiReadMasters  => axiReadMasters(24*i+23 downto 24*i),
            axiReadSlaves   => axiReadSlaves(24*i+23 downto 24*i),
            -- DDR Memory Interface (ddrClk domain)
            ddrClk          => ddrClk(i),
            ddrRst          => ddrRst(i),
            ddrWriteMaster  => ddrWriteMasters(i),
            ddrWriteSlave   => ddrWriteSlaves(i),
            ddrReadMaster   => ddrReadMasters(i),
            ddrReadSlave    => ddrReadSlaves(i));
   end generate GEN_AXI_XBAR;

end mapping;
