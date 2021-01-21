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
local UTIL = D3bot.Util
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Add new locomotion handler class.
LOCOMOTION_HANDLERS.JUMP_AND_FALL = LOCOMOTION_HANDLERS.JUMP_AND_FALL or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.JUMP_AND_FALL

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

-- Creates a new instance of a general locomotion handler for bots that handles controlled falling from edges/walls and jumping onto edges.
-- Works best with locomotion types: "Wall".
function THIS_LOCO_HANDLER:New(maxJumpHeight, maxFallHeight)
	local handler = {
		MaxJumpHeight = maxJumpHeight, -- Max. jump height that a bot can achieve by crouch jumping
		MaxFallHeight = maxFallHeight -- Max. height that the bot is allowed to fall down
	}

	-- Instantiate
	setmetatable(handler, self)

	return handler
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Overrides the base pathfinding cost (in engine units) between two position vectors.
-- If not defined, the distance between the points will be used as metric.
-- Any time based cost would need to be transformed into a distance based cost in here (Relative to normal walking speed).
function THIS_LOCO_HANDLER:CostOverride(posA, posB)
	-- Assume near 0 cost for falling or jumping, which is somewhat realistic
	return 0
end

-- Returns whether the bot can move from entityA to entityB via entityVia.
-- entityData is a map that contains pathfinding metadata (Parent entity, ...).
-- Leaving this undefined has the same result as returning true.
-- The entities are most likely navmesh edges or NAV_PATH_POINT objects.
-- This is used in pathfinding and should be as fast as possible.
function THIS_LOCO_HANDLER:CanNavigate(entityA, entityVia, entityB, entityData)

	-- TODO: Get max diff for non parallel edges
	local posA, posB = entityA:GetCentroid(), entityB:GetCentroid()
	local zDiff = posB[3] - posA[3]
	local sideLengthSqr = (posB - posA):Length2DSqr()

	-- Check if the nodes are somewhat aligned vertically
	if sideLengthSqr > zDiff * zDiff then
		return false
	end

	-- Get zDiff of the previous element, or nil.
	-- A positive zDiff means that the current part is just a fraction of the total jump path.
	-- A negative zDiff means that the current part is just a fraction of the total fall path.
	-- nil means that this is the only or initial jump/fall path.
	local previousEntity = entityData[entityA].From
	local previousZDiff = previousEntity and entityData[previousEntity].ZDiff or nil

	-- A bot can either fall or jump in one go, a mix isn't allowed
	if previousZDiff and UTIL.SimpleSign(zDiff) ~= UTIL.SimpleSign(previousZDiff) then return false end

	-- Check if bot is in the possible and or safe zone
	local totalZDiff = zDiff + (previousZDiff or 0)
	if totalZDiff > -self.MaxFallHeight and totalZDiff < self.MaxJumpHeight then
		-- Store total vertical diff for the next node that may use it
		entityData[entityA].ZDiff = totalZDiff
		return true
	end

	-- Bot can neither jump up that edge, nor can if safely fall down
	return false
end
