local D3bot = D3bot
local UTIL = D3bot.Util

function D3bot.GetBotName()
	local name = "D3bot"

	-- Check if the username already exists
	local usernames = UTIL.GetUsernamesMap()
	if usernames[name] then
		local number = 2
		while usernames[string.format("%s %i", name, number)] do
			number = number + 1
		end
		return string.format("%s %i", name, number)
	end

	return name
end
