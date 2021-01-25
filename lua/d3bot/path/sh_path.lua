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
local PATH_POINT = D3bot.PATH_POINT
local PRIORITY_QUEUE = D3bot.PRIORITY_QUEUE

------------------------------------------------------
--		"Structures"
------------------------------------------------------

---@class D3botPATH_FRAGMENT @Basically a precalculated path fragment that is cached in navmesh objects. This enables the pathfinder to iterate over navmesh objects, and build paths. A list of these is returned by GetPathFragments methods.
---@field From table @Edge or similar navmesh object.
---@field FromPos GVector @Centroid of From.
---@field Via table @Triangle or similar navmesh object.
---@field To table @Edge or similar navmesh object.
---@field ToPos GVector @Centroid of To.
---@field LocomotionType string @Locomotion type.
---@field PathDirection GVector @Vector from start position to dest position.
---@field Distance number @Distance from start to dest.
---@field OrthogonalOutside GVector @Vector for the end condition of this path element. It is used to build a plane that the bot has to pass in order to get to the next path element.

---@class D3botPATH_ELEMENT @An atomic part of a path. It is used by locomotion handlers to control bots.
---@field PathFragment D3botPATH_FRAGMENT @Precalculated values of a path, don't modify.
---@field LocomotionHandler table
---@field Cache table | nil

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botPATH
---@field Navmesh D3botNAV_MESH
---@field Abilities table<string, table> @Maps navmesh locomotion types (keys) to locomotion handlers (values).
---@field Path D3botPATH_ELEMENT[] @Queue of path elements in reverse order (current element is last in the list).
local PATH = D3bot.PATH
PATH.__index = PATH

