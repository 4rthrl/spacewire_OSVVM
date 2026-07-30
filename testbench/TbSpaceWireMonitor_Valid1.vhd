library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;
  use osvvm_spacewire.ScoreboardPkg_SpaceWire.all;
  use osvvm_spacewire.SpaceWireDsDriverPkg.all;


--------------------------------------------------------------------
-- Direct valid-traffic test for SpaceWireMonitor.
--
-- This test drives the physical Data/Strobe signals directly,
-- without using the SpaceWire Light spwstream core.
--
-- Valid traffic:
--
--   - first NULL synchronization sequence
--   - additional NULL
--   - FCT
--   - broadcast outside a packet
--   - packet 1: 55 + EOP
--   - additional NULL
--   - packet 2: 00 11 22 + EEP
--   - broadcast inserted inside packet 2
--
-- The passive monitor must:
--
--   - synchronize to the first NULL;
--   - decode the packet DATA characters;
--   - decode EOP and EEP;
--   - recognize broadcasts without adding them to the packet;
--   - keep packet payload parity statistics correct;
--   - produce the expected N-Chars for the scoreboard.
--------------------------------------------------------------------
architecture Valid1 of MonitorTestCtrl is

  ------------------------------------------------------------------
  -- Direct Data/Strobe timing.
  ------------------------------------------------------------------
  constant BIT_PERIOD : time := 100 ns;


  ------------------------------------------------------------------
  -- Directed packets.
  ------------------------------------------------------------------
  constant Packet1 : SpaceWirePacketType := (
    0 => x"55"
  );

  constant Packet2 : SpaceWirePacketType := (
    x"00", x"11", x"22"
  );


  ------------------------------------------------------------------
  -- Broadcast/time-code values.
  ------------------------------------------------------------------
  constant BroadcastOutsidePacket : std_logic_vector(7 downto 0) :=
    x"01";

  constant BroadcastInsidePacket : std_logic_vector(7 downto 0) :=
    x"A5";


  ------------------------------------------------------------------
  -- Each packet produces one transaction per data byte and one
  -- additional transaction for its EOP or EEP terminator.
  --
  -- Broadcast characters are not N-Chars and are not included.
  ------------------------------------------------------------------
  constant MONITOR_TRANSACTION_COUNT : integer :=
    Packet1'length + 1 +
    Packet2'length + 1;


  ------------------------------------------------------------------
  -- Expected monitor output.
  ------------------------------------------------------------------
  signal MonitorScoreboard : ScoreboardIDType;


  ------------------------------------------------------------------
  -- Indicates that the direct driver has finished sending traffic.
  ------------------------------------------------------------------
  signal DriverFinished : boolean := false;


  ------------------------------------------------------------------
  -- Barrier shared by the control, driver, and monitor checker.
  ------------------------------------------------------------------
  signal TestDone : integer_barrier := 1;


  ------------------------------------------------------------------
  -- Queue one expected packet in the passive monitor scoreboard.
  ------------------------------------------------------------------
  procedure PushExpectedPacket(
    constant Scoreboard : in ScoreboardIDType;
    constant Packet     : in SpaceWirePacketType;
    constant Ending     : in SpaceWirePacketEndType
  ) is
    variable Expected : SpaceWireStimType;
  begin

    --------------------------------------------------------------
    -- Queue every expected packet data character.
    --------------------------------------------------------------
    for Index in Packet'range loop
      Expected.Data := Packet(Index);
      Expected.Flag := (others => '0');

      Push(
        Scoreboard,
        Expected
      );
    end loop;


    --------------------------------------------------------------
    -- Queue the expected packet terminator.
    --------------------------------------------------------------
    Expected.Flag := (others => '1');

    case Ending is
      when PACKET_EOP =>
        Expected.Data := x"00";

      when PACKET_EEP =>
        Expected.Data := x"01";
    end case;

    Push(
      Scoreboard,
      Expected
    );

  end procedure PushExpectedPacket;

