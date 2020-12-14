local function ControlDistributor(bot, cmd)
	local mem = bot.D3bot

	-- Don't take control if there is no D3bot structure
	if not mem then
		return
	end

	-- Assign brain to bot, if needed
	if not mem.Brain then
		-- "Insane in the membrane"
		-- "Crazy insane, got no brain"
		D3bot.AssignBrain(bot)
	end
	-- Run brain "think" callback. Ideally this will resume one or more coroutines, depending on how complex the brain is.
	if mem.Brain then
		if mem.Brain.ThinkCallback then
			mem.Brain.ThinkCallback(bot)
		end
	end
	--mem.Brain = nil -- Reset brain for debug reasons

	-- Check if there is a locomotion ControlCallback
	if mem.Locomotion == nil or mem.Locomotion.ControlCallback == nil then
		cmd:ClearButtons()
		cmd:ClearMovement()
		return
	end

	-- "Don't you know I'm loco?"
	mem.Locomotion.ControlCallback(bot, cmd)
end
hook.Add("StartCommand", D3bot.HookPrefix .. "ControlDistributor", ControlDistributor)
