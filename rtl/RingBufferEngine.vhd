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
      TPD_G            : time    := 1 ns;
      SIMULATION_G     : boolean := false;
      ADC_TYPE_G       : boolean := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      STREAM_INDEX_G   : natural := 1;
      AXIL_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- Compression Inbound Interface
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

   type WrStateType is (
      WR_IDLE_S,
      WR_MOVE_S);

   type RdStateType is (
      RD_IDLE_S);

   type RegType is record
      -- AXI-Lite Registers
      dropFrameCnt   : slv(31 downto 0);
      -- Write Signals
      adcSlave       : AxiStreamSlaveType;
      reorgMasters   : AxiStreamMasterArray(15 downto 0);
      wrIdx          : natural range 0 to 15;
      tsAlignCnt     : slv(7 downto 0);
      wrReq          : AxiWriteDmaReqType;
      wrState        : WrStateType;
      -- Read Signals
      trigRdSlave    : AxiStreamSlaveType;
      trigHdrMaster  : AxiStreamMasterType;
      rdReq          : AxiReadDmaReqType;
      rdState        : RdStateType;
      -- AXI-Lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   constant REG_INIT_C : RegType := (
      -- AXI-Lite Registers
      dropFrameCnt   => (others => '0'),
      -- Write Signals
      adcSlave       => AXI_STREAM_SLAVE_INIT_C,
      reorgMasters   => (others => AXI_STREAM_MASTER_INIT_C),
      wrIdx          => 0,
      tsAlignCnt     => (others => '0'),
      wrReq          => AXI_WRITE_DMA_REQ_INIT_C,
      wrState        => WR_IDLE_S,
      -- Read Signals
      trigRdSlave    => AXI_STREAM_SLAVE_INIT_C,
      trigHdrMaster  => AXI_STREAM_MASTER_INIT_C,
      rdReq          => AXI_READ_DMA_REQ_INIT_C,
      rdState        => RD_IDLE_S,
      -- AXI-Lite
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal wrReq : AxiWriteDmaReqType;
   signal wrAck : AxiWriteDmaAckType;
   signal wrHdr : AxiStreamMasterType;
   signal rdReq : AxiReadDmaReqType;
   signal rdAck : AxiReadDmaAckType;

   signal reorgMasters : AxiStreamMasterArray(15 downto 0);
   signal reorgSlaves  : AxiStreamSlaveArray(15 downto 0);

   signal trigHdrMaster : AxiStreamMasterType;
   signal trigHdrSlave  : AxiStreamSlaveType;

   signal readMaster : AxiStreamMasterType;
   signal readSlave  : AxiStreamSlaveType;

begin

   comb : process (adcMaster, axilReadMaster, axilWriteMaster, r, reorgSlaves,
                   rst, trigHdrSlave, trigRdMaster, wrAck, wrHdr) is
      variable v          : RegType;
      variable axilEp     : AxiLiteEndPointType;
      variable i          : natural;
      variable wrAllReady : sl;
   begin
      -- Latch the current value
      v := r;

      --------------------------------------------------------------------------------
      -- Write AXIS Data Reorganization
      --------------------------------------------------------------------------------

      -- AXI Stream Flow Control
      v.adcSlave.tReady := '0';
      for i in 15 downto 0 loop
         if (reorgSlaves(i).tReady = '0') then
            v.reorgMasters(i).tValid := '0';
            v.reorgMasters(i).tLast  := '0';
         end if;
      end loop;
      wrAllReady := '1';
      for i in 15 downto 0 loop
         if (r.reorgMasters(i).tValid = '1') then
            wrAllReady := '0';
         end if;
      end loop;

      -- State machine
      case r.wrState is
         ----------------------------------------------------------------------
         when WR_IDLE_S =>
            -- Check if ready to move data
            if (adcMaster.tValid = '1') and (wrAllReady = '1') then

               -- Accept the data
               v.adcSlave.tReady := '1';

               -- Check for SOF and not EOF and phase alignment to timestamp
               if (ssiGetUserSof(nexoAxisConfig(ADC_TYPE_G), adcMaster) = '1') and (adcMaster.tLast = '0') and (r.tsAlignCnt = adcMaster.tData(7 downto 0)) then

                  -- Check for 1st time stamp
                  if (r.tsAlignCnt = 0) then
                     for i in 15 downto 0 loop

                        -- Copy the header to all 16 streams
                        v.reorgMasters(i) := adcMaster;

                        -- Overwrite the ring buffer stream ID
                        v.reorgMasters(i).tData(47 downto 44) := toSlv(i, 4);

                     end loop;
                  end if;

                  -- Reset counter
                  v.wrIdx := 0;

                  -- Next state
                  v.wrState := WR_MOVE_S;

               elsif (adcMaster.tLast = '1') then

                  -- Increment the error counter
                  v.dropFrameCnt := r.dropFrameCnt + 1;

               end if;

            end if;
         ----------------------------------------------------------------------
         when WR_MOVE_S =>
            -- Check if ready to move data
            if (adcMaster.tValid = '1') and (r.reorgMasters(r.wrIdx).tValid = '0') then

               -- Accept the data
               v.adcSlave.tReady := '1';

               -- Copy the ADC data
               v.reorgMasters(r.wrIdx) := adcMaster;

               -- Check if last time slice frame
               if (r.tsAlignCnt = 255) then
                  v.reorgMasters(r.wrIdx).tLast := '1';
               else
                  -- Reset EOF
                  v.reorgMasters(r.wrIdx).tLast := '0';
               end if;

               -- Check for last transfer
               if (r.wrIdx = 15) then

                  -- Increment the counter
                  v.tsAlignCnt := r.tsAlignCnt + 1;

                  -- Next state
                  v.wrState := WR_IDLE_S;

               else
                  -- Increment the counter
                  v.wrIdx := r.wrIdx + 1;
               end if;

            end if;

      ----------------------------------------------------------------------
      end case;

      --------------------------------------------------------------------------------
      -- Write DMA Control
      --------------------------------------------------------------------------------

      -- Check if ready for next DMA Write REQ
      if (wrHdr.tValid = '1') and (r.wrReq.request = '0') and (wrAck.done = '0') and (wrAck.idle = '1') then

         -- Send the DMA Write REQ
         v.wrReq.request := '1';

         -- Set Memory Address offset
         v.wrReq.address(11 downto 0)  := x"000";  -- 4kB address alignment
         v.wrReq.address(15 downto 12) := wrHdr.tDest(3 downto 0);  -- Cache buffer index
         v.wrReq.address(29 downto 16) := wrHdr.tData(21 downto 8);  -- Address.BIT[29:16] = TimeStamp[21:8]
         v.wrReq.address(33 downto 30) := toSlv(STREAM_INDEX_G, 4);  -- AXI Stream Index

         -- Set the max buffer size
         v.wrReq.maxSize := toSlv(4096, 32);

      -- Wait for the DMA Write ACK
      elsif (r.wrReq.request = '1') and (wrAck.done = '1') then

         -- Reset the flag
         v.wrReq.request := '0';

      end if;

      --------------------------------------------------------------------------------
      -- Read DMA Control
      --------------------------------------------------------------------------------

      -- AXI Stream Flow Control
      v.trigRdSlave.tReady := '0';
      if (trigHdrSlave.tReady = '0') then
         v.trigHdrMaster.tValid := '0';
         v.trigHdrMaster.tLast  := '0';
      end if;

      -- State machine
      case r.rdState is
         ----------------------------------------------------------------------
         when RD_IDLE_S =>
            -- Wait for Trigger decision
            if (trigRdMaster.tValid = '1') then

               -- Accept the data
               v.trigRdSlave.tReady := '1';

            end if;
      ----------------------------------------------------------------------
      end case;

      --------------------------------------------------------------------------------
      -- AXI-Lite Register Transactions
      --------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      axiSlaveRegisterR(axilEp, x"00", 0, toSlv(STREAM_INDEX_G, 4));
      axiSlaveRegisterR(axilEp, x"04", 0, r.dropFrameCnt);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      --------------------------------------------------------------------------------
      -- Outputs
      --------------------------------------------------------------------------------

      -- AXI-Lite Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

      -- Write Outputs
      adcSlave     <= v.adcSlave;       -- comb (not registered) output
      reorgMasters <= r.reorgMasters;
      wrReq        <= r.wrReq;

      -- Read Outputs
      trigRdSlave   <= v.trigRdSlave;   -- comb (not registered) output
      rdReq         <= r.rdReq;
      trigHdrMaster <= r.trigHdrMaster;

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

   --------------------------------
   -- DMA Engine for the DDR Memory
   --------------------------------
   U_DMA : entity nexo_daq_ring_buffer.RingBufferDma
      generic map (
         TPD_G      => TPD_G,
         ADC_TYPE_G => ADC_TYPE_G)
      port map (
         -- Clock and Reset
         clk            => clk,
         rst            => rst,
         -- Inbound AXI Streams Interface
         reorgMasters   => reorgMasters,
         reorgSlaves    => reorgSlaves,
         -- Outbound AXI Stream Interface
         readMaster     => readMaster,
         readSlave      => readSlave,
         -- DMA Control Interface
         wrReq          => wrReq,
         wrAck          => wrAck,
         wrHdr          => wrHdr,
         rdReq          => rdReq,
         rdAck          => rdAck,
         -- AXI4 Interface
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave);

   ----------------------------
   -- Insert the Trigger header
   ----------------------------
   U_InsertTrigHdr : entity nexo_daq_ring_buffer.RingBufferInsertTrigHdr
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk           => clk,
         rst           => rst,
         -- Trigger Header
         trigHdrMaster => trigHdrMaster,
         trigHdrSlave  => trigHdrSlave,
         -- Slave Port
         sAxisMaster   => readMaster,
         sAxisSlave    => readSlave,
         -- Master Port
         mAxisMaster   => compMaster,
         mAxisSlave    => compSlave);

end rtl;
