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
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Add new locomotion handler class.
LOCOMOTION_HANDLERS.WALKING = LOCOMOTION_HANDLERS.WALKING or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.WALKING

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

---Creates a new instance of a general locomotion handler for bots that can walk.
---Works best with locomotion types: "Ground".
---@param hullSize GVector @The bot's/player's standing hull box size as a vector.
---@param speed number @Speed for normal (unmodified) walking in engine units per second.
---@return table
function THIS_LOCO_HANDLER:New(hullSize, speed)
	local handler = setmetatable({
		HullSize = hullSize,
		Speed = speed,
	}, self)

	return handler
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the cache for the given pathElement (from pathElements at index), if needed this will regenerate the cache.
---The cache contains all values to easily control the bot through the pathElement.
---@param index integer @pathElements index.
---@param pathElements D3botPATH_ELEMENT[]
---@return table
function THIS_LOCO_HANDLER:GetPathElementCache(index, pathElements)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment
	local cache = pathElement.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	pathElement.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- Half hull width.
	local halfHullWidth = self.HullSize[1] / 2
	cache.HalfHullWidth = halfHullWidth

	-- General direction sum of the next few path elements.
	local futureDirectionSum = Vector(0, 0, 0)
	for i = index-1, index-5, -1 do
		local tempPathElement = pathElements[i]
		if not tempPathElement then break end
		futureDirectionSum = futureDirectionSum + tempPathElement.PathFragment.PathDirection
	end
	cache.FutureDirectionSum = futureDirectionSum

	-- End condition. (As a plane that the bot has to cross)
	cache.EndPlaneOrigin = pathFragment.ToPos
	cache.EndPlaneNormal = pathFragment.OrthogonalOutside

	-- Use offset information of the next element to move this elements end plane.
	local endPlaneOffset = 0
	local nextPathElement = pathElements[index-1] -- The previous index is the next path element.
	if nextPathElement then
		local locHandler = nextPathElement.LocomotionHandler
		if locHandler.BeginOffset then
			endPlaneOffset = locHandler:BeginOffset(index-1, pathElements)
		end
	end
	cache.EndPlaneOrigin = cache.EndPlaneOrigin + endPlaneOffset * cache.EndPlaneNormal

	-- Get the points from the start and dest NAV_EDGE (or PATH_POINT).
	-- The point arrays will either contain one or two points.
	local from, via, to = pathFragment.From, pathFragment.Via, pathFragment.To
	local fromPoints, toPoints = {from:GetPoints()}, {to:GetPoints()}
	local fromVertices, toVertices = {from:GetVertices()}, {to:GetVertices()}
	local viaNormal = via:GetCache().Normal
	local pathDirection = pathFragment.PathDirection

	-- A vector that points "to the right" direction as seen from the path direction.
	local pathRight = pathDirection:Cross(viaNormal):GetNormalized()

	-- Check wall state of the edge vertices and move the points so that they keep enough distance to the wall.
	local fromNormVector, toNormVector = ((fromPoints[2] or fromPoints[1]) - fromPoints[1]):GetNormalized(), ((toPoints[2] or toPoints[1]) - toPoints[1]):GetNormalized()
	if #fromVertices == 2 and fromVertices[1]:IsWalled() then
		fromPoints[1] = fromPoints[1] + fromNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(fromNormVector)), 1, fromPoints[1]:Length(fromPoints[2]))
	end
	if #fromVertices == 2 and fromVertices[2]:IsWalled() then
		fromPoints[2] = fromPoints[2] - fromNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(fromNormVector)), 1, fromPoints[1]:Length(fromPoints[2]))
	end
	if #toVertices == 2 and toVertices[1]:IsWalled() then
		toPoints[1] = toPoints[1] + toNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(toNormVector)), 1, toPoints[1]:Length(toPoints[2]))
	end
	if #toVertices == 2 and toVertices[2]:IsWalled() then
		toPoints[2] = toPoints[2] - toNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(toNormVector)), 1, toPoints[1]:Length(toPoints[2]))
	end

	-- Invert the (edge) points, if they point into the wrong direction.
	-- This basically makes sure that the edge vectors are pointing "to the right" as seen from the path direction.
	-- TODO: Put this stuff into the pathFragment, as it can be precalculated.
	if #fromPoints == 2 and pathRight:Dot(fromPoints[2]-fromPoints[1]) < 0 then
		fromPoints[2], fromPoints[1] = fromPoints[1], fromPoints[2]
	end
	if #toPoints == 2 and pathRight:Dot(toPoints[2]-toPoints[1]) < 0 then
		toPoints[2], toPoints[1] = toPoints[1], toPoints[2]
	end

	-- All points that are needed to calculate the right/left limitation planes.
	local fromLeft, fromRight, toLeft, toRight = fromPoints[1], fromPoints[2] or fromPoints[1], toPoints[1], toPoints[2] or toPoints[1]
	cache.fromLeft, cache.fromRight, cache.toLeft, cache.toRight = fromLeft, fromRight, toLeft, toRight

	-- Limitation plane on the right side that prevents the bot from dropping down cliffs or scrubbing along walls.
	-- It's pointing to the outside.
	cache.RightPlaneOrigin = toRight
	if (toRight - fromRight):IsZero() then
		cache.RightPlaneNormal = pathDirection:Cross(viaNormal):GetNormalized()
	else
		cache.RightPlaneNormal = (toRight - fromRight):Cross(viaNormal):GetNormalized()
	end

	-- Limitation plane on the left side that prevents the bot from dropping down cliffs or scrubbing along walls.
	-- It's pointing to the outside.
	cache.LeftPlaneOrigin = toLeft
	if (fromLeft - toLeft):IsZero() then
		cache.LeftPlaneNormal = -pathDirection:Cross(viaNormal):GetNormalized()
	else
		cache.LeftPlaneNormal = (fromLeft - toLeft):Cross(viaNormal):GetNormalized()
	end

	-- Limitation plane on the "from" entity (edge or point) that prevents the bot from going backwards in some edge cases.
	-- It's pointing to the outside.
	cache.BackPlaneOrigin = fromLeft
	if (fromRight - fromLeft):IsZero() then
		cache.BackPlaneNormal = -pathDirection:GetNormalized()
	else
		cache.BackPlaneNormal = (fromRight - fromLeft):Cross(viaNormal):GetNormalized()
	end

	return cache
