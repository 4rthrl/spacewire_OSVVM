# Installation and Simulation

This guide describes the required directory layout, dependencies and commands
needed to run all simulations in this repository.

The instructions assume Linux and a VHDL-2008 version of QuestaSim or ModelSim.
The project was developed with QuestaSim Pro Microchip Edition 2024.3.

## 1. Required software

Install:

- Git
- Subversion
- QuestaSim or ModelSim with VHDL-2008 support

For Ubuntu or Debian:

```bash
sudo apt install git subversion
```

Make sure the simulator command is available:

```bash
vsim
```

## 2. Workspace layout

Create one workspace containing this repository and its dependencies:

```text
~/spacewire-osvvm-workspace/
├── OsvvmLibraries/
├── spacewire_light/
├── spacewire-osvvm/
└── sim/
```

The directory names are used by the commands below. Other locations can be
used, but the relative paths must then be changed accordingly.

Create the workspace:

```bash
mkdir -p ~/spacewire-osvvm-workspace/sim
cd ~/spacewire-osvvm-workspace
```

## 3. Clone this repository

```bash
git clone \
  https://github.com/4rthrl/spacewire_OSVVM.git \
  spacewire-osvvm
```

## 4. Download OSVVM

Clone the complete OSVVM library collection, including its submodules:

```bash
git clone --recursive \
  https://github.com/OSVVM/OsvvmLibraries.git
```

This provides both the main `osvvm` library and `osvvm_common`.

## 5. Download SpaceWire Light

The original SpaceWire Light source is available from OpenCores:

```bash
svn checkout \
  https://opencores.org/ocsvn/spacewire_light/spacewire_light/trunk \
  spacewire_light
```

The VHDL RTL used by this project is located in:

```text
spacewire_light/rtl/vhdl/
```

Only the FIFO-style `spwstream` implementation is required. The optional
AMBA/GRLIB implementation is not needed for these simulations.

## 6. Start the simulator

Start QuestaSim from the simulation directory:

```bash
cd ~/spacewire-osvvm-workspace/sim
vsim
```

Starting the simulator here keeps the compiled library mappings in the local
`sim/modelsim.ini` file.

In the QuestaSim Transcript, load the OSVVM scripting commands:

```tcl
source ../OsvvmLibraries/Scripts/StartUp.tcl
```

## 7. Compile OSVVM

This is normally required only during the initial setup or after updating
OSVVM:

```tcl
build ../OsvvmLibraries
```

## 8. Compile SpaceWire Light

Create the following file:

```text
~/spacewire-osvvm-workspace/sim/SpaceWireLight.pro
```

with this content:

```tcl
SetVHDLVersion 2008

library spacewire_light

analyze ../spacewire_light/rtl/vhdl/spwpkg.vhd
analyze ../spacewire_light/rtl/vhdl/syncdff.vhd
analyze ../spacewire_light/rtl/vhdl/spwram.vhd
analyze ../spacewire_light/rtl/vhdl/spwrecvfront_generic.vhd
analyze ../spacewire_light/rtl/vhdl/spwrecvfront_fast.vhd
analyze ../spacewire_light/rtl/vhdl/spwrecv.vhd
analyze ../spacewire_light/rtl/vhdl/spwxmit.vhd
analyze ../spacewire_light/rtl/vhdl/spwxmit_fast.vhd
analyze ../spacewire_light/rtl/vhdl/spwlink.vhd
analyze ../spacewire_light/rtl/vhdl/spwstream.vhd
```

Compile it from the QuestaSim Transcript:

```tcl
build ./SpaceWireLight.pro
```

OSVVM and SpaceWire Light are now compiled and mapped in the simulator
environment.

## 9. Compile the verification project

Move to the cloned project inside the QuestaSim Transcript:

```tcl
cd ../spacewire-osvvm
```

Compile all project files without running the tests:

```tcl
build ./compile_only.pro
```

The project creates the local libraries:

```text
osvvm_spacewire
spacewire_tb
```

## 10. Run all simulations

From the project directory in the QuestaSim Transcript:

```tcl
build ./RunDemoTests.pro
```

This runs:

```text
TbSpaceWire_SendGet1
TbSpaceWire_Packets1
TbSpaceWire_Traffic1
TbSpaceWireMonitor_Valid1
TbSpaceWireMonitor_Errors1
```

A successful regression ends with all tests reported as `PASSED`.

`TbSpaceWireMonitor_Errors1` deliberately generates four protocol errors and
one warning to test the monitor. These messages are expected, and the test
should still finish as `PASSED`.

## 11. Open the report

The combined OSVVM report is generated in:

```text
spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html
```

Open it from the QuestaSim Transcript:

```tcl
exec xdg-open [file normalize \
  ./spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html] &
```

or from a Linux terminal:

```bash
cd ~/spacewire-osvvm-workspace/spacewire-osvvm

xdg-open \
  spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html
```

## 12. Later use

After the initial setup, the normal workflow is:

```bash
cd ~/spacewire-osvvm-workspace/sim
vsim
```

Then in the QuestaSim Transcript:

```tcl
source ../OsvvmLibraries/Scripts/StartUp.tcl
cd ../spacewire-osvvm
build ./RunDemoTests.pro
```

OSVVM and SpaceWire Light only need to be rebuilt after their source code is
updated or the simulator libraries are removed.
