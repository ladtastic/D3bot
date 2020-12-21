local D3bot = D3bot
local UTIL = D3bot.Util
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDGE = D3bot.NAV_EDGE
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Get new instance of a navmesh container object.
-- This contains edges and triangles of a navmesh and provides methods for locating and path finding.
function NAV_MESH:New()
	local obj = {
		Edges = {},
		Triangles = {},
		UniqueIDCounter = 1 -- TODO: Always start with the highest key that can be found
	}

	setmetatable(obj, self)
	self.__index = self

	return obj
end

-- Same as NAV_MESH:New(), but uses table t to restore a previous state that came from MarshalToTable().
function NAV_MESH:NewFromTable(t)
	local obj = self:New()

	-- Restore edges
	for _, edgeTable in ipairs(t.Edges) do
		NAV_EDGE:NewFromTable(obj, edgeTable)
	end

	-- Restore triangles
	for _, triangleTable in ipairs(t.Triangles) do
		NAV_TRIANGLE:NewFromTable(obj, triangleTable)
	end

	return obj
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Returns a table that contains all important data of this object.
function NAV_MESH:MarshalToTable()
	local t = {}

	-- Get data table of each edge and store it in an array. Ignore the key/id, it's stored in each object.
	t.Edges = {}
	for k, edge in UTIL.kpairs(self.Edges) do
		table.insert(t.Edges, edge:MarshalToTable())
	end

	-- Get data table of each triangle and store it in an array. Ignore the key/id, it's stored in each object.
	t.Triangles = {}
	for k, triangle in UTIL.kpairs(self.Triangles) do
		table.insert(t.Triangles, triangle:MarshalToTable())
	end

	return t
end

-- Returns a unique ID key that has not been used before.
-- It can be used for new edges or triangles.
function NAV_MESH:GetUniqueID()
	-- Check if key is already in use, iteratively increase
	local idKey = self.UniqueIDCounter
	while self.Edges[idKey] or self.Triangles[idKey] do
		self.UniqueIDCounter = self.UniqueIDCounter + 1
		idKey = self.UniqueIDCounter
	end

	return idKey
end

-- Returns the edge with the given ID, or nil if doesn't exist.
function NAV_MESH:FindEdgeByID(id)
	return self.Edges[id]
end

-- Will return the edge that is built with the two given points, if there is one.
function NAV_MESH:FindEdge2P(p1, p2)
	for _, edge in pairs(self.Edges) do
		if edge:ConsistsOfPoints(p1, p2) then return edge end
	end

	return
end

-- Will create a new edge with the given two points, or return an already existing edge.
function NAV_MESH:FindOrCreateEdge2P(p1, p2)
	local edge = self:FindEdge2P(p1, p2)
	if edge then return edge end

	-- Create new edge
	return NAV_EDGE:New(self, nil, p1, p2)
end

-- Will return the triangle that is built with the three given points, if there is one.
function NAV_MESH:FindTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindEdge2P(p1, p2), self:FindEdge2P(p2, p3), self:FindEdge2P(p3, p1)

	return self:FindTriangle3E(e1, e2, e3)
end

-- Will return the triangle that is built with the three given edges, if there is one.
function NAV_MESH:FindTriangle3E(e1, e2, e3)
	for _, triangle in pairs(self.Triangles) do
		if triangle:ConsistsOfEdges(e1, e2, e3) then return triangle end
	end

	return
end

-- Will create a new triangle with the given three points, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindOrCreateEdge2P(p1, p2), self:FindOrCreateEdge2P(p2, p3), self:FindOrCreateEdge2P(p3, p1)

	local triangle = self:FindOrCreateTriangle3E(e1, e2, e3)

	-- If it failed to create a triangle, then garbage collect any "free floating" edge
	if not triangle then
		e1:GC()
		e2:GC()
		e3:GC()
	end

	return triangle
end

-- Will create a new triangle with the given three edges, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3E(e1, e2, e3)
	local triangle = self:FindTriangle3E(e1, e2, e3)
	if triangle then return triangle end

	-- Create new triangle
	return NAV_TRIANGLE:New(self, nil, e1, e2, e3)
end

-- Draw the navmesh into a 3D rendering context.
function NAV_MESH:Render3D()
	-- Draw edges
	for _, edge in pairs(self.Edges) do
		edge:Render3D()
	end

	-- Draw triangles
	for _, triangle in pairs(self.Triangles) do
		triangle:Render3D()
	end
end
