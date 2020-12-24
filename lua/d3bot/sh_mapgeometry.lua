local D3bot = D3bot
local UTIL = D3bot.Util
local MAPGEOMETRY = D3bot.MapGeometry

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
