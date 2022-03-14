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

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local NAV_POLYGON = D3bot.NAV_POLYGON
local NAV_EDIT = D3bot.NavEdit
local NAV_MAIN = D3bot.NavMain
local MAPGEOMETRY = D3bot.MapGeometry

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes
local UI = D3bot.NavSWEP.UI

-- Predefine some local constants for optimization.
local COLOR_POLYGON_HIGHLIGHT_HOVER = Color(255, 0, 0, 127)
local COLOR_POLYGON_HIGHLIGHT_SELECTED = Color(255, 127, 0, 255)
local COLOR_POLYGON_HIGHLIGHT_HOVERSELECTED = Color(255, 127, 0, 255)

-- Edit mode key.
local key = "ContextMenu"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModeContextMenu : D3botNavmesherEditMode
---@field NavEntities table<any, boolean> @Map of selected navmesh entities.
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Entity context menu"

---Set and overwrite current edit mode of the given weapon.
---This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
---@param wep GWeapon
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({
		NavEntities = {},
	}, self)

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

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	local tracedEntity = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons, navmesh.Edges)
	if tracedEntity then
		-- Toggle entity selection state.
		if self.NavEntities[tracedEntity] then
			self.NavEntities[tracedEntity] = nil
		else
			self.NavEntities[tracedEntity] = true
		end

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

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	local tracedEntity = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons, navmesh.Edges)
	if tracedEntity then
		-- Add current entity to selection.
		self.NavEntities[tracedEntity] = true

		local navEntities = {}
		for navEntity in pairs(self.NavEntities) do
			table.insert(navEntities, navEntity)
		end

		-- Create and open context menu.
		local menu = DermaMenu()
		menu:AddOption("Parameters", function()
			local cMenu = vgui.Create(D3bot.VGUIPrefix .. "NavmeshEntityContext")
			cMenu:SetNavEntities(navEntities)
		end)
		menu:AddOption("Delete", function() NAV_EDIT.RemoveByID(LocalPlayer(), tracedEntity:GetID()) end)

		if gui.MouseX() == 0 and gui.MouseY() == 0 then
			-- Mouse is invisible, open context menu in the middle of the screen.
			menu:Open(ScrW() / 2, ScrH() / 2)
		else
			-- Mouse is visible, open context menu at cursor.
			menu:Open() -- BUG: Context menu sometimes doesn't open when the reload menu is open
		end

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
	-- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return end

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context.
	cam.Start3D()
	render.SetColorMaterial()

	-- Highlight selected navmesh entities.
	for entity in pairs(self.NavEntities) do
		entity.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_SELECTED
	end

	-- Highlight current hovered entity.
	local tracedEntity = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons, navmesh.Edges)
	if tracedEntity then
		if tracedEntity.UI.HighlightColor then
			tracedEntity.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_HOVERSELECTED
		else
			tracedEntity.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_HOVER
		end
	end

	-- Draw client side navmesh.
	if navmesh then
		navmesh:Render3D()
	end

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
