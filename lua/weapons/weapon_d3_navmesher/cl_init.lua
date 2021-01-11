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

include("shared.lua")
include("cl_viewscreen.lua")
include("vgui/cl_panel_navmeshing_options.lua")
include("vgui/cl_panel_reload_menu.lua")
include("vgui/cl_ui_reload_menu.lua")

function SWEP:PreDrawViewModel(vm) -- ZS doesn't call this with the weapon and ply parameters
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PreDrawViewModel then return true end

	return editMode:PreDrawViewModel(self, vm)
end

function SWEP:PostDrawViewModel(vm) -- ZS doesn't call this with the weapon and ply parameters
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PostDrawViewModel then return true end

	return editMode:PostDrawViewModel(self, vm)
end

function SWEP:DrawHUD()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.DrawHUD then return true end

	return editMode:DrawHUD(self)
end
