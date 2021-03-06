-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI Crossbar IP core Wrapper
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity RingBufferAxiXbar7to1Wrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Slaves
      sAxiClk          : in  sl;
      sAxiRst          : in  sl;
      sAxiWriteMasters : in  AxiWriteMasterArray(6 downto 0) := (others => AXI_WRITE_MASTER_INIT_C);
      sAxiWriteSlaves  : out AxiWriteSlaveArray(6 downto 0)  := (others => AXI_WRITE_SLAVE_INIT_C);
      sAxiReadMasters  : in  AxiReadMasterArray(6 downto 0)  := (others => AXI_READ_MASTER_INIT_C);
      sAxiReadSlaves   : out AxiReadSlaveArray(6 downto 0)   := (others => AXI_READ_SLAVE_INIT_C);
      -- Master
      mAxiClk          : in  sl;
      mAxiRst          : in  sl;
      mAxiWriteMaster  : out AxiWriteMasterType              := AXI_WRITE_MASTER_INIT_C;
      mAxiWriteSlave   : in  AxiWriteSlaveType               := AXI_WRITE_SLAVE_INIT_C;
      mAxiReadMaster   : out AxiReadMasterType               := AXI_READ_MASTER_INIT_C;
      mAxiReadSlave    : in  AxiReadSlaveType                := AXI_READ_SLAVE_INIT_C);
end RingBufferAxiXbar7to1Wrapper;

