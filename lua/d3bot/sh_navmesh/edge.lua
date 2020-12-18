AddCSLuaFile()

local D3bot = D3bot
local NAV_EDGE = D3bot.NAV_EDGE

-- Get new instance of an edge object with the two given points.
-- This represents an edge that at most can be shared by two triangles.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:New(p1, p2)
	local obj = {
		Points = {p1, p2}
	}

	setmetatable(obj, self)
	self.__this = self
	return obj
end

-- Returns wether the edge consists out of the two given points or not.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:ConsistsOfPoints(p1, p2)
	if self.Points[1] == p1 and self.Points[2] == p2 then return true end
	if self.Points[1] == p2 and self.Points[2] == p1 then return true end
	return false
end