end

---Takes over control of the bot to navigate through the given pathElement (pathElements at index).
---This must be run from a coroutine.
---@param bot GPlayer
---@param mem any
---@param index integer
---@param pathElements D3botPATH_ELEMENT[]
---@return D3botERROR | nil err
function THIS_LOCO_HANDLER:RunPathElementAction(bot, mem, index, pathElements)
	local cache = self:GetPathElementCache(index, pathElements)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment

	local botPos = bot:GetPos()

	-- Get straight direction to the next element.
	local straightDirection = (pathFragment.ToPos - botPos)

	-- Expected arrival time at the next element.
	local timeDiff = straightDirection:Length() / self.Speed
	local destTime = CurTime() + timeDiff
	local stuckTime = CurTime() + timeDiff * 2 + 0.5

	-- Get general movement direction. The "beeline" to the last of the next few elements.
	local direction = (straightDirection + cache.FutureDirectionSum):GetNormalized()

	-- Initialize smoothed direction vector.
	local smoothedDirection = bot:GetAimVector()

	-- Push the right buttons and stuff.
	local prevControlCallback = mem.ControlCallback
	mem.ControlCallback = function(bot, mem, cUserCmd)
		-- Prevent bot from passing the "backside" of the triangle in some edge cases.
		local botPos = bot:GetPos()
		if (botPos - cache.BackPlaneOrigin):Dot(cache.BackPlaneNormal) > 0 then
			if direction:Dot(cache.BackPlaneNormal) > 0 then
				direction = direction * 0.8 - cache.BackPlaneNormal * 0.2
				direction:Normalize()
			end
		end

		-- Adjust direction vector based on the left and right limiting planes.
		-- This checks if the bot is behind the limiting plane and if the direction of the bot is pointing outside the plane.
		local adjustedDirection = direction
		if (botPos - cache.LeftPlaneOrigin):Dot(cache.LeftPlaneNormal) > 0 then
			if direction:Dot(cache.LeftPlaneNormal) > 0 then
				-- Bot went too far to the left and is still going into the plane, set new default direction to be parallel to the plane.
				local alongPlaneDirection = cache.LeftPlaneNormal:Cross(Vector(0, 0, 1))
				direction = alongPlaneDirection
			end
			-- As long as he is behind the plane, let it move away from the plane.
			local awayFromPlaneDirection = -cache.LeftPlaneNormal
			adjustedDirection = direction * 0.6 + awayFromPlaneDirection * 0.4
		end
		if (botPos - cache.RightPlaneOrigin):Dot(cache.RightPlaneNormal) > 0 then
			if direction:Dot(cache.RightPlaneNormal) > 0 then
				-- Bot went too far to the right and is still going into the plane, set new default direction to be parallel to the plane.
				local alongPlaneDirection = cache.RightPlaneNormal:Cross(Vector(0, 0, -1))
				direction = alongPlaneDirection
			end
			-- As long as he is behind the plane, let it move away from the plane.
			local awayFromPlaneDirection = -cache.RightPlaneNormal
			adjustedDirection = direction * 0.6 + awayFromPlaneDirection * 0.4
		end

		-- Smooth out the movement
		smoothedDirection = smoothedDirection * 0.9 + adjustedDirection * 0.1

		-- Get next aim and right sided normal vector.
		local angle = smoothedDirection:Angle()
		local aim2D = Vector(smoothedDirection[1], smoothedDirection[2], 0):GetNormalized()
		local right2D = aim2D:Cross(Vector(0, 0, 1))

		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		--cUserCmd:SetButtons(bit.bor(IN_FORWARD))
		cUserCmd:SetForwardMove(self.Speed * aim2D:Dot(adjustedDirection))
		cUserCmd:SetSideMove(self.Speed * right2D:Dot(adjustedDirection))
		cUserCmd:SetViewAngles(angle)
		bot:SetEyeAngles(angle)
	end

	-- Wait until the bot crosses the end/destination plane.
	while (cache.EndPlaneOrigin - bot:GetPos()):Dot(cache.EndPlaneNormal) >= 0 do

		if stuckTime < CurTime() then
			-- If estimated arrival time got exceeded by much, move the end plane a bit closer.
			cache.EndPlaneOrigin = cache.EndPlaneOrigin - cache.HalfHullWidth * cache.EndPlaneNormal
		end

		-- TODO: Add "is stuck" timeout that stops this action after some time
		-- TODO: Add method to reset "is stuck" timeout (especially from inherited objects)

		coroutine.yield()
	end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback
