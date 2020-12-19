local D3bot = D3bot
local LOCOMOTION = D3bot.Locomotion

-- Add new locomotion controller
function LOCOMOTION.JumpUp(bot, mem, gestureName)
	-- Init
	mem.Locomotion = {}

	-- Press jump button
	mem.Locomotion.Callback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetButtons(IN_JUMP)
	end

	coroutine.wait(0.2)

	-- Release jump button
	mem.Locomotion.Callback = nil

	coroutine.wait(0.8)

	-- Cleanup
	mem.Locomotion = nil
end
