-- Copyright (C) 2020-2021 David Vogel
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
local ERROR = D3bot.ERROR

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNAV_TRIANGLE
---@field Navmesh D3botNAV_MESH
---@field ID number | string
---@field Edges D3botNAV_EDGE[]
---@field FlipNormal boolean
---@field Cache table | nil @Contains cached values like the normal, the 3 corner points and neighbor triangles. Can be invalidated.
---@field UI table @General structure for UI related properties like selection status.
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE
NAV_TRIANGLE.__index = NAV_TRIANGLE

-- Min height of any triangle.
NAV_TRIANGLE.MinHeight = 10

---Get new instance of a triangle object.
---This represents a triangle that is defined by 3 edges that are connected in a loop.
---If a triangle with the same id already exists, it will be replaced.
---It's possible to get invalid triangles, therefore this needs to be checked.
---@param navmesh D3botNAV_MESH
---@param id number | string
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@param e3 D3botNAV_EDGE
---@param flipNormal boolean
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_TRIANGLE:New(navmesh, id, e1, e2, e3, flipNormal)
	local obj = setmetatable({
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(),
		Edges = {e1, e2, e3},
		FlipNormal = flipNormal,
		Cache = nil,
		UI = {},
	}, self)

	-- General parameter checks. -- TODO: Check parameters for types and other stuff
	if not navmesh then return nil, ERROR:New("Invalid value of parameter %q", "navmesh") end
	if not e1 then return nil, ERROR:New("Invalid value of parameter %q", "e1") end
	if not e2 then return nil, ERROR:New("Invalid value of parameter %q", "e2") end
	if not e3 then return nil, ERROR:New("Invalid value of parameter %q", "e3") end

	-- Check if the edges form a triangle shape.
	local trianglePoints, err = UTIL.EdgesToTrianglePoints(obj.Edges)
	if err then
		return nil, err
	end

	-- Check the resulting triangle's min height.
	local h1, h2, h3 = UTIL.GetTriangleHeights(trianglePoints[1], trianglePoints[2], trianglePoints[3])
	if math.min(h1, h2, h3) < obj.MinHeight then
		return nil, ERROR:New("The triangle's smallest height is below allowed min. height (%s < %s)", math.min(h1, h2, h3), obj.MinHeight)
	end

	-- Check if there is already an air connection connecting any of the three edges.
	for _, airConnection in pairs(navmesh.AirConnections) do
		if airConnection:ConsistsOfEdges(e1, e2) then
			return nil, ERROR:New("There is already a similar connection between %s and %s via %s", e1, e2, airConnection)
		end
		if airConnection:ConsistsOfEdges(e1, e3) then
			return nil, ERROR:New("There is already a similar connection between %s and %s via %s", e1, e3, airConnection)
		end
		if airConnection:ConsistsOfEdges(e2, e3) then
			return nil, ERROR:New("There is already a similar connection between %s and %s via %s", e2, e3, airConnection)
		end
	end

	-- Add reference to this triangle to all edges.
	table.insert(e1.Triangles, obj)
	table.insert(e2.Triangles, obj)
	table.insert(e3.Triangles, obj)

	-- Invalidate the cache of the neighbor triangles/air connections and their edges.
	-- It's ugly but has to be done.
	for _, edge in ipairs(obj.Edges) do
		for _, triangle in ipairs(edge.Triangles) do
			triangle:InvalidateCache()
			for _, edge2 in ipairs(triangle.Edges) do
				-- This may be run several times on some edges, but it's a fast operation.
				edge2:InvalidateCache()
			end
		end
		for _, airConnection in ipairs(edge.AirConnections) do
			airConnection:InvalidateCache()
			for _, edge2 in ipairs(airConnection.Edges) do
				-- This may be run several times on some edges, but it's a fast operation.
				edge2:InvalidateCache()
			end
		end
	end

	-- Check if there was a previous element. If so, delete it.
	local old = navmesh.Triangles[obj.ID]
	if old then old:_Delete() end

	-- Add object to the navmesh.
	navmesh.Triangles[obj.ID] = obj

	-- Check if there are at most 2 triangles connected to each edge.
	for _, edge in ipairs(obj.Edges) do
		if #edge.Triangles > 2 then
			obj:_Delete()
			return nil, ERROR:New("There are already %d triangles connected to %s", #edge.Triangles, edge)
		end
	end

	-- Check if cache is valid, if not abort and delete.
	local cache = obj:GetCache()
	if not cache.IsValid then
		obj:_Delete()
		return nil, ERROR:New("Failed to generate valid cache")
	end

	-- Publish change event.
	if navmesh.PubSub then
		navmesh.PubSub:SendTriangleToSubs(obj)
	end

	return obj, nil
end

---Same as NAV_TRIANGLE:New(), but uses table t to restore a previous state that came from MarshalToTable().
---As it needs a navmesh to find the edges by their reference ID, this should only be called after all the edges have been fully loaded into the navmesh.
---@param navmesh D3botNAV_MESH
---@param t table
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_TRIANGLE:NewFromTable(navmesh, t)
	local e1 = navmesh:FindEdgeByID(t.Edges[1])
	local e2 = navmesh:FindEdgeByID(t.Edges[2])
	local e3 = navmesh:FindEdgeByID(t.Edges[3])

	if not e1 or not e2 or not e3 then return nil, ERROR:New("Couldn't find all edges by their reference") end

	local obj, err = self:New(navmesh, t.ID, e1, e2, e3, t.FlipNormal)

	return obj, err
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the object's ID, which is most likely a number object.
---It can be anything else, though.
---@return number | string
function NAV_TRIANGLE:GetID()
	return self.ID
end

---Returns a table that contains all important data of this object.
---@return table
function NAV_TRIANGLE:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Edges = {
			self.Edges[1]:GetID(),
			self.Edges[2]:GetID(),
			self.Edges[3]:GetID(),
		},
		FlipNormal = self.FlipNormal,
	}

	return t -- Make sure that any object returned here is a deep copy of its original.
