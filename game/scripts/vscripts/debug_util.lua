Debug = class({})

if not mode then
	mode = nil
end

if enableEndCheck == nil then
	enableEndCheck = false
end

if not debugHero then
	debugHero = nil
end

function OnTakeDamage(eventSourceIndex, args)
	mode.Players[args.PlayerID].hero:Damage()
end

function OnHealHealth(eventSourceIndex, args)
	mode.Players[args.PlayerID].hero:Heal()
end

function OnCheckEnd()
	mode.Round:CheckEndConditions()
end

function OnHealDebugHero()
	debugHero.unit:SetHealth(5)
end

function InjectFreeSelection()
	Hero.SetOwner = function(self, owner)
		self.owner = owner
		self.unit:SetControllableByPlayer(owner.id, true)
	end
end

function InjectHero(round)
	PrecacheUnitByNameAsync("npc_dota_hero_zuus", function()
		require("heroes/zeus")
		local hero = Zeus()
		local center = Entities:FindByName(nil, "map_center"):GetAbsOrigin()

		hero:SetUnit(CreateUnitByName("npc_dota_hero_zuus", center, true, nil, nil, DOTA_TEAM_BADGUYS))
		hero:Setup()
		hero.unit:SetControllableByPlayer(round.Players[0].id, true)
		
		local original = round.GetAllHeroes
		local new =
			function()
				local result = original(round)
				table.insert(result, hero)
				return result
			end

		round.GetAllHeroes = new
		debugHero = hero
	end)
end

function InjectEndCheck(round)
	local original = round.CheckEndConditions
	local new = 
		function()
			if enableEndCheck then
				original(round)
			end
		end

	round.CheckEndConditions = new
end

function InjectProjectileDebug()
	local original = Spells.ThinkFunction
	local new = 
		function(dt)
			for _, projectile in ipairs(Projectiles) do
				DebugDrawCircle(projectile.position, Vector(0, 255, 0), 255, projectile.radius, false, THINK_PERIOD)
			end

			return original(dt)
		end

	Spells.ThinkFunction = new
end

function InjectAreaDebug()
	local original = Spells.AreaDamage
	local new = 
		function(self, hero, point, area, action)
			DebugDrawCircle(point, Vector(0, 255, 0), 255, area, false, 1)

			return original(nil, hero, point, area, action)
		end

	Spells.AreaDamage = new
end

function Debug:CheckAndEnableDebug(gameMode)
	local cheatsEnabled = Convars:GetInt("sv_cheats") == 1

	CustomNetTables:SetTableValue("main", "debug", { enabled = cheatsEnabled })

	if not cheatsEnabled then
		return
	end

	mode = gameMode

	CustomGameEventManager:RegisterListener("debug_take_damage", OnTakeDamage)
	CustomGameEventManager:RegisterListener("debug_heal_health", OnHealHealth)
	CustomGameEventManager:RegisterListener("debug_heal_debug_hero", OnHealDebugHero)
	CustomGameEventManager:RegisterListener("debug_switch_end_check", function() enableEndCheck = not enableEndCheck end)
	CustomGameEventManager:RegisterListener("debug_check_end", OnCheckEnd)

	GameRules.GameMode.Round.StageTwoTimerTime = 1500
	GameRules.GameMode.Round.StageThreeTimerTime = 4000
	GameRules.GameMode.Round.UltsTimerTime = 15
	GameRules.GameMode.Round.SuddenDeathTimerTime = 60000

	GameRules.GameMode.HeroSelection.SelectionTimerTime = 2000
	GameRules.GameMode.HeroSelection.PreGameTime = 0
	
	InjectFreeSelection()
	InjectHero(GameRules.GameMode.Round)
	InjectEndCheck(GameRules.GameMode.Round)
end

if Convars:GetInt("sv_cheats") == 1 then
	InjectProjectileDebug()
	InjectAreaDebug()
end