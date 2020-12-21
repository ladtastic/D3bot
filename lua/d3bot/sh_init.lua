AddCSLuaFile()

------------------------------------------------------
--						Init						--
------------------------------------------------------

-- Init namespaces
D3bot = D3bot or {}
D3bot.Config = D3bot.Config or {} -- General configuration table
D3bot.Util = D3bot.Util or {} -- Utility functions
D3bot.NavPubSub = D3bot.NavPubSub or {} -- Navmesh pub/sub functions
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
--						Includes					--
------------------------------------------------------

-- General stuff
include("sh_util.lua")
local UTIL = D3bot.Util -- From here on UTIL.IncludeRealm can be used

-- Navmesh stuff
UTIL.IncludeRealm("sh_navmesh/navmesh.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("sh_navmesh/edge.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("sh_navmesh/triangle.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("sh_navmesh/sh_network.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("sh_navmesh/sv_network.lua", UTIL.REALM_SERVER)
UTIL.IncludeRealm("sh_navmesh/cl_network.lua", UTIL.REALM_CLIENT)

-- Load bot naming script
UTIL.IncludeRealm("sv_names/names.lua", UTIL.REALM_SERVER)

-- Load any gamemode specific logic
UTIL.IncludeRealm("gamemodes/" .. engine.ActiveGamemode() .. "/sh_init.lua", UTIL.REALM_SHARED)

-- Load brains (General and gamemode specific)
D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "sv_brains/", "*.lua", UTIL.REALM_SERVER)
D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/sv_brains/", "*.lua", UTIL.REALM_SERVER)

-- Load general locomotion controllers (General and gamemode specific)
D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "sv_locomotion/", "*.lua", UTIL.REALM_SERVER)
D3bot.Util.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/sv_locomotion/", "*.lua", UTIL.REALM_SERVER)

-- Other server side scripts
UTIL.IncludeRealm("sv_control.lua", UTIL.REALM_SERVER)
UTIL.IncludeRealm("sh_navmesh/sv_network.lua", UTIL.REALM_SERVER)
UTIL.IncludeRealm("sv_ulx_fix.lua", UTIL.REALM_SERVER)
