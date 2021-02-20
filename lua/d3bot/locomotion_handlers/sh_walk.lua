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
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Predefine some local constants for optimization.
local VECTOR_UP = Vector(0, 0, 1)
local VECTOR_DOWN = Vector(0, 0, -1)

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
	cache.HalfHullSafetyWidth = halfHullWidth + 5

	-- Future (or current) path element that the bot uses as target.
	-- TODO: Directly calculate index based on list length
	local futurePathElement
	for i = index, index-5, -1 do
		local tempPathElement = pathElements[i]
		if tempPathElement then
			futurePathElement = tempPathElement
		else
			break
		end
	end
	cache.FuturePathElement = futurePathElement

	-- Next path element is the previous one in the list.
	-- This can be nil.
	cache.NextPathElement = pathElements[index-1]

	-- List of planes that the bot avoids to cross. (Walls, cliffs, ...)
	local limitingPlanes = {}
	for _, plane in ipairs(pathFragment.LimitingPlanes) do
		local origin, normal = plane.Origin, plane.Normal2D
		if plane.IsWalled then
			-- Keep distance from any wall. Calculate distance to squared base of the bot's hull.
			origin = origin - normal * UTIL.PlaneXYSquareTouchDistance(normal, cache.HalfHullSafetyWidth)
		end
		table.insert(limitingPlanes, {Origin = origin, Normal = normal})
	end
	cache.LimitingPlanes = limitingPlanes

	-- End condition.
	if pathFragment.EndPlane then
		-- Plane that the bot has to cross.
		cache.EndPlane = {}
		cache.EndPlane.Origin = pathFragment.EndPlane.Origin
		cache.EndPlane.Normal = pathFragment.EndPlane.Normal2D

		-- Use offset information of the next element to move the element's end plane.
		local endPlaneOffset = 0
		local nextPathElement = pathElements[index-1] -- The previous index is the next path element.
		if nextPathElement then
			local locHandler = nextPathElement.LocomotionHandler
			if locHandler.BeginOffset then
				endPlaneOffset = locHandler:BeginOffset(index-1, pathElements, cache.EndPlane.Normal)
				-- TODO: Handle positive offsets in a different way, as real time string pulling doesn't work correctly with bot positions behind the end plane
				cache.EndPlane.Origin = cache.EndPlane.Origin + endPlaneOffset * cache.EndPlane.Normal
			end
		end
	else
		-- 2D position that the bot has to get close to. This is calculated in the control callback.
	end

	-- A vector that points to the "right" direction as seen from the path direction.
	local pathRight = pathFragment.PathDirection:Cross(pathFragment.Via:GetNormal()):GetNormalized()

	-- Vertices of the destination element "To".
	local v1, v2 = pathFragment.To:GetVertices()
	local p1, p2 = pathFragment.To:GetPoints()
	-- Check if "To" is an edge or similar entity.
	if v1 and v2 then
		-- Flip direction of the two vertices, so that v1 is the "left" and v2 is the "right" one.
		if (p2 - p1):Dot(pathRight) < 0 then
			v1, v2, p1, p2 = v2, v1, p2, p1
		end

		cache.DestVertexLeft, cache.DestVertexRight = v1, v2
		cache.DestPosLeft, cache.DestPosRight = p1, p2
	else
		-- There is only a single vertex as destination. Calculate in real time, as destination is most likely a PATH_POINT object.
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

	-- Estimated arrival time at the next element.
	local timeDiff = pathFragment.Distance / self.Speed
	local destTime = CurTime() + timeDiff
	local stuckTime = CurTime() + timeDiff * 2 + 0.5

	-- Initialize smoothed direction vector.
	local lookingDirection = bot:GetAimVector()

	local prevControlCallback = mem.ControlCallback
	---Push the right buttons and stuff.
	---@param bot GPlayer
	---@param mem any
	---@param cUserCmd table
	mem.ControlCallback = function(bot, mem, cUserCmd)

		local botPos = bot:GetPos()
		local botPos2D = Vector(botPos)
		botPos2D[3] = 0

		local movementDirection
		if cache.DestVertexLeft and cache.DestVertexRight then
			-- Destination consists of two vertices (Like an edge). Walk between/through them.

			-- Get destination position that lies on some future path element.
			-- The destination can't be cached, as it may be updated while the bot is walking.
			local toPos = cache.FuturePathElement.PathFragment.ToPos
			local direction = toPos - botPos2D
			direction[3] = 0

			-- Clamp direction to the next path element's "To" entity.
			-- This step can be disabled, but results in a bit wonkier movement in some edge cases.
			if cache.NextPathElement and cache.NextPathElement._ClampBetweenVertices then
				local nextCache = cache.NextPathElement:GetPathElementCache(index-1, pathElements)
				direction = self:_ClampBetweenVertices(botPos2D, direction, nextCache.DestVertexLeft, nextCache.DestVertexRight, nextCache.HalfHullSafetyWidth)
			end

			-- Clamp direction to the current path element's "To" entity.
			movementDirection = self:_ClampBetweenVertices(botPos2D, direction, cache.DestVertexLeft, cache.DestVertexRight, cache.HalfHullSafetyWidth)
		else
			-- A single destination position. Go straight towards it.
			movementDirection = pathFragment.ToPos - botPos
			movementDirection[3] = 0
		end
		movementDirection:Normalize()

		-- Check limiting planes that prevent the bot from leaving the valid walking area.
		local movementCorrection = Vector()
		for _, limitingPlane in ipairs(cache.LimitingPlanes) do
			if (botPos - limitingPlane.Origin):Dot(limitingPlane.Normal) > 0 then
				-- Bot has crossed one of the limiting planes. Adjust its direction so that it moves back inside.

				-- Determine if the movement direction is parallel (in any direction) to the correction direction.
				-- It's in the range of [0;1], as both vectors are normalized.
				local parallelism = math.abs(movementDirection:Dot(limitingPlane.Normal))

				-- Correct most if the bot is moving parallel to the plane.
				-- Correct least if the bot is moving towards the plane or away from it.
				movementCorrection:Sub(limitingPlane.Normal * (1 - parallelism))
			end
		end
		if not movementDirection:IsZero() then
			movementDirection:Add(movementCorrection)
			movementDirection:Normalize()
		end

		-- Smooth out the movement and make it 2D.
		lookingDirection = bot:GetAimVector() * 0.9 + movementDirection * 0.1
		lookingDirection[3] = 0

		-- Get future aim and right sided vector.
		-- TODO: Use some different direction as view angle.
		local angle = lookingDirection:Angle()
		local aim2D = lookingDirection
		local right2D = aim2D:Cross(VECTOR_UP)

		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		--cUserCmd:SetButtons(bit.bor(IN_FORWARD))
		cUserCmd:SetForwardMove(self.Speed * aim2D:Dot(movementDirection))
		cUserCmd:SetSideMove(self.Speed * right2D:Dot(movementDirection))
		cUserCmd:SetViewAngles(angle)
		bot:SetEyeAngles(angle)
	end

	while true do
		-- End condition for this path element.
		if cache.EndPlane then
			if (cache.EndPlane.Origin - bot:GetPos()):Dot(cache.EndPlane.Normal) < 0 then
				-- Bot crossed the end plane.
				break
			end
		else
			-- 2D distance to end position of this path element. Can't cache ToPos, as it may change while the bot is moving.
			local pos, toPos = Vector(bot:GetPos()), Vector(pathFragment.ToPos)
			pos[3], toPos[3] = 0, 0
			if pos:DistToSqr(toPos) < 20*20 then
				-- Bot is close enough to the end.
				break
			end
		end

		-- Check if the path element is still valid. If the path got updated, stop this action.
		if pathElement.IsInvalid then mem.ControlCallback = prevControlCallback return nil end

		-- TODO: Add "is stuck" timeout that stops this action after some time
		-- TODO: Add method to reset "is stuck" timeout (especially from inherited objects)

		coroutine.yield()
	end

	-- If this is the last element, give it some more time.
	if index == 1 then coroutine.wait(0.2) end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback
	return nil
