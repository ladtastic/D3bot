-- Copyright (C) 2021 David Vogel
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
local NAV_SWEP = D3bot.NavSWEP
local UI = D3bot.NavSWEP.UI
local RELOAD_MENU = D3bot.NavSWEP.UI.ReloadMenu

function RELOAD_MENU:Create()
	if IsValid(self.PanelInstance) then
		self.PanelInstance:Remove()
		self.PanelInstance = nil
	end

	-- Create instance of reload menu.
	-- All the logic is in the panel itself.
	self.PanelInstance = vgui.Create(D3bot.VGUIPrefix .. "ReloadMenu")
	if not IsValid(self.PanelInstance) then
		self.PanelInstance = nil
		return
	end
end

function RELOAD_MENU:Open()
	-- Prevent Spam
	if self.IsOpen then return end
	self.IsOpen = true

	-- Make sure that there is a panel instance
	if not IsValid(self.PanelInstance) then
		self:Create()
	end

	-- Only open menu if the player has the SWEP in his hand
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid(wep) or not wep:GetClass() == "weapon_d3_navmesher" then return end

	self.PanelInstance:Open()
end

function RELOAD_MENU:Close()
	-- Prevent Spam
	if not self.IsOpen then return end
	self.IsOpen = nil

	-- Check if there is a panel instance
	if not IsValid(self.PanelInstance) then
		return
	end

	self.PanelInstance:Close()
end

-- Stupid hack: Check if the reload key is hold, and open the menu accordingly.
local reloadMenuOpener = function()
	-- Only open menu if the player has the SWEP in his hand
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "weapon_d3_navmesher" then return end

	-- Reset edit mode every time the player reloads the SWEP
	if LocalPlayer():KeyPressed(IN_RELOAD) and CONVARS.SWEPResetOnReloadKey:GetBool() then
		wep:ResetEditMode()
	end

	-- Spam open or close calls
	if LocalPlayer():KeyDown(IN_RELOAD) then
		RELOAD_MENU:Open()
	else
		RELOAD_MENU:Close()
	end
end
hook.Add("Think", D3bot.HookPrefix .. "ReloadMenuOpener", reloadMenuOpener)

-- Register console commands.
concommand.Add("+d3bot_menu_reload", function() RELOAD_MENU:Open() end, nil, "Opens the D3bot reload menu", FCVAR_DONTRECORD)
concommand.Add("-d3bot_menu_reload", function() if (input.IsKeyTrapping()) then return end RELOAD_MENU:Close() end, nil, "Closes the D3bot reload menu", FCVAR_DONTRECORD)

-- For debugging: Recreate panel every time the file loads
-- TODO: Don't call RELOAD_MENU:Create from here
RELOAD_MENU:Create()
