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
local MAPGEOMETRY = D3bot.MapGeometry

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes
local UI = D3bot.NavSWEP.UI

local key = "FlipNormal"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModeFlipNormal : D3botNavmesherEditMode
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Recalc & flip triangle normals"

---Set and overwrite current edit mode of the given weapon.
---This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
---@param wep GWeapon
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({}, self)

	wep.EditMode = mode
end

------------------------------------------------------
--		Methods
------------------------------------------------------

---Called when primary attack button ( +attack ) is pressed.
---Predicted, therefore it's not called by the client in single player.
---Shared.
---@param wep GWeapon
function THIS_EDIT_MODE:PrimaryAttack(wep)
	if not IsFirstTimePredicted() then return end
	if not CLIENT then return end

	-- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep:EmitSound("buttons/button1.wav")
		return
	end

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Trace triangle.
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	if tracedTriangle then
		-- Edit server side navmesh.
		NAV_EDIT.RecalcFlipNormalByID(LocalPlayer(), tracedTriangle:GetID())

		wep:EmitSound("buttons/blip2.wav")
	else
		wep:EmitSound("common/wpn_denyselect.wav")
	end
end

---Called when secondary attack button ( +attack2 ) is pressed.
---For issues with this hook being called rapidly on the client side, see the global function IsFirstTimePredicted.
---Predicted, therefore it's not called by the client in single player.
---Shared.
---@param wep GWeapon
function THIS_EDIT_MODE:SecondaryAttack(wep)
	if not IsFirstTimePredicted() then return end
	if not CLIENT then return end

	-- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep:EmitSound("buttons/button1.wav")
		return
	end

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Trace triangle.
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	if tracedTriangle then
		-- Edit server side navmesh.
		NAV_EDIT.SetFlipNormalByID(LocalPlayer(), tracedTriangle:GetID(), not tracedTriangle.FlipNormal)

		wep:EmitSound("buttons/blip2.wav")
	else
		wep:EmitSound("common/wpn_denyselect.wav")
	end
end

---Called when the reload key ( +reload ) is pressed.
---Predicted, therefore it's not called by the client in single player.
---Shared.
---@param wep GWeapon
--function THIS_EDIT_MODE:Reload(wep)
--end

---Allows you to modify viewmodel while the weapon in use before it is drawn. This hook only works if you haven't overridden GM:PreDrawViewModel.
---Client realm.
---@param wep GWeapon
---@param vm GEntity
---@param weapon GWeapon @Can be nil in some gamemodes.
---@param ply GPlayer @Can be nil in some gamemodes.
function THIS_EDIT_MODE:PreDrawViewModel(wep, vm, weapon, ply)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return end

	-- Get map line trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Highlighting of navmesh triangles.
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	-- Set highlighted state of traced element.
	if tracedTriangle then
		tracedTriangle.UI.Highlighted = true
	end

	-- Setup rendering context.
	cam.Start3D()

	-- Draw client side navmesh.
	navmesh:Render3D()

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context.
	cam.IgnoreZ(true)
end

---This hook allows you to draw on screen while this weapon is in use.
---If you want to draw a custom crosshair, consider using WEAPON:DoDrawCrosshair instead.
---Client realm.
---@param wep GWeapon
--function THIS_EDIT_MODE:DrawHUD(wep)
--end
