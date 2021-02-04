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

---@class D3botNAV_EDGE
---@field Navmesh D3botNAV_MESH
---@field ID number | string
---@field Vertices D3botNAV_VERTEX[] @The two vertices that the edge is made of.
---@field Triangles D3botNAV_TRIANGLE[] @This points to triangles that this edge is part of. There should be at most 2 triangles.
---@field AirConnections D3botNAV_AIR_CONNECTION[] @This points to air connections that this edge is part of.
---@field Cache table | nil @Contains connected neighbor edges and other cached values.
---@field UI table @General structure for UI related properties like selection status
local NAV_EDGE = D3bot.NAV_EDGE
NAV_EDGE.__index = NAV_EDGE

-- Radius of the edge used for drawing and mouse click tracing.
NAV_EDGE.DisplayRadius = 5

-- Min length of any edge.
NAV_EDGE.MinLength = 5

---Get new instance of an edge object with the two given points.
---This represents an edge that is defined with two points.
---If an edge with the same id already exists, it will be replaced.
---The point coordinates will be rounded to a single engine unit.
---@param navmesh D3botNAV_MESH
---@param id number | string
---@param v1 D3botNAV_VERTEX
---@param v2 D3botNAV_VERTEX
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_EDGE:New(navmesh, id, v1, v2)
	local obj = setmetatable({
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(),
		Vertices = {v1, v2},
		Triangles = {},
		AirConnections = {},
		Cache = nil,
		UI = {},
	}, self)

	-- General parameter checks. -- TODO: Check parameters for types and other stuff.
	if not navmesh then return nil, ERROR:New("Invalid value of parameter %q", "navmesh") end
	if not v1 then return nil, ERROR:New("Invalid value of parameter %q", "v1") end
	if not v2 then return nil, ERROR:New("Invalid value of parameter %q", "v2") end

	-- TODO: Check if ID is used by a different entity type

	-- Make sure that length is >= self.MinLength.
	local length = v1:GetPoint():Distance(v2:GetPoint())
	if length < self.MinLength then
		return nil, ERROR:New("The edge is shorter than the allowed min. length (%s < %s)", length, self.MinLength)
	end

	-- Add edge reference to the two vertices.
	table.insert(v1.Edges, obj)
	table.insert(v2.Edges, obj)

	-- Check if there was a previous element. If so, change references to/from it.
	local old = navmesh.Edges[obj.ID]
	if old then
		obj.Triangles = old.Triangles
		obj.AirConnections = old.AirConnections

		-- Iterate over linked triangles.
		for _, triangle in ipairs(obj.Triangles) do
			-- Correct the edge references of these triangles.
			for i, edge in ipairs(triangle.Edges) do
				if edge == old then
					triangle.Edges[i] = obj
				end
			end
		end
		-- Iterate over linked air connections.
		for _, airConnection in ipairs(obj.AirConnections) do
			-- Correct the edge references of these triangles.
			for i, edge in ipairs(airConnection.Edges) do
				if edge == old then
					airConnection.Edges[i] = obj
				end
			end
		end

		old.Triangles = {}
		old.AirConnections = {}
		old:_Delete()
	end

	-- Invalidate cache of any connected entities.
	for _, vertex in ipairs(obj.Vertices) do
		vertex:InvalidateCache()
	end
	for _, triangle in ipairs(obj.Triangles) do
		triangle:InvalidateCache()
	end
	for _, airConnection in ipairs(obj.AirConnections) do
		airConnection:InvalidateCache()
	end

	-- Add object to the navmesh.
	navmesh.Edges[obj.ID] = obj

	-- Publish change event.
	if navmesh.PubSub then
		navmesh.PubSub:SendEdgeToSubs(obj)
	end

	return obj, nil
end

---Same as NAV_EDGE:New(), but uses table t to restore a previous state that came from MarshalToTable().
---@param navmesh D3botNAV_MESH
---@param t table
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_EDGE:NewFromTable(navmesh, t)
	if not t.Vertices then return nil, ERROR:New("The field %q is missing from the table", "Vertices") end

	local v1 = navmesh:FindVertexByID(t.Vertices[1])
	local v2 = navmesh:FindVertexByID(t.Vertices[2])

	if not v1 or not v2 then return nil, ERROR:New("Couldn't find all vertices by their reference") end

	local obj, err = self:New(navmesh, t.ID, v1, v2)
	return obj, err
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the object's ID, which is most likely a number object.
---It can also be a string, though.
---@return number | string
function NAV_EDGE:GetID()
	return self.ID
