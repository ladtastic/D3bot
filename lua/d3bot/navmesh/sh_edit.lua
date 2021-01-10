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

-- All navmesh edit functions in here are available on the client and server realm.
-- But regardless from which realm they are called, they will always edit the main navmesh on the server side.
-- Basically client --> server communication.

local D3bot = D3bot
local NAV_MAIN = D3bot.NavMain
local NAV_EDIT = D3bot.NavEdit

------------------------------------------------------
--				CreateTriangle3P					--
------------------------------------------------------

-- Create a triangle in the main navmesh.
function NAV_EDIT.CreateTriangle3P(ply, p1, p2, p3)
	if SERVER then
		-- Only he who wields the weapon has the power
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh
		local navmesh = NAV_MAIN:ForceNavmesh()

		local _, err = navmesh:FindOrCreateTriangle3P(p1, p2, p3)
		if err then ply:ChatPrint(string.format("%s Failed to create triangle: %s", D3bot.PrintPrefix, err)) end

		-- Try to garbage collect entities
		navmesh:_GC()

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

-- Remove element by id.
function NAV_EDIT.RemoveByID(ply, id)
	if SERVER then
		-- Only he who wields the weapon has the power
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh
		local navmesh = NAV_MAIN:ForceNavmesh()

		local entity = navmesh:FindByID(id)
		entity:Delete()
		navmesh:_GC()

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_RemoveByID")
		net.WriteTable({id})
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_RemoveByID")
	net.Receive("D3bot_Nav_Edit_RemoveByID",
		function(len, ply)
			local id = unpack(net.ReadTable())
			NAV_EDIT.RemoveByID(ply, id)
		end
	)
end