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
local MAPGEOMETRY = D3bot.MapGeometry ---@class D3botMAPGEOMETRY

function MAPGEOMETRY:GetCache()
	local cache = self.Cache
	if cache then return cache end

	local cache = {}
	self.Cache = cache

	-- Get all vertices
	cache.Vertices = {}
	local world = Entity(0)
	local surfaces = world:GetBrushSurfaces()
	for _, surf in ipairs(surfaces) do
		local vertices = surf:GetVertices()
		for _, vertex in ipairs(vertices) do
			table.insert(cache.Vertices, vertex)
		end
	end

	return cache
end

-- Returns the nearest corner of any world surface to the given point p with a radius of r.
-- If no point is found, point p will be returned.
function MAPGEOMETRY:GetNearestPoint(p, r)
	local cache = self:GetCache()

	return UTIL.GetNearestPoint(cache.Vertices, p, r)
end
