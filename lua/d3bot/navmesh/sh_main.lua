-- Container for the main navmesh instance.
-- On the server realm this will be used for navigation, and on the client realm this will be used for displaying/editing.

local D3bot = D3bot
local NAV_MAIN = D3bot.NavMain
local NAV_MESH = D3bot.NAV_MESH
local NAV_PUBSUB = D3bot.NavPubSub

-- Get the current navmesh, or nil if there is none.
function NAV_MAIN:GetNavmesh()
	return self.Navmesh
end

-- Get the current navmesh, or create a new one.
function NAV_MAIN:ForceNavmesh()
	if self.Navmesh then return self.Navmesh end

	-- Create new navmesh and link PubSub
	self.Navmesh = NAV_MESH:New()
	if SERVER then self.Navmesh:SetPubSub(NAV_PUBSUB) end

	return self.Navmesh
end

-- Will overwrite the current main navmesh with the given one.
function NAV_MAIN:SetNavmesh(navmesh)
	if self.Navmesh then self.Navmesh:SetPubSub(nil) end

	self.Navmesh = navmesh
	if SERVER and self.Navmesh then self.Navmesh:SetPubSub(NAV_PUBSUB) end
end
