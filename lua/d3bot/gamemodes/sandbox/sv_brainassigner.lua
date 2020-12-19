local D3bot = D3bot
local BRAINS = D3bot.Brains

-- Assigns a suitable brain to the bot.
function D3bot.AssignBrain(bot, mem)
	-- Assign a GENERAL brain by default.
	BRAINS.GENERAL:AssignToBot(bot, mem)
end
