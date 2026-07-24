library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

  use osvvm.ScoreboardPkg_slv.all;

use work.SpaceWireTbPkg.all;


entity SpaceWireTx is
  generic (
    MODEL_ID_NAME : string := ""
  );
  port (
    ----------------------------------------------------------------
    -- OSVVM transaction interface
    ----------------------------------------------------------------
    TransRec : inout SpaceWireRecType;

    ----------------------------------------------------------------
    -- Testbench clock and reset
    ----------------------------------------------------------------
    Clk      : in std_logic;
    nReset   : in std_logic;

    ----------------------------------------------------------------
    -- SpaceWire Light spwstream transmit interface
    ----------------------------------------------------------------
    TxReady  : in  std_logic;
    TxWrite  : out std_logic := '0';
    TxFlag   : out std_logic := '0';
    TxData   : out std_logic_vector(7 downto 0) := (others => '0')
  );

  ------------------------------------------------------------------
  -- Use explicit name when provided.
  -- Otherwise derive the name from the VHDL instance label.
  ------------------------------------------------------------------
  constant MODEL_INSTANCE_NAME : string :=
    IfElse(
      MODEL_ID_NAME'length > 0,
      MODEL_ID_NAME,
      to_lower(PathTail(SpaceWireTx'PATH_NAME))
    );

end entity SpaceWireTx;


architecture model of SpaceWireTx is

  ------------------------------------------------------------------
  -- OSVVM alert and logging identity
  ------------------------------------------------------------------
  signal ModelID : AlertLogIDType;

  ------------------------------------------------------------------
  -- Internal queue containing SpaceWire stream items
  --
  -- Each entry contains:
  --     Data(7 downto 0) & Flag(0)
  --
  -- Flag = 0: normal data character
  -- Flag = 1: EOP or EEP
  ------------------------------------------------------------------
  signal TransmitFifo :
    osvvm.ScoreboardPkg_slv.ScoreboardIDType;

  ------------------------------------------------------------------
  -- Transaction accounting
  ------------------------------------------------------------------
  signal TransmitRequestCount : integer := 0;
  signal TransmitDoneCount    : integer := 0;
  signal TransactionDone     : boolean;

begin

  ------------------------------------------------------------------
  -- Initialize OSVVM model identity and private FIFO
  ------------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
  begin
    ID := NewID(MODEL_INSTANCE_NAME);

    ModelID <= ID;

    TransmitFifo <= NewID(
      Name       => "TransmitFifo",
      ParentID   => ID,
      ReportMode => DISABLED,
      Search     => PRIVATE_NAME
    );

    wait;
  end process Initialize;


  ------------------------------------------------------------------
  -- Transaction Dispatcher
  --
  -- Receives high-level OSVVM operations from the test sequencer.
  --
  -- SEND:
  --   1. Read DataToModel and ParamToModel.
  --   2. Convert them into one SpaceWire stream item.
  --   3. Push the item into the internal FIFO.
  --   4. Wait until the item is accepted by spwstream.
  --
  -- SEND_ASYNC:
  --   Same operation, but returns after queueing.
  ------------------------------------------------------------------
  TransactionDispatcher : process
    alias Operation : StreamOperationType is TransRec.Operation;

    variable TxStim : SpaceWireStimType;
  begin

    ----------------------------------------------------------------
    -- Allow the Initialize process to assign ModelID
    ----------------------------------------------------------------
    wait for 0 ns;

    ----------------------------------------------------------------
    -- The common stream record contains a BurstFifo field.
    -- It is not used yet, but it must still be initialized.
    ----------------------------------------------------------------
    TransRec.BurstFifo <= NewID(
      Name       => "TxBurstFifo",
      ParentID   => ModelID,
      ReportMode => DISABLED,
      Search     => PRIVATE_NAME
    );

    wait for 0 ns;

    TransactionDispatcherLoop : loop

      --------------------------------------------------------------
      -- Wait for a transaction from the test sequencer
      --------------------------------------------------------------
      WaitForTransaction(
        Clk => Clk,
        Rdy => TransRec.Rdy,
        Ack => TransRec.Ack
      );

      case Operation is

        ------------------------------------------------------------
        -- Send one SpaceWire N-Char
        ------------------------------------------------------------
        when SEND | SEND_ASYNC =>

          ----------------------------------------------------------
          -- DataToModel carries the eight-bit data value
          ----------------------------------------------------------
          TxStim.Data := SafeResize(
            ModelID,
            TransRec.DataToModel,
            TxStim.Data'length
          );

          ----------------------------------------------------------
          -- ParamToModel carries the one-bit SpaceWire flag
          ----------------------------------------------------------
          TxStim.Flag := SafeResize(
            ModelID,
            TransRec.ParamToModel,
            TxStim.Flag'length
          );

          ----------------------------------------------------------
          -- Convert unknown/weak flag values to clean 0 or 1
          ----------------------------------------------------------
          TxStim.Flag(0) := to_01(TxStim.Flag(0));

          ----------------------------------------------------------
          -- Add the character to the internal transaction FIFO
          ----------------------------------------------------------
          Push(
            TransmitFifo,
            TxStim.Data & TxStim.Flag
          );

          Log(
            ModelID,
            "SEND queueing: " & to_string(TxStim) &
            "  Operation # " &
            to_string(TransmitRequestCount + 1),
            DEBUG,
            Enable => TransRec.BoolToModel
          );

          Increment(TransmitRequestCount);

          ----------------------------------------------------------
          -- Allow updated request count to become visible
          ----------------------------------------------------------
          wait for 0 ns;

          ----------------------------------------------------------
          -- SEND is blocking.
          --
          -- It returns only after the character has been accepted
          -- by the spwstream TX FIFO.
          --
          -- SEND_ASYNC skips this wait.
          ----------------------------------------------------------
          if Operation = SEND then
            if TransmitRequestCount /= TransmitDoneCount then
              wait until
                TransmitRequestCount = TransmitDoneCount;
            end if;
          end if;


        ------------------------------------------------------------
        -- Handle common OSVVM directives:
        --
        -- WaitForClock
        -- GetAlertLogID
        -- GetTransactionCount
        -- GetErrorCount
        -- WaitForTransaction
        -- and related operations
        ------------------------------------------------------------
        when others =>

          DoDirectiveTransactions(
            TransRec                => TransRec,
            Clk                     => Clk,
            ModelID                 => ModelID,
            TransactionDone         => TransactionDone,
            TransactionCount        => TransmitDoneCount,
            PendingTransactionCount =>
              TransmitRequestCount - TransmitDoneCount
          );

      end case;

    end loop TransactionDispatcherLoop;

  end process TransactionDispatcher;


  ------------------------------------------------------------------
  -- True when no transmit operations remain pending
  ------------------------------------------------------------------
  TransactionDone <=
    TransmitRequestCount = TransmitDoneCount;


  ------------------------------------------------------------------
  -- SpaceWire Stream Transmit Handler
  --
  -- Converts queued OSVVM transactions into the synchronous
  -- spwstream transmit handshake.
  ------------------------------------------------------------------
  SpaceWireTransmitHandler : process
    variable TxStim : SpaceWireStimType;
  begin

    ----------------------------------------------------------------
    -- Initialize the spwstream outputs
    ----------------------------------------------------------------
    TxWrite <= '0';
    TxFlag  <= '0';
    TxData  <= (others => '0');

    ----------------------------------------------------------------
    -- Do not begin transmission during reset
    ----------------------------------------------------------------
    wait until nReset = '1';

    TransmitLoop : loop

      --------------------------------------------------------------
      -- Wait until a SEND transaction has queued an item
      --------------------------------------------------------------
      if IsEmpty(TransmitFifo) then
        WaitForToggle(TransmitRequestCount);
      else
        wait for 0 ns;
      end if;

      --------------------------------------------------------------
      -- Remove the oldest item from the transaction FIFO
      --------------------------------------------------------------
      (TxStim.Data, TxStim.Flag) := Pop(TransmitFifo);

      Log(
        ModelID,
        "SEND starting: " & to_string(TxStim) &
        "  Operation # " &
        to_string(TransmitDoneCount + 1),
        DEBUG
      );

      --------------------------------------------------------------
      -- Present the complete character to spwstream
      --
      -- txdata and txflag remain stable while txwrite is high.
      --------------------------------------------------------------
      TxData  <= TxStim.Data;
      TxFlag  <= TxStim.Flag(0);
      TxWrite <= '1';

      --------------------------------------------------------------
      -- Keep TxWrite asserted until spwstream accepts the character.
      --
      -- Acceptance occurs when:
      --
      --   TxWrite = 1
      --   TxReady = 1
      --
      -- on a rising edge of Clk.
      --------------------------------------------------------------
      loop
        wait until rising_edge(Clk);

        exit when TxReady = '1';
      end loop;

      --------------------------------------------------------------
      -- The character was accepted on the previous rising edge.
      --------------------------------------------------------------
      TxWrite <= '0';

      --------------------------------------------------------------
      -- Mark this OSVVM transaction as completed
      --------------------------------------------------------------
      Increment(TransmitDoneCount);

    end loop TransmitLoop;

  end process SpaceWireTransmitHandler;

end architecture model;