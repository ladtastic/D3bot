AddCSLuaFile()

-- Init namespaces and default values
D3bot = D3bot or {}
D3bot.PrintPrefix = "D3bot:"
D3bot.HookPrefix = "D3bot_"
D3bot.AddonRoot = "d3bot/"
D3bot.Config = D3bot.Config or {}
D3bot.Util = D3bot.Util or {}
D3bot.Locomotion = D3bot.Locomotion or {}
D3bot.Brains = D3bot.Brains or {}

-- Shared files
include("ulx/modules/sh/d3bot_ulx_fix.lua")

-- Client files
if CLIENT then
end

-- Server files
if SERVER then
	-- Include the gamemode specific brains
	include("sv_brains/" .. engine.ActiveGamemode() .. "/init.lua") -- ActiveGamemode returns the gamemode's folder name, so it will always be a valid path

	-- Include general locomotion controllers
	local filenames, _ = file.Find(D3bot.AddonRoot .. "sv_locomotion/*.lua", "LUA")
	for _, filename in ipairs(filenames) do
		include(D3bot.AddonRoot .. "sv_locomotion/" .. filename)
	end

	-- Load bot naming script
	local nameScript = D3bot.Config.NameScript or "default"
	include("sv_names/" .. nameScript .. ".lua")

	-- Other server side scripts
	include("sv_util.lua")
	include("sv_control.lua")
	include("sv_supervisor.lua")
end
