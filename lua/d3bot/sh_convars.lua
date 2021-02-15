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
local CONVARS = D3bot.Convars

CONVARS.NavmeshZCulling = CreateClientConVar("d3bot_navmesh_zculling", 1, true, true, "Hide navmesh entities that are obscured by map geometry or map entities.")

CONVARS.SWEPHitWater = CreateClientConVar("d3bot_swep_hit_water", 1, true, true, "Enables the SWEP to place its 3D cursor on water surfaces.")

CONVARS.SWEPSnapToMapGeometry = CreateClientConVar("d3bot_snap_mapgeometry", 1, true, true, "Enables snapping to map geometry (corners) for the 3D cursor.")
CONVARS.SWEPSnapToNavmeshGeometry = CreateClientConVar("d3bot_snap_navgeometry", 1, true, true, "Enables snapping to navmesh geometry (edge points or triangle corners) for the 3D cursor.")

CONVARS.SWEPResetOnReloadKey = CreateClientConVar("d3bot_swep_reset_on_reload", 1, true, true, "Resets the SWEP's edit mode every time the player reloads the SWEP (Uses the reload menu).")
