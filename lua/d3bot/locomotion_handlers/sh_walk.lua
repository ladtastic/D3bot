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
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers

-- Add new locomotion handler class.
LOCOMOTION_HANDLERS.WALKING = LOCOMOTION_HANDLERS.WALKING or {}
local THIS_LOCO_HANDLER = LOCOMOTION_HANDLERS.WALKING

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_LOCO_HANDLER.__index = THIS_LOCO_HANDLER

---Creates a new instance of a general locomotion handler for bots that can walk.
---Works best with locomotion types: "Ground".
---@param speed number
---@return table
function THIS_LOCO_HANDLER:New(speed)
	local handler = setmetatable({
		Speed = speed -- Speed for normal (unmodified) walking in engine units per second
	}, self)

	return handler
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Get the cached values of the given pathElement, if needed this will regenerate the cache.
---This will store all variables needed for controlling the bot across the pathElement.
---@param pathElement D3botPATH_ELEMENT
---@return table
function THIS_LOCO_HANDLER:GetPathElementCache(pathElement)
	local cache = pathElement.Cache
	if cache then return cache end

	-- Regenerate cache
	local cache = {}
	self.Cache = cache

	-- A signal that the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	return cache
end

---Overrides the base pathfinding cost (in engine units) for the path fragment defined in pathFragment.
---If no method is defined, the distance between the points will be used as metric.
---Any time based cost would need to be transformed into a distance based cost in here (Relative to normal walking speed).
---@param pathFragment D3botPATH_FRAGMENT
---@return number cost
--function THIS_LOCO_HANDLER:CostOverride(pathFragment)
--	return (posB - posA):Length()
--end

---Returns whether the bot can move on the path fragment described by pathFragment.
---entityData is a map that contains pathfinding metadata (Parent entity, ...).
---Leaving this undefined has the same result as returning true.
---The entities are most likely navmesh edges or NAV_PATH_POINT objects.
---This is used in pathfinding and should be as fast as possible.
---@param pathFragment D3botPATH_FRAGMENT
---@param entityData table
---@return boolean
--function THIS_LOCO_HANDLER:CanNavigate(pathFragment, entityData)
--	return true
--end

---Draw the path into a 3D rendering context.
---@param pathElement D3botPATH_ELEMENT
function THIS_LOCO_HANDLER:Render3D(pathElement)
	local pathFragment = pathElement.PathFragment
	local fromPos, toPos = pathFragment.FromPos, pathFragment.ToPos

	-- Draw arrow as the main movement direction
	RENDER_UTIL.Draw2DArrowPos(fromPos, toPos, 50, Color(0, 0, 255, 128))

	-- Draw end condition planes
	render.DrawQuadEasy(toPos, -pathFragment.OrthogonalOutside, 50, 50, Color(255, 0, 255, 128))
end
