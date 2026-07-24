# SpaceWire OSVVM Testbench

OSVVM verification environment for the **SpaceWire Light `spwstream` core**.

The testbench contains two real SpaceWire Light nodes connected through their
Data/Strobe signals. Application-side OSVVM verification components generate
and check traffic, while passive monitors independently decode the actual
SpaceWire link in both directions.

## Current verification status

The current environment verifies:

- SpaceWire link initialization and transition to `Running`;
- normal data characters;
- EOP and EEP packet endings;
- bidirectional packet transfer;
- simultaneous full-duplex traffic;
- passive Data/Strobe decoding in both directions;
- first-NULL detection;
- SpaceWire character parity;
- packet reconstruction and readable packet logging;
- expected-versus-actual checking with two OSVVM scoreboards.

The packet test currently monitors:

```text
A -> B:
  55 + EOP
  00 11 22 33 44 55 66 77 + EEP

B -> A:
  A1 B2 C3 D4 + EOP
  00 01 02 03 04 05 06 07
  08 09 0A 0B 0C 0D 0E 0F + EEP
```

Expected scoreboard totals:

```text
Monitor_A_to_B_Scoreboard: 11 checked, 0 errors, 0 remaining
Monitor_B_to_A_Scoreboard: 22 checked, 0 errors, 0 remaining
```

## Architecture

```text
                      A -> B direction

TestCtrl
   |
   v
SpaceWireTx_A
   |
   v
spwstream A ---- Data/Strobe ----> spwstream B ----> SpaceWireRx_B
                    |
                    +----> Monitor_A_to_B
                              |
                              v
                    Monitor_A_to_B_Scoreboard


                      B -> A direction

TestCtrl
   |
   v
SpaceWireTx_B
   |
   v
spwstream B ---- Data/Strobe ----> spwstream A ----> SpaceWireRx_A
                    |
                    +----> Monitor_B_to_A
                              |
                              v
                    Monitor_B_to_A_Scoreboard
```

The monitors are passive. They never drive or modify the SpaceWire link.

## Repository structure

```text
spacewire-osvvm/
├── src/
│   ├── SpaceWireTbPkg.vhd
│   ├── ScoreboardPkg_SpaceWire.vhd
│   ├── SpaceWireTx.vhd
│   ├── SpaceWireRx.vhd
│   └── SpaceWireMonitor.vhd
│
├── testbench/
│   ├── TestCtrl_e.vhd
│   ├── TbSpaceWire.vhd
│   ├── TbSpaceWire_SendGet1.vhd
│   └── TbSpaceWire_Packets1.vhd
│
├── build.pro
├── RunDemoTests.pro
├── wave.do
├── README.md
└── .gitignore
```

## Dependencies

The current setup uses:

- QuestaSim Pro Microchip Edition 2024.3;
- OSVVM;
- OSVVM Common;
- SpaceWire Light RTL.

The paths below are specific to the current development machine and can be
changed when the repository is used elsewhere.

Example OSVVM startup script:

```text
/home/arthur-22/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl
```

The compiled SpaceWire Light library must be mapped as `spacewire_light`.

## Running the complete regression

Start QuestaSim, then run:

```tcl
cd /home/arthur-22/spacewire-osvvm

source /home/arthur-22/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl

build ./RunDemoTests.pro
```

The run script builds the reusable verification components and runs the
registered test cases.

A successful run ends with results similar to:

```text
DONE PASSED TbSpaceWire_SendGet1
DONE PASSED TbSpaceWire_Packets1
```

## Running one test interactively

Build the project first, then load the packet test:

```tcl
vsim -voptargs=+acc spacewire_tb.TbSpaceWire_Packets1
do wave.do
run -all
```

To restart the same simulation:

```tcl
restart -f
run -all
```

To load the simpler character-level test:

```tcl
vsim -voptargs=+acc spacewire_tb.TbSpaceWire_SendGet1
do wave.do
run -all
```

## Available tests

### `TbSpaceWire_SendGet1`

Basic application-side transaction test.

It verifies individual DATA, EOP and EEP transfers through both real
`spwstream` cores.

### `TbSpaceWire_Packets1`

Directed packet and passive-monitor test.

It verifies:

