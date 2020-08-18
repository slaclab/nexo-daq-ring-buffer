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
use surf.AxiDmaPkg.all;

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

entity RingBufferWriteFsm is
   generic (
      TPD_G          : time    := 1 ns;
      SIMULATION_G   : boolean := false;
      ADC_TYPE_G     : boolean := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      STREAM_INDEX_G : natural := 0);
   port (
      -- Control/Monitor Interface
      enable      : in  sl;
      dropFrame   : out sl;
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl;
      -- ADC Stream Interface
      adcMaster   : in  AxiStreamMasterType;
      adcSlave    : out AxiStreamSlaveType;
      -- DMA Write Interface
      wrReq       : out AxiWriteDmaReqType;
      wrAck       : in  AxiWriteDmaAckType;
      writeMaster : out AxiStreamMasterType;
      writeSlave  : in  AxiStreamSlaveType);
end RingBufferWriteFsm;

architecture rtl of RingBufferWriteFsm is

   type WrBuffStateType is (
      WR_BUFF_IDLE_S,
      WR_BUFF_MOVE_S);

   type RdBuffStateType is (
      RD_BUFF_IDLE_S,
      RD_BUFF_HDR_S,
      RD_BUFF_MOVE_S,
      RD_BUFF_PADDING_S,
      RD_BUFF_WAIT_S);

   type RegType is record
      dropFrame   : sl;
      -- Common Ping-Pong Buffer Signals
      buffValid   : slv(1 downto 0);
      eventHdr    : Slv96Array(1 downto 0);
      -- Write Ping-Pong Buffer Signals
      wrSel       : natural range 0 to 1;
      adcSlave    : AxiStreamSlaveType;
      ramWrEn     : slv(1 downto 0);
      ramWrData   : slv(95 downto 0);
      tsWrCnt     : slv(7 downto 0);
      wrChCnt     : slv(3 downto 0);
      wrBuffState : WrBuffStateType;
      -- Read Ping-Pong Buffer Signals
      rdSel       : natural range 0 to 1;
      writeMaster : AxiStreamMasterType;
      wrReq       : AxiWriteDmaReqType;
      tsRdCnt     : slv(7 downto 0);
      rdChCnt     : slv(3 downto 0);
      ramRdRdy    : sl;
      padCnt      : natural range 0 to 4;
      rdBuffState : RdBuffStateType;
   end record;
   constant REG_INIT_C : RegType := (
      dropFrame   => '0',
      -- Common Ping-Pong Buffer Signals
      buffValid   => (others => '0'),
      eventHdr    => (others => (others => '0')),
      -- Write Ping-Pong Buffer Signals
      wrSel       => 0,
      adcSlave    => AXI_STREAM_SLAVE_INIT_C,
      ramWrEn     => (others => '0'),
      ramWrData   => (others => '0'),
      tsWrCnt     => (others => '0'),
      wrChCnt     => (others => '0'),
      wrBuffState => WR_BUFF_IDLE_S,
      -- Read Ping-Pong Buffer Signals
      rdSel       => 0,
      writeMaster => AXI_STREAM_MASTER_INIT_C,
      wrReq       => AXI_WRITE_DMA_REQ_INIT_C,
      tsRdCnt     => (others => '0'),
      rdChCnt     => (others => '0'),
      ramRdRdy    => '0',
      padCnt      => 0,
      rdBuffState => RD_BUFF_IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramWrEn   : slv(1 downto 0);
   signal ramWrAddr : slv(11 downto 0);
   signal ramWrData : slv(95 downto 0);

   signal ramRdAddr : slv(11 downto 0);
   signal ramRdData : Slv96Array(1 downto 0);

begin

   -------------------------------------------
   -- Ping Pong Buffer for Data Reorganization
   -------------------------------------------
   GEN_PING_PONG :
   for i in 1 downto 0 generate

      U_RAM : entity surf.SimpleDualPortRamXpm
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => "uram",
            READ_LATENCY_G => 2,        -- Using REGB output
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
            clkb   => clk,
            addrb  => ramRdAddr,
            doutb  => ramRdData(i));

   end generate GEN_PING_PONG;

   comb : process (adcMaster, enable, r, ramRdData, rst, wrAck, writeSlave) is
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

                     -- Toggle the wrSel index
                     if (r.wrSel = 0) then
                        v.wrSel := 1;
                     else
                        v.wrSel := 0;
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

      -- Reset the strobes
      v.ramRdRdy := '1';

      -- AXI Stream Flow Control
      if (writeSlave.tReady = '0') then
         v.writeMaster.tValid := '0';
         v.writeMaster.tLast  := '0';
         v.writeMaster.tKeep  := (others = '1');
      end if;

      -- State machine
      case r.rdBuffState is
         ----------------------------------------------------------------------
         when RD_BUFF_IDLE_S =>
            -- Check if ready to move data
            if (r.buffValid(r.rdSel) = '1') and (wrAck.done = '0') and (wrAck.idle = '1') then

               -- Send the DMA Write REQ
               v.wrReq.request := '1';

               -- Set Memory Address offset
               v.wrReq.address(11 downto 0)  := x"000";  -- 4kB address alignment
               v.wrReq.address(15 downto 12) := r.rdChCnt;  -- Cache buffer index
               v.wrReq.address(29 downto 16) := r.eventHdr(r.rdSel)(21 downto 8);  -- Address.BIT[29:16] = TimeStamp[21:8]
               v.wrReq.address(33 downto 30) := toSlv(STREAM_INDEX_G, 4);  -- AXI Stream Index

               -- Set the max buffer size
               v.wrReq.maxSize := toSlv(4096, 32);

               -- Next state
               v.rdBuffState := RD_BUFF_HDR_S;

            end if;
         ----------------------------------------------------------------------
         when RD_BUFF_HDR_S =>
            -- Check if ready to move data
            if (v.writeMaster.tValid = '0') then

               -- Write the Data header
               v.writeMaster.tValid := '1';

               -- Copy the header exactly
               v.writeMaster.tData(95 downto 0) := r.eventHdr(r.rdSel);

               -- Next state
               v.rdBuffState := RD_BUFF_MOVE_S;

            end if;
         ----------------------------------------------------------------------
         when RD_BUFF_MOVE_S =>
            -- Check if ready to move data
            if (v.writeMaster.tValid = '0') and (r.ramRdRdy = '1') then

               -- Write the Data header
               v.writeMaster.tValid             := '1';
               v.writeMaster.tData(95 downto 0) := ramRdData(r.rdSel);

               -- Reset the flag
               v.ramRdRdy := '0';

               -- Increment the counter
               v.tsRdCnt := r.tsRdCnt + 1;

               -- Check for last timestamp
               if (r.tsRdCnt = 255) then

                  -- Increment the counter
                  v.rdChCnt := r.rdChCnt + 1;

                  -- Check for last channel
                  if (r.rdChCnt = 15) then

                     -- Set the flag
                     v.buffValid(r.rdSel) := '0';

                     -- Toggle the rdSel index
                     if (r.rdSel = 0) then
                        v.rdSel := 1;
                     else
                        v.rdSel := 0;
                     end if;

                  end if;

                  -- Check for padding write padding for charge system
                  if ADC_TYPE_G then

                     -- Next state
                     v.rdBuffState := RD_BUFF_PADDING_S;

                  else

                     -- Terminate the frame
                     v.writeMaster.tLast := '1';

                     -- Next state
                     v.rdBuffState := RD_BUFF_WAIT_S;

                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when RD_BUFF_PADDING_S =>
            -- Check if ready to move data
            if (v.writeMaster.tValid = '0') then

               -- Send the padding to fix 512-bit AXI4 alignment
               v.writeMaster.tValid := '1';

               -----------------------------------------------
               -- DDR benchmark show better memory transaction
               -- rate when on a 64B boundary
               -----------------------------------------------
               -- 3136B-3084B = 52 Bytes padding
               -- (52 Byte padding)/12 = 4.333 words
               -- 52B = 4 x 12 words + lastWord.tKeep = 0xF
               -----------------------------------------------
               if r.padCnt = 4 then

                  -- Reset the counter
                  v.padCnt := 0;

                  -- lastWord.tKeep = 0xF
                  v.writeMaster.tKeep(11 downto 0) := x"00F";

                  -- Terminate the frame
                  v.writeMaster.tLast := '1';

                  -- Next state
                  v.rdBuffState := RD_BUFF_WAIT_S;

               else
                  v.padCnt := r.padCnt + 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RD_BUFF_WAIT_S =>
            -- Check if Write DMA complete
            if (r.wrReq.request = '1') and (wrAck.done = '1') then

               -- Reset the flag
               v.wrReq.request := '0';

               -- Next state
               v.rdBuffState := RD_BUFF_IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      --------------------------------------------------------------------------------
      -- Outputs
      --------------------------------------------------------------------------------

      -- Ping-Pong Buffer Outputs
      ramWrEn                <= r.ramWrEn;
      ramWrAddr(7 downto 0)  <= r.tsWrCnt(7 downto 0);
      ramWrAddr(11 downto 8) <= r.wrChCnt;
      ramWrData              <= r.ramWrData;
      ramRdAddr(7 downto 0)  <= v.tsRdCnt;  -- comb (not registered) output
      ramRdAddr(11 downto 8) <= v.rdChCnt;  -- comb (not registered) output

      -- Write Outputs
      adcSlave    <= v.adcSlave;        -- comb (not registered) output
      writeMaster <= r.writeMaster;
      wrReq       <= r.wrReq;
      dropFrame   <= r.dropFrame;

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
