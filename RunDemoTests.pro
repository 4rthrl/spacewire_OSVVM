# Build the verification components and fixed harness
include ./build.pro

# Name used in the HTML report
TestSuite SpaceWire

# Library containing TestCtrl and TbSpaceWire
library spacewire_tb

# Analyze and run the configuration in this file
RunTest ./testbench/TbSpaceWire_SendGet1.vhd
