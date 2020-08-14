-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Package file for Ring Buffer
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;

package RingBufferPkg is

   -- Number of photon channels: 480 ASIC links x 16 channels/link = 7680
   constant NUM_PHOTON_CH_C : positive := 480*16;

   -- Number of photon channels: 120 ASIC links x 32 channels/link = 3840
   constant NUM_CHARGE_CH_C : positive := 120*32;

   -- Total Number of system channels: NUM_PHOTON_CH_C + NUM_CHARGE_CH_C = 11520
   constant NUM_SYSTEM_CH_C : positive := NUM_PHOTON_CH_C + NUM_CHARGE_CH_C;

   -- Number of channels per compression engine
   constant CH_PER_COMP_ENGINE_C : positive := 128;

   -- Total Number of compression engines: NUM_SYSTEM_CH_C/CH_PER_COMP_ENGINE_C = 90
   constant NUM_SYSTEM_COMP_ENGINE_C : positive := NUM_SYSTEM_CH_C/CH_PER_COMP_ENGINE_C;

   -- Charge System AXI stream Configuration
   constant CHARGE_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => (96/8),  -- 96-bit data interface (8 x 12-bit ADCs)
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   -- Photon System AXI stream Configuration
   constant PHOTON_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => CHARGE_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => (80/8),  -- 80-bit data interface (8 x 10-bit ADCs)
      TDEST_BITS_C  => CHARGE_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => CHARGE_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => CHARGE_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => CHARGE_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => CHARGE_AXIS_CONFIG_C.TUSER_MODE_C);

   -- DDR AXI Stream DMA Configuration
   constant DDR_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => CHARGE_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => (512/8),         -- 512-bit data interface
      TDEST_BITS_C  => CHARGE_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => CHARGE_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => CHARGE_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => CHARGE_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => CHARGE_AXIS_CONFIG_C.TUSER_MODE_C);

   function nexoAxisConfig (
      adcType : boolean)
      return AxiStreamConfigType;

end package RingBufferPkg;

package body RingBufferPkg is

   function nexoAxisConfig (
      adcType : boolean)
      return AxiStreamConfigType
   is
      variable ret : AxiStreamConfigType;
   begin
      if (adcType = true) then
         ret := CHARGE_AXIS_CONFIG_C;
      else
         ret := PHOTON_AXIS_CONFIG_C;
      end if;
      return ret;
   end function nexoAxisConfig;

end package body RingBufferPkg;
