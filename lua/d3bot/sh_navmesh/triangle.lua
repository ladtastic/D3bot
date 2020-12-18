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

	-- TODO: Selfcheck

	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- Returns wether the triangle consists out of the three given edges or not.
function NAV_EDGE:ConsistsOfEdges(e1, e2, e3)
	-- There is probably a nicer way to do this, but it doesn't need to be that fast
	-- In the worst case
	if self.Edges[1] == e1 and self.Edges[2] == e2 and self.Edges[3] == e3 then return true end
	if self.Edges[1] == e1 and self.Edges[2] == e3 and self.Edges[3] == e2 then return true end
	if self.Edges[1] == e2 and self.Edges[2] == e1 and self.Edges[3] == e3 then return true end
	if self.Edges[1] == e2 and self.Edges[2] == e3 and self.Edges[3] == e1 then return true end
	if self.Edges[1] == e3 and self.Edges[2] == e1 and self.Edges[3] == e2 then return true end
	if self.Edges[1] == e3 and self.Edges[2] == e2 and self.Edges[3] == e1 then return true end
	return false
end
