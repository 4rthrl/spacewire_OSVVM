library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;
  use osvvm_spacewire.ScoreboardPkg_SpaceWire.all;


--------------------------------------------------------------------
-- Directed SpaceWire packet test
--
-- This test verifies the packet helper procedures added to
-- SpaceWireTbPkg:
--
--   SendPacket
--   CheckPacket
--
-- A packet is still transferred internally as individual SpaceWire
-- N-Chars followed by EOP or EEP.
--
-- Test traffic:
--
--   Node A -> Node B
--     PacketA1: 1 byte,  EOP
--     PacketA2: 8 bytes, EEP
--
--   Node B -> Node A
--     PacketB1: 4 bytes,  EOP
--     PacketB2: 16 bytes, EEP
--------------------------------------------------------------------
architecture Packets1 of TestCtrl is

  ------------------------------------------------------------------
  -- Directed packets
  ------------------------------------------------------------------
  constant PacketA1 : SpaceWirePacketType := (
    0 => x"55"
  );

  constant PacketA2 : SpaceWirePacketType := (
    x"00", x"11", x"22", x"33",
    x"44", x"55", x"66", x"77"
  );

  constant PacketB1 : SpaceWirePacketType := (
    x"A1", x"B2", x"C3", x"D4"
  );

  constant PacketB2 : SpaceWirePacketType := (
    x"00", x"01", x"02", x"03",
    x"04", x"05", x"06", x"07",
    x"08", x"09", x"0A", x"0B",
    x"0C", x"0D", x"0E", x"0F"
  );

  ------------------------------------------------------------------
  -- Each packet produces one transaction per data byte and one
  -- additional transaction for its EOP or EEP terminator.
  ------------------------------------------------------------------
  constant A_TO_B_TRANSACTION_COUNT : integer :=
    PacketA1'length + 1 +
    PacketA2'length + 1;

  constant B_TO_A_TRANSACTION_COUNT : integer :=
    PacketB1'length + 1 +
    PacketB2'length + 1;

  ------------------------------------------------------------------
  -- Expected A-to-B N-Chars are pushed here by the TX process.
  -- Actual N-Chars decoded from Data/Strobe are checked by the
  -- passive monitor checker process.
  ------------------------------------------------------------------
  signal MonitorABScoreboard : ScoreboardIDType;

  signal MonitorBAScoreboard : ScoreboardIDType;

  ------------------------------------------------------------------
  -- Barrier shared by control, TX, RX, and monitor checker.
  ------------------------------------------------------------------
  signal TestDone : integer_barrier := 1;

