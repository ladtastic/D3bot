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

AddCSLuaFile()

local D3bot = D3bot
local UTIL = D3bot.Util

------------------------------------------------------
--		Init
------------------------------------------------------

SWEP.PrintName = "D3navmesher"
SWEP.Author = "D3"
SWEP.Contact = ""
SWEP.Purpose = "Create, edit and test D3bot navmeshes"
SWEP.Instructions = ""

SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.UseHands = true

-- Be nice, precache the models.
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

------------------------------------------------------
--		Includes
------------------------------------------------------

-- Other stuff.
UTIL.IncludeRealm("", "sh_hooks.lua")

-- Load edit modes.
UTIL.IncludeRealm("", "sh_editmode.lua")
UTIL.IncludeDirectory("weapons/weapon_d3_navmesher/editmodes/", "*.lua")

-- UI stuff.
UTIL.IncludeRealm("", "cl_viewscreen.lua")
UTIL.IncludeRealm("vgui/", "cl_panel_navmeshing_options.lua")
UTIL.IncludeRealm("vgui/", "cl_panel_reload_menu.lua")
UTIL.IncludeRealm("vgui/", "cl_ui_reload_menu.lua")
