library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

package SpaceWireTbPkg is

  ------------------------------------------------------------------
  -- One SpaceWire stream item
  ------------------------------------------------------------------
  subtype SpaceWireTb_DataType is
    std_logic_vector(7 downto 0);

  subtype SpaceWireTb_FlagType is
    std_logic_vector(0 downto 0);

  constant SPW_DATA_FLAG    : SpaceWireTb_FlagType := "0";
  constant SPW_CONTROL_FLAG : SpaceWireTb_FlagType := "1";

  constant SPW_EOP_DATA : SpaceWireTb_DataType := x"00";
  constant SPW_EEP_DATA : SpaceWireTb_DataType := x"01";

  ------------------------------------------------------------------
  -- OSVVM transaction record
  ------------------------------------------------------------------
  subtype SpaceWireRecType is StreamRecType (
    DataToModel    (SpaceWireTb_DataType'range),
    ParamToModel   (SpaceWireTb_FlagType'range),
    DataFromModel  (SpaceWireTb_DataType'range),
    ParamFromModel (SpaceWireTb_FlagType'range)
  );

  ------------------------------------------------------------------
  -- Local representation of one SpaceWire item
  ------------------------------------------------------------------
  type SpaceWireStimType is record
    Data : SpaceWireTb_DataType;
    Flag : SpaceWireTb_FlagType;
  end record;

  ------------------------------------------------------------------
  -- packet type for a SpaceWire packet
  ------------------------------------------------------------------
  type SpaceWirePacketType is array (natural range <>) of
  std_logic_vector(7 downto 0);

  type SpaceWirePacketEndType is (
  PACKET_EOP,
  PACKET_EEP
  );

  ------------------------------------------------------------------
  -- Printing and comparing
  ------------------------------------------------------------------
  function to_string (
    constant Item : in SpaceWireStimType
  ) return string;

  function Match (
    constant Actual   : in SpaceWireStimType;
    constant Expected : in SpaceWireStimType
  ) return boolean;

  ------------------------------------------------------------------
  -- Convenient SpaceWire transactions
  ------------------------------------------------------------------
  procedure SendData (
    signal   TransactionRec : inout SpaceWireRecType;
    constant Data           : in    SpaceWireTb_DataType
  );

  procedure SendEop (
    signal TransactionRec : inout SpaceWireRecType
  );

  procedure SendEep (
    signal TransactionRec : inout SpaceWireRecType
  );

  procedure CheckData (
    signal   TransactionRec : inout SpaceWireRecType;
    constant ExpectedData   : in    SpaceWireTb_DataType
  );

  procedure CheckEop (
    signal TransactionRec : inout SpaceWireRecType
  );

  procedure CheckEep (
    signal TransactionRec : inout SpaceWireRecType
  );

  procedure SendPacket(
  signal   TransRec : inout SpaceWireRecType;
  constant Packet   : in    SpaceWirePacketType;
  constant Ending   : in    SpaceWirePacketEndType := PACKET_EOP
  );

  procedure CheckPacket(
  signal   TransRec : inout SpaceWireRecType;
  constant Packet   : in    SpaceWirePacketType;
  constant Ending   : in    SpaceWirePacketEndType := PACKET_EOP
  );

end package SpaceWireTbPkg;


package body SpaceWireTbPkg is

  function to_string (
    constant Item : in SpaceWireStimType
  ) return string is
  begin
    if Item.Flag = SPW_DATA_FLAG then
      return
        "Data character: 0x" & to_hxstring(Item.Data);

    elsif Item.Data = SPW_EOP_DATA then
      return "EOP";

    elsif Item.Data = SPW_EEP_DATA then
      return "EEP";

    else
      return
        "Unsupported control character: 0x" &
        to_hxstring(Item.Data);
    end if;
  end function to_string;


  function Match (
    constant Actual   : in SpaceWireStimType;
    constant Expected : in SpaceWireStimType
  ) return boolean is
  begin
    return
      Actual.Data = Expected.Data and
      Actual.Flag = Expected.Flag;
  end function Match;


  procedure SendData (
    signal   TransactionRec : inout SpaceWireRecType;
    constant Data           : in    SpaceWireTb_DataType
  ) is
  begin
    Send(TransactionRec, Data, SPW_DATA_FLAG);
  end procedure SendData;


  procedure SendEop (
    signal TransactionRec : inout SpaceWireRecType
  ) is
  begin
    Send(TransactionRec, SPW_EOP_DATA, SPW_CONTROL_FLAG);
  end procedure SendEop;


  procedure SendEep (
    signal TransactionRec : inout SpaceWireRecType
  ) is
  begin
    Send(TransactionRec, SPW_EEP_DATA, SPW_CONTROL_FLAG);
  end procedure SendEep;


  procedure CheckData (
    signal   TransactionRec : inout SpaceWireRecType;
    constant ExpectedData   : in    SpaceWireTb_DataType
  ) is
  begin
    Check(TransactionRec, ExpectedData, SPW_DATA_FLAG);
  end procedure CheckData;


  procedure CheckEop (
    signal TransactionRec : inout SpaceWireRecType
  ) is
  begin
    Check(TransactionRec, SPW_EOP_DATA, SPW_CONTROL_FLAG);
  end procedure CheckEop;


  procedure CheckEep (
    signal TransactionRec : inout SpaceWireRecType
  ) is
  begin
    Check(TransactionRec, SPW_EEP_DATA, SPW_CONTROL_FLAG);
  end procedure CheckEep;

  procedure SendPacket(
  signal   TransRec : inout SpaceWireRecType;
  constant Packet   : in    SpaceWirePacketType;
  constant Ending   : in    SpaceWirePacketEndType := PACKET_EOP
  ) is
  begin
    for Index in Packet'range loop
      SendData(TransRec, Packet(Index));
    end loop;

    case Ending is
      when PACKET_EOP =>
        SendEop(TransRec);

      when PACKET_EEP =>
        SendEep(TransRec);
    end case;
  end procedure;

  procedure CheckPacket(
  signal   TransRec : inout SpaceWireRecType;
  constant Packet   : in    SpaceWirePacketType;
  constant Ending   : in    SpaceWirePacketEndType := PACKET_EOP
  ) is
  begin
    for Index in Packet'range loop
      CheckData(TransRec, Packet(Index));
    end loop;

    case Ending is
      when PACKET_EOP =>
        CheckEop(TransRec);

      when PACKET_EEP =>
        CheckEep(TransRec);
    end case;
  end procedure;

end package body SpaceWireTbPkg;