library ieee;
  use ieee.std_logic_1164.all;


--------------------------------------------------------------------
-- Direct SpaceWire Data/Strobe driver package
--
-- Simulation-only verification component.
--
-- This package directly drives the physical SpaceWire Data and
-- Strobe signals. It is intended for unit testing SpaceWireMonitor
-- without using the SpaceWire Light spwstream transmitter.
--
-- A valid SpaceWire bit transition changes exactly one signal:
--
--   - Data changes when the new bit differs from the current Data.
--   - Strobe changes when the new bit equals the current Data.
--
-- At every transition, the current Data level represents the
-- transmitted serial bit.
--------------------------------------------------------------------
package SpaceWireDsDriverPkg is

  ------------------------------------------------------------------
  -- SpaceWire control-character payloads.
  ------------------------------------------------------------------
  constant SPW_CONTROL_FCT : std_logic_vector(1 downto 0) := "00";
  constant SPW_CONTROL_EEP : std_logic_vector(1 downto 0) := "01";
  constant SPW_CONTROL_EOP : std_logic_vector(1 downto 0) := "10";
  constant SPW_CONTROL_ESC : std_logic_vector(1 downto 0) := "11";


  ------------------------------------------------------------------
  -- Driver state
  --
  -- SpaceWire parity for one character is completed by the parity
  -- and data/control bits of the following character.
  ------------------------------------------------------------------
  type SpaceWireDsDriverStateType is record
    PreviousPayloadXor : std_logic;
    ParityAlreadySent  : boolean;
  end record SpaceWireDsDriverStateType;


  constant SPACEWIRE_DS_DRIVER_STATE_INIT :
    SpaceWireDsDriverStateType := (
      PreviousPayloadXor => '0',
      ParityAlreadySent  => false
    );


  ------------------------------------------------------------------
  -- Reset the internal driver state.
  ------------------------------------------------------------------
  procedure ResetDriver(
    variable State : out SpaceWireDsDriverStateType
  );


  ------------------------------------------------------------------
  -- Send one Data/Strobe encoded bit.
  ------------------------------------------------------------------
  procedure SendBit(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    constant BitValue     : in std_logic;
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Send the standard first-NULL synchronization sequence:
  --
  --   0 111 0 100 0 = 011101000
  --
  -- The final bit is already the parity bit of the following
  -- control character. The next transmitted character must
  -- therefore be a control character, normally the ESC at the
  -- beginning of another NULL.
  ------------------------------------------------------------------
  procedure SendFirstNull(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Send one normal SpaceWire data character.
  ------------------------------------------------------------------
  procedure SendDataCharacter(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant DataByte     : in std_logic_vector(7 downto 0);
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Send one SpaceWire control character.
  ------------------------------------------------------------------
  procedure SendControlCharacter(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant ControlCode  : in std_logic_vector(1 downto 0);
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Convenience procedures for individual control characters.
  ------------------------------------------------------------------
  procedure SendFct(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  procedure SendEep(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  procedure SendEop(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  procedure SendEsc(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Send NULL = ESC + FCT.
  ------------------------------------------------------------------
  procedure SendNull(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  );


  ------------------------------------------------------------------
  -- Send broadcast/time-code = ESC + DATA.
  ------------------------------------------------------------------
  procedure SendBroadcast(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BroadcastByte : in std_logic_vector(7 downto 0);
    constant BitPeriod     : in time := 100 ns
  );

end package SpaceWireDsDriverPkg;


package body SpaceWireDsDriverPkg is

  ------------------------------------------------------------------
  -- Return TRUE only for a resolved binary value.
  ------------------------------------------------------------------
  function IsBinary(
    constant Value : std_logic
  ) return boolean is
  begin
    return Value = '0' or Value = '1';
  end function IsBinary;


  ------------------------------------------------------------------
  -- XOR reduction used for SpaceWire parity generation.
  ------------------------------------------------------------------
  function XorReduce(
    constant Value : std_logic_vector
  ) return std_logic is
    variable Result : std_logic := '0';
  begin
    for Index in Value'range loop
      Result := Result xor Value(Index);
    end loop;

    return Result;
  end function XorReduce;


  ------------------------------------------------------------------
  -- Reset the internal driver state.
  ------------------------------------------------------------------
  procedure ResetDriver(
    variable State : out SpaceWireDsDriverStateType
  ) is
  begin
    State := SPACEWIRE_DS_DRIVER_STATE_INIT;
  end procedure ResetDriver;


  ------------------------------------------------------------------
  -- Send one Data/Strobe encoded bit.
  ------------------------------------------------------------------
  procedure SendBit(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    constant BitValue     : in std_logic;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    assert IsBinary(DataLine)
      report
        "SpaceWireDsDriverPkg: DataLine is not binary"
      severity failure;

    assert IsBinary(StrobeLine)
      report
        "SpaceWireDsDriverPkg: StrobeLine is not binary"
      severity failure;

    assert IsBinary(BitValue)
      report
        "SpaceWireDsDriverPkg: BitValue is not binary"
      severity failure;

    --------------------------------------------------------------
    -- Exactly one physical line changes for every transmitted bit.
    --------------------------------------------------------------
    if DataLine /= BitValue then
      DataLine <= BitValue;
    else
      StrobeLine <= not StrobeLine;
    end if;

    wait for BitPeriod;
  end procedure SendBit;


  ------------------------------------------------------------------
  -- Send the first-NULL synchronization sequence.
  ------------------------------------------------------------------
  procedure SendFirstNull(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod : in time := 100 ns
  ) is
    constant FirstNullPattern :
      std_logic_vector(8 downto 0) := "011101000";
  begin
    assert not State.ParityAlreadySent
      report
        "SpaceWireDsDriverPkg: first NULL started while a parity " &
        "bit was already pending"
      severity failure;

    --------------------------------------------------------------
    -- Send the pattern from left to right.
    --------------------------------------------------------------
    for Index in FirstNullPattern'range loop
      SendBit(
        DataLine,
        StrobeLine,
        FirstNullPattern(Index),
        BitPeriod
      );
    end loop;

    --------------------------------------------------------------
    -- The completed symbol before the final bit is FCT.
    -- The final zero is the parity bit of the next control
    -- character.
    --------------------------------------------------------------
    State.PreviousPayloadXor := '0';
    State.ParityAlreadySent  := true;
  end procedure SendFirstNull;


  ------------------------------------------------------------------
  -- Send one normal SpaceWire data character.
  ------------------------------------------------------------------
  procedure SendDataCharacter(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant DataByte     : in std_logic_vector(7 downto 0);
    constant BitPeriod : in time := 100 ns
  ) is
    variable ParityBit : std_logic;
  begin
    --------------------------------------------------------------
    -- The fixed final bit in the first-NULL sequence is intended
    -- for a following control character, not a data character.
    --------------------------------------------------------------
    assert not State.ParityAlreadySent
      report
        "SpaceWireDsDriverPkg: a data character cannot directly " &
        "follow SendFirstNull; send a control character or NULL first"
      severity failure;

    --------------------------------------------------------------
    -- Odd parity:
    --
    -- PreviousPayloadXor xor ParityBit xor DataControlBit = '1'
    --
    -- DataControlBit is zero for a data character.
    --------------------------------------------------------------
    ParityBit :=
      not (
        State.PreviousPayloadXor xor
        '0'
      );

    SendBit(
      DataLine,
      StrobeLine,
      ParityBit,
      BitPeriod
    );

    --------------------------------------------------------------
    -- Data/control flag: zero means DATA.
    --------------------------------------------------------------
    SendBit(
      DataLine,
      StrobeLine,
      '0',
      BitPeriod
    );

    --------------------------------------------------------------
    -- SpaceWire data bits are transmitted least-significant bit
    -- first.
    --------------------------------------------------------------
    for Index in 0 to 7 loop
      SendBit(
        DataLine,
        StrobeLine,
        DataByte(Index),
        BitPeriod
      );
    end loop;

    State.PreviousPayloadXor := XorReduce(DataByte);
  end procedure SendDataCharacter;


  ------------------------------------------------------------------
  -- Send one SpaceWire control character.
  ------------------------------------------------------------------
  procedure SendControlCharacter(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant ControlCode  : in std_logic_vector(1 downto 0);
    constant BitPeriod    : in time := 100 ns
  ) is
    variable ParityBit : std_logic;
  begin
    --------------------------------------------------------------
    -- Send a new parity bit unless SendFirstNull already supplied
    -- the parity bit for this control character.
    --------------------------------------------------------------
    if State.ParityAlreadySent then
      State.ParityAlreadySent := false;

    else
      ------------------------------------------------------------
      -- Odd parity:
      --
      -- PreviousPayloadXor xor ParityBit xor DataControlBit = '1'
      --
      -- DataControlBit is one for a control character.
      ------------------------------------------------------------
      ParityBit :=
        not (
          State.PreviousPayloadXor xor
          '1'
        );

      SendBit(
        DataLine,
        StrobeLine,
        ParityBit,
        BitPeriod
      );
    end if;

    --------------------------------------------------------------
    -- Data/control flag: one means CONTROL.
    --------------------------------------------------------------
    SendBit(
      DataLine,
      StrobeLine,
      '1',
      BitPeriod
    );

    --------------------------------------------------------------
    -- Control payload bits are transmitted least-significant bit
    -- first.
    --------------------------------------------------------------
    SendBit(
      DataLine,
      StrobeLine,
      ControlCode(0),
      BitPeriod
    );

    SendBit(
      DataLine,
      StrobeLine,
      ControlCode(1),
      BitPeriod
    );

    State.PreviousPayloadXor :=
      ControlCode(0) xor ControlCode(1);
  end procedure SendControlCharacter;


  ------------------------------------------------------------------
  -- Send FCT.
  ------------------------------------------------------------------
  procedure SendFct(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    SendControlCharacter(
      DataLine,
      StrobeLine,
      State,
      SPW_CONTROL_FCT,
      BitPeriod
    );
  end procedure SendFct;


  ------------------------------------------------------------------
  -- Send EEP.
  ------------------------------------------------------------------
  procedure SendEep(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    SendControlCharacter(
      DataLine,
      StrobeLine,
      State,
      SPW_CONTROL_EEP,
      BitPeriod
    );
  end procedure SendEep;


  ------------------------------------------------------------------
  -- Send EOP.
  ------------------------------------------------------------------
  procedure SendEop(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    SendControlCharacter(
      DataLine,
      StrobeLine,
      State,
      SPW_CONTROL_EOP,
      BitPeriod
    );
  end procedure SendEop;


  ------------------------------------------------------------------
  -- Send ESC.
  ------------------------------------------------------------------
  procedure SendEsc(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    SendControlCharacter(
      DataLine,
      StrobeLine,
      State,
      SPW_CONTROL_ESC,
      BitPeriod
    );
  end procedure SendEsc;


  ------------------------------------------------------------------
  -- Send NULL = ESC + FCT.
  ------------------------------------------------------------------
  procedure SendNull(
    signal DataLine       : inout std_logic;
    signal StrobeLine     : inout std_logic;
    variable State        : inout SpaceWireDsDriverStateType;
    constant BitPeriod    : in time := 100 ns
  ) is
  begin
    SendEsc(
      DataLine,
      StrobeLine,
      State,
      BitPeriod
    );

    SendFct(
      DataLine,
      StrobeLine,
      State,
      BitPeriod
    );
  end procedure SendNull;


  ------------------------------------------------------------------
  -- Send broadcast/time-code = ESC + DATA.
  ------------------------------------------------------------------
  procedure SendBroadcast(
    signal DataLine        : inout std_logic;
    signal StrobeLine      : inout std_logic;
    variable State         : inout SpaceWireDsDriverStateType;
    constant BroadcastByte : in std_logic_vector(7 downto 0);
    constant BitPeriod     : in time := 100 ns
  ) is
  begin
    SendEsc(
      DataLine,
      StrobeLine,
      State,
      BitPeriod
    );

    SendDataCharacter(
      DataLine,
      StrobeLine,
      State,
      BroadcastByte,
      BitPeriod
    );
  end procedure SendBroadcast;

end package body SpaceWireDsDriverPkg;