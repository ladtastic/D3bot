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

AddCSLuaFile()

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local ERROR = D3bot.ERROR

---Get a map with all currently used usernames (ply:Nick() of all players).
---@return table usernames @Map with username mapped to player objects.
function UTIL.GetUsernamesMap()
	local usernames = {}
	for _, ply in pairs(player.GetAll()) do
		usernames[ply:Nick()] = ply
	end
	return usernames
end

---Floors the coordinates of a vector.
---@param vec GVector
---@return GVector
function UTIL.FloorVector(vec)
	return Vector(math.floor(vec[1]), math.floor(vec[2]), math.floor(vec[3]))
end

---Rounds the coordinates of a vector.
---@param vec GVector
---@return GVector
function UTIL.RoundVector(vec)
	return Vector(math.floor(vec[1] + 0.5), math.floor(vec[2] + 0.5), math.floor(vec[3] + 0.5))
end

---Returns whether a number is positive (including positive 0) or not.
---Unlike the mathematical sign function, this only returns a bool.
---@param num number
---@return boolean positive @True if num >= 0 and false otherwise.
function UTIL.PositiveNumber(num)
	if num >= 0 then
		return true
	else
		return false
	end
end

---Returns the sign of a given number as integer.
---@param num number
---@return integer sign @1 when num > 0, -1 when num < -0, otherwise 0
function UTIL.Sign(num)
	if num > 0 then
		return 1
	elseif num < -0 then
		return -1
	else
		return 0
	end
end

---Realm bitmasks/enumerations.
---@alias D3botRealmEnum "UTIL.REALM_SERVER" | "UTIL.REALM_CLIENT" | "UTIL.REALM_SHARED"
UTIL.REALM_SERVER = 1 -- 0b01
UTIL.REALM_CLIENT = 2 -- 0b10
UTIL.REALM_SHARED = 3 -- 0b11

-- TODO: Add function that determines realm by filename/path

---Include a lua file into the given realm.
---This helper must be run in the "shared" realm to work properly, and the usage of any AddCSLuaFile() is not necessary.
--- - UTIL.REALM_SERVER: The file will only be included on the server side.
--- - UTIL.REALM_CLIENT: The file will only be included on the client side. Additionally the file will be marked with AddCSLuaFile.
--- - UTIL.REALM_SHARED: The file will only be included on both sides. Additionally the file will be marked with AddCSLuaFile.
---@param path string @The (relative) path of the file to include.
---@param realm D3botRealmEnum @The realm the file will be loaded into.
function UTIL.IncludeRealm(path, realm)
	if realm == UTIL.REALM_SERVER then
		if SERVER then include(path) end
	elseif realm == UTIL.REALM_CLIENT then
		if SERVER then AddCSLuaFile(path) end
		if CLIENT then include(path) end
	elseif realm == UTIL.REALM_SHARED then
		if SERVER then AddCSLuaFile(path) end
		include(path)
	else
		error("Invalid realm")
	end
end

