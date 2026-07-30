# ============================================================================
# build.pro
#
# Compile the reusable SpaceWire OSVVM verification components and the
# current SpaceWire testbench.
#
# External libraries expected to be available before this script is run:
#   - osvvm
#   - osvvm_common
#   - spacewire_light
#
# The SpaceWire Light RTL remains an external dependency for now. Later, its
# own .pro file can be included here so the complete project is portable.
# ============================================================================

SetVHDLVersion 2008

# --------------------------------------------------------------------------
# Reusable SpaceWire verification components
# --------------------------------------------------------------------------
library osvvm_spacewire

analyze ./src/SpaceWireTbPkg.vhd
analyze ./src/ScoreboardPkg_SpaceWire.vhd
analyze ./src/SpaceWireTx.vhd
analyze ./src/SpaceWireRx.vhd
analyze ./src/SpaceWireMonitor.vhd

# Direct Data/Strobe driver for monitor unit tests
analyze ./src/SpaceWireDsDriverPkg.vhd

# --------------------------------------------------------------------------
# Testbench harness and directed tests
# --------------------------------------------------------------------------
library spacewire_tb

analyze ./testbench/TestCtrl_e.vhd
analyze ./testbench/MonitorTestCtrl_e.vhd

analyze ./testbench/TbSpaceWire.vhd
analyze ./testbench/TbSpaceWireMonitor.vhd
