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
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Predefine some local constants for optimization.
local VECTOR_UP = Vector(0, 0, 1)
local VECTOR_DOWN = Vector(0, 0, -1)

-- Add new locomotion handler class.
LOCOMOTION_HANDLERS.JUMP_AND_FALL = LOCOMOTION_HANDLERS.JUMP_AND_FALL or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.JUMP_AND_FALL

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

---Creates a new instance of a general locomotion handler for bots that handles controlled falling from edges/walls and jumping onto edges.
---Works best with locomotion types: "Wall", "AirVertical".
---@param hullSize GVector @The bot's/player's standing hull box size as a vector.
---@param maxJumpHeight number @Max. jump height that a bot can achieve by crouch jumping.
---@param maxFallHeight number @Max. height that the bot is allowed to fall down.
---@return table
function THIS_LOCO_HANDLER:New(hullSize, maxJumpHeight, maxFallHeight)
	local handler = setmetatable({
		HullSize = hullSize,
		MaxJumpHeight = maxJumpHeight,
		MaxFallHeight = maxFallHeight,
	}, self)

	return handler
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the cache for the given pathElement (from pathElements at index), if needed this will regenerate the cache.
---The cache contains all values to easily control the bot through the pathElement.
---@param index integer @pathElements index
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

	-- End condition as a plane.
	-- This will try to create a plane with a horizontal normal. This may fail if the path direction is vertical.
	local nextPathElement = pathElements[index-1]
	if nextPathElement then
		-- If there is a next element, use the direction of it to determine the end plane.

		local nextPathFragment = nextPathElement.PathFragment
		local nextDirection = nextPathFragment.PathDirection

		-- Get points of the dest edge on the current cell/triangle (it may also be a point or something similar).
		local eP1, eP2 = pathFragment.To:GetPoints()

		-- If there is only one point, position the second point in some way so that it is orthogonal to the moving direction.
		if not eP2 then
			eP2 = eP1 + nextDirection:Cross(VECTOR_UP)
		end

		-- Determine a normal that is always horizontal and orthogonal to the edge.
		local normalEdgeOrtho = (eP2 - eP1):Cross(VECTOR_UP)
		cache.EndPlaneOrigin = pathFragment.ToPos
		cache.EndPlaneNormal = (normalEdgeOrtho * (normalEdgeOrtho:Dot(nextDirection))):GetNormalized()

		-- Move end plane based on next element.
		if nextPathElement then
			local locHandler = nextPathElement.LocomotionHandler
			if locHandler.BeginOffset then
				local beginOffset = locHandler:BeginOffset(index-1, pathElements, cache.EndPlaneNormal)
				cache.EndPlaneOrigin = cache.EndPlaneOrigin + beginOffset * cache.EndPlaneNormal
			end
		end
	end

	-- If the previous calculation failed, just use the orthogonal that comes with the path fragment.
	if not cache.EndPlaneNormal or cache.EndPlaneNormal:IsZero() then
		cache.EndPlaneOrigin = pathFragment.ToPos
		cache.EndPlaneNormal = pathFragment.ToOrthogonal
	end

	-- If the next path element has a different locomotion type, move the end plane a bit back.
	local endPlaneOffset = 0
	if nextPathElement then
		local nextPathFragment = nextPathElement.PathFragment
		local locType = nextPathFragment.LocomotionType
		if locType ~= pathFragment.LocomotionType then
			if pathFragment.PathDirection[3] < 0 then
				endPlaneOffset = halfHullWidth
			end
		end
	end
	cache.EndPlaneOrigin = cache.EndPlaneOrigin + endPlaneOffset * cache.EndPlaneNormal

	-- Get aim position, as we can't use edges or directions directly.
	--cache.AimPosition = cache.EndPlaneOrigin + 0.5 * endPlaneOffset * cache.EndPlaneNormal

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

	-- General direction to the next triangle/cell.
	local direction = pathFragment.PathDirection

	-- Plane used to align the bot to face the end plane from the front.
	local leftRightSplitPlaneOrigin = cache.EndPlaneOrigin
	local leftRightSplitPlaneNormal = cache.EndPlaneNormal:Cross(VECTOR_UP)

	-- Prevent the bot from pressing jump all the time.
	local jumpTimeout = 0

	local prevControlCallback = mem.ControlCallback
	---Push the right buttons and stuff.
	---@param bot GPlayer
	---@param mem any
	---@param cUserCmd table
	mem.ControlCallback = function(bot, mem, cUserCmd)
		local botPos = bot:GetPos()

		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()

		if direction[3] > 0 then
			-- Let the bot crouch jump if the path is going upwards.
			if bot:IsOnGround() then
				if jumpTimeout <= 0 then
					jumpTimeout = 30
					cUserCmd:SetButtons(bit.bor(IN_JUMP, IN_FORWARD))
				else
					jumpTimeout = jumpTimeout - 1
				end
			else
				-- When the bot is in the air, let it crouch.
				cUserCmd:SetButtons(bit.bor(IN_DUCK, IN_FORWARD))
			end
		else
			-- Otherwise the bot will just fall down, there is not much to do.
			cUserCmd:SetForwardMove(150)
		end

		-- Rotate bot so that it aligns with the end plane, which is usually parallel to the destination (edge).
		-- We can't use PathDirection, as it can be vertical.
		local rotDirection = cache.EndPlaneNormal
		cUserCmd:SetViewAngles(rotDirection:Angle())
		bot:SetEyeAngles(rotDirection:Angle())

		-- Try to position the bot so that it faces the end plane.
		local forwardMove = (cache.EndPlaneOrigin - botPos):Dot(cache.EndPlaneNormal) * 100
		local sideMove = (leftRightSplitPlaneOrigin - botPos):Dot(leftRightSplitPlaneNormal) * 100
		cUserCmd:SetForwardMove(forwardMove)
		cUserCmd:SetSideMove(sideMove)
	end

	-- TODO: Only continue if bot is on ground again.

	-- Wait until the bot crosses the end/destination plane.
	while (cache.EndPlaneOrigin - bot:GetPos()):Dot(cache.EndPlaneNormal) >= 0 do
		-- Check if the path element is still valid. If the path got updated, stop this action.
		if pathElement.IsInvalid then mem.ControlCallback = prevControlCallback return nil end

		coroutine.yield()
	end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback
	return nil
