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
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
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
local ObjectImages = require(ReplicatedStorage:WaitForChild("ObjectImages"))

if not placeEvent then
	warn("[Sandbox] PlaceObject remote not found")
	return
end
if not deleteEvent then
	warn("[Sandbox] DeleteObject remote not found")
	return
end

local function findModelTemplate(modelName)
	if type(modelName) ~= "string" then return nil end
	local found = modelsFolder:FindFirstChild(modelName, true)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Preload images to ensure they're loaded before UI is complete
local imagesToPreload = {}
for _, model in ipairs(modelsFolder:GetChildren()) do
	local modelName = model.Name
	local imageId = ObjectImages[modelName]
	if imageId and imageId ~= "" then
		table.insert(imagesToPreload, imageId)
	end
end

if #imagesToPreload > 0 then
	ContentProvider:PreloadAsync(imagesToPreload)
end

local gui = script.Parent
if not gui or not gui:IsA("ScreenGui") then
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BuildModeMenu")
end

local frame = gui:WaitForChild("Frame")
local scrollingDropper = frame:WaitForChild("ScrollingDropper")
local scrollingObject = frame:FindFirstChild("ScrollingObject")

local deleteButton = gui:FindFirstChild("Delete")
local copyButton = gui:FindFirstChild("Copy")
local moveButton = gui:FindFirstChild("Move")
local paintButton = gui:FindFirstChild("Paint")

local mouse = player:GetMouse()

-- Variables de estado
local activeGhost, currentModelName, renderConn, activeIsValid = nil, nil, nil, false
local currentRotation = 0
local activeToolMode = "place"
local selectedModel = nil
local selectedHighlight = nil

local gridFolder = Instance.new("Folder")
gridFolder.Name = "PlacementGrid"
gridFolder.Parent = workspace

local BASE_GRID_SIZE = 4
local SUB_GRID_SIZE = BASE_GRID_SIZE / 2

local function isBuildModeEnabled()
	return gui.Enabled
end

local function getPlayerBase()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local foundation = map:FindFirstChild("FoundationFolder")
	if not foundation then return nil end
	for _, baseFolder in ipairs(foundation:GetChildren()) do
		local ownerUserId = baseFolder:GetAttribute("OwnerUserId")
		if type(ownerUserId) == "number" and ownerUserId == player.UserId then
			return baseFolder
		end
	end
	return nil
end

local function clearSelection()
	selectedModel = nil
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
end

local function resolvePlacedModelFromTarget(target)
	if not target then return nil end
	local baseFolder = getPlayerBase()
	if not baseFolder then return nil end
	local placedFolder = baseFolder:FindFirstChild("PlacedFolder")
	if not placedFolder then return nil end
	local model = target:FindFirstAncestorOfClass("Model")
	if model and model:IsDescendantOf(placedFolder) then
		return model
	end
	return nil
end

local function selectModel(model)
	clearSelection()
	if not model then return end
	selectedModel = model
	selectedHighlight = Instance.new("Highlight")
	selectedHighlight.Name = "DeleteSelectionHighlight"
	selectedHighlight.FillColor = Color3.fromRGB(55, 125, 255)
	selectedHighlight.FillTransparency = 0.75
	selectedHighlight.OutlineColor = Color3.fromRGB(95, 170, 255)
	selectedHighlight.OutlineTransparency = 0
	selectedHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	selectedHighlight.Adornee = selectedModel
	selectedHighlight.Parent = selectedModel
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

local function setToolMode(newMode)
	activeToolMode = newMode
	if newMode ~= "place" then
		stopPlacement()
	end
	if newMode ~= "delete" then
		clearSelection()
	end
end

local function isDeleteMode()
	return activeToolMode == "delete"
end

local function resolveModelName(uiElement)
	local attrName = uiElement:GetAttribute("ModelName")
	if attrName and findModelTemplate(attrName) then
		return attrName
	end

	if uiElement:IsA("TextLabel") and uiElement.Text then
		local text = uiElement.Text
		if findModelTemplate(text) then
			return text
		end
	end

	if findModelTemplate(uiElement.Name) then
		return uiElement.Name
	end

	local parent = uiElement.Parent
	if parent and parent:IsA("Frame") and findModelTemplate(parent.Name) then
		return parent.Name
	end

	return nil
end

