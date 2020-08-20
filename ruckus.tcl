# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

########################################################

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {2.7.0} ] < 0 } {exit -1}
   if { [SubmoduleCheck {surf}   {2.8.0} ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in nexo-daq-ring-buffer/ruckus.tcl"
   puts "*********************************************************\n\n"
}

########################################################

# Check for version 2020.1 of Vivado (or later)
if { [VersionCheck 2020.1] < 0 } {exit -1}

########################################################

# Load RTL Source Code
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl"
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl/Resize32b"
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl/Resize64b"
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl/Resize128b"
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl/Resize256b"
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl/Resize512b"

########################################################

loadIpCore -path "$::DIR_PATH/ip/RingBufferAxiXbar.xci"

# loadSource -path "$::DIR_PATH/ip/RingBufferAxiXbar.dcp"

########################################################

# loadIpCore -dir "$::DIR_PATH/ip/Resize32b"
# loadIpCore -dir "$::DIR_PATH/ip/Resize64b"
# loadIpCore -dir "$::DIR_PATH/ip/Resize128b"
# loadIpCore -dir "$::DIR_PATH/ip/Resize256b"
# loadIpCore -dir "$::DIR_PATH/ip/Resize512b"

loadSource -dir "$::DIR_PATH/ip/Resize32b"
loadSource -dir "$::DIR_PATH/ip/Resize64b"
loadSource -dir "$::DIR_PATH/ip/Resize128b"
loadSource -dir "$::DIR_PATH/ip/Resize256b"
loadSource -dir "$::DIR_PATH/ip/Resize512b"

########################################################
