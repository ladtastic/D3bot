local function MaintainBotRoles()
	local bots = player.GetBots()

	if #bots < 120 then
		local bot = player.CreateNextBot("blabl101a")
		bot.D3bot = {}
	elseif #bots > 120 then
		bots[1]:Kick("blabla")
	end
end
timer.Create(D3bot.HookPrefix .. "MaintainBotRoles", 0.1, 0, MaintainBotRoles)
