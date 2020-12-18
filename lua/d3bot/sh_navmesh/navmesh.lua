AddCSLuaFile()

local D3bot = D3bot
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDGE = D3bot.NAV_EDGE

-- Get new instance of a navmesh container object.
-- This contains edges and triangles of a navmesh and provides methods for location and path finding.
function NAV_MESH:New()
	local obj = {
		Edges = {},
		Triangles = {}
	}

	setmetatable(obj, self)
	self.__this = self
	return obj
end

-- Will return the edge that is built with the two given points, if there is one.
function NAV_MESH:FindEdge(p1, p2)
	for _, edge in ipairs(self.Edges) do
		if edge:ConsistsOfPoints(p1, p2) then return edge end
	end

	return
end

-- Will create a new edge with the given two points, or return an already existing edge.
function NAV_MESH:FindOrCreateEdge(p1, p2)
	local edge = NAV_MESH:FindEdge(p1, p2)
	if edge then return edge end

	return NAV_EDGE:New(p1, p2)
end
