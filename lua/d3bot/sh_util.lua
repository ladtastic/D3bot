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

-- Realm bitmasks
UTIL.REALM_SERVER = 1 -- 0b01
UTIL.REALM_CLIENT = 2 -- 0b10
UTIL.REALM_SHARED = 3 -- 0b11

-- Include a lua file into the given realm.
-- The usage of any AddCSLuaFile() is not necessary.
-- This helper must be run in the "shared" realm to work properly.
-- - UTIL.REALM_SERVER: The file will only be included on the server side.
-- - UTIL.REALM_CLIENT: The file will only be included on the client side. Additionally the file will be marked with AddCSLuaFile.
-- - UTIL.REALM_SHARED: The file will only be included on both sides. Additionally the file will be marked with AddCSLuaFile.
function UTIL.IncludeRealm(path, realm) -- TODO: Add function that determines realm by filename/path
	if realm == UTIL.REALM_SERVER then
		if SERVER then include(path) end
	elseif realm == UTIL.REALM_CLIENT then
		if SERVER then AddCSLuaFile(path) end
		if CLIENT then include(path) end
	elseif realm == UTIL.REALM_SHARED then
		if SERVER then AddCSLuaFile(path) end
		include(path)
	else
		error("Invalid realm")
	end
end

-- Includes all (lua) files in the given directory path + filename into a specific realm.
-- The path must be absolute (relative to the lua directory), and the filename can contain * wildcards.
-- Example: UTIL.IncludeDirectory("foo/bar/", "sv_*.lua", UTIL.REALM_SERVER)
function UTIL.IncludeDirectory(path, name, realm)
	local filenames, _ = file.Find(path .. name, "LUA")
	for _, filename in ipairs(filenames) do
		UTIL.IncludeRealm(path .. filename, realm)
	end
end

-- Sorted version of pairs: This will iterate in ascending key order over any map/sparse array.
function UTIL.kpairs(m)
	-- Get keys of m
	local keys = {}
	for k in pairs(m) do
		table.insert(keys, k)
	end

	-- Sort keys
	table.sort(keys)

	-- Return iterator
	local i = 0
	return function()
		i = i + 1
		local key = keys[i]
		if key then
			return key, m[key]
		end
	end
end

-- Returns the closest point from the list points to a given point p with a radius r.
-- If no point is found, nil will be returned.
function UTIL.GetNearestPoint(points, p, r)
	-- Stupid linear search for the closest point
	local minDistSqr = (r and r * r) or math.huge
	local resultPoint
	for _, point in pairs(points) do -- Needs to be pairs, as it needs to support sparse arrays/maps
		local distSqr = p:DistToSqr(point)
		if minDistSqr > distSqr then
			minDistSqr = distSqr
			resultPoint = point
		end
	end

	return resultPoint
end
