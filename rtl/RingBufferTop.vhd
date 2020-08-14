-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Top-Level (1 RingBufferTop per DDR4 DIMM)
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

library nexo_daq_trigger_decision;
use nexo_daq_trigger_decision.TriggerDecisionPkg.all;

entity RingBufferTop is
   generic (
      TPD_G                  : time                   := 1 ns;
      SIMULATION_G           : boolean                := false;
      ADC_TYPE_G             : boolean                := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      AXIS_SIZE_G            : positive range 1 to 15 := 15;
      ADC_CLK_IS_CORE_CLK_G  : boolean                := true;
      TRIG_CLK_IS_CORE_CLK_G : boolean                := true;
      COMP_CLK_IS_CORE_CLK_G : boolean                := true;
      AXIL_CLK_IS_CORE_CLK_G : boolean                := true;
      AXIL_BASE_ADDR_G       : slv(31 downto 0)       := (others => '0'));
   port (
      -- Core Clock/Reset
      coreClk          : in  sl;
      coreRst          : in  sl;
      -- DDR Memory Interface (ddrClk domain)
      ddrClk           : in  sl;
      ddrRst           : in  sl;
      ddrWriteMaster   : out AxiWriteMasterType;
      ddrWriteSlave    : in  AxiWriteSlaveType;
      ddrReadMaster    : out AxiReadMasterType;
      ddrReadSlave     : in  AxiReadSlaveType;
      -- ADC Streams Interface (adcClk domain, nexoAxisConfig(ADC_TYPE_G))
      adcClk           : in  sl;
      adcRst           : in  sl;
      adcMasters       : in  AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0);
      adcSlaves        : out AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0);
      -- Trigger Decision Interface (trigClk domain, TRIG_DECISION_AXIS_CONFIG_C)
      trigClk          : in  sl;
      trigRst          : in  sl;
      trigRdMaster     : in  AxiStreamMasterType;
      trigRdSlave      : out AxiStreamSlaveType;
      -- Compression Interface (compClk domain, nexoAxisConfig(ADC_TYPE_G))
      compClk          : in  sl;
      compRst          : in  sl;
      compMasters      : out AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0);
      compSlaves       : in  AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end RingBufferTop;

