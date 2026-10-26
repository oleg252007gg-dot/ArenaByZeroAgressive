require("game/config")
require("game/stats")
require("game/loot")
require("game/perks")
require("game/heroes/axe")
require("game/enemies")
require("game/progression")
require("game/waves")

LinkLuaModifier("modifier_rpg_stats", "modifiers/modifier_rpg_stats", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_item", "modifiers/modifier_rpg_item", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_axe", "modifiers/modifier_rpg_axe", LUA_MODIFIER_MOTION_NONE)
for _, name in ipairs({ "modifier_rpg_slow", "modifier_rpg_dmg_reduction", "modifier_rpg_helix_stacks", "modifier_rpg_cull_stacks", "modifier_rpg_fire_zone", "modifier_rpg_phase" }) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_misc", LUA_MODIFIER_MOTION_NONE)
end

if RPGArena == nil then RPGArena = class({}) end

function Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_crystal_maiden/maiden_crystal_nova.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
	for _, name in ipairs({
		"npc_rpg_creep_melee", "npc_rpg_creep_ranged", "npc_rpg_creep_brute", "npc_rpg_wolf", "npc_rpg_satyr",
		"npc_rpg_kobold_healer", "npc_rpg_ghost", "npc_rpg_centaur", "npc_rpg_troll_summoner", "npc_rpg_golem",
		"npc_rpg_boss_golem", "npc_rpg_boss_ogre", "npc_rpg_boss_troll", "npc_rpg_boss_ghost", "npc_rpg_boss_centaur", "npc_rpg_boss_roshan",
	}) do
		PrecacheUnitByNameSync(name, context)
	end
end

function Activate()
	GameRules.RPG = RPGArena()
	GameRules.RPG:InitGameMode()
end

function RPGArena:InitGameMode()
	local gm = GameRules:GetGameModeEntity()

	-- Команды: игроки против волн
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, RPG.CFG.MAX_PLAYERS)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)

	-- Тайминги и правила
	GameRules:SetHeroSelectionTime(40)
	GameRules:SetStrategyTime(0)
	GameRules:SetShowcaseTime(0)
	GameRules:SetPreGameTime(5)
	GameRules:SetPostGameTime(30)
	GameRules:SetStartingGold(500)
	GameRules:SetGoldPerTick(0)
	GameRules:SetFirstBloodActive(false)
	GameRules:SetSameHeroSelectionEnabled(false)
	GameRules:SetUseUniversalShopMode(true)

	gm:SetBuybackEnabled(false)
	gm:SetLoseGoldOnDeath(false)
	gm:SetFixedRespawnTime(20)
	gm:SetDaynightCycleDisabled(true)
	gm:SetFogOfWarDisabled(true)
	gm:SetRecommendedItemsDisabled(true)

	-- Свои уровни героя
	local xp = {}
	for lvl = 1, RPG.CFG.MAX_LEVEL do
		xp[lvl] = math.floor(90 * (lvl - 1) ^ 1.75)
	end
	gm:SetUseCustomHeroLevels(true)
	gm:SetCustomHeroMaxLevel(RPG.CFG.MAX_LEVEL)
	gm:SetCustomXPRequiredToReachNextLevel(xp)

	Progression:Init()
	Waves:Init()

	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(RPGArena, "OnStateChange"), self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap(RPGArena, "OnNpcSpawned"), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(RPGArena, "OnEntityKilled"), self)
end

function RPGArena:OnStateChange()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		Waves:Start()
	end
end

function RPGArena:OnNpcSpawned(keys)
	local unit = EntIndexToHScript(keys.entindex)
	if unit and not unit:IsNull() and unit:IsRealHero() and not unit.rpg then
		Progression:InitHero(unit)
	end
end

function RPGArena:OnEntityKilled(keys)
	local unit = EntIndexToHScript(keys.entindex_killed)
	if not unit or unit:IsNull() then return end
	if unit.rpg_wave then
		Waves:OnCreepKilled(unit)
		Perks:OnKill(keys, unit)
	elseif unit:IsRealHero() then
		Waves:CheckWipe()
	end
end
