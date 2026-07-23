# SpaceWire OSVVM Verification

OSVVM verification environment for the SpaceWire Light `spwstream` core.

## Structure

### Reusable verification components

- `src/SpaceWireTbPkg.vhd`
- `src/SpaceWireTx.vhd`
- `src/SpaceWireRx.vhd`

### Testbench

- `testbench/TestCtrl_e.vhd`
- `testbench/TbSpaceWire.vhd`
- `testbench/TbSpaceWire_SendGet1.vhd`

### Waveforms

- `wave.do`

## Current passing test

Node A to Node B:

- `0x55`
- `0x5A`
- EOP

Node B to Node A:

- `0xA6`
- `0xC3`
- EEP

The first directed test passes all 16 OSVVM affirmations.

## External dependencies

The following are installed and compiled separately:

- OSVVM
- OSVVM Common
- SpaceWire Light RTL
- QuestaSim Pro Microchip Edition
