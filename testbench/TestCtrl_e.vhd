library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;


entity TestCtrl is
  port (
    ------------------------------------------------------------
    -- Testbench clock and reset
    ------------------------------------------------------------
    Clk    : in std_logic;
    nReset : in std_logic;

    ------------------------------------------------------------
    -- Node A transaction interfaces
    ------------------------------------------------------------
    SpwTxRecA : inout SpaceWireRecType;
    SpwRxRecA : inout SpaceWireRecType;

    ------------------------------------------------------------
    -- Node B transaction interfaces
    ------------------------------------------------------------
    SpwTxRecB : inout SpaceWireRecType;
    SpwRxRecB : inout SpaceWireRecType;

    ------------------------------------------------------------
    -- SpaceWire link status
    ------------------------------------------------------------
    RunningA : in std_logic;
    RunningB : in std_logic;

    ------------------------------------------------------------
    -- SpaceWire error indications
    ------------------------------------------------------------
    ErrorDisconnectA : in std_logic;
    ErrorParityA     : in std_logic;
    ErrorEscapeA     : in std_logic;
    ErrorCreditA     : in std_logic;

    ErrorDisconnectB : in std_logic;
    ErrorParityB     : in std_logic;
    ErrorEscapeB     : in std_logic;
    ErrorCreditB     : in std_logic;

    ----------------------------------------------------------------
    -- Passive A-to-B Data/Strobe monitor
    ----------------------------------------------------------------
    MonABValid        : in std_logic;
    MonABFlag         : in std_logic;
    MonABData         : in std_logic_vector(7 downto 0);
    MonABSynchronized : in std_logic;
    MonABPacketActive : in std_logic;

    ----------------------------------------------------------------
    -- Passive B-to-A Data/Strobe monitor
    ----------------------------------------------------------------
    MonBAValid        : in std_logic;
    MonBAFlag         : in std_logic;
    MonBAData         : in std_logic_vector(7 downto 0);
    MonBASynchronized : in std_logic;
    MonBAPacketActive : in std_logic
  );

end entity TestCtrl;