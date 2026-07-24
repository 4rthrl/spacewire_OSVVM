library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use std.textio.all;

library osvvm;
  context osvvm.OsvvmContext;


--------------------------------------------------------------------
-- Passive SpaceWire Data/Strobe monitor
--
-- Simulation-only verification component.  It observes one SpaceWire
-- transmit direction, decodes the Data/Strobe stream, writes readable
-- OSVVM logs, and exposes decoded N-Chars to an external scoreboard.
--
-- MonValid/MonFlag/MonData representation:
--
--   MonFlag = '0'                 normal data byte
--   MonFlag = '1', MonData = 00   EOP
--   MonFlag = '1', MonData = 01   EEP
--
-- The monitor does not know the expected packet.  The test sequencer
-- supplies expected N-Chars to an OSVVM scoreboard, while a separate
-- checker process sends MonFlag/MonData to that scoreboard as actual
-- observations.
--------------------------------------------------------------------
entity SpaceWireMonitor is
  generic (
    MONITOR_NAME          : string   := "SpaceWireMonitor";
    MAX_PACKET_BYTES      : positive := 256;
    LOG_DATA_CHARACTERS   : boolean  := false;
    LOG_LINK_CHARACTERS   : boolean  := false;
    CHECK_PARITY          : boolean  := true;
    LOG_PARITY_RESULTS    : boolean  := false;
    LOG_PACKET_SUMMARY    : boolean  := true
  );
  port (
    nReset   : in std_logic;
    DataIn   : in std_logic;
    StrobeIn : in std_logic;

    -- Actual decoded N-Chars for the external scoreboard.
    MonValid : out std_logic;
    MonFlag  : out std_logic;
    MonData  : out std_logic_vector(7 downto 0);

    -- Status signals for the waveform window.
    Synchronized : out std_logic;
    PacketActive : out std_logic
  );
end entity SpaceWireMonitor;


architecture Behavioral of SpaceWireMonitor is

  signal ModelID : AlertLogIDType;

  type SymbolKindType is (
    SYMBOL_UNKNOWN,
    SYMBOL_DATA,
    SYMBOL_FCT,
    SYMBOL_EEP,
    SYMBOL_EOP,
    SYMBOL_ESC
  );

  ------------------------------------------------------------------
  -- Return TRUE only for a resolved binary value.
  ------------------------------------------------------------------
  function IsBinary(Value : std_logic) return boolean is
  begin
    return Value = '0' or Value = '1';
  end function IsBinary;


  ------------------------------------------------------------------
  -- XOR reduction used by the SpaceWire parity calculation.
  ------------------------------------------------------------------
  function XorReduce(Value : std_logic_vector) return std_logic is
    variable Result : std_logic := '0';
  begin
    for Index in Value'range loop
      Result := Result xor Value(Index);
    end loop;
    return Result;
  end function XorReduce;


  ------------------------------------------------------------------
  -- Human-readable name for the previous decoded symbol.
  ------------------------------------------------------------------
  function SymbolToString(
    constant Kind      : SymbolKindType;
    constant DataValue : std_logic_vector(7 downto 0)
  ) return string is
  begin
    case Kind is
      when SYMBOL_DATA =>
        return "DATA 0x" & to_hstring(DataValue);
      when SYMBOL_FCT =>
        return "FCT";
      when SYMBOL_EEP =>
        return "EEP";
      when SYMBOL_EOP =>
        return "EOP";
      when SYMBOL_ESC =>
        return "ESC";
      when others =>
        return "unknown symbol";
    end case;
  end function SymbolToString;

begin

  ------------------------------------------------------------------
  -- Give this monitor its own AlertLog hierarchy entry.
  --
  -- Messages will appear as:
  --   ... in Monitor_A_to_B, ...
  ------------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
    begin
    ID := NewID(MONITOR_NAME);

    --------------------------------------------------------------
    -- Explicitly enable monitor logging on this AlertLog ID.
    --------------------------------------------------------------
    SetLogEnable(ID, INFO, true);

    if LOG_LINK_CHARACTERS then
        SetLogEnable(ID, DEBUG, true);
    end if;

    ModelID <= ID;

  --------------------------------------------------------------
  -- ALWAYS is not filtered. This also shows the actual generic
  -- values used by the instantiated monitor.
  --------------------------------------------------------------
  Log(
    ID,
    "logger initialized" &
    "; LOG_LINK_CHARACTERS=" &
    boolean'image(LOG_LINK_CHARACTERS) &
    "; CHECK_PARITY=" &
    boolean'image(CHECK_PARITY) &
    "; LOG_PARITY_RESULTS=" &
    boolean'image(LOG_PARITY_RESULTS),
    DEBUG
  );

  wait;
