--!strict
-- Admin
-- Single source of truth for developer permissions and dev-tool networking names,
-- shared by client and server so both sides agree on who is an admin and what the
-- RemoteEvent is called.
--
-- SECURITY: The client uses isAdmin() only to decide whether to *show* dev UI.
-- That is cosmetic — an exploiter can always see the RemoteEvent and fire it.
-- The server MUST call isAdmin() again on every OnServerEvent before acting.

local RunService = game:GetService("RunService")

local Admin = {}

-- RemoteEvent / folder names (kept here so client and server never drift apart).
Admin.REMOTES_FOLDER = "Remotes"
Admin.RESET_MONEY_EVENT = "ResetMoneyEvent"

-- Whitelisted developer UserIds allowed to use dev tools in the live game.
Admin.USER_IDS = {
	[3011735313] = true,
	[1277828922] = true,
	[5697403751] = true,
} :: { [number]: boolean }

-- True in Studio (dev convenience) or for a whitelisted UserId in a live server.
function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return Admin.USER_IDS[player.UserId] == true
end

table.freeze(Admin.USER_IDS)
table.freeze(Admin)

return Admin