end

---Get the cached values, if needed this will regenerate the cache.
--@return table
function NAV_TRIANGLE:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	self.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Get 3 corner points from the edges and check for validity.
	local points, err = UTIL.EdgesToTrianglePoints(self.Edges)
	if err then
		print(string.format("%s Failed to generate valid cache for triangle %s: %s", D3bot.PrintPrefix, self, err))
		cache.IsValid = false
	end
	cache.CornerPoints = points

	-- Get neighbor triangles that are connected via edges.
	-- The triangle indices correspond to the edge indices.
	cache.NeighborTriangles = {}
	for i, edge in ipairs(self.Edges) do
		for _, triangle in ipairs(edge.Triangles) do
			if triangle ~= self then
				cache.NeighborTriangles[i] = triangle
				break
			end
		end
	end

	-- Calculate normal.
	if cache.IsValid then
		cache.Normal = (points[1] - points[2]):Cross(points[3] - points[1]):GetNormalized()
	else
		cache.Normal = Vector(0, 0, 1)
	end
	if self.FlipNormal then cache.Normal = cache.Normal * -1 end

	-- Calculate "centroid" center.
	if cache.IsValid then
		cache.Centroid = (points[1] + points[2] + points[3]) / 3
	else
		cache.Centroid = Vector(0, 0, 0)
	end

	-- Determine locomotion type. (Hardcoded locomotion types)
	cache.LocomotionType = "Ground" -- Default type.
	if cache.Normal then
		local angle = cache.Normal:Angle()
		if angle.pitch < 15 then
			cache.LocomotionType = "Wall" -- Everything steeper than 80 deg is considered a wall.
		elseif angle.pitch < 45 then
			cache.LocomotionType = "SteepGround" -- Everything steeper than 45 deg is considered a steep ground (That is not walkable normally).
		end
		-- TODO: Add user defined locomotion type override to triangles
	end

	---A list of possible paths to take from this triangle.
	---@type D3botPATH_FRAGMENT[]
	cache.PathFragments = {}
	if cache.IsValid then
		for _, edge in ipairs(self.Edges) do
			if #edge.Triangles + #edge.AirConnections > 1 then
				local edgeCenter = (edge.Points[1] + edge.Points[2]) / 2
				local edgeVector = edge.Points[2] - edge.Points[1]
				local edgeOrthogonal = cache.Normal:Cross(edgeVector) -- Vector that is orthogonal to the edge and parallel to the triangle plane.
				local pathDirection = edgeCenter - cache.Centroid -- Basically the walking direction.
				---@type D3botPATH_FRAGMENT
				local pathFragment = {
					From = self,
					FromPos = cache.Centroid,
					Via = self,
					To = edge,
					ToPos = edgeCenter,
					LocomotionType = cache.LocomotionType,
					PathDirection = pathDirection, -- Vector from start position to dest position.
					Distance = pathDirection:Length(), -- Distance from start to dest.
					OrthogonalOutside = (edgeOrthogonal * (edgeOrthogonal:Dot(pathDirection))):GetNormalized(), -- Vector for path end condition that is orthogonal to the edge and parallel to the triangle plane, additionally it always points outside the triangle.
				}
				table.insert(cache.PathFragments, pathFragment)
			end
		end
	end

	return cache
