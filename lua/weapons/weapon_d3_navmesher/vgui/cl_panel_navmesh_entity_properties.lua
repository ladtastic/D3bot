-- Copyright (C) 2021 David Vogel
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

-- Window/Frame with the most important navmeshing settings.

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local CONCOMMANDS = D3bot.ConCommands

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes

local PANEL = {}

function PANEL:Init()
	self:SetTitle("D3bot entity properties")
	self:SetSizable(false)
	self:SetDraggable(false)
	self:ShowCloseButton(true)
	self:SetMinimumSize(200, 300)
	self:MakePopup()

	-- Set its size and pos.
	self:SetPos(gui.MouseX(), gui.MouseY())
	self:SetSize(400, 400)

	self.NavEntities = {}

	local dButtonAbort = vgui.Create("DButton", self)
	dButtonAbort:SetText("Abort")
	dButtonAbort:SizeToContents()
	dButtonAbort:Dock(BOTTOM)
	dButtonAbort:SetTooltip("Close window without editing any navmesh entity properties")

	local dCollapsible = vgui.Create("DCollapsibleCategory", self)
	dCollapsible:SetLabel("")
	dCollapsible:Dock(FILL)
end

---Sets the list of navmesh entities to be edited.
---@param entities any[]
function PANEL:SetNavEntities(entities)
	self.NavEntities = entities
end

vgui.Register(D3bot.VGUIPrefix .. "NavmeshEntityContext", PANEL, "DFrame")
