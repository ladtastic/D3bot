-- Copyright (C) 2020 David Vogel
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
