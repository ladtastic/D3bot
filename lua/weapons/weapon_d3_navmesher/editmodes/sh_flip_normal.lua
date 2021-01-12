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

AddCSLuaFile()

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local NAV_EDIT = D3bot.NavEdit
local NAV_MAIN = D3bot.NavMain
local MAPGEOMETRY = D3bot.MapGeometry

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = NAV_SWEP.EditModes
local UI = NAV_SWEP.UI

-- Add edit mode to list
EDIT_MODES.FlipNormal = EDIT_MODES.FlipNormal or {}
local THIS_EDIT_MODE = EDIT_MODES.FlipNormal

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- General edit mode info.
THIS_EDIT_MODE.Name = "Recalc & Flip triangle normals"

-- Set and overwrite current edit mode of the given weapon.
-- This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = {}

	-- Instantiate
	setmetatable(mode, self)

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

	-- If there is no navmesh, stop
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep.Weapon:EmitSound("buttons/button1.wav")
		return true
	end

	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Trace triangle
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	if tracedTriangle then
		-- Edit server side navmesh
		NAV_EDIT.RecalcFlipNormalByID(LocalPlayer(), tracedTriangle:GetID())

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		wep.Weapon:EmitSound("common/wpn_denyselect.wav")
	end

	return true
end

-- Right mouse button action.
function THIS_EDIT_MODE:SecondaryAttack(wep)
	if not IsFirstTimePredicted() then return true end
	if not CLIENT then return true end

	-- If there is no navmesh, stop
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep.Weapon:EmitSound("buttons/button1.wav")
		return true
	end

	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Trace triangle
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	if tracedTriangle then
		-- Edit server side navmesh
		NAV_EDIT.SetFlipNormalByID(LocalPlayer(), tracedTriangle:GetID(), not tracedTriangle.FlipNormal)

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		wep.Weapon:EmitSound("common/wpn_denyselect.wav")
	end

	return true
end

-- Reload button action.
function THIS_EDIT_MODE:Reload(wep)
	return true
end

-- Client side drawing
function THIS_EDIT_MODE:PreDrawViewModel(wep, vm)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return end

	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Highlighting of navmesh triangles
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	-- Set highlighted state of traced element
	if tracedTriangle then
		tracedTriangle.UI.Highlighted = true
	end

	-- Setup rendering context
	cam.Start3D()

	-- Draw client side navmesh
	navmesh:Render3D()

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context
	cam.IgnoreZ(true)
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
