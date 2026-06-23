-- Server entry point.
-- Because src/server contains this init.server.luau, Rojo turns the whole folder
-- into a single Script (ServerScriptService.Server), and every sibling .luau file
-- becomes a child ModuleScript reachable via `script.<Name>`.

local MoneyService = require(script.MoneyService)
local AdminService = require(script.AdminService)

MoneyService:Init()
AdminService:Init(MoneyService)
