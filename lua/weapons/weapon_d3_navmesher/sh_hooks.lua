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
local RELOAD_MENU = D3bot.NavSWEP.UI.ReloadMenu

------------------------------------------------------
--		Shared
------------------------------------------------------

---Called when the weapon entity is created.
function SWEP:Initialize()
	-- Define starting edit mode.
	self:ChangeEditMode("TriangleAddRemove")
end

---Called when the swep is about to be removed.
function SWEP:OnRemove()
	local editMode = self.EditMode

	-- Hide UI.
	if CLIENT then
		RELOAD_MENU:Close()
	end

	-- Unsubscribe from navmesh PubSub.
	if SERVER then
		local owner = self.Owner
		if IsValid(owner) and owner:IsPlayer() then
			D3bot.NavPubSub:UnsubscribePlayer(owner)
		end
	end

	if not editMode then return end
	if not editMode.OnRemove then return end

	return editMode:OnRemove(self)
end

---Called when player has just switched to this weapon.
---Predicted, therefore it's not called by the client in single player.
---@return boolean @Return true to allow switching away from this weapon using lastinv command.
function SWEP:Deploy()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Deploy then return true end

	return editMode:Deploy(self)
end

---Called when weapon tries to holster.
---Predicted, therefore it's not called by the client in single player.
---@param weapon GWeapon @The weapon we are trying switch to.
---@return boolean @Return true to allow weapon to holster.
function SWEP:Holster(weapon)
	local editMode = self.EditMode

	-- Hide UI when holstering.
	if CLIENT then
		RELOAD_MENU:Close()
	end

	if not editMode then return true end
	if not editMode.Holster then return true end

	return editMode:Holster(self, weapon)
end

---Called when primary attack button ( +attack ) is pressed.
---Predicted, therefore it's not called by the client in single player.
function SWEP:PrimaryAttack()
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.PrimaryAttack then return end

	return editMode:PrimaryAttack(self)
end

---Called when secondary attack button ( +attack2 ) is pressed.
---For issues with this hook being called rapidly on the client side, see the global function IsFirstTimePredicted.
---Predicted, therefore it's not called by the client in single player.
function SWEP:SecondaryAttack()
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.SecondaryAttack then return end

	return editMode:SecondaryAttack(self)
end

---Called when the reload key ( +reload ) is pressed.
---Predicted, therefore it's not called by the client in single player.
function SWEP:Reload()
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.Reload then return end

	return editMode:Reload(self)
end

------------------------------------------------------
--		Server
------------------------------------------------------

---Called when a player or NPC has picked the weapon up.
---@param ent GEntity
function SWEP:Equip(ent)
	local editMode = self.EditMode

	if IsValid(ent) and ent:IsPlayer() then
		D3bot.NavPubSub:SubscribePlayer(ent)
	end

	if not editMode then return end
	if not editMode.Equip then return end

	return editMode:Equip(self)
end

---Called when weapon is dropped by Player:DropWeapon.
---See also WEAPON:OwnerChanged.
function SWEP:OnDrop()
	local editMode = self.EditMode

	local owner = self.Owner
	if IsValid(owner) and owner:IsPlayer() then
		D3bot.NavPubSub:UnsubscribePlayer(owner)
	end

	if not editMode then return end
	if not editMode.OnDrop then return end

	return editMode:OnDrop(self)
end

---Should this weapon be dropped when its owner dies?
---This only works if the player has Player:ShouldDropWeapon set to true.
---@return boolean
function SWEP:ShouldDropOnDie()
	return false
end

------------------------------------------------------
--		Client
------------------------------------------------------

---Allows you to modify viewmodel while the weapon in use before it is drawn. This hook only works if you haven't overridden GM:PreDrawViewModel.
---@param vm GEntity
---@param weapon GWeapon @Can be nil in some gamemodes.
---@param ply GPlayer @Can be nil in some gamemodes.
function SWEP:PreDrawViewModel(vm, weapon, ply)
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.PreDrawViewModel then return end

	return editMode:PreDrawViewModel(self, vm, weapon, ply)
end

---Called after the view model has been drawn while the weapon in use. This hook is called from the default implementation of GM:PostDrawViewModel, and as such, will not occur if it has been overridden.
---WEAPON:ViewModelDrawn is an alternative hook which is always called before GM:PostDrawViewModel.
---@param vm GEntity
---@param weapon GWeapon @Can be nil in some gamemodes.
---@param ply GPlayer @Can be nil in some gamemodes.
function SWEP:PostDrawViewModel(vm, weapon, ply)
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.PostDrawViewModel then return end

	return editMode:PostDrawViewModel(self, vm, weapon, ply)
end

---This hook allows you to draw on screen while this weapon is in use.
---If you want to draw a custom crosshair, consider using WEAPON:DoDrawCrosshair instead.
function SWEP:DrawHUD()
	local editMode = self.EditMode

	if not editMode then return end
	if not editMode.DrawHUD then return end

	return editMode:DrawHUD(self)
end
