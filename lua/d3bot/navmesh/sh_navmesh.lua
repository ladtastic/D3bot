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
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDGE = D3bot.NAV_EDGE
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Get new instance of a navmesh container object.
-- This contains edges and triangles of a navmesh and provides methods for locating and path finding.
function NAV_MESH:New()
	local obj = {
		Edges = {},
		Triangles = {},
		PubSub = nil,
		UniqueIDCounter = 1
	}

	setmetatable(obj, self)
	self.__index = self

	return obj
end

-- Same as NAV_MESH:New(), but uses table t to restore a previous state that came from MarshalToTable().
function NAV_MESH:NewFromTable(t)
	local obj = self:New()

	-- Restore edges
	for _, edgeTable in ipairs(t.Edges) do
		NAV_EDGE:NewFromTable(obj, edgeTable)
	end

	-- Restore triangles
	for _, triangleTable in ipairs(t.Triangles) do
		NAV_TRIANGLE:NewFromTable(obj, triangleTable)
	end

	-- GC all free floating edges
	for _, edge in pairs(obj.Edges) do
		edge:_GC()
	end

	return obj
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Returns a table that contains all important data of this object.
function NAV_MESH:MarshalToTable()
	local t = {}

	-- Get data table of each edge and store it in an array. Ignore the key/id, it's stored in each object.
	t.Edges = {}
	for k, edge in UTIL.kpairs(self.Edges) do
		table.insert(t.Edges, edge:MarshalToTable())
	end

	-- Get data table of each triangle and store it in an array. Ignore the key/id, it's stored in each object.
	t.Triangles = {}
	for k, triangle in UTIL.kpairs(self.Triangles) do
		table.insert(t.Triangles, triangle:MarshalToTable())
	end

	return t
end

-- Returns a unique ID key that has not been used before.
-- It can be used for new edges or triangles.
function NAV_MESH:GetUniqueID()
	local idKey = self.UniqueIDCounter

	-- Check if key is already in use, iteratively increase
	while self.Edges[idKey] or self.Triangles[idKey] do
		idKey = idKey + 1
		self.UniqueIDCounter = idKey
	end

	return self.UniqueIDCounter
end

-- Returns the nearest triangle/edge corner to the given point p with a radius of r.
-- If no point is found, nil will be returned.
function NAV_MESH:GetNearestPoint(p, r)
	-- Stupid linear search for the closest point
	-- Also, it will go over points several times, as some edges share points
	local minDistSqr = (r and r * r) or math.huge
	local resultPoint
	for _, edge in pairs(self.Edges) do
		for _, point in ipairs(edge.Points) do
			local distSqr = p:DistToSqr(point)
			if minDistSqr > distSqr then
				minDistSqr = distSqr
				resultPoint = point
			end
		end
	end

	return resultPoint
end

-- Returns any entity with the given ID, or nil if doesn't exist.
function NAV_MESH:FindByID(id)
	return self.Edges[id] or self.Triangles[id]
end

-- Returns the edge with the given ID, or nil if doesn't exist.
function NAV_MESH:FindEdgeByID(id)
	return self.Edges[id]
end

-- Will return the edge that is built with the two given points, if there is one.
function NAV_MESH:FindEdge2P(p1, p2)
	for _, edge in pairs(self.Edges) do
		if edge:ConsistsOfPoints(p1, p2) then return edge end
	end

	return
end

-- Will create a new edge with the given two points, or return an already existing edge.
function NAV_MESH:FindOrCreateEdge2P(p1, p2)
	local edge = self:FindEdge2P(p1, p2)
	if edge then return edge end

	-- Create new edge
	return NAV_EDGE:New(self, nil, p1, p2)
end

-- Returns the triangle with the given ID, or nil if doesn't exist.
function NAV_MESH:FindTriangleByID(id)
	return self.Triangles[id]
end

-- Will return the triangle that is built with the three given points, if there is one.
function NAV_MESH:FindTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindEdge2P(p1, p2), self:FindEdge2P(p2, p3), self:FindEdge2P(p3, p1)

	return self:FindTriangle3E(e1, e2, e3)
end

-- Will return the triangle that is built with the three given edges, if there is one.
function NAV_MESH:FindTriangle3E(e1, e2, e3)
	for _, triangle in pairs(self.Triangles) do
		if triangle:ConsistsOfEdges(e1, e2, e3) then return triangle end
	end

	return
end

-- Will create a new triangle with the given three points, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindOrCreateEdge2P(p1, p2), self:FindOrCreateEdge2P(p2, p3), self:FindOrCreateEdge2P(p3, p1)

	local triangle = self:FindOrCreateTriangle3E(e1, e2, e3)

	-- If it failed to create a triangle, then garbage collect any "free floating" edge
	if not triangle then
		e1:_GC()
		e2:_GC()
		e3:_GC()
	end

	return triangle
end

-- Will create a new triangle with the given three edges, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3E(e1, e2, e3)
	local triangle = self:FindTriangle3E(e1, e2, e3)
	if triangle then return triangle end

	-- Create new triangle
	local triangle = NAV_TRIANGLE:New(self, nil, e1, e2, e3, nil)
	if not triangle then return triangle end

	-- Determine FlipNormal state
	triangle:RecalcFlipNormal()

	return triangle
end

-- Set where to publish change events to.
-- Use nil to disable publishing.
-- Make sure that there is only one navmesh that is linked with a PubSub at a time.
function NAV_MESH:SetPubSub(pubSub)
	if SERVER then
		if self.PubSub then self.PubSub:DeleteNavmeshFromSubs() end
		self.PubSub = pubSub
		if self.PubSub then self.PubSub:SendNavmeshToSubs(self) end
	end
end

-- Draw the navmesh into a 3D rendering context.
function NAV_MESH:Render3D()
	-- Draw edges
	for _, edge in pairs(self.Edges) do
		edge:Render3D()
	end

	-- Draw triangles
	render.SetColorMaterial()
	for _, triangle in pairs(self.Triangles) do
		triangle:Render3D()
	end
end
