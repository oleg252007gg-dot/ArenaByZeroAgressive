-- Перки: 5 редкостей. Общие перки доступны всем героям, перки героя лежат в game/heroes/<hero>.lua
Perks = Perks or {}

Perks.RARITY = {
	{ id = "common",    name = "Обычное",     color = "#b8b8b8" },
	{ id = "rare",      name = "Редкое",      color = "#4a90e2" },
	{ id = "epic",      name = "Эпическое",   color = "#b050e0" },
	{ id = "legendary", name = "Легендарное", color = "#ff9a1e" },
	{ id = "mythic",    name = "Мифическое",  color = "#ff3d6e" },
}

-- tier: 1 обычное ... 5 мифическое
Perks.GENERIC = {
	-- Обычные: базовые статы
	{ id = "c_hp",     tier = 1, name = "Стойкость",      desc = "+250 к здоровью",              stats = { hp = 250 },        max = 6 },
	{ id = "c_mana",   tier = 1, name = "Резерв маны",    desc = "+200 к мане",                  stats = { mana = 200 },      max = 6 },
	{ id = "c_armor",  tier = 1, name = "Железная кожа",  desc = "+4 к броне",                   stats = { armor = 4 },       max = 6 },
	{ id = "c_ms",     tier = 1, name = "Лёгкая поступь", desc = "+20 к скорости движения",      stats = { ms = 20 },         max = 4 },
	{ id = "c_regen",  tier = 1, name = "Регенерация",    desc = "+4 к регенерации здоровья",    stats = { hpregen = 4 },     max = 6 },
	{ id = "c_mregen", tier = 1, name = "Поток маны",     desc = "+2 к регенерации маны",        stats = { manaregen = 2 },   max = 6 },
	{ id = "c_dmg",    tier = 1, name = "Ярость",         desc = "+18 к урону",                  stats = { damage = 18 },     max = 6 },
	{ id = "c_as",     tier = 1, name = "Быстрые руки",   desc = "+20 к скорости атаки",         stats = { as = 20 },         max = 6 },

	-- Редкие: связки статов и новые умения
	{ id = "r_steel",  tier = 2, name = "Сталь и кровь",  desc = "+30 к урону, +5% вампиризм",           stats = { damage = 30, lifesteal = 5 },    max = 4 },
	{ id = "r_swift",  tier = 2, name = "Ловкач",         desc = "+40 к скорости атаки, +25 к скорости", stats = { as = 40, ms = 25 },              max = 4 },
	{ id = "r_focus",  tier = 2, name = "Фокус",          desc = "+10% снижение перезарядки, +250 к мане", stats = { cdr = 10, mana = 250 },        max = 3 },
	{ id = "r_titan",  tier = 2, name = "Кровь титана",   desc = "+400 к здоровью, +6 к регенерации",    stats = { hp = 400, hpregen = 6 },         max = 4 },
	{ id = "ab_wind",  tier = 2, name = "Второе дыхание", desc = "Новая способность: лечит вас и союзников рядом. Повторный выбор улучшает её", ability = "rpg_second_wind", max = 5 },

	-- Эпические
	{ id = "e_might",  tier = 3, name = "Мощь героя",     desc = "+50 к урону, +30 к скорости атаки, +10% крит", stats = { damage = 50, as = 30, crit = 10 }, max = 3 },
	{ id = "e_bastion",tier = 3, name = "Бастион",        desc = "+700 к здоровью, +10 к броне, +8 к регенерации", stats = { hp = 700, armor = 10, hpregen = 8 }, max = 3 },
	{ id = "e_tactic", tier = 3, name = "Тактик",         desc = "+15% перезарядка, +25% сила умений, +350 к мане", stats = { cdr = 15, spellamp = 25, mana = 350 }, max = 3 },
	{ id = "ab_burst", tier = 3, name = "Арканный взрыв", desc = "Новая способность: взрыв вокруг героя. Повторный выбор улучшает её", ability = "rpg_arcane_burst", max = 5 },

	-- Легендарные
	{ id = "l_skin",   tier = 4, name = "Божественная кожа", desc = "+1200 к здоровью, +15 к броне, +15 к регенерации", stats = { hp = 1200, armor = 15, hpregen = 15 }, max = 2 },
	{ id = "l_harvest",tier = 4, name = "Кровавая жатва",    desc = "+90 к урону, +15% вампиризм, +15% крит",             stats = { damage = 90, lifesteal = 15, crit = 15 }, max = 2 },
	{ id = "l_mind",   tier = 4, name = "Бесконечный разум", desc = "+60% сила умений, +25% перезарядка, +800 к мане",    stats = { spellamp = 60, cdr = 25, mana = 800 }, max = 2 },
}

