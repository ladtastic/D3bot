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

-- Go like error handling, just without error wrapping.

local D3bot = D3bot
local ERROR = D3bot.ERROR

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
ERROR.__index = ERROR

-- Get new instance of an error object with the given formatted message.
function ERROR:New(format, ...)
	local params = {...}
	local message = string.format(format, unpack(params))

	local obj = {
		Message = message,
	}

	-- Instantiate
	setmetatable(obj, self)

	return obj
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Return the error message as string.
function ERROR:Error()
	return self.Message
end

-- Define metamethod for string conversion.
function ERROR:__tostring()
	return self:Error()
end
