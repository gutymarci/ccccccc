--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local placeEvent = ReplicatedStorage:FindFirstChild("PlaceObject") or ReplicatedStorage:FindFirstChild("PlaceObjectEvent")
if not placeEvent then
	placeEvent = Instance.new("RemoteEvent")
	placeEvent.Name = "PlaceObject"
	placeEvent.Parent = ReplicatedStorage
end

local modelsFolder = ReplicatedStorage:WaitForChild("Models")
local ObjectCosts = require(ReplicatedStorage:WaitForChild("ObjectCosts"))
local placementStore = DataStoreService:GetDataStore("PlacementData")

-- Debe coincidir con el LocalScript: baseGridSize = 8 y subGridSize = 4.
local BASE_GRID_SIZE = 8
local SUB_GRID_SIZE = BASE_GRID_SIZE / 2

local function ensurePrimaryPart(model)
	if model.PrimaryPart then return model.PrimaryPart end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			model.PrimaryPart = p
			return p
		end
	end
	return nil
end

local function getFoundationFolder()
	local m = workspace:FindFirstChild("Map")
	if not m then return nil end
	return m:FindFirstChild("FoundationFolder")
end

local function getPlayerBase(player)
	local foundation = getFoundationFolder()
	if not foundation then return nil end
	for _, baseFolder in ipairs(foundation:GetChildren()) do
		local ownerVal = baseFolder:FindFirstChild("Owner")
		if ownerVal then
			local v = ownerVal.Value
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

local function isPosWithinBase(basePart, halfSize, pos)
	local bsize = basePart.Size
	local baseHalf = Vector3.new(bsize.X / 2, bsize.Y / 2, bsize.Z / 2)
	local baseMin = basePart.Position - baseHalf
	local baseMax = basePart.Position + baseHalf
	if pos.X - halfSize.X < baseMin.X then return false end
	if pos.X + halfSize.X > baseMax.X then return false end
	if pos.Z - halfSize.Z < baseMin.Z then return false end
	if pos.Z + halfSize.Z > baseMax.Z then return false end
	return true
end

local function snapPositionToGrid(basePart, pos, gridSize)
	local bsize = basePart.Size
	local baseHalf = Vector3.new(bsize.X / 2, bsize.Y / 2, bsize.Z / 2)
	local baseMin = basePart.Position - baseHalf

	-- IMPORTANTE: ignoramos la posición cruda enviada por el cliente y la
	-- recalculamos con snap en servidor para prevenir exploits.
	local relX = pos.X - baseMin.X
	local relZ = pos.Z - baseMin.Z
	local snappedX = math.round(relX / gridSize) * gridSize + baseMin.X
	local snappedZ = math.round(relZ / gridSize) * gridSize + baseMin.Z

	return Vector3.new(snappedX, pos.Y, snappedZ)
end

local function placeModel(player, modelName, cf, charge)
	if type(modelName) ~= "string" then return false end
	if typeof(cf) ~= "CFrame" then return false end
	local base = getPlayerBase(player)
	if not base then return false end
	local basePart = base:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return false end
	local template = modelsFolder:FindFirstChild(modelName)
	if not template then return false end
	local tempClone = template:Clone()
	local prim = ensurePrimaryPart(tempClone)
	if not prim then
		tempClone:Destroy()
		return false
	end
	local ext = tempClone:GetExtentsSize()
	local half = Vector3.new(ext.X / 2, ext.Y / 2, ext.Z / 2)
	-- Nunca usamos la posición directa del cliente: primero hacemos snap server-side.
	local snappedPos = snapPositionToGrid(basePart, cf.Position, SUB_GRID_SIZE)
	if not isPosWithinBase(basePart, half, snappedPos) then
		tempClone:Destroy()
		return false
	end
	local cost = ObjectCosts[modelName] or 0
	if charge == nil then charge = true end
	if charge and cost > 0 then
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			tempClone:Destroy()
			return false
		end
		local coins = leaderstats:FindFirstChild("Coins")
		if not coins or coins.Value < cost then
			tempClone:Destroy()
			return false
		end
		coins.Value = coins.Value - cost
	end
	local finalPos = Vector3.new(snappedPos.X, basePart.Position.Y + (basePart.Size.Y / 2) + half.Y, snappedPos.Z)
	local finalCFrame = CFrame.new(finalPos, finalPos + cf.LookVector)
	local placedFolder = base:FindFirstChild("PlacedFolder")

	-- 🔒 Anti superposición (anti overlap): solo bloqueamos cuando invade
	-- objetos YA colocados en PlacedFolder (no el piso/base de la parcela).
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { player.Character, basePart }

	local partsInArea = workspace:GetPartBoundsInBox(finalCFrame, ext, overlapParams)
	for _, part in ipairs(partsInArea) do
		if placedFolder and part:IsDescendantOf(placedFolder) then
			tempClone:Destroy()
			return false
		end
	end

	for _, p in pairs(tempClone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
			p.Transparency = 0
		end
	end
	if not placedFolder then
		placedFolder = Instance.new("Folder")
		placedFolder.Name = "PlacedFolder"
		placedFolder.Parent = base
	end
	tempClone.Parent = placedFolder
	tempClone:SetPrimaryPartCFrame(finalCFrame)
	return true
end

placeEvent.OnServerEvent:Connect(function(player, modelName, cf)
	placeModel(player, modelName, cf, true)
end)

local function serializeCFrame(cf)
	return { cf:GetComponents() }
end

local function deserializeCFrame(tbl)
	if type(tbl) ~= "table" then return nil end
	return CFrame.new(table.unpack(tbl))
end

Players.PlayerAdded:Connect(function(player)
	local ok, data = pcall(function()
		return placementStore:GetAsync(tostring(player.UserId))
	end)
	if ok and type(data) == "table" then
		print("Loading plot for", player.Name)
		task.spawn(function()
			local waited = 0
			local base
			repeat
				base = getPlayerBase(player)
				if base then break end
				task.wait(0.2)
				waited = waited + 0.2
			until waited >= 10
			if base then
				local placedFolder = base:FindFirstChild("PlacedFolder")
				if placedFolder then placedFolder:ClearAllChildren() end
				for _, entry in ipairs(data) do
					if type(entry) == "table" and entry.Name and entry.CFrame then
						local cf = deserializeCFrame(entry.CFrame)
						if cf then
							placeModel(player, entry.Name, cf, false)
						end
					end
				end
				print("Finished loading plot for", player.Name)
			else
				print("Failed to find base for", player.Name, "during load")
			end
		end)
	else
		print("No saved plot for", player.Name)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local base = getPlayerBase(player)
	if not base then
		pcall(function()
			placementStore:RemoveAsync(tostring(player.UserId))
		end)
		print("Removed empty plot data for", player.Name)
		return
	end
	local placedFolder = base:FindFirstChild("PlacedFolder")
	if not placedFolder then
		pcall(function()
			placementStore:RemoveAsync(tostring(player.UserId))
		end)
		print("Removed empty plot data for", player.Name)
		return
	end
	local saveData = {}
	for _, obj in ipairs(placedFolder:GetChildren()) do
		if obj.PrimaryPart then
			local cf = obj:GetPrimaryPartCFrame()
			table.insert(saveData, { Name = obj.Name, CFrame = serializeCFrame(cf) })
		end
	end
	pcall(function()
		placementStore:SetAsync(tostring(player.UserId), saveData)
	end)
	print("Saved plot for", player.Name, "with", #saveData, "objects")
	placedFolder:ClearAllChildren()
end)
