AddCSLuaFile()

local D3bot = D3bot
local UTIL = D3bot.Util

function UTIL.GetUsernamesMap()
	local usernames = {}
	for _, ply in pairs(player.GetAll()) do
		usernames[ply:Nick()] = ply
	end
	return usernames
end

function UTIL.ResumeCoroutine(bot, mem, co)
	if not co then
		return false
	end

	local succ, msg = coroutine.resume(co)
	if not succ then
		if msg and msg ~= "cannot resume dead coroutine" then -- There is no way to cleanly determine if a coroutine ended because of an error or not
			print(string.format("%s %s of bot %s failed: %s", D3bot.PrintPrefix, co, bot:Nick(), msg))
		end
		return false
	end

	return true
end

-- Floors the coordinates of a vector
function UTIL.FloorVector(vec)
	return Vector(math.floor(vec[1]), math.floor(vec[2]), math.floor(vec[3]))
end

-- Round the coordinates of a vector
function UTIL.RoundVector(vec)
	return Vector(math.floor(vec[1] + 0.5), math.floor(vec[2] + 0.5), math.floor(vec[3] + 0.5))
end
