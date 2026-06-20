--!nonstrict
-- MoneyService
-- Server-side source of truth for player money.
--
-- Design notes:
--  * `_playerData[userId]` is the authoritative balance. `leaderstats.Money` is
--    only a *mirror* used to display the value on the Roblox leaderboard; gameplay
--    code should never read from it.
--  * All DataStore calls are wrapped in pcall + retry so a transient failure does
--    not crash the join/leave flow or silently lose data.
--  * Per-player state is removed on PlayerRemoving so leavers don't leak memory.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)

local MoneyService = {}
MoneyService._playerData = {} :: { [number]: number } -- userId -> current balance (the source of truth)
MoneyService._connections = {} :: { RBXScriptConnection } -- retains Init's event connections for the server's lifetime
MoneyService._dataStore = DataStoreService:GetDataStore(GameConstants.MONEY_DATASTORE_KEY)
MoneyService._isInitialized = false -- guards Init() and keeps the income loop alive

-- ---------------------------------------------------------------------------
-- Leaderstats (display mirror only)
-- ---------------------------------------------------------------------------

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "Money"
	moneyValue.Value = MoneyService._playerData[player.UserId] or 0
	moneyValue.Parent = leaderstats

	leaderstats.Parent = player
end

local function getMoneyValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	return leaderstats:FindFirstChild("Money") :: IntValue?
end

local function updateLeaderstats(player: Player)
	local moneyValue = getMoneyValue(player)
	if moneyValue then
		moneyValue.Value = MoneyService._playerData[player.UserId] or 0
	end
end

-- ---------------------------------------------------------------------------
-- DataStore helpers (retry-wrapped)
-- ---------------------------------------------------------------------------

local function retry(label: string, fn: () -> any): (boolean, any)
	local attempts = 0
	while attempts < GameConstants.DATASTORE_MAX_RETRIES do
		attempts += 1
		local success, result = pcall(fn)
		if success then
			return true, result
		end
		warn(
			string.format(
				"MoneyService: %s failed (attempt %d/%d) - %s",
				label,
				attempts,
				GameConstants.DATASTORE_MAX_RETRIES,
				tostring(result)
			)
		)
		if attempts < GameConstants.DATASTORE_MAX_RETRIES then
			task.wait(GameConstants.DATASTORE_RETRY_DELAY)
		end
	end
	return false, nil
end

function MoneyService:_savePlayerData(userId: number)
	local currentMoney = self._playerData[userId]
	if currentMoney == nil then
		return -- nothing loaded for this user; never overwrite good data with nil
	end

	retry("save:" .. userId, function()
		self._dataStore:SetAsync(tostring(userId), currentMoney)
	end)
end

function MoneyService:_loadPlayerData(player: Player)
	local userId = player.UserId

	local success, result = retry("load:" .. userId, function()
		return self._dataStore:GetAsync(tostring(userId))
	end)

	-- The GetAsync above yields; the player may have left while we waited.
	if player.Parent == nil then
		return
	end

	-- result is nil for a brand-new player; fall back to the starting balance.
	local moneyValue = GameConstants.STARTING_MONEY
	if success and typeof(result) == "number" then
		moneyValue = result
	end

	self._playerData[userId] = moneyValue
	createLeaderstats(player)
	updateLeaderstats(player)
end

function MoneyService:_removePlayerData(player: Player)
	local userId = player.UserId
	self:_savePlayerData(userId)
	self._playerData[userId] = nil
end

-- ---------------------------------------------------------------------------
-- Public API (gameplay code should go through these, not _playerData directly)
-- ---------------------------------------------------------------------------

function MoneyService:GetMoney(userId: number): number
	return self._playerData[userId] or 0
end

function MoneyService:AddMoney(userId: number, amount: number)
	if self._playerData[userId] == nil then
		return
	end
	self._playerData[userId] += amount
	local player = Players:GetPlayerByUserId(userId)
	if player then
		updateLeaderstats(player)
	end
end

-- Returns true if the player had enough and the amount was deducted.
function MoneyService:TrySpendMoney(userId: number, amount: number): boolean
	local balance = self._playerData[userId]
	if balance == nil or balance < amount then
		return false
	end
	self:AddMoney(userId, -amount)
	return true
end

-- ---------------------------------------------------------------------------
-- Passive income
-- ---------------------------------------------------------------------------

-- Per-player income for a single tick. This is the extension point for Phase 2:
-- sum the stats of the player's equipped characters here instead of the flat base.
function MoneyService:_calculateIncome(_player: Player, _userId: number): number
	return GameConstants.BASE_MONEY_PER_SECOND
end

function MoneyService:_awardPassiveIncome()
	for userId in pairs(self._playerData) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self._playerData[userId] += self:_calculateIncome(player, userId)
			updateLeaderstats(player)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function MoneyService:_bindPlayerEvents()
	table.insert(
		self._connections,
		Players.PlayerAdded:Connect(function(player)
			self:_loadPlayerData(player)
		end)
	)

	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player)
			self:_removePlayerData(player)
		end)
	)
end

function MoneyService:_bindShutdown()
	game:BindToClose(function()
		-- Save everyone in parallel so we fit inside the 30s shutdown budget.
		local pending = 0
		for userId in pairs(self._playerData) do
			pending += 1
			task.spawn(function()
				self:_savePlayerData(userId)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

function MoneyService:_startIncomeLoop()
	task.spawn(function()
		while self._isInitialized do
			task.wait(GameConstants.PASSIVE_INCOME_INTERVAL)
			self:_awardPassiveIncome()
		end
	end)
end

function MoneyService:Init()
	if self._isInitialized then
		return
	end
	self._isInitialized = true

	self:_bindPlayerEvents()
	self:_bindShutdown()

	-- Catch players who joined before this service finished initializing.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_loadPlayerData(player)
		end)
	end

	self:_startIncomeLoop()
end

return MoneyService
