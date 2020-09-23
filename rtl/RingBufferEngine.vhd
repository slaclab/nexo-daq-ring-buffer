-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer Engine
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
use surf.SsiPkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

library nexo_daq_trigger_decision;
use nexo_daq_trigger_decision.TriggerDecisionPkg.all;

entity RingBufferEngine is
   generic (
      TPD_G            : time := 1 ns;
      SIMULATION_G     : boolean;
      ADC_TYPE_G       : AdcType;
      ADC_CH_OFFSET_G  : natural;
      DDR_DIMM_INDEX_G : natural;
      STREAM_INDEX_G   : natural);
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- ADC Stream Interface
      adcMaster       : in  AxiStreamMasterType;
      adcSlave        : out AxiStreamSlaveType;
      -- Trigger Decision Interface
      trigRdMaster    : in  AxiStreamMasterType;
      trigRdSlave     : out AxiStreamSlaveType;
      -- Compression Interface
      compMaster      : out AxiStreamMasterType;
      compSlave       : in  AxiStreamSlaveType;
      -- AXI4 Interface
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      -- AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end RingBufferEngine;

architecture rtl of RingBufferEngine is

   type RegType is record
      enable         : sl;
      adcChOffset    : slv(12 downto 0);
      cntRst         : sl;
      dropFrameCnt   : slv(31 downto 0);
      dropTrigCnt    : slv(31 downto 0);
      eofeEventCnt   : slv(31 downto 0);
      -- AXI-Lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   constant REG_INIT_C : RegType := (
      enable         => '1',
      adcChOffset    => toSlv(ADC_CH_OFFSET_G, 13),
      cntRst         => '0',
      dropFrameCnt   => (others => '0'),
      dropTrigCnt    => (others => '0'),
      eofeEventCnt   => (others => '0'),
      -- AXI-Lite
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dropFrame : sl;
   signal dropTrig  : sl;
   signal eofeEvent : sl;

   signal rdReq : AxiReadDmaReqType;
   signal rdAck : AxiReadDmaAckType;

   signal writeMaster : AxiStreamMasterType;
   signal writeSlave  : AxiStreamSlaveType;

   signal readMaster : AxiStreamMasterType;
   signal readSlave  : AxiStreamSlaveType;

   signal trigHdrMaster : AxiStreamMasterType;
   signal trigHdrSlave  : AxiStreamSlaveType;

   signal compMasters : AxiStreamMasterArray(1 downto 0);
   signal compSlaves  : AxiStreamSlaveArray(1 downto 0);

begin

   comb : process (axilReadMaster, axilWriteMaster, dropFrame, dropTrig,
                   eofeEvent, r, rst) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst := '0';

      -- Check for dropped frame flag
      if (dropFrame = '1') then
         -- Increment the error counter
         v.dropFrameCnt := r.dropFrameCnt + 1;
      end if;

      -- Check for dropped frame flag
      if (dropTrig = '1') then
         -- Increment the error counter
         v.dropTrigCnt := r.dropTrigCnt + 1;
      end if;

      -- Check for eofeEvent flag
      if (eofeEvent = '1') then
         -- Increment the error counter
         v.eofeEventCnt := r.eofeEventCnt + 1;
      end if;

      -- Check for counter reset
      if (r.cntRst = '1') then
         v.dropFrameCnt := (others => '0');
         v.dropTrigCnt  := (others => '0');
         v.eofeEventCnt := (others => '0');
      end if;

      --------------------------------------------------------------------------------
      -- AXI-Lite Register Transactions
      --------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      axiSlaveRegisterR(axilEp, x"00", 0, toSlv(STREAM_INDEX_G, 8));
      axiSlaveRegisterR(axilEp, x"00", 8, toSlv(DDR_DIMM_INDEX_G, 8));
      axiSlaveRegisterR(axilEp, x"00", 16, ite((ADC_TYPE_G = ADC_TYPE_CHARGE_C), '1', '0'));
      axiSlaveRegisterR(axilEp, x"00", 24, ite(SIMULATION_G, '1', '0'));

      axiSlaveRegisterR(axilEp, x"10", 0, r.dropFrameCnt);
      axiSlaveRegisterR(axilEp, x"14", 0, r.dropTrigCnt);
      axiSlaveRegisterR(axilEp, x"18", 0, r.eofeEventCnt);

      axiSlaveRegister (axilEp, x"80", 0, v.enable);
      axiSlaveRegister (axilEp, x"84", 0, v.adcChOffset);

      axiSlaveRegister (axilEp, x"FC", 0, v.cntRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      --------------------------------------------------------------------------------

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

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

   ------------
   -- Write FSM
   ------------
   U_WriteFsm : entity nexo_daq_ring_buffer.RingBufferWriteFsm
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Control/Monitor Interface
         enable      => r.enable,
         dropFrame   => dropFrame,
         -- Clock and Reset
         clk         => clk,
         rst         => rst,
         -- Compression Inbound Interface
         adcMaster   => adcMaster,
         adcSlave    => adcSlave,
         -- DMA Write Interface
         writeMaster => writeMaster,
         writeSlave  => writeSlave);

   -----------------------
   -- DMA Write Controller
   -----------------------
   U_DmaWrite : entity nexo_daq_ring_buffer.RingBufferDmaWrite
      generic map (
         TPD_G          => TPD_G,
         PIPE_STAGES_G  => 1,
         ADC_TYPE_G     => ADC_TYPE_G,
         STREAM_INDEX_G => STREAM_INDEX_G)
      port map (
         -- Clock and Reset
         axiClk         => clk,
         axiRst         => rst,
         -- AXI Stream Interface
         axisMaster     => writeMaster,
         axisSlave      => writeSlave,
         -- AXI4 Interface
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   ----------------------
   -- DMA Read Controller
   ----------------------
   U_DmaRead : entity nexo_daq_ring_buffer.RingBufferDmaRead
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         ADC_TYPE_G    => ADC_TYPE_G)
      port map (
         -- Clock and Reset
         axiClk        => clk,
         axiRst        => rst,
         -- DMA Control
         dmaReq        => rdReq,
         dmaAck        => rdAck,
         -- AXI Stream Interface
         axisMaster    => readMaster,
         axisSlave     => readSlave,
         -- AXI4 Interface
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

   ------------
   -- Read FSM
   ------------
   U_ReadFsm : entity nexo_daq_ring_buffer.RingBufferReadFsm
      generic map (
         TPD_G          => TPD_G,
         ADC_TYPE_G     => ADC_TYPE_G,
         STREAM_INDEX_G => STREAM_INDEX_G)
      port map (
         -- Control/Monitor Interface
         enable       => r.enable,
         adcChOffset  => r.adcChOffset,
         dropTrig     => dropTrig,
         eofeEvent    => eofeEvent,
         -- Clock and Reset
         clk          => clk,
         rst          => rst,
         -- Trigger Decision Interface
         trigRdMaster => trigRdMaster,
         trigRdSlave  => trigRdSlave,
         -- DMA Read Interface
         rdReq        => rdReq,
         rdAck        => rdAck,
         readMaster   => readMaster,
         readSlave    => readSlave,
         -- Compression Inbound Interface
         compMaster   => compMaster,
         compSlave    => compSlave);

end rtl;
