--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarbleDropper = {}

local FINAL_SIZE = Vector3.new(0.925, 0.925, 0.925)
local START_SIZE = Vector3.new(0.1, 0.1, 0.1)
local GROW_SPEED = 0.02
local GROW_STEP_WAIT = 0.03

local marbleTemplate = ReplicatedStorage:WaitForChild("Marble")

function MarbleDropper.CreateMarble(dropperModel)
	if not dropperModel or not dropperModel:IsA("Model") then
		return nil
	end

	local spawnPart = dropperModel:FindFirstChild("Spawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return nil
	end

	local marble = marbleTemplate:Clone()
	marble.Parent = workspace
	marble.CFrame = spawnPart.CFrame
	marble.Size = START_SIZE
	marble.Anchored = true

	while marble.Size.X < FINAL_SIZE.X do
		local nextX = math.min(marble.Size.X + GROW_SPEED, FINAL_SIZE.X)
		local nextY = math.min(marble.Size.Y + GROW_SPEED, FINAL_SIZE.Y)
		local nextZ = math.min(marble.Size.Z + GROW_SPEED, FINAL_SIZE.Z)
		marble.Size = Vector3.new(nextX, nextY, nextZ)
		task.wait(GROW_STEP_WAIT)
	end

	marble.Size = FINAL_SIZE
	marble.Anchored = false

	return marble
end

return MarbleDropper
