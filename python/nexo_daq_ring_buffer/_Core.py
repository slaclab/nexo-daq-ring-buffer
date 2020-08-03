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

class Core(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
