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
local UTIL = D3bot.Util

local NAV_SWEP = D3bot.NavSWEP
local EDIT_MODES = NAV_SWEP.EditModes

local PANEL = {}

function PANEL:Init()
	self:SetTitle("D3bot navmeshing options")
	self:SetSizable(true)
	self:SetDraggable(true)
	self:ShowCloseButton(false)
	self:SetSize(300, 400)

	local propertySheet = vgui.Create("DPropertySheet", self)
	propertySheet:Dock(FILL)

	--propertySheet:AddSheet("View", dPanel, nil, false, false, "test2")
	--propertySheet:AddSheet("Help", dPanel, nil, false, false, "test3")

	------------------------------------------------------
	--		Main tab content
	------------------------------------------------------

	local dScrollPanel = vgui.Create("DScrollPanel")
	propertySheet:AddSheet("Main", dScrollPanel, nil, false, false, "Contains general navmesh settings")
	dScrollPanel:Dock(FILL)

	--[[local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetTextColor(Color(0, 0, 0))
	item:SetText("Enable")
	item:SetConVar("d3bot_navmeshing_enabled")

	local item = vgui.Create("DCheckBoxLabel", dScrollPanel)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetTextColor(Color(0, 0, 0))
	item:SetText("Cycle mode with RELOAD")
	item:SetConVar("d3bot_navmeshing_reloadmodecycle")]]

	local list = vgui.Create("DListView", dScrollPanel)
	list:SetMultiSelect(false)
	list:SetSize(nil, 100)
	list:Dock(TOP)
	list:AddColumn("EditMode")
	-- Fill with edit modes sorted by their name
	for _, editMode in UTIL.kpairs(EDIT_MODES) do
		list:AddLine(editMode.Name)
	end

	list.OnRowSelected = function(lst, index, pnl)
		-- Dirty way to get the edit mode
		local i = 0
		for _, editMode in UTIL.kpairs(EDIT_MODES) do
			i = i + 1
			if i == index then
				-- Apply edit mode to the players navmeshing SWEP
				local wep = LocalPlayer():GetWeapon("weapon_d3_navmesher")
				if IsValid(wep) then
					editMode:AssignToWeapon(wep)
				end
				break
			end
		end
	end
end

vgui.Register(D3bot.VGUIPrefix .. "NavmeshingOptions", PANEL, "DFrame")
