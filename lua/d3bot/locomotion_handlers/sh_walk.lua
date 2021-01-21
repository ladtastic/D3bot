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
LOCOMOTION_HANDLERS.WALKING = LOCOMOTION_HANDLERS.WALKING or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.WALKING

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

-- Creates a new instance of a general locomotion handler for bots that can walk.
-- Works best with locomotion types: "Ground".
function THIS_LOCO_HANDLER:New(speed)
	local handler = {
		Speed = speed -- Speed for normal (unmodified) walking in engine units per second
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

-- Returns whether the bot can move from entityA to entityB via entityVia.
-- entityData is a map that contains pathfinding metadata (Parent entity, ...).
-- Leaving this undefined has the same result as returning true.
-- The entities are most likely navmesh edges or NAV_PATH_POINT objects.
-- This is used in pathfinding and should be as fast as possible.
--function THIS_LOCO_HANDLER:CanNavigate(entityA, entityVia, entityB, entityData)
--	return true
--end