begin

  ------------------------------------------------------------------
  -- ControlProc
  --
  -- Sets up OSVVM reporting, waits for the TX and RX processes,
  -- generates the reports, and stops the simulation.
  ------------------------------------------------------------------
  ControlProc : process
  begin

    SetTestName("TbSpaceWire_Packets1");
    SetLogEnable(PASSED, FALSE);

    MonitorABScoreboard <= NewID(
      "Monitor_A_to_B_Scoreboard"
    );

    MonitorBAScoreboard <= NewID(
      "Monitor_B_to_A_Scoreboard"
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
      5 ms
    );

    AffirmIf(
      IsEmpty(MonitorABScoreboard),
      "Monitor A-to-B scoreboard is empty"
    );

    AffirmIfEqual(
      GetCheckCount(MonitorABScoreboard),
      A_TO_B_TRANSACTION_COUNT,
      "Monitor A-to-B scoreboard check count"
    );

    AffirmIf(
      IsEmpty(MonitorBAScoreboard),
      "Monitor B-to-A scoreboard is empty"
    );

    AffirmIfEqual(
      GetCheckCount(MonitorBAScoreboard),
      B_TO_A_TRANSACTION_COUNT,
      "Monitor B-to-A scoreboard check count"
    );

    TranscriptClose;

    osvvm_spacewire.ScoreboardPkg_SpaceWire.WriteScoreboardYaml(
      FileName => "SpaceWire"
    );

    EndOfTestReports(
      TimeOut => (now >= 5 ms)
    );

    std.env.stop;
    wait;

  end process ControlProc;


  ------------------------------------------------------------------
  -- SpaceWireTbTxProc
  --
  -- Sends four complete packets using SendPacket.
  ------------------------------------------------------------------
  SpaceWireTbTxProc : process

    variable SpwTxAID : AlertLogIDType;
    variable SpwTxBID : AlertLogIDType;

    variable TransactionCount : integer;
    variable ErrorCount       : integer;

    --------------------------------------------------------------
    -- Queue one expected packet in the passive monitor scoreboard.
    --------------------------------------------------------------
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

    GetAlertLogID(
      SpwTxRecA,
      SpwTxAID
    );

    GetAlertLogID(
      SpwTxRecB,
      SpwTxBID
    );

    SetLogEnable(
      SpwTxAID,
      INFO,
      FALSE
    );

    SetLogEnable(
      SpwTxBID,
      INFO,
      FALSE
    );

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    WaitForClock(
      SpwTxRecA,
      2
    );


    --------------------------------------------------------------
    -- Node A -> Node B
    --------------------------------------------------------------
    Log(
      "TX: Sending PacketA1 from Node A to Node B: 1 byte, EOP",
      INFO
    );

    PushExpectedPacket(
      MonitorABScoreboard,
      PacketA1,
      PACKET_EOP
    );
    SendPacket(
      SpwTxRecA,
      PacketA1,
      PACKET_EOP
    );

    Log(
      "TX: Sending PacketA2 from Node A to Node B: 8 bytes, EEP",
      INFO
    );

    PushExpectedPacket(
      MonitorABScoreboard,
      PacketA2,
      PACKET_EEP
    );

    SendPacket(
      SpwTxRecA,
      PacketA2,
      PACKET_EEP
    );


    --------------------------------------------------------------
    -- Check Node A TX statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwTxRecA,
      TransactionCount
    );

    AffirmIfEqual(
      SpwTxAID,
      TransactionCount,
      A_TO_B_TRANSACTION_COUNT,
      "Node A TX transaction count"
    );

    GetErrorCount(
      SpwTxRecA,
      ErrorCount
    );

    AffirmIfEqual(
      SpwTxAID,
      ErrorCount,
      0,
      "Node A TX error count"
    );


    --------------------------------------------------------------
    -- Node B -> Node A
    --------------------------------------------------------------
    Log(
      "TX: Sending PacketB1 from Node B to Node A: 4 bytes, EOP",
      INFO
    );

    PushExpectedPacket(
      MonitorBAScoreboard,
      PacketB1,
      PACKET_EOP
    );


    SendPacket(
      SpwTxRecB,
      PacketB1,
      PACKET_EOP
    );

    Log(
      "TX: Sending PacketB2 from Node B to Node A: 16 bytes, EEP",
      INFO
    );

    PushExpectedPacket(
      MonitorBAScoreboard,
      PacketB2,
      PACKET_EEP
    );

    SendPacket(
      SpwTxRecB,
      PacketB2,
      PACKET_EEP
    );


    --------------------------------------------------------------
    -- Check Node B TX statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwTxRecB,
      TransactionCount
    );

    AffirmIfEqual(
      SpwTxBID,
      TransactionCount,
      B_TO_A_TRANSACTION_COUNT,
      "Node B TX transaction count"
    );

    GetErrorCount(
      SpwTxRecB,
      ErrorCount
    );

    AffirmIfEqual(
      SpwTxBID,
      ErrorCount,
      0,
      "Node B TX error count"
    );


    WaitForBarrier(TestDone);
    wait;

  end process SpaceWireTbTxProc;


  ------------------------------------------------------------------
  -- SpaceWireMonitorABScoreboardProc
  --
  -- Converts the passive monitor output into SpaceWireStimType and
  -- compares each actual decoded N-Char against the expected FIFO.
  ------------------------------------------------------------------
  SpaceWireMonitorABScoreboardProc : process
    variable Actual : SpaceWireStimType;
  begin
    wait until nReset = '1';

    for OperationNumber in 1 to A_TO_B_TRANSACTION_COUNT loop
      wait until MonABValid = '1';

      Actual.Data := MonABData;
      Actual.Flag := (others => MonABFlag);

      Check(
        MonitorABScoreboard,
        Actual
      );
    end loop;

    WaitForBarrier(TestDone);
    wait;

  end process SpaceWireMonitorABScoreboardProc;

  SpaceWireMonitorBAScoreboardProc : process
    variable Actual : SpaceWireStimType;
  begin 
    wait until nReset = '1';

    for OperationNumber in 1 to B_TO_A_TRANSACTION_COUNT loop
      wait until MonBAValid = '1';

      Actual.Data := MonBAData;
      Actual.Flag := (others => MonBAFlag);

      Check(
        MonitorBAScoreboard,
        Actual
      );
    end loop;

    WaitForBarrier(TestDone);
    wait;

  end process SpaceWireMonitorBAScoreboardProc;


  ------------------------------------------------------------------
  -- SpaceWireTbRxProc
  --
  -- Checks the four complete packets using CheckPacket.
  ------------------------------------------------------------------
  SpaceWireTbRxProc : process

    variable SpwRxAID : AlertLogIDType;
    variable SpwRxBID : AlertLogIDType;

    variable TransactionCount : integer;
    variable ErrorCount       : integer;

  begin

    GetAlertLogID(
      SpwRxRecA,
      SpwRxAID
    );

    GetAlertLogID(
      SpwRxRecB,
      SpwRxBID
    );

    SetLogEnable(
      SpwRxAID,
      INFO,
      FALSE
    );

    SetLogEnable(
      SpwRxBID,
      INFO,
      FALSE
    );

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    WaitForClock(
      SpwRxRecB,
      2
    );


    --------------------------------------------------------------
    -- Check Node A -> Node B packets
    --------------------------------------------------------------
    Log(
      "RX: Checking PacketA1 at Node B",
      INFO
    );

    CheckPacket(
      SpwRxRecB,
      PacketA1,
      PACKET_EOP
    );

    Log(
      "RX: Checking PacketA2 at Node B",
      INFO
    );

    CheckPacket(
      SpwRxRecB,
      PacketA2,
      PACKET_EEP
    );


    --------------------------------------------------------------
    -- Check Node B RX statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwRxRecB,
      TransactionCount
    );

    AffirmIfEqual(
      SpwRxBID,
      TransactionCount,
      A_TO_B_TRANSACTION_COUNT,
      "Node B RX transaction count"
    );

    GetErrorCount(
      SpwRxRecB,
      ErrorCount
    );

    AffirmIfEqual(
      SpwRxBID,
      ErrorCount,
      0,
      "Node B RX error count"
    );


    --------------------------------------------------------------
    -- Check Node B -> Node A packets
    --------------------------------------------------------------
    Log(
      "RX: Checking PacketB1 at Node A",
      INFO
    );

    CheckPacket(
      SpwRxRecA,
      PacketB1,
      PACKET_EOP
    );

    Log(
      "RX: Checking PacketB2 at Node A",
      INFO
    );

    CheckPacket(
      SpwRxRecA,
      PacketB2,
      PACKET_EEP
    );


    --------------------------------------------------------------
    -- Check Node A RX statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwRxRecA,
      TransactionCount
    );

    AffirmIfEqual(
      SpwRxAID,
      TransactionCount,
      B_TO_A_TRANSACTION_COUNT,
      "Node A RX transaction count"
    );

    GetErrorCount(
      SpwRxRecA,
      ErrorCount
    );

    AffirmIfEqual(
      SpwRxAID,
      ErrorCount,
      0,
      "Node A RX error count"
    );


    --------------------------------------------------------------
    -- The links must remain operational after all packets.
    --------------------------------------------------------------
    AffirmIf(
      RunningA = '1',
      "Node A remains in the Running state"
    );

    AffirmIf(
      RunningB = '1',
      "Node B remains in the Running state"
    );


    WaitForBarrier(TestDone);
    wait;

  end process SpaceWireTbRxProc;

end architecture Packets1;


--------------------------------------------------------------------
-- Bind the Packets1 architecture to TestCtrl_1 in TbSpaceWire.
--------------------------------------------------------------------
configuration TbSpaceWire_Packets1 of TbSpaceWire is

  for TestHarness

    for TestCtrl_1 : TestCtrl

      use entity work.TestCtrl(Packets1);

    end for;

  end for;

end configuration TbSpaceWire_Packets1;