end

---Returns an offset that a previous element can use to offset its end plane.
---@param index integer
---@param pathElements D3botPATH_ELEMENT[]
---@param prevEndPlaneNormal GVector @Normal of the previous element's end plane.
---@return number
function THIS_LOCO_HANDLER:BeginOffset(index, pathElements, prevEndPlaneNormal)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment

	local prevEndPlaneNormal2D = Vector(prevEndPlaneNormal[1], prevEndPlaneNormal[2], 0):GetNormalized()

	-- Half hull width.
	local halfHullWidth = self.HullSize[1] / 2

	if pathFragment.PathDirection[3] > 0 then
		-- This will be a jump, so the previous path element should end a bit earlier.
		return -UTIL.PlaneXYSquareTouchDistance(prevEndPlaneNormal2D, halfHullWidth) - 32
	else
		-- The bot will fall down a cliff or similar, make the previous path element end later.
		return UTIL.PlaneXYSquareTouchDistance(prevEndPlaneNormal2D, halfHullWidth)
	end
end

---Overrides the base pathfinding cost (in engine units) for the given path fragment.
---If no method is defined, the distance of the path fragment will be used as metric.
---Any time based cost would need to be transformed into a distance based cost in here (Relative to normal walking speed).
---This is used in pathfinding and should be as fast as possible.
---@param pathFragment D3botPATH_FRAGMENT
---@return number cost
function THIS_LOCO_HANDLER:CostOverride(pathFragment)
	-- Assume constant but low cost for falling or jumping, which is somewhat realistic.
	return 100
end

---Returns whether the bot can move on the path fragment described by pathFragment.
---entityData is a map that contains pathfinding metadata (Parent entity, gScore, ...).
---Leaving this undefined has the same result as returning true.
---This is used in pathfinding and should be as fast as possible.
---@param pathFragment D3botPATH_FRAGMENT
---@param entityData table
---@return boolean
function THIS_LOCO_HANDLER:CanNavigate(pathFragment, entityData)
	-- Start navmesh entity of the path fragment.
	local entityA = pathFragment.From

	-- TODO: Get max diff for non parallel edges
	local posA, posB = pathFragment.FromPos, pathFragment.ToPos
	local zDiff = posB[3] - posA[3]
	local sideLengthSqr = (posB - posA):Length2DSqr()

	-- Check if the nodes are somewhat aligned vertically.
	if sideLengthSqr > zDiff * zDiff then
		return false
	end

	-- Get zDiff of the previous element, or nil.
	-- A positive zDiff means that the current part is just a fraction of the total jump path.
	-- A negative zDiff means that the current part is just a fraction of the total fall path.
	-- nil means that this is the only or initial jump/fall path.
	local previousEntity = entityData[entityA].From
	local previousZDiff = previousEntity and entityData[previousEntity].ZDiff or nil

	-- A bot can either jump and then fall, or just fall.
	if previousZDiff and UTIL.PositiveNumber(zDiff) ~= UTIL.PositiveNumber(previousZDiff) and UTIL.PositiveNumber(previousZDiff) == false then return false end

	-- Check if bot is in the possible and or safe zone.
	local totalZDiff = zDiff + (previousZDiff or 0)
	if totalZDiff > -self.MaxFallHeight and totalZDiff < self.MaxJumpHeight then
		-- Store total vertical diff for the next node that may use it.
		entityData[entityA].ZDiff = totalZDiff
		return true
	end

	-- Bot can neither jump up that edge, nor can it safely fall down.
	return false
end

---Draw the pathElement (from pathElements at index) into a 3D rendering context.
---@param index integer @pathElements index.
---@param pathElements D3botPATH_ELEMENT[]
function THIS_LOCO_HANDLER:Render3D(index, pathElements)
	local cache = self:GetPathElementCache(index, pathElements)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment
	local fromPos, toPos = pathFragment.FromPos, pathFragment.ToPos
	cam.IgnoreZ(true)
	render.DrawBeam(fromPos, toPos, 5, 0, 1, Color(0, 255, 0, 255))

	-- Draw end condition planes.
	cam.IgnoreZ(false)
	render.DrawQuadEasy(cache.EndPlaneOrigin, -cache.EndPlaneNormal, 20, 20, Color(255, 0, 255, 128))
end
