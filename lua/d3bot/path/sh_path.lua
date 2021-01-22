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
local PATH = D3bot.PATH
local PATH_POINT = D3bot.PATH_POINT
local PRIORITY_QUEUE = D3bot.PRIORITY_QUEUE

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
PATH.__index = PATH

-- Get new instance of a path object.
-- abilities is a table that maps navmesh locomotion types (keys) to locomotion handlers (values)
-- This contains a path as a series of points with some metadata (E.g. what navmesh triangle this points to, the navmesh connection entity it uses (NAV_EDGE, ...)).
function PATH:New(navmesh, abilities)
	local obj = {
		Navmesh = navmesh,
		Abilities = abilities, -- Maps navmesh locomotion types (keys) to locomotion handlers (values)
		Path = {} -- Queue of path elements in reverse order (current element is last in the list)
	}

	-- Instantiate
	setmetatable(obj, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Generates a path from startPoint to destPoint PATH_POINT objects.
-- The actual pathfinding is mostly based on edges, not triangles.
function PATH:GeneratePathBetweenPoints(startPoint, destPoint)
	-- See: https://en.wikipedia.org/wiki/A*_search_algorithm

	-- Reset current path
	self.Path = {}

	-- Define some variables for optimization
	local navmesh = self.Navmesh
	local abilities = self.Abilities
	local startPos, destPos = startPoint:GetCentroid(), destPoint:GetCentroid()

	-- Data structures for pathfinding
	local entityData = {} -- Contains scores and other information about visited navmesh entities
	local closedList = {} -- List of entities that have been expanded
	local openList = PRIORITY_QUEUE:New() -- List of entities that have to be expanded

	-- Function to build a path from the generated data
	local function reconstructPath(entity)
		-- Iterate from the found destination to the start entity and push path to pathElements
		local entity = entity
		while entity do
			local entityInfo = entityData[entity]

			local pathElement = {
				Pos = entity:GetCentroid(),
				Via = entityInfo.Via,
				LocomotionHandler = abilities[entityInfo.Via:GetLocomotionType()]
			}
			table.insert(self.Path, pathElement)

			entity = entityInfo.From
		end

		return nil
	end

	-- Returns the heuristic for a given vector pos.
	-- Should be consistent (monotone), otherwise some code has to be changed.
	local function heuristic(pos)
		return (destPos-pos):Length()
	end

	-- Helper function for adding navmesh entities to the open list
	local function enqueueEntity(entity, tentative_gScore, from, via, toPos)
		local fScore = tentative_gScore + heuristic(toPos) -- Best guess as to how cheap a path can be that goes through this entity
		entityData[entity] = {
			GScore = tentative_gScore, -- The cheapest path from start to this entity
			From = from, -- The previous entity
			Via = via -- The navmesh entity that connects the previous and current entity
		}
		openList:Enqueue(entity, fScore)
	end

	-- Add start point to open list
	enqueueEntity(startPoint, 0, nil, startPoint.Triangle, startPos)
	
	-- As search is edge based, store edges where the destPoint has to be injected to the "neighbors" list
	local destTriangle = destPoint.Triangle
	local endE1, endE2, endE3 = destTriangle.Edges[1], destTriangle.Edges[2], destTriangle.Edges[3]

	-- Get next entity from queue and expand it
	for entity in openList.Dequeue, openList do
		-- Add to closed list
		closedList[entity] = true

		-- End condition: Found destPoint.
		if entity == destPoint then
			return reconstructPath(entity)
		end

		-- Store some variables of this entity for later use
		local entityInfo = entityData[entity]
		local gScore = entityInfo.GScore
		local entityPos = entity:GetCentroid()

		-- Get list of neighbor navmesh entities
		local neighbors = entity:GetPathfindingNeighbors()

		-- If we are at the edge of our destination triangle, inject destPoint into neighbor list
		if entity == endE1 or entity == endE2 or entity == endE3 then
			neighbors = table.Add({{Entity = destPoint, Via = destPoint.Triangle, Distance = (destPos - entityPos):Length()}}, neighbors)
		end

		-- Iterate over neighbor entities
		for _, neighbor in ipairs(neighbors) do
			local neighborEntity, via, distance = neighbor.Entity, neighbor.Via, neighbor.Distance

			-- Check if neighbor is in the closed list, if so it's already optimal.
			-- This check must be removed if the heuristic is changed to an "admissible heuristic".
			if not closedList[neighborEntity] then

				-- Get locomotion type and handler.
				-- Via may be a triangle or some other similar navmesh entity.
				local locomotionHandler = abilities[via:GetLocomotionType()]

				-- Check if there is a locomotion handler ("Does the bot know how to navigate on this navmesh entity?")
				if locomotionHandler then
					local neighborEntityPos = neighborEntity:GetCentroid()

					-- And check if the bot is able to walk to the next entity
					if not locomotionHandler.CanNavigate or locomotionHandler:CanNavigate(entity, via, neighborEntity, entityData) then

						-- Calculate gScore for the neighbor entity
						local tentative_gScore
						if locomotionHandler.CostOverride then
							tentative_gScore = gScore + locomotionHandler:CostOverride(entityPos, neighborEntityPos)
						else
							tentative_gScore = gScore + distance
						end

						-- Check if the gScore is better than the previous score
						local neighborEntityInfo = entityData[neighborEntity]
						if tentative_gScore < (neighborEntityInfo and neighborEntityInfo.GScore or math.huge) then

							-- Enqueue neighbor entity
							enqueueEntity(neighborEntity, tentative_gScore, entity, via, neighborEntityPos)

						end
					end
				end
			end
		end
	end

	-- No path found
	return ERROR:New("Couldn't find a path from %s to %s", startPoint, destPoint)
end

-- Generates a path to the given vector destPos or updates an already existing path.
-- This tries to recalculate as few things as possible.
function PATH:UpdatePathToPos(startPos, destPos)
	local navmesh = self.Navmesh

	-- TODO: Check if destPos is still on the same navmesh entity (shortest distance to {current triangle, neighbors...})
	-- TODO: Regenerate path if destPos moved to different navmesh

	-- It should be decided in an intelligent way how and when to regenerate the path.
	-- Ideally it only has to do a full path regeneration when the destPos moves too much, otherwise it only has to update the last path element.
	-- Also, if the current path is long enough, there is no need to regenerate the path every time the destPos moves from one triangle to another.
	-- In this case it could do a search from the old "end" position of the path to the new destPos.

	-- Regenerate path
	local startPoint, err = PATH_POINT:New(navmesh, startPos)
	if err then return err end
	local destPoint, err = PATH_POINT:New(navmesh, destPos)
	if err then return err end

	self:GeneratePathBetweenPoints(startPoint, destPoint)
end

-- Draw the path into a 3D rendering context.
function PATH:Render3D()
	render.SetColorMaterialIgnoreZ()
	cam.IgnoreZ(true)

	local oldPos
	for _, pathElement in pairs(self.Path) do
		local pos = pathElement.Pos

		if pos and oldPos then
			render.DrawBeam(pos, oldPos, 5, 0, 1, Color(0, 0, 255, 255))
		end

		oldPos = pos
	end

	cam.IgnoreZ(false)
end
