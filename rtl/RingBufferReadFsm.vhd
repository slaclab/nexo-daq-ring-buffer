-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer's Read FSM
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
use surf.SsiPkg.all;
use surf.AxiDmaPkg.all;

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

library nexo_daq_trigger_decision;
use nexo_daq_trigger_decision.TriggerDecisionPkg.all;

entity RingBufferReadFsm is
   generic (
      TPD_G            : time    := 1 ns;
      SIMULATION_G     : boolean := false;
      ADC_TYPE_G       : boolean := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      DDR_DIMM_INDEX_G : natural := 0;
      STREAM_INDEX_G   : natural := 0);
   port (
      -- Control/Monitor Interface
      enable       : in  sl;
      eofeEvent    : out sl;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl;
      -- Trigger Decision Interface
      trigRdMaster : in  AxiStreamMasterType;
      trigRdSlave  : out AxiStreamSlaveType;
      -- DMA Read Interface
      rdReq        : out AxiReadDmaReqType;
      rdAck        : in  AxiReadDmaAckType;
      readMaster   : in  AxiStreamMasterType;
      readSlave    : out AxiStreamSlaveType;
      -- Compression Inbound Interface
      compMaster   : out AxiStreamMasterType;
      compSlave    : in  AxiStreamSlaveType);
end RingBufferReadFsm;

