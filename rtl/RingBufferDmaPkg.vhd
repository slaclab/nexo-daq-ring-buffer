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
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;

package RingBufferDmaPkg is

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 34,               -- 16GB per MIG interface (64GB total)
      DATA_BYTES_C => 64,               -- 512-bit data interface
      ID_BITS_C    => 8,                -- Up to 256 IDS
      LEN_BITS_C   => 8);               -- 8-bit awlen/arlen interface

   function nexoGetWordSize (
      adcType : boolean)
      return positive;

   function nexoGetMaxWordCnt (
      adcType : boolean)
      return positive;

   function nexoGetBurstSize (
      adcType : boolean)
      return positive;

end package RingBufferDmaPkg;

package body RingBufferDmaPkg is

   function nexoGetWordSize (
      adcType : boolean)
      return positive
   is
      variable ret : positive;
   begin
      if (adcType = true) then
         -- Charge
         ret := 96;                     -- 96-bits (12-bytes) per AXIS word
      else
         -- Photon
         ret := 80;                     -- 80-bits (10-bytes) per AXIS word
      end if;
      return ret;
   end function nexoGetWordSize;

   function nexoGetMaxWordCnt (
      adcType : boolean)
      return positive
   is
      variable ret : positive;
   begin
      if (adcType = true) then
         -- Charge
         ret := 5;  -- 5 x 12-byte AXIS words per 64B AXI4 word
      else
         -- Photon
         ret := 6;  -- 6 x 12-byte AXIS words per 64B AXI4 word
      end if;
      return ret;
   end function nexoGetMaxWordCnt;

   function nexoGetBurstSize (
      adcType : boolean)
      return positive
   is
      variable ret : positive;
   begin
      if (adcType = true) then
         -- Charge: 257/5 = 51.400
         ret := 52*64;                  -- 52 AXI4 words x 64B = 3328B
      else
         -- Photon: 257/6 = 42.833
         ret := 43*64;                  -- 43 AXI4 words x 64B = 2752B
      end if;
      return ret;
   end function nexoGetBurstSize;

end package body RingBufferDmaPkg;
