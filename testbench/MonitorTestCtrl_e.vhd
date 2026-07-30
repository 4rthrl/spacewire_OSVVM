library ieee;
  use ieee.std_logic_1164.all;


--------------------------------------------------------------------
-- Common test-controller interface for direct SpaceWire monitor
-- unit tests.
--
-- The test architecture directly drives DataLine and StrobeLine
-- using SpaceWireDsDriverPkg.
--
-- SpaceWireMonitor observes the same physical signals and returns
-- decoded N-Chars through MonValid, MonFlag, and MonData.
--------------------------------------------------------------------
entity MonitorTestCtrl is
  port (
    nReset : in std_logic;

    --------------------------------------------------------------
    -- Directly driven SpaceWire Data/Strobe signals.
    --------------------------------------------------------------
    DataLine   : inout std_logic;
    StrobeLine : inout std_logic;

    --------------------------------------------------------------
    -- Decoded N-Char output from SpaceWireMonitor.
    --
    -- MonFlag = '0'                 normal data byte
    -- MonFlag = '1', MonData = 00   EOP
    -- MonFlag = '1', MonData = 01   EEP
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
end entity MonitorTestCtrl;