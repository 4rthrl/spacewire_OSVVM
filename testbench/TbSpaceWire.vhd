library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm_spacewire;
  use osvvm_spacewire.SpaceWireTbPkg.all;

--------------------------------------------------------------------
-- Original SpaceWire Light RTL library
--
-- This library must contain:
--   spwpkg.vhd
--   spwstream.vhd
--   and the supporting SpaceWire Light RTL files
--------------------------------------------------------------------
library spacewire_light;
  use spacewire_light.spwpkg.all;


--------------------------------------------------------------------
-- The top-level testbench has no external ports.
--
-- Everything needed for the simulation is instantiated inside the
-- TestHarness architecture.
--------------------------------------------------------------------
entity TbSpaceWire is
end entity TbSpaceWire;


architecture TestHarness of TbSpaceWire is

  ------------------------------------------------------------------
  -- Testbench configuration
  ------------------------------------------------------------------
  constant CLK_PERIOD : time := 20 ns;

  ------------------------------------------------------------------
  -- 50 MHz system clock
  --
  -- 1 / 20 ns = 50 MHz
  ------------------------------------------------------------------
  signal Clk : std_logic := '0';

  ------------------------------------------------------------------
  -- Testbench reset
  --
  -- nReset:
  --   0 = verification components are in reset
  --   1 = verification components are operating
  --
  -- SpwReset:
  --   1 = SpaceWire Light core is in reset
  --   0 = SpaceWire Light core is operating
  ------------------------------------------------------------------
  signal nReset  : std_logic := '0';
  signal SpwReset : std_logic;


  ------------------------------------------------------------------
  -- OSVVM transaction records
  --
  -- Node A:
  --   SpwTxRecA sends characters into SpaceWire core A.
  --   SpwRxRecA receives characters arriving at core A.
  --
  -- Node B:
  --   SpwTxRecB sends characters into SpaceWire core B.
  --   SpwRxRecB receives characters arriving at core B.
  ------------------------------------------------------------------
  signal SpwTxRecA : SpaceWireRecType;
  signal SpwRxRecA : SpaceWireRecType;

  signal SpwTxRecB : SpaceWireRecType;
  signal SpwRxRecB : SpaceWireRecType;


  ------------------------------------------------------------------
  -- Node A transmit stream interface
  ------------------------------------------------------------------
  signal TxReadyA : std_logic;
  signal TxWriteA : std_logic;
  signal TxFlagA  : std_logic;
  signal TxDataA  : std_logic_vector(7 downto 0);


  ------------------------------------------------------------------
  -- Node A receive stream interface
  ------------------------------------------------------------------
  signal RxValidA : std_logic;
  signal RxReadA  : std_logic;
  signal RxFlagA  : std_logic;
  signal RxDataA  : std_logic_vector(7 downto 0);


  ------------------------------------------------------------------
  -- Node B transmit stream interface
  ------------------------------------------------------------------
  signal TxReadyB : std_logic;
  signal TxWriteB : std_logic;
  signal TxFlagB  : std_logic;
  signal TxDataB  : std_logic_vector(7 downto 0);


  ------------------------------------------------------------------
  -- Node B receive stream interface
  ------------------------------------------------------------------
  signal RxValidB : std_logic;
  signal RxReadB  : std_logic;
  signal RxFlagB  : std_logic;
  signal RxDataB  : std_logic_vector(7 downto 0);


  ------------------------------------------------------------------
  -- Link-management settings
  --
  -- For now:
  --   - both nodes start their links automatically after reset;
  --   - autostart is disabled;
  --   - link disable is inactive;
  --   - the run-rate divider is fixed at 0x04.
  --
  -- At 50 MHz:
  --
  --   50 MHz / (4 + 1) = 10 Mbit/s
  --
  -- Later, these signals can be controlled from TestCtrl so tests
  -- can stop, restart and reconfigure the link.
  ------------------------------------------------------------------
  signal AutoStartA : std_logic := '0';
  signal LinkStartA : std_logic := '1';
  signal LinkDisableA : std_logic := '0';
  signal TxDivCntA : std_logic_vector(7 downto 0) := x"04";

  signal AutoStartB : std_logic := '0';
  signal LinkStartB : std_logic := '1';
  signal LinkDisableB : std_logic := '0';
  signal TxDivCntB : std_logic_vector(7 downto 0) := x"04";


  ------------------------------------------------------------------
  -- Node A link-state signals
  ------------------------------------------------------------------
  signal StartedA    : std_logic;
  signal ConnectingA : std_logic;
  signal RunningA    : std_logic;


  ------------------------------------------------------------------
  -- Node B link-state signals
  ------------------------------------------------------------------
  signal StartedB    : std_logic;
  signal ConnectingB : std_logic;
  signal RunningB    : std_logic;


  ------------------------------------------------------------------
  -- Node A error indications
  ------------------------------------------------------------------
  signal ErrorDisconnectA : std_logic;
  signal ErrorParityA     : std_logic;
  signal ErrorEscapeA     : std_logic;
  signal ErrorCreditA     : std_logic;


  ------------------------------------------------------------------
  -- Node B error indications
  ------------------------------------------------------------------
  signal ErrorDisconnectB : std_logic;
  signal ErrorParityB     : std_logic;
  signal ErrorEscapeB     : std_logic;
  signal ErrorCreditB     : std_logic;


  ------------------------------------------------------------------
  -- Logical SpaceWire Data/Strobe signals
  --
  -- Core outputs:
  --   SpwDataOutA, SpwStrobeOutA
  --   SpwDataOutB, SpwStrobeOutB
  --
  -- Core inputs:
  --   SpwDataInA, SpwStrobeInA
  --   SpwDataInB, SpwStrobeInB
  ------------------------------------------------------------------
  signal SpwDataOutA   : std_logic;
  signal SpwStrobeOutA : std_logic;
  signal SpwDataInA    : std_logic;
  signal SpwStrobeInA  : std_logic;

  signal SpwDataOutB   : std_logic;
  signal SpwStrobeOutB : std_logic;
  signal SpwDataInB    : std_logic;
  signal SpwStrobeInB  : std_logic;

  ------------------------------------------------------------------
  -- Passive A-to-B & B-to-A SpaceWire monitor outputs
  ------------------------------------------------------------------
  signal MonABValid        : std_logic;
  signal MonABFlag         : std_logic;
  signal MonABData         : std_logic_vector(7 downto 0);
  signal MonABSynchronized : std_logic;
  signal MonABPacketActive : std_logic;

  signal MonBAValid        : std_logic;
  signal MonBAFlag         : std_logic;
  signal MonBAData         : std_logic_vector(7 downto 0);
  signal MonBASynchronized : std_logic;
  signal MonBAPacketActive : std_logic;

  ------------------------------------------------------------------
  -- TestCtrl component declaration
  --
  -- TestCtrl_e.vhd defines this interface.
  --
  -- A particular architecture, such as SendGet1, will later be
  -- selected through a VHDL configuration.
  ------------------------------------------------------------------
  component TestCtrl is
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
      MonBAPacketActive : in std_logic


    );
  end component TestCtrl;