local function startPlacement(modelName)
	if not isBuildModeEnabled() then return end
	if activeGhost then stopPlacement() end
	setToolMode("place")

	local template = findModelTemplate(modelName)
	if not template then return end

	local baseFolder = getPlayerBase()
	if not baseFolder then return end
	local basePart = baseFolder:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return end

	drawGrid(basePart, SUB_GRID_SIZE)

	local ghost = template:Clone()
	if not ghost.PrimaryPart then
		for _, p in ipairs(ghost:GetDescendants()) do
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
	local baseSize = basePart.Size
	local baseHalf = Vector3.new(baseSize.X / 2, baseSize.Y / 2, baseSize.Z / 2)
	local baseMin = basePart.Position - baseHalf
	local baseMax = basePart.Position + baseHalf
	local cost = ObjectCosts[modelName] or 0

	renderConn = RunService.RenderStepped:Connect(function()
		if not isBuildModeEnabled() then
			stopPlacement()
			return
		end
		local hit = mouse.Hit
		if not hit then return end

		local pos = hit.Position
		local relX = pos.X - baseMin.X
		local relZ = pos.Z - baseMin.Z
		local snapX = math.round(relX / SUB_GRID_SIZE) * SUB_GRID_SIZE + baseMin.X
		local snapZ = math.round(relZ / SUB_GRID_SIZE) * SUB_GRID_SIZE + baseMin.Z

		local y = basePart.Position.Y + baseHalf.Y + half.Y + 0.05
		local rotationCFrame = CFrame.Angles(0, currentRotation, 0)
		local finalCFrame = CFrame.new(snapX, y, snapZ) * rotationCFrame

		local rotatedExtents = activeGhost:GetExtentsSize()
		local rotatedHalf = rotatedExtents / 2
		local valid = true

		if snapX - rotatedHalf.X < baseMin.X or snapX + rotatedHalf.X > baseMax.X or snapZ - rotatedHalf.Z < baseMin.Z or snapZ + rotatedHalf.Z > baseMax.Z then
			valid = false
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if valid and cost > 0 and (not coins or coins.Value < cost) then
			valid = false
		end

		local placedFolder = baseFolder:FindFirstChild("PlacedFolder")
		if valid and placedFolder then
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			overlapParams.FilterDescendantsInstances = { placedFolder }
			local parts = workspace:GetPartBoundsInBox(finalCFrame, rotatedExtents, overlapParams)
			if #parts > 0 then
				valid = false
			end
		end

		activeIsValid = valid
		for _, p in ipairs(activeGhost:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = valid and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
			end
		end
		activeGhost:SetPrimaryPartCFrame(finalCFrame)
	end)
end

local function populateScrollFromFolder(scrollFrame, folderName)
	scrollFrame:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.Parent = scrollFrame
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 0)

	local function updateCanvas()
		local totalWidth = 0
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("GuiObject") and child ~= layout then
				totalWidth = totalWidth + child.AbsoluteSize.X + layout.Padding.Offset
			end
		end
		scrollFrame.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

	local folder = modelsFolder:FindFirstChild(folderName)
	if not folder then
		warn("No se encontró la carpeta:", folderName)
		return
	end

	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local modelName = model.Name
			local cost = ObjectCosts[modelName] or 0
			local imageId = ObjectImages[modelName] or ""

			local itemFrame = Instance.new("Frame")
			itemFrame.Name = modelName
			itemFrame.Size = UDim2.new(0, 120, 0, 140)
			itemFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			itemFrame.BackgroundTransparency = 0.5
			itemFrame.Parent = scrollFrame

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 21)
			corner.Parent = itemFrame

			local imageButton = Instance.new("ImageButton")
			imageButton.Name = "ImageButton"
			imageButton.Size = UDim2.new(0.601, 0, 0.601, 0)
			imageButton.Position = UDim2.new(0.199, 0, 0.199, 0)
			imageButton.BackgroundTransparency = 1
			imageButton.BorderSizePixel = 0
			imageButton.Image = imageId
			imageButton.ScaleType = Enum.ScaleType.Fit
			imageButton.Parent = itemFrame

			imageButton.Activated:Connect(function()
				startPlacement(modelName)
			end)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "NameLabel"
			nameLabel.Size = UDim2.new(0.953, 0, 0.248, 0)
			nameLabel.Position = UDim2.new(0.043, 0, -0.01, 0)
			nameLabel.Text = modelName
			nameLabel.TextColor3 = Color3.fromRGB(31, 114, 238)
			nameLabel.BackgroundTransparency = 1
			nameLabel.BorderSizePixel = 0
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.SourceSansBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Center
			nameLabel.TextYAlignment = Enum.TextYAlignment.Center
			nameLabel.Parent = itemFrame

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Name = "PriceLabel"
			priceLabel.Size = UDim2.new(0.953, 0, 0.248, 0)
			priceLabel.Position = UDim2.new(0.014, 0, 0.748, 0)
			priceLabel.Text = "$" .. tostring(cost)
			priceLabel.TextColor3 = Color3.fromRGB(31, 114, 238)
			priceLabel.BackgroundTransparency = 1
			priceLabel.BorderSizePixel = 0
			priceLabel.TextScaled = true
			priceLabel.TextSize = 14
			priceLabel.Font = Enum.Font.SourceSansBold
			priceLabel.TextWrapped = true
			priceLabel.TextXAlignment = Enum.TextXAlignment.Center
			priceLabel.TextYAlignment = Enum.TextYAlignment.Center
			priceLabel.Parent = itemFrame
		end
	end

	task.wait()
	updateCanvas()
