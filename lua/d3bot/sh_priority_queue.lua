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
	local priValueFunc = self.PriValFunc
	local priValue = priValueFunc(elem)
	local list = self.List

	-- Check if element already exists
	if self.Map[elem] then
		-- Stupid linear search.
		-- Alternatively it's possible to just return here and ignore the new element, this will slightly change the outcome, though.
		table_RemoveByValue(list, elem) -- "Slow" operation
	end
	self.Map[elem] = true

	-- TODO: Reverse priority queue insert search order, or find another faster way

	-- Insert elem at position that preserves the priority order
	for i, v in ipairs(list) do
		if priValue >= priValueFunc(v) then
			table_insert(list, i, elem) -- "Slow" operation
			return
		end
	end

	-- Append to list if nothing was found
	return table_insert(list, elem) -- Fast operation
end

-- Returns the element with the highest priority, and removes it from the queue.
-- Will return nil if there is no element.
function PRIORITY_QUEUE:Dequeue()
	-- Get and remove element from the end of the list
	local elem = table_remove(self.List) -- Fast operation
	if not elem then return nil end

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
