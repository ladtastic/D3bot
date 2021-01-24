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
local ERROR = D3bot.ERROR
local UTIL = D3bot.Util

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botPATH_POINT
---@field Navmesh D3botNAV_MESH
---@field Pos GVector
---@field Triangle D3botNAV_TRIANGLE @The triangle that the point lies on (or is closest to)
---@field PathfindingNeighbors table[]
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
		Pos = pos
	}, self)

	-- Check if there is even a position
	if not pos then
		return nil, ERROR:New("Invalid position given")
	end

	-- Get triangle that the point is on
	obj.Triangle = UTIL.GetClosestToPos(pos, navmesh.Triangles)
	if not obj.Triangle then
		return nil, ERROR:New("Can't find closest triangle for point %s", pos)
	end

	-- Triangle normal
	local triangleNormal = obj.Triangle:GetCache().Normal

	-- Get all edges that can be navigated to from this point and that have more than 1 triangle or similar navmesh entities connected to them.
	-- This will be used for pathfinding.
	obj.PathfindingNeighbors = {}
	for _, edge in ipairs(obj.Triangle.Edges) do
		if #edge.Triangles > 1 then
			local edgeCenter = (edge.Points[1] + edge.Points[2]) / 2
			local edgeVector = edge.Points[2] - edge.Points[1]
			local edgeOrthogonal = triangleNormal:Cross(edgeVector) -- Vector that is orthogonal to the edge and parallel to the triangle plane.
			local pathDirection = edgeCenter - pos -- Basically the walking direction.
			---@type D3botPATH_NEIGHBOR
			local neighbor = {
				From = obj,
				FromPos = pos,
				Via = obj.Triangle,
				To = edge,
				ToPos = edge:GetCentroid(),
				LocomotionType = obj.Triangle:GetLocomotionType(),
				PathDirection = pathDirection, -- Vector from start position to dest position.
				Distance = pathDirection:Length(), -- Distance from start to dest.
				OrthogonalOutside = (edgeOrthogonal * (edgeOrthogonal:Dot(pathDirection))):GetNormalized() -- Vector for path end condition that is orthogonal to the edge and parallel to the triangle plane, additionally it always points outside the triangle.
			}
			table.insert(obj.PathfindingNeighbors, neighbor)
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

---Returns a list of connected neighbor entities that a bot can navigate to.
---The result is a list of tables that contain the destination entity and some metadata.
---This is used for pathfinding.
---@return D3botPATH_NEIGHBOR[]
function PATH_POINT:GetPathfindingNeighbors()
	return self.PathfindingNeighbors
end

---Returns a single path fragment that can be injected into the "PathfindingNeighbors" list in the pathfinding routine.
---This is basically the path fragment from any edge ("from") of the destination triangle to the PATH_POINT itself.
---@param from table
---@param fromPos GVector
---@return D3botPATH_NEIGHBOR
function PATH_POINT:GetPathfindingNeighborForInjection(from, fromPos)
	local pathDirection = self.Pos - fromPos -- Basically the walking direction.
	---@type D3botPATH_NEIGHBOR
	local neighbor = {
		From = from,
		FromPos = fromPos,
		Via = self.Triangle,
		To = self,
		ToPos = self.Pos,
		LocomotionType = self.Triangle:GetLocomotionType(),
		PathDirection = pathDirection, -- Vector from start position to dest position.
		Distance = pathDirection:Length(), -- Distance from start to dest.
		OrthogonalOutside = pathDirection:GetNormalized() -- Vector for the end condition of this path element.
	}
	return neighbor
end

---Define metamethod for string conversion.
---@return string
function PATH_POINT:__tostring()
	return string.format("{Path point %s}", self.Pos)
end
