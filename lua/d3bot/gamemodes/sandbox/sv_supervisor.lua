-- Copyright (C) 2020-2021 David Vogel
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

local function MaintainBotRoles()
	local bots = player.GetBots()

	if #bots < 5 then
		---@type GPlayer
		local bot = player.CreateNextBot(D3bot.GetBotName())
		bot.D3bot = {}
	elseif #bots > 5 then
		bots[1]:Kick("blabla") -- TODO: Add kick message
	end
end
timer.Create(D3bot.HookPrefix .. "MaintainBotRoles", 0.1, 0, MaintainBotRoles)
