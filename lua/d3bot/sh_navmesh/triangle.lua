local D3bot = D3bot
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

-- Get new instance of a triangle object.
-- This represents a triangle that is defined by 3 edges that are connected in a loop.
-- It's possible to get invalid triangles, therefore this needs to be checked.
function NAV_TRIANGLE:New(e1, e2, e3)
	local obj = {
		Edges = {e1, e2, e3}
	}

	-- TODO: Selfcheck

	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- Returns wether the triangle consists out of the three given edges or not.
function NAV_TRIANGLE:ConsistsOfEdges(e1, e2, e3)
	local se1, se2, se3 = self.Edges[1], self.Edges[2], self.Edges[3]
	-- There is probably a nicer way to do this, but it doesn't need to be that fast.
	-- This will cause between 6 to 9 comparison operations, but most of time time just 6.
	-- If the optimizer is doing its job well, it may just be 3 comparisons at best.
	if se1 == e1 and se2 == e2 and se3 == e3 then return true end
	if se1 == e1 and se2 == e3 and se3 == e2 then return true end
	if se1 == e2 and se2 == e1 and se3 == e3 then return true end
	if se1 == e2 and se2 == e3 and se3 == e1 then return true end
	if se1 == e3 and se2 == e1 and se3 == e2 then return true end
	if se1 == e3 and se2 == e2 and se3 == e1 then return true end
	return false
end

-- Draw the edge into a 3D rendering context.
function NAV_TRIANGLE:Render3D()
	local e1, e2, e3 = self.Edges[1], self.Edges[2], self.Edges[3]
	--local p1, p2, p3 = e1.Points[1], e2.Points[1], e3.Points[1]

	-- TODO: Cache triangle points

	--render.DrawQuad(e1, p2)
end
