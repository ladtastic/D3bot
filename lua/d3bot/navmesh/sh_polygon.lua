-- Copyright (C) 2020-2021 David Vogel
--
-- This file is part of D3bot.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local ERROR = D3bot.ERROR

-- Predefine some local constants for optimization.
local COLOR_POLYGON_HIGHLIGHTED = Color(255, 0, 0, 127)
local COLOR_POLYGON_NORMAL = Color(255, 255, 255, 255)
local COLOR_POLYGON_GROUND = Color(255, 0, 0, 31)
local COLOR_POLYGON_OTHER = Color(255, 255, 0, 31)
local VECTOR_UP = Vector(0, 0, 1)
local VECTOR_DOWN = Vector(0, 0, -1)

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNAV_POLYGON
---@field Navmesh D3botNAV_MESH
---@field ID number | string
---@field Vertices D3botNAV_VERTEX[] @List of vertices that this polygon is made of.
---@field Edges D3botNAV_EDGE[] @List of edges, order corresponds with the vertex list. This is generated in the constructor.
---@field Cache table | nil @Contains cached values like the normal, the 3 corner points and neighbor polygons. Can be invalidated.
---@field UI table @General structure for UI related properties like selection status.
local NAV_POLYGON = D3bot.NAV_POLYGON
NAV_POLYGON.__index = NAV_POLYGON

-- Min height of any polygon.
--NAV_POLYGON.MinHeight = 5

-- Max distance a point is allowed to deviate from the average plane of all points.
NAV_POLYGON.MaxPlaneDeviation = 5

