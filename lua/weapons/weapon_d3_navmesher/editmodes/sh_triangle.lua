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

local key = "TriangleAddRemove"

-- Add edit mode to list
EDIT_MODES[key] = EDIT_MODES[key] or {}
local THIS_EDIT_MODE = EDIT_MODES[key]

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Create & remove triangles"

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

	-- Store points that are used to create triangles
	self.TempPoints = self.TempPoints or {}

	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- An edge entity that the player points on
	local tracedEdge

	-- Get 3D cursor that snaps to either map geometry or navmesh points
	local snapToMap = CONVARS.SWEPSnapToMapGeometry:GetBool()
	local snapToNav = CONVARS.SWEPSnapToNavmeshGeometry:GetBool()
	local snappedPos, snapped = UTIL.GetSnappedPosition(snapToNav and navmesh or nil, snapToMap and MAPGEOMETRY or nil, trRes.HitPos, 10)

	-- Check if any edge can be selected, if so add the two edge points to the temp points list.
	if not snapped and (3 - #self.TempPoints) >= 2 then
		-- Trace closest edge
		tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)

		if tracedEdge then
			table.insert(self.TempPoints, tracedEdge.Points[1])
			table.insert(self.TempPoints, tracedEdge.Points[2])
		end
	end

	-- If there is no traced edge, and there are still more points needed, get one
	if not tracedEdge and trRes.Hit and (3 - #self.TempPoints) >= 1 then
		table.insert(self.TempPoints, snappedPos)
	end

	if #self.TempPoints == 3 then
		-- Edit server side navmesh
		NAV_EDIT.CreateTriangle3P(LocalPlayer(), self.TempPoints[1], self.TempPoints[2], self.TempPoints[3])

		-- Reset build mode and its state
		THIS_EDIT_MODE:AssignToWeapon(wep)

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		wep.Weapon:EmitSound("buttons/blip1.wav")
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

	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	-- Set highlighted state of traced element
	if tracedTriangle then
		-- Edit server side navmesh
		NAV_EDIT.RemoveByID(LocalPlayer(), tracedTriangle:GetID())

		wep.Weapon:EmitSound("buttons/blip2.wav")
	else
		wep.Weapon:EmitSound("common/wpn_denyselect.wav")
	end

	return true
end

-- Reload button action.
function THIS_EDIT_MODE:Reload(wep)
	-- Reset build mode and its state
	--THIS_EDIT_MODE:AssignToWeapon(wep)

	return true
end

-- Client side drawing
function THIS_EDIT_MODE:PreDrawViewModel(wep, vm)
	local navmesh = NAV_MAIN:GetNavmesh()
	if not navmesh then return end

	-- Triangle points that are used to draw a ghost of the current triangle
	local trianglePoints = table.Copy(self.TempPoints or {})
	
	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context
	cam.Start3D()
	render.SetColorMaterial()

	-- An edge entity that the player points on
	local tracedEdge

	-- Get 3D cursor pos that snaps to either map geometry or navmesh points
	local snapToMap = CONVARS.SWEPSnapToMapGeometry:GetBool()
	local snapToNav = CONVARS.SWEPSnapToNavmeshGeometry:GetBool()
	local snappedPos, snapped = UTIL.GetSnappedPosition(snapToNav and navmesh or nil, snapToMap and MAPGEOMETRY or nil, trRes.HitPos, 10)

	-- Highlighting of navmesh edges.
	-- Check if any edge can be selected (based on the temp points needed), if so highlight it.
	if not snapped and (3 - #trianglePoints) >= 2 then
		-- Trace closest edge
		tracedEdge = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Edges)

		-- Set highlighted state of traced element
		if tracedEdge then
			tracedEdge.UI.Highlighted = true
			table.insert(trianglePoints, tracedEdge.Points[1])
			table.insert(trianglePoints, tracedEdge.Points[2])
		end
	end

	-- Draw 3D cursor with geometry snapping
	if not tracedEdge and trRes.Hit and (3 - #trianglePoints) >= 1 then
		table.insert(trianglePoints, snappedPos)
		RENDER_UTIL.Draw3DCursorPos(snappedPos, Color(255, 255, 255, 255), Color(0, 0, 0, 255))
		--render.DrawSphere(snappedPos, 10, 10, 10, Color(255, 255, 255, 31))
		--render.DrawSphere(snappedPos, 1, 10, 10, Color(255, 255, 255, 127))
	end

	-- Highlighting of navmesh triangles
	local tracedTriangle = UTIL.GetClosestIntersectingWithRay(aimOrigin, aimVec, navmesh.Triangles)
	-- Set highlighted state of traced element
	if tracedTriangle then
		tracedTriangle.UI.Highlighted = true
	end

	-- Draw client side navmesh
	navmesh:Render3D()

	-- Draw ghost of triangle
	for _, point in ipairs(trianglePoints) do
		render.SetColorMaterialIgnoreZ()
		RENDER_UTIL.Draw3DCursorPos(point, 2, Color(255, 255, 255, 31), Color(0, 0, 0, 31))
		render.SetColorMaterial()
		RENDER_UTIL.Draw3DCursorPos(point, 2, Color(255, 255, 255, 255), Color(0, 0, 0, 255))
		--render.DrawSphere(point, 10, 10, 10, Color(255, 255, 255, 31))
	end
	if #trianglePoints == 3 then
		local p1, p2, p3 = trianglePoints[1], trianglePoints[2], trianglePoints[3]
		render.SetColorMaterial()
		render.DrawQuad(p1, p2, p3, p2, Color(255, 255, 255, 31))
		render.DrawLine(p1, p2, Color(255, 255, 255, 255), false)
		render.DrawLine(p2, p3, Color(255, 255, 255, 255), false)
		render.DrawLine(p3, p1, Color(255, 255, 255, 255), false)
	end

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context
	cam.IgnoreZ(true)
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
