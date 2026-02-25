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
local DROP_INTERVAL = 2 -- segundos entre marbles por dropper

local activeDroppers = {}

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
			MarbleModule.CreateMarble(dropperModel)
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
