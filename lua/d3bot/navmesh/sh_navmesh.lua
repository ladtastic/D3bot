-- Copyright (C) 2020-2021 David Vogel
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
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local ERROR = D3bot.ERROR
local NAV_VERTEX = D3bot.NAV_VERTEX
local NAV_EDGE = D3bot.NAV_EDGE
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE
local NAV_AIR_CONNECTION = D3bot.NAV_AIR_CONNECTION

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNAV_MESH
---@field Vertices D3botNAV_VERTEX[]
---@field Edges D3botNAV_EDGE[]
---@field Triangles D3botNAV_TRIANGLE[]
---@field AirConnections D3botNAV_AIR_CONNECTION[]
---@field PubSub D3botNAV_PUBSUB
---@field UniqueIDCounter integer
local NAV_MESH = D3bot.NAV_MESH
NAV_MESH.__index = NAV_MESH

---Get new instance of a navmesh container object.
---This contains edges and triangles of a navmesh and provides methods for locating and path finding.
---@return D3botNAV_MESH
---@return D3botERROR | nil err
function NAV_MESH:New()
	local obj = setmetatable({
		Vertices = {},
		Edges = {},
		Triangles = {},
		AirConnections = {},
		PubSub = nil,
		UniqueIDCounter = 1,
	}, self)

	return obj, nil
end

---Same as NAV_MESH:New(), but uses table t to restore a previous state that came from MarshalToTable().
---@param t table
---@return D3botNAV_MESH
---@return D3botERROR | nil err
function NAV_MESH:NewFromTable(t)
	local obj, err = self:New()
	if err then return nil, err end

	if not t.Vertices then return nil, ERROR:New("The field %q is missing from the table", "Vertices") end
	if not t.Edges then return nil, ERROR:New("The field %q is missing from the table", "Edges") end
	if not t.Triangles then return nil, ERROR:New("The field %q is missing from the table", "Triangles") end
	if not t.AirConnections then return nil, ERROR:New("The field %q is missing from the table", "AirConnections") end

	-- Ignore but print any sub errors, so malformed navmesh elements are ignored, but the rest is loaded.

	-- Restore vertices.
	if t.Vertices then
		for _, vertexTable in ipairs(t.Vertices) do
			local _, err = NAV_VERTEX:NewFromTable(obj, vertexTable)
			if err then print(string.format("%s Failed to restore vertex %s: %s", D3bot.PrintPrefix, vertexTable.ID, err)) end
		end
	end

	-- Restore edges.
	if t.Edges then
		for _, edgeTable in ipairs(t.Edges) do
			local _, err = NAV_EDGE:NewFromTable(obj, edgeTable)
			if err then print(string.format("%s Failed to restore edge %s: %s", D3bot.PrintPrefix, edgeTable.ID, err)) end
		end
	end

	-- Restore triangles.
	if t.Triangles then
		for _, triangleTable in ipairs(t.Triangles) do
			local _, err = NAV_TRIANGLE:NewFromTable(obj, triangleTable)
			if err then print(string.format("%s Failed to restore triangle %s: %s", D3bot.PrintPrefix, triangleTable.ID, err)) end
		end
	end

	-- Restore air connections.
	if t.AirConnections then
		for _, airConnectionTable in ipairs(t.AirConnections) do
			local _, err = NAV_AIR_CONNECTION:NewFromTable(obj, airConnectionTable)
			if err then print(string.format("%s Failed to restore air connection %s: %s", D3bot.PrintPrefix, airConnectionTable.ID, err)) end
		end
	end

	return obj, nil
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Returns a table that contains all important data of this object.
---@return table
function NAV_MESH:MarshalToTable()
	local t = {}

	-- Get data table of each vertex and store it in an array. Ignore the key/id, it's stored in each object.
	t.Vertices = {}
	for _, vertex in UTIL.kpairs(self.Vertices) do
		table.insert(t.Vertices, vertex:MarshalToTable())
	end

	-- Get data table of each edge and store it in an array. Ignore the key/id, it's stored in each object.
	t.Edges = {}
	for _, edge in UTIL.kpairs(self.Edges) do
		table.insert(t.Edges, edge:MarshalToTable())
	end

	-- Get data table of each triangle and store it in an array. Ignore the key/id, it's stored in each object.
	t.Triangles = {}
	for _, triangle in UTIL.kpairs(self.Triangles) do
		table.insert(t.Triangles, triangle:MarshalToTable())
	end

	-- Get data table of each air connection and store it in an array. Ignore the key/id, it's stored in each object.
	t.AirConnections = {}
	for _, airConnection in UTIL.kpairs(self.AirConnections) do
		table.insert(t.AirConnections, airConnection:MarshalToTable())
	end

	return t
end

---Returns a unique ID key that has not been used before.
---It can be used for new edges or triangles.
---@return integer
function NAV_MESH:GetUniqueID()
	local idKey = self.UniqueIDCounter

	-- Check if key is already in use, iteratively increase.
	while self.Vertices[idKey] or self.Edges[idKey] or self.Triangles[idKey] or self.AirConnections[idKey] do
		idKey = idKey + 1
		self.UniqueIDCounter = idKey
	end

	return self.UniqueIDCounter
