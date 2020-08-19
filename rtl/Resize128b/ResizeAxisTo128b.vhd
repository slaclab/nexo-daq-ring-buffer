-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXIS Resize to 128b Resize IP core Wrapper
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
use surf.AxiStreamPkg.all;

entity ResizeAxisTo128b is
   generic (
      TPD_G      : time    := 1 ns;
      ADC_TYPE_G : boolean := true);  -- True: 12-bit ADC for CHARGE, False: 10-bit ADC for PHOTON
   port (
      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      mAxisSlave  : in  AxiStreamSlaveType);
end ResizeAxisTo128b;

architecture mapping of ResizeAxisTo128b is

   component Axis96bto128b
      port (
         aclk          : in  std_logic;
         aresetn       : in  std_logic;
         s_axis_tvalid : in  std_logic;
         s_axis_tready : out std_logic;
         s_axis_tdata  : in  std_logic_vector(95 downto 0);
         s_axis_tkeep  : in  std_logic_vector(11 downto 0);
         s_axis_tlast  : in  std_logic;
         s_axis_tid    : in  std_logic_vector(7 downto 0);
         s_axis_tdest  : in  std_logic_vector(7 downto 0);
         s_axis_tuser  : in  std_logic_vector(95 downto 0);
         m_axis_tvalid : out std_logic;
         m_axis_tready : in  std_logic;
         m_axis_tdata  : out std_logic_vector(127 downto 0);
         m_axis_tkeep  : out std_logic_vector(15 downto 0);
         m_axis_tlast  : out std_logic;
         m_axis_tid    : out std_logic_vector(7 downto 0);
         m_axis_tdest  : out std_logic_vector(7 downto 0);
         m_axis_tuser  : out std_logic_vector(127 downto 0)
         );
   end component;

   component Axis80bto128b
      port (
         aclk          : in  std_logic;
         aresetn       : in  std_logic;
         s_axis_tvalid : in  std_logic;
         s_axis_tready : out std_logic;
         s_axis_tdata  : in  std_logic_vector(79 downto 0);
         s_axis_tkeep  : in  std_logic_vector(9 downto 0);
         s_axis_tlast  : in  std_logic;
         s_axis_tid    : in  std_logic_vector(7 downto 0);
         s_axis_tdest  : in  std_logic_vector(7 downto 0);
         s_axis_tuser  : in  std_logic_vector(79 downto 0);
         m_axis_tvalid : out std_logic;
         m_axis_tready : in  std_logic;
         m_axis_tdata  : out std_logic_vector(127 downto 0);
         m_axis_tkeep  : out std_logic_vector(15 downto 0);
         m_axis_tlast  : out std_logic;
         m_axis_tid    : out std_logic_vector(7 downto 0);
         m_axis_tdest  : out std_logic_vector(7 downto 0);
         m_axis_tuser  : out std_logic_vector(127 downto 0)
         );
   end component;

   signal axisRstL : sl;

begin

   axisRstL <= not(axisRst);

   GEN_CHARGE : if (ADC_TYPE_G = true) generate
      U_Resize : Axis96bto128b
         port map (
            -- Clock and reset
            aclk          => axisClk,
            aresetn       => axisRstL,
            -- Slave Port
            s_axis_tvalid => sAxisMaster.tvalid,
            s_axis_tready => sAxisSlave.tready,
            s_axis_tdata  => sAxisMaster.tdata(95 downto 0),
            s_axis_tkeep  => sAxisMaster.tkeep(11 downto 0),
            s_axis_tlast  => sAxisMaster.tlast,
            s_axis_tid    => sAxisMaster.tid(7 downto 0),
            s_axis_tdest  => sAxisMaster.tdest(7 downto 0),
            s_axis_tuser  => sAxisMaster.tuser(95 downto 0),
            -- Master Port
            m_axis_tvalid => mAxisMaster.tvalid,
            m_axis_tready => mAxisSlave.tready,
            m_axis_tdata  => mAxisMaster.tdata(127 downto 0),
            m_axis_tkeep  => mAxisMaster.tkeep(15 downto 0),
            m_axis_tlast  => mAxisMaster.tlast,
            m_axis_tid    => mAxisMaster.tid(7 downto 0),
            m_axis_tdest  => mAxisMaster.tdest(7 downto 0),
            m_axis_tuser  => mAxisMaster.tuser(127 downto 0));
   end generate;

   GEN_PHOTON : if (ADC_TYPE_G = false) generate
      U_Resize : Axis80bto128b
         port map (
            -- Clock and reset
            aclk          => axisClk,
            aresetn       => axisRstL,
            -- Slave Port
            s_axis_tvalid => sAxisMaster.tvalid,
            s_axis_tready => sAxisSlave.tready,
            s_axis_tdata  => sAxisMaster.tdata(79 downto 0),
            s_axis_tkeep  => sAxisMaster.tkeep(9 downto 0),
            s_axis_tlast  => sAxisMaster.tlast,
            s_axis_tid    => sAxisMaster.tid(7 downto 0),
            s_axis_tdest  => sAxisMaster.tdest(7 downto 0),
            s_axis_tuser  => sAxisMaster.tuser(79 downto 0),
            -- Master Port
            m_axis_tvalid => mAxisMaster.tvalid,
            m_axis_tready => mAxisSlave.tready,
            m_axis_tdata  => mAxisMaster.tdata(127 downto 0),
            m_axis_tkeep  => mAxisMaster.tkeep(15 downto 0),
            m_axis_tlast  => mAxisMaster.tlast,
            m_axis_tid    => mAxisMaster.tid(7 downto 0),
            m_axis_tdest  => mAxisMaster.tdest(7 downto 0),
            m_axis_tuser  => mAxisMaster.tuser(127 downto 0));
   end generate;

end mapping;
