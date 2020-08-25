-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame from memory using an AXI
-- interface.
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

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferDmaPkg.all;

entity RingBufferDmaRead is
   generic (
      TPD_G      : time    := 1 ns;
      ADC_TYPE_G : boolean := true);  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
   port (
      -- Clock/Reset
      axiClk        : in  sl;
      axiRst        : in  sl;
      -- DMA Control Interface
      dmaReq        : in  AxiReadDmaReqType;
      dmaAck        : out AxiReadDmaAckType;
      -- Streaming Interface
      axisMaster    : out AxiStreamMasterType;
      axisSlave     : in  AxiStreamSlaveType;
      -- AXI Interface
      axiReadMaster : out AxiReadMasterType;
      axiReadSlave  : in  AxiReadSlaveType);
end RingBufferDmaRead;

architecture rtl of RingBufferDmaRead is

   constant WORD_SIZE_C  : positive := nexoGetWordSize(ADC_TYPE_G);
   constant MAX_CNT_C    : positive := nexoGetMaxWordCnt(ADC_TYPE_G);
   constant BURST_SIZE_C : positive := nexoGetBurstSize(ADC_TYPE_G);

   type StateType is (
      READ_ADDR_S,
      READ_DATA_S);

   type RegType is record
      wrdCnt        : natural range 0 to MAX_CNT_C-1;
      cnt           : natural range 0 to 256;
      dmaAck        : AxiReadDmaAckType;
      axiReadMaster : AxiReadMasterType;
      axisMaster    : AxiStreamMasterType;
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrdCnt        => 0,
      cnt           => 0,
      dmaAck        => AXI_READ_DMA_ACK_INIT_C,
      axiReadMaster => (
         arvalid    => '0',
         araddr     => (others => '0'),
         arid       => (others => '0'),
         arlen      => getAxiLen(AXI_CONFIG_C, BURST_SIZE_C),
         arsize     => toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3),
         arburst    => "01",
         arlock     => (others => '0'),
         arprot     => (others => '0'),
         arcache    => "1111",
         arqos      => (others => '0'),
         arregion   => (others => '0'),
         rready     => '0'),
      axisMaster    => AXI_STREAM_MASTER_INIT_C,
      state         => READ_ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiReadSlave, axiRst, axisSlave, dmaReq, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      v.axiReadMaster.rready := '0';
      if axiReadSlave.arready = '1' then
         v.axiReadMaster.arvalid := '0';
      end if;
      if axisSlave.tReady = '1' then
         v.axisMaster.tValid := '0';
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when READ_ADDR_S =>
            -- Init
            v.wrdCnt := 0;
            v.cnt    := 0;

            -- Check for DMA request
            if (dmaReq.request = '1') then

               -- Write Address channel
               v.axiReadMaster.arvalid := '1';
               v.axiReadMaster.araddr  := dmaReq.address;

               -- Reset the flag
               v.axisMaster.tLast := '0';

               -- Next State
               v.state := READ_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when READ_DATA_S =>
            -- Check for new data
            if (axiReadSlave.rvalid = '1') and (r.axisMaster.tValid = '0') then

               -- Move the data
               v.axisMaster.tValid := not(r.axisMaster.tLast);

               -- Write Data channel
               v.axisMaster.tData(WORD_SIZE_C-1 downto 0) := axiReadSlave.rdata(
                  r.wrdCnt*WORD_SIZE_C+WORD_SIZE_C-1 downto
                  r.wrdCnt*WORD_SIZE_C);

               -- Check for max count
               if (r.wrdCnt = MAX_CNT_C-1) then

                  -- Reset counter
                  v.wrdCnt := 0;

                  -- Accept the data
                  v.axiReadMaster.rready := '1';

               else

                  -- Increment the counter
                  v.wrdCnt := r.wrdCnt + 1;

               end if;

               -- Check burst size count
               if (r.cnt = 256) then

                  -- Terminate the frame
                  v.axisMaster.tLast := '1';

               else

                  -- Increment the counters
                  v.cnt := r.cnt + 1;

               end if;

               -- Check for last transfer
               if axiReadSlave.rlast = '1' then

                  -- Next State
                  v.state := READ_ADDR_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Forward the state of the state machine
      if (r.state = READ_ADDR_S) and (r.axiReadMaster.arvalid = '0') and (r.axisMaster.tValid = '0') then
         -- Set the flag
         v.dmaAck.idle := '1';
      else
         -- Reset the flag
         v.dmaAck.idle := '0';
      end if;

      -- Outputs
      dmaAck               <= r.dmaAck;
      axisMaster           <= r.axisMaster;
      axiReadMaster        <= r.axiReadMaster;
      axiReadMaster.rready <= v.axiReadMaster.rready;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
