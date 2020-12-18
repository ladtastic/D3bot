AddCSLuaFile()

local D3bot = D3bot
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

-- Get new instance of a triangle object.
-- This represents a triangle that is defined by 3 edges that are connected in a loop.
-- It's possible to get invalid triangles, therefore this needs to be checked.
function NAV_TRIANGLE:New(e1, e2, e3)
	local obj = {
		Edges = {e1, e2, e3}
	}

	setmetatable(obj, self)
	self.__index = self
	return obj
end
