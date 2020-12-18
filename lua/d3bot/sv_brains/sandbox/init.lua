include("general.lua")

local D3bot = D3bot
local BRAINS = D3bot.Brains

-- Assigns a suitable brain to the bot
function D3bot.AssignBrain(bot, mem)
	-- Assign default brain
	BRAINS.General(bot, mem)
end
