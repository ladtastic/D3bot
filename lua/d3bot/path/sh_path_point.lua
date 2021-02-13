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
local ERROR = D3bot.ERROR
local UTIL = D3bot.Util

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botPATH_POINT
---@field Navmesh D3botNAV_MESH
---@field Pos GVector
---@field Triangle D3botNAV_TRIANGLE @The triangle that the point lies on (or is closest to)
---@field PathFragments D3botPATH_FRAGMENT[]
---@field InjectionPathFragment D3botPATH_FRAGMENT
local PATH_POINT = D3bot.PATH_POINT
PATH_POINT.__index = PATH_POINT

---Get new instance of a path point object.
---This is not a point of a path, but a helper point for the start and destination positions of paths.
---It will implement methods similar to navmesh entities so that it can be used in the pathfinder.
---@param navmesh D3botNAV_MESH
---@param pos GVector
---@return D3botPATH_POINT | nil
---@return D3botERROR | nil err
function PATH_POINT:New(navmesh, pos)
	local obj = setmetatable({
		Navmesh = navmesh,
		Pos = pos,
		InjectionPathFragment = {},
	}, self)

	-- Check if there is even a position.
	if not pos then
		return nil, ERROR:New("Invalid position given")
	end

	-- Get triangle that the point is on.
	obj.Triangle = UTIL.GetClosestToPos(pos, navmesh.Triangles)
	if not obj.Triangle then
		return nil, ERROR:New("Can't find closest triangle for point %s", pos)
	end

	-- Triangle normal.
	local triangleNormal = obj.Triangle:GetCache().Normal

	---A list of possible paths to take from this point.
	---@type D3botPATH_FRAGMENT[]
	obj.PathFragments = {}
	for _, edge in ipairs(obj.Triangle.Edges) do
		if #edge.Triangles + #edge.AirConnections > 1 then
			local eP1, eP2 = edge:GetPoints()
			local edgeCenter = edge:GetCentroid() -- Use cache as it may be faster.
			local edgeVector = eP2 - eP1
			local edgeOrthogonal = triangleNormal:Cross(edgeVector) -- Vector that is orthogonal to the edge and parallel to the triangle plane.
			local pathDirection = edgeCenter - pos -- Basically the walking direction.
			---@type D3botPATH_FRAGMENT
			local pathFragment = {
				From = obj,
				FromPos = pos,
				Via = obj.Triangle,
				To = edge,
				ToPos = edgeCenter,
				ToOrthogonal = (edgeOrthogonal * (edgeOrthogonal:Dot(pathDirection))):GetNormalized(), -- Vector for path end condition that is orthogonal to the edge and parallel to the triangle plane, additionally it always points outside the triangle.
				LocomotionType = obj.Triangle:GetLocomotionType(),
				PathDirection = pathDirection, -- Vector from start position to dest position.
				Distance = pathDirection:Length(), -- Distance from start to dest.
			}
			table.insert(obj.PathFragments, pathFragment)
		end
	end

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector
function PATH_POINT:GetCentroid()
	return self.Pos
end

---Returns the points (vectors) that this entity is made of.
---May use the cache.
---@return GVector
function PATH_POINT:GetPoints()
	return self.Pos
end

---Internal and uncached version of GetPoints.
---@return GVector
function PATH_POINT:_GetPoints()
	return self.Pos
end

---Returns the list of vertices that this entity is made of.
function PATH_POINT:GetVertices() end

---Returns the vector that describes this path point.
---@return GVector
function PATH_POINT:GetPoint()
	return self.Pos
end

---Returns a list of possible paths to take from this navmesh entity.
---The result is a list of path fragment tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_FRAGMENT[]
function PATH_POINT:GetPathFragments()
	return self.PathFragments
end

---Returns a single path fragment that can be injected into the pathFragments list in the pathfinding routine.
---This is basically the path fragment from any edge "from" to the PATH_POINT itself.
---This should be injected on edges of the triangle that the PATH_POINT is inside of.
---@param from table
---@param fromPos GVector
---@return D3botPATH_FRAGMENT
function PATH_POINT:GetPathFragmentsForInjection(from, fromPos)
	local pathDirection = self.Pos - fromPos -- Basically the walking direction.
	local pathLength = pathDirection:Length()

	local pathFragment = self.InjectionPathFragment

	pathFragment.From = from
	pathFragment.FromPos = fromPos
	pathFragment.Via = self.Triangle
	pathFragment.To = self
	pathFragment.ToPos = self.Pos
	pathFragment.ToOrthogonal = pathDirection / pathLength -- Vector for the end condition of this path element.
	pathFragment.LocomotionType = self.Triangle:GetLocomotionType()
	pathFragment.PathDirection = pathDirection -- Vector from start position to dest position.
	pathFragment.Distance = pathLength -- Distance from start to dest.

	return pathFragment
end

---Change the position of the path point.
---This assumes that the point is still in the previous triangle.
---@param pos GVector
function PATH_POINT:UpdatePosition(pos)
	self.Pos = pos

	-- Update some values of the path fragment.
	local pathFragment = self.InjectionPathFragment
	pathFragment.ToPos = pos
end

---Define metamethod for string conversion.
---@return string
function PATH_POINT:__tostring()
	return string.format("{Path point %s}", self.Pos)
end
