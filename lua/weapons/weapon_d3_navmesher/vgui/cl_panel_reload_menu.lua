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

-- This panel spans the whole screen and either allows interaction with controls contained in it, or the world.

local D3bot = D3bot

local PANEL = {}

function PANEL:Init()
	self:Dock(FILL)
	self:SetWorldClicker(true)
	self:SetVisible(false)

	local dNavmeshingOptions = vgui.Create(D3bot.VGUIPrefix .. "NavmeshingOptions", self)
	self.dNavmeshingOptions = dNavmeshingOptions
end

function PANEL:Open()
	self:SetVisible(true)
	gui.EnableScreenClicker(true)
end

function PANEL:Close()
	self:SetVisible(false)
	gui.EnableScreenClicker(false)
end

vgui.Register(D3bot.VGUIPrefix .. "ReloadMenu", PANEL, "EditablePanel")