end

---Invalidate the cache, it will be regenerated on next use.
function NAV_TRIANGLE:InvalidateCache()
	self.Cache = nil
end

---Deletes the triangle from the navmesh and makes sure that there is nothing left that references it.
function NAV_TRIANGLE:Delete()
	-- Publish change event.
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteByIDFromSubs(self:GetID())
	end

	self:_Delete()
end

---Internal method.
function NAV_TRIANGLE:_Delete()
	-- Delete any reference to this triangle from edges.
	for _, edge in ipairs(self.Edges) do
		table.RemoveByValue(edge.Triangles, self)
		-- Invalidate cache of the edge.
		edge:InvalidateCache()
		-- Invalidate cache of the (other) connected triangles and air connections.
		for _, triangle in ipairs(edge.Triangles) do
			triangle:InvalidateCache()
		end
		for _, airConnection in ipairs(edge.AirConnections) do
			airConnection:InvalidateCache()
		end
	end

	local navmesh = self.Navmesh
	self.Navmesh = nil
	navmesh.Triangles[self.ID] = nil
end

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector | nil
function NAV_TRIANGLE:GetCentroid()
	local cache = self:GetCache()
	return cache.Centroid
end

---Returns a list of possible paths to take from this navmesh entity.
---The result is a list of path fragment tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_FRAGMENT[]
function NAV_TRIANGLE:GetPathFragments()
	local cache = self:GetCache()
	return cache.PathFragments
end

---Returns the locomotion type as a string.
---@return string
function NAV_TRIANGLE:GetLocomotionType()
	local cache = self:GetCache()
	return cache.LocomotionType
end

---Returns whether the triangle consists out of the three given edges or not.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@param e3 D3botNAV_EDGE
---@return boolean
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

---Returns the winding order/direction relative to the given edge.
---true: Winding direction is aligned with the edge.
---false: Winding direction is aligned against the edge.
---nil: Otherwise.
---@param edge D3botNAV_EDGE
---@return boolean | nil
function NAV_TRIANGLE:WindingOrderToEdge(edge)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local p1, p2, p3 = cache.CornerPoints[1], cache.CornerPoints[2], cache.CornerPoints[3]

	-- Aligned with edge.
	if p1 == edge.Points[1] and p2 == edge.Points[2] then return true end
	if p2 == edge.Points[1] and p3 == edge.Points[2] then return true end
	if p3 == edge.Points[1] and p1 == edge.Points[2] then return true end

	-- Aligned against edge.
	if p1 == edge.Points[1] and p3 == edge.Points[2] then return false end
	if p2 == edge.Points[1] and p1 == edge.Points[2] then return false end
	if p3 == edge.Points[1] and p2 == edge.Points[2] then return false end

	return nil
end

---Calculates and changes the triangle's new FlipNormal state.
---This is determined by its neighbor triangles.
---If the neighbor give a conflicting answer, the normal will be pointing upwards.
function NAV_TRIANGLE:RecalcFlipNormal()
	local cache = self:GetCache()

	local FlipCounter = 0

	for k, triangle in pairs(cache.NeighborTriangles) do
		local edge = self.Edges[k]
		local selfWindingOrder, neighborWindingOrder = self:WindingOrderToEdge(edge), triangle:WindingOrderToEdge(edge)
		if selfWindingOrder == neighborWindingOrder then
			FlipCounter = FlipCounter + (triangle.FlipNormal and -1 or 1)
		else
			FlipCounter = FlipCounter + (triangle.FlipNormal and 1 or -1)
		end
	end

	if FlipCounter > 0 then
		-- Most neighbor triangles are flipped in this direction.
		self:SetFlipNormal(true)
	elseif FlipCounter < 0 then
		-- Most neighbor triangles are flipped in the other direction.
		self:SetFlipNormal(false)
	else
		-- Neighbor triangle normals are indecisive: Assume upwards is more likely to be correct.
		if cache.Normal[3] < 0 then
			self:SetFlipNormal(not self.FlipNormal)
		end
	end
