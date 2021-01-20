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
local PRIORITY_QUEUE = D3bot.PRIORITY_QUEUE

-- Some optimization stuff
local table_RemoveByValue = table.RemoveByValue
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
PRIORITY_QUEUE.__index = PRIORITY_QUEUE

-- Returns a sorted/prioritized queue object.
function PRIORITY_QUEUE:New()
	local obj = {
		Map = {}, -- Contains the priority for every element
		List = {} -- Contains the elements in descending priority *value* order (The last element has the highest priority)
	}

	-- Instantiate
	setmetatable(obj, self)

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Insert or overwrite an arbitrary object in(to) the queue.
-- The lower the given priValue, the higher is the priority of the inserted value.
-- By reinserting an element with a higher priority, the position in the queue will be updated.
-- Updating is a slow operation, so it's better to prevent this if possible.
function PRIORITY_QUEUE:Enqueue(elem, priValue)
	local list = self.List

	-- Check if element already exists and if its priority is smaller
	local oldPriValue = self.Map[elem]
	if oldPriValue and oldPriValue > priValue then
		-- It exists and is lower priority
		-- Stupid linear search.
		-- Alternatively it's possible to just return here and ignore the new element, this will slightly change the outcome, though.
		for i, v in ipairs(list) do
			if v[1] == elem then
				table_remove(list, i) -- "Slow" operation
				break
			end
		end
	elseif oldPriValue then
		-- It exists and is higher priority
		return
	end
	self.Map[elem] = priValue

	-- TODO: Reverse priority queue insert search order, or find another faster way

	-- Insert elem at position that preserves the priority order
	local entry = {[1] = elem, [2] = priValue}
	for i, v in ipairs(list) do
		if priValue >= v[2] then
			table_insert(list, i, entry) -- "Slow" operation
			return
		end
	end

	-- Append to list if nothing was found
	return table_insert(list, entry) -- Fast operation
end

-- Returns the element with the highest priority, and removes it from the queue.
-- Will return nil if there is no element.
function PRIORITY_QUEUE:Dequeue()
	-- Get and remove element from the end of the list
	local entry = table_remove(self.List) -- Fast operation
	if not entry then return nil end

	local elem = entry[1]

	-- Remove element from map/set
	self.Map[elem] = nil

	return elem
end

------------------------------------------------------
--		Benchmark
------------------------------------------------------

--[[local PriorityQueue = include("sh_priority_queue_2.lua")

-- Create list of 10000 elements
local testElements = {}
for i = 1, 10001 do
	local elem = {Name = "elem " .. i, Cost = math.random()}
	table_insert(testElements, elem)
end

local pq = PRIORITY_QUEUE:New(function(elem) return elem.Cost end)

local startTime = SysTime()
-- "Simulate" A* with a consistent heuristic. (Neighbors don't get requeued into the open list)
local d3ResultElements = {}
for i = 1, 1000 do
	pq:Enqueue(testElements[i*2])
	pq:Enqueue(testElements[i*2+1])
	table_insert(d3ResultElements, pq:Dequeue())
end
local endTime = SysTime()

--PrintTable(d3ResultElements)
print("D3bot v2:", endTime - startTime.."s")

------------------------------------------------------
--		Benchmark azBot
------------------------------------------------------

local lib = {}
lib.SortedQueueMeta = { __index = {} }
local sortedQueueFallback = lib.SortedQueueMeta.__index
function lib.NewSortedQueue(func)
	return setmetatable({
		Set = {},
		Func = func }, lib.SortedQueueMeta)
end
function sortedQueueFallback:Enqueue(item)
	if self.Set[item] then return end
	self.Set[item] = true
	for idx, v in ipairs(self) do if self.Func(item, v) then return table.insert(self, idx, item) end end
	return table.insert(self, item)
end
function sortedQueueFallback:Dequeue()
	local item = table.remove(self)
	if item then self.Set[item] = nil end
	return item
end

local pq = lib.NewSortedQueue(function(elemA, elemB) return elemA.Cost > elemB.Cost end)

local startTime = SysTime()
-- "Simulate" A* with a consistent heuristic. (Neighbors don't get requeued into the open list)
local azResultElements = {}
for i = 1, 1000 do
	pq:Enqueue(testElements[i*2])
	pq:Enqueue(testElements[i*2+1])
	table_insert(azResultElements, pq:Dequeue())
end
local endTime = SysTime()

--PrintTable(azResultElements)
print("azBot:", endTime - startTime.."s")

------------------------------------------------------
--		Benchmark heap based priority queue
------------------------------------------------------

local pq = PriorityQueue()

local startTime = SysTime()
-- "Simulate" A* with a consistent heuristic. (Neighbors don't get requeued into the open list)
local heapResultElements = {}
for i = 1, 1000 do
	pq:put(testElements[i*2], testElements[i*2].Cost)
	pq:put(testElements[i*2+1], testElements[i*2+1].Cost)
	table_insert(heapResultElements, pq:pop())
end
local endTime = SysTime()

--PrintTable(heapResultElements)
print("heap based:", endTime - startTime.."s")

-- Compare results
if #d3ResultElements ~= #azResultElements then print("Length of results doesn't match!") end
if #d3ResultElements ~= #heapResultElements then print("Length of results doesn't match!") end

for i, v in ipairs(d3ResultElements) do
	local v2 = azResultElements[i]
	local v3 = heapResultElements[i]
	if v ~= v2 then print("Entry "..i.." doesn't match in both result lists!") end
	if v ~= v3 then print("Entry "..i.." doesn't match in both result lists!") end
end]]
