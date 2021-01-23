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

-- TODO: Use heap based method to sort the objects

local D3bot = D3bot

-- Some optimization stuff
local table_RemoveByValue = table.RemoveByValue
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botPRIORITY_QUEUE
---@field Map table<any, number> @Contains the priority for every element
---@field List any[] @Contains the elements in descending priority *value* order (The last element has the highest priority)
local PRIORITY_QUEUE = D3bot.PRIORITY_QUEUE
PRIORITY_QUEUE.__index = PRIORITY_QUEUE

---Returns a sorted/prioritized queue object.
---@return D3botPRIORITY_QUEUE | nil
---@return D3botERROR | nil err
function PRIORITY_QUEUE:New()
	local obj = setmetatable({
		Map = {},
		List = {}
	}, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Insert or overwrite an arbitrary object in(to) the queue.
---The lower the given priValue, the higher is the priority of the inserted value.
---By reinserting an element with a higher priority, the position in the queue will be updated.
---Updating is a slow operation, so it's better to prevent this if possible.
---@param elem any
---@param priValue number
---@return boolean inserted @Returns true if the element was inserted or updated, false otherwise.
function PRIORITY_QUEUE:Enqueue(elem, priValue)
	local list = self.List

	-- Check if element already exists and if its priority is smaller
	local oldPriValue = self.Map[elem]
	if oldPriValue and oldPriValue > priValue then
		-- It exists and is lower priority
		-- Stupid linear search, but at least it's more likely to find the element in the lower half of the list.
		-- Alternatively it's possible to just return here and ignore the new element, this will slightly change the outcome, though.
		for i, v in ipairs(list) do
			if v[1] == elem then
				table_remove(list, i) -- "Slow" operation
				break
			end
		end
	elseif oldPriValue then
		-- It exists and is higher priority
		return false
	end
	self.Map[elem] = priValue

	-- TODO: Reverse priority queue insert search order, or find another faster way

	-- Insert elem at position that preserves the priority order.
	-- Stupid linear search, it would be slightly better to search from the top. But only slightly.
	local entry = {elem, priValue}
	for i, v in ipairs(list) do
		if priValue >= v[2] then
			table_insert(list, i, entry) -- "Slow" operation
			return true
		end
	end

	-- Append to list if nothing was found
	table_insert(list, entry) -- Fast operation
	return true
end

---Returns the element with the highest priority, and removes it from the queue.
---Will return nil if there is no element.
---@return any | nil
function PRIORITY_QUEUE:Dequeue()
	-- Get and remove element from the end of the list
	local entry = table_remove(self.List) -- Fast operation
	if not entry then return nil end

	local elem = entry[1]

	-- Remove element from map/set
	self.Map[elem] = nil

	return elem
end
