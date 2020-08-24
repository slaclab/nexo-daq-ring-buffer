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

entity RingBufferDmaWrite is
   generic (
      TPD_G          : time    := 1 ns;
      ADC_TYPE_G     : boolean := true;  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
      STREAM_INDEX_G : natural := 0;
      AXIS_CONFIG_G  : AxiStreamConfigType;
      AXI_CONFIG_G   : AxiConfigType);
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

   constant BURST_SIZE_C : positive := ite(ADC_TYPE_G, 3136, 2624);

   type StateType is (
      WRITE_ADDR_S,
      WRITE_DATA_S,
      WRITE_RESP_S);

   type RegType is record
      sof            : sl;
      awlen          : slv(7 downto 0);
      axiWriteMaster : AxiWriteMasterType;
      axisSlave      : AxiStreamSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sof            => '1',
      awlen          => (others => '0'),
      axiWriteMaster => (
         awvalid     => '0',
         awaddr      => (others => '0'),
         awid        => (others => '0'),
         awlen       => getAxiLen(AXI_CONFIG_G, BURST_SIZE_C),
         awsize      => toSlv(log2(AXI_CONFIG_G.DATA_BYTES_C), 3),
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
      axisSlave      => AXI_STREAM_SLAVE_INIT_C,
      state          => WRITE_ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   comb : process (axiRst, axiWriteSlave, axisMaster, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      v.axisSlave.tReady      := '0';
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
            -- Check if enabled and timeout
            if (axisMaster.tValid = '1') and (r.axiWriteMaster.awvalid = '0') and (r.axiWriteMaster.wvalid = '0') then

               -- Write Address channel
               v.axiWriteMaster.awvalid := '1';

               -- Set Memory Address offset
               v.axiWriteMaster.awaddr(11 downto 0)  := x"000";  -- 4kB address alignment
               v.axiWriteMaster.awaddr(15 downto 12) := axisMaster.tData(3 downto 0);  -- Cache buffer index
               v.axiWriteMaster.awaddr(28 downto 16) := axisMaster.tData(20 downto 8);  -- Address.BIT[28:16] = TimeStamp[20:8]
               v.axiWriteMaster.awaddr(33 downto 29) := toSlv(STREAM_INDEX_G, 5);  -- AXI Stream Index

               -- Set the local burst length
               v.awlen := getAxiLen(AXI_CONFIG_G, BURST_SIZE_C);

               -- Set the flag
               v.sof := '1';

               -- Next State
               v.state := WRITE_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when WRITE_DATA_S =>
            -- Check if ready to move write data
            if (axisMaster.tValid = '1') and (r.axiWriteMaster.awvalid = '0') and (v.axiWriteMaster.wvalid = '0') then

               -- Accept the data
               v.axisSlave.tReady := '1';

               -- Write Data channel
               v.axiWriteMaster.wvalid                                      := '1';
               v.axiWriteMaster.wdata(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0) := axisMaster.tData(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0);
               v.axiWriteMaster.wlast                                       := axisMaster.tLast;

               -- Check the flag
               if (r.sof = '1') then

                  -- Reset the flag
                  v.sof := '0';

                  -- Mask off the meta-data to be written to RAM
                  v.axiWriteMaster.wdata(3 downto 0) := (others => '0');

               end if;

               -- Decrement the counters
               v.awlen := r.awlen - 1;

               -- Check for last transaction
               if (axisMaster.tLast = '1') then

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
      axisSlave      <= v.axisSlave;
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
