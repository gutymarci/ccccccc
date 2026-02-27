local DropperRewards = {}

DropperRewards.ValuesByType = {
	["Dropper1"] = 1,
	-- ["Dropper2"] = 3,
	-- ["Dropper3"] = 5,
	-- ["Dropper4"] = 8,
	-- ["Dropper5"] = 12,
}

DropperRewards.DefaultReward = 0

local function normalizeDropperType(value)
	if type(value) ~= "string" then
		return nil
	end

	local number = string.match(value, "^Dropper%s*(%d+)$")
	if number then
		return "Dropper" .. number
	end

	if value == "Dropper" then
		return "Dropper1"
	end

	return value
end

function DropperRewards.GetDropperType(dropperModel)
	if typeof(dropperModel) ~= "Instance" or not dropperModel:IsA("Model") then
		return nil
	end

	local explicitType = dropperModel:GetAttribute("DropperType")
	local normalizedExplicit = normalizeDropperType(explicitType)
	if normalizedExplicit then
		return normalizedExplicit
	end

	return normalizeDropperType(dropperModel.Name)
end

function DropperRewards.GetRewardByType(dropperType)
	if type(dropperType) ~= "string" then
		return DropperRewards.DefaultReward
	end

	local reward = DropperRewards.ValuesByType[dropperType]
	if type(reward) == "number" then
		return reward
	end

	return DropperRewards.DefaultReward
end

function DropperRewards.GetRewardForDropper(dropperModel)
	local dropperType = DropperRewards.GetDropperType(dropperModel)
	return DropperRewards.GetRewardByType(dropperType)
end

return DropperRewards
