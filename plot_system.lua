--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

-- Plot System (ServerScriptService)
-- Responsabilidad única:
-- 1) Buscar plots libres.
-- 2) Asignar un plot al jugador al entrar.
-- 3) Teletransportarlo a su SpawnPoint.
-- 4) Liberar el plot cuando salga.

local Players = game:GetService("Players")

local function getFoundationFolder()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	return map:FindFirstChild("FoundationFolder")
end

local function getOwnerUserId(plot)
	local value = plot:GetAttribute("OwnerUserId")
	if type(value) == "number" then
		return value
	end
	return nil
end

local function isPlotFree(plot)
	return getOwnerUserId(plot) == nil
end

local function findPlayerPlot(player)
	local foundation = getFoundationFolder()
	if not foundation then return nil end

	for _, plot in ipairs(foundation:GetChildren()) do
		if getOwnerUserId(plot) == player.UserId then
			return plot
		end
	end

	return nil
end

local function findFreePlot()
	local foundation = getFoundationFolder()
	if not foundation then return nil end

	for _, plot in ipairs(foundation:GetChildren()) do
		if isPlotFree(plot) then
			return plot
		end
	end

	return nil
end

local function getSpawnPoint(plot)
	return plot:FindFirstChild("SpawnPoint") or plot:FindFirstChild("Spawn")
end

local function teleportPlayerToPlot(player, plot)
	local spawnPoint = getSpawnPoint(plot)
	if not spawnPoint or not spawnPoint:IsA("BasePart") then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
	root.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
end

local function claimPlot(player)
	local plot = findPlayerPlot(player)
	if not plot then
		plot = findFreePlot()
	end
	if not plot then
		warn("[PlotSystem] No hay plot libre para", player.Name)
		return nil
	end

	plot:SetAttribute("OwnerUserId", player.UserId)
	return plot
end

local function releasePlotByPlayer(player)
	local plot = findPlayerPlot(player)
	if not plot then return end

	plot:SetAttribute("OwnerUserId", nil)
end

local function clearAllPlotsOnServerStart()
	local foundation = getFoundationFolder()
	if not foundation then return end

	for _, plot in ipairs(foundation:GetChildren()) do
		plot:SetAttribute("OwnerUserId", nil)
	end
end

clearAllPlotsOnServerStart()

Players.PlayerAdded:Connect(function(player)
	local plot = claimPlot(player)
	if not plot then return end

	teleportPlayerToPlot(player, plot)
	player.CharacterAdded:Connect(function()
		local myPlot = findPlayerPlot(player)
		if myPlot then
			teleportPlayerToPlot(player, myPlot)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	releasePlotByPlayer(player)
end)
