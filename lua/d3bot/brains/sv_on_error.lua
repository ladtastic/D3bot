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
BRAINS.ON_ERROR = BRAINS.ON_ERROR or {}
local THIS_BRAIN = BRAINS.ON_ERROR

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
	--bot:Say("I had a stronk")

	-- Do dumb gesture/sequence.
	--ACTIONS.Gesture(bot, mem, "taunt_robot")

	-- Jump several times.
	for i = 1, 2, 1 do
		bot:EmitSound("vo/k_lab/kl_ahhhh.wav")
		ACTIONS.JumpUp(bot, mem)
	end

	coroutine.wait(math.random() * 10)

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