- packet helper procedures;
- EOP and EEP packet termination;
- both link directions;
- both passive monitors;
- parity checking;
- packet reconstruction;
- two monitor scoreboards;
- continued `Running` state after all traffic.

## Opening the reports

Main OSVVM report:

```tcl
exec xdg-open [file normalize \
  ./spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html] &
```

Detailed packet-test report:

```tcl
exec xdg-open [file normalize \
  ./spacewire-osvvm_RunDemoTests/reports/SpaceWire/TbSpaceWire_Packets1.html] &
```

The generated report contains:

- overall test status;
- AlertLog results;
- pass/fail counts;
- scoreboard statistics;
- links to the detailed simulation transcript.

The scoreboard table is a summary. It does not store every checked byte in the
HTML table. Individual decoded and checked items are available in the
simulation transcript.

For a passing monitor scoreboard:

```text
ItemCount    = number of expected items pushed
ItemsChecked = number of actual items compared
ErrorCount   = number of mismatches
ItemsPopped  = expected items removed after checking
FifoCount    = expected items still remaining
```

A complete pass requires:

```text
ItemsChecked = ItemCount
ErrorCount   = 0
FifoCount    = 0
```

## Monitor logging

Logging for each passive monitor is controlled by generics in
`testbench/TbSpaceWire.vhd`.

Example:

```vhdl
MonitorAB : entity osvvm_spacewire.SpaceWireMonitor
  generic map (
    MONITOR_NAME          => "Monitor_A_to_B",
    MAX_PACKET_BYTES      => 256,

    LOG_DATA_CHARACTERS   => false,
    LOG_LINK_CHARACTERS   => false,

    CHECK_PARITY          => true,
    LOG_PARITY_RESULTS    => false,
    LOG_PACKET_SUMMARY    => true
  )
```

The same options are available for `Monitor_B_to_A`.

### Monitor generic reference

| Generic | Meaning |
|---|---|
| `MONITOR_NAME` | Name used in the OSVVM transcript and report |
| `MAX_PACKET_BYTES` | Maximum number of bytes stored for one printed packet summary |
| `LOG_DATA_CHARACTERS` | Print every decoded packet data character |
| `LOG_LINK_CHARACTERS` | Print NULL, FCT and ESC link characters |
| `CHECK_PARITY` | Enable SpaceWire parity checking |
| `LOG_PARITY_RESULTS` | Print every successful parity check |
| `LOG_PACKET_SUMMARY` | Print one complete summary for each packet |

### Recommended normal mode

This is the preferred setting for regression runs:

```vhdl
LOG_DATA_CHARACTERS => false,
LOG_LINK_CHARACTERS => false,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => false,
LOG_PACKET_SUMMARY  => true
```

Typical output:

```text
Monitor_A_to_B: FIRST NULL detected; decoder synchronized
Monitor_A_to_B: PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=OK
Monitor_A_to_B: PACKET 2 DATA=[00 11 22 33 44 55 66 77]
                END=EEP LEN=8 PARITY=OK
```

Parity is still checked when `LOG_PARITY_RESULTS` is false. Only successful
per-character messages are hidden. A parity failure still produces an OSVVM
error.

### Detailed monitor-debug mode

Use this temporarily when debugging the decoder:

```vhdl
LOG_DATA_CHARACTERS => true,
LOG_LINK_CHARACTERS => true,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => true,
LOG_PACKET_SUMMARY  => true
```

This can produce a long transcript because an idle SpaceWire link continuously
transmits NULLs and may transmit FCTs.

### Link-character logging only

To inspect NULL, FCT and ESC activity without printing every packet byte:

```vhdl
LOG_DATA_CHARACTERS => false,
LOG_LINK_CHARACTERS => true,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => false,
LOG_PACKET_SUMMARY  => true
```

## TX and RX logging

The application-side TX and RX verification components have their own OSVVM
AlertLog IDs.

Per-character TX and raw RX messages are logged at `DEBUG` in the verification
components.

To enable them in a test:

```vhdl
SetLogEnable(
  SpwTxAID,
  DEBUG,
  true
);

SetLogEnable(
  SpwRxBID,
  DEBUG,
  true
);
```

To keep the transcript clean:

