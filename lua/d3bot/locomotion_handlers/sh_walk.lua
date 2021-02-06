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
	-- Don't sum up elements that have a different locomotion handler (Or after).
	local futureDirectionSum = Vector(0, 0, 0)
	for i = index-1, index-5, -1 do
		local tempPathElement = pathElements[i]
		if not tempPathElement or tempPathElement.LocomotionHandler ~= self then break end
		futureDirectionSum = futureDirectionSum + tempPathElement.PathFragment.PathDirection
	end
	cache.FutureDirectionSum = futureDirectionSum

	-- End condition. (As a plane that the bot has to cross)
	cache.EndPlaneOrigin = pathFragment.ToPos
	cache.EndPlaneNormal = pathFragment.ToOrthogonal

	-- Use offset information of the next element to move this element's end plane.
	local endPlaneOffset = 0
	local nextPathElement = pathElements[index-1] -- The previous index is the next path element.
	if nextPathElement then
		local locHandler = nextPathElement.LocomotionHandler
		if locHandler.BeginOffset then
			endPlaneOffset = locHandler:BeginOffset(index-1, pathElements, cache.EndPlaneNormal)
			cache.EndPlaneOrigin = cache.EndPlaneOrigin + endPlaneOffset * cache.EndPlaneNormal
		end
	end

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
	cache.FromNormVector = fromNormVector
	if #fromVertices == 2 and fromVertices[1]:IsWalled() then
		fromPoints[1] = fromPoints[1] + fromNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(fromNormVector)), 1, fromPoints[1]:Distance(fromPoints[2]))
	end
	if #fromVertices == 2 and fromVertices[2]:IsWalled() then
		fromPoints[2] = fromPoints[2] - fromNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(fromNormVector)), 1, fromPoints[1]:Distance(fromPoints[2]))
	end
	if #toVertices == 2 and toVertices[1]:IsWalled() then
		toPoints[1] = toPoints[1] + toNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(toNormVector)), 1, toPoints[1]:Distance(toPoints[2]))
	end
	if #toVertices == 2 and toVertices[2]:IsWalled() then
		toPoints[2] = toPoints[2] - toNormVector * math.Clamp((halfHullWidth + 5) / math.abs(pathRight:Dot(toNormVector)), 1, toPoints[1]:Distance(toPoints[2]))
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
	cache.FromLeft, cache.FromRight, cache.ToLeft, cache.ToRight = fromLeft, fromRight, toLeft, toRight

	-- Limitation plane on the right side that prevents the bot from dropping down cliffs or scrubbing along walls.
	-- It's pointing to the outside.
	cache.RightPlaneOrigin = (fromRight + toRight) / 2
	if (toRight - fromRight):IsZero() then
		cache.RightPlaneNormal = pathDirection:Cross(Vector(0, 0, 1)):GetNormalized()
	else
		cache.RightPlaneNormal = (toRight - fromRight):Cross(Vector(0, 0, 1)):GetNormalized()
	end

	-- Limitation plane on the left side that prevents the bot from dropping down cliffs or scrubbing along walls.
	-- It's pointing to the outside.
	cache.LeftPlaneOrigin = (fromLeft + toLeft) / 2
	if (fromLeft - toLeft):IsZero() then
		cache.LeftPlaneNormal = -pathDirection:Cross(Vector(0, 0, 1)):GetNormalized()
	else
		cache.LeftPlaneNormal = (fromLeft - toLeft):Cross(Vector(0, 0, 1)):GetNormalized()
	end

	-- Limitation plane on the "from" entity (edge or point) that prevents the bot from going backwards in some edge cases.
	-- It doesn't exist for point entities.
	-- It's pointing to the outside.
	if not (fromRight - fromLeft):IsZero() then
		cache.BackPlaneNormal = (fromRight - fromLeft):Cross(Vector(0, 0, 1)):GetNormalized()
		cache.BackPlaneOrigin = pathFragment.FromPos - cache.BackPlaneNormal * (halfHullWidth + 5)
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

	-- Get general 2D movement direction.
	local direction

	-- Initialize smoothed direction vector.
	local lookingDirection = bot:GetAimVector()

	-- Generate list of limiting planes. (Back, left and right)
	local limitingPlanes = {
		{Origin = cache.LeftPlaneOrigin, Normal = cache.LeftPlaneNormal},
		{Origin = cache.RightPlaneOrigin, Normal = cache.RightPlaneNormal},
	}
	if cache.BackPlaneOrigin then
		table.insert(limitingPlanes, {Origin = cache.BackPlaneOrigin, Normal = cache.BackPlaneNormal})
	end

	local prevControlCallback = mem.ControlCallback
	---Push the right buttons and stuff.
	---@param bot GPlayer
	---@param mem any
	---@param cUserCmd table
	mem.ControlCallback = function(bot, mem, cUserCmd)

		local botPos = bot:GetPos()

		-- If this is the last path element, go straight towards it.
		local walkingDirection
		if index == 1 then
			walkingDirection = (pathFragment.ToPos - botPos) * 0.1
			if not direction then
				direction = walkingDirection:GetNormalized()
			end
		else
			-- Check limiting planes that prevent the bot from leaving the valid walking area.
			local directionCorrection = Vector()
			local pointingOutside = false
			for _, limitingPlane in ipairs(limitingPlanes) do
				if (botPos - limitingPlane.Origin):Dot(limitingPlane.Normal) > 0 then
					-- Bot has crossed one of the limiting planes. Adjust its direction so that it moves back inside.
					directionCorrection:Sub(limitingPlane.Normal * 0.5)

					-- Check if the general movement direction of the bot points outside this plane.
					-- The pointingOutside check is just for speedup.
					if direction and not pointingOutside and direction:Dot(limitingPlane.Normal) > 0 then
						pointingOutside = true
					end
				end
			end

			-- Bot is behind a limiting plane AND is moving to the outside.
			-- Calculate new direction from current position that goes straight to the destination edge/point.
			-- Basically this is 2D string pulling from the current position to some future position through the edge.
			-- Normally this would check how many future path elements can be combined into a straight line, but for simplicity and faster calculation it uses a fixed amount and a precalculated beeline.
			-- There are a lot of distance/normalization calculations going on, this needs to be optimized.
			-- TODO: Optimize string pulling in walk handler.
			if not direction or pointingOutside then
				-- Get the 2D vector that describes the destination entity (edge or point).
				local destOrigin, destVector = Vector(cache.ToLeft[1], cache.ToLeft[2], 0), cache.ToRight - cache.ToLeft
				destVector[3] = 0

				local toPos2D = Vector(pathFragment.ToPos[1], pathFragment.ToPos[2], 0)
				local botPos2D = Vector(botPos[1], botPos[2], 0)

				if destVector:IsZero() then
					-- Destination is a point.

					direction = (toPos2D - botPos2D):GetNormalized()
				else
					-- 2D direction to the end of some future path element.
					local beeline = (toPos2D - botPos2D) + cache.FutureDirectionSum
					beeline[3] = 0

					-- Normal describing a plane on the end/destination entity pointing outwards.
					local tempOrthoNormal = destVector:Cross(Vector(0, 0, -1)):GetNormalized()

					-- Check if the beeline (ray) points into the direction of the plane.
					local denominator = beeline:Dot(tempOrthoNormal)
					if denominator > 0 then
						-- Beeline points towards the plane.

						-- Get distance from bot pos to intersection and the intersection point.
						local beelineFraction = (destOrigin - botPos2D):Dot(tempOrthoNormal) / denominator
						local point = botPos2D + beeline * beelineFraction

						-- Point will lie on the destination edge, now calculate the fraction.
						local destFraction = (point - destOrigin):Dot(destVector) / destVector:LengthSqr()

						-- Clamp resulting point.
						destFraction = math.Clamp(destFraction, 0, 1)
						local clampedPoint = destOrigin + destVector * destFraction

						direction = (clampedPoint - botPos2D):GetNormalized()

					else
						-- Beeline is either parallel or points back from the plane.

						if beeline:Dot(destVector) > 0 then
							-- The beeline points towards the end of the edge (destVector).
							direction = (destOrigin + destVector - botPos2D):GetNormalized()
						else
							-- The beeline points towards the beginning of the edge (destVector).
							direction = (destOrigin - botPos2D):GetNormalized()
						end
					end
				end
			end

			walkingDirection = direction + directionCorrection
		end

		-- Smooth out the movement and make it 2D.
		lookingDirection = lookingDirection * 0.9 + direction * 0.1
		lookingDirection[3] = 0

		-- Get future aim and right sided vector.
		-- TODO: Use some different direction as view angle.
		local angle = lookingDirection:Angle()
		local aim2D = lookingDirection
		local right2D = aim2D:Cross(Vector(0, 0, 1))

		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		--cUserCmd:SetButtons(bit.bor(IN_FORWARD))
		cUserCmd:SetForwardMove(self.Speed * aim2D:Dot(walkingDirection))
		cUserCmd:SetSideMove(self.Speed * right2D:Dot(walkingDirection))
		cUserCmd:SetViewAngles(angle)
		bot:SetEyeAngles(angle)
	end

	-- Wait until the bot crosses the end/destination plane.
	while (cache.EndPlaneOrigin - bot:GetPos()):Dot(cache.EndPlaneNormal) >= 0 do

		-- TODO: Add "is stuck" timeout that stops this action after some time
		-- TODO: Add method to reset "is stuck" timeout (especially from inherited objects)

		coroutine.yield()
	end

	-- If this is the last element, give it some more time.
	if index == 1 then coroutine.wait(0.2) end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback
