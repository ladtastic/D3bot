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
local RENDER_UTIL = D3bot.RenderUtil
local ERROR = D3bot.ERROR

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNAV_AIR_CONNECTION
---@field Navmesh D3botNAV_MESH
---@field ID number | string
---@field Edges D3botNAV_EDGE[]
---@field Cache table | nil @Contains cached values. Can be invalidated.
---@field UI table @General structure for UI related properties like selection status.
local NAV_AIR_CONNECTION = D3bot.NAV_AIR_CONNECTION
NAV_AIR_CONNECTION.__index = NAV_AIR_CONNECTION

-- Radius of the air connection used for drawing and mouse click tracing.
NAV_AIR_CONNECTION.DisplayRadius = 10

-- Min length of the connection.
NAV_AIR_CONNECTION.MinLength = 10

---Get new instance of an air connection object.
---This represents connection "over the air" between two edges.
---If an entity with the same id already exists, it will be replaced.
---@param navmesh D3botNAV_MESH
---@param id number | string
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@return D3botNAV_AIR_CONNECTION | nil
---@return D3botERROR | nil err
function NAV_AIR_CONNECTION:New(navmesh, id, e1, e2)
	local obj = setmetatable({
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(),
		Edges = {e1, e2},
		Cache = nil,
		UI = {},
	}, self)

	-- General parameter checks. -- TODO: Check parameters for types and other stuff
	if not navmesh then return nil, ERROR:New("Invalid value of parameter %q", "navmesh") end
	if not e1 then return nil, ERROR:New("Invalid value of parameter %q", "e1") end
	if not e2 then return nil, ERROR:New("Invalid value of parameter %q", "e2") end

	local e1Centroid, e2Centroid = e1:GetCentroid(), e2:GetCentroid()

	-- Check if it's below min length.
	if e1Centroid:Distance(e2Centroid) < obj.MinLength then
		return nil, ERROR:New("Distance between edges is too short: %s < %s", e1Centroid:Distance(e2Centroid), obj.MinLength)
	end

	-- Check if there is already a triangle connecting the two edges.
	for _, triangle in ipairs(e1.Triangles) do
		if triangle.Edges[1] == e2 or triangle.Edges[2] == e2 or triangle.Edges[3] == e2 then
			return nil, ERROR:New("There is already a similar connection between %s and %s via %s", e1, e2, triangle)
		end
	end

	-- Add reference to this air connection to its edges.
	table.insert(e1.AirConnections, obj)
	table.insert(e2.AirConnections, obj)

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
	local old = navmesh.AirConnections[obj.ID]
	if old then old:_Delete() end

	-- Add object to the navmesh.
	navmesh.AirConnections[obj.ID] = obj

	-- Check if cache is valid, if not abort and delete.
	local cache = obj:GetCache()
	if not cache.IsValid then
		obj:_Delete()
		return nil, ERROR:New("Failed to generate valid cache")
	end

	-- Publish change event.
	if navmesh.PubSub then
		navmesh.PubSub:SendAirConnectionToSubs(obj)
	end

	return obj, nil
end

---Same as NAV_AIR_CONNECTION:New(), but uses table t to restore a previous state that came from MarshalToTable().
---As it needs a navmesh to find the edges by their reference ID, this should only be called after all the edges have been fully loaded into the navmesh.
---@param navmesh D3botNAV_MESH
---@param t table
---@return D3botNAV_AIR_CONNECTION | nil
---@return D3botERROR | nil err
function NAV_AIR_CONNECTION:NewFromTable(navmesh, t)
	local e1 = navmesh:FindEdgeByID(t.Edges[1])
	local e2 = navmesh:FindEdgeByID(t.Edges[2])

	if not e1 or not e2 then return nil, ERROR:New("Couldn't find all edges by their reference") end

	local obj, err = self:New(navmesh, t.ID, e1, e2)

	return obj, err
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the object's ID, which is most likely a number object.
---It can be anything else, though.
---@return number | string
function NAV_AIR_CONNECTION:GetID()
	return self.ID
end

---Returns a table that contains all important data of this object.
---@return table
function NAV_AIR_CONNECTION:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Edges = {
			self.Edges[1]:GetID(),
			self.Edges[2]:GetID(),
		}
	}

	return t -- Make sure that any object returned here is a deep copy of its original.
end

