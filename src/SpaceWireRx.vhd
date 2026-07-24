library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;
  use osvvm.ScoreboardPkg_slv.all;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

use work.SpaceWireTbPkg.all;


entity SpaceWireRx is
  generic (
    MODEL_ID_NAME : string := ""
  );
  port (
    ------------------------------------------------------------
    -- OSVVM transaction interface
    ------------------------------------------------------------
    TransRec : inout SpaceWireRecType;

    ------------------------------------------------------------
    -- Testbench clock and reset
    ------------------------------------------------------------
    Clk    : in std_logic;
    nReset : in std_logic;

    ------------------------------------------------------------
    -- SpaceWire Light spwstream receive interface
    ------------------------------------------------------------
    RxValid : in  std_logic;
    RxRead  : out std_logic := '0';
    RxFlag  : in  std_logic;
    RxData  : in  std_logic_vector(7 downto 0)
  );

  ------------------------------------------------------------
  -- Use the generic model name when one is supplied.
  -- Otherwise, derive the name from the instance label.
  ------------------------------------------------------------
  constant MODEL_INSTANCE_NAME : string :=
    IfElse(
      MODEL_ID_NAME'length > 0,
      MODEL_ID_NAME,
      to_lower(PathTail(SpaceWireRx'PATH_NAME))
    );

end entity SpaceWireRx;


architecture model of SpaceWireRx is

  ------------------------------------------------------------
  -- OSVVM logging and alert identity
  ------------------------------------------------------------
  signal ModelID : AlertLogIDType;

  ------------------------------------------------------------
  -- Internal queue of received SpaceWire characters
  --
  -- Each entry contains:
  --     Data(7 downto 0) & Flag(0)
  ------------------------------------------------------------
  signal ReceiveFifo :
    osvvm.ScoreboardPkg_slv.ScoreboardIDType;

  ------------------------------------------------------------
  -- Number of characters accepted from spwstream
  ------------------------------------------------------------
  signal ReceiveCount : integer := 0;

  ------------------------------------------------------------
  -- Required by DoDirectiveTransactions.
  --
  -- GET and CHECK transactions are handled directly in this
  -- model, so this signal is not used for their completion.
  ------------------------------------------------------------
  signal TransactionDone : boolean := FALSE;

begin

  ------------------------------------------------------------
  -- Initialize the OSVVM model and its private receive FIFO
  ------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
  begin
    ID := NewID(MODEL_INSTANCE_NAME);

    SetLogEnable(
      ID,
      PASSED,
      false
    );

    ModelID <= ID;

    ReceiveFifo <= NewID(
      Name       => "ReceiveFifo",
      ParentID   => ID,
      ReportMode => DISABLED,
      Search     => PRIVATE_NAME
    );

    wait;
  end process Initialize;


  ------------------------------------------------------------
  -- Always accept characters while the model is not in reset.
  --
  -- A character is accepted on a rising clock edge when:
  --
  --     RxValid = '1'
  --     RxRead  = '1'
  ------------------------------------------------------------
  RxRead <= nReset;


  ------------------------------------------------------------
  -- SpaceWire receive handler
  --
  -- Watches the spwstream receive interface and stores every
  -- accepted character in the OSVVM receive FIFO.
  ------------------------------------------------------------
  SpaceWireReceiveHandler : process
    variable RxStim : SpaceWireStimType;
  begin

    ReceiveLoop : loop

      wait until rising_edge(Clk);

      ----------------------------------------------------------
      -- RxRead is high while nReset is high.
      --
      -- Therefore, when RxValid is also high at this edge,
      -- the character is accepted and removed from the
      -- spwstream receive FIFO.
      ----------------------------------------------------------
      if nReset = '1' and RxValid = '1' then

        RxStim.Data    := RxData;
        RxStim.Flag(0) := to_01(RxFlag);

        --------------------------------------------------------
        -- Store the complete item for a future GET or CHECK
        --------------------------------------------------------
        Push(
          ReceiveFifo,
          RxStim.Data & RxStim.Flag
        );

        --------------------------------------------------------
        -- Count physically received characters
        --------------------------------------------------------
        Increment(ReceiveCount);

        Log(
          ModelID,
          "Received: " & to_string(RxStim) &
          "  Operation # " & to_string(ReceiveCount + 1),
          DEBUG
        );

      end if;

    end loop ReceiveLoop;

  end process SpaceWireReceiveHandler;


  ------------------------------------------------------------
  -- OSVVM transaction dispatcher
  --
  -- Processes requests from the test sequencer:
  --
  -- GET       Return the next received character
  -- TRY_GET   Return immediately if none is available
  -- CHECK     Compare the next character with an expected value
  -- TRY_CHECK Check only when a character is available
  ------------------------------------------------------------
  TransactionDispatcher : process
    alias Operation : StreamOperationType is TransRec.Operation;

    variable RxStim       : SpaceWireStimType;
    variable ExpectedStim : SpaceWireStimType;
  begin

    ------------------------------------------------------------
    -- Allow the Initialize process to update ModelID
    ------------------------------------------------------------
    wait for 0 ns;

    ------------------------------------------------------------
    -- The common stream record contains a BurstFifo field.
    -- It is not used by this first model, but initialize it
    -- because common stream procedures expect a valid ID.
    ------------------------------------------------------------
    TransRec.BurstFifo <= NewID(
      Name       => "RxBurstFifo",
      ParentID   => ModelID,
      ReportMode => DISABLED,
      Search     => PRIVATE_NAME
    );

    wait for 0 ns;

    TransactionDispatcherLoop : loop

      ----------------------------------------------------------
      -- Wait for a request from the OSVVM test sequencer
      ----------------------------------------------------------
      WaitForTransaction(
        Clk => Clk,
        Rdy => TransRec.Rdy,
        Ack => TransRec.Ack
      );

      case Operation is

        --------------------------------------------------------
        -- Receive or check one SpaceWire character
        --------------------------------------------------------
        when GET | TRY_GET | CHECK | TRY_CHECK =>

          ------------------------------------------------------
          -- TRY_GET and TRY_CHECK do not wait when the FIFO
          -- is empty.
          ------------------------------------------------------
          if IsEmpty(ReceiveFifo) and IsTry(Operation) then

            TransRec.BoolFromModel <= FALSE;

          else

            TransRec.BoolFromModel <= TRUE;

            ----------------------------------------------------
            -- Normal GET and CHECK wait until data arrives.
            ----------------------------------------------------
            if IsEmpty(ReceiveFifo) then

              WaitForToggle(ReceiveCount);

            else

              --------------------------------------------------
              -- Allow ReceiveCount and FIFO state to settle
              --------------------------------------------------
              wait for 0 ns;

            end if;

            ----------------------------------------------------
            -- Remove the oldest received character
            ----------------------------------------------------
            (RxStim.Data, RxStim.Flag) :=
              Pop(ReceiveFifo);

            ----------------------------------------------------
            -- Return the received item through TransRec
            ----------------------------------------------------
            TransRec.DataFromModel <= SafeResize(
              ModelID,
              RxStim.Data,
              TransRec.DataFromModel'length
            );

            TransRec.ParamFromModel <= SafeResize(
              ModelID,
              RxStim.Flag,
              TransRec.ParamFromModel'length
            );

            ----------------------------------------------------
            -- CHECK and TRY_CHECK compare against expected
            -- data supplied through DataToModel/ParamToModel.
            ----------------------------------------------------
            if IsCheck(Operation) then

              ExpectedStim.Data := SafeResize(
                ModelID,
                TransRec.DataToModel,
                ExpectedStim.Data'length
              );

              ExpectedStim.Flag := SafeResize(
                ModelID,
                TransRec.ParamToModel,
                ExpectedStim.Flag'length
              );

              ExpectedStim.Flag(0) :=
                to_01(ExpectedStim.Flag(0));

              if Match(RxStim, ExpectedStim) then

                AffirmPassed(
                  ModelID,
                  "Received: " & to_string(RxStim) &
                  ". Operation # " & to_string(ReceiveCount),
                  Enable => TransRec.BoolToModel
                );

              else

                AffirmError(
                  ModelID,
                  "Received: " & to_string(RxStim) &
                  ". Expected: " & to_string(ExpectedStim) &
                  ". Operation # " & to_string(ReceiveCount)
                );

              end if;

            else

              --------------------------------------------------
              -- GET returns the item without comparing it
              --------------------------------------------------
              Log(
                ModelID,
                "GET returning: " & to_string(RxStim) &
                ". Operation # " & to_string(ReceiveCount),
                DEBUG,
                Enable => TransRec.BoolToModel
              );

            end if;

          end if;


        --------------------------------------------------------
        -- Wait until at least one received item is available
        --------------------------------------------------------
        when WAIT_FOR_TRANSACTION =>

          if IsEmpty(ReceiveFifo) then
            WaitForToggle(ReceiveCount);
          end if;


        --------------------------------------------------------
        -- Common OSVVM directive transactions:
        --
        -- WaitForClock
        -- GetAlertLogID
        -- GetTransactionCount
        -- GetErrorCount
        -- GetPendingTransactionCount
        -- and related operations
        --------------------------------------------------------
        when others =>

          DoDirectiveTransactions(
            TransRec                => TransRec,
            Clk                     => Clk,
            ModelID                 => ModelID,
            TransactionDone         => TransactionDone,
            TransactionCount        => ReceiveCount,
            PendingTransactionCount =>
              GetFifoCount(ReceiveFifo)
          );

      end case;

    end loop TransactionDispatcherLoop;

  end process TransactionDispatcher;

end architecture model;