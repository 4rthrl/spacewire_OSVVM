library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;


--------------------------------------------------------------------
-- First directed SpaceWire test
--
-- Structure deliberately follows the OSVVM UART SendGet1 test:
--
--   ControlProc
--   SpaceWireTbTxProc
--   SpaceWireTbRxProc
--
-- The TX and RX processes run concurrently.
--------------------------------------------------------------------
architecture SendGet1 of TestCtrl is

  ------------------------------------------------------------------
  -- Barrier shared by the control, TX, and RX processes.
  --
  -- ControlProc waits until the TX and RX processes have completed.
  ------------------------------------------------------------------
  signal TestDone : integer_barrier := 1;

begin

  ------------------------------------------------------------------
  -- ControlProc
  --
  -- Sets up OSVVM reporting, waits for the end of the test,
  -- generates the final reports, and stops the simulation.
  ------------------------------------------------------------------
  ControlProc : process
  begin

    --------------------------------------------------------------
    -- Initialize the OSVVM test
    --------------------------------------------------------------
    SetTestName("TbSpaceWire_SendGet1");

    -- Show successful checks in the transcript
    SetLogEnable(PASSED, FALSE);

    --------------------------------------------------------------
    -- Allow verification components to initialize
    --------------------------------------------------------------
    wait for 0 ns;

    SetAlertLogOptions(
      WriteTimeLast => FALSE
    );

    SetAlertLogOptions(
      TimeJustifyAmount => 16
    );

    SetAlertLogJustify;

    --------------------------------------------------------------
    -- Allow the transaction records and model IDs to initialize
    --------------------------------------------------------------
    wait for 0 ns;
    wait for 0 ns;

    --------------------------------------------------------------
    -- Open the OSVVM transcript
    --------------------------------------------------------------
    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    --------------------------------------------------------------
    -- Wait until reset is released
    --------------------------------------------------------------
    wait until nReset = '1';

    --------------------------------------------------------------
    -- Remove any alerts generated during initialization
    --------------------------------------------------------------
    ClearAlerts;

    --------------------------------------------------------------
    -- Wait until the transmitting and receiving processes finish.
    --
    -- The timeout ensures that a broken link cannot make the
    -- simulation wait forever.
    --------------------------------------------------------------
    WaitForBarrier(
      TestDone,
      5 ms
    );

    --------------------------------------------------------------
    -- Generate final OSVVM reports
    --------------------------------------------------------------
    TranscriptClose;

    EndOfTestReports(
      TimeOut => (now >= 5 ms)
    );

    --------------------------------------------------------------
    -- Stop the simulator
    --------------------------------------------------------------
    std.env.stop;
    wait;

  end process ControlProc;


  ------------------------------------------------------------------
  -- SpaceWireTbTxProc
  --
  -- Sends characters through the two SpaceWire transmit VCs.
  --
  -- Sequence 1:
  --   Node A -> Node B
  --   0x55, 0x5A, EOP
  --
  -- Sequence 2:
  --   Node B -> Node A
  --   0xA6, 0xC3, EEP
  ------------------------------------------------------------------
  SpaceWireTbTxProc : process

    variable SpwTxAID : AlertLogIDType;
    variable SpwTxBID : AlertLogIDType;

    variable TransactionCount : integer;
    variable ErrorCount       : integer;

  begin

    --------------------------------------------------------------
    -- Obtain the alert/log identities of the two TX VCs
    --------------------------------------------------------------
    GetAlertLogID(
      SpwTxRecA,
      SpwTxAID
    );

    GetAlertLogID(
      SpwTxRecB,
      SpwTxBID
    );

    --------------------------------------------------------------
    -- Enable informational logging for the TX VCs
    --------------------------------------------------------------
    SetLogEnable(
      SpwTxAID,
      INFO,
      TRUE
    );

    SetLogEnable(
      SpwTxBID,
      INFO,
      TRUE
    );

    --------------------------------------------------------------
    -- Wait until reset is released
    --------------------------------------------------------------
    wait until nReset = '1';

    --------------------------------------------------------------
    -- Wait until both SpaceWire link state machines are Running
    --------------------------------------------------------------
    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    --------------------------------------------------------------
    -- Wait two VC clock cycles before starting traffic
    --------------------------------------------------------------
    WaitForClock(
      SpwTxRecA,
      2
    );


    --------------------------------------------------------------
    -- Sequence 1: Node A transmits to Node B
    --------------------------------------------------------------
    Log(
      "TX: Starting Node A to Node B sequence",
      INFO
    );

    SendData(
      SpwTxRecA,
      x"55"
    );

    SendData(
      SpwTxRecA,
      x"5A"
    );

    SendEop(
      SpwTxRecA
    );


    --------------------------------------------------------------
    -- Check Node A TX transaction statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwTxRecA,
      TransactionCount
    );

    AffirmIfEqual(
      SpwTxAID,
      TransactionCount,
      3,
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
    -- Sequence 2: Node B transmits to Node A
    --------------------------------------------------------------
    Log(
      "TX: Starting Node B to Node A sequence",
      INFO
    );

    SendData(
      SpwTxRecB,
      x"A6"
    );

    SendData(
      SpwTxRecB,
      x"C3"
    );

    SendEep(
      SpwTxRecB
    );


    --------------------------------------------------------------
    -- Check Node B TX transaction statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwTxRecB,
      TransactionCount
    );

    AffirmIfEqual(
      SpwTxBID,
      TransactionCount,
      3,
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


    --------------------------------------------------------------
    -- TX work is complete.
    --
    -- The RX process can still be waiting for the final characters.
    -- The barrier ensures ControlProc waits for both processes.
    --------------------------------------------------------------
    WaitForBarrier(TestDone);

    wait;

  end process SpaceWireTbTxProc;


  ------------------------------------------------------------------
  -- SpaceWireTbRxProc
  --
  -- Checks characters received through the two SpaceWire RX VCs.
  --
  -- This process runs concurrently with SpaceWireTbTxProc.
  ------------------------------------------------------------------
  SpaceWireTbRxProc : process

    variable SpwRxAID : AlertLogIDType;
    variable SpwRxBID : AlertLogIDType;

    variable TransactionCount : integer;
    variable ErrorCount       : integer;

  begin

    --------------------------------------------------------------
    -- Obtain the alert/log identities of the RX VCs
    --------------------------------------------------------------
    GetAlertLogID(
      SpwRxRecA,
      SpwRxAID
    );

    GetAlertLogID(
      SpwRxRecB,
      SpwRxBID
    );

    --------------------------------------------------------------
    -- Enable informational logging
    --------------------------------------------------------------
    SetLogEnable(
      SpwRxAID,
      INFO,
      TRUE
    );

    SetLogEnable(
      SpwRxBID,
      INFO,
      TRUE
    );

    --------------------------------------------------------------
    -- Wait until reset is released
    --------------------------------------------------------------
    wait until nReset = '1';

    --------------------------------------------------------------
    -- Wait until both link directions are operational
    --------------------------------------------------------------
    if RunningA /= '1' or RunningB /= '1' then
      wait until RunningA = '1' and RunningB = '1';
    end if;

    --------------------------------------------------------------
    -- Allow the receive VCs two clock cycles to settle
    --------------------------------------------------------------
    WaitForClock(
      SpwRxRecB,
      2
    );


    --------------------------------------------------------------
    -- Check Sequence 1
    --
    -- Data transmitted by Node A must arrive at Node B.
    --------------------------------------------------------------
    Log(
      "RX: Checking Node A to Node B sequence",
      INFO
    );

    CheckData(
      SpwRxRecB,
      x"55"
    );

    CheckData(
      SpwRxRecB,
      x"5A"
    );

    CheckEop(
      SpwRxRecB
    );


    --------------------------------------------------------------
    -- Check Node B RX transaction statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwRxRecB,
      TransactionCount
    );

    AffirmIfEqual(
      SpwRxBID,
      TransactionCount,
      3,
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
    -- Check Sequence 2
    --
    -- Data transmitted by Node B must arrive at Node A.
    --------------------------------------------------------------
    Log(
      "RX: Checking Node B to Node A sequence",
      INFO
    );

    CheckData(
      SpwRxRecA,
      x"A6"
    );

    CheckData(
      SpwRxRecA,
      x"C3"
    );

    CheckEep(
      SpwRxRecA
    );


    --------------------------------------------------------------
    -- Check Node A RX transaction statistics
    --------------------------------------------------------------
    GetTransactionCount(
      SpwRxRecA,
      TransactionCount
    );

    AffirmIfEqual(
      SpwRxAID,
      TransactionCount,
      3,
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
    -- Check that both link state machines remain Running
    --------------------------------------------------------------
    AffirmIf(
      RunningA = '1',
      "Node A remains in the Running state"
    );

    AffirmIf(
      RunningB = '1',
      "Node B remains in the Running state"
    );


    --------------------------------------------------------------
    -- RX work is complete
    --------------------------------------------------------------
    WaitForBarrier(TestDone);

    wait;

  end process SpaceWireTbRxProc;

end architecture SendGet1;


--------------------------------------------------------------------
-- Bind the SendGet1 architecture to TestCtrl_1 in TbSpaceWire.
--------------------------------------------------------------------
configuration TbSpaceWire_SendGet1 of TbSpaceWire is

  for TestHarness

    for TestCtrl_1 : TestCtrl

      use entity work.TestCtrl(SendGet1);

    end for;

  end for;

end configuration TbSpaceWire_SendGet1;