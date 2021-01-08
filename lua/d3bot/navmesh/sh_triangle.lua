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
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Get new instance of a triangle object.
-- This represents a triangle that is defined by 3 edges that are connected in a loop.
-- If a triangle with the same id already exists, it will be overwritten.
-- It's possible to get invalid triangles, therefore this needs to be checked.
function NAV_TRIANGLE:New(navmesh, id, e1, e2, e3, flipNormal)
	local obj = {
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(), -- TODO: Convert id to integer if possible
		Edges = {e1, e2, e3},
		FlipNormal = flipNormal,
		Cache = nil -- Contains cached values like the normal, the 3 corner points and neighbour triangles. Can be invalidated.
	}

	setmetatable(obj, self)
	self.__index = self

	-- TODO: Selfcheck

	-- Add reference to this triangle to all edges
	table.insert(e1.Triangles, obj)
	table.insert(e2.Triangles, obj)
	table.insert(e3.Triangles, obj)

	-- Check if there was a previous element. If so, delete it
	local old = navmesh.Triangles[obj.ID]
	if old then old:_Delete() end

	-- Add object to the navmesh
	navmesh.Triangles[obj.ID] = obj

	-- Check if cache is valid, if not abort and delete
	local cache = obj:GetCache()
	if not cache.IsValid then obj:_Delete() return nil end

	-- Publish change event
	if navmesh.PubSub then
		navmesh.PubSub:SendTriangleToSubs(obj)
	end

	return obj
end

-- Same as NAV_TRIANGLE:New(), but uses table t to restore a previous state that came from MarshalToTable().
-- As it needs a navmesh to find the edges by their reference ID, this should only be called after all the edges have been fully loaded into the navmesh.
function NAV_TRIANGLE:NewFromTable(navmesh, t)
	local e1 = navmesh:FindEdgeByID(t.Edges[1])
	local e2 = navmesh:FindEdgeByID(t.Edges[2])
	local e3 = navmesh:FindEdgeByID(t.Edges[3])
	
	if not e1 or not e2 or not e3 then error("Couldn't find all edges by their reference") end

	local obj = self:New(navmesh, t.ID, e1, e2, e3, t.FlipNormal)

	return obj
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Returns the object's ID, which is most likely a number object.
-- It can be anything else, though.
function NAV_TRIANGLE:GetID()
	return self.ID
end

-- Returns a table that contains all important data of this object.
function NAV_TRIANGLE:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Edges = {
			self.Edges[1]:GetID(),
			self.Edges[2]:GetID(),
			self.Edges[3]:GetID()
		},
		FlipNormal = self.FlipNormal
	}

	return t -- Make sure that any object returned here is a deep copy of its original
end

-- Get the cached values, if needed this will regenerate the cache.
function NAV_TRIANGLE:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache
	local cache = {}
	self.Cache = cache

	-- A signal that the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Get 3 corner points from the edges
	local points = {}
	for _, edge in ipairs(self.Edges) do
		for _, newPoint in ipairs(edge.Points) do
			local found = false
			-- Check if point already is in the list
			for _, point in ipairs(points) do
				if point == newPoint then
					found = true
					break
				end
			end

			if not found then
				table.insert(points, newPoint)
			end
		end
	end

	-- Check the points for validity
	if #points == 3 then
		cache.CornerPoints = points
	else
		cache.IsValid = false
	end

	-- Get neighbour triangles that are connected via edges.
	-- The triangle indices correspond to the edge indices.
	cache.NeighbourTriangles = {}
	for i, edge in ipairs(self.Edges) do
		for _, triangle in ipairs(edge.Triangles) do
			if triangle ~= self then
				cache.NeighbourTriangles[i] = triangle
				break
			end
		end
	end

	-- Calculate normal
	cache.Normal = (points[1] - points[2]):Cross(points[3] - points[1]):GetNormalized()
	if self.FlipNormal then cache.Normal = cache.Normal * -1 end

	-- Caclulate "centroid" center
	cache.Centroid = (points[1] + points[2] + points[3]) / 3

	return cache
end

-- Invalidate the cache, it will be regenerated on next use.
function NAV_TRIANGLE:InvalidateCache()
	self.Cache = nil
end

-- Deletes the triangle from the navmesh and makes sure that there is nothing left that references it.
function NAV_TRIANGLE:Delete()
	-- Publish change event
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteTriangleFromSubs(self:GetID())
	end

	self:_Delete()
