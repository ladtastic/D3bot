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

local D3bot = D3bot
local ERROR = D3bot.ERROR
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
---@return D3botERROR | nil err
function NAV_FILE.LoadMainNavmesh()
	--local startTime = SysTime()

	local mapName = game.GetMap()
	local filePath, gamePath = findValidFilePath(NAV_FILE.BasePaths, mapName)
	if filePath and gamePath then
		local tJSON = file.Read(filePath, gamePath)
		local t = util.JSONToTable(tJSON)
		local navmesh, err = NAV_MESH:NewFromTable(t)
		if err then return ERROR:New("Couldn't load navmesh from file %q in gamePath %q: %s", filePath, gamePath, err) end
		navmesh:_GC()
		NAV_MAIN:SetNavmesh(navmesh)
	else
		NAV_MAIN:SetNavmesh(nil)
	end

	--local duration = SysTime() - startTime
	--print(string.format("%s Loaded %q navmesh in %f seconds", D3bot.PrintPrefix, mapName, duration))

	return nil
end

---Stores the main navmesh in a file.
---This will store the navmesh in gmod's data directory.
---@return D3botERROR | nil err
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

	return nil
end

-- Load the navmesh for the map, if possible.
local err = NAV_FILE.LoadMainNavmesh()
if err then print(string.format("%s Failed to load navmesh for the current map: %s", D3bot.PrintPrefix, err)) end
