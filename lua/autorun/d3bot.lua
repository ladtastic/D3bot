AddCSLuaFile()

D3bot = D3bot or {}
D3bot.HookPrefix = "D3bot_"

-- Shared files

-- Client files
if CLIENT then
end

-- Server files
if SERVER then
	include("d3bot/sv_control.lua")
	include("d3bot/sv_supervisor.lua")
end