end

-- Internal method.
function NAV_TRIANGLE:_Delete()
	-- Delete any reference to this triangle from edges
	for _, edge in ipairs(self.Edges) do
		table.RemoveByValue(edge.Triangles, self)
		-- Delete any "floating" edge
		edge:_GC()
	end

	self.Navmesh.Triangles[self.ID] = nil
	self.Navmesh = nil
end

-- Returns wether the triangle consists out of the three given edges or not.
function NAV_TRIANGLE:ConsistsOfEdges(e1, e2, e3)
	local se1, se2, se3 = self.Edges[1], self.Edges[2], self.Edges[3]
	-- There is probably a nicer way to do this, but it doesn't need to be that fast.
	-- This will cause between 6 to 9 comparison operations, but most of time time just 6.
	-- If the optimizer is doing its job well, it may just be 3 comparisons at best.
	if se1 == e1 and se2 == e2 and se3 == e3 then return true end
	if se1 == e1 and se2 == e3 and se3 == e2 then return true end
	if se1 == e2 and se2 == e1 and se3 == e3 then return true end
	if se1 == e2 and se2 == e3 and se3 == e1 then return true end
	if se1 == e3 and se2 == e1 and se3 == e2 then return true end
	if se1 == e3 and se2 == e2 and se3 == e1 then return true end
	return false
end

-- Returns the winding order/direction relative to the given edge.
-- true: Winding direction is aligned with the edge.
-- false: Winding direction is aligned against the edge.
-- nil: Otherwise.
function NAV_TRIANGLE:WindingOrderToEdge(edge)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local p1, p2, p3 = cache.CornerPoints[1], cache.CornerPoints[2], cache.CornerPoints[3]

	-- Aligned with edge
	if p1 == edge.Points[1] and p2 == edge.Points[2] then return true end
	if p2 == edge.Points[1] and p3 == edge.Points[2] then return true end
	if p3 == edge.Points[1] and p1 == edge.Points[2] then return true end

	-- Aligned against edge
	if p1 == edge.Points[1] and p3 == edge.Points[2] then return false end
	if p2 == edge.Points[1] and p1 == edge.Points[2] then return false end
	if p3 == edge.Points[1] and p2 == edge.Points[2] then return false end

	return nil
end

-- Calculates and changes the triangle's new FlipNormal state.
-- This is determined by its neighbour triangles.
-- If the neighbours give a conflicting answer, the normal will be pointing upwards.
function NAV_TRIANGLE:UpdateFlipNormal()
	local cache = self:GetCache()

	local FlipCounter = 0

	for k, triangle in pairs(cache.NeighbourTriangles) do
		local edge = self.Edges[k]
		local selfWindingOrder, neighbourWindingOrder = self:WindingOrderToEdge(edge), triangle:WindingOrderToEdge(edge)
		if selfWindingOrder == neighbourWindingOrder then
			FlipCounter = FlipCounter + (triangle.FlipNormal and -1 or 1)
		else
			FlipCounter = FlipCounter + (triangle.FlipNormal and 1 or -1)
		end
	end

	if FlipCounter > 0 then
		self:SetFlipNormal(true)
	elseif FlipCounter < 0 then
		self:SetFlipNormal(false)
	else
		if cache.Normal[3] < 0 then
			self:SetFlipNormal(true)
		else
			self:SetFlipNormal(false)
		end
	end

	print(self.FlipNormal)
end

-- Changes and publishes the FlipNormal state.
function NAV_TRIANGLE:SetFlipNormal(state)
	local navmesh = self.Navmesh

	if state then
		self.FlipNormal = true
	else
		self.FlipNormal = nil
	end

	-- Recalc normal and other stuff
	self:InvalidateCache()

	-- Publish change event
	if navmesh and navmesh.PubSub then
		navmesh.PubSub:SendTriangleToSubs(self)
	end
end

-- Draw the edge into a 3D rendering context.
function NAV_TRIANGLE:Render3D()
	local cache = self:GetCache()
	local cornerPoints = cache.CornerPoints
	local normal, centroid = cache.Normal, cache.Centroid

	-- Draw triangle by misusing a quad.
	if cornerPoints then
		render.DrawQuad(cornerPoints[1], cornerPoints[2], cornerPoints[3], cornerPoints[2], Color(255,0,0,31))
	end
	if centroid and normal then
		render.DrawLine(centroid, centroid + normal * 10)
	end
end
