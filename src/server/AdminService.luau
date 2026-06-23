--!nonstrict
-- AdminService
-- Owns developer-only RemoteEvents and enforces permissions on them.
--
-- The RemoteEvent is created here (not in Studio) so it always exists and client
-- and server stay in sync. Crucially, the OnServerEvent handler re-checks admin
-- status on every call: the client UI gate is cosmetic, this is the real wall an
-- exploiter hits if they fire the remote directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admin = require(ReplicatedStorage.Shared.Admin)

local AdminService = {}
AdminService._isInitialized = false

-- Minimum seconds between accepted resets per player; cheap spam guard.
local RESET_COOLDOWN = 0.5
local lastResetAt = {} :: { [number]: number }

local function getRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Admin.REMOTES_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Admin.REMOTES_FOLDER
		folder.Parent = ReplicatedStorage
	end
	return folder
end

function AdminService:_onResetMoney(player: Player)
	-- Real permission check — runs regardless of whether the client showed UI.
	if not Admin.isAdmin(player) then
		warn(string.format("AdminService: rejected ResetMoney from non-admin %s (%d)", player.Name, player.UserId))
		return
	end

	local now = os.clock()
	local last = lastResetAt[player.UserId]
	if last and now - last < RESET_COOLDOWN then
		return
	end
	lastResetAt[player.UserId] = now

	self._moneyService:SetMoney(player.UserId, 0)
	print(string.format("AdminService: %s (%d) reset their money to 0", player.Name, player.UserId))
end

function AdminService:Init(moneyService)
	if self._isInitialized then
		return
	end
	self._isInitialized = true
	self._moneyService = moneyService

	local resetEvent = Instance.new("RemoteEvent")
	resetEvent.Name = Admin.RESET_MONEY_EVENT
	resetEvent.Parent = getRemotesFolder()

	resetEvent.OnServerEvent:Connect(function(player)
		self:_onResetMoney(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastResetAt[player.UserId] = nil
	end)
end

return AdminService
