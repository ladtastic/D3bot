local D3bot = D3bot
local UTIL = D3bot.Util

UTIL.GetUsernamesMap = function()
	local usernames = {}
	for _, ply in pairs(player.GetAll()) do
		usernames[ply:Nick()] = ply
	end
	return usernames
end

UTIL.ResumeCoroutine = function(bot, mem, co)
	if not co then
		return false
	end

	succ, msg = coroutine.resume(co)
	if not succ then
		if msg and msg ~= "cannot resume dead coroutine" then -- There is no way to cleanly determine if a coroutine ended because of an error or not
			print(string.format("%s %s of bot %s failed: %s", D3bot.PrintPrefix, co, bot:Nick(), msg))
		end
		return false
	end

	return true
end