begin

  ------------------------------------------------------------------
  -- Clock generation
  ------------------------------------------------------------------
  CreateClock(
    Clk,
    CLK_PERIOD
  );


  ------------------------------------------------------------------
  -- Reset generation
  --
  -- nReset remains low for seven clock periods, then becomes high.
  --
  -- The 2 ns delay avoids changing reset at exactly the same time as
  -- a clock edge.
  ------------------------------------------------------------------
  CreateReset(
  Reset       => nReset,
  ResetActive => '0',
  Clk         => Clk,
  Period      => 7 * CLK_PERIOD,
  tpd         => 2 ns
);

  ------------------------------------------------------------------
  -- SpaceWire Light uses an active-high reset.
  --
  -- Our verification components use active-low reset naming:
  --
  --   nReset = 0  -> reset
  --   nReset = 1  -> operate
  --
  -- Therefore, invert it for spwstream.
  ------------------------------------------------------------------
  SpwReset <= not nReset;


  ------------------------------------------------------------------
  -- Logical bidirectional SpaceWire link
  --
  -- Node A transmitter connects to Node B receiver.
  ------------------------------------------------------------------
  SpwDataInB   <= SpwDataOutA;
  SpwStrobeInB <= SpwStrobeOutA;


  ------------------------------------------------------------------
  -- Node B transmitter connects to Node A receiver.
  ------------------------------------------------------------------
  SpwDataInA   <= SpwDataOutB;
  SpwStrobeInA <= SpwStrobeOutB;


  ------------------------------------------------------------------
  -- OSVVM transmitter for Node A
  --
  -- Converts high-level OSVVM SEND operations into the spwstream
  -- txwrite/txrdy handshake.
  ------------------------------------------------------------------
  SpaceWireTx_A : entity osvvm_spacewire.SpaceWireTx(model)
    generic map (
      MODEL_ID_NAME => "SpaceWireTx_A"
    )
    port map (
      TransRec => SpwTxRecA,

      Clk      => Clk,
      nReset   => nReset,

      TxReady  => TxReadyA,
      TxWrite  => TxWriteA,
      TxFlag   => TxFlagA,
      TxData   => TxDataA
    );


  ------------------------------------------------------------------
  -- OSVVM receiver for Node A
  --
  -- Collects characters from the spwstream receive interface and
  -- makes them available through GET and CHECK transactions.
  ------------------------------------------------------------------
  SpaceWireRx_A : entity osvvm_spacewire.SpaceWireRx(model)
    generic map (
      MODEL_ID_NAME => "SpaceWireRx_A"
    )
    port map (
      TransRec => SpwRxRecA,

      Clk      => Clk,
      nReset   => nReset,

      RxValid  => RxValidA,
      RxRead   => RxReadA,
      RxFlag   => RxFlagA,
      RxData   => RxDataA
    );


  ------------------------------------------------------------------
  -- OSVVM transmitter for Node B
  ------------------------------------------------------------------
  SpaceWireTx_B : entity osvvm_spacewire.SpaceWireTx(model)
    generic map (
      MODEL_ID_NAME => "SpaceWireTx_B"
    )
    port map (
      TransRec => SpwTxRecB,

      Clk      => Clk,
      nReset   => nReset,

      TxReady  => TxReadyB,
      TxWrite  => TxWriteB,
      TxFlag   => TxFlagB,
      TxData   => TxDataB
    );


  ------------------------------------------------------------------
  -- OSVVM receiver for Node B
  ------------------------------------------------------------------
  SpaceWireRx_B : entity osvvm_spacewire.SpaceWireRx(model)
    generic map (
      MODEL_ID_NAME => "SpaceWireRx_B"
    )
    port map (
      TransRec => SpwRxRecB,

      Clk      => Clk,
      nReset   => nReset,

      RxValid  => RxValidB,
      RxRead   => RxReadB,
      RxFlag   => RxFlagB,
      RxData   => RxDataB
    );

  ------------------------------------------------------------------
  -- Passive monitor for traffic transmitted from Node A to Node B
  --
  -- The monitor only observes the signals. It does not drive or
  -- modify the SpaceWire connection.
  ------------------------------------------------------------------
  MonitorAB : entity osvvm_spacewire.SpaceWireMonitor
    generic map (
      MONITOR_NAME          => "Monitor_A_to_B",
      MAX_PACKET_BYTES      => 256,

      LOG_DATA_CHARACTERS   => false,
      LOG_LINK_CHARACTERS   => false,

      CHECK_PARITY          => true,
      LOG_PARITY_RESULTS    => false,
      LOG_PACKET_SUMMARY    => true
    )
    port map (
      nReset   => nReset,
      DataIn   => SpwDataOutA,
      StrobeIn => SpwStrobeOutA,

      MonValid => MonABValid,
      MonFlag  => MonABFlag,
      MonData  => MonABData,

      Synchronized => MonABSynchronized,
      PacketActive => MonABPacketActive
    );

  MonitorBA : entity osvvm_spacewire.SpaceWireMonitor
    generic map (
      MONITOR_NAME          => "Monitor_B_to_A",
      MAX_PACKET_BYTES      => 256,

      LOG_DATA_CHARACTERS   => false,
      LOG_LINK_CHARACTERS   => false,

      CHECK_PARITY          => true,
      LOG_PARITY_RESULTS    => false,
      LOG_PACKET_SUMMARY    => true
    )
    port map (
      nReset   => nReset,
      DataIn   => SpwDataOutB,
      StrobeIn => SpwStrobeOutB,

      MonValid => MonBAValid,
      MonFlag  => MonBAFlag,
      MonData  => MonBAData,

      Synchronized => MonBASynchronized,
      PacketActive => MonBAPacketActive
    );

  ------------------------------------------------------------------
  -- SpaceWire Light core A
  --
  -- For now:
  --   - generic receiver and transmitter implementations;
  --   - one shared 50 MHz clock;
  --   - 64-character TX and RX FIFOs;
  --   - time-code support is not tested;
  --   - link starts as soon as reset is released.
  --
  -- Later:
  --   - implementation and FIFO sizes can become harness generics;
  --   - separate RX/TX clocks can test impl_fast;
  --   - time-code signals can connect to another VC;
  --   - link control can be driven by TestCtrl.
  ------------------------------------------------------------------
  SpaceWireCore_A : entity spacewire_light.spwstream
    generic map (
      sysfreq         => 50.0e6,
      txclkfreq       => 0.0,

      rximpl          => impl_generic,
      rxchunk         => 1,

      tximpl          => impl_generic,

      rxfifosize_bits => 6,
      txfifosize_bits => 6
    )
    port map (
      ------------------------------------------------------------
      -- Clocks and reset
      ------------------------------------------------------------
      clk   => Clk,
      rxclk => Clk,
      txclk => Clk,
      rst   => SpwReset,

      ------------------------------------------------------------
      -- Link management
      ------------------------------------------------------------
      autostart => AutoStartA,
      linkstart => LinkStartA,
      linkdis   => LinkDisableA,
      txdivcnt  => TxDivCntA,

      ------------------------------------------------------------
      -- Time-code transmit interface
      --
      -- Not used in the first testbench version.
      ------------------------------------------------------------
      tick_in => '0',
      ctrl_in => "00",
      time_in => "000000",

      ------------------------------------------------------------
      -- Application transmit FIFO interface
      ------------------------------------------------------------
      txwrite => TxWriteA,
      txflag  => TxFlagA,
      txdata  => TxDataA,
      txrdy   => TxReadyA,
      txhalff => open,

      ------------------------------------------------------------
      -- Time-code receive interface
      --
      -- Not used in the first testbench version.
      ------------------------------------------------------------
      tick_out => open,
      ctrl_out => open,
      time_out => open,

      ------------------------------------------------------------
      -- Application receive FIFO interface
      ------------------------------------------------------------
      rxvalid => RxValidA,
      rxhalff => open,
      rxflag  => RxFlagA,
      rxdata  => RxDataA,
      rxread  => RxReadA,

      ------------------------------------------------------------
      -- Link status
      ------------------------------------------------------------
      started    => StartedA,
      connecting => ConnectingA,
      running    => RunningA,

      ------------------------------------------------------------
      -- Link errors
      ------------------------------------------------------------
      errdisc => ErrorDisconnectA,
      errpar  => ErrorParityA,
      erresc  => ErrorEscapeA,
      errcred => ErrorCreditA,

      ------------------------------------------------------------
      -- Logical SpaceWire Data/Strobe interface
      ------------------------------------------------------------
      spw_di => SpwDataInA,
      spw_si => SpwStrobeInA,
      spw_do => SpwDataOutA,
      spw_so => SpwStrobeOutA
    );


  ------------------------------------------------------------------
  -- SpaceWire Light core B
  --
  -- Core B uses the same initial configuration as core A.
  ------------------------------------------------------------------
  SpaceWireCore_B : entity spacewire_light.spwstream
    generic map (
      sysfreq         => 50.0e6,
      txclkfreq       => 0.0,

      rximpl          => impl_generic,
      rxchunk         => 1,

      tximpl          => impl_generic,

      rxfifosize_bits => 6,
      txfifosize_bits => 6
    )
    port map (
      ------------------------------------------------------------
      -- Clocks and reset
      ------------------------------------------------------------
      clk   => Clk,
      rxclk => Clk,
      txclk => Clk,
      rst   => SpwReset,

      ------------------------------------------------------------
      -- Link management
      ------------------------------------------------------------
      autostart => AutoStartB,
      linkstart => LinkStartB,
      linkdis   => LinkDisableB,
      txdivcnt  => TxDivCntB,

      ------------------------------------------------------------
      -- Time-code transmit interface
      ------------------------------------------------------------
      tick_in => '0',
      ctrl_in => "00",
      time_in => "000000",

      ------------------------------------------------------------
      -- Application transmit FIFO interface
      ------------------------------------------------------------
      txwrite => TxWriteB,
      txflag  => TxFlagB,
      txdata  => TxDataB,
      txrdy   => TxReadyB,
      txhalff => open,

      ------------------------------------------------------------
      -- Time-code receive interface
      ------------------------------------------------------------
      tick_out => open,
      ctrl_out => open,
      time_out => open,

      ------------------------------------------------------------
      -- Application receive FIFO interface
      ------------------------------------------------------------
      rxvalid => RxValidB,
      rxhalff => open,
      rxflag  => RxFlagB,
      rxdata  => RxDataB,
      rxread  => RxReadB,

      ------------------------------------------------------------
      -- Link status
      ------------------------------------------------------------
      started    => StartedB,
      connecting => ConnectingB,
      running    => RunningB,

      ------------------------------------------------------------
      -- Link errors
      ------------------------------------------------------------
      errdisc => ErrorDisconnectB,
      errpar  => ErrorParityB,
      erresc  => ErrorEscapeB,
      errcred => ErrorCreditB,

      ------------------------------------------------------------
      -- Logical SpaceWire Data/Strobe interface
      ------------------------------------------------------------
      spw_di => SpwDataInB,
      spw_si => SpwStrobeInB,
      spw_do => SpwDataOutB,
      spw_so => SpwStrobeOutB
    );


  ------------------------------------------------------------------
  -- Test controller
  --
  -- This instance connects the fixed harness to a selectable test
  -- architecture.
  --
  -- The next file, TbSpaceWire_SendGet1.vhd, will define:
  --
  --   architecture SendGet1 of TestCtrl
  --
  -- and a configuration will bind that architecture to this
  -- TestCtrl_1 instance.
  ------------------------------------------------------------------
  TestCtrl_1 : TestCtrl
    port map (
      Clk    => Clk,
      nReset => nReset,

      SpwTxRecA => SpwTxRecA,
      SpwRxRecA => SpwRxRecA,

      SpwTxRecB => SpwTxRecB,
      SpwRxRecB => SpwRxRecB,

      RunningA => RunningA,
      RunningB => RunningB,

      ErrorDisconnectA => ErrorDisconnectA,
      ErrorParityA     => ErrorParityA,
      ErrorEscapeA     => ErrorEscapeA,
      ErrorCreditA     => ErrorCreditA,

      ErrorDisconnectB => ErrorDisconnectB,
      ErrorParityB     => ErrorParityB,
      ErrorEscapeB     => ErrorEscapeB,
      ErrorCreditB     => ErrorCreditB,

      MonABValid        => MonABValid,
      MonABFlag         => MonABFlag,
      MonABData         => MonABData,
      MonABSynchronized => MonABSynchronized,
      MonABPacketActive => MonABPacketActive,

      MonBAValid        => MonBAValid,
      MonBAFlag         => MonBAFlag,
      MonBAData         => MonBAData,
      MonBASynchronized => MonBASynchronized,
      MonBAPacketActive => MonBAPacketActive
    );

end architecture TestHarness;