local D3bot = D3bot
local LOCOMOTION = D3bot.Locomotion

-- Add new locomotion controller
function LOCOMOTION.RandomWalkTest(bot, mem, duration)
	-- Init
	mem.Locomotion = {}

	local direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()

	-- Add control callback to bot
	mem.Locomotion.Callback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetForwardMove(100)
		--cUserCmd:SetSideMove(direction[1])
		cUserCmd:SetViewAngles(direction:Angle())
		bot:SetEyeAngles(direction:Angle())
	end

	-- Wait for x amount of time
	coroutine.wait(duration)

	-- Cleanup
	mem.Locomotion = nil
end