---Get new instance of a path object.
---abilities is a table that maps navmesh locomotion types (keys) to locomotion handlers (values).
---This contains a path as a series of points with some metadata (E.g. what navmesh triangle this points to, the navmesh connection entity it uses (NAV_EDGE, ...)).
---@param navmesh D3botNAV_MESH
---@param abilities table<string, table>
---@return D3botPATH | nil
---@return D3botERROR | nil err
function PATH:New(navmesh, abilities)
	local obj = setmetatable({
		Navmesh = navmesh,
		Abilities = abilities,
		Path = {},
	}, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Generates a path from startPoint to destPoint PATH_POINT objects.
---The actual pathfinding is mostly based on edges, not triangles.
---@param startPoint D3botPATH_POINT
---@param destPoint D3botPATH_POINT
---@return D3botERROR | nil err
function PATH:GeneratePathBetweenPoints(startPoint, destPoint)
	-- See: https://en.wikipedia.org/wiki/A*_search_algorithm

	-- Reset current path.
	self.Path = {}

	-- Define some variables for optimization.
	local navmesh = self.Navmesh
	local abilities = self.Abilities
	local startPos, destPos = startPoint:GetCentroid(), destPoint:GetCentroid()

	-- Data structures for pathfinding.
	local entityData = {} -- Contains scores and other information about visited navmesh entities.
	local closedList = {} -- List of entities that have been expanded.
	local openList = PRIORITY_QUEUE:New() -- List of entities that have to be expanded.

	---Function to build a path from the generated data.
	---@param entity any
	---@return D3botERROR | nil
	local function reconstructPath(entity)
		--local iterCounter = 0

		-- Iterate from the found destination to the start entity and push path to pathElements.
		while entity do
			-- Debug end condition.
			--if iterCounter > 10000 then return ERROR:New("Exceeded maximum number of path reconstruction iterations") end
			--iterCounter = iterCounter + 1

			local entityInfo = entityData[entity]
			if not entityInfo.From then break end
			local pathFragment = entityInfo.PathFragment

			---@type D3botPATH_ELEMENT
			local pathElement = {
				PathFragment = pathFragment,
				LocomotionHandler = abilities[pathFragment.LocomotionType],
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

	---Helper function for adding navmesh entities to the open list.
	---@param pathFragment D3botPATH_FRAGMENT
	---@param tentative_gScore number
	local function enqueueEntity(pathFragment, tentative_gScore)
		local fScore = tentative_gScore + heuristic(pathFragment.ToPos) -- Best guess as to how cheap a path can be that goes through this entity.
		entityData[pathFragment.To] = {
			GScore = tentative_gScore, -- The cheapest path from start to this entity.
			From = pathFragment.From, -- The previous entity for path reconstruction.
			PathFragment = pathFragment, -- Reference to the path fragment from the navmesh entity for later use. Do not modify the content!
		}
		openList:Enqueue(pathFragment.To, fScore)
	end

	-- Add start point to open list.
	enqueueEntity({To = startPoint, ToPos = startPos, Via = startPoint.Triangle}, 0)

	-- As search is edge based, store edges where the destPoint has to be injected to the "neighbors" list.
	local destTriangle = destPoint.Triangle
	local endE1, endE2, endE3 = destTriangle.Edges[1], destTriangle.Edges[2], destTriangle.Edges[3]

	--local iterCounter = 0

	-- Get next entity from queue and expand it.
	for entity in openList.Dequeue, openList do
		-- Debug end condition.
		--if iterCounter > 10000 then return ERROR:New("Exceeded maximum number of pathfinding iterations") end
		--iterCounter = iterCounter + 1

		-- Add to closed list.
		closedList[entity] = true

		-- End condition: Found destPoint.
		if entity == destPoint then
			return reconstructPath(entity)
		end

		-- Store some variables of this entity for later use.
		local entityInfo = entityData[entity]
		local gScore = entityInfo.GScore
		local entityPos = entity:GetCentroid()

		---Get list of possible paths to take.
		local pathFragments = entity:GetPathFragments()

		-- If we are at the edge of our destination triangle, inject the pathFragment to the destPoint into the list of possible paths.
		if entity == endE1 or entity == endE2 or entity == endE3 then
			local pathFragment = destPoint:GetPathFragmentsForInjection(entity, entityPos)
			pathFragments = table.Add({pathFragment}, pathFragments)
		end

		---Iterate over possible paths: Neighbor entities that are somehow connected to the current entity.
		---@type D3botPATH_FRAGMENT
		for _, pathFragment in ipairs(pathFragments) do
			local neighborEntity = pathFragment.To

			-- Check if neighbor is in the closed list, if so it's already optimal.
			-- This check must be removed if the heuristic is changed to an "admissible heuristic".
			if not closedList[neighborEntity] then

				-- Get locomotion handler.
				local locomotionHandler = abilities[pathFragment.LocomotionType]

				-- Check if there is a locomotion handler ("Does the bot know how to navigate on this navmesh entity?").
				if locomotionHandler then

					-- And check if the bot is able to walk to the next entity.
					if not locomotionHandler.CanNavigate or locomotionHandler:CanNavigate(pathFragment, entityData) then

						-- Calculate gScore for the neighbor entity.
						local tentative_gScore
						if locomotionHandler.CostOverride then
							tentative_gScore = gScore + locomotionHandler:CostOverride(pathFragment)
						else
							tentative_gScore = gScore + pathFragment.Distance
						end

						-- Check if the gScore is better than the previous score.
						local neighborEntityInfo = entityData[neighborEntity]
						if tentative_gScore < (neighborEntityInfo and neighborEntityInfo.GScore or math.huge) then

							-- Enqueue neighbor entity.
							enqueueEntity(pathFragment, tentative_gScore)

						end
					end
				end
			end
		end
	end

	-- No path found.
	return ERROR:New("Couldn't find a path from %s to %s", startPoint, destPoint)
end

---Generates a path to the given vector destPos or updates an already existing path.
---This tries to recalculate as few things as possible.
---@param startPos GVector
---@param destPos GVector
---@return D3botERROR | nil err
function PATH:UpdatePathToPos(startPos, destPos)
	local navmesh = self.Navmesh

	-- TODO: Check if destPos is still on the same navmesh entity (shortest distance to {current triangle, neighbors...})
	-- TODO: Regenerate path if destPos moved to different navmesh

	-- It should be decided in an intelligent way how and when to regenerate the path.
	-- Ideally it only has to do a full path regeneration when the destPos moves too much, otherwise it only has to update the last path element.
	-- Also, if the current path is long enough, there is no need to regenerate the path every time the destPos moves from one triangle to another.
	-- In this case it could do a search from the old "end" position of the path to the new destPos.

	-- Regenerate path.
	local startPoint, err = PATH_POINT:New(navmesh, startPos)
	if err then return err end
	local destPoint, err = PATH_POINT:New(navmesh, destPos)
	if err then return err end

	return self:GeneratePathBetweenPoints(startPoint, destPoint)
end

---Draw the path into a 3D rendering context.
function PATH:Render3D()
	render.SetColorMaterialIgnoreZ()
	cam.IgnoreZ(true)

	---@type D3botPATH_ELEMENT
	for i, pathElement in pairs(self.Path) do
		local locomotionHandler = pathElement.LocomotionHandler
		-- Let the locomotion handler render the path element.
		locomotionHandler:Render3D(i, self.Path)
	end

	cam.IgnoreZ(false)
end