end

---Returns an offset that a previous element can use to offset its end plane.
---@param index integer
---@param pathElements D3botPATH_ELEMENT[]
---@param prevEndPlaneNormal GVector @Normal of the previous element's end plane.
---@return number
function THIS_LOCO_HANDLER:BeginOffset(index, pathElements, prevEndPlaneNormal)
	local pathElement = pathElements[index]
	local pathFragment = pathElement.PathFragment

	-- Path direction.
	local direction = pathFragment.PathDirection

	-- Half hull width.
	local halfHullWidth = self.HullSize[1] / 2

	-- Offsets the plane in a way that the bot doesn't get stuck on small steps.
	-- It basically moves the previous end plane by the amount that this path is too short.
	-- This is just an estimation.
	return math.min(0, direction:Length() - halfHullWidth)
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
	RENDER_UTIL.Draw2DArrowPos(fromPos, toPos, 10, Color(0, 0, 255, 128))

	-- Draw end condition planes.
	cam.IgnoreZ(false)
	render.DrawQuadEasy(cache.EndPlaneOrigin, -cache.EndPlaneNormal, 30, 15, Color(255, 0, 255, 128))

	-- Draw right limitation plane.
	cam.IgnoreZ(false)
	render.DrawQuadEasy(cache.RightPlaneOrigin, -cache.RightPlaneNormal, 30, 10, Color(255, 0, 0, 128))

	-- Draw left limitation plane.
	cam.IgnoreZ(false)
	render.DrawQuadEasy(cache.LeftPlaneOrigin, -cache.LeftPlaneNormal, 30, 10, Color(0, 255, 0, 128))

	-- Draw back limitation plane.
	if cache.BackPlaneOrigin then
		cam.IgnoreZ(false)
		render.DrawQuadEasy(cache.BackPlaneOrigin, -cache.BackPlaneNormal, 30, 10, Color(0, 0, 0, 128))
	end

	-- Draw plane the the bot is able to walk on.
	cam.IgnoreZ(true)
	render.DrawQuad(cache.FromLeft, cache.ToLeft, cache.ToRight, cache.FromRight, Color(0, 0, 255, 63))
end
