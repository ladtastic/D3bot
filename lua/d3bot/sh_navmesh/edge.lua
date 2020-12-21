local D3bot = D3bot
local UTIL = D3bot.Util
local NAV_EDGE = D3bot.NAV_EDGE

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Get new instance of an edge object with the two given points.
-- This represents an edge that at most can be shared by two triangles.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:New(navmesh, id, p1, p2)
	local obj = {
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(), -- TODO: Convert id to integer if possible
		Points = {UTIL.RoundVector(p1), UTIL.RoundVector(p2)},
		Triangles = {} -- This points to triangles that this edge is part of. There should be at most 2 triangles.
	}

	setmetatable(obj, self)
	self.__index = self

	-- TODO: Selfcheck

	

	-- Add object to the navmesh, or abort if there is already an element with the same ID
	if navmesh.Edges[obj.ID] then return end
	navmesh.Edges[obj.ID] = obj

	return obj
end

-- Same as NAV_EDGE:New(), but uses table t to restore a previous state that came from MarshalToTable().
function NAV_EDGE:NewFromTable(navmesh, t)
	local obj = self:New(navmesh, t.ID, t.Points[1], t.Points[2])

	return obj
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Returns the object's ID, which is most likely a number object.
-- It can be anything else, though.
function NAV_EDGE:GetID()
	return self.ID
end

-- Returns a table that contains all important data of this object.
function NAV_EDGE:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Points = {
			Vector(self.Points[1]),
			Vector(self.Points[2])
		}
	}

	return t
end

-- Deletes the edge from the navmesh and makes sure that there is nothing left that references it.
function NAV_EDGE:Delete()
	-- Delete the (one or two) triangles that use this edge
	for _, triangle in ipairs(self.Triangles) do
		triangle:Delete()
	end

	self.Navmesh.Edges[self.ID] = nil
	self.Navmesh = nil
end

-- Deletes the edge, if there is nothing that references it.
function NAV_EDGE:GC()
	if #self.Triangles == 0 then
		self:Delete()
	end
end

-- Returns wether the edge consists out of the two given points or not.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:ConsistsOfPoints(p1, p2)
	p1, p2 = UTIL.RoundVector(p1), UTIL.RoundVector(p2)
	if self.Points[1] == p1 and self.Points[2] == p2 then return true end
	if self.Points[1] == p2 and self.Points[2] == p1 then return true end
	return false
end

-- Draw the edge into a 3D rendering context.
function NAV_EDGE:Render3D()
	local p1, p2 = self.Points[1], self.Points[2]

	render.DrawLine(p1, p2)
end
