local roundStartTime = CurTime()
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRoundSupervisor", function()
	roundStartTime, D3bot.NodeZombiesCountAddition = CurTime(), nil 
	D3bot.ZombiesCountAddition = 0
	GAMEMODE.ShouldPopBlock = false
end)

local player_GetAll = player.GetAll
local player_GetCount = player.GetCount
local player_GetHumans = player.GetHumans
local game_MaxPlayers = game.MaxPlayers
local M_Player = FindMetaTable("Player")
local P_Team = M_Player.Team
local math_Clamp = math.Clamp
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local table_insert = table.insert
local table_sort = table.sort

local forced_player_zombies = 1

local count_target = 0

local humans_dead = 0
hook.Add("DoPlayerDeath","D3Bot.AddHumansDied.Supervisor", function(pl, attacker, dmginfo)
	local is_human = pl:Team() == TEAM_HUMAN
	--[[if is_human and (GAMEMODE.RoundEnded or GAMEMODE:GetWave() <= 1) and humans_dead < forced_player_zombies then
		humans_dead = humans_dead + 1
	end]]

	if not is_human or pl:IsBot() or GAMEMODE.RoundEnded or GAMEMODE:GetWave() <= 1 then return end

	--humans_dead = ( GAMEMODE:GetWave() == 0 and humans_dead or GAMEMODE:GetWave() == 1 and math_min(humans_dead + 1, 3) or humans_dead + 1) 
	humans_dead = humans_dead + 1
end)

hook.Add("PlayerDisconnected", "D3Bot.PlayerDisconnected.Supervisor", function(pl)
	if forced_player_zombies > 0 and GAMEMODE:GetWave() > 0 and pl:Team() == TEAM_UNDEAD then
		forced_player_zombies = forced_player_zombies - 1
	end
end)

hook.Add("PostPlayerRedeemed","D3Bot.PostPlayerRedeemed.Supervisor", function(pl, silent, noequip)
	if GAMEMODE.RoundEnded or GAMEMODE:GetWave() <= 1 --[[or player.GetCount() <= GAMEMODE.LowPopulationLimit]] then return end

	humans_dead = math_max(humans_dead - 1, 0)
end)

hook.Add("PostEndRound", "D3Bot.ResetHumansDead.Supervisor", function(winnerteam)
	humans_dead = 0
end)

function D3bot.GetDesiredBotCount()
	--If no active players then don't add any bots.
	if #player_GetHumans() == 0 then return 0 end

	if GAMEMODE.PVB then return 0 end

	local allowedTotal = game_MaxPlayers() - 2 --50
	local volunteers = math_max(GAMEMODE:GetDesiredStartingZombies(), 1)
	local botmod = D3bot.ZombiesCountAddition
	local force_players = 0 --not GAMEMODE.ZombieEscape and volunteers > 3 and forced_player_zombies or 0

	--Override if wanted for events or extreme lag.
	if GAMEMODE.ShouldPopBlock then
		return humans_dead + botmod, allowedTotal
	end

	//enable this line below when we use force_players again, it was adding an extra bot because we set it to 0 to keep bots out
	--return math_max(GAMEMODE:GetWave(), 1) - 1 + volunteers + humans_dead + botmod - force_players, allowedTotal
	-- One bot per wave unless volunteers is higher (for low pop)
	return math_max(GAMEMODE:GetWave(), 1) - 1 + volunteers + humans_dead + botmod, allowedTotal
end

local spawnAsTeam
hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
	local wave = GAMEMODE:GetWave()
	if pl:IsBot() and spawnAsTeam == TEAM_UNDEAD then
		GAMEMODE.PreviouslyDied[pl:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(pl)
	end
end)

D3bot.BotZombies = D3bot.BotZombies or {}
function D3bot.MaintainBotRoles()
	if #player_GetHumans() == 0 or GAMEMODE.RoundEnded then return end

	if team.NumPlayers(TEAM_UNDEAD) < D3bot.GetDesiredBotCount() then
		local bot = player.CreateNextBot(D3bot.GetUsername() or "BOT")
		
		spawnAsTeam = TEAM_UNDEAD

		if IsValid(bot) then
			bot:D3bot_InitializeOrReset()

			table_insert(D3bot.BotZombies, bot)

			if GAMEMODE:GetWave() <= 1 then
				bot:Kill()
			end
		end

		spawnAsTeam = nil
		
		return
	end
	if team.NumPlayers(TEAM_UNDEAD) > D3bot.GetDesiredBotCount() then
		for i=1, team.NumPlayers(TEAM_UNDEAD)-D3bot.GetDesiredBotCount() do
			if #D3bot.BotZombies > (D3bot.ZombiesCountAddition or 0) then
				local randomBot = table.remove(D3bot.BotZombies, 1)
				if IsValid(randomBot) then
					local zWeapon = randomBot:GetActiveWeapon()
					if IsValid(zWeapon) and zWeapon.StopMoaning then
						zWeapon:StopMoaning()
					end
					randomBot:StripWeapons()
				end
				return randomBot and ( randomBot:IsValid() and randomBot:Kick(D3bot.BotKickReason) )
			end
		end
	end
end

local NextNodeDamage = CurTime()
local NextMaintainBotRoles = CurTime()
function D3bot.SupervisorThinkFunction()
	if NextMaintainBotRoles < CurTime() then
		NextMaintainBotRoles = CurTime() + D3bot.BotUpdateDelay
		D3bot.MaintainBotRoles()
	end
	--[[if game.GetMap() == "gm_construct" then return end
	if (NextNodeDamage or 0) < CurTime() then
		NextNodeDamage = CurTime() + 2
		D3bot.DoNodeTrigger()
	end]]
end

function D3bot.DoNodeTrigger()
	local players = D3bot.RemoveObsDeadTgts(player_GetAll())
	players = D3bot.From(players):Where(function(k, v) return P_Team(v) ~= TEAM_UNDEAD end).R
	local ents = table.Add(players, D3bot.GetEntsOfClss(D3bot.NodeDamageEnts))
	for i, ent in pairs(ents) do
		local nodeOrNil = D3bot.MapNavMesh:GetNearestNodeOrNil(ent:GetPos()) -- TODO: Don't call GetNearestNodeOrNil that often
		if nodeOrNil then
			if type(nodeOrNil.Params.DMGPerSecond) == "number" and nodeOrNil.Params.DMGPerSecond > 0 then
				ent:TakeDamage(nodeOrNil.Params.DMGPerSecond*2, game.GetWorld(), game.GetWorld())
			end
			if ent:IsPlayer() and not ent.D3bot_Mem and nodeOrNil.Params.BotMod then
				D3bot.NodeZombiesCountAddition = nodeOrNil.Params.BotMod
			end
		end
	end
end
-- TODO: Detect situations and coordinate bots accordingly (Attacking cades, hunt down runners, spawncamping prevention)
-- TODO: If needed force one bot to flesh creeper and let him build a nest at a good place
