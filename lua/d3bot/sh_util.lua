AddCSLuaFile()

local D3bot = D3bot
local UTIL = D3bot.Util

-- Get a map with all currently used usernames (ply:Nick() of all players).
function UTIL.GetUsernamesMap()
	local usernames = {}
	for _, ply in pairs(player.GetAll()) do
		usernames[ply:Nick()] = ply
	end
	return usernames
end

-- Floors the coordinates of a vector
function UTIL.FloorVector(vec)
	return Vector(math.floor(vec[1]), math.floor(vec[2]), math.floor(vec[3]))
end

-- Round the coordinates of a vector
function UTIL.RoundVector(vec)
	return Vector(math.floor(vec[1] + 0.5), math.floor(vec[2] + 0.5), math.floor(vec[3] + 0.5))
end

-- Includes all (lua) files in the given directory path + filename.
-- The path must be absolute (relative to the lua directory), and the filename can contain * wildcards.
-- If the bool `onlyAddCS` is true, files will only be marked for client side download. They need to be inlcuded on the client side, too.
-- Example: UTIL.IncludeDirectory("foo/bar/", "*.lua", false)
function UTIL.IncludeDirectory(path, name, onlyAddCS)
	local filenames, _ = file.Find(path .. name, "LUA")
	for _, filename in ipairs(filenames) do
		if onlyAddCS then
			AddCSLuaFile(path .. filename)
		else
			include(path .. filename)
		end
	end
end