```vhdl
SetLogEnable(
  SpwTxAID,
  DEBUG,
  false
);

SetLogEnable(
  SpwRxBID,
  DEBUG,
  false
);
```

Do not enable `INFO` on an RX model during a normal regression unless the
successful `CHECK` messages are wanted. In the current RX VC, enabling `INFO`
can cause each successful received character to be printed.

Successful checks can be hidden globally while still being counted:

```vhdl
SetLogEnable(
  PASSED,
  false
);
```

Failures, errors and warnings remain visible and still affect the final result.

## Scoreboard logging

The monitor scoreboards compare expected N-Chars against N-Chars decoded from
the actual Data/Strobe signals.

Expected items are pushed by the test process before transmission. Actual items
are sent to the scoreboard when the monitor asserts `MonValid`.

Representation:

```text
Flag = 0                    normal DATA
Flag = 1, Data = 0x00       EOP
Flag = 1, Data = 0x01       EEP
```

The HTML scoreboard section provides compact statistics. Item-by-item
comparisons can be shown in the transcript by enabling `PASSED`, but this is
usually disabled for a readable regression log.

## EOP and EEP

- `EOP` is a normal end-of-packet marker.
- `EEP` is an error end-of-packet marker.

The packet test deliberately includes both endings. A packet ending in EEP does
not mean the test failed when EEP was the expected result.

## Parity-count note

SpaceWire parity for a character is completed using the parity and
data/control bits of the following character.

The current monitor can observe link characters such as FCT between packet data
characters. In older packet-summary formatting, the displayed parity-check
count can therefore be greater than the packet data length.

For example:

```text
8 packet data characters + 1 interleaved FCT = 9 parity checks
```

This does not indicate a parity error. The packet summary should primarily be
read from its `PARITY=OK` or `PARITY=FAILED` result. A future refinement can
separate packet-data parity statistics from link-character parity statistics.

## Waveform notes

`RxData` and `RxFlag` may appear as `X` or `U` when `RxValid = 0`. Those values
are not meaningful while the receive interface is invalid.

Only interpret RX data when:

```text
RxValid = 1
```

Similarly, TX data and flag values are meaningful as a new transfer only when
the TX handshake is active.

## Adding a new test

1. Create a new architecture of `TestCtrl` in `testbench/`.
2. Add a configuration that binds it to `TbSpaceWire(TestHarness)`.
3. Add the file to `RunDemoTests.pro`.
4. Use the shared barrier so all concurrent test processes finish cleanly.
5. Push expected monitor items before transmitting actual traffic.
6. Check that each scoreboard is empty and has the expected check count.
7. Run the complete regression to ensure older tests still pass.

Example test registration:

```tcl
RunTest ./testbench/TbSpaceWire_NewTest.vhd
```

## Generated files

QuestaSim and OSVVM generate libraries, transcripts and HTML reports. These
should not be committed.

Typical generated paths:

```text
spacewire-osvvm_RunDemoTests/
OsvvmSimRun.tcl
index.html
index.yml
transcript
vsim.wlf
osvvm_spacewire/
spacewire_tb/
work/
```

Keep them in `.gitignore`.

## Git workflow

Check changes:

```bash
git status
git diff --stat
```

Stage source and documentation files explicitly:

```bash
git add \
  README.md \
  .gitignore \
  build.pro \
  src/ \
  testbench/
```

Review before committing:

```bash
git status
git diff --cached --stat
```

Commit and push:

```bash
git commit -m "Add bidirectional SpaceWire monitors and scoreboards"
git push origin main
```

## Current limitations and next steps

The current environment does not yet directly generate malformed Data/Strobe
traffic.

The next planned test is a dedicated low-level monitor test that directly
drives Data/Strobe and verifies:

- first NULL;
- FCT;
- DATA;
- EOP;
- EEP;
- broadcast/time code;
- deliberately incorrect parity;
- invalid ESC sequences;
- monitor error reporting.

Later work can add:

- constrained-random packet contents and lengths;
- functional coverage;
- backpressure and FIFO-pressure tests;
- link disable and restart;
- disconnect recovery;
- time-code checking;
- credit-error tests;
- Data/Strobe skew and timing tests.
