-- Copyright (C) 2020 David Vogel
-- 
-- This file is part of D3bot.
-- 
-- D3bot is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- D3bot is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with D3bot.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local UTIL = D3bot.Util
local NAV_EDGE = D3bot.NAV_EDGE

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Radius of the edge used for drawing and mouse click tracing.
NAV_EDGE.DisplayRadius = 5

-- Get new instance of an edge object with the two given points.
-- This represents an edge that is defined with two points.
-- If an edge with the same id already exists, it will be overwritten.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:New(navmesh, id, p1, p2)
	local obj = {
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(), -- TODO: Convert id to integer if possible
		Points = {UTIL.RoundVector(p1), UTIL.RoundVector(p2)},
		Triangles = {}, -- This points to triangles that this edge is part of. There should be at most 2 triangles.
		UI = {} -- General structure for UI related properties like selection status
	}

	setmetatable(obj, self)
	self.__index = self

	-- TODO: Selfcheck

	-- Check if there was a previous element. If so, change references to/from it
	local old = navmesh.Edges[obj.ID]
	if old then
		obj.Triangles = old.Triangles
		-- Iterate over linked triangles
		for _, triangle in ipairs(obj.Triangles) do
			-- Correct the edge references of these triangles
			for i, edge in ipairs(triangle.Edges) do
				if edge == old then
					triangle.Edges[i] = obj
				end
			end
		end
		old.Triangles = {}
		old:_Delete()
	end

	-- Invalidate cache of connected triangles
	for _, triangle in ipairs(obj.Triangles) do
		triangle:InvalidateCache()
	end

	-- Add object to the navmesh
	navmesh.Edges[obj.ID] = obj

	-- Publish change event
	if navmesh.PubSub then
		navmesh.PubSub:SendEdgeToSubs(obj)
	end

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

	return t -- Make sure that any object returned here is a deep copy of its original
end

-- Deletes the edge from the navmesh and makes sure that there is nothing left that references it.
function NAV_EDGE:Delete()
	-- Publish change event
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteEdgeFromSubs(self:GetID())
	end

	return self:_Delete()
end

-- Internal method.
function NAV_EDGE:_Delete()
	-- Delete the (one or two) triangles that use this edge
	for _, triangle in ipairs(self.Triangles) do
		triangle:_Delete()
	end

	self.Navmesh.Edges[self.ID] = nil
	self.Navmesh = nil
end

-- Internal method: Deletes the edge, if there is nothing that references it.
function NAV_EDGE:_GC()
	if #self.Triangles == 0 then
		self:_Delete()
	end
end

-- Returns whether the edge consists out of the two given points or not.
-- The point coordinates will be rounded to a single engine unit.
function NAV_EDGE:ConsistsOfPoints(p1, p2)
	p1, p2 = UTIL.RoundVector(p1), UTIL.RoundVector(p2)
	if self.Points[1] == p1 and self.Points[2] == p2 then return true end
	if self.Points[1] == p2 and self.Points[2] == p1 then return true end
	return false
end

-- Returns the closest points to the given line defined by its origin and the direction dir.
-- The first returned point lies on the element itself.
-- The second returned point lies on the given line.
-- The length of dir has no influence on the result.
function NAV_EDGE:GetClosestPointToLine(origin, dir)
	-- See: http://geomalgorithms.com/a07-_distance.html

	local p1, p2 = self.Points[1], self.Points[2]
	local u = p2 - p1
	local w0 = p1 - origin
	local a, b, c, d, e = u:Dot(u), u:Dot(dir), dir:Dot(dir), u:Dot(w0), dir:Dot(w0)

	-- Ignore the cases where the two lines are parallel
	local denominator = a * c - b * b
	if denominator <= 0 then return p1, origin end

	local sc = (b*e - c*d) / denominator -- Position on the edge (self) between p1 and p2 and beyond
	local tc = (a*e - b*d) / denominator -- Position on the given line between origin and (origin + dir) and beyond

	-- Clamp
	local scClamped = math.Clamp(sc, 0, 1)

	return p1 + u * scClamped, origin + dir * tc
end

-- Returns whether a ray from the given origin in the given direction dir intersects with the edge.
-- The result is either nil or the distance from the origin as a fraction of dir length.
-- This will not return anything behind the origin, or beyond the length of dir.
function NAV_EDGE:IntersectsRay(origin, dir)
	-- See: http://geomalgorithms.com/a07-_distance.html

	-- Approximate capsule shaped edge by checking if the smallest distance between the ray and segment is < edge radius.
	-- Also, subtract some amount ( √(radius² - dist²) ) from the calculated dist to give it some "volume".
	-- That should be good enough.

	local p1, p2 = self.Points[1], self.Points[2]
	local u = p2 - p1
	local w0 = p1 - origin
	local a, b, c, d, e = u:Dot(u), u:Dot(dir), dir:Dot(dir), u:Dot(w0), dir:Dot(w0)

	-- Ignore the cases where the two lines are parallel
	local denominator = a*c - b*b
	if denominator <= 0 then return nil end

	local sc = (b*e - c*d) / denominator -- Position on the edge (self) between p1 and p2 and beyond
	local tc = (a*e - b*d) / denominator -- Position on the given line between origin and (origin + dir) and beyond

	-- Ignore if the element is behind the origin
	if tc <= 0 then return nil end

	-- Clamp
	local scClamped = math.Clamp(sc, 0, 1)

	-- Get resulting closest points
	local res1, res2 = p1 + u*scClamped, origin + dir*tc

	-- Check if ray is not intersecting with the "capsule shape"
	local radiusSqr = self.DisplayRadius * self.DisplayRadius
	local distSqr = (res1 - res2):LengthSqr()
	if distSqr > radiusSqr then return nil end

	-- Subtract distance to sphere hull, to give the fake capsule its round shell
	local d = tc - math.sqrt(radiusSqr - distSqr) / dir:Length()

	-- Ignore if the element is beyond dir length
	if d > 1 then return nil end

	return d
end

-- Draw the edge into a 3D rendering context.
function NAV_EDGE:Render3D()
	local ui = self.UI
	local p1, p2 = self.Points[1], self.Points[2]

	if ui.Highlighted then
		ui.Highlighted = nil
		cam.IgnoreZ(true)
		render.DrawBeam(p1, p2, self.DisplayRadius*2, 0, 1, Color(255,255,255,127))
		cam.IgnoreZ(false)
	else
		render.DrawLine(p1, p2, Color(255,0,0,31), true)
	end
end
