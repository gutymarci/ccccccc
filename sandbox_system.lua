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

local placeEvent = getRemoteEvent("PlaceObject")
local deleteEvent = getRemoteEvent("DeleteObject")

local modelsFolder = ReplicatedStorage:WaitForChild("Models")
local ObjectCosts = require(ReplicatedStorage:WaitForChild("ObjectCosts"))

local BASE_GRID_SIZE = 4
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


local function isPointWithinBase(basePart, point)
	local bsize = basePart.Size
	local baseHalf = Vector3.new(bsize.X / 2, bsize.Y / 2, bsize.Z / 2)
	local baseMin = basePart.Position - baseHalf
	local baseMax = basePart.Position + baseHalf
	return point.X >= baseMin.X and point.X <= baseMax.X
		and point.Z >= baseMin.Z and point.Z <= baseMax.Z
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
	if not template then
		warn(("Modelo '%s' no encontrado en Models (incluyendo subcarpetas)"):format(modelName))
		return false
	end

	local tempClone = template:Clone()
	local prim = ensurePrimaryPart(tempClone)
	if not prim then
		tempClone:Destroy()
		return false
	end


	local bboxCF, bboxSize = tempClone:GetBoundingBox()
	local bboxHalf = bboxSize / 2

	local baseTopY = basePart.Position.Y + basePart.Size.Y / 2
	local desiredCenterY = baseTopY + bboxHalf.Y


	local snappedXZ = snapPositionToGrid(basePart, cf.Position, SUB_GRID_SIZE)
	local desiredCenter = Vector3.new(snappedXZ.X, desiredCenterY, snappedXZ.Z)


	local desiredRot = cf.Rotation


	local bboxWorldCF = CFrame.new(desiredCenter) * desiredRot
	local corners = {
		bboxWorldCF * Vector3.new(-bboxHalf.X, -bboxHalf.Y, -bboxHalf.Z),
		bboxWorldCF * Vector3.new( bboxHalf.X, -bboxHalf.Y, -bboxHalf.Z),
		bboxWorldCF * Vector3.new(-bboxHalf.X, -bboxHalf.Y,  bboxHalf.Z),
		bboxWorldCF * Vector3.new( bboxHalf.X, -bboxHalf.Y,  bboxHalf.Z),
		bboxWorldCF * Vector3.new(-bboxHalf.X,  bboxHalf.Y, -bboxHalf.Z),
		bboxWorldCF * Vector3.new( bboxHalf.X,  bboxHalf.Y, -bboxHalf.Z),
		bboxWorldCF * Vector3.new(-bboxHalf.X,  bboxHalf.Y,  bboxHalf.Z),
		bboxWorldCF * Vector3.new( bboxHalf.X,  bboxHalf.Y,  bboxHalf.Z),
	}
	for _, corner in ipairs(corners) do
		if not isPointWithinBase(basePart, corner) then
			tempClone:Destroy()
			return false
		end
	end

	-- Verificar solapamiento con objetos ya colocados
	local placedFolder = base:FindFirstChild("PlacedFolder")
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { player.Character, basePart }

	local partsInArea = workspace:GetPartBoundsInBox(bboxWorldCF, bboxSize, overlapParams)
	for _, part in ipairs(partsInArea) do
		if placedFolder and part:IsDescendantOf(placedFolder) then
			tempClone:Destroy()
			return false
		end
	end

	-- Coste y monedas
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

	-- Crear la carpeta si no existe
	if not placedFolder then
		placedFolder = Instance.new("Folder")
		placedFolder.Name = "PlacedFolder"
		placedFolder.Parent = base
	end


	local relativeToBBox = prim.CFrame:ToObjectSpace(bboxCF) 
	local newPrimaryCF = CFrame.new(desiredCenter) * desiredRot * relativeToBBox:Inverse()

	-- Colocar el modelo
	tempClone.Parent = placedFolder
	tempClone:SetPrimaryPartCFrame(newPrimaryCF)
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