end

---Internal method: Deletes all elements that are not needed anymore.
---Only call GC from the server side and let it sync the result to all clients.
function NAV_MESH:_GC()
	-- Try to GC all free floating edges.
	for _, edge in pairs(self.Edges) do
		edge:_GC()
	end

	-- Try to GC all free floating vertices.
	for _, vertex in pairs(self.Vertices) do
		vertex:_GC()
	end
end

---Returns the nearest triangle/edge corner to the given point p with a radius of r.
---If no point is found, nil will be returned.
---@param p GVector
---@param r number
---@return GVector | nil
function NAV_MESH:GetNearestPoint(p, r)
	-- Stupid linear search for the closest point.
	-- Also, it will go over points several times, as some edges share points.
	local minDistSqr = (r and r * r) or math.huge
	local resultPoint
	for _, vertex in pairs(self.Vertices) do
		local distSqr = p:DistToSqr(vertex:GetPoints())
		if minDistSqr > distSqr then
			minDistSqr = distSqr
			resultPoint = vertex.Point
		end
	end

	return resultPoint
end

---Returns any entity with the given ID, or nil if doesn't exist.
---@param id number | string
---@return D3botNAV_EDGE | D3botNAV_TRIANGLE | nil
function NAV_MESH:FindByID(id)
	return self.Vertices[id] or self.Edges[id] or self.Triangles[id] or self.AirConnections[id] or nil
end

---Returns the vertex with the given ID, or nil if doesn't exist.
---@param id number | string
---@return D3botNAV_VERTEX | nil
function NAV_MESH:FindVertexByID(id)
	return self.Vertices[id]
end

---Will return the vertex that is located at a given point, if there is one.
---@param p GVector
---@return D3botNAV_VERTEX | nil
---@return D3botERROR | nil err
function NAV_MESH:FindVertex1P(p)
	for _, vertex in pairs(self.Vertices) do
		if vertex:ConsistsOfPoint(p) then return vertex, nil end
	end

	return nil, ERROR:New("No vertex found at the given point %s", p)
end

---Will create a new vertex at the given point, or return an already existing vertex.
---@param p GVector
---@return D3botNAV_VERTEX | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateVertex1P(p)
	local vertex, _ = self:FindVertex1P(p)
	if vertex then return vertex, nil end

	-- Create new vertex.
	return NAV_VERTEX:New(self, nil, p)
end

---Returns the edge with the given ID, or nil if doesn't exist.
---@param id number | string
---@return D3botNAV_EDGE | nil
function NAV_MESH:FindEdgeByID(id)
	return self.Edges[id]
end

---Will return the edge that is built with the two given points (vectors), if there is one.
---@param p1 GVector
---@param p2 GVector
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindEdge2P(p1, p2)
	local v1, err = self:FindVertex1P(p1)
	if err then return nil, err end
	local v2, err = self:FindVertex1P(p2)
	if err then return nil, err end

	return self:FindEdge2V(v1, v2)
end

---Will return the edge that is built with the two given vertices, if there is one.
---@param v1 D3botNAV_VERTEX
---@param v2 D3botNAV_VERTEX
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindEdge2V(v1, v2)
	for _, edge in pairs(self.Edges) do
		if edge:ConsistsOfVertices(v1, v2) then return edge, nil end
	end

	return nil, ERROR:New("No edge found with the given vertices %s, %s", v1, v2)
end

---Will create a new edge with the given two points (vectors), or return an already existing edge.
---@param p1 GVector
---@param p2 GVector
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateEdge2P(p1, p2)
	local v1, err = self:FindOrCreateVertex1P(p1)
	if err then return nil, err end
	local v2, err = self:FindOrCreateVertex1P(p2)
	if err then return nil, err end

	return self:FindOrCreateEdge2V(v1, v2)
end

---Will create a new edge with the given two vertices, or return an already existing edge.
---@param v1 D3botNAV_VERTEX
---@param v2 D3botNAV_VERTEX
---@return D3botNAV_EDGE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateEdge2V(v1, v2)
	local edge, _ = self:FindEdge2V(v1, v2)
	if edge then return edge, nil end

	-- Create new edge.
	return NAV_EDGE:New(self, nil, v1, v2)
end

---Returns the triangle with the given ID, or nil if doesn't exist.
---@param id number | string
---@return D3botNAV_TRIANGLE | nil
function NAV_MESH:FindTriangleByID(id)
	return self.Triangles[id]
end

---Will return the triangle that is built with the three given points (vectors), if there is one.
---@param p1 GVector
---@param p2 GVector
---@param p3 GVector
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindTriangle3P(p1, p2, p3)
	local e1, err = self:FindEdge2P(p1, p2)
	if err then return nil, err end
	local e2, err = self:FindEdge2P(p2, p3)
	if err then return nil, err end
	local e3, err = self:FindEdge2P(p3, p1)
	if err then return nil, err end

	local triangle, err = self:FindTriangle3E(e1, e2, e3)
	return triangle, err
end

