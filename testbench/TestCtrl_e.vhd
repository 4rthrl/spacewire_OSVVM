library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;


--------------------------------------------------------------------
-- Common test-controller interface used by all test architectures.
--------------------------------------------------------------------
entity TestCtrl is
  port (
    Clk    : in std_logic;
    nReset : in std_logic;

    SpwTxRecA : inout SpaceWireRecType;
    SpwRxRecA : inout SpaceWireRecType;

    SpwTxRecB : inout SpaceWireRecType;
    SpwRxRecB : inout SpaceWireRecType;

    RunningA : in std_logic;
    RunningB : in std_logic;

    ErrorDisconnectA : in std_logic;
    ErrorParityA     : in std_logic;
    ErrorEscapeA     : in std_logic;
    ErrorCreditA     : in std_logic;

    ErrorDisconnectB : in std_logic;
    ErrorParityB     : in std_logic;
    ErrorEscapeB     : in std_logic;
    ErrorCreditB     : in std_logic;

    MonABValid        : in std_logic;
    MonABFlag         : in std_logic;
    MonABData         : in std_logic_vector(7 downto 0);
    MonABSynchronized : in std_logic;
    MonABPacketActive : in std_logic;

    MonBAValid        : in std_logic;
    MonBAFlag         : in std_logic;
    MonBAData         : in std_logic_vector(7 downto 0);
    MonBASynchronized : in std_logic;
    MonBAPacketActive : in std_logic;

    --------------------------------------------------------------
    -- Node A time-code transmit and receive interfaces
    --
    -- Defaults keep older tests safe when their architectures do
    -- not explicitly drive time-code requests.
    --------------------------------------------------------------
    TickInA : out std_logic := '0';
    CtrlInA : out std_logic_vector(1 downto 0) := (others => '0');
    TimeInA : out std_logic_vector(5 downto 0) := (others => '0');

    TickOutA : in std_logic;
    CtrlOutA : in std_logic_vector(1 downto 0);
    TimeOutA : in std_logic_vector(5 downto 0);

    --------------------------------------------------------------
    -- Node B time-code transmit and receive interfaces
    --------------------------------------------------------------
    TickInB : out std_logic := '0';
    CtrlInB : out std_logic_vector(1 downto 0) := (others => '0');
    TimeInB : out std_logic_vector(5 downto 0) := (others => '0');

    TickOutB : in std_logic;
    CtrlOutB : in std_logic_vector(1 downto 0);
    TimeOutB : in std_logic_vector(5 downto 0)
  );
end entity TestCtrl;
