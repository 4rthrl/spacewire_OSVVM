# SpaceWire OSVVM Verification Environment

OSVVM verification environment for the **SpaceWire Light `spwstream` core** and the passive **SpaceWire Data/Strobe monitor** developed in this repository.

The project now contains two complementary verification environments:

1. A **two-node system testbench** with two real `spwstream` cores, application-side TX/RX verification components, passive monitors in both directions, scoreboards, packet tests and time-code tests.
2. A **direct monitor unit-testbench** that drives Data and Strobe itself, allowing valid traffic and deliberately malformed traffic to be tested without relying on the SpaceWire Light transmitter.

The passive monitor is complete for the current project scope. It has been tested with valid packets, EOP, EEP, NULL, FCT, broadcasts/time-codes, parity errors, invalid ESC sequences, synchronization loss and recovery. This does not claim full formal ECSS protocol compliance; additional randomized, timing and flow-control coverage can still be added.

---

## Contents

- [Current verification status](#current-verification-status)
- [Repository structure](#repository-structure)
- [Verification architecture](#verification-architecture)
- [Source files](#source-files)
- [Testbench files](#testbench-files)
- [How the passive monitor works](#how-the-passive-monitor-works)
- [Using the monitor](#using-the-monitor)
- [Available tests](#available-tests)
- [Building and running](#building-and-running)
- [Reports](#reports)
- [Logging](#logging)
- [Waveform notes](#waveform-notes)
- [Adding a new test](#adding-a-new-test)
- [Generated files](#generated-files)
- [Future improvements](#future-improvements)

---

## Current verification status

The current regression verifies:

- link initialization and transition to `Running`;
- application-side TX and RX transactions;
- normal DATA characters;
- EOP and EEP packet endings;
- packet helper procedures;
- bidirectional packet traffic;
- simultaneous full-duplex traffic;
- different packet lengths and payload patterns;
- time-code/broadcast transmission and reception;
- passive Data/Strobe decoding in both directions;
- first-NULL detection and monitor synchronization;
- FCT, NULL, ESC, EOP and EEP decoding;
- broadcast recognition as `ESC + DATA`;
- SpaceWire odd-parity checking;
- packet reconstruction and readable packet summaries;
- expected-versus-actual checking with OSVVM scoreboards;
- direct monitor testing without `spwstream`;
- deliberate packet-data parity failure;
- invalid `ESC + EOP`;
- invalid `ESC + EEP`;
- invalid `ESC + ESC`;
- simultaneous Data/Strobe transition detection;
- loss of synchronization and successful resynchronization;
- valid packet reception after error recovery.

Current regression tests:

```text
TbSpaceWire_SendGet1
TbSpaceWire_Packets1
TbSpaceWire_Traffic1
TbSpaceWireMonitor_Valid1
TbSpaceWireMonitor_Errors1
```

---

## Repository structure

```text
spacewire-osvvm/
├── src/
│   ├── SpaceWireTbPkg.vhd
│   ├── ScoreboardPkg_SpaceWire.vhd
│   ├── SpaceWireTx.vhd
│   ├── SpaceWireRx.vhd
│   ├── SpaceWireMonitor.vhd
│   └── SpaceWireDsDriverPkg.vhd
│
├── testbench/
│   ├── TestCtrl_e.vhd
│   ├── MonitorTestCtrl_e.vhd
│   ├── TbSpaceWire.vhd
│   ├── TbSpaceWireMonitor.vhd
│   ├── TbSpaceWire_SendGet1.vhd
│   ├── TbSpaceWire_Packets1.vhd
│   ├── TbSpaceWire_Traffic1.vhd
│   ├── TbSpaceWireMonitor_Valid1.vhd
│   └── TbSpaceWireMonitor_Errors1.vhd
│
├── build.pro
├── compile_only.pro
├── RunDemoTests.pro
├── wave.do
├── README.md
└── .gitignore
```

Generated simulator libraries, reports, transcripts and temporary directories are not source files and should remain excluded by `.gitignore`.

---

## Dependencies

The current setup uses:

- **QuestaSim Pro Microchip Edition 2024.3**
- **OSVVM**
- **OSVVM Common**
- **SpaceWire Light RTL**

Example OSVVM startup script on the development machine:

```text
/home/arthur-22/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl
```

The compiled SpaceWire Light library must be available as:

```text
spacewire_light
```

Paths are machine-specific and can be changed when the project is used elsewhere.

---

## Verification architecture

### Two-node system testbench

`TbSpaceWire.vhd` contains two real SpaceWire Light `spwstream` cores.

```text
                          A -> B direction

TestCtrl
   |
   v
SpaceWireTx_A
   |
   v
spwstream A ===== Data/Strobe =====> spwstream B ----> SpaceWireRx_B
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
spwstream B ===== Data/Strobe =====> spwstream A ----> SpaceWireRx_A
                    |
                    +----> Monitor_B_to_A
                              |
                              v
                    Monitor_B_to_A_Scoreboard
```

The two directions are independent and can carry traffic simultaneously.

This environment gives two checks of the same traffic:

1. `SpaceWireRx` checks the receiving `spwstream` application interface.
2. `SpaceWireMonitor` independently decodes the physical Data/Strobe stream and checks it with a separate scoreboard.

### Direct monitor unit testbench

`TbSpaceWireMonitor.vhd` contains no SpaceWire Light core.

```text
MonitorTestCtrl architecture
          |
          | direct Data/Strobe procedures
          v
   SpaceWireDsDriverPkg
          |
          v
      DataLine / StrobeLine
          |
          v
     SpaceWireMonitor
          |
          +----> readable logs and alerts
          |
          +----> MonValid / MonFlag / MonData
                         |
                         v
                     scoreboard
```

This environment is used for traffic that a correct `spwstream` transmitter would not normally generate, such as bad parity and invalid ESC sequences.

---

## Source files

### `src/SpaceWireTbPkg.vhd`

Defines the shared SpaceWire transaction types and high-level helper procedures.

Important concepts include:

```text
SpaceWireRecType
SpaceWireStimType
SpaceWirePacketType
SpaceWirePacketEndType
```

Packet helpers include:

```vhdl
SendPacket(...)
CheckPacket(...)
```

A packet is transferred internally as DATA N-Chars followed by EOP or EEP.

### `src/ScoreboardPkg_SpaceWire.vhd`

SpaceWire-specific OSVVM scoreboard instance used for monitor checking and YAML/HTML scoreboard reporting.

Expected values are pushed before transmission. Actual values decoded from Data/Strobe are checked when the monitor asserts `MonValid`.

### `src/SpaceWireTx.vhd`

Application-side OSVVM transmitter verification component for `spwstream`.

It drives:

```text
txdata
txflag
txwrite
```

and observes:

```text
txrdy
```

It converts high-level OSVVM transactions into the `spwstream` transmit handshake.

### `src/SpaceWireRx.vhd`

Application-side OSVVM receiver/checker for `spwstream`.

It observes:

```text
rxdata
rxflag
rxvalid
```

and drives:

```text
rxread
```

Received N-Chars are stored in an internal FIFO and checked by GET/CHECK transactions.

### `src/SpaceWireMonitor.vhd`

Passive simulation-only Data/Strobe decoder.

It:

- waits for the first NULL;
- synchronizes to the serial bit stream;
- decodes DATA and control characters;
- detects FCT, NULL, EOP, EEP and ESC;
- recognizes broadcast codes;
- checks odd parity;
- reconstructs packets;
- logs packet summaries;
- reports malformed sequences;
- emits decoded packet N-Chars to an external scoreboard.

The monitor never drives or modifies the observed link.

### `src/SpaceWireDsDriverPkg.vhd`

Simulation-only direct Data/Strobe driver package used by the monitor unit tests.

It contains reusable procedures such as:

```vhdl
ResetDriver(...)
SendBit(...)
SendFirstNull(...)
SendDataCharacter(...)
SendControlCharacter(...)
SendFct(...)
SendEep(...)
SendEop(...)
SendEsc(...)
SendNull(...)
SendBroadcast(...)
```

The package maintains the parity state required because the parity of the previous SpaceWire character is completed by the beginning of the next character.

The error test contains a small local helper for deliberately sending incorrect parity. That procedure is intentionally kept in the error test rather than in the normal driver API.

---

## Testbench files

### `testbench/TestCtrl_e.vhd`

Common controller entity for the two-node `spwstream` system harness.

It exposes:

- TX and RX OSVVM transaction records for Nodes A and B;
- link state;
- link error signals;
- both monitor outputs;
- time-code input and output signals.

Each system test is an architecture of `TestCtrl`.

### `testbench/MonitorTestCtrl_e.vhd`

Common controller entity for the direct monitor harness.

It exposes:

```text
nReset
DataLine
StrobeLine
MonValid
MonFlag
MonData
Synchronized
PacketActive
```

Each direct monitor test is an architecture of `MonitorTestCtrl`.

### `testbench/TbSpaceWire.vhd`

Fixed two-node harness containing:

- clock and reset generation;
- two SpaceWire Light `spwstream` cores;
- two `SpaceWireTx` instances;
- two `SpaceWireRx` instances;
- two passive `SpaceWireMonitor` instances;
- Data/Strobe cross-connections;
- time-code connections;
- the configurable `TestCtrl` instance.

### `testbench/TbSpaceWireMonitor.vhd`

Fixed direct monitor harness containing:

- reset generation;
- directly driven `DataLine` and `StrobeLine`;
- one `SpaceWireMonitor`;
- the configurable `MonitorTestCtrl` instance.

### Individual test files

Each test file contains:

- one architecture of `TestCtrl` or `MonitorTestCtrl`;
- concurrent driver/checker processes;
- OSVVM reporting and barriers;
- a configuration binding that architecture to the correct harness.

---

## How the passive monitor works

### Data/Strobe decoding

For every valid SpaceWire bit, exactly one physical line changes:

```text
Data changes
or
Strobe changes
```

At the transition, the current Data level is the received serial bit.

If Data and Strobe change in the same simulation event, the monitor reports a warning and loses synchronization.

### First-NULL synchronization

Before normal decoding, the monitor searches for the complete first-NULL bit pattern:

```text
0 111 0 100 0
```

or:

```text
011101000
```

After detecting it:

```text
Synchronized = 1
```

The monitor can then decode normal characters.

### Character decoding

The monitor distinguishes:

```text
DATA
FCT
EOP
EEP
ESC
```

Special sequences:

```text
ESC + FCT   = NULL
ESC + DATA  = broadcast/time-code
```

Invalid sequences reported as errors:

```text
ESC + EOP
ESC + EEP
ESC + ESC
```

### Parity

SpaceWire uses odd parity.

The parity of one character is completed using:

- the payload bits of the previous character;
- the parity bit of the current character;
- the current data/control flag.

The monitor checks parity when the data/control flag of the following character arrives.

Packet summaries count parity checks for packet DATA bytes. Link characters and broadcast DATA are still checked but are not counted as packet payload.

### Packet reconstruction

A packet starts on a normal DATA character and ends on EOP or EEP.

The monitor stores packet bytes up to `MAX_PACKET_BYTES` for readable reporting.

Example:

```text
PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=OK
```

A deliberately corrupted packet can produce:

```text
PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=FAILED ERRORS=1
```

### Monitor output interface

```vhdl
MonValid        : out std_logic;
MonFlag         : out std_logic;
MonData         : out std_logic_vector(7 downto 0);
Synchronized    : out std_logic;
PacketActive    : out std_logic;
```

N-Char representation:

```text
MonFlag = 0                    normal DATA
MonFlag = 1, MonData = 0x00    EOP
MonFlag = 1, MonData = 0x01    EEP
```

`MonValid` pulses when a packet N-Char is emitted.

FCT, NULL, ESC and broadcasts are not emitted to the packet scoreboard.

---

## Using the monitor

### Example instantiation

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
  port map (
    nReset   => nReset,
    DataIn   => SpwDataOutA,
    StrobeIn => SpwStrobeOutA,

    MonValid => MonABValid,
    MonFlag  => MonABFlag,
    MonData  => MonABData,

    Synchronized => MonABSynchronized,
    PacketActive => MonABPacketActive
  );
```

For full duplex, instantiate one monitor for each transmit direction.

### Connecting a scoreboard

Queue expected N-Chars before sending traffic:

```vhdl
Expected.Data := x"55";
Expected.Flag := (others => '0');
Push(MonitorScoreboard, Expected);

Expected.Data := x"00";
Expected.Flag := (others => '1');
Push(MonitorScoreboard, Expected);
```

Check actual monitor output:

```vhdl
wait until MonValid = '1';

Actual.Data := MonData;
Actual.Flag := (others => MonFlag);

Check(
  MonitorScoreboard,
  Actual
);
```

A successful scoreboard requires:

```text
ItemsChecked = ItemCount
ErrorCount   = 0
FifoCount    = 0
```

### Generic reference

| Generic | Purpose |
|---|---|
| `MONITOR_NAME` | AlertLog hierarchy name |
| `MAX_PACKET_BYTES` | Maximum packet bytes retained for a printed summary |
| `LOG_DATA_CHARACTERS` | Log every decoded packet DATA character |
| `LOG_LINK_CHARACTERS` | Log link characters such as NULL, FCT and ESC |
| `CHECK_PARITY` | Enable parity checking |
| `LOG_PARITY_RESULTS` | Log every successful parity check |
| `LOG_PACKET_SUMMARY` | Log one summary per completed packet |

Recommended regression settings:

```vhdl
LOG_DATA_CHARACTERS => false,
LOG_LINK_CHARACTERS => false,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => false,
LOG_PACKET_SUMMARY  => true
```

Detailed decoder debugging:

```vhdl
LOG_DATA_CHARACTERS => true,
LOG_LINK_CHARACTERS => true,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => true,
LOG_PACKET_SUMMARY  => true
```

Detailed mode can create a large transcript because active SpaceWire links continuously exchange NULLs and FCTs.

---

## Available tests

### `TbSpaceWire_SendGet1.vhd`

Small application-side transaction test using the real `spwstream` cores.

Verifies:

- individual DATA transfers;
- EOP and EEP;
- both directions;
- application-side TX/RX verification components;
- link operation after traffic.

This is the simplest regression test and is useful when debugging basic VC or harness problems.

### `TbSpaceWire_Packets1.vhd`

Directed packet test using both real cores and both passive monitors.

Traffic:

```text
A -> B:
  55 + EOP
  00 11 22 33 44 55 66 77 + EEP

B -> A:
  A1 B2 C3 D4 + EOP
  00 01 02 03 04 05 06 07
  08 09 0A 0B 0C 0D 0E 0F + EEP
```

Expected monitor scoreboard totals:

```text
A -> B: 11 N-Chars
B -> A: 22 N-Chars
```

Verifies:

- packet helper procedures;
- EOP and EEP;
- bidirectional monitor decoding;
- packet reconstruction;
- parity;
- two independent scoreboards;
- full-duplex operation.

### `TbSpaceWire_Traffic1.vhd`

Extended directed traffic test.

It sends five packets in each direction with:

- single-byte and multi-byte packets;
- EOP and EEP;
- ascending and descending data;
- alternating patterns;
- boundary and mixed values;
- simultaneous full-duplex traffic.

Expected monitor scoreboard totals:

```text
A -> B: 55 N-Chars
B -> A: 65 N-Chars
```

It also sends and checks four broadcast/time-code values:

```text
A -> B:
  0x01
  0x82

B -> A:
  0x50
  0xD1
```

Broadcasts are checked through the receiving core's time-code interface and are also decoded by the passive monitors. They must not become packet scoreboard items or increase packet payload length.

The test also checks:

```text
RunningA = 1
RunningB = 1
all link error outputs = 0
```

### `TbSpaceWireMonitor_Valid1.vhd`

Direct unit test of `SpaceWireMonitor`, without any `spwstream` core.

Traffic includes:

- first NULL;
- additional NULL;
- FCT;
- broadcast `0x01` outside a packet;
- packet `55 + EOP`;
- NULL between packets;
- packet `00 11 22 + EEP`;
- broadcast `0xA5` inserted inside the packet;
- final NULL.

Expected scoreboard result:

```text
6 N-Chars checked
0 errors
0 remaining
```

Expected main log:

```text
FIRST NULL detected; decoder synchronized
BROADCAST code 0x01
PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=OK
BROADCAST code 0xA5
PACKET 2 DATA=[00 11 22] END=EEP LEN=3 PARITY=OK
```

This test proves that broadcasts do not become packet payload or scoreboard items.

### `TbSpaceWireMonitor_Errors1.vhd`

Direct malformed-traffic and recovery test.

Deliberately generates:

```text
1 parity error for DATA 0x55
1 invalid ESC + EOP
1 invalid ESC + EEP
1 invalid ESC + ESC
1 simultaneous Data/Strobe transition
```

Expected alerts:

```text
Errors   = 4
Warnings = 1
Failures = 0
```

It also verifies:

- the bad-parity packet is still decoded as `55 + EOP`;
- the packet summary reports `PARITY=FAILED`;
- invalid ESC sequences do not emit packet N-Chars;
- the simultaneous transition causes synchronization loss;
- a new first NULL restores synchronization;
- the recovery packet `5A + EOP` is decoded correctly.

Expected packet logs:

```text
PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=FAILED ERRORS=1
PACKET 2 DATA=[5A] END=EOP LEN=1 PARITY=OK
```

The actual monitor alerts remain enabled so their messages are visible in the simulation transcript.

The test:

1. reads and checks the exact monitor alert counts;
2. clears the deliberately generated alerts;
3. generates the final passing OSVVM report.

As a result:

- the transcript contains the real error and warning messages;
- the test result is `PASSED`;
- the final HTML alert table shows zero remaining active alerts.

The detailed transcript is therefore the primary evidence for the intentionally generated alerts.

---

## Building and running

Enter the repository:

```bash
cd ~/spacewire-osvvm
```

### Start OSVVM in QuestaSim

In the Questa transcript:

```tcl
source ~/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl
```

### Compile-only check

`compile_only.pro` compiles the reusable components, both harnesses and all current test architectures without running simulations.

In Questa:

```tcl
build ./compile_only.pro
```

From the Linux terminal:

```bash
vsim -c -do \
"source ~/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl; \
build ./compile_only.pro; quit -f" \
2>&1 | tee compile_only.log
```

Search for compile failures:

```bash
grep -nEi \
'\*\* Error:|vcom-[0-9]+|analyze.*fail|BuildError' \
compile_only.log
```

No matching output means no detected compiler error.

### Build reusable files and harnesses

`build.pro` compiles the packages, verification components and fixed harnesses.

```tcl
build ./build.pro
```

Individual test architectures are normally compiled by `RunTest`.

### Run the complete regression

```tcl
build ./RunDemoTests.pro
```

Expected tests:

```text
TbSpaceWire_SendGet1          PASSED
TbSpaceWire_Packets1          PASSED
TbSpaceWire_Traffic1          PASSED
TbSpaceWireMonitor_Valid1     PASSED
TbSpaceWireMonitor_Errors1    PASSED
```

From the Linux terminal:

```bash
vsim -c -do \
"source ~/spacewire/OSVVM/OsvvmLibraries/Scripts/StartUp.tcl; \
build ./RunDemoTests.pro; quit -f" \
2>&1 | tee RunDemoTests.log
```

Show final test results:

```bash
grep "DONE" RunDemoTests.log
```

### Run one test with `RunTest`

First build the common files:

```tcl
build ./build.pro
```

Then run one test:

```tcl
RunTest ./testbench/TbSpaceWireMonitor_Valid1.vhd
```

```tcl
RunTest ./testbench/TbSpaceWireMonitor_Errors1.vhd
```

Other examples:

```tcl
RunTest ./testbench/TbSpaceWire_SendGet1.vhd
RunTest ./testbench/TbSpaceWire_Packets1.vhd
RunTest ./testbench/TbSpaceWire_Traffic1.vhd
```

### Run an already compiled configuration interactively

```tcl
vsim -voptargs=+acc spacewire_tb.TbSpaceWireMonitor_Valid1
run -all
```

```tcl
vsim -voptargs=+acc spacewire_tb.TbSpaceWireMonitor_Errors1
run -all
```

For the system harness:

```tcl
vsim -voptargs=+acc spacewire_tb.TbSpaceWire_Packets1
do wave.do
run -all
```

Restart the loaded simulation:

```tcl
restart -f
run -all
```

The message:

```text
Break in Process ControlProc
```

at the end of a passing test is normal. It is caused by the intentional:

```vhdl
std.env.stop;
```

---

## Build scripts

### `build.pro`

Compiles reusable source files and fixed harnesses in dependency order.

Important ordering:

```text
SpaceWireTbPkg
ScoreboardPkg_SpaceWire
SpaceWireTx / SpaceWireRx / SpaceWireMonitor
SpaceWireDsDriverPkg
TestCtrl / MonitorTestCtrl
TbSpaceWire / TbSpaceWireMonitor
```

### `compile_only.pro`

Compiles all reusable files, harnesses and individual tests. It is useful for quickly finding VHDL analysis errors without running a regression.

### `RunDemoTests.pro`

Builds the shared environment, runs all registered tests and generates the combined OSVVM report.

A test only appears in the combined regression report when it has a corresponding `RunTest` entry in this file and `RunDemoTests.pro` is rerun.

---

## Reports

Main combined report:

```text
spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html
```

Open from Questa:

```tcl
exec xdg-open [file normalize \
  ./spacewire-osvvm_RunDemoTests/spacewire-osvvm_RunDemoTests.html] &
```

Find recently generated reports:

```bash
find . -name "*.html" -printf "%TY-%Tm-%Td %TH:%TM  %p\n" \
  | sort -r \
  | head -n 20
```

The reports include:

- overall test status;
- affirmation counts;
- AlertLog hierarchy;
- scoreboard statistics;
- build summary;
- links to simulation results and transcripts.

### Scoreboard columns

```text
ItemCount       expected items pushed
ItemsChecked    actual items compared
ErrorCount      mismatches
ItemsPopped     expected items removed after checking
FifoCount       expected items still waiting
```

A complete pass requires:

```text
ItemsChecked = ItemCount
ErrorCount   = 0
FifoCount    = 0
```

### Error-test reporting note

`TbSpaceWireMonitor_Errors1` deliberately creates real enabled alerts.

The test saves and verifies the expected counts, then clears those expected alerts before the final report.

Therefore:

```text
simulation transcript:
  contains the four real ERROR messages and one real WARNING

final HTML alert table:
  shows zero remaining active alerts

test status:
  PASSED
```

This is intentional. Use the transcript link in the report to inspect the injected monitor errors.

---

## Logging

### Monitor logging

Logging is controlled by monitor generics.

Normal regression mode:

```vhdl
LOG_DATA_CHARACTERS => false,
LOG_LINK_CHARACTERS => false,
CHECK_PARITY        => true,
LOG_PARITY_RESULTS  => false,
LOG_PACKET_SUMMARY  => true
```

Typical output:

```text
FIRST NULL detected; decoder synchronized
PACKET 1 DATA=[55] END=EOP LEN=1 PARITY=OK
```

Broadcasts are logged at INFO:

```text
BROADCAST code 0xA5 TYPE=2 VALUE=37
```

Parity failures and invalid protocol sequences are OSVVM alerts and remain visible even when successful parity logs are disabled.

### TX/RX logging

Application-side TX/RX components have separate AlertLog IDs.

Enable detailed debug output:

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

Keep normal regression output clean:

```vhdl
SetLogEnable(
  SpwTxAID,
  INFO,
  false
);

SetLogEnable(
  SpwRxBID,
  INFO,
  false
);
```

Avoid enabling RX `INFO` during normal regression unless successful per-character CHECK messages are wanted.

Hide successful affirmations while still counting them:

```vhdl
SetLogEnable(
  PASSED,
  false
);
```

Failures, errors and warnings remain active.

---

## EOP and EEP

```text
EOP = normal end of packet
EEP = error end of packet
```

The testbench deliberately uses both.

An EEP does not mean the simulation failed when the test expected that packet to end with EEP.

---

## Waveform notes

`RxData` and `RxFlag` may appear as `X` or `U` while:

```text
RxValid = 0
```

Those values are not meaningful outside a valid receive transaction.

Only interpret receive data when:

```text
RxValid = 1
```

TX data and flag are meaningful as a new transaction only while the TX handshake is active.

Useful system signals:

```text
Clk
nReset

RunningA
RunningB

TxReadyA/B
TxWriteA/B
TxFlagA/B
TxDataA/B

RxValidA/B
RxReadA/B
RxFlagA/B
RxDataA/B

SpwDataOutA/B
SpwStrobeOutA/B

MonABValid
MonABFlag
MonABData
MonABSynchronized
MonABPacketActive

MonBAValid
MonBAFlag
MonBAData
MonBASynchronized
MonBAPacketActive

ErrorDisconnectA/B
ErrorParityA/B
ErrorEscapeA/B
ErrorCreditA/B
```

Useful direct monitor signals:

```text
nReset
DataLine
StrobeLine
MonValid
MonFlag
MonData
Synchronized
PacketActive
```

---

## Adding a new test

### System test

1. Create a new architecture of `TestCtrl`.
2. Add a configuration binding it to `TbSpaceWire(TestHarness)`.
3. Push expected monitor items before transmitting.
4. Check application-side RX traffic.
5. Check both monitor scoreboards.
6. Use the shared `TestDone` barrier.
7. Add the test file to `RunDemoTests.pro`.
8. Add it to `compile_only.pro`.
9. Run the complete regression.

Example:

```tcl
RunTest ./testbench/TbSpaceWire_NewTest.vhd
```

### Direct monitor test

1. Create a new architecture of `MonitorTestCtrl`.
2. Drive `DataLine` and `StrobeLine` through `SpaceWireDsDriverPkg`.
3. Add expected N-Chars to a scoreboard.
4. Check `Synchronized` and `PacketActive` where relevant.
5. Add a configuration binding it to `TbSpaceWireMonitor(TestHarness)`.
6. Add it to `RunDemoTests.pro` and `compile_only.pro`.
7. Run the complete regression.

---

## Generated files

QuestaSim and OSVVM generate libraries, reports and temporary files. Do not commit them.

Examples:

```text
osvvm_spacewire/
spacewire_tb/
work/
OsvvmTemp_QuestaSim/

spacewire-osvvm_build/
spacewire-osvvm_compile_only/
spacewire-osvvm_RunDemoTests/

TbSpaceWireMonitor_Valid1/
TbSpaceWireMonitor_Errors1/

OsvvmSimRun.tcl
index.html
index.yml
transcript
*.wlf
etch*
```

The source-controlled files are:

```text
src/
testbench/
build.pro
compile_only.pro
RunDemoTests.pro
wave.do
README.md
.gitignore
```

---


## Future improvements

The current passive monitor is complete for the directed tests implemented in this project. Useful future additions include:

### Randomized traffic

- randomized packet lengths;
- randomized payload values;
- randomized EOP/EEP selection;
- randomized delays;
- simultaneous randomized full-duplex traffic;
- randomized time-code values.

### Functional coverage

Coverage bins for:

- packet length ranges;
- EOP versus EEP;
- link direction;
- broadcast types and values;
- packet/broadcast interleaving;
- FCT and NULL interleaving;
- parity pass/fail;
- each invalid ESC sequence;
- synchronization loss and recovery.

### Link and flow-control tests

- link disable and restart;
- repeated initialization;
- disconnect timeout and recovery;
- delayed `RxRead`;
- receive FIFO backpressure;
- large packet bursts;
- credit exhaustion and credit errors;
- traffic while both directions are under pressure.

### More direct malformed-traffic cases

- bad parity on each control-character type;
- incomplete character sequences;
- empty packets;
- repeated illegal physical transitions;
- invalid line values;
- resynchronization at different bit offsets;
- long malformed sequences before recovery.

### Timing-oriented testing

- Data/Strobe skew;
- different bit periods;
- jittered bit periods;
- transition-spacing limits;
- timing tolerance around synchronization.

The current monitor detects logical simultaneous transitions, but it is not yet a complete timing-compliance checker.

### Reporting and reuse

- aggregate monitor statistics;
- packet, byte, NULL, FCT and broadcast counters;
- functional-coverage reports;
- reusable monitor verification component packaging;
- reusable direct driver with optional error injection;
- integration with the APB wrapper;
- complete BeagleV-Fire CPU-to-SpaceWire system verification.