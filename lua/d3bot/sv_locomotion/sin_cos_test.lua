local D3bot = D3bot
local LOCOMOTION = D3bot.Locomotion

-- Add new locomotion controller
function LOCOMOTION.SinCosTest(bot, mem, duration)
	-- Init
	mem.Locomotion = {}

	-- Add control callback to bot
	mem.Locomotion.Callback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetForwardMove(math.sin(CurTime()) * 100)
		cUserCmd:SetSideMove(math.cos(CurTime()) * 100)
	end

	-- Wait for x amount of time
	--local stopTime = CurTime() + duration
	--while CurTime() < stopTime do
	--	coroutine.yield()
	--end
	coroutine.wait(duration)

	-- Cleanup
	mem.Locomotion = nil
end