end

---Returns a table that contains all important data of this object.
---@return table
function NAV_EDGE:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Vertices = {
			self.Vertices[1]:GetID(),
			self.Vertices[2]:GetID(),
		}
	}

	return t -- Make sure that any object returned here is a deep copy of its original.
end

---Get the cached values, if needed this will regenerate the cache.
--@return table
function NAV_EDGE:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	self.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Get the two edge corners/points.
	local p1, p2 = self:_GetPoints()
	cache.Point1, cache.Point2 = p1, p2

	---Calculate center.
	---@type GVector
	cache.Center = self:_GetCentroid()

	---Cache IsWalled state.
	cache.IsWalled = self:_IsWalled()

	---A list of possible paths to take from this edge.
	---@type D3botPATH_FRAGMENT[]
	cache.PathFragments = {}
	if cache.IsValid then
		for _, triangle in ipairs(self.Triangles) do
			-- Get an orthogonal vector of the triangle plane, without using the triangle cache.
			local triangleVertices, err = UTIL.EdgesToTriangleVertices(triangle.Edges)
			local triangleNormal = Vector(0, 0, 1)
			if triangleVertices then
				local trianglePoints = {triangleVertices[1]:GetPoint(), triangleVertices[2]:GetPoint(), triangleVertices[3]:GetPoint()}
				triangleNormal = (trianglePoints[1] - trianglePoints[2]):Cross(trianglePoints[3] - trianglePoints[1]):GetNormalized() -- Has to be normalized, because too large numbers will be interpreted as infinity. Thanks lua.
			end

			for _, edge in ipairs(triangle.Edges) do
				if edge ~= self and #edge.Triangles + #edge.AirConnections > 1 then
					local eP1, eP2 = edge:_GetPoints()
					local neighborEdgeCenter = edge:_GetCentroid()
					local edgeVector = eP2 - eP1
					local edgeOrthogonal = triangleNormal:Cross(edgeVector) -- Vector that is orthogonal to the edge and parallel to the triangle plane.
					local pathDirection = neighborEdgeCenter - cache.Center -- Basically the walking direction.
					---@type D3botPATH_FRAGMENT
					local pathFragment = {
						From = self,
						FromPos = cache.Center,
						Via = triangle,
						To = edge,
						ToPos = neighborEdgeCenter,
						LocomotionType = triangle:GetLocomotionType(), -- Not optimal as it makes a cache query and has potential for infinite recursion.
						PathDirection = pathDirection, -- Vector from start position to dest position.
						Distance = pathDirection:Length(), -- Distance from start to dest.
						OrthogonalOutside = (edgeOrthogonal * (edgeOrthogonal:Dot(pathDirection))):GetNormalized(), -- Vector for path end condition that is orthogonal to the edge and parallel to the triangle plane, additionally it always points outside the triangle.
					}
					table.insert(cache.PathFragments, pathFragment)
				end
			end
		end
		for _, airConnection in ipairs(self.AirConnections) do
			for _, edge in ipairs(airConnection.Edges) do
				if edge ~= self and #edge.Triangles + #edge.AirConnections > 1 then
					local eP1, eP2 = edge:_GetPoints()
					local edgeCenter = edge:_GetCentroid()
					local edgeVector = eP2 - eP1
					local pathDirection = edgeCenter - cache.Center -- Basically the walking direction.
					local edgeOrthogonal = pathDirection:Cross(edgeVector):Cross(edgeVector) -- Vector that is orthogonal to the edge.
					---@type D3botPATH_FRAGMENT
					local pathFragment = {
						From = self,
						FromPos = cache.Center,
						Via = airConnection,
						To = edge,
						ToPos = edgeCenter,
						LocomotionType = airConnection:GetLocomotionType(), -- Not optimal as it makes a cache query and has potential for infinite recursion.
						PathDirection = pathDirection, -- Vector from start position to dest position.
						Distance = pathDirection:Length(), -- Distance from start to dest.
						OrthogonalOutside = (edgeOrthogonal * (edgeOrthogonal:Dot(pathDirection))):GetNormalized(), -- Vector for path end condition that is orthogonal to the edge and parallel to the triangle plane, additionally it always points outside the triangle.
					}
					table.insert(cache.PathFragments, pathFragment)
				end
			end
		end
	end

	return cache
