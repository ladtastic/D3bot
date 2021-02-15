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

---Let the bot jump a single time.
---Takes 1 second in total.
---@param bot GPlayer
---@param mem table
function ACTIONS.JumpUp(bot, mem)
	-- Press jump button.
	local prevControlCallback = mem.ControlCallback
	mem.ControlCallback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetButtons(IN_JUMP)
	end

	coroutine.wait(0.2)

	-- Release jump button.
	mem.ControlCallback = nil

	coroutine.wait(0.8)

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback
end
