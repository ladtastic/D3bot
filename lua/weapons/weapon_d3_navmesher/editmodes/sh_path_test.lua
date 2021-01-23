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

-- TODO: Put this path testing tool into its own SWEP

AddCSLuaFile()

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local RENDER_UTIL = D3bot.RenderUtil
local NAV_MAIN = D3bot.NavMain
local LOCOMOTION_HANDLERS = D3bot.LocomotionHandlers
local PATH = D3bot.PATH
local PATH_POINT = D3bot.PATH_POINT

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes
local UI = D3bot.NavSWEP.UI

local key = "PathTest"

-- Add edit mode to list
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModePathTest
---@field StartPos GVector
---@field DestPos GVector
---@field Path D3botPATH
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Debug path generation"

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

-- Generate a path from the current edit mode state and store it.
function THIS_EDIT_MODE:GeneratePath(navmesh, debugOutput)

	-- Can't generate a path if start and end point are not defined
	if not self.StartPos or not self.DestPos then return true end

	-- Add some virtual locomotion handlers
	local abilities = {
		Ground = LOCOMOTION_HANDLERS.WALKING:New(200),
		Wall = LOCOMOTION_HANDLERS.JUMP_AND_FALL:New(56, 1000)
	}

	-- Create path object
	self.Path = PATH:New(navmesh, abilities)

	-- Get triangles of start and end pos
	local startPoint = PATH_POINT:New(navmesh, self.StartPos)
	local destPoint = PATH_POINT:New(navmesh, self.DestPos)
	if not startPoint or not destPoint then return end

	-- Calculate path (Several times for average)
	local iterations = debugOutput and 1000 or 1
	local startTime = SysTime()
	for i = 1, iterations do
		self.Path:GeneratePathBetweenPoints(startPoint, destPoint)
	end
	local endTime = SysTime()

	if debugOutput then
		LocalPlayer():ChatPrint(string.format("It took %f ms to generate the path", (endTime - startTime)*1000/iterations))
	end
end

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

	-- Set start pos
	self.StartPos = trRes.HitPos

	-- (Re)generate path
	self:GeneratePath(navmesh, true)

	wep.Weapon:EmitSound("buttons/blip2.wav")

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

	-- Set end pos
	self.DestPos = trRes.HitPos

	-- (Re)generate path
	self:GeneratePath(navmesh, true)

	wep.Weapon:EmitSound("buttons/blip2.wav")

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

	-- Get map line trace result and navmesh tracing ray
	local tr, trRes, aimOrigin, aimVec = UTIL.SWEPLineTrace(LocalPlayer())

	-- Setup rendering context
	cam.Start3D()
	render.SetColorMaterial()

	-- Draw 3D cursor
	render.SetColorMaterialIgnoreZ()
	RENDER_UTIL.Draw3DCursorPos(trRes.HitPos, Color(255, 255, 255, 255), Color(0, 0, 0, 255))

	-- Draw client side navmesh
	navmesh:Render3D()

	-- Debug: Live path regeneration
	self.DestPos = trRes.HitPos
	self:GeneratePath(navmesh, false)

	-- Draw path
	if self.Path then
		self.Path:Render3D()
	end

	-- Draw start and end pos
	render.SetColorMaterialIgnoreZ()
	if self.StartPos then
		RENDER_UTIL.Draw3DCursorPos(self.StartPos, 2, Color(255, 0, 0, 255), Color(0, 0, 0, 255))
	end
	render.SetColorMaterialIgnoreZ()
	if self.DestPos then
		RENDER_UTIL.Draw3DCursorPos(self.DestPos, 2, Color(0, 255, 0, 255), Color(0, 0, 0, 255))
	end

	cam.End3D()

	-- "Restore" IgnoreZ for the original rendering context
	cam.IgnoreZ(true)
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
