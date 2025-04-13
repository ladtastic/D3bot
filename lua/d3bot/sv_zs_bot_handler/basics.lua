D3bot.Basics = {}

function D3bot.Basics.SuicideOrRetarget(bot)
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if D3bot.UsingSourceNav then return end
		
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			local handler = findHandler(bot:GetZombieClass(), bot:Team())
			if handler and handler.RerollTarget then handler.RerollTarget(bot) end
			return
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

function D3bot.Basics.Walk(bot, pos, slowdown, proximity) -- 'pos' should be inside the current or next node.
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local origin = bot:GetPos()
	local actions = {}
	
	local sideSpeed
	
	-- Check if the bot needs to climb while being on a node or going towards a node. As maneuvering while climbing is different, this will change/override some movement actions.
	local shouldClimb
	if D3bot.UsingSourceNav then
		shouldClimb = ( nodeOrNil and nodeOrNil:GetMetaData().Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.Climbing == "Needed" )
	else
		shouldClimb = ( nodeOrNil and nodeOrNil.Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil.Params.Climbing == "Needed" )
	end

	-- Make bot aim straight when outside of current node area This should prevent falling down edges.
	local aimStraight = false
	if D3bot.UsingSourceNav then
		if nodeOrNil and not navmesh.GetNavArea( origin, 8 ) then aimStraight = true end
	else
		if nodeOrNil and not nodeOrNil:GetContains(origin, nil) then aimStraight = true end
	end
	if shouldClimb then
		local wep = bot:GetActiveWeapon()
		if wep and wep:IsValid() and ( wep.GetClimbing and wep:GetClimbing() ) and wep.GetClimbSurface then
			local tr = wep:GetClimbSurface()
			if tr and tr.Hit then
				bot:D3bot_FaceTo(origin - tr.HitNormal, origin, D3bot.BotAngLerpFactor, 0)
			end
		else
			bot:D3bot_FaceTo(Vector(pos.x, pos.y, origin.z), origin, 1, 0)
		end
	else
		bot:D3bot_FaceTo(pos, origin, aimStraight and 1 or D3bot.BotAngLerpFactor, aimStraight and 0 or 1)
	end
	
	local duckParam
	local duckToParam
	local jumpParam
	local jumpToParam

	if D3bot.UsingSourceNav then
		duckParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.JumpTo
	else
		duckParam = nodeOrNil and nodeOrNil.Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil.Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	end
	
	-- Slow down bot when close to target (2D distance)
	local tempPos = Vector(pos.x, pos.y, origin.z)
	local invProximity = math.Clamp((origin:Distance(tempPos) - (proximity or 10))/60, 0, 1)
	local speed = bot:GetMaxSpeed() * (slowdown and invProximity or 1)
	
	-- Antistuck when bot is possibly stuck crouching below something
	if mem.AntiStuckTime and mem.AntiStuckTime > CurTime() then
		if not bot:Crouching() then
			mem.AntiStuckTime = nil
		else
			speed = -40
			actions.Jump = true
			actions.Attack = true
		end
	end

	local facesHindrance = not shouldClimb and bot:GetVelocity():Length2D() < 0.50 * speed - 10
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()
	
	if not facesHindrance then
		mem.lastNoHindrance = CurTime()
	end
	
	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			-- If we should climb, jump while we're on the ground
			if shouldClimb or jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				end
				if math.random(D3bot.BotDuckAntichance) == 1 then
					actions.Duck = true
				end
				-- Check if bot is possibly stuck below something
				if bot:Crouching() and not actions.Duck and (not bot.D3bot_LastDamage or bot.D3bot_LastDamage < CurTime() - 2) and (not mem.lastNoHindrance or mem.lastNoHindrance < CurTime() - 2) then
					mem.AntiStuckTime = CurTime() + 1
				end
			end
		else
			actions.Duck = true
			if shouldClimb then
				-- If we are airborne and should be climbing, try to climb the surface
				actions.Attack2 = true
				-- Calculate climbing speeds
				if bot:GetActiveWeapon() and bot:GetActiveWeapon().GetClimbing and bot:GetActiveWeapon():GetClimbing() then
					local yaw1 = bot:GetForward():Angle().Yaw
					local yaw2 = (Vector(pos.x, pos.y, origin.z) - origin):Angle().Yaw
					sideSpeed = math.AngleDifference(yaw1, yaw2)
					speed = (pos.z - origin.z + 20) * 10
					if (math.abs(speed) < 20 or bot:GetVelocity():Length() < 10) and math.abs(sideSpeed) > 1 then speed = 0 end
				end
			end
		end
	elseif minorStuck then
		-- Stuck on ladder
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end
	
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" or (not actions.Duck and bot:Crouching()) then
		actions.Jump = false
	end
	
	actions.Attack = facesHindrance
	actions.Use = actions.Use or facesHindrance
	
	if speed > 0 then actions.MoveForward = true end
	if speed < 0 then actions.MoveBackward = true end
	
	if sideSpeed and sideSpeed > 0 then actions.MoveRight = true end
	if sideSpeed and sideSpeed < 0 then actions.MoveLeft = true end
	
	return true, actions, speed, sideSpeed, nil, mem.Angs, minorStuck, majorStuck, facesHindrance
