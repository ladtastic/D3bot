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

-- Returns the cost (in engine units) between two position vectors.
-- This is used to approximate the cost for pathfinding.
-- It can't know if the bot has to crouch/duck or similar things.
-- Any time based cost would need to be transformed into a distance based cost in here.
-- This method should be as fast as possible.
function THIS_LOCO_HANDLER:GetApproximateCost(posA, posB)
	return (posB - posA):Length()
end