end

---Changes and publishes the FlipNormal state.
---@param state boolean
function NAV_TRIANGLE:SetFlipNormal(state)
	local navmesh = self.Navmesh

	if state then
		self.FlipNormal = true
	else
		self.FlipNormal = nil
	end

	-- Recalc normal and other stuff.
	self:InvalidateCache()

	-- Publish change event.
	if navmesh and navmesh.PubSub then
		navmesh.PubSub:SendTriangleToSubs(self)
	end
end

---Returns the closest point to the given point p.
---@param p GVector
---@return GVector
function NAV_TRIANGLE:GetClosestPointToPoint(p)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local normal = cache.Normal
	local p1, p2, p3 = cache.CornerPoints[1], cache.CornerPoints[2], cache.CornerPoints[3]

	-- Project the point p onto the plane.
	--local projected = p + normal:Cross(p1 - p) * normal

	-- Get clamped barycentric coordinates.
	local u, v, w = UTIL.GetBarycentric3DClamped(p1, p2, p3, p)

	-- Transform barycentric back to cartesian.
	return p1 * u + p2 * v + p3 * w
end

---Returns the closest squared distance to the given point p.
---@param p GVector
---@return number
function NAV_TRIANGLE:GetClosestDistanceSqr(p)
	local selfP = self:GetClosestPointToPoint(p)
	return (selfP - p):LengthSqr()
end

---Returns whether a ray from the given origin in the given direction dir intersects with the triangle.
---The result is either nil or the distance from the origin as a fraction of dir length.
---This will not return anything behind the origin, or beyond the length of dir.
---@param origin GVector @Ray origin.
---@param dir GVector @Ray direction.
---@return number | nil distance
function NAV_TRIANGLE:IntersectsRay(origin, dir)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local normal = cache.Normal
	local p1, p2, p3 = cache.CornerPoints[1], cache.CornerPoints[2], cache.CornerPoints[3]

	-- Ignore all cases where the ray and the plane are parallel.
	local denominator = dir:Dot(normal)
	if denominator == 0 then return nil end

	-- Get intersection distance and point.
	local d = (p1 - origin):Dot(normal) / denominator
	local point = origin + dir * d

	-- Ignore if the element is behind the origin or beyond dir length.
	if d <= 0 then return nil end
	if d > 1 then return nil end

	-- Check if intersection point is outside the triangle.
	local u, v, w = UTIL.GetBarycentric3D(p1, p2, p3, point)
	if u < 0 or v < 0 or w < 0 then return nil end

	return d
end

---Draw the edge into a 3D rendering context.
function NAV_TRIANGLE:Render3D()
	local cache = self:GetCache()
	local ui = self.UI
	local cornerPoints = cache.CornerPoints
	local normal, centroid = cache.Normal, cache.Centroid
	local tinyNormal = normal * 0.3

	-- Draw triangle by misusing a quad.
	if cornerPoints then
		if ui.Highlighted then
			ui.Highlighted = nil
			cam.IgnoreZ(true)
			render.DrawQuad(cornerPoints[1], cornerPoints[2], cornerPoints[3], cornerPoints[2], Color(255, 0, 0, 127))
			cam.IgnoreZ(false)

			if centroid and normal then
				render.DrawLine(centroid, centroid + normal * 30, Color(255, 255, 255, 255), true)
			end
		else
			render.DrawQuad(cornerPoints[1] + tinyNormal, cornerPoints[2] + tinyNormal, cornerPoints[3] + tinyNormal, cornerPoints[2] + tinyNormal, Color(255, 0, 0, 31))
		end
	end
end

---Define metamethod for string conversion.
---@return string
function NAV_TRIANGLE:__tostring()
	return string.format("{Triangle %s}", self:GetID())
end
