local D3bot = D3bot
local UTIL = D3bot.Util
local BRAINS = D3bot.Brains
local LOCOMOTION = D3bot.Locomotion

-- Add new brain
function BRAINS.General(bot, mem)
	-- Init brain
	mem.Brain = {}

	-- Add main handler
	local mainCoroutine =
		coroutine.create(
		function()
			-- Walk in an arc for 3 seconds
			LOCOMOTION.SinCosTest(bot, mem, 3)

			-- Walk in some random directino for 3 seconds
			LOCOMOTION.RandomWalkTest(bot, mem, 3)

			-- Wait 2 seconds
			coroutine.wait(2)

			-- A new brain will be assigned at the end of all logic
		end
	)

	-- Setup think callback for the coroutine
	mem.Brain.Callback = function(bot, mem)
		if not UTIL.ResumeCoroutine(bot, mem, mainCoroutine) then
			-- Delete brain on end of coroutine
			mem.Brain = nil
		end
	end

	--print("Assigned brain to bot", bot)
end