---Get the cached values, if needed this will regenerate the cache.
--@return table
function NAV_AIR_CONNECTION:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	self.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Get the two endpoints of the connection. (Without using the cache)
	local point1, point2 = (self.Edges[1].Points[1] + self.Edges[1].Points[2])/2, (self.Edges[2].Points[1] + self.Edges[2].Points[2])/2
	cache.Point1, cache.Point2 = point1, point2

	-- Calculate "centroid" center.
	cache.Centroid = (point1 + point2) / 3

	-- Determine locomotion type. (Hardcoded locomotion types)
	cache.LocomotionType = "AirHorizontal" -- Default type
	local direction = (point2 - point1)
	local angle = direction:Angle()
	-- Everything steeper than 45 deg is considered vertical.
	if angle.pitch < -45 or angle.pitch > 45 then
		cache.LocomotionType = "AirVertical"
	end
	-- TODO: Add user defined locomotion type override to air connections

	---A list of possible paths to take from this air connection.
	---@type D3botPATH_FRAGMENT[]
	cache.PathFragments = {}
	if cache.IsValid then
		for _, edge in ipairs(self.Edges) do
			if #edge.Triangles + #edge.AirConnections > 1 then
				local edgeCenter = (edge.Points[1] + edge.Points[2]) / 2
				local edgeVector = edge.Points[2] - edge.Points[1]
				local pathDirection = edgeCenter - cache.Centroid -- Basically the walking direction.
				local edgeOrthogonal = pathDirection:Cross(edgeVector):Cross(edgeVector) -- Vector that is orthogonal to the edge.
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
function NAV_AIR_CONNECTION:InvalidateCache()
	self.Cache = nil
end

---Deletes the air connection from the navmesh and makes sure that there is nothing left that references it.
function NAV_AIR_CONNECTION:Delete()
	-- Publish change event.
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteByIDFromSubs(self:GetID())
	end

	self:_Delete()
end

---Internal method.
function NAV_AIR_CONNECTION:_Delete()
	-- Delete any reference to this air connection from edges.
	for _, edge in ipairs(self.Edges) do
		table.RemoveByValue(edge.AirConnections, self)
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
	navmesh.AirConnections[self.ID] = nil
end

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector | nil
function NAV_AIR_CONNECTION:GetCentroid()
	local cache = self:GetCache()
	return cache.Centroid
end

---Returns a list of possible paths to take from this navmesh entity.
---The result is a list of path fragment tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_FRAGMENT[]
function NAV_AIR_CONNECTION:GetPathFragments()
	local cache = self:GetCache()
	return cache.PathFragments
end

---Returns the locomotion type as a string.
---@return string
function NAV_AIR_CONNECTION:GetLocomotionType()
	local cache = self:GetCache()
	return cache.LocomotionType
end

---Returns whether the air connection consists out of the two given edges or not.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@return boolean
function NAV_AIR_CONNECTION:ConsistsOfEdges(e1, e2)
	local se1, se2= self.Edges[1], self.Edges[2]
	if se1 == e1 and se2 == e2 then return true end
	if se1 == e2 and se2 == e1 then return true end
	return false
end

---Returns the closest point to the given point p.
---@param p GVector
---@return GVector
function NAV_AIR_CONNECTION:GetClosestPointToPoint(p)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local p1, p2 = cache.Point1, cache.Point2

	-- Get position as a fraction between point 1 and 2.
	local direction = (p2 - p1)
	local comparisonDirection = (p - p1)
	local fraction = direction:Dot(comparisonDirection) / direction:Length()

	-- Clamp fraction.
	local fractionClamped = math.Clamp(fraction, 0, 1)

	-- Return clamped position.
	return p1 + fractionClamped * direction
end

---Returns the closest squared distance to the given point p.
---@param p GVector
---@return number
function NAV_AIR_CONNECTION:GetClosestDistanceSqr(p)
	local selfP = self:GetClosestPointToPoint(p)
	return (selfP - p):LengthSqr()
end

---Returns whether a ray from the given origin in the given direction dir intersects with the air connection.
---The result is either nil or the distance from the origin as a fraction of dir length.
---This will not return anything behind the origin, or beyond the length of dir.
---@param origin GVector @Ray origin.
---@param dir GVector @Ray direction.
---@return number | nil distance
function NAV_AIR_CONNECTION:IntersectsRay(origin, dir)
	-- See: http://geomalgorithms.com/a07-_distance.html

	-- Approximate capsule shaped object by checking if the smallest distance between the ray and segment is < edge radius.
	-- Also, subtract some amount ( √(radius² - dist²) ) from the calculated dist to give it some "volume".
	-- That should be good enough.

	local cache = self:GetCache()

	local p1, p2 = cache.Point1, cache.Point2
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

---Draw the air connection into a 3D rendering context.
function NAV_AIR_CONNECTION:Render3D()
	local cache = self:GetCache()
	local ui = self.UI
	local p1, p2 = cache.Point1, cache.Point2
	local center = (p1 + p2) / 2
	local color = Color(255, 255, 0, 127)

	if ui.Highlighted then
		color = Color(255, 255, 255, 255)
		cam.IgnoreZ(true)
	end

	RENDER_UTIL.Draw2DArrow2SidedRotatingPos(center, p1, self.DisplayRadius*6, -0.5, color)
	RENDER_UTIL.Draw2DArrow2SidedRotatingPos(center, p2, self.DisplayRadius*6, 0.5, color)

	if ui.Highlighted then
		ui.Highlighted = nil
		cam.IgnoreZ(false)
	end
end

---Define metamethod for string conversion.
---@return string
function NAV_AIR_CONNECTION:__tostring()
	return string.format("{Air connection %s}", self:GetID())
end
