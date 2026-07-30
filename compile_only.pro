SetVHDLVersion 2008

# Stop immediately when the first compilation error occurs
set ::osvvm::AnalyzeErrorStopCount 1


# Verification components
library osvvm_spacewire

puts "\n===== Compiling SpaceWireTbPkg.vhd ====="
analyze ./src/SpaceWireTbPkg.vhd

puts "\n===== Compiling ScoreboardPkg_SpaceWire.vhd ====="
analyze ./src/ScoreboardPkg_SpaceWire.vhd

puts "\n===== Compiling SpaceWireTx.vhd ====="
analyze ./src/SpaceWireTx.vhd

puts "\n===== Compiling SpaceWireRx.vhd ====="
analyze ./src/SpaceWireRx.vhd

puts "\n===== Compiling SpaceWireMonitor.vhd ====="
analyze ./src/SpaceWireMonitor.vhd

puts "\n===== Compiling SpaceWireDsDriverPkg.vhd ====="
analyze ./src/SpaceWireDsDriverPkg.vhd


# Fixed testbench harnesses
library spacewire_tb

puts "\n===== Compiling TestCtrl_e.vhd ====="
analyze ./testbench/TestCtrl_e.vhd

puts "\n===== Compiling MonitorTestCtrl_e.vhd ====="
analyze ./testbench/MonitorTestCtrl_e.vhd

puts "\n===== Compiling TbSpaceWire.vhd ====="
analyze ./testbench/TbSpaceWire.vhd

puts "\n===== Compiling TbSpaceWireMonitor.vhd ====="
analyze ./testbench/TbSpaceWireMonitor.vhd


# Individual tests
puts "\n===== Compiling TbSpaceWire_SendGet1.vhd ====="
analyze ./testbench/TbSpaceWire_SendGet1.vhd

puts "\n===== Compiling TbSpaceWire_Packets1.vhd ====="
analyze ./testbench/TbSpaceWire_Packets1.vhd

puts "\n===== Compiling TbSpaceWire_Traffic1.vhd ====="
analyze ./testbench/TbSpaceWire_Traffic1.vhd

puts "\n===== Compiling TbSpaceWireMonitor_Valid1.vhd ====="
analyze ./testbench/TbSpaceWireMonitor_Valid1.vhd

puts "\n===== Compiling TbSpaceWireMonitor_Errors1.vhd ====="
analyze ./testbench/TbSpaceWireMonitor_Errors1.vhd
