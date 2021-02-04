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
local ERROR = D3bot.ERROR
local NAV_MAIN = D3bot.NavMain
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers
local PATH = D3bot.PATH
local PATH_POINT = D3bot.PATH_POINT

local ACTIONS = D3bot.Actions

---Checks if there is a debug command that the bot has to obey. (Like go to position x)
---If there is nothing to do, the function will return immediately.
---Put this at the beginning of your brain handler, so your bots can be commanded with the SWEP.
---@param bot GPlayer
---@param mem table
---@param abilities table<string, table> @List of mapped locomotion controllers, needed for pathfinding.
---@return D3botERROR | nil err
function ACTIONS.DebugCommands(bot, mem, abilities)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return nil end

	-- Called on errors.
	local onError = function(err)
		-- Reset control callback.
		mem.ControlCallback = nil
		-- Let the bot say what's wrong.
		bot:Say(tostring(err))
	end

	-- Get destination position that the SWEP set.
	local destPosition = mem.DebugCommandPosition
	local prevControlCallback = mem.ControlCallback
	mem.DebugCommandPosition = nil
	if not destPosition then return nil end

	-- Create points from the start and end position.
	local startPoint, err = PATH_POINT:New(navmesh, bot:GetPos())
	if err then onError(err) return err end
	local destPoint, err = PATH_POINT:New(navmesh, destPosition)
	if err then onError(err) return err end

	-- Create path object.
	local path, err = PATH:New(navmesh, abilities)
	if err then onError(err) return err end

	-- Calculate path.
	local err = path:GeneratePathBetweenPoints(startPoint, destPoint)
	if err then onError(err) return err end

	-- Control bot along the path.
	local err = path:RunPathActions(bot, mem)
	if err then onError(err) return err end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback

	return nil
end
