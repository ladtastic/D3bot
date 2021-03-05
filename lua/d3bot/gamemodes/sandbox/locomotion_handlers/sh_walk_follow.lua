-- Copyright (C) 2021 David Vogel
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
LOCOMOTION_HANDLERS.WALK_FOLLOW = LOCOMOTION_HANDLERS.WALK_FOLLOW or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.WALK_FOLLOW

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

-- Inherit everything from the WALK locomotion handler.
THIS_LOCO_HANDLER.SuperClass = LOCOMOTION_HANDLERS.WALK
setmetatable(THIS_LOCO_HANDLER, {__index = THIS_LOCO_HANDLER.SuperClass})

---Creates a new instance of a general locomotion handler for bots that can follow something.
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

---Callback to override some values of the super locomotion handler.
---@param bot GPlayer
---@param mem any
---@param index integer
---@param pathElements D3botPATH_ELEMENT[]
---@param cache table
---@param pathElement D3botPATH_ELEMENT
---@param pathFragment D3botPATH_FRAGMENT
function THIS_LOCO_HANDLER:_ControlOverride(bot, mem, index, pathElements, cache, pathElement, pathFragment)
	local angle = CurTime() * 360 * 0.5

	-- Override the looking direction as test.
	self.LookingDirection = Angle(0, angle, 0):Forward()
end

---Override the end condition of the base class.
---@param bot GPlayer
---@param mem any
---@param index integer
---@param pathElements D3botPATH_ELEMENT[]
---@param cache table
---@param pathElement D3botPATH_ELEMENT
---@param pathFragment D3botPATH_FRAGMENT
---@return boolean | nil endCondition @Return nil to let the super class handle the end condition.
function THIS_LOCO_HANDLER:_EndConditionOverride(bot, mem, index, pathElements, cache, pathElement, pathFragment)
	if index == 1 then
		-- Never stop after the last path element.
		return false
	end

	-- Let the super class handle the end condition for any other path element.
	return nil
end
