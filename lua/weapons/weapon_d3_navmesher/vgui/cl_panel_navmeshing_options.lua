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

-- Window/Frame with the most important navmeshing settings.

local D3bot = D3bot
local CONVARS = D3bot.Convars
local UTIL = D3bot.Util
local CONCOMMANDS = D3bot.ConCommands

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = D3bot.NavSWEP.EditModes

local PANEL = {}

function PANEL:Init()
	self:SetTitle("D3bot navmeshing options")
	self:SetSizable(true)
	self:SetDraggable(true)
	self:ShowCloseButton(false)
	self:SetMinimumSize(200, 300)

	-- Restore its previous size and pos.
	self:SetCookieName(D3bot.VGUIPrefix .. "NavmeshingOptions")
	local x, y, width, height = self:GetCookieNumber("x", 100), self:GetCookieNumber("y", 100), self:GetCookieNumber("width", 300), self:GetCookieNumber("height", 400)
	self:SetPos(x, y)
	self:SetSize(width, height)

	------------------------------------------------------
	--		Tabs
	------------------------------------------------------

	local propertySheet = vgui.Create("DPropertySheet", self)
	propertySheet:Dock(FILL)

	--propertySheet:AddSheet("View", dPanel, nil, false, false, "test2")
	--propertySheet:AddSheet("Help", dPanel, nil, false, false, "test3")

	------------------------------------------------------
	--		EditMode tab content
	------------------------------------------------------

	local dScrollPanel = vgui.Create("DScrollPanel")
	propertySheet:AddSheet("EditMode", dScrollPanel, nil, false, false, "Editmode related settings")
	dScrollPanel:Dock(FILL)

	local dEditablePanel = vgui.Create("EditablePanel", dScrollPanel)
	dEditablePanel:Dock(TOP)
	dEditablePanel:DockMargin(5, 5, 5, 0)

	local dButton = vgui.Create("DButton", dEditablePanel)
	dButton:SetText("Reset edit mode")
	dButton:SizeToContents()
	dButton:Dock(LEFT)
	dButton:SetConsoleCommand(CONCOMMANDS.EditModeReset:GetName())
	dButton:SetTooltip(CONCOMMANDS.EditModeReset:GetHelpText())

	local item = vgui.Create("DCheckBoxLabel", dEditablePanel)
	item:Dock(LEFT)
	item:DockMargin(5, 0, 0, 0)
	item:SetText("Reset on RELOAD")
	item:SetConVar(CONVARS.SWEPResetOnReloadKey:GetName())
	item:SetTooltip(CONVARS.SWEPResetOnReloadKey:GetHelpText())

	local list = vgui.Create("DListView", dScrollPanel)
	list:SetMultiSelect(false)
	list:SetSize(nil, 100)
	list:DockMargin(5, 5, 5, 0)
	list:Dock(TOP)
	list:AddColumn("Name")
	-- Fill with edit modes sorted by their name.
	for _, editMode in UTIL.kpairs(EDIT_MODES) do
		list:AddLine(editMode.Name)
	end

	list.OnRowSelected = function(lst, index, pnl)
		-- Dirty way to get the edit mode.
		local i = 0
		for _, editMode in UTIL.kpairs(EDIT_MODES) do
			i = i + 1
			if i == index then
				LocalPlayer():ConCommand(CONCOMMANDS.EditMode:GetName() .. " " .. editMode.Key)
				break
			end
		end
	end

	------------------------------------------------------
	--		Drawing & Interaction tab content
	------------------------------------------------------

	local dScrollPanel = vgui.Create("DScrollPanel")
	propertySheet:AddSheet("Drawing & Interaction", dScrollPanel, nil, false, false, "Navmesh drawing and interactivity settings")
	dScrollPanel:Dock(FILL)

	local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetText("Z-Culling")
	item:SetConVar(CONVARS.NavmeshZCulling:GetName())
	item:SetTooltip(CONVARS.NavmeshZCulling:GetHelpText())

	local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetText("3D cursor hits water")
	item:SetConVar(CONVARS.SWEPHitWater:GetName())
	item:SetTooltip(CONVARS.SWEPHitWater:GetHelpText())

	local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetText("Snap 3D cursor to map geometry")
	item:SetConVar(CONVARS.SWEPSnapToMapGeometry:GetName())
	item:SetTooltip(CONVARS.SWEPSnapToMapGeometry:GetHelpText())

	local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetText("Snap 3D cursor to navmesh")
	item:SetConVar(CONVARS.SWEPSnapToNavmeshGeometry:GetName())
	item:SetTooltip(CONVARS.SWEPSnapToNavmeshGeometry:GetHelpText())
end

function PANEL:OnMouseReleased()
	-- Store current window position.
	local x, y = self:GetPos()
	self:SetCookie("x", tostring(x))
	self:SetCookie("y", tostring(y))

	-- Call method of base class, if it exists.
	if self.BaseClass.OnMouseReleased then return self.BaseClass.OnMouseReleased(self) end
end

function PANEL:OnSizeChanged(newWidth, newHeight)
	-- Store current window size.
	self:SetCookie("width", tostring(newWidth))
	self:SetCookie("height", tostring(newHeight))

	-- Call method of base class, if it exists.
	if self.BaseClass.OnSizeChanged then return self.BaseClass.OnSizeChanged(self) end
end

vgui.Register(D3bot.VGUIPrefix .. "NavmeshingOptions", PANEL, "DFrame")
