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
local COLOR_SPLIT_GHOST = Color(0, 0, 0, 127)
local COLOR_SPLIT_GHOST_SNAPPED = Color(0, 0, 0, 255)
local COLOR_SPLIT_CURSOR_A = Color(255, 255, 255, 255)
local COLOR_SPLIT_CURSOR_B = Color(0, 0, 0, 255)
local COLOR_SPLIT_CURSOR_A_TRANSPARENT = Color(255, 255, 255, 31)
local COLOR_SPLIT_CURSOR_B_TRANSPARENT = Color(0, 0, 0, 31)

-- Edit mode key.
local key = "PolygonMergeSplit"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModePolygonMergeSplit : D3botNavmesherEditMode
---@field TempVertices D3botNAV_VERTEX[] @List of vertices that will be used to split polygons.
---@field Polygons table<D3botNAV_POLYGON, boolean> @Map of selected polygons to be merged.
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Merge & Split polygons"

---Set and overwrite current edit mode of the given weapon.
---This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
---@param wep GWeapon
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({
		TempVertices = {},
		Polygons = {},
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

	local tracedPolygon = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons)
	if tracedPolygon then
		-- Toggle polygon selection state.
		if self.Polygons[tracedPolygon] then
			self.Polygons[tracedPolygon] = nil
		else
			self.Polygons[tracedPolygon] = true
		end

		-- Table of polygon edges mapping to the count of selected polygons they are connected with.
		local edgesMap, polygonCount = {}, 0
		for polygon in pairs(self.Polygons) do
			polygonCount = polygonCount + 1
			for _, edge in ipairs(polygon.Edges) do
				edgesMap[edge] = (edgesMap[edge] or 0) + 1
			end
		end

		if polygonCount < 2 then
			--LocalPlayer():ChatPrint(string.format("Too few selected polygons. Want at least %d, got %d", 2, polygonCount))
			wep:EmitSound("buttons/blip1.wav")
			return
		end

		-- Filter out any edges that are shared between polygons.
		local edges = {}
		for edge, polygonCount in pairs(edgesMap) do
			if polygonCount == 1 then
				table.insert(edges, edge)
			end
		end

		-- Sort list of edges, generate sorted list of vertices and check for any errors.
		local sortedEdges, sortedVertices, err = UTIL.EdgeChainLoop(edges, false)
		if err then
			LocalPlayer():ChatPrint(string.format("Can't create edge chain from selected polygons: %s.", err))
			wep:EmitSound("common/wpn_denyselect.wav")
			return
		end

		-- Get list of points from vertices.
		local points = {}
		for _, vertex in ipairs(sortedVertices) do
			table.insert(points, vertex:GetPoint())
		end

		-- Check if vertices/points form a valid polygon.
		local err = NAV_POLYGON:VerifyVertices(points)
		if err then
			LocalPlayer():ChatPrint(string.format("Merged polygons don't form a valid polygon: %s.", err))
			wep:EmitSound("common/wpn_denyselect.wav")
			return
		end

		-- Delete all selected polygons from the server side.
		for polygon in pairs(self.Polygons) do
			NAV_EDIT.RemoveByID(LocalPlayer(), polygon:GetID())
		end

		-- Create new merged polygon on the server side.
		NAV_EDIT.CreatePolygonPs(LocalPlayer(), points)

		-- Clear polygon selection.
		self.Polygons = {} -- TODO: Figure out a way to add the newly created polygon (on the server side) to the merge selection

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

	--- If there is no navmesh, stop.
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then
		wep:EmitSound("buttons/button1.wav")
		return
	end

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Get closest vertex in search radius.
	local newVertex = navmesh:GetClosestVertex(trRes.HitPos, 50)
	if not newVertex then
		wep:EmitSound("common/wpn_denyselect.wav")
		return
	end

	table.insert(self.TempVertices, newVertex)

	if #self.TempVertices == 2 then

		local found
		for _, polygon in pairs(navmesh.Polygons) do
			if polygon:ContainsVertices(self.TempVertices) then

				-- Split vertices of the polygon into two lists.
				local splitIndexA, splitIndexB
				for i, vertex in ipairs(polygon.Vertices) do
					if vertex == self.TempVertices[1] then splitIndexA = i end
					if vertex == self.TempVertices[2] then splitIndexB = i end
				end
				if splitIndexA > splitIndexB then splitIndexA, splitIndexB = splitIndexB, splitIndexA end
				if splitIndexA and splitIndexB and splitIndexA ~= splitIndexB then
					local pointsA, pointsB = {}, {}
					for i, vertex in ipairs(polygon.Vertices) do
						if i <= splitIndexA or i >= splitIndexB then table.insert(pointsA, vertex:GetPoint()) end
						if i >= splitIndexA and i <= splitIndexB then table.insert(pointsB, vertex:GetPoint()) end
					end

					if #pointsA >= 3 and #pointsB >= 3 then
						-- Remove old polygon on the server side.
						NAV_EDIT.RemoveByID(LocalPlayer(), polygon:GetID())

						-- Create polygons on the server side.
						NAV_EDIT.CreatePolygonPs(LocalPlayer(), pointsA)
						NAV_EDIT.CreatePolygonPs(LocalPlayer(), pointsB)
					else
						LocalPlayer():ChatPrint(string.format("Can't split polygon at an edge or corner."))
					end
				else
					LocalPlayer():ChatPrint(string.format("Invalid selection of vertices."))
				end

				found = true
				break
			end
		end

		if not found then
			LocalPlayer():ChatPrint(string.format("There is no triangle that can be split by the two given vertices."))
		end

		wep:ResetEditMode()

		wep:EmitSound("buttons/blip2.wav")
	else
		wep:EmitSound("buttons/blip1.wav")
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

	-- Copy of temporary vertices used to split polygons.
	local tempVertices = {unpack(self.TempVertices)}

	-- Get world trace result and navmesh tracing ray.
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context.
	cam.Start3D()
	render.SetColorMaterial()

	-- Get closest vertex in search radius.
	local newVertex = navmesh:GetClosestVertex(trRes.HitPos, 50)

	-- Add vertex to temp list so a ghost is drawn. Otherwise store hit of current trace to draw a ghost with.
	local newPos
	if newVertex then
		table.insert(tempVertices, newVertex)
	else
		newPos = trRes.HitPos
	end

	-- Highlighting of selected navmesh polygons.
	if navmesh then
		for polygon in pairs(self.Polygons) do
			polygon.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_SELECTED
		end
	end

	-- Highlight current hovered polygon.
	local tracedPolygon = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Polygons)
	if tracedPolygon then
		if tracedPolygon.UI.HighlightColor then
			tracedPolygon.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_HOVERSELECTED
		else
			tracedPolygon.UI.HighlightColor = COLOR_POLYGON_HIGHLIGHT_HOVER
		end
	end

	-- Draw client side navmesh.
	if navmesh then
		navmesh:Render3D()
	end

	for _, tempVertex in ipairs(tempVertices) do
		local pos = tempVertex:GetPoint()
		render.SetColorMaterialIgnoreZ()
		RENDER_UTIL.Draw3DCursorPos(pos, 2, COLOR_SPLIT_CURSOR_A_TRANSPARENT, COLOR_SPLIT_CURSOR_B_TRANSPARENT)
		render.SetColorMaterial()
		RENDER_UTIL.Draw3DCursorPos(pos, 2, COLOR_SPLIT_CURSOR_A, COLOR_SPLIT_CURSOR_B)
	end

	if #tempVertices >= 2 then
		render.DrawLine(tempVertices[1]:GetPoint(), tempVertices[2]:GetPoint(), COLOR_SPLIT_GHOST_SNAPPED, false)
	elseif newPos and #tempVertices == 1 then
		render.DrawLine(tempVertices[1]:GetPoint(), newPos, COLOR_SPLIT_GHOST, false)
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