end

---Helper function for real time string pulling.
---This takes the current position and direction, and outputs a corrected direction that goes through between v1 and v2.
---Additionally this will help the bot to "corner" corners by making bots walk around vertices of walled edges.
---@param pos2D GVector
---@param direction2D GVector
---@param leftVertex D3botNAV_VERTEX
---@param rightVertex D3botNAV_VERTEX
---@return GVector clampedDirection2D
function THIS_LOCO_HANDLER:_ClampBetweenVertices(pos2D, direction2D, leftVertex, rightVertex, walledOffset)
	-- Flattened/Projected positions of the vertices.
	local leftPos, rightPos = leftVertex:GetPoint(), rightVertex:GetPoint()
	leftPos, rightPos = Vector(leftPos[1], leftPos[2], 0), Vector(rightPos[1], rightPos[2], 0)

	-- Distance from bot position to a vertex.
	local leftLen, rightLen = leftPos:Distance(pos2D), rightPos:Distance(pos2D)

	-- Determine left and right plane normals by calculating tangents. (Either point to circle or point to point)
	local leftTangentPos, leftPlaneNormal
	if leftVertex:IsWalled() then
		-- Approximate point to circle tangent in two iterations.
		-- Additionally, the approximation returns a useful result in case the bot is inside the circle.
		leftTangentPos = leftPos + (leftPos - pos2D):Cross(VECTOR_UP) * walledOffset / leftLen
		leftTangentPos = leftPos + (leftTangentPos - pos2D):Cross(VECTOR_UP):GetNormalized() * walledOffset
		leftPlaneNormal = (leftTangentPos - pos2D):Cross(VECTOR_DOWN)
	else
		-- Calculate point to point.
		leftTangentPos = leftPos
		leftPlaneNormal = (leftPos - pos2D):Cross(VECTOR_DOWN)
	end
	--leftPlaneNormal:Normalize()
	local rightTangentPos, rightPlaneNormal
	if rightVertex:IsWalled() then
		-- Approximate point to circle tangent in two iterations.
		-- Additionally, the approximation returns a useful result in case the bot is inside the circle.
		rightTangentPos = rightPos + (rightPos - pos2D):Cross(VECTOR_DOWN) * walledOffset / rightLen
		rightTangentPos = rightPos + (rightTangentPos - pos2D):Cross(VECTOR_DOWN):GetNormalized() * walledOffset
		rightPlaneNormal = (rightTangentPos - pos2D):Cross(VECTOR_UP)
	else
		-- Calculate point to point.
		rightTangentPos = rightPos
		rightPlaneNormal = (rightPos - pos2D):Cross(VECTOR_UP)
	end
	--rightPlaneNormal:Normalize()

	-- Check whether the direction points behind either plane.
	local dotLeftPlane, dotRightPlane = direction2D:Dot(leftPlaneNormal), direction2D:Dot(rightPlaneNormal)

	-- Decide on how to move.
	if (rightTangentPos - pos2D):Dot(leftPlaneNormal) > 0 then
		-- Left and right planes are swapped because the bot is standing too far to the side.
		-- In this edge case we need to use the closest tangent as destination.
		--          ▄▄▄▄▄
		--   ▄▄▄  ▄▀▄▄▄
		--  ▐███▌▄▀▐███▌
		--   ▀▀▀▄▀  ▀▀▀
		-- ▀▀▀▀▀
		if leftLen < rightLen then
			return leftTangentPos - pos2D
		else
			return rightTangentPos - pos2D
		end
	elseif dotLeftPlane > 0 and dotRightPlane > 0 then
		-- Bot is trying to move backwards because its direction crosses both planes.
		-- Use the shortest distance from either vertex to the destination.
		local destPos = direction2D + pos2D
		if leftPos:DistToSqr(destPos) < rightPos:DistToSqr(destPos) then
			return leftTangentPos - pos2D
		else
			return rightTangentPos - pos2D
		end
	elseif dotLeftPlane > 0 then
		return leftTangentPos - pos2D
	elseif dotRightPlane > 0 then
		return rightTangentPos - pos2D
	end

	-- Pass the direction through.
	return direction2D
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

	-- Path direction.
	local direction = pathFragment.PathDirection

	-- Half hull width.
	local halfHullWidth = self.HullSize[1] / 2

	-- Offsets the plane in a way that the bot doesn't get stuck on small steps.
	-- It basically moves the previous end plane by the amount that this path is too short.
	-- This is just an estimation.
	return math.min(0, direction:Length() - UTIL.PlaneXYSquareTouchDistance(prevEndPlaneNormal2D, halfHullWidth))
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
	RENDER_UTIL.Draw2DArrowPos(fromPos, toPos, 16, Color(0, 0, 255, 127))

	-- Draw end condition plane.
	if cache.EndPlane then
		cam.IgnoreZ(false)
		render.DrawQuadEasy(cache.EndPlane.Origin, -cache.EndPlane.Normal, 30, 15, Color(255, 0, 255, 127))
	end

	-- Draw limitation planes.
	for _, limitingPlane in ipairs(cache.LimitingPlanes) do
		cam.IgnoreZ(false)
		render.DrawQuadEasy(limitingPlane.Origin, -limitingPlane.Normal, 30, 15, Color(255, 0, 0, 127))
	end

	-- Draw corners (left and right vertices).
	if cache.DestVertexLeft and cache.DestVertexLeft:IsWalled() then
		render.DrawSphere(cache.DestPosLeft, cache.HalfHullSafetyWidth, 16, 3, Color(255, 0, 0, 127))
	end
	if cache.DestVertexRight and cache.DestVertexRight:IsWalled() then
		render.DrawSphere(cache.DestPosRight, cache.HalfHullSafetyWidth, 16, 3, Color(0, 255, 0, 127))
	end

	-- Draw direction field for debugging
	--[[if cache.DestVertexLeft and cache.DestVertexRight and pathFragment.Via.GetBoundingBox then
		cam.IgnoreZ(true)
		local min, max = pathFragment.Via:GetBoundingBox()
		for x = min[1], max[1], 16 do
			for y = min[2], max[2], 16 do
				local botPos = Vector(x, y, max[3])

				local outside
				if cache.EndPlane and (cache.EndPlane.Origin - botPos):Dot(cache.EndPlane.Normal) < 0 then outside = true end
				for _, limitingPlane in ipairs(cache.LimitingPlanes) do
					if (botPos - limitingPlane.Origin):Dot(limitingPlane.Normal) > 0 then outside = true break end
				end

				if not outside then

					local toPos = cache.FuturePathElement.PathFragment.ToPos
					local botPos2D = Vector(x, y, 0)

					local direction = toPos - botPos2D
					direction[3] = 0

					local clampedDirection = self:_ClampBetweenVertices(botPos2D, direction, cache.DestVertexLeft, cache.DestVertexRight, cache.HalfHullSafetyWidth)
					clampedDirection:Normalize()
					clampedDirection:Mul(16)

					RENDER_UTIL.Draw2DArrowPos(botPos, botPos + clampedDirection, 8, Color(0, 0, 255, 127))
				end
			end
		end
	end]]
end