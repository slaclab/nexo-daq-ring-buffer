-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame into memory using an AXI
-- interface.
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

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;
use nexo_daq_ring_buffer.RingBufferDmaPkg.all;

entity RingBufferDmaWrite is
   generic (
      TPD_G          : time := 1 ns;
      PIPE_STAGES_G  : natural;
      ADC_TYPE_G     : AdcType;
      STREAM_INDEX_G : natural);
   port (
      -- Clock/Reset
      axiClk         : in  sl;
      axiRst         : in  sl;
      -- Streaming Interface
      axisMaster     : in  AxiStreamMasterType;
      axisSlave      : out AxiStreamSlaveType;
      -- AXI Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType);
end RingBufferDmaWrite;

architecture rtl of RingBufferDmaWrite is

   constant WORD_SIZE_C  : positive := nexoGetWordSize(ADC_TYPE_G);
   constant MAX_CNT_C    : positive := nexoGetMaxWordCnt(ADC_TYPE_G);
   constant BURST_SIZE_C : positive := nexoGetBurstSize(ADC_TYPE_G);

   type StateType is (
      WRITE_ADDR_S,
      WRITE_DATA_S,
      WRITE_RESP_S);

   type RegType is record
      wrdCnt         : natural range 0 to MAX_CNT_C-1;
      sof            : sl;
      awlen          : slv(7 downto 0);
      axiWriteMaster : AxiWriteMasterType;
      rxSlave        : AxiStreamSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrdCnt         => 0,
      sof            => '1',
      awlen          => (others => '0'),
      axiWriteMaster => (
         awvalid     => '0',
         awaddr      => (others => '0'),
         awid        => (others => '0'),
         awlen       => getAxiLen(AXI_CONFIG_C, BURST_SIZE_C),
         awsize      => toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3),
         awburst     => "01",
         awlock      => (others => '0'),
         awprot      => (others => '0'),
         awcache     => "1111",
         awqos       => (others => '0'),
         awregion    => (others => '0'),
         wdata       => (others => '0'),
         wlast       => '0',
         wvalid      => '0',
         wid         => (others => '0'),
         wstrb       => (others => '1'),  -- always 64 byte write for performance reasons
         bready      => '0'),
      rxSlave        => AXI_STREAM_SLAVE_INIT_C,
      state          => WRITE_ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

begin

   U_AxiStreamPipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axiClk,
         axisRst     => axiRst,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (axiRst, axiWriteSlave, r, rxMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      v.rxSlave.tReady        := '0';
      v.axiWriteMaster.bready := '0';
      if axiWriteSlave.awready = '1' then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if axiWriteSlave.wready = '1' then
         v.axiWriteMaster.wvalid := '0';
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when WRITE_ADDR_S =>
            -- Init
            v.wrdCnt := 0;
            v.sof    := '1';
            v.awlen  := getAxiLen(AXI_CONFIG_C, BURST_SIZE_C);  -- used for simulation debugging

            -- Check if enabled and timeout
            if (rxMaster.tValid = '1') and (r.axiWriteMaster.awvalid = '0') then

               -- Write Address channel
               v.axiWriteMaster.awvalid              := '1';
               v.axiWriteMaster.awaddr(11 downto 0)  := x"000";  -- 4kB address alignment
               v.axiWriteMaster.awaddr(15 downto 12) := rxMaster.tData(3 downto 0);  -- Cache buffer index
               v.axiWriteMaster.awaddr(30 downto 16) := rxMaster.tData(22 downto 8);  -- Address.BIT[30:16] = TimeStamp[22:8]
               v.axiWriteMaster.awaddr(33 downto 31) := toSlv(STREAM_INDEX_G, 3);  -- AXI Stream Index

               -- Next State
               v.state := WRITE_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when WRITE_DATA_S =>
            -- Check if ready to move write data
            if (rxMaster.tValid = '1') and (v.axiWriteMaster.wvalid = '0') then

               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Write Data channel
               v.axiWriteMaster.wdata(
                  r.wrdCnt*WORD_SIZE_C+WORD_SIZE_C-1 downto
                  r.wrdCnt*WORD_SIZE_C) := rxMaster.tData(WORD_SIZE_C-1 downto 0);

               -- Check for start of frame flag
               if (r.sof = '1') then

                  -- Reset the flag
                  v.sof := '0';

                  -- Mask off the "Cache buffer index" meta-data
                  v.axiWriteMaster.wdata(3 downto 0) := (others => '0');

                  -- Write Data channel
                  v.axiWriteMaster.wlast := '0';

               end if;

               -- Check for max count
               if (r.wrdCnt = MAX_CNT_C-1) then

                  -- Reset counter
                  v.wrdCnt := 0;

                  -- Write the AXI4 word
                  v.axiWriteMaster.wvalid := '1';

                  -- Decrement the counters
                  v.awlen := r.awlen - 1;  -- used for simulation debugging

               else

                  -- Increment the counter
                  v.wrdCnt := r.wrdCnt + 1;

               end if;

               -- Check for last transaction
               if (rxMaster.tLast = '1') then

                  -- Terminate the frame
                  v.axiWriteMaster.wvalid := '1';
                  v.axiWriteMaster.wlast  := '1';

                  -- Next State
                  v.state := WRITE_RESP_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when WRITE_RESP_S =>
            -- Wait for the response
            if axiWriteSlave.bvalid = '1' then

               -- Accept the response
               v.axiWriteMaster.bready := '1';

               -- Next State
               v.state := WRITE_ADDR_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxSlave        <= v.rxSlave;
      axiWriteMaster <= r.axiWriteMaster;

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
