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

entity AxiProtocolChecker512bWrapper is
   generic (
      TPD_G        : time    := 1 ns;
      SIMULATION_G : boolean := false);
   port (
      -- AXI4 Interface
      axiClk         : in sl;
      axiRst         : in sl;
      axiWriteMaster : in AxiWriteMasterType;
      axiWriteSlave  : in AxiWriteSlaveType;
      axiReadMaster  : in AxiReadMasterType;
      axiReadSlave   : in AxiReadSlaveType);
end AxiProtocolChecker512bWrapper;

architecture mapping of AxiProtocolChecker512bWrapper is

   component AxiProtocolChecker512b
      port (
         pc_status       : out std_logic_vector(159 downto 0);
         pc_asserted     : out std_logic;
         aclk            : in  std_logic;
         aresetn         : in  std_logic;
         pc_axi_awid     : in  std_logic_vector(7 downto 0);
         pc_axi_awaddr   : in  std_logic_vector(33 downto 0);
         pc_axi_awlen    : in  std_logic_vector(7 downto 0);
         pc_axi_awsize   : in  std_logic_vector(2 downto 0);
         pc_axi_awburst  : in  std_logic_vector(1 downto 0);
         pc_axi_awlock   : in  std_logic_vector(0 downto 0);
         pc_axi_awcache  : in  std_logic_vector(3 downto 0);
         pc_axi_awprot   : in  std_logic_vector(2 downto 0);
         pc_axi_awqos    : in  std_logic_vector(3 downto 0);
         pc_axi_awregion : in  std_logic_vector(3 downto 0);
         pc_axi_awvalid  : in  std_logic;
         pc_axi_awready  : in  std_logic;
         pc_axi_wlast    : in  std_logic;
         pc_axi_wdata    : in  std_logic_vector(511 downto 0);
         pc_axi_wstrb    : in  std_logic_vector(63 downto 0);
         pc_axi_wvalid   : in  std_logic;
         pc_axi_wready   : in  std_logic;
         pc_axi_bid      : in  std_logic_vector(7 downto 0);
         pc_axi_bresp    : in  std_logic_vector(1 downto 0);
         pc_axi_bvalid   : in  std_logic;
         pc_axi_bready   : in  std_logic;
         pc_axi_arid     : in  std_logic_vector(7 downto 0);
         pc_axi_araddr   : in  std_logic_vector(33 downto 0);
         pc_axi_arlen    : in  std_logic_vector(7 downto 0);
         pc_axi_arsize   : in  std_logic_vector(2 downto 0);
         pc_axi_arburst  : in  std_logic_vector(1 downto 0);
         pc_axi_arlock   : in  std_logic_vector(0 downto 0);
         pc_axi_arcache  : in  std_logic_vector(3 downto 0);
         pc_axi_arprot   : in  std_logic_vector(2 downto 0);
         pc_axi_arqos    : in  std_logic_vector(3 downto 0);
         pc_axi_arregion : in  std_logic_vector(3 downto 0);
         pc_axi_arvalid  : in  std_logic;
         pc_axi_arready  : in  std_logic;
         pc_axi_rid      : in  std_logic_vector(7 downto 0);
         pc_axi_rlast    : in  std_logic;
         pc_axi_rdata    : in  std_logic_vector(511 downto 0);
         pc_axi_rresp    : in  std_logic_vector(1 downto 0);
         pc_axi_rvalid   : in  std_logic;
         pc_axi_rready   : in  std_logic
         );
   end component;

   signal axiRstL     : sl                := '0';
   signal pc_asserted : sl                := '0';
   signal pc_status   : slv(159 downto 0) := (others => '0');

begin


   GEN_CORE : if (SIMULATION_G) generate

      axiRstL <= not(axiRst);

      U_AxiProtocolChecker : AxiProtocolChecker512b
         port map (
            pc_status       => pc_status,
            pc_asserted     => pc_asserted,
            aclk            => axiClk,
            aresetn         => axiRstL,
            pc_axi_awid     => axiWriteMaster.awid(7 downto 0),
            pc_axi_awaddr   => axiWriteMaster.awaddr(33 downto 0),
            pc_axi_awlen    => axiWriteMaster.awlen,
            pc_axi_awsize   => axiWriteMaster.awsize,
            pc_axi_awburst  => axiWriteMaster.awburst,
            pc_axi_awlock   => axiWriteMaster.awlock(0 downto 0),
            pc_axi_awcache  => axiWriteMaster.awcache,
            pc_axi_awprot   => axiWriteMaster.awprot,
            pc_axi_awqos    => axiWriteMaster.awqos,
            pc_axi_awregion => axiWriteMaster.awregion,
            pc_axi_awvalid  => axiWriteMaster.awvalid,
            pc_axi_awready  => axiWriteSlave.awready,
            pc_axi_wlast    => axiWriteMaster.wlast,
            pc_axi_wdata    => axiWriteMaster.wdata(511 downto 0),
            pc_axi_wstrb    => axiWriteMaster.wstrb(63 downto 0),
            pc_axi_wvalid   => axiWriteMaster.wvalid,
            pc_axi_wready   => axiWriteSlave.wready,
            pc_axi_bid      => axiWriteSlave.bid(7 downto 0),
            pc_axi_bresp    => axiWriteSlave.bresp,
            pc_axi_bvalid   => axiWriteSlave.bvalid,
            pc_axi_bready   => axiWriteMaster.bready,
            pc_axi_arid     => axiReadMaster.arid(7 downto 0),
            pc_axi_araddr   => axiReadMaster.araddr(33 downto 0),
            pc_axi_arlen    => axiReadMaster.arlen,
            pc_axi_arsize   => axiReadMaster.arsize,
            pc_axi_arburst  => axiReadMaster.arburst,
            pc_axi_arlock   => axiReadMaster.arlock(0 downto 0),
            pc_axi_arcache  => axiReadMaster.arcache,
            pc_axi_arprot   => axiReadMaster.arprot,
            pc_axi_arqos    => axiReadMaster.arqos,
            pc_axi_arregion => axiReadMaster.arregion,
            pc_axi_arvalid  => axiReadMaster.arvalid,
            pc_axi_arready  => axiReadSlave.arready,
            pc_axi_rid      => axiReadSlave.rid(7 downto 0),
            pc_axi_rlast    => axiReadSlave.rlast,
            pc_axi_rdata    => axiReadSlave.rdata(511 downto 0),
            pc_axi_rresp    => axiReadSlave.rresp,
            pc_axi_rvalid   => axiReadSlave.rvalid,
            pc_axi_rready   => axiReadMaster.rready);

   end generate;

end mapping;
