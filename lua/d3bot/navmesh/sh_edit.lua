-- Copyright (C) 2020-2021 David Vogel
--
-- This file is part of D3bot.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- All navmesh edit functions in here are available on the client and server realm.
-- But regardless from which realm they are called, they will always edit the main navmesh on the server side.
-- Basically client --> server communication.

local D3bot = D3bot
local NAV_MAIN = D3bot.NavMain
local NAV_EDIT = D3bot.NavEdit

------------------------------------------------------
--		CreatePolygonPs
------------------------------------------------------

---Create a polygon in the main navmesh.
---@param ply GPlayer
---@param points GVector[]
function NAV_EDIT.CreatePolygonPs(ply, points)
	if SERVER then
		-- Only he who wields the weapon has the power.
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh.
		local navmesh = NAV_MAIN:ForceNavmesh()

		local _, err = navmesh:FindOrCreatePolygonPs(points)
		if err then ply:ChatPrint(string.format("%s Failed to create polygon: %s", D3bot.PrintPrefix, err)) end

		-- Try to garbage collect entities.
		navmesh:_GC()

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_CreatePolygonPs")
		net.WriteTable(points)
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_CreatePolygonPs")
	net.Receive("D3bot_Nav_Edit_CreatePolygonPs",
		function(len, ply)
			local points = net.ReadTable()
			NAV_EDIT.CreatePolygonPs(ply, points)
		end
	)
end

------------------------------------------------------
--		CreateAirConnection2E
------------------------------------------------------

---Create an air connection in the main navmesh.
---@param ply GPlayer
---@param e1ID number | string
---@param e2ID number | string
function NAV_EDIT.CreateAirConnection2E(ply, e1ID, e2ID)
	if SERVER then
		-- Only he who wields the weapon has the power.
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh.
		local navmesh = NAV_MAIN:ForceNavmesh()

		local e1, e2 = navmesh:FindEdgeByID(e1ID), navmesh:FindEdgeByID(e2ID)
		if not e1 or not e2 then
			ply:ChatPrint(string.format("%s Failed to create air connection: Can't find all needed edges", D3bot.PrintPrefix))
			return
		end

		local _, err = navmesh:FindOrCreateAirConnection2E(e1, e2)
		if err then ply:ChatPrint(string.format("%s Failed to create air connection: %s", D3bot.PrintPrefix, err)) end

		-- Try to garbage collect entities.
		navmesh:_GC()

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_CreateAirConnection2E")
		net.WriteTable({e1ID, e2ID})
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_CreateAirConnection2E")
	net.Receive("D3bot_Nav_Edit_CreateAirConnection2E",
		function(len, ply)
			local e1ID, e2ID = unpack(net.ReadTable())
			NAV_EDIT.CreateAirConnection2E(ply, e1ID, e2ID)
		end
	)
end

------------------------------------------------------
--		RemoveByID
------------------------------------------------------

---Remove element by id.
---@param ply GPlayer
---@param id number | string
function NAV_EDIT.RemoveByID(ply, id)
	if SERVER then
		-- Only he who wields the weapon has the power.
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh.
		local navmesh = NAV_MAIN:ForceNavmesh()

		local entity = navmesh:FindByID(id)
		if entity then
			entity:Delete()
		end
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

------------------------------------------------------
--		FlipNormalByID
------------------------------------------------------

---Flip normal of entity.
---@param ply GPlayer
---@param id number | string
function NAV_EDIT.FlipNormalByID(ply, id)
	if SERVER then
		-- Only he who wields the weapon has the power.
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh.
		local navmesh = NAV_MAIN:ForceNavmesh()

		local polygon = navmesh:FindPolygonByID(id)
		if polygon then
			polygon:FlipNormal()
		end

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_FlipNormalByID")
		net.WriteTable({id})
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_FlipNormalByID")
	net.Receive("D3bot_Nav_Edit_FlipNormalByID",
		function(len, ply)
			local id = unpack(net.ReadTable())
			local state = net.ReadBool()
			NAV_EDIT.FlipNormalByID(ply, id, state)
		end
	)
end

------------------------------------------------------
--		RecalcFlipNormalByID
------------------------------------------------------

---Recalculate normal of entity.
---@param ply GPlayer
---@param id number | string
function NAV_EDIT.RecalcFlipNormalByID(ply, id)
	if SERVER then
		-- Only he who wields the weapon has the power.
		if not ply:HasWeapon("weapon_d3_navmesher") then return end
		-- Get or create navmesh.
		local navmesh = NAV_MAIN:ForceNavmesh()

		local polygon = navmesh:FindPolygonByID(id)
		if polygon then
			polygon:RecalcFlipNormal()
		end

	elseif CLIENT then
		net.Start("D3bot_Nav_Edit_RecalcFlipNormalByID")
		net.WriteTable({id})
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString("D3bot_Nav_Edit_RecalcFlipNormalByID")
	net.Receive("D3bot_Nav_Edit_RecalcFlipNormalByID",
		function(len, ply)
			local id = unpack(net.ReadTable())
			NAV_EDIT.RecalcFlipNormalByID(ply, id)
		end
	)
end
