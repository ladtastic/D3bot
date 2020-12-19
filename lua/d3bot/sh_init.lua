AddCSLuaFile()

-- Init namespaces
D3bot = D3bot or {}
D3bot.Config = D3bot.Config or {} -- General configuration table
D3bot.Util = D3bot.Util or {} -- Utility functions
D3bot.Locomotion = D3bot.Locomotion or {} -- Locomotion handlers
D3bot.Brains = D3bot.Brains or {} -- Brain handlers

-- Init default values
D3bot.PrintPrefix = "D3bot:"
D3bot.HookPrefix = "D3bot_"
D3bot.AddonRoot = "d3bot/"

-- Init class namespaces
D3bot.NAV_MESH = D3bot.NAV_MESH or {} -- NAV_MESH Class
D3bot.NAV_EDGE = D3bot.NAV_EDGE or {} -- NAV_EDGE Class
D3bot.NAV_TRIANGLE = D3bot.NAV_TRIANGLE or {} -- NAV_TRIANGLE Class

------------------------------------------------------
--					Shared files					--
------------------------------------------------------
include("sh_util.lua")
include("sh_navmesh/navmesh.lua")
include("sh_navmesh/edge.lua")
include("sh_navmesh/triangle.lua")

-- Load any gamemode specific logic
include("gamemodes/" .. engine.ActiveGamemode() .. "/sh_init.lua")

------------------------------------------------------
--					Client files					--
------------------------------------------------------
if CLIENT then
end

------------------------------------------------------
--					Server files					--
------------------------------------------------------
if SERVER then
	-- Load brains
	D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "sv_brains/", "*.lua", false)

	-- Load gamemode specific brains
	D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/sv_brains/", "*.lua", false)

	-- Load general locomotion controllers
	D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "sv_locomotion/", "*.lua", false)

	-- Load gamemode specific locomotion controllers
	D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/sv_locomotion/", "*.lua", false)

	-- Load bot naming script
	include("sv_names/names.lua")

	-- Other server side scripts
	include("sv_control.lua")
	include("sv_ulx_fix.lua")
end
