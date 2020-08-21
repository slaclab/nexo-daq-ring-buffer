-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Dummy Rate Generator for debugging and testing
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

library nexo_daq_ring_buffer;
use nexo_daq_ring_buffer.RingBufferPkg.all;

library nexo_daq_trigger_decision;
use nexo_daq_trigger_decision.TriggerDecisionPkg.all;

entity RateGenerator is
   generic (
      TPD_G             : time     := 1 ns;
      ADC_TYPE_G        : boolean  := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      NUM_ADC_STREAMS_G : positive := 15;
      CLK_FREQ_G        : real     := 250.0E+6);
   port (
      ddrRst           : in  sl;
      -- Clock and Reset
      coreClk          : in  sl;
      coreRst          : in  sl;
      -- ADC Interface
      adcClk           : in  sl;
      adcRst           : in  sl;
      adcMasters       : out AxiStreamMasterArray(NUM_ADC_STREAMS_G-1 downto 0);
      adcSlaves        : in  AxiStreamSlaveArray(NUM_ADC_STREAMS_G-1 downto 0);
      -- Trigger Decision Interface
      trigClk          : in  sl;
      trigRst          : in  sl;
      trigRdMaster     : out AxiStreamMasterType;
      trigRdSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end RateGenerator;

architecture rtl of RateGenerator is

   constant TIMER_C : natural := integer(CLK_FREQ_G / 2.0E+6) - 1;

   type StateType is (
      IDLE_S,
      ADC_HDR_S,
      ADC_DATA_S,
      TRIG_S);

   type RegType is record
      trigRate       : slv(15 downto 0);
      trigCnt        : slv(15 downto 0);
      timer          : natural range 0 to TIMER_C;
      cntRst         : sl;
      dropCnt        : slv(31 downto 0);
      timestamp      : slv(TS_WIDTH_C-1 downto 0);
      eventCnt       : slv(47 downto 0);
      adcWrd         : natural range 0 to 15;
      adcTxMasters   : AxiStreamMasterArray(NUM_ADC_STREAMS_G-1 downto 0);
      trigTxMaster   : AxiStreamMasterType;
      state          : StateType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   constant REG_INIT_C : RegType := (
      trigRate       => (others => '1'),
      -- trigCnt        => (others => '1'),
      trigCnt        => (others => '0'),
      timer          => TIMER_C,
      cntRst         => '0',
      dropCnt        => (others => '0'),
      timestamp      => (others => '0'),
      eventCnt       => (others => '0'),
      adcWrd         => 0,
      adcTxMasters   => (others => AXI_STREAM_MASTER_INIT_C),
      trigTxMaster   => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal adcTxSlaves : AxiStreamSlaveArray(NUM_ADC_STREAMS_G-1 downto 0);
   signal trigTxSlave : AxiStreamSlaveType;

   signal memReset : sl;

begin

   U_start : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => coreClk,
         dataIn  => ddrRst,
         dataOut => memReset);

   -----------------------------------------
   -- Convert AXI-Lite bus to coreClk domain
   -----------------------------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => false,
         NUM_ADDR_BITS_G => 8)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => sAxilReadMaster,
         sAxiReadSlave   => sAxilReadSlave,
         sAxiWriteMaster => sAxilWriteMaster,
         sAxiWriteSlave  => sAxilWriteSlave,
         -- Master Interface
         mAxiClk         => coreClk,
         mAxiClkRst      => coreRst,
         mAxiReadMaster  => axilReadMaster,
         mAxiReadSlave   => axilReadSlave,
         mAxiWriteMaster => axilWriteMaster,
         mAxiWriteSlave  => axilWriteSlave);

   comb : process (adcTxSlaves, axilReadMaster, axilWriteMaster, coreRst,
                   memReset, r, trigTxSlave) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
      variable i      : natural;
      variable txRdy  : sl;
   begin
      -- Latch the current value
      v := r;

      if (memReset = '0') then

         -- 2 MHz timer
         if r.timer /= 0 then
            -- Decrement the counter
            v.timer := r.timer - 1;
         elsif (r.state /= IDLE_S) then
            -- Increment the counter
            v.dropCnt := r.dropCnt + 1;
         end if;

      end if;

      -- AXI Stream Flow Control
      txRdy := '1';
      for i in 0 to NUM_ADC_STREAMS_G-1 loop
         if (r.adcTxMasters(i).tValid = '1') then
            txRdy := '0';
         end if;
         if (adcTxSlaves(i).tReady = '1') then
            v.adcTxMasters(i).tValid := '0';
            v.adcTxMasters(i).tLast  := '0';
            v.adcTxMasters(i).tUser  := (others => '0');
         end if;
      end loop;

      if (trigTxSlave.tReady = '1') then
         v.trigTxMaster.tValid := '0';
         v.trigTxMaster.tLast  := '0';
         v.trigTxMaster.tUser  := (others => '0');
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for timeout
            if r.timer = 0 then

               -- Set the timer
               v.timer := TIMER_C;

               -- Next state
               v.state := ADC_HDR_S;

            end if;
         ----------------------------------------------------------------------
         when ADC_HDR_S =>
            -- Check if ready to move data
            if (txRdy = '1') then

               for i in 0 to NUM_ADC_STREAMS_G-1 loop

                  -- Write the Data header
                  v.adcTxMasters(i).tValid                       := '1';
                  v.adcTxMasters(i).tData(TS_WIDTH_C-1 downto 0) := r.timestamp;
                  v.adcTxMasters(i).tData(95 downto TS_WIDTH_C)  := (others => '0');

                  -- Insert the SOF (Start of Frame) bit
                  ssiSetUserSof(TRIG_DECISION_AXIS_CONFIG_C, v.adcTxMasters(i), '1');

               end loop;

               -- Next state
               v.state := ADC_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when ADC_DATA_S =>
            -- Check if ready to move data
            if (txRdy = '1') then

               for i in 0 to NUM_ADC_STREAMS_G-1 loop

                  -- Write the Data header
                  v.adcTxMasters(i).tValid := '1';

                  v.adcTxMasters(i).tData := (others => '0');

                  v.adcTxMasters(i).tData(7 downto 0)  := r.timestamp(7 downto 0);
                  v.adcTxMasters(i).tData(15 downto 8) := toSlv(r.adcWrd, 8)+1;

                  -- if ADC_TYPE_G then
                  -- for j in 0 to 7 loop
                  -- v.adcTxMasters(i).tData(12*j+11 downto 12*j) := toSlv((128*i+r.adcWrd*8+j) mod 2**12, 12);
                  -- end loop;
                  -- else
                  -- for j in 0 to 7 loop
                  -- v.adcTxMasters(i).tData(10*j+9 downto 10*j) := toSlv((128*i+r.adcWrd*8+j) mod 2**10, 10);
                  -- end loop;
                  -- end if;

               end loop;

               -- Check for last work
               if (r.adcWrd = 15) then

                  -- Reset the counter
                  v.adcWrd := 0;

                  -- Terminate the frame
                  for i in 0 to NUM_ADC_STREAMS_G-1 loop
                     v.adcTxMasters(i).tLast := '1';
                  end loop;

                  -- Increment the counter
                  v.timestamp := r.timestamp + 1;

                  -- Check trigger
                  if (r.timestamp(11 downto 0) = 4095) then

                     -- Check for trigger decision
                     if (r.trigCnt = 0) then

                        -- Preset the counter
                        v.trigCnt := r.trigRate;

                        -- Next state
                        v.state := TRIG_S;

                     else

                        -- Decrement the counter
                        v.trigCnt := r.trigCnt - 1;

                        -- Next state
                        v.state := IDLE_S;

                     end if;

                  else

                     -- Next state
                     v.state := IDLE_S;

                  end if;

               else

                  -- Increment the counter
                  v.adcWrd := r.adcWrd + 1;

               end if;
            end if;
         ----------------------------------------------------------------------
         when TRIG_S =>
            -- Check if ready to move data
            if (v.trigTxMaster.tValid = '0') then

               -- Write the trigger decision
               v.trigTxMaster.tValid := '1';
               v.trigTxMaster.tLast  := '1';

               -- Insert the SOF bit
               ssiSetUserSof(TRIG_DECISION_AXIS_CONFIG_C, v.trigTxMaster, '1');

               v.trigTxMaster.tData(31 downto 0)   := r.eventCnt(31 downto 0);  -- Event ID
               v.trigTxMaster.tData(47 downto 32)  := r.eventCnt(47 downto 32);  -- Event Type
               v.trigTxMaster.tData(59 downto 48)  := toSlv(4095, 12);  -- Readout Size = 4096 time slices
               v.trigTxMaster.tData(107 downto 64) := r.timestamp - 4096;  -- Readout the data from 4096 time slices earlier

               -- Increment the counter
               v.eventCnt := r.eventCnt + 1;

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      --------------------------------------------------------------------------------
      -- AXI-Lite Register Transactions
      --------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      axiSlaveRegisterR(axilEp, x"00", 0, r.dropCnt);
      axiSlaveRegisterR(axilEp, x"04", 0, memReset);
      axiSlaveRegister (axilEp, x"80", 0, v.trigRate);
      axiSlaveRegister (axilEp, x"FC", 0, v.cntRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      --------------------------------------------------------------------------------

      -- Reset strobes
      v.cntRst := '0';

      -- Check for counter reset
      if (r.cntRst = '1') then
         v.dropCnt := (others => '0');
      end if;

      -- Check for change in trigger rate
      if (r.trigRate /= v.trigRate) then
         -- Preset the counter
         v.trigCnt := v.trigRate;
      end if;

      --------------------------------------------------------------------------------

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

      -- Reset
      if (coreRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (coreClk) is
   begin
      if rising_edge(coreClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_VEC : for i in NUM_ADC_STREAMS_G-1 downto 0 generate
      U_ASYNC_ADC : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => 0,
            -- FIFO configurations
            MEMORY_TYPE_G       => "distributed",
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 5,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => nexoAxisConfig(ADC_TYPE_G),
            MASTER_AXI_CONFIG_G => nexoAxisConfig(ADC_TYPE_G))
         port map (
            -- Slave Port
            sAxisClk    => coreClk,
            sAxisRst    => coreRst,
            sAxisMaster => r.adcTxMasters(i),
            sAxisSlave  => adcTxSlaves(i),
            -- Master Port
            mAxisClk    => adcClk,
            mAxisRst    => adcRst,
            mAxisMaster => adcMasters(i),
            mAxisSlave  => adcSlaves(i));
   end generate GEN_VEC;

   U_ASYNC_TRIG : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         -- FIFO configurations
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 5,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => TRIG_DECISION_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => TRIG_DECISION_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => coreClk,
         sAxisRst    => coreRst,
         sAxisMaster => r.trigTxMaster,
         sAxisSlave  => trigTxSlave,
         -- Master Port
         mAxisClk    => trigClk,
         mAxisRst    => trigRst,
         mAxisMaster => trigRdMaster,
         mAxisSlave  => trigRdSlave);

end rtl;
