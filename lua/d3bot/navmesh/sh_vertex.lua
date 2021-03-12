-- Copyright (C) 2020-2021 David Vogel
--
-- This file is part of D3bot.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local UTIL = D3bot.Util
local ERROR = D3bot.ERROR

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNAV_VERTEX
---@field Navmesh D3botNAV_MESH
---@field ID number | string
---@field Point GVector
---@field Edges D3botNAV_EDGE[] @This points to edges that are using this vertex.
---@field Cache table | nil @Contains connected neighbor edges and other cached values.
---@field UI table @General structure for UI related properties like selection status
local NAV_VERTEX = D3bot.NAV_VERTEX
NAV_VERTEX.__index = NAV_VERTEX

-- Radius of the vertex used for drawing and mouse click tracing.
NAV_VERTEX.DisplayRadius = 5

---Get new instance of an vertex object by a single point vertex.
---If a vertex with the same id already exists, it will be replaced.
---The point coordinates will be rounded to a single engine unit.
---@param navmesh D3botNAV_MESH
---@param id number | string
---@param p GVector
---@return D3botNAV_VERTEX | nil
---@return D3botERROR | nil err
function NAV_VERTEX:New(navmesh, id, p)
	p = UTIL.RoundVector(p)

	local obj = setmetatable({
		Navmesh = navmesh,
		ID = id or navmesh:GetUniqueID(),
		Point = p,
		Edges = {},
		Cache = nil,
		UI = {},
	}, self)

	-- General parameter checks. -- TODO: Check parameters for types and other stuff.
	if not navmesh then return nil, ERROR:New("Invalid value of parameter %q", "navmesh") end
	if not p then return nil, ERROR:New("Invalid value of parameter %q", "p") end

	-- TODO: Check if ID is used by a different entity type

	-- Check if there was a previous element. If so, change references to/from it.
	local old = navmesh.Vertices[obj.ID]
	if old then
		obj.Edges = old.Edges

		-- Iterate over linked edges.
		for _, edge in ipairs(old.Edges) do
			-- Correct the vertex references of these edges.
			for i, vertex in ipairs(edge.Vertices) do
				if vertex == old then
					edge.Vertices[i] = obj
				end
			end
		end

		old.Edges = {}
		old:_Delete()
	end

	-- Invalidate cache of connected edges.
	for _, edge in ipairs(obj.Edges) do
		edge:InvalidateCache()
	end

	-- Add object to the navmesh.
	navmesh.Vertices[obj.ID] = obj

	-- Publish change event.
	if navmesh.PubSub then
		navmesh.PubSub:SendVertexToSubs(obj)
	end

	return obj, nil
end

---Same as NAV_VERTEX:New(), but uses table t to restore a previous state that came from MarshalToTable().
---@param navmesh D3botNAV_MESH
---@param t table
---@return D3botNAV_VERTEX | nil
---@return D3botERROR | nil err
function NAV_VERTEX:NewFromTable(navmesh, t)
	local obj, err = self:New(navmesh, t.ID, t.Point)
	return obj, err
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns the object's ID, which is most likely a number object.
---It can also be a string, though.
---@return number | string
function NAV_VERTEX:GetID()
	return self.ID
end

---Returns a table that contains all important data of this object.
---@return table
function NAV_VERTEX:MarshalToTable()
	local t = {
		ID = self:GetID(),
		Point = Vector(self.Point),
	}

	return t -- Make sure that any object returned here is a deep copy of its original.
end

---Get the cached values, if needed this will regenerate the cache.
--@return table
function NAV_VERTEX:GetCache()
	local cache = self.Cache
	if cache then return cache end

	-- Regenerate cache.
	local cache = {}
	self.Cache = cache

	-- A flag indicating if the cache contains correct or malformed data.
	-- Changing this to false will not cause the cache to be rebuilt.
	cache.IsValid = true

	-- A flag stating if this vertex is located at a wall. Bots will try to keep distance to these vertices.
	cache.IsWalled = false
	for _, edge in pairs(self.Edges) do
		if edge:_IsWalled() then
			cache.IsWalled = true
			break
		end
	end

	return cache
end

---Invalidate the cache, it will be regenerated on next use.
function NAV_VERTEX:InvalidateCache()
	self.Cache = nil
end

---Deletes the edge from the navmesh and makes sure that there is nothing left that references it.
function NAV_VERTEX:Delete()
	-- Publish change event.
	if self.Navmesh.PubSub then
		self.Navmesh.PubSub:DeleteByIDFromSubs(self:GetID())
	end

	return self:_Delete()
end

---Internal method.
function NAV_VERTEX:_Delete()
	-- Delete any edges that use this vertex.
	for _, edge in ipairs(self.Edges) do
		edge:_Delete()
	end

	self.Navmesh.Vertices[self.ID] = nil
	self.Navmesh = nil
end

---Internal method: Deletes the vertex, if there is nothing that references it.
---Only call GC from the server side and let it sync the result to all clients.
function NAV_VERTEX:_GC()
	if #self.Edges == 0 then
		self:Delete()
	end
end

---Returns the average of all points that are contained in this geometry, or nil.
---@return GVector
function NAV_VERTEX:GetCentroid()
	return self.Point
end

---Returns the points (vectors) that this entity is made of.
---May use the cache.
---@return GVector[]
function NAV_VERTEX:GetPoints()
	return {self.Point}
end

---Internal and uncached version of GetPoints.
---@return GVector[]
function NAV_VERTEX:_GetPoints()
	return {self.Point}
end

---Returns the list of vertices that this entity is made of.
---@return D3botNAV_VERTEX[]
function NAV_VERTEX:GetVertices()
	return {self}
end

---Returns the vector that describes this vertex.
---@return GVector
function NAV_VERTEX:GetPoint()
	return self.Point
end

---Returns whether this vector is placed at a wall (or some other non walkable geometry) or not.
---Locomotion controllers can use this information to give bots more distances in paths so that they corner this vertex.
---@return boolean
function NAV_VERTEX:IsWalled()
	local cache = self:GetCache()
	return cache.IsWalled
end

---Returns whether the vertex is made of a single point (vector).
---The point coordinates will be rounded to a single engine unit.
---@param p GVector
---@return boolean
function NAV_VERTEX:ConsistsOfPoint(p)
	p = UTIL.RoundVector(p)
	if self.Point == p then return true end
	return false
end

---Draw the edge into a 3D rendering context.
function NAV_VERTEX:Render3D()
	local ui = self.UI
	local p = self.Point
	local cache = self:GetCache()

	if ui.Highlighted then
		ui.Highlighted = nil
		cam.IgnoreZ(true)
		render.DrawSphere(p, self.DisplayRadius, 6, 6, Color(255, 255, 255, 127))
		cam.IgnoreZ(false)
	else
		if cache.IsWalled then
			render.DrawSphere(p, self.DisplayRadius, 6, 6, Color(255, 255, 0, 255))
		else
			render.DrawSphere(p, self.DisplayRadius, 6, 6, Color(255, 0, 0, 255))
		end
	end
end

---Define metamethod for string conversion.
---@return string
function NAV_VERTEX:__tostring()
	return string.format("{Vertex %s}", self:GetID())
end
