--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

local Players = game:GetService("Players")

local teamMembers = {
	[164483312] = true,
	[110764284] = true,
	[1115809999] = true,
	[1656306734] = true,
	[309702945] = true,
}

Players.PlayerAdded:Connect(function(player)
	if teamMembers[player.UserId] then
		player:SetAttribute("ChatTag", "[DEV]")
		player:SetAttribute("ChatTagColor", "#1E90FF")
	else
		player:SetAttribute("ChatTag", nil)
		player:SetAttribute("ChatTagColor", nil)
	end
end)
