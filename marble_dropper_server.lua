--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

-- Script para ServerScriptService.
-- Responsabilidad:
-- 1) Detectar modelos Dropper en el mundo.
-- 2) Usar MarbleModule para crear marbles.
-- 3) Controlar cada cuánto tiempo se generan.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

if not RunService:IsServer() then
	return
end

-- El módulo ahora vive en ReplicatedStorage/Modules/DropperMarbleModule.
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local marbleModuleScript = modulesFolder:FindFirstChild("DropperMarbleModule")
	or modulesFolder:FindFirstChild("dropper_marble_module")
if not marbleModuleScript then
	warn("[MarbleDropper] ModuleScript missing in ReplicatedStorage.Modules: DropperMarbleModule")
	return
end

local MarbleModule = require(marbleModuleScript)
local DropperRewards = require(ReplicatedStorage:WaitForChild("DropperRewards"))
local DROP_INTERVAL = 2 -- segundos entre marbles por dropper

local activeDroppers = {}


local function findOwnerPlayerFromDropper(dropperModel)
	local current = dropperModel
	while current and current ~= workspace do
		if current:IsA("Folder") then
			local ownerUserId = current:GetAttribute("OwnerUserId")
			if type(ownerUserId) == "number" then
				return Players:GetPlayerByUserId(ownerUserId)
			end

			local ownerValue = current:FindFirstChild("Owner")
			if ownerValue then
				local value = ownerValue.Value
				if typeof(value) == "Instance" and value:IsA("Player") then
					return value
				end
				if typeof(value) == "number" then
					return Players:GetPlayerByUserId(value)
				end
				if typeof(value) == "string" then
					local userId = tonumber(value)
					if userId then
						return Players:GetPlayerByUserId(userId)
					end
				end
			end
		end
		current = current.Parent
	end

	return nil
end

local function awardCoinsForMarble(dropperModel)
	local reward = DropperRewards.GetRewardForDropper(dropperModel)
	if reward <= 0 then
		return 0
	end

	local ownerPlayer = findOwnerPlayerFromDropper(dropperModel)
	if not ownerPlayer then
		return 0
	end

	local leaderstats = ownerPlayer:FindFirstChild("leaderstats")
	if not leaderstats then
		return 0
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		return 0
	end

	coins.Value += reward
	return reward
end

local function isDropperModel(instance)
	if not instance or not instance:IsA("Model") then
		return false
	end

	if instance.Name ~= "Dropper" and not string.match(instance.Name, "^Dropper%s*%d+") then
		return false
	end

	local spawnPart = instance:FindFirstChild("Spawn")
	return spawnPart and spawnPart:IsA("BasePart")
end

local function runDropperLoop(dropperModel)
		task.spawn(function()
			while dropperModel.Parent and activeDroppers[dropperModel] do
				local marble = MarbleModule.CreateMarble(dropperModel)
			if marble then
				local reward = awardCoinsForMarble(dropperModel)
				if reward > 0 then
					marble:SetAttribute("CoinReward", reward)
				end
			end
				task.wait(DROP_INTERVAL)
			end

			activeDroppers[dropperModel] = nil
		end)
end

local function registerDropper(dropperModel)
	if activeDroppers[dropperModel] then
		return
	end

	if not isDropperModel(dropperModel) then
		return
	end

	activeDroppers[dropperModel] = true
	runDropperLoop(dropperModel)
end

for _, obj in ipairs(workspace:GetDescendants()) do
	registerDropper(obj)
end

workspace.DescendantAdded:Connect(function(obj)
	registerDropper(obj)
end)

workspace.DescendantRemoving:Connect(function(obj)
	if activeDroppers[obj] then
		activeDroppers[obj] = nil
	end
end)
