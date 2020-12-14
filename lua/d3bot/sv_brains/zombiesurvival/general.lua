local BRAINS = D3bot.Brains
local LOCOMOTION = D3bot.Locomotion

BRAINS.General = {
	ThinkCallback = function(bot)
		local mem = bot.D3bot
		
		if mem.Brain.Coroutine then
			succ, msg = coroutine.resume(mem.Brain.Coroutine)
			if not succ then
				mem.Brain.Coroutine = nil
			end
		end
	end,
	CreateCallback = function(bot)
		local mem = bot.D3bot
		mem.Brain.Coroutine =
			coroutine.create(
			function()
				for i = 1, 100 do
					LOCOMOTION.SinCosTest.Do(bot, 5)
					print("Done with SinCosTest number", i)
				end
			end
		)
	end
}
