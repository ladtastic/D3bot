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
local PATH_POINT = D3bot.PATH_POINT

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
PATH_POINT.__index = PATH_POINT

-- Get new instance of a path point object.
-- This is not a point of a path, but a helper point for the start and destination positions of paths.
-- It will implement methods similar to navmesh entities so that it can be used in the pathfinder.
function PATH_POINT:New(navmesh, pos)
	local obj = {
		Navmesh = navmesh,
		Pos = pos
	}

	-- Check if there is even a position
	if not pos then
		return nil, ERROR:New("Invalid position given")
	end

	-- Get triangle that the point is on
	obj.Triangle = UTIL.GetClosestToPos(pos, navmesh.Triangles)
	if not obj.Triangle then
		return nil, ERROR:New("Can't find closest triangle for point %s", pos)
	end

	-- Get all edges that can be navigated to from this point and that have more than 1 triangle or similar navmesh entities connected to them.
	-- This will be used for pathfinding.
	obj.PathfindingNeighbors = {}
	for _, edge in ipairs(obj.Triangle.Edges) do
		if #edge.Triangles > 1 then
			local edgeCenter = (edge.Points[1] + edge.Points[2]) / 2
			table.insert(obj.PathfindingNeighbors, {Entity = edge, Via = obj.Triangle, Distance = (edgeCenter - pos):Length()})
		end
	end

	-- Instantiate
	setmetatable(obj, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Returns the average of all points that are contained in this geometry, or nil.
function PATH_POINT:GetCentroid()
	return self.Pos
end

-- Returns a list of connected neighbor entities that a bot can navigate to.
-- The result is a list of tables that contain the destination entity and some metadata.
-- This is used for pathfinding.
function PATH_POINT:GetPathfindingNeighbors()
	return self.PathfindingNeighbors
end