end process Initialize;


  ------------------------------------------------------------------
  -- MonitorProc
  --
  -- One valid SpaceWire bit causes exactly one of Data or Strobe to
  -- change. At the transition, the current Data level is the newly
  -- received serial bit.
  --
  -- Before normal decoding, the monitor searches for the complete
  -- first-NULL sequence required by ECSS:
  --
  --   0 111 0 100 0 = 011101000
  ------------------------------------------------------------------
  MonitorProc : process

    constant FIRST_NULL_PATTERN : std_logic_vector(8 downto 0) :=
      "011101000";

    type PacketBufferType is array (
      0 to MAX_PACKET_BYTES - 1
    ) of std_logic_vector(7 downto 0);

    variable PacketBuffer : PacketBufferType :=
      (others => (others => '0'));

    variable PreviousData   : std_logic := '0';
    variable PreviousStrobe : std_logic := '0';
    variable HavePrevious   : boolean   := false;

    variable DataChanged   : boolean;
    variable StrobeChanged : boolean;
    variable ReceivedBit   : std_logic;

    variable IsSynchronized : boolean := false;
    variable SyncShift      : std_logic_vector(8 downto 0) :=
      (others => '0');
    variable SyncBitCount   : natural range 0 to 9 := 0;

    -- BitIndex 0 is parity, bit 1 is the data/control flag,
    -- and the remaining bits are the symbol payload.
    variable BitIndex       : natural range 0 to 9 := 0;
    variable CurrentParity  : std_logic := '0';
    variable CurrentControl : std_logic := '0';
    variable DataValue      : std_logic_vector(7 downto 0) :=
      (others => '0');
    variable ControlValue   : std_logic_vector(1 downto 0) :=
      (others => '0');

    -- SpaceWire parity for the previous symbol is checked when the
    -- parity and data/control bits of the current symbol arrive.
    variable PreviousPayloadXor : std_logic := '0';
    variable PreviousSymbolKind : SymbolKindType := SYMBOL_UNKNOWN;
    variable PreviousSymbolData : std_logic_vector(7 downto 0) :=
      (others => '0');

    variable ParityOkay       : boolean := true;
    variable ParityCheckCount : natural := 0;
    variable ParityErrorCount : natural := 0;

    variable EscapePending : boolean := false;
    variable InPacket      : boolean := false;
    variable PacketLength  : natural := 0;
    variable PacketCount   : natural := 0;
    variable NullCount     : natural := 0;
    variable FctCount      : natural := 0;

    -- Snapshot counters at packet start so the packet summary can
    -- report the parity result for its data characters.
    variable PacketParityStartChecks : natural := 0;
    variable PacketParityStartErrors : natural := 0;


    --------------------------------------------------------------
    -- Emit one decoded N-Char to the external checker process.
    --------------------------------------------------------------
    procedure EmitNChar(
      constant FlagValue : in std_logic;
      constant DataByte  : in std_logic_vector(7 downto 0)
    ) is
    begin
      MonFlag  <= FlagValue;
      MonData  <= DataByte;
      MonValid <= '1';
    end procedure EmitNChar;


    --------------------------------------------------------------
    -- Print one complete packet on a readable line.
    --
    -- Example:
    --   PACKET 2 DATA=00 11 22 33 END=EEP LENGTH=4
    --   PAYLOAD_PARITY=OK
    --------------------------------------------------------------
    procedure LogPacketSummary(
      constant Ending : in string
    ) is
      variable PacketLine       : line;
      variable BytesToPrint     : natural;
      variable PacketChecks     : natural;
      variable PacketErrors     : natural;
    begin
      if not LOG_PACKET_SUMMARY then
        return;
      end if;

      if PacketLength < MAX_PACKET_BYTES then
        BytesToPrint := PacketLength;
      else
        BytesToPrint := MAX_PACKET_BYTES;
      end if;

      write(
        PacketLine,
        "PACKET " &
        integer'image(PacketCount) &
        " DATA=["
        );

      if BytesToPrint = 0 then
        write(PacketLine, string'("<empty>"));
      else
        for Index in 0 to BytesToPrint - 1 loop
          write(PacketLine, to_hstring(PacketBuffer(Index)));

          if Index < BytesToPrint - 1 then
            write(PacketLine, string'(" "));
          end if;
        end loop;
      end if;

      if PacketLength > MAX_PACKET_BYTES then
        write(PacketLine, string'(" ..."));
      end if;

      write(
        PacketLine,
        string'(
            "] END=" & Ending &
            " LEN=" & integer'image(PacketLength)
        )
    );

      if CHECK_PARITY then
        PacketChecks :=
          ParityCheckCount - PacketParityStartChecks;

        PacketErrors :=
          ParityErrorCount - PacketParityStartErrors;

        if PacketErrors = 0 then
            write(
                PacketLine,
                string'(" PARITY=OK")
            );
        else
            write(
                PacketLine,
                string'(
                " PARITY=FAILED" &
                " ERRORS=" & integer'image(PacketErrors)
                )
            );
        end if;
      else
        write(PacketLine, string'(" PAYLOAD_PARITY=NOT_CHECKED"));
      end if;

      Log(ModelID, PacketLine.all, INFO);
      deallocate(PacketLine);
    end procedure LogPacketSummary;


    --------------------------------------------------------------
    -- Reset all decoder and reporting state.
    --------------------------------------------------------------
    procedure ResetDecoder is
    begin
      IsSynchronized       := false;
      SyncShift            := (others => '0');
      SyncBitCount         := 0;
      BitIndex             := 0;
      CurrentParity        := '0';
      CurrentControl       := '0';
      DataValue            := (others => '0');
      ControlValue         := (others => '0');
      PreviousPayloadXor   := '0';
      PreviousSymbolKind   := SYMBOL_UNKNOWN;
      PreviousSymbolData   := (others => '0');
      ParityCheckCount     := 0;
      ParityErrorCount     := 0;
      PacketParityStartChecks := 0;
      PacketParityStartErrors := 0;
      EscapePending        := false;
      InPacket             := false;
      PacketLength         := 0;
      PacketCount          := 0;
      NullCount            := 0;
      FctCount             := 0;
      PacketBuffer         := (others => (others => '0'));

      Synchronized <= '0';
      PacketActive <= '0';
      MonValid      <= '0';
      MonFlag       <= '0';
      MonData       <= (others => '0');
    end procedure ResetDecoder;

  begin

    ResetDecoder;

    loop
      wait on nReset, DataIn, StrobeIn;

      -- MonValid is an event pulse.  MonFlag and MonData retain the
      -- most recently decoded value between pulses.
      MonValid <= '0';

      if nReset = '0' then
        ResetDecoder;
        HavePrevious := false;

      elsif IsBinary(DataIn) and IsBinary(StrobeIn) then

        -- On reset release, remember the current line levels.  They
        -- are not themselves a received bit.
        if not HavePrevious then
          PreviousData   := DataIn;
          PreviousStrobe := StrobeIn;
          HavePrevious   := true;

        else
          DataChanged   := DataIn /= PreviousData;
          StrobeChanged := StrobeIn /= PreviousStrobe;

          PreviousData   := DataIn;
          PreviousStrobe := StrobeIn;

          if DataChanged or StrobeChanged then

            ------------------------------------------------------
            -- A valid SpaceWire bit changes Data or Strobe, not
            -- both in the same simulation event.
            ------------------------------------------------------
            if DataChanged and StrobeChanged then
              Alert(
                ModelID,
                "Data and Strobe changed simultaneously; " &
                "decoder synchronization lost",
                WARNING
              );

              IsSynchronized     := false;
              Synchronized       <= '0';
              SyncShift          := (others => '0');
              SyncBitCount       := 0;
              BitIndex           := 0;
              EscapePending      := false;
              PreviousSymbolKind := SYMBOL_UNKNOWN;

            else
              ReceivedBit := DataIn;

              ----------------------------------------------------
              -- Search for the standard first-NULL sequence.
              ----------------------------------------------------
              if not IsSynchronized then
                SyncShift := SyncShift(7 downto 0) & ReceivedBit;

                if SyncBitCount < 9 then
                  SyncBitCount := SyncBitCount + 1;
                end if;

                if SyncBitCount = 9 and
                   SyncShift = FIRST_NULL_PATTERN then

                  IsSynchronized := true;
                  Synchronized   <= '1';

                  -- The ninth bit is the parity bit belonging to
                  -- the character following the first NULL.
                  CurrentParity := ReceivedBit;
                  BitIndex      := 1;

                  EscapePending := false;
                  NullCount     := 1;

                  -- The final complete character in the first NULL
                  -- is FCT, with payload bits "00".
                  PreviousPayloadXor := '0';
                  PreviousSymbolKind := SYMBOL_FCT;
                  PreviousSymbolData := (others => '0');

                  Log(
                    ModelID,
                    "FIRST NULL detected; decoder synchronized",
                    INFO
                  );
                end if;

              ----------------------------------------------------
              -- Normal decoding after synchronization.
              ----------------------------------------------------
              else
                case BitIndex is

                  ------------------------------------------------
                  -- Parity bit of the current symbol.
                  ------------------------------------------------
                  when 0 =>
                    CurrentParity := ReceivedBit;
                    BitIndex      := 1;

                  ------------------------------------------------
                  -- Data/control bit.  It completes the parity
                  -- information for the previous symbol.
                  ------------------------------------------------
                  when 1 =>
                    CurrentControl := ReceivedBit;

                    if CHECK_PARITY then
                        ParityOkay :=
                            (PreviousPayloadXor xor
                            CurrentParity xor
                            ReceivedBit) = '1';

                        if InPacket and
                            PreviousSymbolKind = SYMBOL_DATA then

                            PacketDataParityChecks :=
                            PacketDataParityChecks + 1;

                            if not ParityOkay then
                            PacketDataParityErrors :=
                                PacketDataParityErrors + 1;
                            end if;
                        end if;

                        if not ParityOkay then
                            ParityErrorCount := ParityErrorCount + 1;

                            Alert(
                            ModelID,
                            "PARITY ERROR for " &
                            SymbolToString(
                                PreviousSymbolKind,
                                PreviousSymbolData
                            ),
                            ERROR
                            );

                        elsif LOG_PARITY_RESULTS then
                            Log(
                            ModelID,
                            "PARITY OK for " &
                            SymbolToString(
                                PreviousSymbolKind,
                                PreviousSymbolData
                            ),
                            INFO
                            );
                        end if;
                    end if;

                    BitIndex := 2;

                  ------------------------------------------------
                  -- Data or control payload.
                  ------------------------------------------------
                  when others =>

                    if CurrentControl = '0' then
                      --------------------------------------------
                      -- Data character: eight bits, LSB first.
                      --------------------------------------------
                      DataValue(BitIndex - 2) := ReceivedBit;

                      if BitIndex = 9 then
                        PreviousPayloadXor := XorReduce(DataValue);
                        PreviousSymbolKind := SYMBOL_DATA;
                        PreviousSymbolData := DataValue;
                        BitIndex           := 0;

                        if EscapePending then
                          ----------------------------------------
                          -- ESC + DATA = broadcast code.
                          ----------------------------------------
                          Log(
                            ModelID,
                            "BROADCAST code 0x" &
                            to_hstring(DataValue) &
                            " TYPE=" &
                            integer'image(
                              to_integer(
                                unsigned(DataValue(7 downto 6))
                              )
                            ) &
                            " VALUE=" &
                            integer'image(
                              to_integer(
                                unsigned(DataValue(5 downto 0))
                              )
                            ),
                            INFO
                          );

                          EscapePending := false;

                        else
                          ----------------------------------------
                          -- Normal packet data.
                          ----------------------------------------
                          if not InPacket then
                            InPacket     := true;
                            PacketLength := 0;
                            PacketActive <= '1';

                            PacketParityStartChecks :=
                              ParityCheckCount;

                            PacketParityStartErrors :=
                              ParityErrorCount;

                            Log(
                              ModelID,
                              "PACKET " &
                              integer'image(PacketCount + 1) &
                              " START",
                              DEBUG
                            );
                          end if;

                          if PacketLength < MAX_PACKET_BYTES then
                            PacketBuffer(PacketLength) := DataValue;
                          elsif PacketLength = MAX_PACKET_BYTES then
                            Alert(
                              ModelID,
                              "packet log buffer is full; " &
                              "remaining bytes will not be printed",
                              WARNING
                            );
                          end if;

                          if LOG_DATA_CHARACTERS then
                            Log(
                              ModelID,
                              "DATA[" &
                              integer'image(PacketLength) &
                              "] = 0x" &
                              to_hstring(DataValue),
                              INFO
                            );
                          end if;

                          PacketLength := PacketLength + 1;
                          EmitNChar('0', DataValue);
                        end if;

                      else
                        BitIndex := BitIndex + 1;
                      end if;

                    else
                      --------------------------------------------
                      -- Control character: two bits, LSB first.
                      --------------------------------------------
                      ControlValue(BitIndex - 2) := ReceivedBit;

                      if BitIndex = 3 then
                        PreviousPayloadXor :=
                          ControlValue(0) xor ControlValue(1);

                        BitIndex := 0;

                        case ControlValue is

                          ----------------------------------------
                          -- FCT = "00"; ESC + FCT = NULL.
                          ----------------------------------------
                          when "00" =>
                            PreviousSymbolKind := SYMBOL_FCT;
                            PreviousSymbolData := (others => '0');

                            if EscapePending then
                              NullCount := NullCount + 1;

                              if LOG_LINK_CHARACTERS then
                                Log(
                                  ModelID,
                                  "NULL detected; count=" &
                                  integer'image(NullCount),
                                  INFO
                                );
                              end if;

                              EscapePending := false;

                            else
                              FctCount := FctCount + 1;

                              if LOG_LINK_CHARACTERS then
                                Log(
                                  ModelID,
                                  "FCT detected; count=" &
                                  integer'image(FctCount),
                                  INFO
                                );
                              end if;
                            end if;

                          ----------------------------------------
                          -- EEP = "01".
                          ----------------------------------------
                          when "01" =>
                            PreviousSymbolKind := SYMBOL_EEP;
                            PreviousSymbolData := x"01";

                            if EscapePending then
                              Alert(
                                ModelID,
                                "invalid ESC + EEP sequence",
                                ERROR
                              );
                              EscapePending := false;

                            else
                              PacketCount := PacketCount + 1;

                              Log(
                                ModelID,
                                "EEP detected; PACKET " &
                                integer'image(PacketCount) &
                                " END",
                                DEBUG
                              );

                              LogPacketSummary("EEP");

                              EmitNChar('1', x"01");
                              InPacket     := false;
                              PacketLength := 0;
                              PacketActive <= '0';
                            end if;

                          ----------------------------------------
                          -- EOP = "10".
                          ----------------------------------------
                          when "10" =>
                            PreviousSymbolKind := SYMBOL_EOP;
                            PreviousSymbolData := x"00";

                            if EscapePending then
                              Alert(
                                ModelID,
                                "invalid ESC + EOP sequence",
                                ERROR
                              );
                              EscapePending := false;

                            else
                              PacketCount := PacketCount + 1;

                              Log(
                                ModelID,
                                "EOP detected; PACKET " &
                                integer'image(PacketCount) &
                                " END",
                                DEBUG
                              );

                              LogPacketSummary("EOP");

                              EmitNChar('1', x"00");
                              InPacket     := false;
                              PacketLength := 0;
                              PacketActive <= '0';
                            end if;

                          ----------------------------------------
                          -- ESC = "11".
                          ----------------------------------------
                          when "11" =>
                            PreviousSymbolKind := SYMBOL_ESC;
                            PreviousSymbolData := (others => '0');

                            if EscapePending then
                              Alert(
                                ModelID,
                                "invalid ESC + ESC sequence",
                                ERROR
                              );
                              EscapePending := false;

                            else
                              EscapePending := true;

                              if LOG_LINK_CHARACTERS then
                                Log(
                                  ModelID,
                                  "ESC detected",
                                  INFO
                                );
                              end if;
                            end if;

                          when others =>
                            null;

                        end case;

                      else
                        BitIndex := BitIndex + 1;
                      end if;
                    end if;

                end case;
              end if;
            end if;
          end if;
        end if;

      else
        -- Wait until both line inputs have resolved binary values.
        HavePrevious := false;
      end if;
    end loop;

  end process MonitorProc;

end architecture Behavioral;