---Includes all (lua) files in the given directory path + filename into a specific realm.
---Example: UTIL.IncludeDirectory("foo/bar/", "sv_*.lua", UTIL.REALM_SERVER)
---@param path string @The absolute path (relative to gmod's lua directory).
---@param name string @The filename inside the given path, can contain `*` wildcards.
---@param realm D3botRealmEnum @The realm the file will be loaded into.
function UTIL.IncludeDirectory(path, name, realm)
	local filenames, _ = file.Find(path .. name, "LUA")
	for _, filename in ipairs(filenames) do
		UTIL.IncludeRealm(path .. filename, realm)
	end
end

---Sorted version of pairs: This will iterate in ascending key order over any map/sparse array.
---@param m table @The table to be iterated over.
---@return function iterator @The iterator function.
function UTIL.kpairs(m)
	-- Get keys of m.
	local keys = {}
	for k in pairs(m) do
		table.insert(keys, k)
	end

	-- Sort keys.
	table.sort(keys)

	-- Return iterator.
	local i = 0
	return function()
		i = i + 1
		local key = keys[i]
		if key then
			return key, m[key]
		end
	end
end

---Returns the closest point from the list points to a given point p with a search radius of r.
---@param points table<any,GVector> @Can be any sparse array/map that contains vectors as values.
---@param p GVector
---@param r number
---@return GVector | nil @Resulting closest point, or nil.
function UTIL.GetNearestPoint(points, p, r)
	-- Stupid linear search for the closest point.
	local minDistSqr = (r and r * r) or math.huge
	local resultPoint
	for _, point in pairs(points) do ---@type GVector @Needs to be pairs, as it needs to support sparse arrays/maps.
		local distSqr = p:DistToSqr(point)
		if minDistSqr > distSqr then
			minDistSqr = distSqr
			resultPoint = point
		end
	end

	return resultPoint
end

---Returns the barycentric u, v, w coordinates of point p of the triangle defined by p1, p2 and p3.
---@param p1 GVector
---@param p2 GVector
---@param p3 GVector
---@param p GVector @Point in 3D space, that will be projected onto the triangle.
---@return number u
---@return number v
---@return number w
function UTIL.GetBarycentric3D(p1, p2, p3, p)
	-- See: https://gamedev.stackexchange.com/a/23745

	local v1, v2, v3 = p2 - p1, p3 - p1, p - p1
	local d11, d12, d22, d31, d32 = v1:Dot(v1), v1:Dot(v2), v2:Dot(v2), v3:Dot(v1), v3:Dot(v2)
	local denom = d11 * d22 - d12 * d12
	local v = (d22 * d31 - d12 * d32) / denom
	local w = (d11 * d32 - d12 * d31) / denom
	local u = 1 - v - w

	return u, v, w
end

---Returns the barycentric coordinates of point p of the triangle defined by p1, p2 and p3.
---This will clamp the coordinates in a way that the resulting u, v and w represent a point inside the triangle with the shortest distance to p.
---@param p1 GVector
---@param p2 GVector
---@param p3 GVector
---@param p GVector @Point in 3D space, that will be projected and clamped to the inside of the triangle.
---@return number u
---@return number v
---@return number w
function UTIL.GetBarycentric3DClamped(p1, p2, p3, p)
	-- See: https://stackoverflow.com/a/37923949/14967192
	-- Even though the stackoverflow example has an edge case that produces wrong results.

	local u, v, w = UTIL.GetBarycentric3D(p1, p2, p3, p)

	-- The point is outside of the triangle at the edge between p2 and p3.
	if u < 0 and u <= v and u <= w then
		local t = (p - p2):Dot(p3 - p2) / (p3 - p2):Dot(p3 - p2)
		t = math.Clamp(t, 0, 1)
		return 0, 1 - t, t
	end
	-- The point is outside of the triangle at the edge between p1 and p3.
	if v < 0 and v <= u and v <= w then
		local t = (p - p3):Dot(p1 - p3) / (p1 - p3):Dot(p1 - p3)
		t = math.Clamp(t, 0, 1)
		return t, 0, 1 - t
	end
	-- The point is outside of the triangle at the edge between p1 and p2.
	if w < 0 and w <= u and w <= v then
		local t = (p - p1):Dot(p2 - p1) / (p2 - p1):Dot(p2 - p1)
		t = math.Clamp(t, 0, 1)
		return 1 - t, t, 0
	end

	-- Point is inside of the triangle.
	return u, v, w
end

---Returns the 3 heights of the triangle defined by 3 points.
---A height is the shortest distance from a triangle corner to its opposite edge.
---@param p1 GVector
---@param p2 GVector
---@param p3 GVector
---@return number h1 @Shortest distance from p1 to opposite side.
---@return number h2 @Shortest distance from p2 to opposite side.
---@return number h3 @Shortest distance from p3 to opposite side.
function UTIL.GetTriangleHeights(p1, p2, p3)
	local e1, e2, e3 = p2-p3, p1-p3, p1-p2
	local parallelArea = e1:Cross(e2):Length()

	return parallelArea / e1:Length(), parallelArea / e2:Length(), parallelArea / e3:Length()
end

---Returns the closest entity from lists of entities that intersects with a ray from the given origin in the given direction dir.
---The entities in the supplied lists have to implement the IntersectsRay method.
---The result is either nil or the intersecting entity, and its distance from the origin as a fraction of dir length.
---This will not return anything behind the origin, or beyond the length of dir.
---@param origin GVector @Ray origin.
---@param dir GVector @Ray direction, the length defines the search range.
--@vararg table[] @Maps containing entities.
---@return table | nil minEntity @Closest intersecting entity or nil.
---@return number minDist @Minimal dist, or 1 if nothing was found.
function UTIL.GetClosestIntersectingWithRay(origin, dir, ...)
	local lists = {...}
	local minDist = 1
	local minEntity = nil

	for _, list in ipairs(lists) do
		for _, entity in pairs(list) do
			local dist = entity:IntersectsRay(origin, dir)
			if dist and minDist > dist then
				minDist = dist
				minEntity = entity
			end
		end
	end

	return minEntity, minDist
end

---Returns the closest entity from lists of entities to the point pos.
---The entities in the supplied lists have to implement the GetClosestDistanceSqr method.
---The result is either nil or the closest entity, and the minimal squared distance.
---@param pos GVector
--@vararg table[] @Maps containing entities.
---@return table | nil minEntity @Closest entity or nil.
---@return number minDist @Minimal dist, or infinity if nothing was found.
function UTIL.GetClosestToPos(pos, ...)
	local lists = {...}
	local minDist = math.huge
	local minEntity = nil

	for _, list in ipairs(lists) do
		for _, entity in pairs(list) do
			local dist = entity:GetClosestDistanceSqr(pos)
			if dist and minDist > dist then
				minDist = dist
				minEntity = entity
			end
		end
	end

	return minEntity, minDist
end

---Returns pos snapped to the closest (in proximity range) snapping point of a given navmesh or map geometry.
---Additionally this will round the vector to one source engine unit.
---The result is a snapped point and a bool stating if the pos got snapped or not.
---@param navmesh D3botNAV_MESH
---@param mapgeometry D3botMAPGEOMETRY
---@param pos GVector
---@param proximity number
---@return GVector pos
---@return boolean snapped
function UTIL.GetSnappedPosition(navmesh, mapgeometry, pos, proximity)
	local posGeometry = mapgeometry and mapgeometry:GetNearestPoint(pos, proximity)
	local posNavmesh = navmesh and navmesh:GetNearestPoint(pos, proximity)
	local snapped = UTIL.GetNearestPoint({posGeometry, posNavmesh}, pos)
	return UTIL.RoundVector(snapped or pos), snapped ~= nil
end

---Takes an array (not map/table) with edges and returns its unique vertices.
---This will always return the vertices in a predictable order.
---@param edges D3botNAV_EDGE[]
---@return D3botNAV_VERTEX[]
function UTIL.EdgesToVertices(edges)
	local vertices = {}
	for _, edge in ipairs(edges) do
		for _, newVertex in ipairs(edge.Vertices) do
			local found = false
			-- Check if vertex is already in the list.
			for _, vertex in ipairs(vertices) do
				if vertex == newVertex then
					found = true
					break
				end
			end

			if not found then
				table.insert(vertices, newVertex)
			end
		end
	end

	return vertices
end

---Takes an array (not map/table) with edges and returns 3 vertices that form a triangle, or an error if it's impossible.
---This will also return the vertices as array in a predictable order.
---@param edges D3botNAV_EDGE[]
---@return D3botNAV_VERTEX[] | nil
---@return D3botERROR | nil err
function UTIL.EdgesToTriangleVertices(edges)
	if #edges ~= 3 then return nil, ERROR:New("There is an unexpected amount of edges. Want %d, got %d", 3, #edges) end

	local vertices = UTIL.EdgesToVertices(edges)
	if #vertices ~= 3 then return nil, ERROR:New("There is an unexpected amount of vertices. Want %d, got %d", 3, #vertices) end

	return vertices, nil
end

---Helper function for SWEPs that does a line trace on the given player.
---It returns the trace table tr, the result of the trace trRes and a ray (origin, direction) that can be used for navmesh entity tracing.
---The result depends on the client's convars.
---This works best in the client realm, don't expect the same result in the server realm.
---@param ply GPlayer
---@return table tr @The trace query table.
---@return table trRes @The trace result table.
---@return GVector navAimOrigin @Ray origin that can be used for tracing navmesh elements.
---@return GVector navAimVec @Ray direction vector.
function UTIL.SWEPLineTrace(ply)
	local shouldHitWater = CONVARS.SWEPHitWater:GetBool()

	-- Get normal player eye trace.
	local tr = util.GetPlayerTrace(ply)

	-- Add water to trace mask.
	if shouldHitWater then
		tr.mask = tr.mask or MASK_SOLID + MASK_WATER
	end

	-- Trace, duh.
	local trRes = util.TraceLine(tr)

	-- Edge case for water traces: Redo trace without water mask, if trace starts inside a sold/water brush.
	if shouldHitWater and trRes.StartSolid then
		tr.mask = tr.mask - MASK_WATER
		trRes = util.TraceLine(tr)
	end

	-- Define ray for navmesh entity tracing.
	-- Act differently based on if z-culling is enabled or not.
	local navAimOrigin = tr.start
	local navAimVec = trRes.Normal * 32000
	if CONVARS.NavmeshZCulling:GetBool() then
		navAimVec = trRes.HitPos - navAimOrigin + trRes.Normal * 20 -- Add a bit more to allow for selection of entities inside geometry.
	end

	return tr, trRes, navAimOrigin, navAimVec
end
