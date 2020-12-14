AddCSLuaFile()

D3bot = D3bot or {}
D3bot.HookPrefix = "D3bot_"
D3bot.AddonRoot = "d3bot/"

-- Shared files

-- Client files
if CLIENT then
end

-- Server files
if SERVER then
	-- Include the gamemode specific brains
	D3bot.Brains = {}
	include("sv_brains/" .. engine.ActiveGamemode() .. "/init.lua") -- ActiveGamemode returns the gamemode's folder name, so it will always be a valid path

	-- Include general locomotion controllers
	D3bot.Locomotion = {}
	local filenames, _ = file.Find(D3bot.AddonRoot .. "sv_locomotion/*.lua", "LUA")
	for _, filename in ipairs(filenames) do
		include(D3bot.AddonRoot .. "sv_locomotion/" .. filename)
	end

	-- Other server side scripts
	include("sv_control.lua")
	include("sv_supervisor.lua")
end
