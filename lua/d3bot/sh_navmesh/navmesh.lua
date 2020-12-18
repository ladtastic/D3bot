AddCSLuaFile()

local D3bot = D3bot
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDGE = D3bot.NAV_EDGE
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

-- Get new instance of a navmesh container object.
-- This contains edges and triangles of a navmesh and provides methods for location and path finding.
function NAV_MESH:New()
	local obj = {
		Edges = {},
		Triangles = {}
	}

	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- Will return the edge that is built with the two given points, if there is one.
function NAV_MESH:FindEdge2P(p1, p2)
	for _, edge in ipairs(self.Edges) do
		if edge:ConsistsOfPoints(p1, p2) then return edge end
	end

	return
end

-- Will create a new edge with the given two points, or return an already existing edge.
function NAV_MESH:FindOrCreateEdge2P(p1, p2)
	local edge = self:FindEdge(p1, p2)
	if edge then return edge end

	local newEdge = NAV_EDGE:New(p1, p2)
	if not newEdge then return end
	table.insert(self.Edges, newEdge)
	return newEdge
end

-- Will return the triangle that is built with the three given points, if there is one.
function NAV_MESH:FindTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindEdge(p1, p2), self:FindEdge(p2, p3), self:FindEdge(p3, p1)

	return self:FindTriangle3E(e1, e2, e3)
end

-- Will return the triangle that is built with the three given edges, if there is one.
function NAV_MESH:FindTriangle3E(e1, e2, e3)
	for _, triangle in ipairs(self.Triangles) do
		if triangle:ConsistsOfEdges(e1, e2, e3) then return triangle end
	end

	return
end

-- Will create a new triangle with the given three points, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3P(p1, p2, p3)
	local e1, e2, e3 = self:FindOrCreateEdge2P(p1, p2), self:FindOrCreateEdge2P(p2, p3), self:FindOrCreateEdge2P(p3, p1)

	return self:FindOrCreateTriangle3E(e1, e2, e3) -- TODO: When create triangle fails, some of the edges may not be used. Prevent this, or GC them later
end

-- Will create a new triangle with the given three edges, or return an already existing triangle.
function NAV_MESH:FindOrCreateTriangle3E(e1, e2, e3)
	local triangle = self:FindTriangle3E(e1, e2, e3)
	if triangle then return triangle end

	local newTriangle = NAV_TRIANGLE:New(e1, e2, e3)
	if not newTriangle then return end
	table.insert(self.Triangles, newTriangle)
	return newTriangle
end