architecture mapping of RingBufferAxiXbar7to1Wrapper is

   component RingBufferAxiXbar7to1
      port (
         INTERCONNECT_ACLK    : in  std_logic;
         INTERCONNECT_ARESETN : in  std_logic;
         S00_AXI_ARESET_OUT_N : out std_logic;
         S00_AXI_ACLK         : in  std_logic;
         S00_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S00_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S00_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_AWLOCK       : in  std_logic;
         S00_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_AWVALID      : in  std_logic;
         S00_AXI_AWREADY      : out std_logic;
         S00_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S00_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S00_AXI_WLAST        : in  std_logic;
         S00_AXI_WVALID       : in  std_logic;
         S00_AXI_WREADY       : out std_logic;
         S00_AXI_BID          : out std_logic_vector(0 downto 0);
         S00_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_BVALID       : out std_logic;
         S00_AXI_BREADY       : in  std_logic;
         S00_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S00_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S00_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_ARLOCK       : in  std_logic;
         S00_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_ARVALID      : in  std_logic;
         S00_AXI_ARREADY      : out std_logic;
         S00_AXI_RID          : out std_logic_vector(0 downto 0);
         S00_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S00_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_RLAST        : out std_logic;
         S00_AXI_RVALID       : out std_logic;
         S00_AXI_RREADY       : in  std_logic;
         S01_AXI_ARESET_OUT_N : out std_logic;
         S01_AXI_ACLK         : in  std_logic;
         S01_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S01_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S01_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_AWLOCK       : in  std_logic;
         S01_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_AWVALID      : in  std_logic;
         S01_AXI_AWREADY      : out std_logic;
         S01_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S01_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S01_AXI_WLAST        : in  std_logic;
         S01_AXI_WVALID       : in  std_logic;
         S01_AXI_WREADY       : out std_logic;
         S01_AXI_BID          : out std_logic_vector(0 downto 0);
         S01_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_BVALID       : out std_logic;
         S01_AXI_BREADY       : in  std_logic;
         S01_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S01_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S01_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_ARLOCK       : in  std_logic;
         S01_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_ARVALID      : in  std_logic;
         S01_AXI_ARREADY      : out std_logic;
         S01_AXI_RID          : out std_logic_vector(0 downto 0);
         S01_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S01_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_RLAST        : out std_logic;
         S01_AXI_RVALID       : out std_logic;
         S01_AXI_RREADY       : in  std_logic;
         S02_AXI_ARESET_OUT_N : out std_logic;
         S02_AXI_ACLK         : in  std_logic;
         S02_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S02_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S02_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_AWLOCK       : in  std_logic;
         S02_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_AWVALID      : in  std_logic;
         S02_AXI_AWREADY      : out std_logic;
         S02_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S02_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S02_AXI_WLAST        : in  std_logic;
         S02_AXI_WVALID       : in  std_logic;
         S02_AXI_WREADY       : out std_logic;
         S02_AXI_BID          : out std_logic_vector(0 downto 0);
         S02_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_BVALID       : out std_logic;
         S02_AXI_BREADY       : in  std_logic;
         S02_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S02_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S02_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_ARLOCK       : in  std_logic;
         S02_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_ARVALID      : in  std_logic;
         S02_AXI_ARREADY      : out std_logic;
         S02_AXI_RID          : out std_logic_vector(0 downto 0);
         S02_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S02_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_RLAST        : out std_logic;
         S02_AXI_RVALID       : out std_logic;
         S02_AXI_RREADY       : in  std_logic;
         S03_AXI_ARESET_OUT_N : out std_logic;
         S03_AXI_ACLK         : in  std_logic;
         S03_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S03_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S03_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S03_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S03_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S03_AXI_AWLOCK       : in  std_logic;
         S03_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S03_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S03_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S03_AXI_AWVALID      : in  std_logic;
         S03_AXI_AWREADY      : out std_logic;
         S03_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S03_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S03_AXI_WLAST        : in  std_logic;
         S03_AXI_WVALID       : in  std_logic;
         S03_AXI_WREADY       : out std_logic;
         S03_AXI_BID          : out std_logic_vector(0 downto 0);
         S03_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S03_AXI_BVALID       : out std_logic;
         S03_AXI_BREADY       : in  std_logic;
         S03_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S03_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S03_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S03_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S03_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S03_AXI_ARLOCK       : in  std_logic;
         S03_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S03_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S03_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S03_AXI_ARVALID      : in  std_logic;
         S03_AXI_ARREADY      : out std_logic;
         S03_AXI_RID          : out std_logic_vector(0 downto 0);
         S03_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S03_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S03_AXI_RLAST        : out std_logic;
         S03_AXI_RVALID       : out std_logic;
         S03_AXI_RREADY       : in  std_logic;
         S04_AXI_ARESET_OUT_N : out std_logic;
         S04_AXI_ACLK         : in  std_logic;
         S04_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S04_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S04_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S04_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S04_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S04_AXI_AWLOCK       : in  std_logic;
         S04_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S04_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S04_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S04_AXI_AWVALID      : in  std_logic;
         S04_AXI_AWREADY      : out std_logic;
         S04_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S04_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S04_AXI_WLAST        : in  std_logic;
         S04_AXI_WVALID       : in  std_logic;
         S04_AXI_WREADY       : out std_logic;
         S04_AXI_BID          : out std_logic_vector(0 downto 0);
         S04_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S04_AXI_BVALID       : out std_logic;
         S04_AXI_BREADY       : in  std_logic;
         S04_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S04_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S04_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S04_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S04_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S04_AXI_ARLOCK       : in  std_logic;
         S04_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S04_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S04_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S04_AXI_ARVALID      : in  std_logic;
         S04_AXI_ARREADY      : out std_logic;
         S04_AXI_RID          : out std_logic_vector(0 downto 0);
         S04_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S04_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S04_AXI_RLAST        : out std_logic;
         S04_AXI_RVALID       : out std_logic;
         S04_AXI_RREADY       : in  std_logic;
         S05_AXI_ARESET_OUT_N : out std_logic;
         S05_AXI_ACLK         : in  std_logic;
         S05_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S05_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S05_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S05_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S05_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S05_AXI_AWLOCK       : in  std_logic;
         S05_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S05_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S05_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S05_AXI_AWVALID      : in  std_logic;
         S05_AXI_AWREADY      : out std_logic;
         S05_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S05_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S05_AXI_WLAST        : in  std_logic;
         S05_AXI_WVALID       : in  std_logic;
         S05_AXI_WREADY       : out std_logic;
         S05_AXI_BID          : out std_logic_vector(0 downto 0);
         S05_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S05_AXI_BVALID       : out std_logic;
         S05_AXI_BREADY       : in  std_logic;
         S05_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S05_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S05_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S05_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S05_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S05_AXI_ARLOCK       : in  std_logic;
         S05_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S05_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S05_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S05_AXI_ARVALID      : in  std_logic;
         S05_AXI_ARREADY      : out std_logic;
         S05_AXI_RID          : out std_logic_vector(0 downto 0);
         S05_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S05_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S05_AXI_RLAST        : out std_logic;
         S05_AXI_RVALID       : out std_logic;
         S05_AXI_RREADY       : in  std_logic;
         S06_AXI_ARESET_OUT_N : out std_logic;
         S06_AXI_ACLK         : in  std_logic;
         S06_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S06_AXI_AWADDR       : in  std_logic_vector(33 downto 0);
         S06_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S06_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S06_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S06_AXI_AWLOCK       : in  std_logic;
         S06_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S06_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S06_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S06_AXI_AWVALID      : in  std_logic;
         S06_AXI_AWREADY      : out std_logic;
         S06_AXI_WDATA        : in  std_logic_vector(511 downto 0);
         S06_AXI_WSTRB        : in  std_logic_vector(63 downto 0);
         S06_AXI_WLAST        : in  std_logic;
         S06_AXI_WVALID       : in  std_logic;
         S06_AXI_WREADY       : out std_logic;
         S06_AXI_BID          : out std_logic_vector(0 downto 0);
         S06_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S06_AXI_BVALID       : out std_logic;
         S06_AXI_BREADY       : in  std_logic;
         S06_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S06_AXI_ARADDR       : in  std_logic_vector(33 downto 0);
         S06_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S06_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S06_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S06_AXI_ARLOCK       : in  std_logic;
         S06_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S06_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S06_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S06_AXI_ARVALID      : in  std_logic;
         S06_AXI_ARREADY      : out std_logic;
         S06_AXI_RID          : out std_logic_vector(0 downto 0);
         S06_AXI_RDATA        : out std_logic_vector(511 downto 0);
         S06_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S06_AXI_RLAST        : out std_logic;
         S06_AXI_RVALID       : out std_logic;
         S06_AXI_RREADY       : in  std_logic;
         M00_AXI_ARESET_OUT_N : out std_logic;
         M00_AXI_ACLK         : in  std_logic;
         M00_AXI_AWID         : out std_logic_vector(3 downto 0);
         M00_AXI_AWADDR       : out std_logic_vector(33 downto 0);
         M00_AXI_AWLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_AWSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_AWBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_AWLOCK       : out std_logic;
         M00_AXI_AWCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_AWPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_AWQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_AWVALID      : out std_logic;
         M00_AXI_AWREADY      : in  std_logic;
         M00_AXI_WDATA        : out std_logic_vector(511 downto 0);
         M00_AXI_WSTRB        : out std_logic_vector(63 downto 0);
         M00_AXI_WLAST        : out std_logic;
         M00_AXI_WVALID       : out std_logic;
         M00_AXI_WREADY       : in  std_logic;
         M00_AXI_BID          : in  std_logic_vector(3 downto 0);
         M00_AXI_BRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_BVALID       : in  std_logic;
         M00_AXI_BREADY       : out std_logic;
         M00_AXI_ARID         : out std_logic_vector(3 downto 0);
         M00_AXI_ARADDR       : out std_logic_vector(33 downto 0);
         M00_AXI_ARLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_ARSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_ARBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_ARLOCK       : out std_logic;
         M00_AXI_ARCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_ARPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_ARQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_ARVALID      : out std_logic;
         M00_AXI_ARREADY      : in  std_logic;
         M00_AXI_RID          : in  std_logic_vector(3 downto 0);
         M00_AXI_RDATA        : in  std_logic_vector(511 downto 0);
         M00_AXI_RRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_RLAST        : in  std_logic;
         M00_AXI_RVALID       : in  std_logic;
         M00_AXI_RREADY       : out std_logic
         );
   end component;

   signal sAxiRstL : sl;