begin

  ------------------------------------------------------------------
  -- ControlProc
  --
  -- Initializes OSVVM reporting, waits for the driver and checker,
  -- verifies the scoreboard, writes the reports, and stops.
  ------------------------------------------------------------------
  ControlProc : process
  begin

    SetTestName("TbSpaceWireMonitor_Valid1");
    SetLogEnable(PASSED, FALSE);

    MonitorScoreboard <= NewID(
      "Direct_Monitor_Scoreboard"
    );

    wait for 0 ns;

    SetAlertLogOptions(
      WriteTimeLast => FALSE
    );

    SetAlertLogOptions(
      TimeJustifyAmount => 16
    );

    SetAlertLogJustify;

    wait for 0 ns;
    wait for 0 ns;

    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    wait until nReset = '1';

    ClearAlerts;

    WaitForBarrier(
      TestDone,
      1 ms
    );


    --------------------------------------------------------------
    -- Verify that every expected N-Char was received.
    --------------------------------------------------------------
    AffirmIf(
      IsEmpty(MonitorScoreboard),
      "Direct monitor scoreboard is empty"
    );

    AffirmIfEqual(
      GetCheckCount(MonitorScoreboard),
      MONITOR_TRANSACTION_COUNT,
      "Direct monitor scoreboard check count"
    );


    --------------------------------------------------------------
    -- Verify the final monitor state.
    --------------------------------------------------------------
    AffirmIf(
      Synchronized = '1',
      "Monitor remains synchronized"
    );

    AffirmIf(
      PacketActive = '0',
      "No packet remains active"
    );


    TranscriptClose;

    osvvm_spacewire.ScoreboardPkg_SpaceWire.WriteScoreboardYaml(
      FileName => "SpaceWireMonitor"
    );

    EndOfTestReports(
      TimeOut => (now >= 1 ms)
    );

    std.env.stop;
    wait;

  end process ControlProc;


  ------------------------------------------------------------------
  -- DirectDriverProc
  --
  -- Generates valid SpaceWire Data/Strobe traffic.
  ------------------------------------------------------------------
  DirectDriverProc : process

    variable DriverState : SpaceWireDsDriverStateType :=
      SPACEWIRE_DS_DRIVER_STATE_INIT;

  begin

    --------------------------------------------------------------
    -- Initialize the directly driven physical signals.
    --------------------------------------------------------------
    DataLine   <= '0';
    StrobeLine <= '0';

    wait for 0 ns;

    ResetDriver(
        DriverState
    );

    wait until nReset = '1';

    wait for 2 * BIT_PERIOD;


    --------------------------------------------------------------
    -- First NULL synchronization sequence.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending first NULL synchronization sequence",
      INFO
    );

    SendFirstNull(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );

    AffirmIf(
      Synchronized = '1',
      "Monitor synchronized after first NULL"
    );


    --------------------------------------------------------------
    -- Send another complete NULL.
    --
    -- The first ESC uses the parity bit already included at the
    -- end of SendFirstNull.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending additional NULL",
      INFO
    );

    SendNull(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Send one standalone FCT.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending FCT",
      INFO
    );

    SendFct(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Send one broadcast outside a packet.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending broadcast 0x01 outside a packet",
      INFO
    );

    SendBroadcast(
      DataLine,
      StrobeLine,
      DriverState,
      BroadcastOutsidePacket,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Packet 1: 55 + EOP.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending Packet1: 55 + EOP",
      INFO
    );

    PushExpectedPacket(
      MonitorScoreboard,
      Packet1,
      PACKET_EOP
    );

    SendDataCharacter(
      DataLine,
      StrobeLine,
      DriverState,
      Packet1(0),
      BIT_PERIOD
    );

    AffirmIf(
      PacketActive = '1',
      "PacketActive asserted during Packet1"
    );

    SendEop(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );

    AffirmIf(
      PacketActive = '0',
      "PacketActive cleared after Packet1 EOP"
    );


    --------------------------------------------------------------
    -- Insert one NULL between the packets.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending NULL between packets",
      INFO
    );

    SendNull(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Packet 2: 00 11 22 + EEP.
    --
    -- A broadcast is inserted between 00 and 11. It must not be
    -- added to the packet scoreboard or packet payload length.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending Packet2: 00 11 22 + EEP",
      INFO
    );

    PushExpectedPacket(
      MonitorScoreboard,
      Packet2,
      PACKET_EEP
    );

    SendDataCharacter(
      DataLine,
      StrobeLine,
      DriverState,
      Packet2(0),
      BIT_PERIOD
    );

    AffirmIf(
      PacketActive = '1',
      "PacketActive asserted during Packet2"
    );


    --------------------------------------------------------------
    -- Broadcast/time-code interleaved with packet traffic.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending broadcast 0xA5 inside Packet2",
      INFO
    );

    SendBroadcast(
      DataLine,
      StrobeLine,
      DriverState,
      BroadcastInsidePacket,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Continue Packet2 after the broadcast.
    --------------------------------------------------------------
    SendDataCharacter(
      DataLine,
      StrobeLine,
      DriverState,
      Packet2(1),
      BIT_PERIOD
    );

    SendDataCharacter(
      DataLine,
      StrobeLine,
      DriverState,
      Packet2(2),
      BIT_PERIOD
    );

    SendEep(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );

    AffirmIf(
      PacketActive = '0',
      "PacketActive cleared after Packet2 EEP"
    );


    --------------------------------------------------------------
    -- Send a final NULL.
    --
    -- The first character of this NULL completes the parity check
    -- for the preceding EEP.
    --------------------------------------------------------------
    Log(
      "DRIVER: Sending final NULL",
      INFO
    );

    SendNull(
      DataLine,
      StrobeLine,
      DriverState,
      BIT_PERIOD
    );


    --------------------------------------------------------------
    -- Allow the monitor checker to process the final events.
    --------------------------------------------------------------
    wait for 10 * BIT_PERIOD;

    DriverFinished <= true;

    WaitForBarrier(TestDone);
    wait;

  end process DirectDriverProc;


  ------------------------------------------------------------------
  -- MonitorScoreboardProc
  --
  -- Checks every N-Char emitted by SpaceWireMonitor.
  --
  -- The process remains active until the direct driver has finished.
  -- This also detects unexpected extra N-Chars, such as a broadcast
  -- incorrectly being emitted as normal packet data.
  ------------------------------------------------------------------
  MonitorScoreboardProc : process

    variable Actual      : SpaceWireStimType;
    variable ActualCount : natural := 0;

  begin

    wait until nReset = '1';

    loop
      wait on MonValid, DriverFinished;

      if MonValid'event and MonValid = '1' then
        Actual.Data := MonData;
        Actual.Flag := (others => MonFlag);

        Check(
          MonitorScoreboard,
          Actual
        );

        ActualCount := ActualCount + 1;
      end if;

      exit when DriverFinished and MonValid /= '1';
    end loop;


    --------------------------------------------------------------
    -- Verify the total number of monitor events.
    --------------------------------------------------------------
    AffirmIfEqual(
      ActualCount,
      MONITOR_TRANSACTION_COUNT,
      "Direct monitor actual N-Char count"
    );

    WaitForBarrier(TestDone);
    wait;

  end process MonitorScoreboardProc;

end architecture Valid1;


--------------------------------------------------------------------
-- Bind the Valid1 architecture to MonitorTestCtrl_1 in the direct
-- SpaceWire monitor harness.
--------------------------------------------------------------------
configuration TbSpaceWireMonitor_Valid1 of TbSpaceWireMonitor is

  for TestHarness

    for MonitorTestCtrl_1 : MonitorTestCtrl

      use entity work.MonitorTestCtrl(Valid1);

    end for;

  end for;

end configuration TbSpaceWireMonitor_Valid1;