end

---Overrides the base pathfinding cost (in engine units) for the given path fragment.
---If no method is defined, the distance of the path fragment will be used as metric.
---Any time based cost would need to be transformed into a distance based cost in here (Relative to normal walking speed).
---This is used in pathfinding and should be as fast as possible.
---@param pathFragment D3botPATH_FRAGMENT
---@return number cost
--function THIS_LOCO_HANDLER:CostOverride(pathFragment)
--	return (posB - posA):Length()
--end

---Returns whether the bot can move on the path fragment described by pathFragment.
---entityData is a map that contains pathfinding metadata (Parent entity, gScore, ...).
---Leaving this undefined has the same result as returning true.
---This is used in pathfinding and should be as fast as possible.
---@param pathFragment D3botPATH_FRAGMENT
---@param entityData table
---@return boolean
--function THIS_LOCO_HANDLER:CanNavigate(pathFragment, entityData)
--	return true
--end

---Draw the pathElement (from pathElements at index) into a 3D rendering context.
---@param index integer @pathElements index
---@param pathElements D3botPATH_ELEMENT[]
function THIS_LOCO_HANDLER:Render3D(index, pathElements)
	local cache = self:GetPathElementCache(index, pathElements)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment
	local fromPos, toPos = pathFragment.FromPos, pathFragment.ToPos

	-- Draw arrow as the main movement direction.
	cam.IgnoreZ(true)
	RENDER_UTIL.Draw2DArrowPos(fromPos, toPos, 50, Color(0, 0, 255, 128))

	-- Draw end condition planes.
	cam.IgnoreZ(false)
	render.DrawQuadEasy(cache.EndPlaneOrigin, -cache.EndPlaneNormal, 20, 20, Color(255, 0, 255, 128))

	-- Draw right limitation plane.
	--cam.IgnoreZ(false)
	--render.DrawQuadEasy(cache.RightPlaneOrigin, -cache.RightPlaneNormal, 20, 20, Color(255, 0, 0, 128))

	-- Draw left limitation plane.
	--cam.IgnoreZ(false)
	--render.DrawQuadEasy(cache.LeftPlaneOrigin, -cache.LeftPlaneNormal, 20, 20, Color(0, 255, 0, 128))

	-- Draw plane the the bot is able to walk on.
	cam.IgnoreZ(true)
	render.DrawQuad(cache.fromLeft, cache.toLeft, cache.toRight, cache.fromRight, Color(0, 0, 255, 63))
end
