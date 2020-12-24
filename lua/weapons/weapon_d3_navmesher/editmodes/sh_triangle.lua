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
local UTIL = D3bot.Util
local NAV_EDIT = D3bot.NavEdit
local NAV_MAIN = D3bot.NavMain
local MAPGEOMETRY = D3bot.MapGeometry
local EDIT_MODES = D3_NAVMESHER_EDIT_MODES

-- Add edit mode to list
EDIT_MODES.TriangleAddRemove = EDIT_MODES.TriangleAddRemove or {}
local THIS_EDIT_MODE = EDIT_MODES.TriangleAddRemove

-- General edit mode info.
THIS_EDIT_MODE.Name = "Create & Remove triangles"

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Set and overwrite current edit mode of the given weapon.
-- This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = {}

	setmetatable(mode, self)
	self.__index = self

	wep.EditMode = mode

	return true
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Left mouse button action.
function THIS_EDIT_MODE:PrimaryAttack(wep)
	if not IsFirstTimePredicted() then return true end
	if not CLIENT then return true end

	-- Get eye trace info
	local trRes = wep.Owner:GetEyeTrace()
	if not trRes.Hit then return false end
	local hitPos = trRes.HitPos

	wep.Weapon:EmitSound("buttons/blip1.wav")

	self.TempPoints = self.TempPoints or {}

	local navmesh = NAV_MAIN:GetNavmesh()
	
	local posGeometry = MAPGEOMETRY:GetNearestPoint(hitPos, 10)
	local posNavmesh = navmesh and navmesh:GetNearestPoint(hitPos, 10)
	local pos = UTIL.GetNearestPoint({posGeometry, posNavmesh}, hitPos) or hitPos
	table.insert(self.TempPoints, pos)

	if #self.TempPoints == 3 then
		-- Edit server side navmesh
		NAV_EDIT.CreateTriangle3P(LocalPlayer(), self.TempPoints[1], self.TempPoints[2], self.TempPoints[3])

		-- Reset build mode and its state
		THIS_EDIT_MODE:AssignToWeapon(wep)
	end

	-- Coroutine for primary actions
	-- It's a bit overkill for just storing a few points, but it's more a proof of concept
	--[[if self.PrimaryCR and coroutine.status(self.PrimaryCR) == "dead" then self.PrimaryCR = nil end
	self.PrimaryCR = self.PrimaryCR or coroutine.create(function()
		print("TestA")

		coroutine.yield()

		print("TestB")
	end)
	coroutine.resume(self.PrimaryCR)--]]

	return true
end

-- Right mouse button action.
function THIS_EDIT_MODE:SecondaryAttack(wep)
	return true
end

-- Reload button action.
function THIS_EDIT_MODE:Reload(wep)
	-- Reset build mode and its state
	THIS_EDIT_MODE:AssignToWeapon(wep)

	return true
end

-- Client side drawing
function THIS_EDIT_MODE:PreDrawViewModel(wep, vm)
	cam.Start3D()

	render.SetColorMaterial()

	-- Draw current points
	if self.TempPoints then
		local oldPoint
		for _, point in ipairs(self.TempPoints) do
			render.DrawSphere(point, 10, 10, 10, Color(255, 255, 255, 31))
			oldPoint = oldPoint
		end
	end

	-- Draw client side navmesh
	local navmesh = NAV_MAIN:GetNavmesh()
	if navmesh then
		navmesh:Render3D()
	end

	-- Draw trace hit with geometry snapping
	local trRes = wep.Owner:GetEyeTrace()
	if trRes.Hit then
		local hitPos = trRes.HitPos
		local posGeometry = MAPGEOMETRY:GetNearestPoint(hitPos, 10)
		local posNavmesh = navmesh and navmesh:GetNearestPoint(hitPos, 10)
		local pos = UTIL.GetNearestPoint({posGeometry, posNavmesh}, hitPos) or hitPos
		render.DrawSphere(posNavmesh or pos, 10, 10, 10, Color(255, 255, 255, 31))
		render.DrawSphere(pos, 1, 10, 10, Color(255, 255, 255, 127))
	end

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context
	cam.IgnoreZ(true)
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
