-- Copyright (C) 2021 David Vogel
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
local UTIL = D3bot.Util
local ASYNC = D3bot.Async
local NAV_MAIN = D3bot.NavMain
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers
local PATH = D3bot.PATH
local PATH_POINT = D3bot.PATH_POINT

local ACTIONS = D3bot.Actions

---Makes the bot navigate to a target entity.
---This will update the path while the bot is walking towards the target.
---@param bot GPlayer
---@param mem table
---@param abilities table<string, table> @List of mapped locomotion controllers, needed for pathfinding.
---@param target GEntity
---@return D3botERROR | nil err
function ACTIONS.FollowTarget(bot, mem, abilities, target)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return nil end

	-- Called on errors.
	local onError = function(err)
		-- Reset control callback.
		mem.ControlCallback = nil
		-- Let the bot say what's wrong.
		bot:Say(tostring(err))
	end

	-- Create path object.
	local path, err = PATH:New(navmesh, abilities)
	if err then onError(err) return err end

	-- Save control callback.
	local prevControlCallback = mem.ControlCallback

	-- Control bot along the path, but asynchronously.
	local as = {}
	while true do
		-- Update path. In the ideal case this will only change the destination position of the last path element.
		-- In the worst case this will regenerate the whole path.
		local err = path:UpdatePathToPos(bot:GetPos(), target:GetPos())
		if err then onError(err) return err end

		-- Let the bot walk along the newly updated path.
		local running, err = ASYNC.Run(as, function ()
			local err = path:RunPathActions(bot, mem)
			if err then onError(err) end
		end)

		-- Action end conditions.
		if err then onError(err) return err end
		if not running then break end

		coroutine.yield()
	end

	-- Restore previous control callback.
	mem.ControlCallback = prevControlCallback

	return nil
end
