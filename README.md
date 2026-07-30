# SpaceWire OSVVM Verification Extension

This repository contains an **OSVVM-based verification extension** for
SpaceWire designs written in VHDL.

It was initially developed around the **SpaceWire Light `spwstream` core**, but
the passive Data/Strobe monitor is not tied to that implementation. It can also
be connected to other SpaceWire cores or custom SpaceWire integrations that
expose logical Data and Strobe signals.

## Main components

- `SpaceWireTx.vhd`  
  Drives the FIFO-style transmit interface of the SpaceWire Light `spwstream`
  core through OSVVM transactions.

- `SpaceWireRx.vhd`  
  Receives and checks characters from the `spwstream` receive interface.

- `SpaceWireMonitor.vhd`  
  Passively observes SpaceWire Data/Strobe traffic. It detects the first NULL,
  decodes DATA and control characters, checks parity, reconstructs packets,
  recognizes broadcasts and reports malformed sequences. Because it only
  observes Data and Strobe, it can be reused independently of SpaceWire Light.

- `SpaceWireDsDriverPkg.vhd`  
  Simulation-only direct Data/Strobe driver used to validate the monitor with
  valid and deliberately malformed traffic.

- `SpaceWireTbPkg.vhd`  
  Shared SpaceWire transaction types and helper procedures.

- `ScoreboardPkg_SpaceWire.vhd`  
  OSVVM scoreboard instance for comparing expected and observed SpaceWire
  characters.

- `testbench/`  
  Directed tests for packet traffic, full-duplex operation, time-codes,
  monitor decoding, parity errors, invalid ESC sequences and recovery.

## Verification scope

The current environment verifies:

- link startup and normal operation;
- DATA, EOP and EEP transfer;
- bidirectional and full-duplex packet traffic;
- different packet lengths and payload patterns;
- broadcasts and time-codes;
- passive Data/Strobe decoding;
- odd-parity checking;
- packet reconstruction;
- invalid ESC sequences;
- synchronization loss and recovery.

The passive monitor is considered complete for the current project scope. It is
a simulation and verification component, not synthesizable FPGA logic.

## Repository structure

```text
src/         reusable SpaceWire verification components
testbench/   harnesses and directed test architectures
```

Build instructions, test descriptions and detailed technical documentation are
kept in separate documentation files.

## Credits

The original **SpaceWire Light** core was developed by **Joris van Rantwijk**
and is available through the OpenCores SpaceWire Light project.

This repository adds an independent OSVVM verification environment and passive
SpaceWire Data/Strobe monitor around that core. The original SpaceWire Light RTL
remains the work of its original author and is subject to its own license.