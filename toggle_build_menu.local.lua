local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local button = script.Parent
local buildModeMenu = playerGui:WaitForChild("BuildModeMenu")

button.MouseButton1Click:Connect(function()
	buildModeMenu.Enabled = not buildModeMenu.Enabled
end)
