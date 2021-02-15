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
local ACTIONS = D3bot.Actions

---Runs a gesture/sequence on the bot.
---@param bot GPlayer
---@param mem any
---@param gestureName string
function ACTIONS.Gesture(bot, mem, gestureName)
	-- BUG: Gestures don't seem to work with this kind of bot entities
	local duration = bot:SetSequence(gestureName)
	bot:ResetSequenceInfo()
	bot:SetCycle(0)
	bot:SetPlaybackRate(1)

	coroutine.wait(duration)
end