end

---Invalidate the cache, it will be regenerated on next use.
function NAV_EDGE:InvalidateCache()
	self.Cache = nil
end

---Deletes the edge from the navmesh and makes sure that there is nothing left that references it.
function NAV_EDGE:Delete()
	-- Publish change event.
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteByIDFromSubs(self:GetID())
	end

	return self:_Delete()
end

---Internal method.
function NAV_EDGE:_Delete()
	-- Delete the triangles and air connections that are connected.
	for _, triangle in ipairs(self.Triangles) do
		triangle:_Delete()
	end
	for _, airConnection in ipairs(self.AirConnections) do
		airConnection:_Delete()
	end

	-- Delete any reference to this edge from its vertices.
	for _, vertex in ipairs(self.Vertices) do
		table.RemoveByValue(vertex.Edges, self)
		-- Invalidate cache of the vertex.
		vertex:InvalidateCache()
	end

	self.Navmesh.Edges[self.ID] = nil
	self.Navmesh = nil
end

---Internal method: Deletes the edge, if there is nothing that references it.
---Only call GC from the server side and let it sync the result to all clients.
function NAV_EDGE:_GC()
	if #self.Triangles + #self.AirConnections == 0 then
		self:Delete()
	end
end

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector
function NAV_EDGE:GetCentroid()
	local cache = self:GetCache()
	return cache.Center
end

---Internal and uncached version of GetCentroid.
---@return GVector
function NAV_EDGE:_GetCentroid()
	local p1, p2 = self:_GetPoints()
	return (p1 + p2) / 2
end

---Returns the points (vectors) that this entity is made of.
---May use the cache.
---@return GVector, GVector
function NAV_EDGE:GetPoints()
	local cache = self:GetCache()
	return cache.Point1, cache.Point2
end

---Internal and uncached version of GetPoints.
---@return GVector, GVector
function NAV_EDGE:_GetPoints()
	return self.Vertices[1]:GetPoint(), self.Vertices[2]:GetPoint()
end

---Returns the list of vertices that this entity is made of.
---@return D3botNAV_VERTEX, D3botNAV_VERTEX
function NAV_EDGE:GetVertices()
	return self.Vertices[1], self.Vertices[2]
end

---Returns whether an edge is at a wall or wall like (not walkable) geometry.
---This doesn't influence pathfinding or if bots can use this edge to navigate.
---This is used (indirectly via vertices) to determine if a bot has to keep distance to edges/vertices so it doesn't get stuck on walls or corners.
---@return boolean
function NAV_EDGE:IsWalled()
	local cache = self:GetCache()
	return cache.IsWalled
end

---Internal and uncached version of IsWalled.
---@return boolean
function NAV_EDGE:_IsWalled()
	-- If the edge has less than two triangles, assume that the edge is at a wall.
	if #self.Triangles < 2 then
		-- TODO: Add user override for edges that are at cliffs or similar geometries, and therefore "walkable"
		return true
	end

	-- Check if any of the two connected triangles can be walked on.
	for _, triangle in ipairs(self.Triangles) do
		local locType = triangle:GetLocomotionType()
		if locType ~= "Ground" then
			-- TODO: Calculate "angle" between the two triangles, and use it to determine if the edge is at a cliff or wall
			return true
		end
	end

	return false
end

---Returns a list of possible paths to take from this navmesh entity.
---The result is a list of path fragment tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_FRAGMENT[]
function NAV_EDGE:GetPathFragments()
	local cache = self:GetCache()
	return cache.PathFragments
end

---Returns whether the edge consists out of the two given vertices or not.
---@param v1 D3botNAV_VERTEX
---@param v2 D3botNAV_VERTEX
---@return boolean
function NAV_EDGE:ConsistsOfVertices(v1, v2)
	if self.Vertices[1] == v1 and self.Vertices[2] == v2 then return true end
	if self.Vertices[1] == v2 and self.Vertices[2] == v1 then return true end
	return false
end

