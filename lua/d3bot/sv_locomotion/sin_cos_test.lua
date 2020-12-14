local LOCOMOTION = D3bot.Locomotion

LOCOMOTION.SinCosTest = {
	ControlCallback = function(bot, cmd)
		cmd:SetForwardMove(math.sin(CurTime()) * 100)
		cmd:SetSideMove(math.cos(CurTime()) * 100)
	end,
	Do = function(bot, duration)
		local mem = bot.D3bot

		local stopTime = CurTime() + duration

		mem.Locomotion = LOCOMOTION.SinCosTest -- TODO: Make a copy of the table

		while CurTime() < stopTime do
			coroutine.yield()
		end

		mem.Locomotion = nil
		
	end
}
