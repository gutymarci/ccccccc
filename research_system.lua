local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local researchEvent = ReplicatedStorage:WaitForChild("ResearchRequest")
local researchedModelsFolder = ReplicatedStorage:WaitForChild("ResearchedModels")

local researchDataStore = DataStoreService:GetDataStore("PlayerResearchData")
local SAVE_KEY_PREFIX = "Research_"

local function getOrCreateResearchFolder(player)
	local researchFolder = player:FindFirstChild("ResearchModels")

	if not researchFolder then
		researchFolder = Instance.new("Folder")
		researchFolder.Name = "ResearchModels"
		researchFolder.Parent = player
	end

	return researchFolder
end

local function savePlayerData(player)
	local userId = player.UserId
	local saveKey = SAVE_KEY_PREFIX .. userId
	local researchFolder = player:FindFirstChild("ResearchModels")

	if researchFolder then
		local modelsToSave = {}
		for _, model in ipairs(researchFolder:GetChildren()) do
			table.insert(modelsToSave, model.Name)
		end

		local success, err = pcall(function()
			researchDataStore:SetAsync(saveKey, modelsToSave)
		end)
	end
end

local function loadPlayerData(player)
	local userId = player.UserId
	local saveKey = SAVE_KEY_PREFIX .. userId
	local data = nil
	local researchFolder = getOrCreateResearchFolder(player)

	local success, result = pcall(function()
		data = researchDataStore:GetAsync(saveKey)
	end)

	if success and data then
		for _, modelName in ipairs(data) do
			if not researchFolder:FindFirstChild(modelName) then
				local marker = Instance.new("StringValue")
				marker.Name = modelName
				marker.Parent = researchFolder
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	loadPlayerData(player)
end)

Players.PlayerRemoving:Connect(savePlayerData)

researchEvent.OnServerEvent:Connect(function(player, modelName)
	local researchFolder = getOrCreateResearchFolder(player)

	if not researchFolder:FindFirstChild(modelName) then
		local marker = Instance.new("StringValue")
		marker.Name = modelName
		marker.Parent = researchFolder

		savePlayerData(player)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)
