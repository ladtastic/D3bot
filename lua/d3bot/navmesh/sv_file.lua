-- Copyright (C) 2020-2021 David Vogel
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
local NAV_FILE = D3bot.NavFile
local NAV_MAIN = D3bot.NavMain
local NAV_MESH = D3bot.NAV_MESH

-- Define base directories for navmeshes ordered in descending priority.
-- For saving, the first entry will be used.
-- For loading, it will iterate over all entries until one with an existing file is found. (Not necessarily a valid navmesh)
NAV_FILE.BasePaths = {
	{gamePath = "DATA", path = D3bot.AddonRoot .. "navmeshes/map/"},
	{gamePath = "GAME", path = "data/" .. D3bot.AddonRoot .. "navmeshes/map/"},
}

-- Create all paths that are in gmod's data directory.
for _, basePath in ipairs(NAV_FILE.BasePaths) do
	if basePath.gamePath == "DATA" then
		file.CreateDir(basePath.path)
	end
end

---Builds and returns a file path from the given base path and map name.
---@param basePath table
---@param mapName string
---@return string
local function getFilePath(basePath, mapName)
	return basePath.path .. mapName .. ".json", basePath.gamePath
end

---Iterates over base paths until it finds an existing file.
---Returns a filePath and gamePath pair.
---@param basePaths table[]
---@param mapName string
---@return string filePath @Path to the file, relative to the root that gamePath defines.
---@return string gamePath @A string like "DATA".
local function findValidFilePath(basePaths, mapName)
	for _, basePath in ipairs(basePaths) do
		local filePath, gamePath = getFilePath(basePath, mapName)
		if file.Exists(filePath, gamePath) then
			return filePath, gamePath
		end
	end
end

---Loads the main navmesh from a file.
---This will try to load the navmesh from several directories, see NAV_FILE.BasePaths.
function NAV_FILE.LoadMainNavmesh()
	local mapName = game.GetMap()
	local filePath, gamePath = findValidFilePath(NAV_FILE.BasePaths, mapName)
	if filePath and gamePath then
		local tJSON = file.Read(filePath, gamePath)
		local t = util.JSONToTable(tJSON)
		local navmesh = NAV_MESH:NewFromTable(t)
		if navmesh then
			navmesh:_GC()
			NAV_MAIN:SetNavmesh(navmesh)
		end
	else
		NAV_MAIN:SetNavmesh(nil)
	end
end

---Stores the main navmesh in a file.
---This will store the navmesh in gmod's data directory.
function NAV_FILE.SaveMainNavmesh()
	local mapName = game.GetMap()
	local filePath, gamePath = getFilePath(NAV_FILE.BasePaths[1], mapName)
	if filePath and gamePath and gamePath == "DATA" then
		local navmesh = NAV_MAIN:GetNavmesh()
		if navmesh then
			local t = navmesh:MarshalToTable()
			local tJSON = util.TableToJSON(t, true)
			file.Write(filePath, tJSON)
		else
			file.Delete(filePath)
		end
	end
end

-- Load the navmesh for the map, if possible.
NAV_FILE.LoadMainNavmesh()
