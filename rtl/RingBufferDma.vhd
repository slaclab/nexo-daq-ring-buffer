-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Engine DMA
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
use surf.AxiPkg.all;

library axi_pcie_core;
use axi_pcie_core.MigPkg.all;

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

entity RingBufferDma is
   generic (
      TPD_G      : time    := 1 ns;
      ADC_TYPE_G : boolean := true);  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
   port (
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl;
      -- Inbound AXI Stream Interface
      reorgMasters   : in  AxiStreamMasterArray(15 downto 0);
      reorgSlaves    : out AxiStreamSlaveArray(15 downto 0);
      -- Outbound AXI Stream Interface
      readMaster     : out AxiStreamMasterType;
      readSlave      : in  AxiStreamSlaveType;
      -- DMA Control Interface
      wrReq          : in  AxiWriteDmaReqType;
      wrAck          : out AxiWriteDmaAckType;
      wrHdr          : out AxiStreamMasterType;
      rdReq          : in  AxiReadDmaReqType;
      rdAck          : out AxiReadDmaAckType;
      -- AXI4 Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiReadMaster  : out AxiReadMasterType;
      axiReadSlave   : in  AxiReadSlaveType);
end RingBufferDma;

architecture rtl of RingBufferDma is

   signal writeMasters : AxiStreamMasterArray(15 downto 0);
   signal writeSlaves  : AxiStreamSlaveArray(15 downto 0);

   signal writeMaster : AxiStreamMasterType;
   signal writeSlave  : AxiStreamSlaveType;

   signal writeResizeMaster : AxiStreamMasterType;
   signal writeResizeSlave  : AxiStreamSlaveType;

   signal dmaIbMaster : AxiStreamMasterType;
   signal dmaIbSlave  : AxiStreamSlaveType;
   signal dmaIbCtrl   : AxiStreamCtrlType;

   signal dmaObMaster : AxiStreamMasterType;
   signal dmaObSlave  : AxiStreamSlaveType;

   signal readResizeMaster : AxiStreamMasterType;
   signal readResizeSlave  : AxiStreamSlaveType;

begin

   --------------------------------------
   -- Ring Buffer Stream Cache per stream
   --------------------------------------
   GEN_VEC :
   for i in 15 downto 0 generate
      U_RingBufferStream : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => 0,
            SLAVE_READY_EN_G    => true,
            -- FIFO configurations
            MEMORY_TYPE_G       => "block",
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 9,  -- 6kB/FIFO = 12-bytes x 512 entries
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => nexoAxisConfig(ADC_TYPE_G),
            MASTER_AXI_CONFIG_G => nexoAxisConfig(ADC_TYPE_G))
         port map (
            -- Slave Port
            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => reorgMasters(i),
            sAxisSlave  => reorgSlaves(i),
            -- Master Port
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => writeMasters(i),
            mAxisSlave  => writeSlaves(i));
   end generate GEN_VEC;

   -----------------
   -- AXI stream MUX
   -----------------
   U_Mux : entity surf.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 16,
         PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => writeMasters,
         sAxisSlaves  => writeSlaves,
         -- Master
         mAxisMaster  => writeMaster,
         mAxisSlave   => writeSlave);

   --------------------------
   -- Resize AXIS to 512-bits
   --------------------------
   U_IbResize : entity nexo_daq_ring_buffer.RingBufferAxisTo512b
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => writeMaster,
         sAxisSlave  => writeSlave,
         -- Master Port
         mAxisMaster => writeResizeMaster,
         mAxisSlave  => writeResizeSlave);

   ---------------------------------
   -- Store and Forward Write Buffer
   ---------------------------------
   U_Cache : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 0,      -- 0 = only when frame ready
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DDR_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DDR_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => writeResizeMaster,
         sAxisSlave  => writeResizeSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);

   -- Send a copy of the header to the FSM
   wrHdr <= dmaIbMaster;

   -----------------------
   -- DMA Write Controller
   -----------------------
   U_DmaWrite : entity surf.AxiStreamDmaWrite
      generic map (
         TPD_G          => TPD_G,
         AXI_READY_EN_G => true,
         AXIS_CONFIG_G  => DDR_AXIS_CONFIG_C,
         AXI_CONFIG_G   => MEM_AXI_CONFIG_C,
         BYP_SHIFT_G    => true)        -- True = only 4kB address alignment
      port map (
         -- Clock and Reset
         axiClk         => clk,
         axiRst         => rst,
         -- DMA Control
         dmaReq         => wrReq,
         dmaAck         => wrAck,
         -- AXI Stream Interface
         axisMaster     => dmaIbMaster,
         axisSlave      => dmaIbSlave,
         -- AXI4 Interface
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   ----------------------
   -- DMA Read Controller
   ----------------------
   U_DmaRead : entity surf.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => false,      -- Using pause flow control
         AXIS_CONFIG_G   => DDR_AXIS_CONFIG_C,
         AXI_CONFIG_G    => MEM_AXI_CONFIG_C,
         BYP_SHIFT_G     => true)       -- True = only 4kB address alignment
      port map (
         -- Clock and Reset
         axiClk        => clk,
         axiRst        => rst,
         -- DMA Control
         dmaReq        => rdReq,
         dmaAck        => rdAck,
         -- AXI Stream Interface
         axisMaster    => dmaIbMaster,
         axisSlave     => dmaIbSlave,
         axisCtrl      => dmaIbCtrl,
         -- AXI4 Interface
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

   ---------------------------------
   -- Store and Forward Read Buffer
   ---------------------------------
   U_Cache : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => false,  -- Using pause flow control
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 256,    -- 50% of 32kB buffer
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DDR_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DDR_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => dmaIbMaster,
         sAxisSlave  => dmaIbSlave,
         sAxisCtrl   => dmaIbCtrl,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => readResizeMaster,
         mAxisSlave  => readResizeSlave);

   ----------------------------
   -- Resize AXIS from 512-bits
   ----------------------------
   U_ObResize : entity nexo_daq_ring_buffer.RingBufferAxisFrom512b
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => readResizeMaster,
         sAxisSlave  => readResizeSlave,
         -- Master Port
         mAxisMaster => readMaster,
         mAxisSlave  => readSlave);

end rtl;