-- Вес редкостей растёт с номером волны
function Perks:RollTier(wave)
	local w = {
		math.max(8, 70 - wave * 2.4),
		25 + wave * 0.6,
		wave >= 4 and (wave - 3) * 1.8 or 0,
		wave >= 9 and (wave - 8) * 1.1 or 0,
		wave >= 13 and (wave - 12) * 0.7 or 0,
	}
	local total = 0
	for i = 1, 5 do total = total + w[i] end
	local r = RandomFloat(0, total)
	for i = 1, 5 do
		r = r - w[i]
		if r <= 0 then return i end
	end
	return 1
end

function Perks:Eligible(hero, p)
	local r = hero.rpg
	if (r.perk_count[p.id] or 0) >= p.max then return false end
	if p.tier == 5 and r.build then return false end                       -- мифическое: один билд на героя
	if p.build and r.build and p.build ~= r.build then return false end    -- после выбора билда чужие ветки закрыты
	return true
end

function Perks:Pool(hero)
	local pool = {}
	for _, p in ipairs(Perks.GENERIC) do table.insert(pool, p) end
	local def = RPG.HEROES[hero:GetUnitName()]
	if def then
		for _, p in ipairs(def.perks) do table.insert(pool, p) end
	end
	return pool
end

-- Выбирает перк нужной редкости; если таких нет, спускается ниже
function Perks:Pick(hero, pool, tier, taken)
	local order = { tier }
	for t = tier - 1, 1, -1 do table.insert(order, t) end
	for t = tier + 1, 5 do table.insert(order, t) end
	for _, t in ipairs(order) do
		local cands, total = {}, 0
		for _, p in ipairs(pool) do
			if p.tier == t and not taken[p.id] and Perks:Eligible(hero, p) then
				local w = (p.build and hero.rpg.build == p.build) and 3 or 1   -- перки выбранного билда выпадают втрое чаще
				table.insert(cands, { p = p, w = w })
				total = total + w
			end
		end
		if #cands > 0 then
			local r = RandomFloat(0, total)
			for _, c in ipairs(cands) do
				r = r - c.w
				if r <= 0 then return c.p end
			end
			return cands[#cands].p
		end
	end
	return nil
end

function Perks:Roll(hero, wave, count)
	local pool = self:Pool(hero)
	local taken, out = {}, {}
	for slot = 1, count do
		local tier = self:RollTier(wave)
		if slot == 1 and wave >= 10 and wave % 5 == 0 then
			tier = hero.rpg.build and 4 or 5          -- награда за босса: мифическое (выбор билда) или легендарное
		elseif slot == 1 and wave % 5 == 0 then
			tier = math.max(tier, 3)
		end
		local p = self:Pick(hero, pool, tier, taken)
		if p then
			taken[p.id] = true
			table.insert(out, p)
		end
	end
	return out
end

function Perks:Find(id)
	if not self.index then
		self.index = {}
		for _, p in ipairs(Perks.GENERIC) do self.index[p.id] = p end
		for _, def in pairs(RPG.HEROES) do
			for _, p in ipairs(def.perks) do self.index[p.id] = p end
		end
	end
	return self.index[id]
end

function Perks:Payload(hero, p)
	local rar = Perks.RARITY[p.tier]
	local def = RPG.HEROES[hero:GetUnitName()]
	return {
		name = p.name, desc = p.desc, tier = p.tier, rarity = rar.name, color = rar.color,
		build = (p.build and def and def.builds and def.builds[p.build]) or "",
		count = hero.rpg.perk_count[p.id] or 0, max = p.max,
	}
end

-- Вызывается при убийстве врага; передаёт событие модулю героя
function Perks:OnKill(keys, victim)
	if not keys.entindex_attacker then return end
	local attacker = EntIndexToHScript(keys.entindex_attacker)
	if not attacker or attacker:IsNull() or not attacker.rpg then return end
	local def = RPG.HEROES[attacker:GetUnitName()]
	if def and def.on_kill then def.on_kill(attacker, keys, victim) end
end
