-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ring Buffer's Write FSM
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

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

entity RingBufferWriteFsm is
   generic (
      TPD_G            : time    := 1 ns;
      ADC_TYPE_G       : boolean := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      DDR_DIMM_INDEX_G : natural := 0;
      STREAM_INDEX_G   : natural := 0);
   port (
      -- Control/Monitor Interface
      enable      : in  sl;
      calMode     : in  sl;
      dropFrame   : out sl;
      calEventID  : out slv(31 downto 0);
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl;
      -- ADC Stream Interface
      adcMaster   : in  AxiStreamMasterType;
      adcSlave    : out AxiStreamSlaveType;
      -- DMA Write Interface
      writeMaster : out AxiStreamMasterType;
      writeSlave  : in  AxiStreamSlaveType;
      -- Compression Inbound Interface
      compMaster  : out AxiStreamMasterType;
      compSlave   : in  AxiStreamSlaveType);
end RingBufferWriteFsm;

architecture rtl of RingBufferWriteFsm is

   constant NUM_BUFFER_C : positive := 2;

   constant READ_LATENCY_C : natural range 1 to 2 := 2;

   type WrBuffStateType is (
      WR_BUFF_IDLE_S,
      WR_BUFF_MOVE_S);

   type RdBuffStateType is (
      IDLE_S,
      TRIG_HDR_S,
      DATA_HDR_S,
      MOVE_DLY_S,
      MOVE_S);

   type RegType is record
      dropFrame   : sl;
      -- Calibration mode
      calMode     : sl;
      calEventID  : slv(31 downto 0);
      -- Common Ping-Pong Buffer Signals
      buffValid   : slv(NUM_BUFFER_C-1 downto 0);
      eventHdr    : Slv96Array(NUM_BUFFER_C-1 downto 0);
      -- Write Ping-Pong Buffer Signals
      wrSel       : natural range 0 to NUM_BUFFER_C-1;
      adcSlave    : AxiStreamSlaveType;
      ramWrEn     : slv(NUM_BUFFER_C-1 downto 0);
      ramWrData   : slv(95 downto 0);
      tsWrCnt     : slv(7 downto 0);
      tsWrCntDly  : slv(7 downto 0);
      wrChCnt     : slv(3 downto 0);
      wrChCntDly  : slv(3 downto 0);
      wrBuffState : WrBuffStateType;
      -- Read Ping-Pong Buffer Signals
      rdSel       : natural range 0 to NUM_BUFFER_C-1;
      txMaster    : AxiStreamMasterType;
      wrdCnt      : slv(7 downto 0);
      tsRdCnt     : slv(7 downto 0);
      readCh      : slv(3 downto 0);
      rdEn        : slv(1 downto 0);
      rdLat       : slv(1 downto 0);
      rdBuffState : RdBuffStateType;
   end record;
   constant REG_INIT_C : RegType := (
      dropFrame   => '0',
      -- Calibration mode
      calMode     => '0',
      calEventID  => (others => '0'),
      -- Common Ping-Pong Buffer Signals
      buffValid   => (others => '0'),
      eventHdr    => (others => (others => '0')),
      -- Write Ping-Pong Buffer Signals
      wrSel       => 0,
      adcSlave    => AXI_STREAM_SLAVE_INIT_C,
      ramWrEn     => (others => '0'),
      ramWrData   => (others => '0'),
      tsWrCnt     => (others => '0'),
      tsWrCntDly  => (others => '0'),
      wrChCnt     => (others => '0'),
      wrChCntDly  => (others => '0'),
      wrBuffState => WR_BUFF_IDLE_S,
      -- Read Ping-Pong Buffer Signals
      rdSel       => 0,
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      wrdCnt      => (others => '0'),
      tsRdCnt     => (others => '0'),
      readCh      => (others => '0'),
      rdEn        => (others => '1'),
      rdLat       => (others => '0'),
      rdBuffState => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramWrEn   : slv(NUM_BUFFER_C-1 downto 0);
   signal ramWrAddr : slv(11 downto 0);
   signal ramWrData : slv(95 downto 0);

   signal ramRdAddr : slv(11 downto 0);
   signal ramRdData : Slv96Array(NUM_BUFFER_C-1 downto 0);
   signal rdEn      : slv(1 downto 0);

   signal txSlave : AxiStreamSlaveType;

begin

   -------------------------------------------
   -- Ping Pong Buffer for Data Reorganization
   -------------------------------------------
   GEN_PING_PONG :
   for i in NUM_BUFFER_C-1 downto 0 generate

      U_RAM : entity surf.SimpleDualPortRamXpm
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => "uram",
            READ_LATENCY_G => READ_LATENCY_C,
            DATA_WIDTH_G   => 96,
            BYTE_WR_EN_G   => false,
            ADDR_WIDTH_G   => 12)
         port map (
            -- Port A
            clka   => clk,
            wea(0) => ramWrEn(i),
            addra  => ramWrAddr,
            dina   => ramWrData,
            -- Port B
            enb    => rdEn(0),
            clkb   => clk,
            addrb  => ramRdAddr,
            doutb  => ramRdData(i),
            regceb => rdEn(1));

   end generate GEN_PING_PONG;

   comb : process (adcMaster, calMode, enable, r, ramRdData, rst, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      --------------------------------------------------------------------------------
      -- Ping-Pong Write Buffer
      --------------------------------------------------------------------------------

      -- Reset the strobes
      v.ramWrEn   := (others => '0');
      v.dropFrame := '0';

      -- AXI Stream Flow Control
      v.adcSlave.tReady := '0';

      -- Keep delayed copies
      v.wrChCntDly := r.wrChCnt;
      v.tsWrCntDly := r.tsWrCnt;

      -- State machine
      case r.wrBuffState is
         ----------------------------------------------------------------------
         when WR_BUFF_IDLE_S =>
            -- Check if ready to move data
            if (adcMaster.tValid = '1') and (r.buffValid(r.wrSel) = '0') then

               -- Accept the data
               v.adcSlave.tReady := '1';

               -- Check for SOF and not EOF and phase alignment to timestamp
               if (ssiGetUserSof(nexoAxisConfig(ADC_TYPE_G), adcMaster) = '1') and (adcMaster.tLast = '0') and (r.tsWrCnt = adcMaster.tData(7 downto 0)) and (enable = '1') then

                  -- Check for 1st time stamp
                  if (r.tsWrCnt = 0) then

                     -- Cache the header
                     v.eventHdr(r.wrSel) := adcMaster.tData(95 downto 0);

                  end if;

                  -- Next state
                  v.wrBuffState := WR_BUFF_MOVE_S;

               elsif (adcMaster.tLast = '1') then

                  -- Set the flag
                  v.dropFrame := '1';

               end if;

            end if;
         ----------------------------------------------------------------------
         when WR_BUFF_MOVE_S =>
            -- Check if ready to move data
            if (adcMaster.tValid = '1') then

               -- Accept the data
               v.adcSlave.tReady := '1';

               -- Write ADC data into ping-pong buffer
               v.ramWrEn(r.wrSel) := '1';
               v.ramWrData        := adcMaster.tData(95 downto 0);

               -- Increment the counter
               v.wrChCnt := r.wrChCnt + 1;

               -- Check for last channel
               if (r.wrChCnt = 15) then

                  -- Increment the counter
                  v.tsWrCnt := r.tsWrCnt + 1;

                  -- Check for last timestamp
                  if (r.tsWrCnt = 255) then

                     -- Set the flag
                     v.buffValid(r.wrSel) := '1';

                     -- Increment the index
                     if (r.wrSel = NUM_BUFFER_C-1) then
                        v.wrSel := 0;
                     else
                        v.wrSel := r.wrSel + 1;
                     end if;

                  end if;

                  -- Next state
                  v.wrBuffState := WR_BUFF_IDLE_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      --------------------------------------------------------------------------------
      -- Ping-Pong Read Buffer
      --------------------------------------------------------------------------------

      -- AXI Stream Flow Control
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- State machine
      case r.rdBuffState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if buffer is ready to move
            if (r.buffValid(r.rdSel) = '1') then

               -- Next state
               v.rdBuffState := TRIG_HDR_S;

            end if;
         ----------------------------------------------------------------------
         when TRIG_HDR_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Check for triggered readout mode
               if (r.calMode = '0') then

                  -- Don't write Trigger header
                  v.txMaster.tValid := '0';

                  -- Set the routing path
                  v.txMaster.tDest := x"00";

               -- Else calibration mode
               else

                  -- Write the Trigger header
                  v.txMaster.tValid := '1';

                  -- Set the routing path
                  v.txMaster.tDest := x"01";

               end if;

               -- Set TID = Ring Engine Stream ID
               v.txMaster.tId(3 downto 0) := r.readCh;

               -- Insert the SOF (Start of Frame) bit
               ssiSetUserSof(nexoAxisConfig(ADC_TYPE_G), v.txMaster, '1');

               -- Insert the SOR (Start of Readout) bit
               if (r.readCh = 0) then
                  nexoSetUserSor(nexoAxisConfig(ADC_TYPE_G), v.txMaster, '1');
               end if;

               -- Trigger Decision's Event ID
               v.txMaster.tData(31 downto 0) := r.calEventID;  -- Readout sequence counter

               -- Trigger Decision's Event Type
               v.txMaster.tData(47 downto 32) := x"FFFF";  -- EventType[0xFFFF] = Calibration

               -- Trigger Decision's Readout Size (zero inclusive)
               v.txMaster.tData(59 downto 48) := x"FFF";  -- 4096 time slices

               -- Ring Engine Stream ID
               v.txMaster.tData(63 downto 60) := r.readCh;

               -- Ring Engine Stream Index
               v.txMaster.tData(68 downto 64) := toSlv(STREAM_INDEX_G, 5);

               -- DDR DIMM Index
               v.txMaster.tData(70 downto 69) := toSlv(DDR_DIMM_INDEX_G, 2);

               -- ADC_TYPE_G
               if ADC_TYPE_G then
                  v.txMaster.tData(71) := '1';
               else
                  v.txMaster.tData(71) := '0';
               end if;

               -- Calibration Mode
               v.txMaster.tData(72) := '1';

               -- "TBD" field zero'd out
               v.txMaster.tData(95 downto 73) := (others => '0');

               -- Next state
               v.rdBuffState := DATA_HDR_S;

            end if;
         ----------------------------------------------------------------------
         when DATA_HDR_S =>
            -- Enable RAM reads
            v.rdEn := "11";

            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Write the Data header
               v.txMaster.tValid := '1';

               -- Copy the ADC header exactly
               v.txMaster.tData(95 downto 0) := r.eventHdr(r.rdSel);

               -- Next state
               v.rdBuffState := MOVE_DLY_S;

            end if;
         ----------------------------------------------------------------------
         when MOVE_DLY_S =>
            -- Enable RAM reads
            v.rdEn := "11";

            -- Increment the address
            v.tsRdCnt := r.tsRdCnt + 1;

            -- Check if RAM pipeline is filled
            if (r.rdLat = READ_LATENCY_C-1) then

               -- Reset the counter
               v.rdLat := (others => '0');

               -- Next State
               v.rdBuffState := MOVE_S;

            else

               -- Increment the counter
               v.rdLat := r.rdLat + 1;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            --  Hold the pipeline
            v.rdEn := "00";

            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Advance the pipeline
               v.rdEn := "11";

               -- Move the ADC data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(95 downto 0) := ramRdData(r.rdSel);

               -- Increment the counters
               v.tsRdCnt := r.tsRdCnt + 1;
               v.wrdCnt  := r.wrdCnt + 1;

               -- Check for last timestamp
               if (r.wrdCnt = 255) then

                  -- Reset the counter
                  v.tsRdCnt := (others => '0');

                  -- Increment the counter
                  v.readCh := r.readCh + 1;

                  -- Set EOF (End of Frame)
                  v.txMaster.tLast := '1';

                  -- Check for last channel
                  if (r.readCh = 15) then

                     -- Insert the EOR (End of Readout) bit
                     nexoSetUserEor(nexoAxisConfig(ADC_TYPE_G), v.txMaster, '1');

                     -- Set the flag
                     v.buffValid(r.rdSel) := '0';

                     -- Increment the index
                     if (r.rdSel = NUM_BUFFER_C-1) then
                        v.rdSel := 0;
                     else
                        v.rdSel := r.rdSel + 1;
                     end if;


                     -- Check for calibration mode
                     if (r.txMaster.tDest = x"01") then

                        -- Increment the counter
                        v.calEventID := r.calEventID + 1;

                     end if;

                     -- Next state
                     v.rdBuffState := IDLE_S;

                  else

                     -- Next state
                     v.rdBuffState := TRIG_HDR_S;

                  end if;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Keep delay copy
      v.calMode := calMode;

      -- Check if calMode asserted
      if (r.calMode = '0') and (v.calMode = '1') then

         -- Reset eventID counter
         v.calEventID := (others => '0');

      end if;

      --------------------------------------------------------------------------------
      -- Outputs
      --------------------------------------------------------------------------------

      -- Ping-Pong Buffer Write Outputs
      ramWrEn                <= r.ramWrEn;
      ramWrAddr(7 downto 0)  <= r.tsWrCntDly;
      ramWrAddr(11 downto 8) <= r.wrChCntDly;
      ramWrData              <= r.ramWrData;

      -- Ping-Pong Buffer Read Outputs
      ramRdAddr(7 downto 0)  <= r.tsRdCnt;
      ramRdAddr(11 downto 8) <= r.readCh;
      rdEn                   <= v.rdEn;  -- comb (not registered) output

      -- Write Outputs
      adcSlave   <= v.adcSlave;         -- comb (not registered) output
      dropFrame  <= r.dropFrame;
      calEventID <= r.calEventID;

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

   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 2,
         PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk         => clk,
         axisRst         => rst,
         -- Slave
         sAxisMaster     => r.txMaster,
         sAxisSlave      => txSlave,
         -- Masters
         mAxisMasters(0) => writeMaster,
         mAxisMasters(1) => compMaster,
         mAxisSlaves(0)  => writeSlave,
         mAxisSlaves(1)  => compSlave);

end rtl;