architecture rtl of RingBufferReadFsm is

   type StateType is (
      IDLE_S,
      DMA_REQ_S,
      IDLE_S);

   type RegType is record
      -- Trigger Message
      eventID     : slv(31 downto 0);
      eventType   : slv(15 downto 0);
      readSize    : slv(11 downto 0);
      startTime   : slv(TS_WIDTH_C-1 downto 0);
      -- Readout Signals
      rdReq       : AxiReadDmaReqType;
      readTime    : slv(TS_WIDTH_C-1 downto 0);
      trimStart   : slv(7 downto 0);
      readCh      : slv(3 downto 0);
      readCnt     : slv(11 downto 0);
      eofe        : sl;
      tValid      : sl;
      -- AXI stream
      trigRdSlave : AxiStreamSlaveType;
      readSlave   : AxiStreamSlaveType;
      compMaster  : AxiStreamMasterType;
      -- State Machine
      state       : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      -- Trigger Message
      eventID     => (others => '0'),
      eventType   => (others => '0'),
      readSize    => (others => '0'),
      startTime   => (others => '0'),
      -- Readout Signals
      rdReq       => AXI_READ_DMA_REQ_INIT_C,
      readTime    => (others => '0'),
      trimStart   => (others => '0'),
      readCh      => (others => '0'),
      readCnt     => (others => '0'),
      eofe        => '0',
      tValid      => '1',
      -- AXI stream
      trigRdSlave => AXI_STREAM_SLAVE_INIT_C,
      readSlave   => AXI_STREAM_SLAVE_INIT_C,
      compMaster  => AXI_STREAM_MASTER_INIT_C,
      -- State Machine
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (compSlave, r, rdAck, readMaster, rst, trigRdMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.rdReq.request := '0';

      -- AXI Stream Flow Control
      v.trigRdSlave.tReady := '0';
      v.readSlave.tReady   := '0';
      if (compSlave.tReady = '0') then
         v.compMaster.tValid := '0';
         v.compMaster.tLast  := '0';
         v.compMaster.tUser  := (others = '0');
      end if;

      ------------------------------
      -- True: 12-bit ADC for CHARGE
      ------------------------------
      if ADC_TYPE_G then
         -- 3084 Bytes = 96-bit header + 96-bit x 256 words
         v.rdReq.size := toSlv(3084, 32);

      -------------------------------
      -- False: 10-bit ADC for PHOTON
      -------------------------------
      else
         -- 2570 Bytes = 80-bit header + 80-bit x 256 words
         v.rdReq.size := toSlv(2570, 32);

      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Wait for Trigger decision
            if (trigRdMaster.tValid = '1') then

               -- Accept the data
               v.trigRdSlave.tReady := '1';

               -- Check if single word transfer
               if (ssiGetUserSof(TRIG_DECISION_AXIS_CONFIG_C, trigRdMaster) = '1') and (trigRdMaster.tLast = '1') then

                  -- Latch the trigger message
                  v.eventID   := trigRdMaster.tData(31 downto 0);   -- 32-bit
                  v.eventType := trigRdMaster.tData(47 downto 32);  -- 16-bit
                  v.readSize  := trigRdMaster.tData(59 downto 48);  -- 12-bit
                  v.startTime := trigRdMaster.tData(TS_WIDTH_C+63 downto 64);  -- TS_WIDTH_C bits

                  -- Init the readTime
                  v.readTime := v.startTime;

                  -- Init the trimStart
                  v.trimStart := v.startTime(7 downto 0);

                  -- Check if this engine is enabled and single transfer
                  if (r.enable = '1') then

                     -- Next state
                     v.state := DMA_REQ_S;

                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when DMA_REQ_S =>
            -- Check if ready for DMA request
            if (rdAck.idle = '1') then

               -- Send the DMA Read REQ
               v.rdReq.request := '1';

               -- Set Memory Address offset
               v.rdReq.address(11 downto 0)  := x"000";  -- 4kB address alignment
               v.rdReq.address(15 downto 12) := r.readCh;  -- Cache buffer index
               v.rdReq.address(29 downto 16) := r.readTime(21 downto 8);  -- Address.BIT[29:16] = TimeStamp[21:8]
               v.rdReq.address(33 downto 30) := toSlv(STREAM_INDEX_G, 4);  -- AXI Stream Index

               -- Check for first DMA request per AXI stream output
               if (r.readTime = r.startTime) then
                  -- Next state
                  v.state := TRIG_HDR_S;
               else
                  -- Next state
                  v.state := DATA_HDR_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when TRIG_HDR_S =>
            -- Check if ready to move data
            if (v.compMaster.tValid = '0') then

               -- Write the Trigger header
               v.compMaster.tValid := '1';

               -- Insert the SOF bit
               ssiSetUserSof(nexoAxisConfig(ADC_TYPE_G), v.compMaster, '1');

               -- Trigger Decision's Event ID
               v.compMaster.tData(31 downto 0) := r.eventID;

               -- Trigger Decision's Event Type
               v.compMaster.tData(47 downto 32) := r.eventType;

               -- Trigger Decision's Readout Size (zero inclusive)
               v.compMaster.tData(59 downto 48) := r.readSize;

               -- Ring Engine Stream ID
               v.compMaster.tData(63 downto 60) := r.readCh;

               -- Ring Engine Stream Index
               v.compMaster.tData(67 downto 64) := toSlv(STREAM_INDEX_G, 4);

               -- DDR DIMM Index
               v.compMaster.tData(71 downto 68) := toSlv(DDR_DIMM_INDEX_G, 4);

               -- ADC_TYPE_G
               if ADC_TYPE_G then
                  v.compMaster.tData(72) := '1';
               else
                  v.compMaster.tData(72) := '0';
               end if;

               -- "TBD" field zero'd out
               v.compMaster.tData(95 downto 73) := (others => '0');

               -- Next state
               v.state := DATA_HDR_S;

            end if;
         ----------------------------------------------------------------------
         when DATA_HDR_S =>
            -- Check if ready to move data
            if (v.compMaster.tValid = '0') and (readMaster.tValid = '1') then

               -- Accept the data
               v.readSlave.tReady := '1';

               -- Check for timestamp misalignment
               if (readMaster.tData(TS_WIDTH_C-1 downto 8) /= r.readTime(TS_WIDTH_C-1 downto 8)) then
                  -- Reset the flag
                  v.eofe := '1';
               end if;

               -- Check for first DMA request per AXI stream output
               if (r.readTime = r.startTime) then

                  -- Write the Data header
                  v.compMaster.tValid := '1';

               end if;

               -- Time Offset
               v.compMaster.tData(TS_WIDTH_C-1 downto 0) := r.startTime;

               -- Pass the other meta-data from ADC header
               v.compMaster.tData(95 downto TS_WIDTH_C) := readMaster.tData(95 downto TS_WIDTH_C);

               -- Set the flag
               v.tValid := '1';

               -- Next state
               v.state := MOVE_S;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.compMaster.tValid = '0') and (readMaster.tValid = '1') then

               -- Accept the data
               v.readSlave.tReady := '1';

               -- Check if trimming the beginning
               if (r.trimStart /= 0) then

                  -- Decrement the counter
                  v.trimStart := r.trimStart - 1;

               else

                  -- Move the ADC data
                  v.compMaster.tValid             := r.tValid;
                  v.compMaster.tData(95 downto 0) := readMaster.tData(95 downto 0);

                  -- Check if last sample
                  if (r.readCnt = r.readSize) then

                     -- Terminate the frame
                     v.compMaster.tLast := '1';

                     -- Insert the EOFE bit
                     ssiSetUserEofe(nexoAxisConfig(ADC_TYPE_G), v.compMaster, r.eofe);

                     -- Reset the flag
                     v.tValid := '0';

                     -- Check for last DMA word
                     if (readMaster.tLast = '1') then

                        -- Reset the counter
                        v.readCnt := (others => '0');

                        -- Init the readTime
                        v.readTime := r.startTime;

                        -- Init the trimStart
                        v.trimStart := r.startTime(7 downto 0);

                        -- Reset the flag
                        v.eofe := '0';

                        -- Check if last stream sent
                        if (r.readCh = 15) then

                           -- Reset the counters
                           v.readCh := (others => '0');

                           -- Next state
                           v.state := IDLE_S;

                        else

                           -- Increment the counter
                           v.readCh := r.readCh + 1;

                           -- Next state
                           v.state := DMA_REQ_S;

                        end if;

                     end if;

                  else

                     -- Increment the counter
                     v.readCnt := r.readCnt + 1;

                     -- Check for last DMA word
                     if (readMaster.tLast = '1') then

                        -- Setup for next 256 time slices
                        v.readTime := r.readTime + 256;

                        -- Next state
                        v.state := DMA_REQ_S;

                     end if;

                  end if;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      trigRdSlave <= v.trigRdSlave;     -- comb (not registered) output
      readSlave   <= v.readSlave;       -- comb (not registered) output
      rdReq       <= r.rdReq;
      compMaster  <= r.compMaster;
      eofeEvent   <= r.eofe and r.compMaster.tValid and r.compMaster.tLast and compSlave.tReady;

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

end rtl;
