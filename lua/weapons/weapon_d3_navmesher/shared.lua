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

SWEP.PrintName = "D3navmesher"
SWEP.Author = "D3"
SWEP.Contact = ""
SWEP.Purpose = "Build and edit D3bot navmeshes"
SWEP.Instructions = ""

SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.UseHands = true

-- Be nice, precache the models
util.PrecacheModel(SWEP.ViewModel)
util.PrecacheModel(SWEP.WorldModel)

SWEP.ShootSound = Sound("Airboat.FireGunRevDown")

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.CanHolster = true
SWEP.CanDeploy = true

-- Load edit modes
D3_NAVMESHER_EDIT_MODES = D3_NAVMESHER_EDIT_MODES or {}
include("editmodes/sh_triangle.lua")

function SWEP:Initialize()
	self:ChangeEditMode("TriangleAddRemove")
end

-- Server realm only
function SWEP:Equip(ent)
	local editMode = self.EditMode

	if IsValid(ent) and ent:IsPlayer() then
		D3bot.NavPubSub:SubscribePlayer(ent)
	end

	if not editMode then return true end
	if not editMode.Equip then return true end

	return editMode:Equip(self)
end

-- Server realm only
function SWEP:OnDrop()
	local editMode = self.EditMode

	local owner = self.Owner
	if IsValid(owner) and owner:IsPlayer() then
		D3bot.NavPubSub:UnsubscribePlayer(owner)
	end

	if not editMode then return true end
	if not editMode.OnDrop then return true end

	return editMode:OnDrop(self)
end

function SWEP:OnRemove()
	local editMode = self.EditMode

	if SERVER then
		local owner = self.Owner
		if IsValid(owner) and owner:IsPlayer() then
			D3bot.NavPubSub:UnsubscribePlayer(owner)
		end
	end

	if not editMode then return true end
	if not editMode.OnRemove then return true end

	return editMode:OnRemove(self)
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:Deploy()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Deploy then return true end

	return editMode:Deploy(self)
end

function SWEP:Holster()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Holster then return true end

	return editMode:Holster(self)
end

function SWEP:PrimaryAttack()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PrimaryAttack then return true end

	return editMode:PrimaryAttack(self)
end

function SWEP:SecondaryAttack()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.SecondaryAttack then return true end

	return editMode:SecondaryAttack(self)
end

function SWEP:Reload()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Reload then return true end

	return editMode:Reload(self)
end

function SWEP:ChangeEditMode(modeIdentifier)
	local editMode = D3_NAVMESHER_EDIT_MODES[modeIdentifier]
	if not editMode then return false end

	return editMode:AssignToWeapon(self)
end
