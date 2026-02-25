--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

-- Sandbox System (servidor)
-- Rotación: la decide cliente al enviar CFrame.
-- Validación: siempre en servidor.
-- Guardado: se agrega después (sin DataStore por ahora).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local secureRemotesFolder = ReplicatedStorage:FindFirstChild("SecureRemotes")

local function getRemoteEvent(remoteName)
	if secureRemotesFolder then
		local inSecure = secureRemotesFolder:FindFirstChild(remoteName)
		if inSecure and inSecure:IsA("RemoteEvent") then
			return inSecure
		end
	end

	local inRoot = ReplicatedStorage:FindFirstChild(remoteName)
	if inRoot and inRoot:IsA("RemoteEvent") then
		return inRoot
	end

	return nil
end

-- Nombres canónicos según tu setup.
local placeEvent = getRemoteEvent("PlaceObject")
local deleteEvent = getRemoteEvent("DeleteObject")

if not placeEvent then
	warn("[SandboxServer] RemoteEvent missing: PlaceObject")
	return
end
if not deleteEvent then
	warn("[SandboxServer] RemoteEvent missing: DeleteObject")
	return
end

local modelsFolder = ReplicatedStorage:WaitForChild("Models")
local ObjectCosts = require(ReplicatedStorage:WaitForChild("ObjectCosts"))

local BASE_GRID_SIZE = 8
local SUB_GRID_SIZE = BASE_GRID_SIZE / 2

local function findModelTemplate(modelName)
	if type(modelName) ~= "string" then return nil end
	local found = modelsFolder:FindFirstChild(modelName, true)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

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
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	return map:FindFirstChild("FoundationFolder")
end

local function getPlayerBase(player)
	local foundation = getFoundationFolder()
	if not foundation then return nil end

	for _, baseFolder in ipairs(foundation:GetChildren()) do
		local ownerUserId = baseFolder:GetAttribute("OwnerUserId")
		if type(ownerUserId) == "number" and ownerUserId == player.UserId then
			return baseFolder
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

	local relX = pos.X - baseMin.X
	local relZ = pos.Z - baseMin.Z
	local snappedX = math.round(relX / gridSize) * gridSize + baseMin.X
	local snappedZ = math.round(relZ / gridSize) * gridSize + baseMin.Z

	return Vector3.new(snappedX, pos.Y, snappedZ)
end

local function placeModel(player, modelName, cf)
	if type(modelName) ~= "string" then return false end
	if typeof(cf) ~= "CFrame" then return false end

	local base = getPlayerBase(player)
	if not base then return false end

	local basePart = base:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return false end

	local template = findModelTemplate(modelName)
	if not template then return false end

	local tempClone = template:Clone()
	local prim = ensurePrimaryPart(tempClone)
	if not prim then
		tempClone:Destroy()
		return false
	end

	local ext = tempClone:GetExtentsSize()
	local half = Vector3.new(ext.X / 2, ext.Y / 2, ext.Z / 2)

	-- Anti exploit: nunca confiar en la posición cruda del cliente.
	local snappedPos = snapPositionToGrid(basePart, cf.Position, SUB_GRID_SIZE)
	if not isPosWithinBase(basePart, half, snappedPos) then
		tempClone:Destroy()
		return false
	end

	local cost = ObjectCosts[modelName] or 0
	if cost > 0 then
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if not coins or coins.Value < cost then
			tempClone:Destroy()
			return false
		end
		coins.Value -= cost
	end

	local finalPos = Vector3.new(snappedPos.X, basePart.Position.Y + (basePart.Size.Y / 2) + half.Y, snappedPos.Z)
	local finalCFrame = CFrame.new(finalPos, finalPos + cf.LookVector)
	local placedFolder = base:FindFirstChild("PlacedFolder")

	-- Anti-overlap: no permitir superposición con objetos ya colocados.
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

	for _, p in ipairs(tempClone:GetDescendants()) do
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

local function deletePlacedModel(player, candidate)
	if typeof(candidate) ~= "Instance" then return false end
	if not candidate:IsA("Model") then return false end

	local base = getPlayerBase(player)
	if not base then return false end

	local placedFolder = base:FindFirstChild("PlacedFolder")
	if not placedFolder then return false end

	if not candidate:IsDescendantOf(placedFolder) then
		return false
	end

	candidate:Destroy()
	return true
end

placeEvent.OnServerEvent:Connect(function(player, modelName, cf)
	placeModel(player, modelName, cf)
end)

deleteEvent.OnServerEvent:Connect(function(player, modelInstance)
	deletePlacedModel(player, modelInstance)
end)
