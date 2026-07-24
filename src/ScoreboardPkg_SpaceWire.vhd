library ieee;
  use ieee.std_logic_1164.all;

library osvvm;
  context osvvm.OsvvmContext;

use work.SpaceWireTbPkg.all;


--------------------------------------------------------------------
-- SpaceWire N-Char scoreboard
--
-- Expected and actual entries use SpaceWireStimType:
--
--   Flag = '0'                  normal DATA
--   Flag = '1', Data = x"00"    EOP
--   Flag = '1', Data = x"01"    EEP
--
-- The Match and to_string functions already provided by
-- SpaceWireTbPkg make the HTML report readable.
--------------------------------------------------------------------
package ScoreboardPkg_SpaceWire is new osvvm.ScoreboardGenericPkg
  generic map (
    ExpectedType       => SpaceWireStimType,
    ActualType         => SpaceWireStimType,
    Match              => Match,
    expected_to_string => to_string,
    actual_to_string   => to_string
  );
