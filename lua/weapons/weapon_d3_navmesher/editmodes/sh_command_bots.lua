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

local key = "CommandBots"

-- Add edit mode to list.
EDIT_MODES[key] = EDIT_MODES[key] or {}

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botNavmesherEditModeCommandBots : D3botNavmesherEditMode
---@field Bots table<GPlayer, boolean> @List of selected bots.
---@field Positions GVector[] @List of destination positions.
local THIS_EDIT_MODE = EDIT_MODES[key]
THIS_EDIT_MODE.__index = THIS_EDIT_MODE

-- Key of the edit mode. Must be the same as is used as entry in EDIT_MODES.
THIS_EDIT_MODE.Key = key

-- Name that is shown to the user.
THIS_EDIT_MODE.Name = "Select and command bots"

---Set and overwrite current edit mode of the given weapon.
---This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
---@param wep GWeapon
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = setmetatable({
		Bots = {},
		Positions = {},
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
	if not SERVER then return end

	---@type GPlayer
	local owner = wep:GetOwner()

	-- Have to use lag compensation, as the trace happens on the server side.
	owner:LagCompensation(true)
	local trRes = owner:GetEyeTrace()
	owner:LagCompensation(false)

	---If the user points on a bot, add or remove the bot from the current selection list.
	---@type GPlayer
	local entity = trRes.Entity
	if IsValid(entity) and entity:IsPlayer() then
		local mem = entity.D3bot
		if mem then
			if self.Bots[entity] then
				self.Bots[entity] = nil
			else
				self.Bots[entity] = true
			end

			owner:EmitSound("buttons/blip2.wav")

			-- Sync state with the client side.
			self:SendToClient(wep)
			return
		end
	end

	owner:EmitSound("common/wpn_denyselect.wav")
end

---Called when secondary attack button ( +attack2 ) is pressed.
---For issues with this hook being called rapidly on the client side, see the global function IsFirstTimePredicted.
---Predicted, therefore it's not called by the client in single player.
---Shared.
---@param wep GWeapon
function THIS_EDIT_MODE:SecondaryAttack(wep)
	if not IsFirstTimePredicted() then return end

	---@type GPlayer
	local owner = wep:GetOwner()

	-- Have to use lag compensation, as the trace happens on the server side.
	owner:LagCompensation(true)
	local trRes = owner:GetEyeTrace()
	owner:LagCompensation(false)

	-- Generate list with destination positions in a grid like fashion.
	-- This will happen on both, the server and client side. Normally this will be in sync, but it doesn't have to.
	local direction = Vector(32, 0, 0)
	local i, iMax = 1, 1
	local pos = trRes.HitPos
	self.Positions = {}
	for bot in pairs(self.Bots) do
		local mem = bot.D3bot

		-- Give bots their destination position and reset their brain.
		if SERVER and mem then
			mem.DebugCommandPosition = pos
			mem.Brain = nil
		end

		-- Calculate next position on the spiral grid.
		table.insert(self.Positions, pos)
		pos = pos + direction
		i = i + 1
		if i > math.floor(iMax) then
			direction:Rotate(Angle(0, 90, 0))
			i, iMax = 1, iMax + 0.5
		end
	end

	wep:EmitSound("buttons/blip2.wav")
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

	-- Setup rendering context.
	cam.Start3D()
	render.SetColorMaterial()

	---Highlight the selected bots somehow.
	---@type GPlayer
	for ply in pairs(self.Bots) do
		local pos = ply:GetPos()
		render.DrawSphere(pos, 16, 6, 6, Color(255, 255, 255, 255))
	end

	-- Draw destination positions.
	for _, pos in ipairs(self.Positions) do
		RENDER_UTIL.Draw3DCursorPos(pos, 2, Color(255, 255, 255, 255), Color(0, 0, 0, 255))
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

------------------------------------------------------
--		Network syncing
------------------------------------------------------

---Sends the current state of the edit mode to the client, so it can display everything correctly.
---Not a perfect solution as it works around prediction and lag compensation, but it works for now.
---@param wep GWeapon
if SERVER then
	function THIS_EDIT_MODE:SendToClient(wep)
		local owner = wep:GetOwner()

		if IsValid(owner) and owner:IsPlayer() then
			net.Start("D3bot_Nav_EditSync_CommandBots")
			net.WriteString(self.Key)
			net.WriteEntity(wep)
			net.WriteTable(self.Bots)
			net.Send(owner)
		end
	end
	util.AddNetworkString("D3bot_Nav_EditSync_CommandBots")
end

if CLIENT then
	net.Receive("D3bot_Nav_EditSync_CommandBots",
		function(len)
			local editModeKey = net.ReadString()
			local wep = net.ReadEntity()

			-- Check if the weapon exists, and if its edit mode is the same, as it could have changed in the meanwhile. There are other edge cases where this might go wrong, but blah.
			if IsValid(wep) then
				local editMode = wep.EditMode
				if editMode and editModeKey == editMode.Key then
					editMode.Bots = net.ReadTable()
				end
			end
		end
	)
end
