-- Client entry point.
-- The src/client folder becomes a LocalScript (StarterPlayerScripts.Client); each
-- sibling .luau is a child ModuleScript reachable via `script.<Name>`.

local DevResetButton = require(script.DevResetButton)

DevResetButton.init()
