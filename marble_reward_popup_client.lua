--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

-- LocalScript (StarterPlayerScripts recomendado)
-- Muestra un popup encima de cada marble cuando el servidor marca su recompensa.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local POPUP_DURATION = 0.9
local FLOAT_OFFSET = Vector3.new(0, 3, 0)

local function showRewardPopup(marble, reward)
	if typeof(marble) ~= "Instance" or not marble:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MarbleRewardPopup"
	billboard.Adornee = marble
	billboard.Size = UDim2.fromOffset(120, 50)
	billboard.StudsOffset = FLOAT_OFFSET
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = marble

	local label = Instance.new("TextLabel")
	label.Name = "RewardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = ("+$%d"):format(reward)
	label.TextColor3 = Color3.fromRGB(74, 255, 87)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local fadeTween = TweenService:Create(label, TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	local moveTween = TweenService:Create(billboard, TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = FLOAT_OFFSET + Vector3.new(0, 1.5, 0),
	})

	fadeTween:Play()
	moveTween:Play()

	task.delay(POPUP_DURATION + 0.05, function()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end

local function connectMarble(marble)
	if typeof(marble) ~= "Instance" or not marble:IsA("BasePart") then
		return
	end

	local function onRewardChanged()
		local reward = marble:GetAttribute("CoinReward")
		if type(reward) == "number" and reward > 0 then
			showRewardPopup(marble, reward)
		end
	end

	marble:GetAttributeChangedSignal("CoinReward"):Connect(onRewardChanged)
	onRewardChanged()
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj.Name == "Marble" and obj:IsA("BasePart") then
		connectMarble(obj)
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj.Name == "Marble" and obj:IsA("BasePart") then
		connectMarble(obj)
	end
end)