---Get new instance of a polygon object.
---This represents a polygon that is defined by n vertices that are connected in a loop.
---The normal of the polygon is determined by the direction of the vertex loop (right hand rule).
---If a polygon with the same id already exists, it will be replaced.
---There are some restrictions to what represents a valid polygon.
---If the polygon isn't nearly flat (no unique normal can be found), this function will fail.
---If the polygon isn't convex, this function will also fail.
---@param navmesh D3botNAV_MESH
---@param id number | string
---@param vertices D3botNAV_VERTEX[]
---@return D3botNAV_POLYGON | nil
---@return D3botERROR | nil err
function NAV_POLYGON:New(navmesh, id, vertices)
	local obj = setmetatable({
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(),
		Edges = {},
		Vertices = vertices,
		Cache = nil,
		UI = {},
	}, self)

	-- General parameter checks. -- TODO: Check parameters for types and other stuff
	if not navmesh then return nil, ERROR:New("Invalid value of parameter %q", "navmesh") end
	if not vertices then return nil, ERROR:New("Invalid value of parameter %q", "vertices") end

	-- TODO: Check if ID is used by a different entity type

	-- Get corner points.
	local cornerPoints = {}
	for _, vertex in ipairs(vertices) do
		table.insert(cornerPoints, vertex:GetPoint())
	end

	-- Check if the polygon is valid.
	local err = self:VerifyVertices(cornerPoints)
	if err then return nil, err end

	-- Get list of edges that corresponds with the vertex list.
	for i, v1 in ipairs(vertices) do
		local v2 = vertices[i%(#vertices)+1]
		local edge, err = navmesh:FindEdge2V(v1, v2)
		if err then return nil, err end
		table.insert(obj.Edges, edge)
	end

	-- TODO: Check polygon min. height
	-- Check the resulting polygon's min height.
	--[[local trianglePoints = {triangleVertices[1]:GetPoint(), triangleVertices[2]:GetPoint(), triangleVertices[3]:GetPoint()}
	local h1, h2, h3 = UTIL.GetTriangleHeights(trianglePoints[1], trianglePoints[2], trianglePoints[3])
	if math.min(h1, h2, h3) < obj.MinHeight then
		return nil, ERROR:New("The triangle's smallest height is below allowed min. height (%s < %s)", math.min(h1, h2, h3), obj.MinHeight)
	end]]

	-- Check if there is already an air connection connecting any of the edges.
	for i, e1 in ipairs(obj.Edges) do
		for i2 = i + 1, #obj.Edges do
			local e2 = obj.Edges[i2]
			for _, airConnection in pairs(navmesh.AirConnections) do
				if airConnection:ConsistsOfEdges(e1, e2) then
					return nil, ERROR:New("There is already a similar connection between %s and %s via %s", e1, e2, airConnection)
				end
			end
		end
	end

	-- Add reference to this polygon to all edges.
	for _, edge in ipairs(obj.Edges) do
		table.insert(edge.Polygons, obj)
	end

	-- Invalidate the cache of the neighbor polygons/air connections and their edges.
	-- It's ugly but has to be done.
	for _, edge in ipairs(obj.Edges) do
		for _, vertex in ipairs(edge.Vertices) do
			vertex:InvalidateCache()
		end
		for _, polygon in ipairs(edge.Polygons) do
			polygon:InvalidateCache()
			for _, edge2 in ipairs(polygon.Edges) do
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
	local old = navmesh.Polygons[obj.ID]
	if old then old:_Delete() end

	-- Add object to the navmesh.
	navmesh.Polygons[obj.ID] = obj

	-- Check if there are at most 2 polygons connected to each edge.
	for _, edge in ipairs(obj.Edges) do
		if #edge.Polygons > 2 then
			obj:_Delete()
			return nil, ERROR:New("There are already %d polygons connected to %s", #edge.Polygons, edge)
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
		navmesh.PubSub:SendPolygonToSubs(obj)
	end

	return obj, nil
end

---This verifies if a list of cornerPoints (vectors) can create a valid polygon.
---If the polygon isn't nearly flat (no unique normal can be found), this function will return an error.
---If the polygon isn't convex, this function will also return an error.
---@param cornerPoints GVector[]
---@return D3botERROR | nil err
function NAV_POLYGON:VerifyVertices(cornerPoints)
	local _, err = UTIL.CalculatePolygonNormal(cornerPoints, self.MaxPlaneDeviation)
	return err
end

---Same as NAV_POLYGON:New(), but uses table t to restore a previous state that came from MarshalToTable().
---As it needs a navmesh to find the edges by their reference ID, this should only be called after all the edges have been fully loaded into the navmesh.
---@param navmesh D3botNAV_MESH
---@param t table
---@return D3botNAV_POLYGON | nil
---@return D3botERROR | nil err
function NAV_POLYGON:NewFromTable(navmesh, t)
	if not t.Vertices then return nil, ERROR:New("The field %q is missing from the table", "Vertices") end

	local vertices = {}
	for _, vertexID in ipairs(t.Vertices) do
		local vertex = navmesh:FindVertexByID(vertexID)
		if not vertex then return nil, ERROR:New("Couldn't find all vertices by their reference") end
		table.insert(vertices, vertex)
	end

	local obj, err = self:New(navmesh, t.ID, vertices)
	return obj, err
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the object's ID, which is most likely a number object.
---It can also be a string, though.
---@return number | string
function NAV_POLYGON:GetID()
	return self.ID
end

---Returns a table that contains all important data of this object.
---@return table
function NAV_POLYGON:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Vertices = {},
	}

	for _, vertex in ipairs(self.Vertices) do
		table.insert(t.Vertices, vertex:GetID())
	end

	return t -- Make sure that any object returned here is a deep copy of its original.
end

---Get the cached values, if needed this will regenerate the cache.
--@return table
function NAV_POLYGON:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	self.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Get points (vectors) from the vertices.
	local cornerPoints = self:_GetPoints()
	cache.CornerPoints = cornerPoints

	-- Get neighbor polygons that are connected via edges.
	-- The polygon indices correspond to the edge indices.
	cache.NeighborPolygons = {}
	for i, edge in ipairs(self.Edges) do
		for _, polygon in ipairs(edge.Polygons) do
			if polygon ~= self then
				cache.NeighborPolygons[i] = polygon
				break
			end
		end
	end

	-- Calculate normal.
	cache.Normal = self:_GetNormal()
	if not cache.Normal then
		cache.IsValid = false
	end

	-- Calculate "centroid" center.
	cache.Centroid = self:_GetCentroid()

	-- List of "edge planes" that are orthogonal to the polygon surface and parallel to the edge.
	-- They point outside of the polygon.
	cache.EdgePlanes = self:_GetEdgePlanes()

	-- Determine locomotion type. (Hardcoded locomotion types)
	cache.LocomotionType = self:_GetLocomotionType()

	--[[ Exclude this, as paths don't start on polygons. They start on PATH_POINT objects.
	---A list of possible paths to take from this polygon.
	---@type D3botPATH_FRAGMENT[]
	cache.PathFragments = {}
	if cache.IsValid then
		-- Generate path fragments from this polygon to connected edges.
		for edgeIndex, edge in ipairs(self.Edges) do
			if #edge.Polygons + #edge.AirConnections > 1 then
				local eP1, eP2 = unpack(edge:_GetPoints())
				local edgeCenter = edge:_GetCentroid()
				local edgeVector = eP2 - eP1
				local pathDirection = edgeCenter - cache.Centroid -- Basically the walking direction.
				local polygonEdgePlane = cache.PolygonEdgePlanes[edgeIndex]
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
					LimitingPlanes = {},
					EndPlane = polygonEdgePlane,
					--StartPlane = nil,
				}
				-- Add edges to the limiting plane list.
				-- Limiting planes can be either walled or not.
				-- A walled limiting plane implies that the bot has to keep more distance (depending on the bot's hull) to the plane.
				-- TODO: If there is no direct walled edge, use neighbor walled edges
				for edgeIndex2, wEdge in ipairs(self.Edges) do
					if wEdge ~= edge then
						table.insert(pathFragment.LimitingPlanes, cache.PolygonEdgePlanes[edgeIndex2])
					end
				end
				table.insert(cache.PathFragments, pathFragment)
			end
		end
	end]]

	return cache
end

---Invalidate the cache, it will be regenerated on next use.
function NAV_POLYGON:InvalidateCache()
	self.Cache = nil
end

---Deletes the polygon from the navmesh and makes sure that there is nothing left that references it.
function NAV_POLYGON:Delete()
	-- Publish change event.
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteByIDFromSubs(self:GetID())
	end

	self:_Delete()
end

---Internal method.
function NAV_POLYGON:_Delete()
	-- Delete any reference to this polygon from edges.
	for _, edge in ipairs(self.Edges) do
		table.RemoveByValue(edge.Polygons, self)
		-- Invalidate cache of the edge.
		edge:InvalidateCache()
		-- Invalidate cache of vertices of the edge.
		for _, vertex in ipairs(edge.Vertices) do
			vertex:InvalidateCache()
		end
		-- Invalidate cache of the (other) connected polygons and air connections.
		for _, polygon in ipairs(edge.Polygons) do
			polygon:InvalidateCache()
		end
		for _, airConnection in ipairs(edge.AirConnections) do
			airConnection:InvalidateCache()
		end
	end

	local navmesh = self.Navmesh
	self.Navmesh = nil
	navmesh.Polygons[self.ID] = nil
end

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector
function NAV_POLYGON:GetCentroid()
	local cache = self:GetCache()
	return cache.Centroid
end

---Internal and uncached version of GetCentroid.
---@return GVector
function NAV_POLYGON:_GetCentroid()
	-- TODO: Calculate correct centroid of polygon, for now it's just the average of all corner points (Idea: This is correct for triangles, so it's possible to split the polygon into triangles and calculate the weighted average centroid of all centroids)

	local centroid = Vector()
	for _, vertex in ipairs(self.Vertices) do
		centroid:Add(vertex:GetPoint())
	end
	centroid:Div(#self.Vertices)

	return centroid
end

---Returns the points (vectors) that this entity is made of.
---May use the cache.
---@return GVector[]
function NAV_POLYGON:GetPoints()
	local cache = self:GetCache()
	return cache.CornerPoints
end

---Internal and uncached version of GetPoints.
---@return GVector[]
function NAV_POLYGON:_GetPoints()
	-- Get the corner points.
	local points = {}
	for _, vertex in ipairs(self.Vertices) do
		table.insert(points, vertex:GetPoint())
	end
	return points
end

---Returns the bounding box that includes all points of this entity.
---@return GVector min
---@return GVector max
function NAV_POLYGON:GetBoundingBox()
	local cache = self:GetCache()
	local min, max
	for _, point in ipairs(cache.CornerPoints) do
		if min then
			if min[1] > point[1] then min[1] = point[1] end
			if min[2] > point[2] then min[2] = point[2] end
			if min[3] > point[3] then min[3] = point[3] end
		else
			min = Vector(point)
		end
		if max then
			if max[1] < point[1] then max[1] = point[1] end
			if max[2] < point[2] then max[2] = point[2] end
			if max[3] < point[3] then max[3] = point[3] end
		else
			max = Vector(point)
		end
	end

	return min, max
end

---Returns the normal of the polygon.
---@return GVector | nil
function NAV_POLYGON:GetNormal()
	local cache = self:GetCache()
	return cache.Normal
end

---Internal and uncached version of GetNormal.
---@return GVector | nil
function NAV_POLYGON:_GetNormal()
	local cornerPoints = self:_GetPoints()
	local normal, err = UTIL.CalculatePolygonNormal(cornerPoints, self.MaxPlaneDeviation)
	if err then
		print(string.format("%s Failed to calculate normal for %s: %s", D3bot.PrintPrefix, self, err))
		return nil
	end

	return normal
end

---Returns a list of possible paths to take from this navmesh entity.
---The result is a list of path fragment tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_FRAGMENT[]
function NAV_POLYGON:GetPathFragments()
	local cache = self:GetCache()
	return cache.PathFragments
end

---Returns a list of planes for every edge.
---The planes are orthogonal to the polygon surface, and parallel to the edge.
---The normals of the planes are pointing to the outside of the polygon.
---@return table[]
function NAV_POLYGON:GetEdgePlanes()
	local cache = self:GetCache()
	return cache.EdgePlanes
end

---Internal and uncached version of GetEdgePlanes.
---@return table[]
function NAV_POLYGON:_GetEdgePlanes()
	local cornerPoints = self:_GetPoints()
	local normal = self:_GetNormal()

	local edgePlanes = {}
	if normal then
		for i, point in ipairs(cornerPoints) do
			local nextPoint = cornerPoints[i%(#cornerPoints)+1]
			local edge = self.Edges[i]
			local edgeNormal = (nextPoint - point):Cross(normal):GetNormalized()
			local edgeNormal2D = (nextPoint - point):Cross(VECTOR_UP):GetNormalized()
			if VECTOR_UP:Dot(normal) < 0 then edgeNormal2D:Mul(-1) end
			table.insert(edgePlanes, {Origin = (point + nextPoint)/2, Normal = edgeNormal, Normal2D = edgeNormal2D, IsWalled = edge:_IsWalled()})
		end
	end
	return edgePlanes
end

---Returns the locomotion type as a string.
---@return string
function NAV_POLYGON:GetLocomotionType()
	local cache = self:GetCache()
	return cache.LocomotionType
end

---Internal and uncached version of GetLocomotionType.
---@return string
function NAV_POLYGON:_GetLocomotionType()
	local normal = self:_GetNormal()

	local locType = "Ground" -- Default type.
	if normal then
		local cosine = normal:Dot(VECTOR_UP)
		if cosine < 0.2588190451 then
			locType = "Wall" -- Everything steeper than 75 deg is considered a wall.
		elseif cosine < 0.7071067812 then
			locType = "SteepGround" -- Everything steeper than 45 deg is considered a steep ground (That is not walkable normally).
		end
		-- TODO: Add user defined locomotion type override to polygons
	end

	return locType
end

---Returns whether the polygon consists out of the given vertices or not.
---@param vertices D3botNAV_VERTEX[]
---@return boolean
function NAV_POLYGON:ConsistsOfVertices(vertices)
	if #self.Vertices ~= #vertices then return false end

	-- Make copy of list.
	local sVertices = {unpack(self.Vertices)}

	-- Do a stupid linear search for every vertex entity.
	-- It's a slow operation, but as this is only called when editing the navmesh, it has no impact on bot performance.
	for _, vertex in ipairs(vertices) do
		local found = false
		for k, sVertex in pairs(sVertices) do
			if vertex == sVertex then
				sVertices[k], found = nil, true
				break
			end
		end
		-- Element not found, so there is a difference.
		if not found then
			return false
		end
	end

	-- Both lists contain the same elements, order may differ.
	return true
end

---Returns whether the polygon consists out of the given edges or not.
---@param edges D3botNAV_EDGE[]
---@return boolean
function NAV_POLYGON:ConsistsOfEdges(edges)
	if #self.Edges ~= #edges then return false end

	-- Make copy of list.
	local sEdges = {unpack(self.Edges)}

	-- Do a stupid linear search for every edge entity.
	-- It's a slow operation, but as this is only called when editing the navmesh, it has no impact on bot performance.
	for _, edge in ipairs(edges) do
		local found = false
		for k, sEdge in pairs(sEdges) do
			if edge == sEdge then
				sEdges[k], found = nil, true
				break
			end
		end
		-- Element not found, so there is a difference.
		if not found then
			return false
		end
	end

	-- Both lists contain the same elements, order may differ.
	return true
end

---Returns the winding order/direction relative to the given edge.
---true: Winding direction is aligned with the edge.
---false: Winding direction is aligned against the edge.
---nil: The edge is not used by the polygon.
---@param edge D3botNAV_EDGE
---@return boolean | nil
function NAV_POLYGON:WindingOrderToEdge(edge)
	local vertices = self.Vertices

	-- Find vertex pair that corresponds to the given edge and determine how the pair is aligned with the edge.
	for i, sEdge in ipairs(self.Edges) do
		if sEdge == edge then
			local v1, v2 = vertices[(i-1)%(#vertices)+1], vertices[i%(#vertices)+1]
			if v1 == edge.Vertices[1] and v2 == edge.Vertices[2] then return true end
			if v1 == edge.Vertices[2] and v2 == edge.Vertices[1] then return false end
			-- If this happens, something is really fucked.
			error(string.format("%s and %s don't correspond with %s. Something went really wrong somewhere else.", v1, v2, edge))
		end
	end

	-- The polygon doesn't use the given edge.
	return nil
end

---Calculates and changes the polygon's new FlipNormal state.
---The new direction will be determined by the neighbor polygons.
---If the neighbors give a conflicting conclusion, the polygon will be flipped so that the normal points upwards.
function NAV_POLYGON:RecalcFlipNormal()
	local cache = self:GetCache()

	local FlipCounter = 0

	for k, polygon in pairs(cache.NeighborPolygons) do
		local edge = self.Edges[k]
		local selfEdgeDirection, neighborEdgeDirection = self:WindingOrderToEdge(edge), polygon:WindingOrderToEdge(edge)
		if selfEdgeDirection == nil then print(string.format("%s self:WindingOrderToEdge for %s didn't find the edge %s", D3bot.PrintPrefix, self, edge)) end
		if neighborEdgeDirection == nil then print(string.format("%s polygon:WindingOrderToEdge for %s didn't find the edge %s", D3bot.PrintPrefix, polygon, edge)) end
		if selfEdgeDirection == neighborEdgeDirection then
			-- Edges align: Inverted winding order.
			FlipCounter = FlipCounter - 1
		else
			-- Edges don't align: Same winding order.
			FlipCounter = FlipCounter + 1
		end
	end

	if FlipCounter < 0 then
		-- Most neighbor polygons are flipped in the other direction.
		self:FlipNormal()
	elseif FlipCounter > 0 then
		-- Most neighbor polygons are aligned in the same direction.
	else
		-- Neighbor polygon normals are indecisive: Assume upwards is more likely to be correct.
		if cache.Normal[3] < 0 then
			self:FlipNormal()
		end
	end
end

---Flips the normal of the polygon by changing the order of the vertices (and edges).
function NAV_POLYGON:FlipNormal()
	local navmesh = self.Navmesh

	if #self.Vertices ~= #self.Edges then error("Uh oh") end
	local entityCount = #self.Vertices

	-- Change order of the vertices and edges without destroying the interrelationship between both lists.
	-- Also, this will keep the first vertex at the first index.
	local vertices, edges = {}, {}
	for edgeIndex = entityCount, 1, -1 do
		local vertexIndex = edgeIndex%(entityCount) + 1
		table.insert(edges, self.Edges[edgeIndex])
		table.insert(vertices, self.Vertices[vertexIndex])
	end

	self.Vertices, self.Edges = vertices, edges

	-- Recalc normal, neighbor polygons, corner positions and other stuff.
	self:InvalidateCache()

	-- Publish change event.
	if navmesh and navmesh.PubSub then
		navmesh.PubSub:SendPolygonToSubs(self)
	end
end

---Returns the closest point to the given point p.
---@param p GVector
---@return GVector
function NAV_POLYGON:GetClosestPointToPoint(p)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local normal = cache.Normal
	local p1 = cache.CornerPoints[1]

	-- Project the point p onto the plane.
	local projected = p + normal:Dot(p1 - p) * normal

	-- Get the edge plane that has the largest distance to the projected point (only positive distance).
	local maxNormDist = 0
	local maxIndex
	for i, edgePlane in ipairs(cache.EdgePlanes) do
		local dist = edgePlane.Normal:Dot(projected - edgePlane.Origin)
		if maxNormDist < dist then
			maxNormDist, maxIndex = dist, i
		end
	end

	-- Point is outside, maxIndex is the index of the edge that has the largest distance to the point.
	-- Find the closest point on the edge that is also clamped to the edge length.
	if maxIndex then
		local edge = self.Edges[maxIndex]
		local eP1 = edge:GetPoints()[1]
		local edgeVector = edge:GetVector()
		local edgeFraction = math.Clamp((projected - eP1):Dot(edgeVector) / edgeVector:LengthSqr(), 0, 1)
		return eP1 + edgeVector * edgeFraction
	end

	-- Point is inside/on the polygon.
	return projected
end

---Returns the closest squared distance to the given point p.
---@param p GVector
---@return number
function NAV_POLYGON:GetClosestDistanceSqr(p)
	local selfP = self:GetClosestPointToPoint(p)
	return (selfP - p):LengthSqr()
end

---Returns whether a ray from the given origin in the given direction dir intersects with the polygon.
---The result is either nil or the distance from the origin as a fraction of dir length.
---This will not return anything behind the origin, or beyond the length of dir.
---@param origin GVector @Ray origin.
---@param dir GVector @Ray direction.
---@return number | nil distance
function NAV_POLYGON:IntersectsRay(origin, dir)
	local cache = self:GetCache()
	if not cache.IsValid then return nil end

	local normal = cache.Normal
	local p1 = cache.CornerPoints[1]

	-- Ignore all cases where the ray and the plane are parallel.
	local denominator = dir:Dot(normal)
	if denominator == 0 then return nil end

	-- Get intersection distance and point.
	local d = (p1 - origin):Dot(normal) / denominator
	local intersectionPoint = origin + dir * d

	-- Ignore if the element is behind the origin or beyond dir length.
	if d <= 0 then return nil end
	if d > 1 then return nil end

	-- Check if the intersection lies outside of the polygon.
	for i, edgePlane in ipairs(cache.EdgePlanes) do
		local dist = edgePlane.Normal:Dot(intersectionPoint - edgePlane.Origin)
		if dist > 0 then
			return nil
		end
	end

	return d
end

---Draw the edge into a 3D rendering context.
function NAV_POLYGON:Render3D()
	local cache = self:GetCache()
	local ui = self.UI
	local cornerPoints = cache.CornerPoints
	local normal, centroid = cache.Normal, cache.Centroid
	local tinyNormal = normal * 0.3

	-- Draw closest points to player trace for debugging.
	--local trRes = LocalPlayer():GetEyeTrace()
	--local clampedPos = self:GetClosestPointToPoint(trRes.HitPos)
	--render.DrawSphere(clampedPos, 10, 6, 6, Color(255, 255, 255, 127))

	if cornerPoints then
		if ui.Highlighted then
			ui.Highlighted = nil
			cam.IgnoreZ(true)
			RENDER_UTIL.DrawPolygon2Sided(cornerPoints, COLOR_POLYGON_HIGHLIGHTED)
			cam.IgnoreZ(false)

			render.DrawLine(centroid, centroid + normal * 30, COLOR_POLYGON_NORMAL, true)
			if CONVARS.NavmeshZCulling:GetBool() then render.SetColorMaterial()	else render.SetColorMaterialIgnoreZ() end -- Necessary here after some gMod update. DrawLine seems to overwrite the material now.
		else
			if self:GetLocomotionType() == "Ground" then
				RENDER_UTIL.DrawPolygon2Sided(cornerPoints, COLOR_POLYGON_GROUND, tinyNormal)
			else
				RENDER_UTIL.DrawPolygon2Sided(cornerPoints, COLOR_POLYGON_OTHER, tinyNormal)
			end
		end
	end
end

---Define metamethod for string conversion.
---@return string
function NAV_POLYGON:__tostring()
	return string.format("{Polygon %s}", self:GetID())
end
