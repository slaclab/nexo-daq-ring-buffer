-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Top-Level (1 RingBufferTop per DDR4 DIMM)
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
      TPD_G                  : time                  := 1 ns;
      SIMULATION_G           : boolean               := false;
      ADC_TYPE_G             : AdcType               := ADC_TYPE_CHARGE_C;
      DDR_DIMM_INDEX_G       : natural               := 0;
      AXIL_XBAR_SIZE_C       : positive range 1 to 8 := 8;
      ADC_CLK_IS_CORE_CLK_G  : boolean               := false;
      TRIG_CLK_IS_CORE_CLK_G : boolean               := false;
      COMP_CLK_IS_CORE_CLK_G : boolean               := false;
      AXIL_CLK_IS_CORE_CLK_G : boolean               := false;
      AXIL_BASE_ADDR_G       : slv(31 downto 0)      := (others => '0'));
   port (
      -- Core Clock/Reset
      coreClk         : in  sl;
      coreRst         : in  sl;
      -- DDR Memory Interface (ddrClk domain)
      ddrClk          : in  slv(3 downto 0);
      ddrRst          : in  slv(3 downto 0);
      ddrWriteMasters : out AxiWriteMasterArray(3 downto 0);
      ddrWriteSlaves  : in  AxiWriteSlaveArray(3 downto 0);
      ddrReadMasters  : out AxiReadMasterArray(3 downto 0);
      ddrReadSlaves   : in  AxiReadSlaveArray(3 downto 0);
      -- ADC Streams Interface (adcClk domain, nexoAxisConfig(ADC_TYPE_G))
      adcClk          : in  sl;
      adcRst          : in  sl;
      adcMasters      : in  AxiStreamMasterArray(29 downto 0);
      adcSlaves       : out AxiStreamSlaveArray(29 downto 0);
      -- Trigger Decision Interface (trigClk domain, TRIG_DECISION_AXIS_CONFIG_C)
      trigClk         : in  sl;
      trigRst         : in  sl;
      trigRdMaster    : in  AxiStreamMasterType;
      trigRdSlave     : out AxiStreamSlaveType;
      -- Compression Interface (compClk domain, nexoAxisConfig(ADC_TYPE_G))
      compClk         : in  sl;
      compRst         : in  sl;
      compMasters     : out AxiStreamMasterArray(29 downto 0);
      compSlaves      : in  AxiStreamSlaveArray(29 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end RingBufferTop;

architecture mapping of RingBufferTop is

   constant AXIL_XBAR_SIZE_C : positive := 4;

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIL_XBAR_SIZE_C-1 downto 0) := genAxiLiteConfig(AXIL_XBAR_SIZE_C, AXIL_BASE_ADDR_G, 16, 12);

   signal axilWriteMasters : AxiLiteWriteMasterArray(AXIL_XBAR_SIZE_C-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_XBAR_SIZE_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(AXIL_XBAR_SIZE_C-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(AXIL_XBAR_SIZE_C-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal trigRdMasters : AxiStreamMasterArray(AXIL_XBAR_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal trigRdSlaves  : AxiStreamSlaveArray(AXIL_XBAR_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   constant STREAMS_C : NaturalArray(AXIL_XBAR_SIZE_C-1 downto 0) := (
      0 => 8,
      1 => 8,
      2 => 7,
      3 => 7);

   constant LSB_C : NaturalArray(AXIL_XBAR_SIZE_C-1 downto 0) := (
      0 => 0,
      1 => 8,
      2 => 16,
      3 => 23);

   constant MSB_C : NaturalArray(AXIL_XBAR_SIZE_C-1 downto 0) := (
      0 => 7,
      1 => 15,
      2 => 22,
      3 => 29);

begin

   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_XBAR_SIZE_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ----------------------
   -- AXI Stream Repeater
   ----------------------
   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => AXIL_XBAR_SIZE_C,
         INPUT_PIPE_STAGES_G  => 1,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk      => trigClk,
         axisRst      => trigRst,
         -- Slave
         sAxisMaster  => trigRdMaster,
         sAxisSlave   => trigRdSlave,
         -- Masters
         mAxisMasters => trigRdMasters,
         mAxisSlaves  => trigRdSlaves);

   -------------------
   -- Ring Buffer DIMM
   -------------------
   GEN_VEC :
   for i in AXIL_XBAR_SIZE_C-1 downto 0 generate
      U_RingBufferTop : entity nexo_daq_ring_buffer.RingBufferDimm
         generic map (
            TPD_G                  => TPD_G,
            SIMULATION_G           => SIMULATION_G,
            ADC_TYPE_G             => ADC_TYPE_G,
            DDR_DIMM_INDEX_G       => i,
            AXIS_SIZE_G            => STREAMS_C(i),
            ADC_CLK_IS_CORE_CLK_G  => ADC_CLK_IS_CORE_CLK_G,
            TRIG_CLK_IS_CORE_CLK_G => TRIG_CLK_IS_CORE_CLK_G,
            COMP_CLK_IS_CORE_CLK_G => COMP_CLK_IS_CORE_CLK_G,
            AXIL_CLK_IS_CORE_CLK_G => AXIL_CLK_IS_CORE_CLK_G,
            AXIL_BASE_ADDR_G       => AXIL_XBAR_CONFIG_C(i).baseAddr)
         port map (
            -- Core Clock/Reset
            coreClk          => coreClk,
            coreRst          => coreRst,
            -- DDR Memory Interface (ddrClk domain)
            ddrClk           => ddrClk(i),
            ddrRst           => ddrRst(i),
            ddrWriteMaster   => ddrWriteMasters(i),
            ddrWriteSlave    => ddrWriteSlaves(i),
            ddrReadMaster    => ddrReadMasters(i),
            ddrReadSlave     => ddrReadSlaves(i),
            -- ADC Streams Interface (adcClk domain, nexoAxisConfig(ADC_TYPE_G))
            adcClk           => adcClk,
            adcRst           => adcRst,
            adcMasters       => adcMasters(MSB_C(i) downto LSB_C(i)),
            adcSlaves        => adcSlaves(MSB_C(i) downto LSB_C(i)),
            -- Trigger Decision Interface (trigClk domain, TRIG_DECISION_AXIS_CONFIG_C)
            trigClk          => trigClk,
            trigRst          => trigRst,
            trigRdMaster     => trigRdMasters(i),
            trigRdSlave      => trigRdSlaves(i),
            -- Compression Interface (compClk domain, nexoAxisConfig(ADC_TYPE_G))
            compClk          => compClk,
            compRst          => compRst,
            compMasters      => compMasters(MSB_C(i) downto LSB_C(i)),
            compSlaves       => compSlaves(MSB_C(i) downto LSB_C(i)),
            -- AXI-Lite Interface (axilClk domain)
            axilClk          => axilClk,
            axilRst          => axilRst,
            sAxilReadMaster  => axilReadMasters(i),
            sAxilReadSlave   => axilReadSlaves(i),
            sAxilWriteMaster => axilWriteMasters(i),
            sAxilWriteSlave  => axilWriteSlaves(i));
   end generate GEN_VEC;

end mapping;
