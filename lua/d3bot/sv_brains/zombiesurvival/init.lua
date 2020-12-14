local BRAINS = D3bot.Brains

include("general.lua")

D3bot.AssignBrain = function(bot)
	local mem = bot.D3bot

	mem.Brain = BRAINS.General
	if mem.Brain.CreateCallback then
		mem.Brain.CreateCallback(bot)
	end
end
