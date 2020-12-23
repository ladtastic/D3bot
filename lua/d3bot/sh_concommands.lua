local D3bot = D3bot
local CONCOMMAND = D3bot.CONCOMMAND
local CONCOMMANDS = D3bot.ConCommands
local NAV_FILE = D3bot.NavFile

-- Give a player the navmeshing SWEP.
CONCOMMANDS.EditMesh = CONCOMMAND:New("d3bot_editmesh")
function CONCOMMANDS.EditMesh:OnServer(ply, cmd, args, argStr)
	if not ply:IsSuperAdmin() then return end

	ply:Give("weapon_d3_navmesher")
end

-- Save the main navmesh to disk.
CONCOMMANDS.SaveMesh = CONCOMMAND:New("d3bot_savemesh")
function CONCOMMANDS.SaveMesh:OnServer(ply, cmd, args, argStr)
	if not ply:IsSuperAdmin() then return end

	NAV_FILE.SaveMainNavmesh()
end

-- Load the main navmesh from disk.
CONCOMMANDS.LoadMesh = CONCOMMAND:New("d3bot_loadmesh")
function CONCOMMANDS.LoadMesh:OnServer(ply, cmd, args, argStr)
	if not ply:IsSuperAdmin() then return end

	NAV_FILE.LoadMainNavmesh()
end
