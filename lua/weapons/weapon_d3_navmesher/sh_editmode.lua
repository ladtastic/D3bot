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

local D3bot = D3bot
local ERROR = D3bot.ERROR
local EDIT_MODES = D3bot.NavSWEP.EditModes

---Base class for edit modes.
---@class D3botNavmesherEditMode

---Change and reset the navmeshing weapon's edit mode by a given key string.
---@param modeKey string
---@return D3botERROR | nil err
function SWEP:ChangeEditMode(modeKey)
	local editMode = EDIT_MODES[modeKey]
	if not editMode then return ERROR:New("There is no edit mode with the key %q", modeKey) end

	editMode:AssignToWeapon(self)
	return nil
end

---Reset the state of the weapon's edit mode. This basically reapplies the current edit mode.
---@return D3botERROR | nil err
function SWEP:ResetEditMode()
	local editMode = self.EditMode
	if not editMode then return ERROR:New("Weapon has currently no assigned edit mode") end

	return self:ChangeEditMode(editMode.Key)
end