architecture mapping of RingBufferTop is

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIS_SIZE_G-1 downto 0) := genAxiLiteConfig(AXIS_SIZE_G, AXIL_BASE_ADDR_G, 16, 12);

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal axilWriteMasters : AxiLiteWriteMasterArray(AXIS_SIZE_G-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(AXIS_SIZE_G-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(AXIS_SIZE_G-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(AXIS_SIZE_G-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal trigMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal trigSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal trigMasters : AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal trigSlaves  : AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal chMasters : AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal chSlaves  : AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal cpMasters : AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cpSlaves  : AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal axiWriteMasters : AxiWriteMasterArray(23 downto 0) := (others => AXI_WRITE_MASTER_INIT_C);
   signal axiWriteSlaves  : AxiWriteSlaveArray(23 downto 0)  := (others => AXI_WRITE_SLAVE_INIT_C);
   signal axiReadMasters  : AxiReadMasterArray(23 downto 0)  := (others => AXI_READ_MASTER_INIT_C);
   signal axiReadSlaves   : AxiReadSlaveArray(23 downto 0)   := (others => AXI_READ_SLAVE_INIT_C);

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
         NUM_MASTER_SLOTS_G => AXIS_SIZE_G,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => coreClk,
         axiClkRst           => coreRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

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
            sAxisMaster => trigRdMaster,
            sAxisSlave  => trigRdSlave,
            -- Master Port
            mAxisClk    => coreClk,
            mAxisRst    => coreRst,
            mAxisMaster => trigMaster,
            mAxisSlave  => trigSlave);
   end generate;

   SYNC_TRIG : if (TRIG_CLK_IS_CORE_CLK_G = true) generate
      trigMaster  <= trigRdMaster;
      trigRdSlave <= trigSlave;
   end generate;

   ----------------------
   -- AXI Stream Repeater
   ----------------------
   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => AXIS_SIZE_G,
         INPUT_PIPE_STAGES_G  => 1,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk      => coreClk,
         axisRst      => coreRst,
         -- Slave
         sAxisMaster  => trigMaster,
         sAxisSlave   => trigSlave,
         -- Masters
         mAxisMasters => trigMasters,
         mAxisSlaves  => trigSlaves);

   GEN_ENGINE_VEC :
   for i in AXIS_SIZE_G-1 downto 0 generate

      ASYNC_CH : if (ADC_CLK_IS_CORE_CLK_G = false) generate
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
               SLAVE_AXI_CONFIG_G  => nexoAxisConfig(ADC_TYPE_G),
               MASTER_AXI_CONFIG_G => nexoAxisConfig(ADC_TYPE_G))
            port map (
               -- Slave Port
               sAxisClk    => trigClk,
               sAxisRst    => trigRst,
               sAxisMaster => adcMasters(i),
               sAxisSlave  => adcSlaves(i),
               -- Master Port
               mAxisClk    => coreClk,
               mAxisRst    => coreRst,
               mAxisMaster => chMasters(i),
               mAxisSlave  => chSlaves(i));
      end generate;

      SYNC_CH : if (ADC_CLK_IS_CORE_CLK_G = true) generate
         chMasters(i) <= adcMasters(i);
         adcSlaves(i) <= chSlaves(i);
      end generate;

      ---------------------
      -- Ring Buffer Engine
      ---------------------
      U_Engine : entity nexo_daq_ring_buffer.RingBufferEngine
         generic map (
            TPD_G            => TPD_G,
            SIMULATION_G     => SIMULATION_G,
            ADC_TYPE_G       => ADC_TYPE_G,
            STREAM_INDEX_G   => i,
            AXIL_BASE_ADDR_G => AXIL_CONFIG_C(i).baseAddr)
         port map (
            -- Clock and Reset
            clk             => coreClk,
            rst             => coreRst,
            -- Compression Inbound Interface
            adcMaster       => chMasters(i),
            adcSlave        => chSlaves(i),
            -- Trigger Decision Interface
            trigRdMaster    => trigMasters(i),
            trigRdSlave     => trigSlaves(i),
            -- Compression Interface
            compMaster      => cpMasters(i),
            compSlave       => cpSlaves(i),
            -- AXI4 Interface
            axiWriteMaster  => axiWriteMasters(i),
            axiWriteSlave   => axiWriteSlaves(i),
            axiReadMaster   => axiReadMasters(i),
            axiReadSlave    => axiReadSlaves(i),
            -- AXI-Lite Interface
            axilReadMaster  => axilReadMasters(i),
            axilReadSlave   => axilReadSlaves(i),
            axilWriteMaster => axilWriteMasters(i),
            axilWriteSlave  => axilWriteSlaves(i));

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
               SLAVE_AXI_CONFIG_G  => nexoAxisConfig(ADC_TYPE_G),
               MASTER_AXI_CONFIG_G => nexoAxisConfig(ADC_TYPE_G))
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

      SYNC_COMP : if (COMP_CLK_IS_CORE_CLK_G = true) generate
         compMasters(i) <= cpMasters(i);
         cpSlaves(i)    <= compSlaves(i);
      end generate;

   end generate GEN_ENGINE_VEC;

   -----------------------
   -- AXI4 Memory Crossbar
   -----------------------
   U_AxiXbar : entity nexo_daq_ring_buffer.RingBufferAxiXbarWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Interconnect Clock/Reset
         aclk             => coreClk,
         arst             => coreRst,
         -- Slaves
         sAxiClk          => coreClk,
         sAxiWriteMasters => axiWriteMasters,
         sAxiWriteSlaves  => axiWriteSlaves,
         sAxiReadMasters  => axiReadMasters,
         sAxiReadSlaves   => axiReadSlaves,
         -- Master
         mAxiClk          => ddrClk,
         mAxiWriteMaster  => ddrWriteMaster,
         mAxiWriteSlave   => ddrWriteSlave,
         mAxiReadMaster   => ddrReadMaster,
         mAxiReadSlave    => ddrReadSlave);

end mapping;