begin

   sAxiRstL <= not(sAxiRst);

   U_AXI_XBAR : RingBufferAxiXbar7to1
      port map (
         INTERCONNECT_ACLK    => sAxiClk,
         INTERCONNECT_ARESETN => sAxiRstL,
         -- SLAVE[0]
         S00_AXI_ARESET_OUT_N => open,
         S00_AXI_ACLK         => sAxiClk,
         S00_AXI_AWID         => sAxiWriteMasters(0).awid(0 downto 0),
         S00_AXI_AWADDR       => sAxiWriteMasters(0).awaddr(33 downto 0),
         S00_AXI_AWLEN        => sAxiWriteMasters(0).awlen,
         S00_AXI_AWSIZE       => sAxiWriteMasters(0).awsize,
         S00_AXI_AWBURST      => sAxiWriteMasters(0).awburst,
         S00_AXI_AWLOCK       => sAxiWriteMasters(0).awlock(0),
         S00_AXI_AWCACHE      => sAxiWriteMasters(0).awcache,
         S00_AXI_AWPROT       => sAxiWriteMasters(0).awprot,
         S00_AXI_AWQOS        => sAxiWriteMasters(0).awqos,
         S00_AXI_AWVALID      => sAxiWriteMasters(0).awvalid,
         S00_AXI_AWREADY      => sAxiWriteSlaves(0).awready,
         S00_AXI_WDATA        => sAxiWriteMasters(0).wdata(511 downto 0),
         S00_AXI_WSTRB        => sAxiWriteMasters(0).wstrb(63 downto 0),
         S00_AXI_WLAST        => sAxiWriteMasters(0).wlast,
         S00_AXI_WVALID       => sAxiWriteMasters(0).wvalid,
         S00_AXI_WREADY       => sAxiWriteSlaves(0).wready,
         S00_AXI_BID          => sAxiWriteSlaves(0).bid(0 downto 0),
         S00_AXI_BRESP        => sAxiWriteSlaves(0).bresp,
         S00_AXI_BVALID       => sAxiWriteSlaves(0).bvalid,
         S00_AXI_BREADY       => sAxiWriteMasters(0).bready,
         S00_AXI_ARID         => sAxiReadMasters(0).arid(0 downto 0),
         S00_AXI_ARADDR       => sAxiReadMasters(0).araddr(33 downto 0),
         S00_AXI_ARLEN        => sAxiReadMasters(0).arlen,
         S00_AXI_ARSIZE       => sAxiReadMasters(0).arsize,
         S00_AXI_ARBURST      => sAxiReadMasters(0).arburst,
         S00_AXI_ARLOCK       => sAxiReadMasters(0).arlock(0),
         S00_AXI_ARCACHE      => sAxiReadMasters(0).arcache,
         S00_AXI_ARPROT       => sAxiReadMasters(0).arprot,
         S00_AXI_ARQOS        => sAxiReadMasters(0).arqos,
         S00_AXI_ARVALID      => sAxiReadMasters(0).arvalid,
         S00_AXI_ARREADY      => sAxiReadSlaves(0).arready,
         S00_AXI_RID          => sAxiReadSlaves(0).rid(0 downto 0),
         S00_AXI_RDATA        => sAxiReadSlaves(0).rdata(511 downto 0),
         S00_AXI_RRESP        => sAxiReadSlaves(0).rresp,
         S00_AXI_RLAST        => sAxiReadSlaves(0).rlast,
         S00_AXI_RVALID       => sAxiReadSlaves(0).rvalid,
         S00_AXI_RREADY       => sAxiReadMasters(0).rready,
         -- SLAVE[1]
         S01_AXI_ARESET_OUT_N => open,
         S01_AXI_ACLK         => sAxiClk,
         S01_AXI_AWID         => sAxiWriteMasters(1).awid(0 downto 0),
         S01_AXI_AWADDR       => sAxiWriteMasters(1).awaddr(33 downto 0),
         S01_AXI_AWLEN        => sAxiWriteMasters(1).awlen,
         S01_AXI_AWSIZE       => sAxiWriteMasters(1).awsize,
         S01_AXI_AWBURST      => sAxiWriteMasters(1).awburst,
         S01_AXI_AWLOCK       => sAxiWriteMasters(1).awlock(0),
         S01_AXI_AWCACHE      => sAxiWriteMasters(1).awcache,
         S01_AXI_AWPROT       => sAxiWriteMasters(1).awprot,
         S01_AXI_AWQOS        => sAxiWriteMasters(1).awqos,
         S01_AXI_AWVALID      => sAxiWriteMasters(1).awvalid,
         S01_AXI_AWREADY      => sAxiWriteSlaves(1).awready,
         S01_AXI_WDATA        => sAxiWriteMasters(1).wdata(511 downto 0),
         S01_AXI_WSTRB        => sAxiWriteMasters(1).wstrb(63 downto 0),
         S01_AXI_WLAST        => sAxiWriteMasters(1).wlast,
         S01_AXI_WVALID       => sAxiWriteMasters(1).wvalid,
         S01_AXI_WREADY       => sAxiWriteSlaves(1).wready,
         S01_AXI_BID          => sAxiWriteSlaves(1).bid(0 downto 0),
         S01_AXI_BRESP        => sAxiWriteSlaves(1).bresp,
         S01_AXI_BVALID       => sAxiWriteSlaves(1).bvalid,
         S01_AXI_BREADY       => sAxiWriteMasters(1).bready,
         S01_AXI_ARID         => sAxiReadMasters(1).arid(0 downto 0),
         S01_AXI_ARADDR       => sAxiReadMasters(1).araddr(33 downto 0),
         S01_AXI_ARLEN        => sAxiReadMasters(1).arlen,
         S01_AXI_ARSIZE       => sAxiReadMasters(1).arsize,
         S01_AXI_ARBURST      => sAxiReadMasters(1).arburst,
         S01_AXI_ARLOCK       => sAxiReadMasters(1).arlock(0),
         S01_AXI_ARCACHE      => sAxiReadMasters(1).arcache,
         S01_AXI_ARPROT       => sAxiReadMasters(1).arprot,
         S01_AXI_ARQOS        => sAxiReadMasters(1).arqos,
         S01_AXI_ARVALID      => sAxiReadMasters(1).arvalid,
         S01_AXI_ARREADY      => sAxiReadSlaves(1).arready,
         S01_AXI_RID          => sAxiReadSlaves(1).rid(0 downto 0),
         S01_AXI_RDATA        => sAxiReadSlaves(1).rdata(511 downto 0),
         S01_AXI_RRESP        => sAxiReadSlaves(1).rresp,
         S01_AXI_RLAST        => sAxiReadSlaves(1).rlast,
         S01_AXI_RVALID       => sAxiReadSlaves(1).rvalid,
         S01_AXI_RREADY       => sAxiReadMasters(1).rready,
         -- SLAVE[2]
         S02_AXI_ARESET_OUT_N => open,
         S02_AXI_ACLK         => sAxiClk,
         S02_AXI_AWID         => sAxiWriteMasters(2).awid(0 downto 0),
         S02_AXI_AWADDR       => sAxiWriteMasters(2).awaddr(33 downto 0),
         S02_AXI_AWLEN        => sAxiWriteMasters(2).awlen,
         S02_AXI_AWSIZE       => sAxiWriteMasters(2).awsize,
         S02_AXI_AWBURST      => sAxiWriteMasters(2).awburst,
         S02_AXI_AWLOCK       => sAxiWriteMasters(2).awlock(0),
         S02_AXI_AWCACHE      => sAxiWriteMasters(2).awcache,
         S02_AXI_AWPROT       => sAxiWriteMasters(2).awprot,
         S02_AXI_AWQOS        => sAxiWriteMasters(2).awqos,
         S02_AXI_AWVALID      => sAxiWriteMasters(2).awvalid,
         S02_AXI_AWREADY      => sAxiWriteSlaves(2).awready,
         S02_AXI_WDATA        => sAxiWriteMasters(2).wdata(511 downto 0),
         S02_AXI_WSTRB        => sAxiWriteMasters(2).wstrb(63 downto 0),
         S02_AXI_WLAST        => sAxiWriteMasters(2).wlast,
         S02_AXI_WVALID       => sAxiWriteMasters(2).wvalid,
         S02_AXI_WREADY       => sAxiWriteSlaves(2).wready,
         S02_AXI_BID          => sAxiWriteSlaves(2).bid(0 downto 0),
         S02_AXI_BRESP        => sAxiWriteSlaves(2).bresp,
         S02_AXI_BVALID       => sAxiWriteSlaves(2).bvalid,
         S02_AXI_BREADY       => sAxiWriteMasters(2).bready,
         S02_AXI_ARID         => sAxiReadMasters(2).arid(0 downto 0),
         S02_AXI_ARADDR       => sAxiReadMasters(2).araddr(33 downto 0),
         S02_AXI_ARLEN        => sAxiReadMasters(2).arlen,
         S02_AXI_ARSIZE       => sAxiReadMasters(2).arsize,
         S02_AXI_ARBURST      => sAxiReadMasters(2).arburst,
         S02_AXI_ARLOCK       => sAxiReadMasters(2).arlock(0),
         S02_AXI_ARCACHE      => sAxiReadMasters(2).arcache,
         S02_AXI_ARPROT       => sAxiReadMasters(2).arprot,
         S02_AXI_ARQOS        => sAxiReadMasters(2).arqos,
         S02_AXI_ARVALID      => sAxiReadMasters(2).arvalid,
         S02_AXI_ARREADY      => sAxiReadSlaves(2).arready,
         S02_AXI_RID          => sAxiReadSlaves(2).rid(0 downto 0),
         S02_AXI_RDATA        => sAxiReadSlaves(2).rdata(511 downto 0),
         S02_AXI_RRESP        => sAxiReadSlaves(2).rresp,
         S02_AXI_RLAST        => sAxiReadSlaves(2).rlast,
         S02_AXI_RVALID       => sAxiReadSlaves(2).rvalid,
         S02_AXI_RREADY       => sAxiReadMasters(2).rready,
         -- SLAVE[3]
         S03_AXI_ARESET_OUT_N => open,
         S03_AXI_ACLK         => sAxiClk,
         S03_AXI_AWID         => sAxiWriteMasters(3).awid(0 downto 0),
         S03_AXI_AWADDR       => sAxiWriteMasters(3).awaddr(33 downto 0),
         S03_AXI_AWLEN        => sAxiWriteMasters(3).awlen,
         S03_AXI_AWSIZE       => sAxiWriteMasters(3).awsize,
         S03_AXI_AWBURST      => sAxiWriteMasters(3).awburst,
         S03_AXI_AWLOCK       => sAxiWriteMasters(3).awlock(0),
         S03_AXI_AWCACHE      => sAxiWriteMasters(3).awcache,
         S03_AXI_AWPROT       => sAxiWriteMasters(3).awprot,
         S03_AXI_AWQOS        => sAxiWriteMasters(3).awqos,
         S03_AXI_AWVALID      => sAxiWriteMasters(3).awvalid,
         S03_AXI_AWREADY      => sAxiWriteSlaves(3).awready,
         S03_AXI_WDATA        => sAxiWriteMasters(3).wdata(511 downto 0),
         S03_AXI_WSTRB        => sAxiWriteMasters(3).wstrb(63 downto 0),
         S03_AXI_WLAST        => sAxiWriteMasters(3).wlast,
         S03_AXI_WVALID       => sAxiWriteMasters(3).wvalid,
         S03_AXI_WREADY       => sAxiWriteSlaves(3).wready,
         S03_AXI_BID          => sAxiWriteSlaves(3).bid(0 downto 0),
         S03_AXI_BRESP        => sAxiWriteSlaves(3).bresp,
         S03_AXI_BVALID       => sAxiWriteSlaves(3).bvalid,
         S03_AXI_BREADY       => sAxiWriteMasters(3).bready,
         S03_AXI_ARID         => sAxiReadMasters(3).arid(0 downto 0),
         S03_AXI_ARADDR       => sAxiReadMasters(3).araddr(33 downto 0),
         S03_AXI_ARLEN        => sAxiReadMasters(3).arlen,
         S03_AXI_ARSIZE       => sAxiReadMasters(3).arsize,
         S03_AXI_ARBURST      => sAxiReadMasters(3).arburst,
         S03_AXI_ARLOCK       => sAxiReadMasters(3).arlock(0),
         S03_AXI_ARCACHE      => sAxiReadMasters(3).arcache,
         S03_AXI_ARPROT       => sAxiReadMasters(3).arprot,
         S03_AXI_ARQOS        => sAxiReadMasters(3).arqos,
         S03_AXI_ARVALID      => sAxiReadMasters(3).arvalid,
         S03_AXI_ARREADY      => sAxiReadSlaves(3).arready,
         S03_AXI_RID          => sAxiReadSlaves(3).rid(0 downto 0),
         S03_AXI_RDATA        => sAxiReadSlaves(3).rdata(511 downto 0),
         S03_AXI_RRESP        => sAxiReadSlaves(3).rresp,
         S03_AXI_RLAST        => sAxiReadSlaves(3).rlast,
         S03_AXI_RVALID       => sAxiReadSlaves(3).rvalid,
         S03_AXI_RREADY       => sAxiReadMasters(3).rready,
         -- SLAVE[4]
         S04_AXI_ARESET_OUT_N => open,
         S04_AXI_ACLK         => sAxiClk,
         S04_AXI_AWID         => sAxiWriteMasters(4).awid(0 downto 0),
         S04_AXI_AWADDR       => sAxiWriteMasters(4).awaddr(33 downto 0),
         S04_AXI_AWLEN        => sAxiWriteMasters(4).awlen,
         S04_AXI_AWSIZE       => sAxiWriteMasters(4).awsize,
         S04_AXI_AWBURST      => sAxiWriteMasters(4).awburst,
         S04_AXI_AWLOCK       => sAxiWriteMasters(4).awlock(0),
         S04_AXI_AWCACHE      => sAxiWriteMasters(4).awcache,
         S04_AXI_AWPROT       => sAxiWriteMasters(4).awprot,
         S04_AXI_AWQOS        => sAxiWriteMasters(4).awqos,
         S04_AXI_AWVALID      => sAxiWriteMasters(4).awvalid,
         S04_AXI_AWREADY      => sAxiWriteSlaves(4).awready,
         S04_AXI_WDATA        => sAxiWriteMasters(4).wdata(511 downto 0),
         S04_AXI_WSTRB        => sAxiWriteMasters(4).wstrb(63 downto 0),
         S04_AXI_WLAST        => sAxiWriteMasters(4).wlast,
         S04_AXI_WVALID       => sAxiWriteMasters(4).wvalid,
         S04_AXI_WREADY       => sAxiWriteSlaves(4).wready,
         S04_AXI_BID          => sAxiWriteSlaves(4).bid(0 downto 0),
         S04_AXI_BRESP        => sAxiWriteSlaves(4).bresp,
         S04_AXI_BVALID       => sAxiWriteSlaves(4).bvalid,
         S04_AXI_BREADY       => sAxiWriteMasters(4).bready,
         S04_AXI_ARID         => sAxiReadMasters(4).arid(0 downto 0),
         S04_AXI_ARADDR       => sAxiReadMasters(4).araddr(33 downto 0),
         S04_AXI_ARLEN        => sAxiReadMasters(4).arlen,
         S04_AXI_ARSIZE       => sAxiReadMasters(4).arsize,
         S04_AXI_ARBURST      => sAxiReadMasters(4).arburst,
         S04_AXI_ARLOCK       => sAxiReadMasters(4).arlock(0),
         S04_AXI_ARCACHE      => sAxiReadMasters(4).arcache,
         S04_AXI_ARPROT       => sAxiReadMasters(4).arprot,
         S04_AXI_ARQOS        => sAxiReadMasters(4).arqos,
         S04_AXI_ARVALID      => sAxiReadMasters(4).arvalid,
         S04_AXI_ARREADY      => sAxiReadSlaves(4).arready,
         S04_AXI_RID          => sAxiReadSlaves(4).rid(0 downto 0),
         S04_AXI_RDATA        => sAxiReadSlaves(4).rdata(511 downto 0),
         S04_AXI_RRESP        => sAxiReadSlaves(4).rresp,
         S04_AXI_RLAST        => sAxiReadSlaves(4).rlast,
         S04_AXI_RVALID       => sAxiReadSlaves(4).rvalid,
         S04_AXI_RREADY       => sAxiReadMasters(4).rready,
         -- SLAVE[5]
         S05_AXI_ARESET_OUT_N => open,
         S05_AXI_ACLK         => sAxiClk,
         S05_AXI_AWID         => sAxiWriteMasters(5).awid(0 downto 0),
         S05_AXI_AWADDR       => sAxiWriteMasters(5).awaddr(33 downto 0),
         S05_AXI_AWLEN        => sAxiWriteMasters(5).awlen,
         S05_AXI_AWSIZE       => sAxiWriteMasters(5).awsize,
         S05_AXI_AWBURST      => sAxiWriteMasters(5).awburst,
         S05_AXI_AWLOCK       => sAxiWriteMasters(5).awlock(0),
         S05_AXI_AWCACHE      => sAxiWriteMasters(5).awcache,
         S05_AXI_AWPROT       => sAxiWriteMasters(5).awprot,
         S05_AXI_AWQOS        => sAxiWriteMasters(5).awqos,
         S05_AXI_AWVALID      => sAxiWriteMasters(5).awvalid,
         S05_AXI_AWREADY      => sAxiWriteSlaves(5).awready,
         S05_AXI_WDATA        => sAxiWriteMasters(5).wdata(511 downto 0),
         S05_AXI_WSTRB        => sAxiWriteMasters(5).wstrb(63 downto 0),
         S05_AXI_WLAST        => sAxiWriteMasters(5).wlast,
         S05_AXI_WVALID       => sAxiWriteMasters(5).wvalid,
         S05_AXI_WREADY       => sAxiWriteSlaves(5).wready,
         S05_AXI_BID          => sAxiWriteSlaves(5).bid(0 downto 0),
         S05_AXI_BRESP        => sAxiWriteSlaves(5).bresp,
         S05_AXI_BVALID       => sAxiWriteSlaves(5).bvalid,
         S05_AXI_BREADY       => sAxiWriteMasters(5).bready,
         S05_AXI_ARID         => sAxiReadMasters(5).arid(0 downto 0),
         S05_AXI_ARADDR       => sAxiReadMasters(5).araddr(33 downto 0),
         S05_AXI_ARLEN        => sAxiReadMasters(5).arlen,
         S05_AXI_ARSIZE       => sAxiReadMasters(5).arsize,
         S05_AXI_ARBURST      => sAxiReadMasters(5).arburst,
         S05_AXI_ARLOCK       => sAxiReadMasters(5).arlock(0),
         S05_AXI_ARCACHE      => sAxiReadMasters(5).arcache,
         S05_AXI_ARPROT       => sAxiReadMasters(5).arprot,
         S05_AXI_ARQOS        => sAxiReadMasters(5).arqos,
         S05_AXI_ARVALID      => sAxiReadMasters(5).arvalid,
         S05_AXI_ARREADY      => sAxiReadSlaves(5).arready,
         S05_AXI_RID          => sAxiReadSlaves(5).rid(0 downto 0),
         S05_AXI_RDATA        => sAxiReadSlaves(5).rdata(511 downto 0),
         S05_AXI_RRESP        => sAxiReadSlaves(5).rresp,
         S05_AXI_RLAST        => sAxiReadSlaves(5).rlast,
         S05_AXI_RVALID       => sAxiReadSlaves(5).rvalid,
         S05_AXI_RREADY       => sAxiReadMasters(5).rready,
         -- SLAVE[6]
         S06_AXI_ARESET_OUT_N => open,
         S06_AXI_ACLK         => sAxiClk,
         S06_AXI_AWID         => sAxiWriteMasters(6).awid(0 downto 0),
         S06_AXI_AWADDR       => sAxiWriteMasters(6).awaddr(33 downto 0),
         S06_AXI_AWLEN        => sAxiWriteMasters(6).awlen,
         S06_AXI_AWSIZE       => sAxiWriteMasters(6).awsize,
         S06_AXI_AWBURST      => sAxiWriteMasters(6).awburst,
         S06_AXI_AWLOCK       => sAxiWriteMasters(6).awlock(0),
         S06_AXI_AWCACHE      => sAxiWriteMasters(6).awcache,
         S06_AXI_AWPROT       => sAxiWriteMasters(6).awprot,
         S06_AXI_AWQOS        => sAxiWriteMasters(6).awqos,
         S06_AXI_AWVALID      => sAxiWriteMasters(6).awvalid,
         S06_AXI_AWREADY      => sAxiWriteSlaves(6).awready,
         S06_AXI_WDATA        => sAxiWriteMasters(6).wdata(511 downto 0),
         S06_AXI_WSTRB        => sAxiWriteMasters(6).wstrb(63 downto 0),
         S06_AXI_WLAST        => sAxiWriteMasters(6).wlast,
         S06_AXI_WVALID       => sAxiWriteMasters(6).wvalid,
         S06_AXI_WREADY       => sAxiWriteSlaves(6).wready,
         S06_AXI_BID          => sAxiWriteSlaves(6).bid(0 downto 0),
         S06_AXI_BRESP        => sAxiWriteSlaves(6).bresp,
         S06_AXI_BVALID       => sAxiWriteSlaves(6).bvalid,
         S06_AXI_BREADY       => sAxiWriteMasters(6).bready,
         S06_AXI_ARID         => sAxiReadMasters(6).arid(0 downto 0),
         S06_AXI_ARADDR       => sAxiReadMasters(6).araddr(33 downto 0),
         S06_AXI_ARLEN        => sAxiReadMasters(6).arlen,
         S06_AXI_ARSIZE       => sAxiReadMasters(6).arsize,
         S06_AXI_ARBURST      => sAxiReadMasters(6).arburst,
         S06_AXI_ARLOCK       => sAxiReadMasters(6).arlock(0),
         S06_AXI_ARCACHE      => sAxiReadMasters(6).arcache,
         S06_AXI_ARPROT       => sAxiReadMasters(6).arprot,
         S06_AXI_ARQOS        => sAxiReadMasters(6).arqos,
         S06_AXI_ARVALID      => sAxiReadMasters(6).arvalid,
         S06_AXI_ARREADY      => sAxiReadSlaves(6).arready,
         S06_AXI_RID          => sAxiReadSlaves(6).rid(0 downto 0),
         S06_AXI_RDATA        => sAxiReadSlaves(6).rdata(511 downto 0),
         S06_AXI_RRESP        => sAxiReadSlaves(6).rresp,
         S06_AXI_RLAST        => sAxiReadSlaves(6).rlast,
         S06_AXI_RVALID       => sAxiReadSlaves(6).rvalid,
         S06_AXI_RREADY       => sAxiReadMasters(6).rready,
         -- MASTER
         M00_AXI_ARESET_OUT_N => open,
         M00_AXI_ACLK         => mAxiClk,
         M00_AXI_AWID         => mAxiWriteMaster.awid(3 downto 0),
         M00_AXI_AWADDR       => mAxiWriteMaster.awaddr(33 downto 0),
         M00_AXI_AWLEN        => mAxiWriteMaster.awlen,
         M00_AXI_AWSIZE       => mAxiWriteMaster.awsize,
         M00_AXI_AWBURST      => mAxiWriteMaster.awburst,
         M00_AXI_AWLOCK       => mAxiWriteMaster.awlock(0),
         M00_AXI_AWCACHE      => mAxiWriteMaster.awcache,
         M00_AXI_AWPROT       => mAxiWriteMaster.awprot,
         M00_AXI_AWQOS        => mAxiWriteMaster.awqos,
         M00_AXI_AWVALID      => mAxiWriteMaster.awvalid,
         M00_AXI_AWREADY      => mAxiWriteSlave.awready,
         M00_AXI_WDATA        => mAxiWriteMaster.wdata(511 downto 0),
         M00_AXI_WSTRB        => mAxiWriteMaster.wstrb(63 downto 0),
         M00_AXI_WLAST        => mAxiWriteMaster.wlast,
         M00_AXI_WVALID       => mAxiWriteMaster.wvalid,
         M00_AXI_WREADY       => mAxiWriteSlave.wready,
         M00_AXI_BID          => mAxiWriteSlave.bid(3 downto 0),
         M00_AXI_BRESP        => mAxiWriteSlave.bresp,
         M00_AXI_BVALID       => mAxiWriteSlave.bvalid,
         M00_AXI_BREADY       => mAxiWriteMaster.bready,
         M00_AXI_ARID         => mAxiReadMaster.arid(3 downto 0),
         M00_AXI_ARADDR       => mAxiReadMaster.araddr(33 downto 0),
         M00_AXI_ARLEN        => mAxiReadMaster.arlen,
         M00_AXI_ARSIZE       => mAxiReadMaster.arsize,
         M00_AXI_ARBURST      => mAxiReadMaster.arburst,
         M00_AXI_ARLOCK       => mAxiReadMaster.arlock(0),
         M00_AXI_ARCACHE      => mAxiReadMaster.arcache,
         M00_AXI_ARPROT       => mAxiReadMaster.arprot,
         M00_AXI_ARQOS        => mAxiReadMaster.arqos,
         M00_AXI_ARVALID      => mAxiReadMaster.arvalid,
         M00_AXI_ARREADY      => mAxiReadSlave.arready,
         M00_AXI_RID          => mAxiReadSlave.rid(3 downto 0),
         M00_AXI_RDATA        => mAxiReadSlave.rdata(511 downto 0),
         M00_AXI_RRESP        => mAxiReadSlave.rresp,
         M00_AXI_RLAST        => mAxiReadSlave.rlast,
         M00_AXI_RVALID       => mAxiReadSlave.rvalid,
         M00_AXI_RREADY       => mAxiReadMaster.rready);

end mapping;
