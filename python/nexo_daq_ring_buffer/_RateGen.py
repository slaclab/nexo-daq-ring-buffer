#-----------------------------------------------------------------------------
# This file is part of the 'nexo-daq-ring-buffer'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'nexo-daq-ring-buffer', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class RateGen(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'DropCnt',
            offset       = 0x00,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TrigRate',
            offset       = 0x80,
            bitSize      = 16,
            mode         = 'RW',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteCommand(
            name         = "CountReset",
            offset       =  0xFC,
            bitSize      =  1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
