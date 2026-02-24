--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local placeEvent = ReplicatedStorage:FindFirstChild("PlaceObject") or ReplicatedStorage:FindFirstChild("PlaceObjectEvent")
if not placeEvent then
	placeEvent = ReplicatedStorage:WaitForChild("PlaceObject")
end

local modelsFolder = ReplicatedStorage:WaitForChild("Models")
local ObjectCosts = require(ReplicatedStorage:WaitForChild("ObjectCosts"))

local gui = script.Parent
if not gui or not gui:IsA("ScreenGui") then
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BuildModeMenu")
end

local scrollingFrame = gui:WaitForChild("Frame"):WaitForChild("ScrollingFrame")
local mouse = player:GetMouse()

local activeGhost, currentModelName, renderConn, activeIsValid = nil, nil, nil, false
local currentRotation = 0

local gridFolder = Instance.new("Folder")
gridFolder.Name = "PlacementGrid"
gridFolder.Parent = workspace

local baseGridSize = 8
local subGridSize = baseGridSize / 2

local function getPlayerBase()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end

	local foundation = map:FindFirstChild("FoundationFolder")
	if not foundation then return nil end

	for _, baseFolder in ipairs(foundation:GetChildren()) do
		local ownerVal = baseFolder:FindFirstChild("Owner")
		if ownerVal then
			local v = ownerVal.Value
			-- Nota: replicamos la lógica del servidor para soportar Owner como
			-- Instance, number o string y no depender de un único formato.
			if typeof(v) == "Instance" and v == player then
				return baseFolder
			end
			if typeof(v) == "number" and v == player.UserId then
				return baseFolder
			end
			if typeof(v) == "string" and tonumber(v) == player.UserId then
				return baseFolder
			end
		end
	end

	return nil
end

local function drawGrid(basePart, cellSize)
	gridFolder:ClearAllChildren()

	local baseSize = basePart.Size
	local basePos = basePart.Position
	local baseMinX = basePos.X - baseSize.X / 2
	local baseMinZ = basePos.Z - baseSize.Z / 2

	for x = 0, baseSize.X, cellSize do
		local line = Instance.new("Part")
		line.Size = Vector3.new(0.2, 0.1, baseSize.Z)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(255, 255, 255)
		line.Material = Enum.Material.Neon
		line.Position = Vector3.new(baseMinX + x, basePos.Y + baseSize.Y / 2 + 0.05, basePos.Z)
		line.Parent = gridFolder
	end

	for z = 0, baseSize.Z, cellSize do
		local line = Instance.new("Part")
		line.Size = Vector3.new(baseSize.X, 0.1, 0.2)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(255, 255, 255)
		line.Material = Enum.Material.Neon
		line.Position = Vector3.new(basePos.X, basePos.Y + baseSize.Y / 2 + 0.05, baseMinZ + z)
		line.Parent = gridFolder
	end
end

local function stopPlacement()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end

	if activeGhost then
		activeGhost:Destroy()
		activeGhost = nil
	end

	currentModelName = nil
	activeIsValid = false
	gridFolder:ClearAllChildren()
	currentRotation = 0
end

local function startPlacement(modelName)
	if activeGhost then
		stopPlacement()
	end

	local template = modelsFolder:FindFirstChild(modelName)
	if not template then return end

	local baseFolder = getPlayerBase()
	if not baseFolder then return end

	local basePart = baseFolder:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return end

	drawGrid(basePart, subGridSize)

	local ghost = template:Clone()
	for _, p in pairs(ghost:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Anchored = true
			p.Transparency = 0.5
			p.CastShadow = false
		end
	end

	if not ghost.PrimaryPart then
		for _, p in pairs(ghost:GetDescendants()) do
			if p:IsA("BasePart") then
				ghost.PrimaryPart = p
				break
			end
		end
	end

	if not ghost.PrimaryPart then return end

	ghost.Parent = workspace
	activeGhost = ghost
	currentModelName = modelName
	activeIsValid = false

	local ext = ghost:GetExtentsSize()
	local half = Vector3.new(ext.X / 2, ext.Y / 2, ext.Z / 2)
	local bsize = basePart.Size
	local baseHalf = Vector3.new(bsize.X / 2, bsize.Y / 2, bsize.Z / 2)
	local baseMin = basePart.Position - baseHalf
	local baseMax = basePart.Position + baseHalf
	local cost = ObjectCosts[modelName] or 0
	local snap = subGridSize

	renderConn = RunService.RenderStepped:Connect(function()
		local hit = mouse.Hit
		if not hit then return end

		local pos = hit.Position
		local relativeX = pos.X - baseMin.X
		local relativeZ = pos.Z - baseMin.Z
		local snappedRelX = math.round(relativeX / snap) * snap
		local snappedRelZ = math.round(relativeZ / snap) * snap
		local gridX = snappedRelX + baseMin.X
		local gridZ = snappedRelZ + baseMin.Z
		local y = basePart.Position.Y + baseHalf.Y + half.Y + 0.05
		local rotationCFrame = CFrame.Angles(0, currentRotation, 0)
		local finalCFrame = CFrame.new(gridX, y, gridZ) * rotationCFrame
		local rotatedExtents = activeGhost:GetExtentsSize()
		local rotatedHalf = rotatedExtents / 2

		-- Esta validación es visual/UX; la validación final la hace servidor.
		local valid = true
		if gridX - rotatedHalf.X < baseMin.X or gridX + rotatedHalf.X > baseMax.X or gridZ - rotatedHalf.Z < baseMin.Z or gridZ + rotatedHalf.Z > baseMax.Z then
			valid = false
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if valid and cost > 0 and (not coins or coins.Value < cost) then
			valid = false
		end

		activeIsValid = valid

		local green = Color3.fromRGB(0, 255, 0)
		local red = Color3.fromRGB(255, 0, 0)
		for _, p in pairs(activeGhost:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = valid and green or red
			end
		end

		activeGhost:SetPrimaryPartCFrame(finalCFrame)
	end)
end

for _, f in ipairs(scrollingFrame:GetChildren()) do
	if f:IsA("Frame") then
		local button = f:FindFirstChildWhichIsA("ImageButton") or f:FindFirstChildWhichIsA("TextButton")
		if button then
			button.Activated:Connect(function()
				startPlacement(f.Name)
			end)
		end
	end
end

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end

	if activeGhost and input.KeyCode == Enum.KeyCode.R then
		currentRotation = currentRotation + math.rad(90)
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if activeGhost and currentModelName and activeIsValid then
			local primary = activeGhost.PrimaryPart
			if primary then
				placeEvent:FireServer(currentModelName, primary.CFrame)
				stopPlacement()
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
		stopPlacement()
	end
end)
