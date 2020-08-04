-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Package file for Ring Buffer
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;

package RingBufferPkg is

   -- Number of AXI stream lanes from channel bond to ring buffer
   constant CH_BOND_TO_RING_LANES_C : positive := 1;

   -- Ring Buffer AXI Stream Configuration
   constant RING_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,               -- 64-bit data interface
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,               -- BIT0=EOFE, BIT1=SOF
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

end package RingBufferPkg;