end

function D3bot.Basics.WalkAttackAuto(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local actions = {}
	local facesTgt = false
	
	-- Check if the bot needs to climb while being on a node or going towards a node. If so, ignore everything else, and use Basics.WalkAuto, which will handle everything fine. TODO: Put everything into its own basics function
	local shouldClimb
	if D3bot.UsingSourceNav then
		shouldClimb = ( nodeOrNil and nodeOrNil:GetMetaData().Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.Climbing == "Needed" )
	else
		shouldClimb = ( nodeOrNil and nodeOrNil.Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil.Params.Climbing == "Needed" )
	end

	if not IsValid(mem.TgtOrNil) then
		mem.TgtOrNil = nil
	end

	-- TODO: Reduce can see target calls
	if (shouldClimb or not bot:D3bot_CanSeeTargetCached()) and nextNodeOrNil then
		if D3bot.UsingSourceNav then
			return D3bot.Basics.Walk(bot, nextNodeOrNil:GetCenter() )
		else
			return D3bot.Basics.Walk(bot, nextNodeOrNil.Pos)
		end
	elseif mem.TgtOrNil and mem.DontAttackTgt then
		return D3bot.Basics.Walk(bot, mem.TgtOrNil:GetPos(), nil, true, mem.TgtProximity)
	elseif mem.PosTgtOrNil then
		-- Go straight to position target
		return D3bot.Basics.Walk(bot, mem.PosTgtOrNil, nil, true, mem.PosTgtProximity)
	end

	local wep = bot:GetActiveWeapon()
	local range = (wep and wep.MeleeReach or 75) + 25

	local origin = bot:GetShootPos()
	local aimPos = bot:D3bot_GetAttackPosOrNilFuture(nil, math.Rand(0, D3bot.BotAimPosVelocityOffshoot))

	if aimPos and aimPos:DistToSqr(origin) < range * range then
		facesTgt = true
			
		if aimPos.z < bot:GetPos().z + bot:GetViewOffsetDucked().z then
			actions.Duck = true
		end
	end
	
	if aimPos then
		bot:D3bot_FaceTo(aimPos, origin, D3bot.BotAttackAngLerpFactor, facesTgt and D3bot.FaceTargetOffshootFactor or 1)
	end
	
	local duckParam
	local duckToParam
	local jumpParam
	local jumpToParam

	if D3bot.UsingSourceNav then
		duckParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.JumpTo
	else
		duckParam = nodeOrNil and nodeOrNil.Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil.Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	end
	
	local speed = bot:GetMaxSpeed()
	
	-- Antistuck when bot is possibly stuck crouching below something
	if mem.AntiStuckTime and mem.AntiStuckTime > CurTime() then
		if not bot:Crouching() then
			mem.AntiStuckTime = nil
		else
			speed = -40
			actions.Jump = true
			actions.Attack = true
		end
	end

	local facesHindrance = bot:GetVelocity():Length2D() < 0.50 * speed - 10
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()
	
	if not facesHindrance then
		mem.lastNoHindrance = CurTime()
	end
	
	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				end
				if math.random(D3bot.BotDuckAntichance) == 1 then
					actions.Duck = true
				end
				-- Check if bot is possibly stuck below something
				if bot:Crouching() and not actions.Duck and (not bot.D3bot_LastDamage or bot.D3bot_LastDamage < CurTime() - 2) and (not mem.lastNoHindrance or mem.lastNoHindrance < CurTime() - 2) then
					mem.AntiStuckTime = CurTime() + 1
				end
			end
		else
			actions.Duck = true
		end
	elseif minorStuck then
		-- Stuck on ladder
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end
	
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" or (not actions.Duck and bot:Crouching()) then
		actions.Jump = false
	end
	
	actions.Attack = facesTgt or facesHindrance
	actions.Use = actions.Use or facesHindrance
	
	actions.MoveForward = true
	
	return true, actions, speed, nil, nil, mem.Angs, minorStuck, majorStuck, facesHindrance
end

function D3bot.Basics.PounceAuto(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	if not bot:IsOnGround() or bot:GetMoveType() == MOVETYPE_LADDER then return end
	
	local weapon = bot:GetActiveWeapon()
	if not weapon or not weapon.PounceVelocity or not weapon.PounceStartDelay then return end
	
	-- Fill table with possible pounce target positions, ordered with increasing priority
	local tempPos = bot:GetPos()
	local tempDist = 0
	local pounceTargetPositions = {}
	if nextNodeOrNil and D3bot.UsingSourceNav then
		tempDist = tempDist + tempPos:Distance(nextNodeOrNil:GetCenter())
		tempPos = nextNodeOrNil:GetCenter()
		table.insert(pounceTargetPositions, {Pos = nextNodeOrNil:GetCenter() + Vector(0, 0, 1),
											 Dist = tempDist,
											 TimeFactor = 1.1,
											 ForcePounce = (nextNodeOrNil:SharesLink( nodeOrNil ) and nextNodeOrNil:SharesLink( nodeOrNil ):GetMetaData().Params.Pouncing == "Needed")})
	elseif nextNodeOrNil then
		tempDist = tempDist + tempPos:Distance(nextNodeOrNil.Pos)
		tempPos = nextNodeOrNil.Pos
		table.insert(pounceTargetPositions, {Pos = nextNodeOrNil.Pos + Vector(0, 0, 1),
											 Dist = tempDist,
											 TimeFactor = 1.1,
											 ForcePounce = (nextNodeOrNil.LinkByLinkedNode[nodeOrNil] and nextNodeOrNil.LinkByLinkedNode[nodeOrNil].Params.Pouncing == "Needed")})
	end
	local i = 0
	if D3bot.UsingSourceNav then
		for k, v in ipairs(mem.RemainingNodes) do -- TODO: Check if it behaves as expected
			tempDist = tempDist + tempPos:Distance(v:GetCenter())
			tempPos = v:GetCenter()
			table.insert(pounceTargetPositions, {Pos = v:GetCenter() + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1})
			i = i + 1
			if i == 2 then break end
		end
	else
		for k, v in ipairs(mem.RemainingNodes) do -- TODO: Check if it behaves as expected
			tempDist = tempDist + tempPos:Distance(v.Pos)
			tempPos = v.Pos
			table.insert(pounceTargetPositions, {Pos = v.Pos + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1})
			i = i + 1
			if i == 2 then break end
		end
	end
	local tempAttackPosOrNil = bot:D3bot_GetAttackPosOrNilFuturePlatforms(0, mem.pounceFlightTime or 0)
	if tempAttackPosOrNil then
		tempDist = tempDist + bot:GetPos():Distance(tempAttackPosOrNil)
		table.insert(pounceTargetPositions, {Pos = tempAttackPosOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100}) -- TODO: Global bot 'IQ' level influences TimeFactor, the lower the more likely they will cut off the players path
	elseif mem.PosTgtOrNil then
		tempDist = tempDist + bot:GetPos():Distance(mem.PosTgtOrNil)
		table.insert(pounceTargetPositions, {Pos = mem.PosTgtOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100})
	end
	
	-- Find best trajectory
	local trajectory
	for _, pounceTargetPos in ipairs(table.Reverse(pounceTargetPositions)) do
		local trajectories = bot:D3bot_CanPounceToPos(pounceTargetPos.Pos)
		local timeToTarget = pounceTargetPos.Dist / bot:GetMaxSpeed()
		if trajectories and (pounceTargetPos.ForcePounce or (pounceTargetPos.HeightDiff and pounceTargetPos.Pos.z - bot:GetPos().z > pounceTargetPos.HeightDiff) or timeToTarget > (trajectories[1].t1 + (weapon.PounceStartDelay or 0))*pounceTargetPos.TimeFactor) then
			trajectory = trajectories[1]
			break
		end
	end
	
	local actions = {}
	
	if (trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= ( weapon.NextAllowPounce or 0 )) or mem.pouncing then
		if trajectory then
			mem.Angs = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
			mem.pounceFlightTime = math.Clamp(trajectory.t1 + (mem.pouncingStartTime or CurTime()) - CurTime(), 0, 1) -- Store flight time, and use it to iteratively get close to the correct intersection point.
		end
		if not mem.pouncing then
			-- Started pouncing
			actions.Attack2 = true
			mem.pouncingTimer = CurTime() + 0.9 + math.random() * 0.2
			mem.pouncingStartTime = CurTime() + weapon.PounceStartDelay
			mem.pouncing = true
		elseif mem.pouncingTimer and mem.pouncingTimer < CurTime() and (CurTime() - mem.pouncingTimer > 5 or bot:WaterLevel() >= 2 or bot:IsOnGround()) then
			-- Ended pouncing
			mem.pouncing = false
			mem.pounceFlightTime = nil
			bot:D3bot_UpdatePathProgress()
		end
		
		return true, actions, 0, nil, nil, mem.Angs, false
	end
	
	return
end

function D3bot.Basics.AimAndShoot(bot, target, maxDistance)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local actions = {}
	local reloading
	
	if not IsValid(target) then return end
	local weapon = bot:GetActiveWeapon()
	if not IsValid(weapon) then return end
	if weapon:Clip1() == 0 then reloading = true end
	if (weapon.GetNextReload and weapon:GetNextReload() or 0) > CurTime() - 0.5 then -- Subtract half a second, so it will re-trigger reloading if possible
		reloading = true
	end
	actions.Reload = reloading and math.random(5) == 1
	
	local origin = bot:D3bot_GetViewCenter()
	local targetPos = LerpVector(mem.AimHeightFactor or 1, target:GetPos(), target:EyePos())
	
	if maxDistance and origin:DistToSqr(targetPos) > math.pow(maxDistance, 2) then return end
	
	-- TODO: Use fewer traces, cache result for a few frames.
	local tr = util.TraceLine({
		start = origin,
		endpos = targetPos,
		filter = player.GetAllNoCopy(),
		mask = MASK_SHOT_HULL
	})
	local canShootTarget = not tr.Hit
	
	if not canShootTarget then mem.AimHeightFactor = math.Rand(0.5, 1) end
	
	actions.Attack = not reloading and bot:D3bot_IsLookingAt(targetPos, 0.8) and canShootTarget and not mem.WasPressingAttack
	mem.WasPressingAttack = actions.Attack
	
	if targetPos and canShootTarget then
		bot:D3bot_FaceTo(targetPos, origin, D3bot.BotAimAngLerpFactor, 0)
	end
	
	return true, actions, 0, nil, nil, mem.Angs, false
end

function D3bot.Basics.LookAround(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end

	if math.random(200) == 1 then mem.LookTarget = table.Random(player.GetAll()) end
	
	if not IsValid(mem.LookTarget) then return end
	
	local origin = bot:D3bot_GetViewCenter()
	
	bot:D3bot_FaceTo(mem.LookTarget:D3bot_GetViewCenter(), origin, D3bot.BotAngLerpFactor * 0.3, 0)
	
	return true, nil, 0, nil, nil, mem.Angs, false
end
