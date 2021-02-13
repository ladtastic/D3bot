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
local ASYNC = D3bot.Async

---Runs the given function asynchronously.
---This can be used to run blocking functions *seemingly* parallel to other code.
---There is no parallelism, so ASYNC.Run has to be called until it returns false, which means the function has ended, or has panicked.
---@param state table @Contains the coroutine and its state. Initialize and reuse an empty table for this.
---@param func function @The function to call asynchronously.
---@return boolean running
---@return D3botERROR | nil err
function ASYNC.Run(state, func)
	-- Start coroutine on the first call.
	local cr = state[1]
	if not cr then
		cr = coroutine.create(func)
		state[1] = cr
	end

	-- Resume coroutine, catch and print any error.
	local succ, msg = coroutine.resume(cr)
	if not succ then
		-- Coroutine ended unexpectedly.
		--print(string.format("%s %s failed: %s", D3bot.PrintPrefix, cr, msg))
		return false, ERROR:New("%s failed: %s", cr, msg)
	end

	-- Check if the coroutine finished. We will never encounter "running", as we don't call coroutine.status from inside the coroutine.
	if coroutine.status(cr) ~= "suspended" then
		return false, nil
	end

	return true, nil
end