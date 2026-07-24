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
-- Extended directed SpaceWire traffic test
--
-- Purpose:
--   - exercise more packet lengths and data patterns;
--   - exercise both EOP and EEP;
--   - run packet traffic concurrently in both directions;
--   - verify both passive Data/Strobe monitors and scoreboards;
--   - transmit and receive SpaceWire time-codes/broadcast codes.
--
-- The time-code ports listed below must be exposed by TestCtrl and
-- connected to the tick_in/ctrl_in/time_in and
-- tick_out/ctrl_out/time_out ports of both spwstream instances.
--------------------------------------------------------------------
architecture Traffic1 of TestCtrl is

  ------------------------------------------------------------------
  -- Node A -> Node B packets
  ------------------------------------------------------------------
  constant PacketA1 : SpaceWirePacketType := (
    0 => x"00"
  );

  constant PacketA2 : SpaceWirePacketType := (
    x"FF", x"00"
  );

  constant PacketA3 : SpaceWirePacketType := (
    x"55", x"AA", x"55", x"AA",
    x"00", x"FF", x"7E"
  );

  constant PacketA4 : SpaceWirePacketType := (
    x"00", x"01", x"02", x"03",
    x"04", x"05", x"06", x"07",
    x"08", x"09", x"0A", x"0B",
    x"0C", x"0D", x"0E", x"0F"
  );

  constant PacketA5 : SpaceWirePacketType := (
    x"DE", x"AD", x"BE", x"EF",
    x"12", x"34", x"56", x"78",
    x"87", x"65", x"43", x"21",
    x"00", x"FF", x"0F", x"F0",
    x"33", x"CC", x"5A", x"A5",
    x"7E", x"81", x"10", x"EF"
  );


  ------------------------------------------------------------------
  -- Node B -> Node A packets
  ------------------------------------------------------------------
  constant PacketB1 : SpaceWirePacketType := (
    0 => x"FF"
  );

  constant PacketB2 : SpaceWirePacketType := (
    x"01", x"02", x"03", x"04"
  );

  constant PacketB3 : SpaceWirePacketType := (
    x"53", x"70", x"61", x"63",
    x"65", x"57", x"69", x"72"
  );

  constant PacketB4 : SpaceWirePacketType := (
    x"0F", x"0E", x"0D", x"0C",
    x"0B", x"0A", x"09", x"08",
    x"07", x"06", x"05", x"04",
    x"03", x"02", x"01"
  );

  constant PacketB5 : SpaceWirePacketType := (
    x"80", x"81", x"82", x"83",
    x"84", x"85", x"86", x"87",
    x"88", x"89", x"8A", x"8B",
    x"8C", x"8D", x"8E", x"8F",
    x"90", x"91", x"92", x"93",
    x"94", x"95", x"96", x"97",
    x"98", x"99", x"9A", x"9B",
    x"9C", x"9D", x"9E", x"9F"
  );


  ------------------------------------------------------------------
  -- Time-codes / broadcast codes
  --
  -- Broadcast byte seen by the monitor:
  --   ctrl(1 downto 0) & time(5 downto 0)
  ------------------------------------------------------------------
  constant TimeCodeA1Ctrl : std_logic_vector(1 downto 0) := "00";
  constant TimeCodeA1Time : std_logic_vector(5 downto 0) := "000001";

  constant TimeCodeA2Ctrl : std_logic_vector(1 downto 0) := "10";
  constant TimeCodeA2Time : std_logic_vector(5 downto 0) := "000010";

  constant TimeCodeB1Ctrl : std_logic_vector(1 downto 0) := "01";
  constant TimeCodeB1Time : std_logic_vector(5 downto 0) := "010000";

  constant TimeCodeB2Ctrl : std_logic_vector(1 downto 0) := "11";
  constant TimeCodeB2Time : std_logic_vector(5 downto 0) := "010001";


  ------------------------------------------------------------------
  -- One monitor/scoreboard transaction is generated for every data
  -- character and one more for every EOP or EEP.
  --
  -- Time-codes are not N-Chars and are therefore checked separately.
  ------------------------------------------------------------------
  constant A_TO_B_TRANSACTION_COUNT : integer :=
    PacketA1'length + 1 +
    PacketA2'length + 1 +
    PacketA3'length + 1 +
    PacketA4'length + 1 +
    PacketA5'length + 1;

  constant B_TO_A_TRANSACTION_COUNT : integer :=
    PacketB1'length + 1 +
    PacketB2'length + 1 +
    PacketB3'length + 1 +
    PacketB4'length + 1 +
    PacketB5'length + 1;


  signal MonitorABScoreboard : ScoreboardIDType;
  signal MonitorBAScoreboard : ScoreboardIDType;

  signal TestDone : integer_barrier := 1;


  ------------------------------------------------------------------
  -- Queue one complete expected packet for a passive monitor.
  ------------------------------------------------------------------
  procedure PushExpectedPacket(
    constant Scoreboard : in ScoreboardIDType;
    constant Packet     : in SpaceWirePacketType;
    constant Ending     : in SpaceWirePacketEndType
  ) is
    variable Expected : SpaceWireStimType;
  begin
    for Index in Packet'range loop
      Expected.Data := Packet(Index);
      Expected.Flag := (others => '0');
      Push(Scoreboard, Expected);
    end loop;

    Expected.Flag := (others => '1');

    case Ending is
      when PACKET_EOP =>
        Expected.Data := x"00";

      when PACKET_EEP =>
        Expected.Data := x"01";
    end case;

    Push(Scoreboard, Expected);
  end procedure PushExpectedPacket;


