local D3bot = D3bot
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDIT = D3bot.NavEdit

------------------------------------------------------
--				CreateTriangle3P					--
------------------------------------------------------

-- Create a triangle in the main navmesh.
function NAV_EDIT.CreateTriangle3P(ply, p1, p2, p3)
	if SERVER then
		if not ply:HasWeapon("weapon_d3_navmesher") then
			return
		end
		D3bot.Navmesh = D3bot.Navmesh or NAV_MESH:New()

		D3bot.Navmesh:FindOrCreateTriangle3P(p1, p2, p3)

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_CreateTriangle3P")
		net.WriteVector(p1)
		net.WriteVector(p2)
		net.WriteVector(p3)
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_CreateTriangle3P")
	net.Receive("D3bot_Nav_Edit_CreateTriangle3P",
		function(len, ply)
			local p1, p2, p3 = net.ReadVector(), net.ReadVector(), net.ReadVector()
			NAV_EDIT.CreateTriangle3P(ply, p1, p2, p3)
		end
	)
end
