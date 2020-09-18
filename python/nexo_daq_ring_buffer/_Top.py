#-----------------------------------------------------------------------------
# This file is part of the 'nexo-daq-ring-buffer'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'nexo-daq-ring-buffer', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue              as pr
import nexo_daq_ring_buffer as ringBuff

class Top(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        # Refer to RingBufferTop.vhd's STREAMS_C definition
        numStream = [7,7,8,8]

        for i in range(4):
            self.add(ringBuff.Dimm(
                name      = f'Dimm[{i}]',
                offset    = i*0x1000, # Refer to RingBufferTop.vhd's AXIL_XBAR_CONFIG_C definition
                numStream = numStream[i],
            ))
