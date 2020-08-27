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

class StreamEngine(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'STREAM_INDEX_G',
            offset       = 0x00,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DDR_DIMM_INDEX_G',
            offset       = 0x00,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ADC_TYPE_G',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SIMULATION_G',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DropFrameCnt',
            offset       = 0x10,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DropTrigCnt',
            offset       = 0x14,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EofeEventCnt',
            offset       = 0x18,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CalEventID',
            offset       = 0x1C,
            bitSize      = 32,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnableEngine',
            offset       = 0x80,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CalMode',
            offset       = 0x84,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name         = "CountReset",
            offset       =  0xFC,
            bitSize      =  1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
