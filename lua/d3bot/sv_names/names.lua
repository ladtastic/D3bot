local D3bot = D3bot

include("names/default.lua")

-- Load custom name script if defined
if D3bot.Config.NameScript then
	include("names/" .. D3bot.Config.NameScript .. ".lua")
end
