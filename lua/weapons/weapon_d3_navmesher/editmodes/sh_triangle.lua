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
local NAV_EDIT = D3bot.NavEdit
local NAV_MAIN = D3bot.NavMain
local MAPGEOMETRY = D3bot.MapGeometry

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes
local UI = D3bot.NavSWEP.UI

-- Predefine some local constants for optimization.
local COLOR_POLYGON_HIGHLIGHT_HOVER = Color(255, 0, 0, 127)
local COLOR_EDGE_HIGHLIGHT_HOVER = Color(255, 255, 255, 127)

-- Edit mode key.
local key = "TriangleAddRemove"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModeTriangleAddRemove : D3botNavmesherEditMode
---@field TempPoints GVector[] @List of points that will be used to create triangles.
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Create & remove triangles"

---Set and overwrite current edit mode of the given weapon.
---This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
---@param wep GWeapon
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({
		TempPoints = {},
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

	-- Get navmesh, but it's also fine if there is none.
	-- In this case the navmesh will be created when the first polygon gets created.
	local navmesh = NAV_MAIN:GetNavmesh()

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- An edge entity that the player points on.
	local tracedEdge

	-- Get 3D cursor that snaps to either map geometry or navmesh points.
	local snapToMap = CONVARS.SWEPSnapToMapGeometry:GetBool()
	local snapToNav = CONVARS.SWEPSnapToNavmeshGeometry:GetBool()
	local snappedPos, snapped = UTIL.GetSnappedPosition(snapToNav and navmesh or nil, snapToMap and MAPGEOMETRY or nil, trRes.HitPos, 10)

	-- Check if any edge can be selected, if so add the two edge points to the temp points list.
	if navmesh and not snapped and (3 - #self.TempPoints) >= 2 then
		-- Trace closest edge.
		tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)

		if tracedEdge then
			local eP1, eP2 = unpack(tracedEdge:GetPoints())
			table.insert(self.TempPoints, eP1)
			table.insert(self.TempPoints, eP2)
		end
	end

	-- If there is no traced edge, and there are still more points needed, get one.
	if not tracedEdge and trRes.Hit and (3 - #self.TempPoints) >= 1 then
		table.insert(self.TempPoints, snappedPos)
	end

	if #self.TempPoints == 3 then
		-- Edit server side navmesh.
		NAV_EDIT.CreatePolygonPs(LocalPlayer(), self.TempPoints)

		-- Reset edit mode and its state.
		wep:ResetEditMode()

		wep:EmitSound("buttons/blip2.wav")
	else
		wep:EmitSound("buttons/blip1.wav")
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

	local tracedPolygon = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons)
	if tracedPolygon then
		-- Remove polygon on the server side.
		NAV_EDIT.RemoveByID(LocalPlayer(), tracedPolygon:GetID())

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
	-- Get navmesh, but it's also fine if there is none.
	-- In this case the navmesh will be created when the first polygon gets created.
	local navmesh = NAV_MAIN:GetNavmesh()

	-- Polygon points that are used to draw a ghost of the current polygon.
	local polygonPoints = {unpack(self.TempPoints)}

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context.
	cam.Start3D()
	render.SetColorMaterial()

	-- An edge entity that the player points on.
	local tracedEdge

	-- Get 3D cursor pos that snaps to either map geometry or navmesh points.
	local snapToMap = CONVARS.SWEPSnapToMapGeometry:GetBool()
	local snapToNav = CONVARS.SWEPSnapToNavmeshGeometry:GetBool()
	local snappedPos, snapped = UTIL.GetSnappedPosition(snapToNav and navmesh or nil, snapToMap and MAPGEOMETRY or nil, trRes.HitPos, 10)

	-- Highlighting of navmesh edges.
	-- Check if any edge can be selected (based on the temp points needed), if so highlight it.
	if navmesh and not snapped and (3 - #polygonPoints) >= 2 then
		-- Trace closest edge.
		tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)

		-- Highlight edge with specific color.
		if tracedEdge then
			tracedEdge.UI.HighlightColor = COLOR_EDGE_HIGHLIGHT_HOVER
			local eP1, eP2 = unpack(tracedEdge:GetPoints())
			table.insert(polygonPoints, eP1)
			table.insert(polygonPoints, eP2)
		end
	end

	-- Add point to temp polygon points, so it draws the 3D cursors and the ghost of the polygon if possible.
	if not tracedEdge and trRes.Hit and (3 - #polygonPoints) >= 1 then
		table.insert(polygonPoints, snappedPos)
	end

	-- Highlighting of navmesh polygons.
	if navmesh then
		local tracedPolygon = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons)
		-- Highlight polygon with specific color.
		if tracedPolygon then
			tracedPolygon.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_HOVER
		end
	end

	-- Draw client side navmesh.
	if navmesh then
		navmesh:Render3D()
	end

	-- Draw ghost of polygon.
	for _, point in ipairs(polygonPoints) do
		render.SetColorMaterialIgnoreZ()
		RENDER_UTIL.Draw3DCursorPos(point, 2, Color(255, 255, 255, 31), Color(0, 0, 0, 31))
		render.SetColorMaterial()
		RENDER_UTIL.Draw3DCursorPos(point, 2, Color(255, 255, 255, 255), Color(0, 0, 0, 255))
		--render.DrawSphere(point, 10, 10, 10, Color(255, 255, 255, 31))
	end
	if #polygonPoints == 3 then
		local p1, p2, p3 = polygonPoints[1], polygonPoints[2], polygonPoints[3]
		render.SetColorMaterial()
		render.DrawQuad(p1, p2, p3, p2, Color(255, 255, 255, 31))
		render.DrawLine(p1, p2, Color(255, 255, 255, 255), false)
		render.DrawLine(p2, p3, Color(255, 255, 255, 255), false)
		render.DrawLine(p3, p1, Color(255, 255, 255, 255), false)
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
