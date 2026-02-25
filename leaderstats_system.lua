local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local statsStore = DataStoreService:GetDataStore("PlayerStats")

local function setupLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = leaderstats

	return coins, gems
end

local function loadData(player)
	local coins, gems = setupLeaderstats(player)

	local success, data = pcall(function()
		return statsStore:GetAsync("Stats_" .. player.UserId)
	end)

	if success and data then
		if data.Coins then
			coins.Value = data.Coins
		end
		if data.Gems then
			gems.Value = data.Gems
		end
		print("Loaded data for " .. player.Name .. ": Coins=" .. coins.Value .. ", Gems=" .. gems.Value)
	else
		print("No data found for " .. player.Name .. ", starting fresh.")
	end
	--solo para coins de prueba
	-- if game:GetService("RunService"):IsStudio() then
	--	coins.Value = 100000
	--end
end

local function saveData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local coins = leaderstats:FindFirstChild("Coins")
	local gems = leaderstats:FindFirstChild("Gems")
	if not coins or not gems then return end

	local success, err = pcall(function()
		statsStore:SetAsync("Stats_" .. player.UserId, {
			Coins = coins.Value,
			Gems = gems.Value,
		})
	end)

	if success then
		print("Saved data for " .. player.Name .. ": Coins=" .. coins.Value .. ", Gems=" .. gems.Value)
	else
		warn("Failed to save data for " .. player.Name .. ": " .. err)
	end
end

Players.PlayerAdded:Connect(loadData)
Players.PlayerRemoving:Connect(saveData)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)
