local D3bot = D3bot
local NAV_FILE = D3bot.NavFile
local NAV_MAIN = D3bot.NavMain
local NAV_MESH = D3bot.NAV_MESH

-- Define base directories for navmeshes ordered in descending priority.
-- For saving, the first entry will be used.
-- For loading, it will iterate over all entries until one with an existing file is found. (Not necessarily a valid navmesh)
NAV_FILE.BasePaths = {
	{gamePath = "DATA", path = D3bot.AddonRoot .. "navmeshes/map/"},
	{gamePath = "GAME", path = "data/" .. D3bot.AddonRoot .. "navmeshes/map/"}
}

-- Create all paths that are in gmod's data directory.
for _, basePath in ipairs(NAV_FILE.BasePaths) do
	if basePath.gamePath == "DATA" then
		file.CreateDir(basePath.path)
	end
end

-- Builds and returns a file path from the given base path and map name.
local function getFilePath(basePath, mapName)
	return basePath.path .. mapName .. ".json", basePath.gamePath
end

-- Iterates over base paths until it finds an existing file.
-- Returns a filePath and gamePath pair.
local function findValidFilePath(basePaths, mapName)
	for _, basePath in ipairs(NAV_FILE.BasePaths) do
		local filePath, gamePath = getFilePath(basePath, mapName)
		if file.Exists(filePath, gamePath) then
			return filePath, gamePath
		end
	end
end

-- Loads the main navmesh from a file.
-- This will try to load the navmesh from several directories, see NAV_FILE.BasePaths.
function NAV_FILE.LoadMainNavmesh()
	local mapName = game.GetMap()
	local filePath, gamePath = findValidFilePath(NAV_FILE.BasePaths, mapName)
	if filePath and gamePath then
		local tJSON = file.Read(filePath, gamePath)
		local t = util.JSONToTable(tJSON)
		local navmesh = NAV_MESH:NewFromTable(t)
		if navmesh then
			NAV_MAIN:SetNavmesh(navmesh)
		end
	else
		NAV_MAIN:SetNavmesh(nil)
	end
end

-- Stores the main navmesh in a file.
-- This will store the navmesh in gmod's data directory.
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

-- Test
--NAV_FILE.SaveMainNavmesh()

-- Load the navmesh for the map, if possible.
NAV_FILE.LoadMainNavmesh()