---Returns the closest points to the given line defined by its origin and the direction dir.
---The length of dir has no influence on the result.
---@param origin GVector @Origin of the line or ray.
---@param dir GVector @Direction of the line or ray.
---@return GVector edgePoint @Closest point on the edge itself.
---@return GVector rayPoint @Closest point on the ray.
function NAV_EDGE:GetClosestPointToLine(origin, dir)
	-- See: http://geomalgorithms.com/a07-_distance.html

	local p1, p2 = self:GetPoints()
	local u = p2 - p1
	local w0 = p1 - origin
	local a, b, c, d, e = u:Dot(u), u:Dot(dir), dir:Dot(dir), u:Dot(w0), dir:Dot(w0)

	-- Ignore the cases where the two lines are parallel.
	local denominator = a * c - b * b
	if denominator <= 0 then return p1, origin end

	local sc = (b*e - c*d) / denominator -- Position on the edge (self) between p1 and p2 and beyond.
	local tc = (a*e - b*d) / denominator -- Position on the given line between origin and (origin + dir) and beyond.

	-- Clamp
	local scClamped = math.Clamp(sc, 0, 1)

	return p1 + u * scClamped, origin + dir * tc
end

---Returns whether a ray from the given origin in the given direction dir intersects with the edge.
---The result is either nil or the distance from the origin as a fraction of dir length.
---This will not return anything behind the origin, or beyond the length of dir.
---@param origin GVector @Origin of the line or ray.
---@param dir GVector @Direction of the line or ray.
---@return number | nil dist @Distance from the origin as a fraction of dir length.
function NAV_EDGE:IntersectsRay(origin, dir)
	-- See: http://geomalgorithms.com/a07-_distance.html

	-- Approximate capsule shaped edge by checking if the smallest distance between the ray and segment is < edge radius.
	-- Also, subtract some amount ( √(radius² - dist²) ) from the calculated dist to give it some "volume".
	-- That should be good enough.

	local p1, p2 = self:GetPoints()
	local u = p2 - p1
	local w0 = p1 - origin
	local a, b, c, d, e = u:Dot(u), u:Dot(dir), dir:Dot(dir), u:Dot(w0), dir:Dot(w0)

	-- Ignore the cases where the two lines are parallel.
	local denominator = a*c - b*b
	if denominator <= 0 then return nil end

	local sc = (b*e - c*d) / denominator -- Position on the edge (self) between p1 and p2 and beyond.
	local tc = (a*e - b*d) / denominator -- Position on the given line between origin and (origin + dir) and beyond.

	-- Ignore if the element is behind the origin.
	if tc <= 0 then return nil end

	-- Clamp.
	local scClamped = math.Clamp(sc, 0, 1)

	-- Get resulting closest points.
	local res1, res2 = p1 + u*scClamped, origin + dir*tc

	-- Check if ray is not intersecting with the "capsule shape".
	local radiusSqr = self.DisplayRadius * self.DisplayRadius
	local distSqr = (res1 - res2):LengthSqr()
	if distSqr > radiusSqr then return nil end

	-- Subtract distance to sphere hull, to give the fake capsule its round shell.
	local d = tc - math.sqrt(radiusSqr - distSqr) / dir:Length()

	-- Ignore if the element is beyond dir length.
	if d > 1 then return nil end

	return d
end

---Draw the edge into a 3D rendering context.
function NAV_EDGE:Render3D()
	local ui = self.UI
	local p1, p2 = self:GetPoints()

	if ui.Highlighted then
		ui.Highlighted = nil
		cam.IgnoreZ(true)
		render.DrawBeam(p1, p2, self.DisplayRadius*2, 0, 1, Color(255, 255, 255, 127))
		cam.IgnoreZ(false)
	else
		--render.DrawLine(p1, p2, Color(255, 255, 255, 16), false)
		render.DrawLine(p1, p2, Color(255, 0, 0, 255), true)
		if self:IsWalled() then
			render.DrawBeam(p1 + Vector(0, 0, 1), p2 + Vector(0, 0, 1), self.DisplayRadius/2, 0, 1, Color(255, 255, 0, 127))
			--render.DrawLine(p1 + Vector(0, 0, 1), p2 + Vector(0, 0, 1), Color(255, 255, 0, 127), true)
		end
	end
end

---Define metamethod for string conversion.
---@return string
function NAV_EDGE:__tostring()
	return string.format("{Edge %s}", self:GetID())
end
