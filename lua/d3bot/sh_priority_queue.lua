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
-- Internally, the elements are ordered descending by their priority *value* (The last element has the highest priority).
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
-- By inserting an element again (Overwriting), its position in the queue will be recalculated.
-- Overwriting is a slow operation, so it's better to prevent this if possible.
-- You must make sure that the priority value doesn't change for any element stored inside the queue, otherwise you will get wrong results.
function PRIORITY_QUEUE:Enqueue(elem)
	local priValue = self.PriValFunc(elem)

	-- Check if element already exists
	if self.Map[elem] then
		-- Stupid linear search.
		-- Alternatively it's possible to just return here and ignore the new element, this will slightly change the outcome, though.
		table.RemoveByValue(self.List, elem) -- "Slow" operation
	end
	self.Map[elem] = true

	-- TODO: Reverse priority queue insert search order, or find another faster way

	-- Insert elem at position that preserves the priority order
	for i, v in ipairs(self.List) do
		if priValue >= self.PriValFunc(v) then
			table.insert(self.List, i, elem) -- "Slow" operation
			return
		end
	end

	-- Append to list if nothing was found
	return table.insert(self.List, elem) -- Fast operation
end

-- Returns the element with the highest priority, and removes it from the queue.
-- Will return nil if there is no element.
function PRIORITY_QUEUE:Dequeue()
	-- Get and remove element from the end of the list
	local elem = table.remove(self.List) -- Fast operation
	if not elem then return nil end

	-- Remove element from map/set
	self.Map[elem] = nil

	return elem
end
