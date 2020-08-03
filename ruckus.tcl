# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

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

# Check for version 2020.1 of Vivado (or later)
if { [VersionCheck 2020.1] < 0 } {exit -1}

# Load Source Code
loadSource -lib nexo_daq_ring_buffer -dir "$::DIR_PATH/rtl"
