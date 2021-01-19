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
local ACTIONS = D3bot.Actions

-- Let the bot jump a single time.
-- Takes 1 second in total.
function ACTIONS.JumpUp(bot, mem)
	-- Press jump button
	mem.ControlCallback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetButtons(IN_JUMP)
	end

	coroutine.wait(0.2)

	-- Release jump button
	mem.ControlCallback = nil

	coroutine.wait(0.8)
end
