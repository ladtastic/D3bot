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

-- TODO: Get JUMP_AND_FALL locomotion handler working.

-- There are some problems to be solved first, or worked around in another way:
--   1. There needs to be a way to get the total drop or total jump height of several connected triangles
--   2. There needs a check if bottom and top edges are somewhat vertically aligned
--   3. Alternatively use "air connections" to handle jumping and falling
--   4. Another alternative is to use polygons instead of triangles (Or group triangles into convex polygons)

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
--function THIS_LOCO_HANDLER:CostOverride(posA, posB)
--	return (posB - posA):Length()
--end

-- Returns whether the bot can move from posA to posB.
-- edgeA and edgeB may not be nil.
-- This is used in pathfinding and should be as fast as possible.
function THIS_LOCO_HANDLER:CanNavigateToPos(posA, posB)
	local zDiff = posB[3] - posA[3]
	if zDiff > -self.MaxFallHeight and zDiff < self.MaxJumpHeight then
		return true
	end

	-- Can neither jump up that edge, nor should it fall down (due to possible damage)
	return false
end
