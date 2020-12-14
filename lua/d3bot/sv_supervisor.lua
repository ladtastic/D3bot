local D3bot = D3bot

local function MaintainBotRoles()
	local bots = player.GetBots()

	if #bots < 120 then
		local bot = player.CreateNextBot(D3bot.GetBotName())
		bot.D3bot = {}
	elseif #bots > 120 then
		bots[1]:Kick("blabla") -- TODO: Add kick message
	end
end
timer.Create(D3bot.HookPrefix .. "MaintainBotRoles", 0.1, 0, MaintainBotRoles)