begin

  ------------------------------------------------------------------
  -- Test control and reporting
  ------------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("TbSpaceWire_Traffic1");
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

    --------------------------------------------------------------
    -- Passive monitor scoreboard completion.
    --------------------------------------------------------------
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

    --------------------------------------------------------------
    -- Both links must still be healthy after all traffic.
    --------------------------------------------------------------
    AffirmIf(RunningA = '1', "Node A remains in Running");
    AffirmIf(RunningB = '1', "Node B remains in Running");

    AffirmIf(ErrorDisconnectA = '0', "Node A has no disconnect error");
    AffirmIf(ErrorParityA     = '0', "Node A has no parity error");
    AffirmIf(ErrorEscapeA     = '0', "Node A has no escape error");
    AffirmIf(ErrorCreditA     = '0', "Node A has no credit error");

    AffirmIf(ErrorDisconnectB = '0', "Node B has no disconnect error");
    AffirmIf(ErrorParityB     = '0', "Node B has no parity error");
    AffirmIf(ErrorEscapeB     = '0', "Node B has no escape error");
    AffirmIf(ErrorCreditB     = '0', "Node B has no credit error");

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
  -- Node A transmitter
  ------------------------------------------------------------------
  SpaceWireTxAProc : process
    variable SpwTxAID        : AlertLogIDType;
    variable TransactionCount : integer;
    variable ErrorCount       : integer;
  begin
    GetAlertLogID(SpwTxRecA, SpwTxAID);
    SetLogEnable(SpwTxAID, INFO, FALSE);

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    WaitForClock(SpwTxRecA, 2);

    PushExpectedPacket(MonitorABScoreboard, PacketA1, PACKET_EOP);
    SendPacket(SpwTxRecA, PacketA1, PACKET_EOP);

    PushExpectedPacket(MonitorABScoreboard, PacketA2, PACKET_EEP);
    SendPacket(SpwTxRecA, PacketA2, PACKET_EEP);

    PushExpectedPacket(MonitorABScoreboard, PacketA3, PACKET_EOP);
    SendPacket(SpwTxRecA, PacketA3, PACKET_EOP);

    PushExpectedPacket(MonitorABScoreboard, PacketA4, PACKET_EOP);
    SendPacket(SpwTxRecA, PacketA4, PACKET_EOP);

    PushExpectedPacket(MonitorABScoreboard, PacketA5, PACKET_EEP);
    SendPacket(SpwTxRecA, PacketA5, PACKET_EEP);

    GetTransactionCount(SpwTxRecA, TransactionCount);

    AffirmIfEqual(
      SpwTxAID,
      TransactionCount,
      A_TO_B_TRANSACTION_COUNT,
      "Node A TX transaction count"
    );

    GetErrorCount(SpwTxRecA, ErrorCount);

    AffirmIfEqual(
      SpwTxAID,
      ErrorCount,
      0,
      "Node A TX error count"
    );

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireTxAProc;


  ------------------------------------------------------------------
  -- Node B transmitter
  --
  -- This process runs concurrently with SpaceWireTxAProc, producing
  -- sustained full-duplex traffic.
  ------------------------------------------------------------------
  SpaceWireTxBProc : process
    variable SpwTxBID         : AlertLogIDType;
    variable TransactionCount : integer;
    variable ErrorCount       : integer;
  begin
    GetAlertLogID(SpwTxRecB, SpwTxBID);
    SetLogEnable(SpwTxBID, INFO, FALSE);

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    WaitForClock(SpwTxRecB, 2);

    PushExpectedPacket(MonitorBAScoreboard, PacketB1, PACKET_EEP);
    SendPacket(SpwTxRecB, PacketB1, PACKET_EEP);

    PushExpectedPacket(MonitorBAScoreboard, PacketB2, PACKET_EOP);
    SendPacket(SpwTxRecB, PacketB2, PACKET_EOP);

    PushExpectedPacket(MonitorBAScoreboard, PacketB3, PACKET_EEP);
    SendPacket(SpwTxRecB, PacketB3, PACKET_EEP);

    PushExpectedPacket(MonitorBAScoreboard, PacketB4, PACKET_EOP);
    SendPacket(SpwTxRecB, PacketB4, PACKET_EOP);

    PushExpectedPacket(MonitorBAScoreboard, PacketB5, PACKET_EOP);
    SendPacket(SpwTxRecB, PacketB5, PACKET_EOP);

    GetTransactionCount(SpwTxRecB, TransactionCount);

    AffirmIfEqual(
      SpwTxBID,
      TransactionCount,
      B_TO_A_TRANSACTION_COUNT,
      "Node B TX transaction count"
    );

    GetErrorCount(SpwTxRecB, ErrorCount);

    AffirmIfEqual(
      SpwTxBID,
      ErrorCount,
      0,
      "Node B TX error count"
    );

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireTxBProc;


  ------------------------------------------------------------------
  -- Node B receiver: checks all A-to-B packets
  ------------------------------------------------------------------
  SpaceWireRxBProc : process
    variable SpwRxBID         : AlertLogIDType;
    variable TransactionCount : integer;
    variable ErrorCount       : integer;
  begin
    GetAlertLogID(SpwRxRecB, SpwRxBID);
    SetLogEnable(SpwRxBID, INFO, FALSE);

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    CheckPacket(SpwRxRecB, PacketA1, PACKET_EOP);
    CheckPacket(SpwRxRecB, PacketA2, PACKET_EEP);
    CheckPacket(SpwRxRecB, PacketA3, PACKET_EOP);
    CheckPacket(SpwRxRecB, PacketA4, PACKET_EOP);
    CheckPacket(SpwRxRecB, PacketA5, PACKET_EEP);

    GetTransactionCount(SpwRxRecB, TransactionCount);

    AffirmIfEqual(
      SpwRxBID,
      TransactionCount,
      A_TO_B_TRANSACTION_COUNT,
      "Node B RX transaction count"
    );

    GetErrorCount(SpwRxRecB, ErrorCount);

    AffirmIfEqual(
      SpwRxBID,
      ErrorCount,
      0,
      "Node B RX error count"
    );

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireRxBProc;


  ------------------------------------------------------------------
  -- Node A receiver: checks all B-to-A packets
  ------------------------------------------------------------------
  SpaceWireRxAProc : process
    variable SpwRxAID         : AlertLogIDType;
    variable TransactionCount : integer;
    variable ErrorCount       : integer;
  begin
    GetAlertLogID(SpwRxRecA, SpwRxAID);
    SetLogEnable(SpwRxAID, INFO, FALSE);

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    CheckPacket(SpwRxRecA, PacketB1, PACKET_EEP);
    CheckPacket(SpwRxRecA, PacketB2, PACKET_EOP);
    CheckPacket(SpwRxRecA, PacketB3, PACKET_EEP);
    CheckPacket(SpwRxRecA, PacketB4, PACKET_EOP);
    CheckPacket(SpwRxRecA, PacketB5, PACKET_EOP);

    GetTransactionCount(SpwRxRecA, TransactionCount);

    AffirmIfEqual(
      SpwRxAID,
      TransactionCount,
      B_TO_A_TRANSACTION_COUNT,
      "Node A RX transaction count"
    );

    GetErrorCount(SpwRxRecA, ErrorCount);

    AffirmIfEqual(
      SpwRxAID,
      ErrorCount,
      0,
      "Node A RX error count"
    );

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireRxAProc;


  ------------------------------------------------------------------
  -- A-to-B passive monitor scoreboard checker
  ------------------------------------------------------------------
  SpaceWireMonitorABScoreboardProc : process
    variable Actual : SpaceWireStimType;
  begin
    wait until nReset = '1';

    for OperationNumber in 1 to A_TO_B_TRANSACTION_COUNT loop
      wait until MonABValid = '1';

      Actual.Data := MonABData;
      Actual.Flag := (others => MonABFlag);

      Check(MonitorABScoreboard, Actual);
    end loop;

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireMonitorABScoreboardProc;


  ------------------------------------------------------------------
  -- B-to-A passive monitor scoreboard checker
  ------------------------------------------------------------------
  SpaceWireMonitorBAScoreboardProc : process
    variable Actual : SpaceWireStimType;
  begin
    wait until nReset = '1';

    for OperationNumber in 1 to B_TO_A_TRANSACTION_COUNT loop
      wait until MonBAValid = '1';

      Actual.Data := MonBAData;
      Actual.Flag := (others => MonBAFlag);

      Check(MonitorBAScoreboard, Actual);
    end loop;

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireMonitorBAScoreboardProc;


  ------------------------------------------------------------------
  -- Time-code / broadcast-code test
  --
  -- A time-code is transmitted as ESC + DATA on Data/Strobe.  The
  -- passive monitor logs it as a BROADCAST code, while the receiving
  -- spwstream core presents it on tick_out/ctrl_out/time_out.
  ------------------------------------------------------------------
  SpaceWireTimeCodeProc : process

    procedure SendAndCheckTimeCode(
      constant Name      : in string;

      signal TickIn      : out std_logic;
      signal CtrlIn      : out std_logic_vector(1 downto 0);
      signal TimeIn      : out std_logic_vector(5 downto 0);

      signal TickOut     : in std_logic;
      signal CtrlOut     : in std_logic_vector(1 downto 0);
      signal TimeOut     : in std_logic_vector(5 downto 0);

      constant CtrlValue : in std_logic_vector(1 downto 0);
      constant TimeValue : in std_logic_vector(5 downto 0)
    ) is
    begin
      CtrlIn <= CtrlValue;
      TimeIn <= TimeValue;

      wait until rising_edge(Clk);
      TickIn <= '1';

      wait until rising_edge(Clk);
      TickIn <= '0';

      wait until TickOut = '1' for 100 us;

      AffirmIf(
        TickOut = '1',
        Name & " received"
      );

      if TickOut = '1' then
        AffirmIfEqual(
          CtrlOut,
          CtrlValue,
          Name & " control"
        );

        AffirmIfEqual(
          TimeOut,
          TimeValue,
          Name & " time"
        );
      end if;

      -- Separate consecutive requests and allow tick_out to return
      -- low before issuing another time-code.
      for DelayCycle in 1 to 4 loop
        wait until rising_edge(Clk);
      end loop;
    end procedure SendAndCheckTimeCode;

  begin
    TickInA <= '0';
    CtrlInA <= (others => '0');
    TimeInA <= (others => '0');

    TickInB <= '0';
    CtrlInB <= (others => '0');
    TimeInB <= (others => '0');

    wait until nReset = '1';

    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    if MonABSynchronized /= '1' then
      wait until MonABSynchronized = '1';
    end if;

    if MonBASynchronized /= '1' then
      wait until MonBASynchronized = '1';
    end if;

    --------------------------------------------------------------
    -- Place the first time-codes inside active packet traffic when
    -- possible. This proves that broadcast codes do not become part
    -- of the packet scoreboards.
    --------------------------------------------------------------
    if MonABPacketActive /= '1' then
      wait until MonABPacketActive = '1';
    end if;

    SendAndCheckTimeCode(
      "A-to-B time-code 1",
      TickInA, CtrlInA, TimeInA,
      TickOutB, CtrlOutB, TimeOutB,
      TimeCodeA1Ctrl, TimeCodeA1Time
    );

    if MonBAPacketActive /= '1' then
      wait until MonBAPacketActive = '1';
    end if;

    SendAndCheckTimeCode(
      "B-to-A time-code 1",
      TickInB, CtrlInB, TimeInB,
      TickOutA, CtrlOutA, TimeOutA,
      TimeCodeB1Ctrl, TimeCodeB1Time
    );

    SendAndCheckTimeCode(
      "A-to-B time-code 2",
      TickInA, CtrlInA, TimeInA,
      TickOutB, CtrlOutB, TimeOutB,
      TimeCodeA2Ctrl, TimeCodeA2Time
    );

    SendAndCheckTimeCode(
      "B-to-A time-code 2",
      TickInB, CtrlInB, TimeInB,
      TickOutA, CtrlOutA, TimeOutA,
      TimeCodeB2Ctrl, TimeCodeB2Time
    );

    WaitForBarrier(TestDone);
    wait;
  end process SpaceWireTimeCodeProc;

end architecture Traffic1;


--------------------------------------------------------------------
-- Bind the Traffic1 architecture to TestCtrl_1 in TbSpaceWire.
--------------------------------------------------------------------
configuration TbSpaceWire_Traffic1 of TbSpaceWire is
  for TestHarness
    for TestCtrl_1 : TestCtrl
      use entity work.TestCtrl(Traffic1);
    end for;
  end for;
end configuration TbSpaceWire_Traffic1;
