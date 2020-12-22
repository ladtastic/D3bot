local D3bot = D3bot
local LOCOMOTION = D3bot.Locomotion

-- Add new locomotion controller
function LOCOMOTION.Gesture(bot, mem, gestureName)
	-- Init
	mem.Locomotion = {}

	-- BUG: Gestures don't seem to work with this kind of bot entities
	local duration = bot:SetSequence(gestureName)
	bot:ResetSequenceInfo()
	bot:SetCycle(0)
	bot:SetPlaybackRate(1)

	coroutine.wait(duration)

	-- Cleanup
	mem.Locomotion = nil
end
