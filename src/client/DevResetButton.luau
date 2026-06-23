--!strict
-- DevResetButton
-- Code-built dev UI: a "Reset Money" button wired to the ResetMoneyEvent.
--
-- init() bails immediately for non-admins, so in the live game regular players
-- never get the ScreenGui at all — no clutter, and nothing to interact with.
-- (The server still re-verifies on its side; see AdminService.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admin = require(ReplicatedStorage.Shared.Admin)

local DevResetButton = {}

local function buildGui(resetEvent: RemoteEvent): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DevTools"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local button = Instance.new("TextButton")
	button.Name = "ResetMoneyButton"
	button.Size = UDim2.fromOffset(160, 44)
	button.Position = UDim2.new(0, 16, 1, -16)
	button.AnchorPoint = Vector2.new(0, 1) -- pin to bottom-left
	button.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Text = "Reset Money"
	button.AutoButtonColor = true
	button.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.Activated:Connect(function()
		resetEvent:FireServer()
	end)

	return screenGui
end

function DevResetButton.init()
	local player = Players.LocalPlayer
	if not Admin.isAdmin(player) then
		return -- non-admins never receive the UI
	end

	local remotes = ReplicatedStorage:WaitForChild(Admin.REMOTES_FOLDER)
	local resetEvent = remotes:WaitForChild(Admin.RESET_MONEY_EVENT) :: RemoteEvent

	local gui = buildGui(resetEvent)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return DevResetButton
