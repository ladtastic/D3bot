-- Copyright (C) 2020-2021 David Vogel
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

AddCSLuaFile()

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local NAV_EDIT = D3bot.NavEdit
local NAV_MAIN = D3bot.NavMain
local NAV_AIR_CONNECTION = D3bot.NAV_AIR_CONNECTION
local MAPGEOMETRY = D3bot.MapGeometry

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes
local UI = D3bot.NavSWEP.UI

local key = "AirConnectionAddRemove"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModeAirConnectionAddRemove
---@field TempEdges D3botNAV_EDGE[]
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Create & remove air connections"

-- Set and overwrite current edit mode of the given weapon.
-- This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({}, self)

	wep.EditMode = mode

	return true
end

------------------------------------------------------
--		Methods
------------------------------------------------------

-- Left mouse button action.
function THIS_EDIT_MODE:PrimaryAttack(wep)
	if not IsFirstTimePredicted() then return true end
	if not CLIENT then return true end

	-- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep.Weapon:EmitSound("buttons/button1.wav")
		return true
	end

	-- Store edges that will be used to create an air connection.
	self.TempEdges = self.TempEdges or {}

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Trace closest edge and add it to temporary list.
	local tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)
	table.insert(self.TempEdges, tracedEdge)

	if #self.TempEdges == 2 then
		-- Edit server side navmesh.
		NAV_EDIT.CreateAirConnection2E(LocalPlayer(), self.TempEdges[1]:GetID(), self.TempEdges[2]:GetID())

		-- Reset build mode and its state.
		THIS_EDIT_MODE:AssignToWeapon(wep)

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		if tracedEdge then
			wep.Weapon:EmitSound("buttons/blip1.wav")
		else
			wep.Weapon:EmitSound("common/wpn_denyselect.wav")
		end
	end

	return true
end

-- Right mouse button action.
function THIS_EDIT_MODE:SecondaryAttack(wep)
	if not IsFirstTimePredicted() then return true end
	if not CLIENT then return true end

	-- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep.Weapon:EmitSound("buttons/button1.wav")
		return true
	end

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	local tracedAirConnection = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.AirConnections)
	if tracedAirConnection then
		-- Remove air connection on the server side.
		NAV_EDIT.RemoveByID(LocalPlayer(), tracedAirConnection:GetID())

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		wep.Weapon:EmitSound("common/wpn_denyselect.wav")
	end

	return true
end

-- Reload button action.
function THIS_EDIT_MODE:Reload(wep)
	-- Reset build mode and its state.
	--THIS_EDIT_MODE:AssignToWeapon(wep)

	return true
end

-- Client side drawing.
function THIS_EDIT_MODE:PreDrawViewModel(wep, vm)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return end

	-- Triangle points that are used to draw a ghost of the current triangle.
	local tempEdges = table.Copy(self.TempEdges or {})

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context.
	cam.Start3D()
	render.SetColorMaterial()

	-- Trace closest edge and add it to temporary list.
	local tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)
	table.insert(tempEdges, tracedEdge)
	-- Highlight navmesh edge.
	if tracedEdge then
		tracedEdge.UI.Highlighted = true
	end

	-- Highlighting of navmesh air connections.
	local airConnection = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.AirConnections)
	-- Set highlighted state of traced element.
	if airConnection then
		airConnection.UI.Highlighted = true
	end

	-- Draw client side navmesh.
	navmesh:Render3D()

	-- Draw ghost of air connection.
	if #tempEdges == 2 then
		cam.IgnoreZ(true)
		render.DrawBeam(tempEdges[1]:GetCentroid(), tempEdges[2]:GetCentroid(), NAV_AIR_CONNECTION.DisplayRadius*2, 0, 1, Color(255, 255, 255, 31))
		cam.IgnoreZ(false)
		render.DrawBeam(tempEdges[1]:GetCentroid(), tempEdges[2]:GetCentroid(), NAV_AIR_CONNECTION.DisplayRadius*2, 0, 1, Color(255, 255, 255, 255))
	elseif #tempEdges == 1 then
		cam.IgnoreZ(true)
		render.DrawBeam(tempEdges[1]:GetCentroid(), trRes.HitPos, NAV_AIR_CONNECTION.DisplayRadius*2, 0, 1, Color(255, 255, 255, 31))
		cam.IgnoreZ(false)
		render.DrawBeam(tempEdges[1]:GetCentroid(), trRes.HitPos, NAV_AIR_CONNECTION.DisplayRadius*2, 0, 1, Color(255, 255, 255, 255))
	end

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context.
	cam.IgnoreZ(true)
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
