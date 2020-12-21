local D3bot = D3bot
local UTIL = D3bot.Util
local BRAINS = D3bot.Brains
local LOCOMOTION = D3bot.Locomotion

-- Add new brain class.
BRAINS.GENERAL = BRAINS.GENERAL or {}
local THIS_BRAIN = BRAINS.GENERAL

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- This will assign the brain to the given bot (and the corresponding mem).
function THIS_BRAIN:AssignToBot(bot, mem)
	local brain = {Bot = bot, Mem = mem}

	setmetatable(brain, self)
	self.__index = self

	-- Add main handler
	brain.MainCoroutine = coroutine.create(THIS_BRAIN.Think_Coroutine)

	mem.Brain = brain
	return true
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Think coroutine. Put all the important stuff in here.
function THIS_BRAIN:Think_Coroutine(bot, mem)

	-- Walk in an arc for 3 seconds
	LOCOMOTION.SinCosTest(bot, mem, 3)

	-- Walk in some random direction for 3 seconds
	LOCOMOTION.RandomWalkTest(bot, mem, 3)

	-- Wait 2 seconds
	coroutine.wait(2)

	-- A new brain will be assigned automatically after here
end

-- Think callback. Ideally this will resume coroutine(s).
function THIS_BRAIN:Callback(bot, mem)
	-- Resume coroutine, catch and print any error
	local succ, msg = coroutine.resume(self.MainCoroutine, self, bot, mem)
	if not succ then
		-- Coroutine ended unexpectedly
		print(string.format("%s %s of bot %s failed: %s", D3bot.PrintPrefix, self.MainCoroutine, bot:Nick(), msg))
		-- Assign ON_ERROR brain that does some stupid animations to prevent the errornous brain to be assigned again immediately (Spam prevention)
		BRAINS.ON_ERROR:AssignToBot(bot, mem)
		return false
	end

	-- Delete brain when the coroutine ends
	if coroutine.status(self.MainCoroutine) == "dead" then
		mem.Brain = nil
	end

	return true
end
