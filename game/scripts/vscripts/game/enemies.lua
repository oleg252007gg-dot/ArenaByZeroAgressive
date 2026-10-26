-- Враги: ростер по волнам + поведения (способности), которые крутятся на каждом юните
Enemies = Enemies or {}

-- min: с какой волны появляется, weight: частота. behaviors: список из Enemies.BEHAVIORS
Enemies.ROSTER = {
	{ unit = "npc_rpg_creep_melee",    min = 1,  weight = 30 },
	{ unit = "npc_rpg_creep_ranged",   min = 1,  weight = 18 },
	{ unit = "npc_rpg_wolf",           min = 2,  weight = 22, behaviors = { "leap" } },
	{ unit = "npc_rpg_creep_brute",    min = 3,  weight = 12 },
	{ unit = "npc_rpg_satyr",          min = 4,  weight = 14, behaviors = { "curse" } },
	{ unit = "npc_rpg_kobold_healer",  min = 5,  weight = 8,  behaviors = { "heal_pulse" } },
	{ unit = "npc_rpg_ghost",          min = 7,  weight = 12, behaviors = { "drain" } },
	{ unit = "npc_rpg_centaur",        min = 8,  weight = 10, behaviors = { "stomp" }, stomp = { radius = 330, mult = 1.5, stun = 1.0, cd = 8 } },
	{ unit = "npc_rpg_troll_summoner", min = 9,  weight = 7,  behaviors = { "summon" }, summon = "npc_rpg_creep_melee", summon_count = 2, summon_cd = 14 },
	{ unit = "npc_rpg_golem",          min = 11, weight = 6,  behaviors = { "shield" } },
}

-- Боссы по порядку (волна 5, 10, 15, ...)
Enemies.BOSSES = {
	{ name = "Каменный голем", unit = "npc_rpg_boss_golem",   behaviors = { "stomp", "shield" },
	  stomp = { radius = 380, mult = 2.0, stun = 1.2, cd = 7 } },
	{ name = "Огр-вожак",      unit = "npc_rpg_boss_ogre",    behaviors = { "stomp", "summon" },
	  stomp = { radius = 400, mult = 2.0, stun = 1.2, cd = 8 }, summon = "npc_rpg_creep_brute", summon_count = 2, summon_cd = 16 },
	{ name = "Король троллей", unit = "npc_rpg_boss_troll",   behaviors = { "summon", "heal_pulse", "curse" },
	  summon = "npc_rpg_satyr", summon_count = 3, summon_cd = 12 },
	{ name = "Призрачный лорд", unit = "npc_rpg_boss_ghost",  behaviors = { "drain", "leap", "curse" } },
	{ name = "Вождь кентавров", unit = "npc_rpg_boss_centaur", behaviors = { "stomp", "leap" },
	  stomp = { radius = 420, mult = 2.2, stun = 1.5, cd = 7 } },
	{ name = "Рошан",          unit = "npc_rpg_boss_roshan",  behaviors = { "stomp", "shield", "summon" },
	  stomp = { radius = 450, mult = 2.5, stun = 1.5, cd = 7 }, summon = "npc_rpg_golem", summon_count = 2, summon_cd = 18 },
}

function Enemies:Pick(wave)
	local total = 0
	for _, e in ipairs(self.ROSTER) do
		if wave >= e.min then total = total + e.weight end
	end
	local r = RandomFloat(0, total)
	for _, e in ipairs(self.ROSTER) do
		if wave >= e.min then
			r = r - e.weight
			if r <= 0 then return e end
		end
	end
	return self.ROSTER[1]
end

function Enemies:NearestHero(unit, radius)
	local list = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_CLOSEST, false)
	return list[1]
end

-- Запуск поведений на юните (проверка раз в 0.5 с)
function Enemies:Attach(unit, def)
	if not def.behaviors then return end
	unit.rpg_cd = {}
	unit:SetContextThink("rpg_ai", function()
		if not IsValidEntity(unit) or not unit:IsAlive() then return nil end
		local now = GameRules:GetGameTime()
		for _, b in ipairs(def.behaviors) do
			local f = Enemies.BEHAVIORS[b]
			if f and (unit.rpg_cd[b] or 0) <= now then
				local cd = f(unit, def)           -- функция возвращает перезарядку, если сработала
				if cd then unit.rpg_cd[b] = now + cd end
			end
		end
		return 0.5
	end, RandomFloat(0.5, 2))
end

-- Функция возвращает перезарядку (сек) если способность использована, иначе nil
Enemies.BEHAVIORS = {
	-- Рывок к ближайшему герою с ударом
	leap = function(u)
		local h = Enemies:NearestHero(u, 800)
		if not h then return nil end
		local dir = h:GetAbsOrigin() - u:GetAbsOrigin()
		if dir:Length2D() < 250 then return nil end
		FindClearSpaceForUnit(u, h:GetAbsOrigin() - dir:Normalized() * 120, true)
		ApplyDamage({ victim = h, attacker = u, damage = u:GetAverageTrueAttackDamage(h) * 1.5, damage_type = DAMAGE_TYPE_PHYSICAL })
		return 9
	end,

	-- Проклятие: замедление и урон
	curse = function(u)
		local h = Enemies:NearestHero(u, 700)
		if not h then return nil end
		h:AddNewModifier(u, nil, "modifier_rpg_slow", { duration = 3, slow = 40 })
		ApplyDamage({ victim = h, attacker = u, damage = 30 + (u.rpg_wave or 1) * 6, damage_type = DAMAGE_TYPE_MAGICAL })
		return 8
	end,

	-- Лечение союзников вокруг
	heal_pulse = function(u)
		local allies = FindUnitsInRadius(u:GetTeamNumber(), u:GetAbsOrigin(), nil, 500, DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		local healed = false
		for _, a in ipairs(allies) do
			if a:GetHealth() < a:GetMaxHealth() * 0.9 then
				a:Heal(a:GetMaxHealth() * 0.12, u)
				healed = true
			end
		end
		return healed and 6 or nil
	end,

	-- Высасывание здоровья у героя
	drain = function(u)
		local h = Enemies:NearestHero(u, 650)
		if not h then return nil end
		local dmg = h:GetMaxHealth() * 0.06
		ApplyDamage({ victim = h, attacker = u, damage = dmg, damage_type = DAMAGE_TYPE_MAGICAL })
		u:Heal(dmg * 2, u)
		return 7
	end,

	-- Топот: урон и оглушение вокруг
	stomp = function(u, def)
		local s = def.stomp or {}
		local radius = s.radius or 330
		if not Enemies:NearestHero(u, radius * 0.8) then return nil end
		Waves:Slam(u, radius, s.mult or 1.5, s.stun or 1.0)
		return s.cd or 8
	end,

	-- Призыв прислужников
	summon = function(u, def)
		if Waves.alive_count >= 70 or not Enemies:NearestHero(u, 1400) then return nil end
		for _ = 1, def.summon_count or 2 do
			Waves:SpawnMinion(def.summon or "npc_rpg_creep_melee", u:GetAbsOrigin() + RandomVector(150))
		end
		return def.summon_cd or 14
	end,

	-- Каменная кожа: -70% урона на 3 с, когда здоровье упало
	shield = function(u)
		if u:GetHealth() > u:GetMaxHealth() * 0.7 or not Enemies:NearestHero(u, 400) then return nil end
		u:AddNewModifier(u, nil, "modifier_rpg_dmg_reduction", { duration = 3, reduction = 70 })
		return 12
	end,
}
