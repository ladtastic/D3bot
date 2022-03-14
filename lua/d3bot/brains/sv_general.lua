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
local ASYNC = D3bot.Async
local BRAINS = D3bot.Brains
local ACTIONS = D3bot.Actions
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Add new brain class.
BRAINS.GENERAL = BRAINS.GENERAL or {}
local THIS_BRAIN = BRAINS.GENERAL

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_BRAIN.__index = THIS_BRAIN

---This will assign the brain to the given bot (and the corresponding mem).
---@param bot GPlayer
---@param mem table
---@return table
function THIS_BRAIN:AssignToBot(bot, mem)
	local brain = setmetatable({Bot = bot, Mem = mem, AsyncState = {}}, self)

	mem.Brain = brain
	return brain
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Think coroutine. Put all the important stuff in here.
---@param bot GPlayer
---@param mem any
function THIS_BRAIN:_ThinkCoroutine(bot, mem)

	-- Get information about the player object.
	local hullBottom, hullTop = bot:GetHull()
	local speed, hull, crouchJumpHeight, maxFallHeight = bot:GetMaxSpeed(), (hullTop - hullBottom), 65, 230
	-- TODO: Get more information about players.

	-- A list of abilities.
	-- This could be precalculated if specifics of the player entity are known beforehand, in the general case this has to be regenerated every time this brain is assigned.
	local abilities = {
		Ground = LOCOMOTION_HANDLERS.WALK:New(hull, speed),
		Wall = LOCOMOTION_HANDLERS.JUMP_AND_FALL:New(hull, crouchJumpHeight, maxFallHeight),
		AirVertical = LOCOMOTION_HANDLERS.JUMP_AND_FALL:New(hull, crouchJumpHeight, maxFallHeight),
	}

	-- Do debug command actions, if available.
	ACTIONS.DebugCommands(bot, mem, abilities)

	-- Get some target entity.
	local targetEnt = table.Random(player.GetHumans())
	if not IsValid(targetEnt) then coroutine.wait(2) return end

	-- Go to target.
	--ACTIONS.FollowTarget(bot, mem, abilities, targetEnt)

	--bot:Say("Hey!")

	-- Wait 2 seconds.
	coroutine.wait(2)

	-- A new brain will be assigned automatically after here.
end

---Think callback. Ideally this will resume coroutine(s).
---@param bot GPlayer
---@param mem table
---@return boolean
function THIS_BRAIN:Callback(bot, mem)
	-- Initialize the coroutine and continue it every call.
	local running, err = ASYNC.Run(self.AsyncState, function() self:_ThinkCoroutine(bot, mem) end)

	-- Coroutine ended unexpectedly.
	if err then
		print(string.format("%s %s", D3bot.PrintPrefix, err))
		BRAINS.ON_ERROR:AssignToBot(bot, mem)
		return false
	end

	-- Delete brain when the coroutine ends.
	if not running then
		mem.Brain = nil
	end

	return true
end
