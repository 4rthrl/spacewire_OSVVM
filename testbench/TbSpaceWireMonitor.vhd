library ieee;
  use ieee.std_logic_1164.all;

library osvvm_spacewire;


--------------------------------------------------------------------
-- Direct SpaceWire monitor unit-test harness.
--
-- This harness does not instantiate a SpaceWire Light core.
--
-- A MonitorTestCtrl architecture directly drives DataLine and
-- StrobeLine using SpaceWireDsDriverPkg. SpaceWireMonitor observes
-- those signals and returns the decoded N-Chars and status signals
-- to the test controller.
--------------------------------------------------------------------
entity TbSpaceWireMonitor is
end entity TbSpaceWireMonitor;


architecture TestHarness of TbSpaceWireMonitor is

  ------------------------------------------------------------------
  -- Directly driven SpaceWire Data/Strobe signals.
  ------------------------------------------------------------------
  signal DataLine   : std_logic := '0';
  signal StrobeLine : std_logic := '0';

  ------------------------------------------------------------------
  -- Reset signal.
  ------------------------------------------------------------------
  signal nReset : std_logic := '0';

  ------------------------------------------------------------------
  -- Outputs from SpaceWireMonitor.
  ------------------------------------------------------------------
  signal MonValid : std_logic;
  signal MonFlag  : std_logic;
  signal MonData  : std_logic_vector(7 downto 0);

  signal Synchronized : std_logic;
  signal PacketActive : std_logic;


  ------------------------------------------------------------------
  -- Component declaration allows each test configuration to bind
  -- a different architecture of MonitorTestCtrl.
  ------------------------------------------------------------------
  component MonitorTestCtrl is
    port (
      nReset : in std_logic;

      --------------------------------------------------------------
      -- Directly driven SpaceWire Data/Strobe signals.
      --------------------------------------------------------------
      DataLine   : inout std_logic;
      StrobeLine : inout std_logic;

      --------------------------------------------------------------
      -- Decoded N-Char output from SpaceWireMonitor.
      --------------------------------------------------------------
      MonValid : in std_logic;
      MonFlag  : in std_logic;
      MonData  : in std_logic_vector(7 downto 0);

      --------------------------------------------------------------
      -- Monitor status signals.
      --------------------------------------------------------------
      Synchronized : in std_logic;
      PacketActive : in std_logic
    );
  end component MonitorTestCtrl;

begin

  ------------------------------------------------------------------
  -- Reset generation.
  ------------------------------------------------------------------
  ResetProc : process
  begin
    nReset <= '0';

    wait for 1 us;

    nReset <= '1';

    wait;
  end process ResetProc;


  ------------------------------------------------------------------
  -- Passive SpaceWire Data/Strobe monitor.
  ------------------------------------------------------------------
  Monitor_1 : entity osvvm_spacewire.SpaceWireMonitor
    generic map (
      MONITOR_NAME          => "Direct_SpaceWire_Monitor",
      MAX_PACKET_BYTES      => 256,

      LOG_DATA_CHARACTERS   => false,
      LOG_LINK_CHARACTERS   => false,

      CHECK_PARITY          => true,
      LOG_PARITY_RESULTS    => false,
      LOG_PACKET_SUMMARY    => true
    )
    port map (
      nReset   => nReset,
      DataIn   => DataLine,
      StrobeIn => StrobeLine,

      MonValid => MonValid,
      MonFlag  => MonFlag,
      MonData  => MonData,

      Synchronized => Synchronized,
      PacketActive => PacketActive
    );


  ------------------------------------------------------------------
  -- Test controller.
  --
  -- The architecture is selected by the configuration contained
  -- in each individual test file.
  ------------------------------------------------------------------
  MonitorTestCtrl_1 : MonitorTestCtrl
    port map (
      nReset => nReset,

      DataLine   => DataLine,
      StrobeLine => StrobeLine,

      MonValid => MonValid,
      MonFlag  => MonFlag,
      MonData  => MonData,

      Synchronized => Synchronized,
      PacketActive => PacketActive
    );

end architecture TestHarness;