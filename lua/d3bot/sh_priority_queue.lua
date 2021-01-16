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
local PRIORITY_QUEUE = D3bot.PRIORITY_QUEUE

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
PRIORITY_QUEUE.__index = PRIORITY_QUEUE

-- Returns a sorted/prioritized queue object.
-- priValFunc is used to determine the priority *value* of each element. (A priority value of 1 is of higher priority than a priority value of 2)
-- Internally, the elements are ordered ascending by their priority *value* (first element has the highest priority).
function PRIORITY_QUEUE:New(priValFunc)
	local obj = {
		Map = {},
		List = {},
		PriValFunc = priValFunc
	}

	-- Instantiate
	setmetatable(obj, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Insert or overwrite an arbitrary object in(to) the queue.
-- Overwrite will only happen if the element's priority is higher (lower priority value) than the current existing element.
-- Returns the index the element was placed at, or nil.
function PRIORITY_QUEUE:Enqueue(elem)
	local priValue = self.PriValFunc(elem)

	-- Check if element already exists, and if its priority is higher than the new priority
	if self.Map[elem] then
		if self.Map[elem] <= priValue then
			-- Element exists, but the new has a lower priority.
			return nil
		else
			-- Element exists, but the new has a higher priority.
			-- Delete existing element first.
			-- This is stupid linear search, alternatively it's possible to return the method here and just ignore the new element.
			-- This will slightly change the outcome, though.
			for i, v in ipairs(self.List) do
				if v == elem then
					table.remove(self.List, i)
					break
				end
			end
		end
	end

	-- Assign priority value to map element
	self.Map[elem] = priValue

	-- Insert elem at position that preserves the priority order
	for i, v in ipairs(self.List) do
		if priValue <= self.PriValFunc(v) then
			return table.insert(self.List, i, value)
		end
	end

	-- Append to list if nothing smaller was found
	return table.insert(self.List, value)
end

-- Returns the element with the highest priority, and removes it from the queue.
-- Will return nil if there is no element.
function PRIORITY_QUEUE:Dequeue()
	local elem = table.remove(self.List, 1)
	if not elem then return nil end

	self.Map[elem] = nil
	return elem
end