---Will return the triangle that is built with the three given vertices, if there is one.
---@param v1 D3botNAV_VERTEX
---@param v2 D3botNAV_VERTEX
---@param v3 D3botNAV_VERTEX
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindTriangle3V(v1, v2, v3)
	local e1, err = self:FindEdge2V(v1, v2)
	if err then return nil, err end
	local e2, err = self:FindEdge2V(v2, v3)
	if err then return nil, err end
	local e3, err = self:FindEdge2V(v3, v1)
	if err then return nil, err end

	local triangle, err = self:FindTriangle3E(e1, e2, e3)
	return triangle, err
end

---Will return the triangle that is built with the three given edges, if there is one.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@param e3 D3botNAV_EDGE
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindTriangle3E(e1, e2, e3)
	for _, triangle in pairs(self.Triangles) do
		if triangle:ConsistsOfEdges(e1, e2, e3) then return triangle, nil end
	end

	return nil, ERROR:New("No triangle found with the given edges %s, %s, %s", e1, e2, e3)
end

---Will create a new triangle with the given three points, or return an already existing triangle.
---@param p1 GVector
---@param p2 GVector
---@param p3 GVector
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateTriangle3P(p1, p2, p3)
	local e1, err = self:FindOrCreateEdge2P(p1, p2)
	if err then return nil, err end
	local e2, err = self:FindOrCreateEdge2P(p2, p3)
	if err then return nil, err end
	local e3, err = self:FindOrCreateEdge2P(p3, p1)
	if err then return nil, err end

	local triangle, err = self:FindOrCreateTriangle3E(e1, e2, e3)
	return triangle, err
end

---Will create a new triangle with the given three edges, or return an already existing triangle.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@param e3 D3botNAV_EDGE
---@return D3botNAV_TRIANGLE | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateTriangle3E(e1, e2, e3)
	local triangle = self:FindTriangle3E(e1, e2, e3)
	if triangle then return triangle, nil end

	-- Create new triangle.
	local triangle, err = NAV_TRIANGLE:New(self, nil, e1, e2, e3, nil)
	if err then return nil, err end

	-- Determine FlipNormal state.
	triangle:RecalcFlipNormal()

	return triangle, nil
end

---Returns the air connection with the given ID, or nil if doesn't exist.
---@param id number | string
---@return D3botNAV_AIR_CONNECTION | nil
function NAV_MESH:FindAirConnectionByID(id)
	return self.AirConnections[id]
end

---Will return the air connection that is built with the two given edges, if there is one.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@return D3botNAV_AIR_CONNECTION | nil
---@return D3botERROR | nil err
function NAV_MESH:FindAirConnection2E(e1, e2)
	for _, airConnection in pairs(self.AirConnections) do
		if airConnection:ConsistsOfEdges(e1, e2) then return airConnection, nil end
	end

	return nil, ERROR:New("No air connection found with the given edges %s, %s", e1, e2)
end

---Will create a new air connection with the given two edges, or return an already existing air connection.
---@param e1 D3botNAV_EDGE
---@param e2 D3botNAV_EDGE
---@return D3botNAV_AIR_CONNECTION | nil
---@return D3botERROR | nil err
function NAV_MESH:FindOrCreateAirConnection2E(e1, e2)
	local airConnection = self:FindAirConnection2E(e1, e2)
	if airConnection then return airConnection, nil end

	-- Create new air connection.
	local airConnection, err = NAV_AIR_CONNECTION:New(self, nil, e1, e2)
	return airConnection, err
end

---Set where to publish change events to.
---Use nil to disable publishing.
---Make sure that there is only one navmesh that is linked with a PubSub at a time.
---@param pubSub D3botNAV_PUBSUB
function NAV_MESH:SetPubSub(pubSub)
	if SERVER then
		if self.PubSub then self.PubSub:DeleteNavmeshFromSubs() end
		self.PubSub = pubSub
		if self.PubSub then self.PubSub:SendNavmeshToSubs(self) end
	end
end

---Draw the navmesh into a 3D rendering context.
function NAV_MESH:Render3D()

	-- Draw vertices.
	if CONVARS.NavmeshZCulling:GetBool() then render.SetColorMaterial()	else render.SetColorMaterialIgnoreZ() end
	for _, vertex in pairs(self.Vertices) do
		vertex:Render3D()
	end

	-- Draw edges.
	if CONVARS.NavmeshZCulling:GetBool() then render.SetColorMaterial()	else render.SetColorMaterialIgnoreZ() end
	for _, edge in pairs(self.Edges) do
		edge:Render3D()
	end

	-- Draw triangles.
	if CONVARS.NavmeshZCulling:GetBool() then render.SetColorMaterial()	else render.SetColorMaterialIgnoreZ() end
	for _, triangle in pairs(self.Triangles) do
		triangle:Render3D()
	end

	-- Draw air connections.
	if CONVARS.NavmeshZCulling:GetBool() then render.SetColorMaterial()	else render.SetColorMaterialIgnoreZ() end
	for _, airConnection in pairs(self.AirConnections) do
		airConnection:Render3D()
	end
end
