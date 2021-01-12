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

CONVARS.NavmeshZCulling = CreateClientConVar("d3bot_navmesh_zculling", 1, true, true, "Hide navmesh entities that are obscured by map geometry or map entities. Also, this will make these entities selectable.")

CONVARS.SWEPHitWater = CreateClientConVar("d3bot_swep_hit_water", 1, true, true, "Enables the SWEP to place its 3D cursor on water surfaces.")
