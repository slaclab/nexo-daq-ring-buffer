-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Engine DMA
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
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;

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
      awcache        : in slv(3 downto 0);
      wrReq          : in  AxiWriteDmaReqType;
      wrAck          : out AxiWriteDmaAckType;
      wrMaster       : in  AxiStreamMasterType;
      wrSlave        : out AxiStreamSlaveType;
      -- Outbound AXI Stream Interface
      arcache        : in slv(3 downto 0);
      rdReq          : in  AxiReadDmaReqType;
      rdAck          : out AxiReadDmaAckType;
      rdMaster       : out AxiStreamMasterType;
      rdSlave        : in  AxiStreamSlaveType;
      -- AXI4 Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiReadMaster  : out AxiReadMasterType;
      axiReadSlave   : in  AxiReadSlaveType);
end RingBufferDma;

architecture rtl of RingBufferDma is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => CHARGE_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => (128/8),         -- 128-bit data interface
      TDEST_BITS_C  => CHARGE_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => CHARGE_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => CHARGE_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => CHARGE_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => CHARGE_AXIS_CONFIG_C.TUSER_MODE_C);

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => MEM_AXI_CONFIG_C.ADDR_WIDTH_C,
      DATA_BYTES_C => (128/8),          -- 128-bit data interface
      ID_BITS_C    => MEM_AXI_CONFIG_C.ID_BITS_C,
      LEN_BITS_C   => MEM_AXI_CONFIG_C.LEN_BITS_C);

   signal writeMaster : AxiStreamMasterType;
   signal writeSlave  : AxiStreamSlaveType;

   signal readMaster : AxiStreamMasterType;
   signal readSlave  : AxiStreamSlaveType;

begin

   --------------------------------------------
   -- Resize to 128b with respect to ADC_TYPE_G
   --------------------------------------------
   U_WriteResize : entity nexo_daq_ring_buffer.ResizeAxisTo128b
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => wrMaster,
         sAxisSlave  => wrSlave,
         -- Master Port
         mAxisMaster => writeMaster,
         mAxisSlave  => writeSlave);

   -----------------------
   -- DMA Write Controller
   -----------------------
   U_DmaWrite : entity surf.AxiStreamDmaWrite
      generic map (
         TPD_G          => TPD_G,
         AXI_READY_EN_G => true,
         AXIS_CONFIG_G  => AXIS_CONFIG_C,
         AXI_CONFIG_G   => AXI_CONFIG_C,
         SW_CACHE_EN_G  => true,
         BYP_CACHE_G    => true,
         BYP_SHIFT_G    => true)   -- True = only 4kB address alignment
      port map (
         -- Clock and Reset
         axiClk         => clk,
         axiRst         => rst,
         -- DMA Control
         dmaReq         => wrReq,
         dmaAck         => wrAck,
         swCache        => awcache,
         -- AXI Stream Interface
         axisMaster     => writeMaster,
         axisSlave      => writeSlave,
         -- AXI4 Interface
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   ----------------------
   -- DMA Read Controller
   ----------------------
   U_DmaRead : entity surf.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_C,
         SW_CACHE_EN_G   => true,
         BYP_SHIFT_G     => true)       -- True = only 4kB address alignment
      port map (
         -- Clock and Reset
         axiClk        => clk,
         axiRst        => rst,
         -- DMA Control
         dmaReq        => rdReq,
         dmaAck        => rdAck,
         swCache       => arcache,
         -- AXI Stream Interface
         axisMaster    => readMaster,
         axisSlave     => readSlave,
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         -- AXI4 Interface
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

   ----------------------------------------------
   -- Resize from 128b with respect to ADC_TYPE_G
   ----------------------------------------------
   U_ReadResize : entity nexo_daq_ring_buffer.ResizeAxisFrom128b
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => readMaster,
         sAxisSlave  => readSlave,
         -- Master Port
         mAxisMaster => rdMaster,
         mAxisSlave  => rdSlave);

end rtl;