end

populateScrollFromFolder(scrollingDropper, "Marble Droppers")
if scrollingObject then
	populateScrollFromFolder(scrollingObject, "Decorations")
end

local function connectContainer(container)
	for _, ui in ipairs(container:GetDescendants()) do
		if ui:IsA("ImageButton") or ui:IsA("TextButton") then
			ui.Activated:Connect(function()
				local modelName = resolveModelName(ui)
				if modelName then startPlacement(modelName) end
			end)
		elseif ui:IsA("TextLabel") then
			ui.Active = true
			ui.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					local modelName = resolveModelName(ui)
					if modelName then startPlacement(modelName) end
				end
			end)
		end
	end
end

connectContainer(scrollingDropper)
if scrollingObject then
	connectContainer(scrollingObject)
end

local categoryMap = {
	["Marble Droppers"] = scrollingDropper,
	["Decorations"] = scrollingObject
}

for _, child in ipairs(gui:GetDescendants()) do
	if child:IsA("TextButton") then
		local buttonText = child.Text
		if buttonText and categoryMap[buttonText] then
			child.Activated:Connect(function()
				scrollingDropper.Visible = false
				if scrollingObject then scrollingObject.Visible = false end
				local targetScroll = categoryMap[buttonText]
				if targetScroll then
					targetScroll.Visible = true
				end
				stopPlacement()
				setToolMode("place")
			end)
		end
	end
end

local function connectToolButton(button, modeName)
	if not button then return end
	if not button:IsA("TextButton") then return end
	button.Activated:Connect(function()
		if not isBuildModeEnabled() then return end
		if activeToolMode == modeName then
			setToolMode("place")
		else
			setToolMode(modeName)
		end
	end)
end

connectToolButton(deleteButton, "delete")
connectToolButton(copyButton, "copy")
connectToolButton(moveButton, "move")
connectToolButton(paintButton, "paint")

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not isBuildModeEnabled() then
		stopPlacement()
		setToolMode("place")
	end
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not isBuildModeEnabled() then
		stopPlacement()
		setToolMode("place")
		return
	end

	if activeGhost and input.KeyCode == Enum.KeyCode.R then
		currentRotation += math.rad(90)
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isDeleteMode() then
			local selected = resolvePlacedModelFromTarget(mouse.Target)
			if selected then
				selectModel(selected)
			else
				clearSelection()
			end
			return
		end
		if activeGhost and currentModelName and activeIsValid then
			local primary = activeGhost.PrimaryPart
			if primary then
				placeEvent:FireServer(currentModelName, primary.CFrame)
				stopPlacement()
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Delete then
		if isDeleteMode() and selectedModel then
			local baseFolder = getPlayerBase()
			local placedFolder = baseFolder and baseFolder:FindFirstChild("PlacedFolder")
			if placedFolder and selectedModel:IsDescendantOf(placedFolder) then
				deleteEvent:FireServer(selectedModel)
				clearSelection()
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
		stopPlacement()
		setToolMode("place")
	end
end)
