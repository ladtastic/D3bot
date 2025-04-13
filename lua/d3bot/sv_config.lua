D3bot.BotSeeTr = {
	mins = Vector(-15, -15, -15),
	maxs = Vector(15, 15, 15),
	mask = MASK_PLAYERSOLID
}
D3bot.NodeBlocking = {
	mins = Vector(-1, -1, -1),
	maxs = Vector(1, 1, 1),
	classes = {func_breakable = true, prop_physics = true, prop_dynamic = true, prop_door_rotating = true, func_door = true, func_physbox = true, func_physbox_multiplayer = true, func_movelinear = true}
}

D3bot.ValveNav = true							-- Enable the auto-genernated nav-mesh ( Created with "nav_generate" )
D3bot.ValveNavOverride = false					-- Enable overriding the manually created nav-mesh with the auto-generated

D3bot.NodeDamageEnts = {"prop_*turret", "prop_arsenalcrate", "prop_resupply"}

D3bot.BotAttackDistMin = 85 --100 and the bots pre-swing like they're Einstein, 75 and you need to hug them to get an attack out of them
D3bot.LinkDeathCostRaise = 300
D3bot.BotConsideringDeathCostAntichance = 3
D3bot.BotAngLerpFactor = 0.105 --0.125					-- Linear interpolation factor between the current viewing angle and target viewing angle.
D3bot.BotAttackAngLerpFactor = 0.275--0.5		-- See above, but for attacking //the higher the number, the more accurate the bots will be with their attacks/tracking on players.
D3bot.BotAimAngLerpFactor = 0.5					-- See above, but for aiming with guns
D3bot.BotAimPosVelocityOffshoot = 0.4			-- Offshoot for position prediction of moving targets in seconds. The target position is extrapolated from the moving target, whereby the target time is within the interval from now until now + the given value.
D3bot.BotJumpAntichance = 25
D3bot.BotDuckAntichance = 25
D3bot.FaceTargetOffshootFactor = 0.15 --0.2(too high for fasties/lacerators.)			-- Factor that reduces the offshoot when the target is within `D3bot.BotAttackDistMin`. Increase value to prevent bots from "locking" onto target. A value of 1.6 should yield azBot like behavior, tweak it as you like.

D3bot.ZombiesPerPlayer = 0.3
D3bot.ZombiesPerPlayerMax = 2.0			-- Limits amount of zombies to this zombie/player ratio. (ZombiesCountAddition is not calculated in)
D3bot.ZombiesPerPlayerWave = 0.20
D3bot.ZombiesPerMinute = 0
D3bot.ZombiesPerWave = 0.4
D3bot.ZombiesCountAddition = 0			-- BotMod
D3bot.SurvivorsPerPlayer = 0--1.2		-- Survivor bots per total player (non bot) amount. They will only spawn pre round.
D3bot.SurvivorCountAddition = 0			-- BotMod for survivor bots

-- Survivor (human) bots are currently not production ready.
D3bot.SurvivorsEnabled = false			-- If true, survivor bots are allowed to exists by spawning at the beginning of a round (See SurvivorsPerPlayer and SurvivorCountAddition parameters) or by redeeming.

D3bot.IsSelfRedeemEnabled = false		-- Enable or disable the !human command
D3bot.SelfRedeemWaveMax = 1				-- The maximum wave a player can respawn (Setting it to 2 would allow the players to redeem in the first and second wave)
D3bot.StartBonus = nil					-- Number of additional points, that players get at the start of a round.

D3bot.DisableBotCrows = true			-- Disable crows from being controlled by the bot

-- Uncomment the name file you want to use. If you comment out all of the name files, standard names will be used (Bot, Bot(2), Bot(3), ...)
D3bot.BotNameFile = "fakeplayers"
D3bot.UseConsoleBots = false			-- If true, bots will be spawned "the old way". But this will disable custom names.
										-- This may help if the gamemode doesn't fully support the new bot spawning.
										-- Also, this will prevent the use of other custom bots alongside D3bot.

D3bot.DisableNodeDamage = true			-- Prevents players taking damage from any "DMGPerSecond" parameter.

D3bot.BotUpdateDelay = 1 

D3bot.BotKickReason = "Team Balance"
