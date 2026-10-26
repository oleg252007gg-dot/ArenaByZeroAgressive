Loot = Loot or {}

function Loot:IsGear(item)
	return item ~= nil and not item:IsNull() and RPG.GEAR[item:GetAbilityName()] ~= nil
end

-- Выбор редкости: с ростом волны выше шанс эпиков и легенд
function Loot:RollRarity(wave, min_rarity, boost)
	boost = boost or 1
	local w = {
		math.max(15, 60 - wave * 1.2),
		25 + wave * 0.4,
		(11 + wave * 0.5) * boost,
		(4 + wave * 0.3) * boost,
	}
	local start = min_rarity or 1
	local total = 0
	for i = start, 4 do total = total + w[i] end
	local r = RandomFloat(0, total)
	for i = start, 4 do
		r = r - w[i]
		if r <= 0 then return i end
	end
	return 4
end

-- Генерация свойств предмета (хранятся в item.rpg)
function Loot:Roll(item, wave, rarity)
	local def = RPG.GEAR[item:GetAbilityName()]
	rarity = math.max(rarity or Loot:RollRarity(wave), def.min_rarity or 1)
	local rar = RPG.RARITY[rarity]

	local pool = {}
	for _, k in ipairs(def.pool) do table.insert(pool, k) end
	for i = #pool, 2, -1 do
		local j = RandomInt(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local data = { rarity = rarity, wave = wave, stats = {}, list = {} }
	for i = 1, math.min(rar.affixes, #pool) do
		local key = pool[i]
		local a = RPG.AFFIXES[key]
		local v = (a.base + a.step * wave) * rar.mult * RandomFloat(0.85, 1.15)
		v = math.floor(v * 10 + 0.5) / 10
		data.stats[key] = v
		table.insert(data.list, { key = key, value = v })
	end
	if rarity >= 3 then
		data.set = RPG.SET_IDS[RandomInt(1, #RPG.SET_IDS)]
	end
	item.rpg = data
	Loot:Publish(item)
	return data
end

-- Предметы из магазина получают свойства лениво, при первом пересчёте
function Loot:EnsureRolled(item)
	if item.rpg then return end
	local wave = math.max(1, (Waves and Waves.wave) or 1)
	Loot:Roll(item, wave, Loot:RollRarity(wave, 1, 0.5))
end

function Loot:AffixLine(key, value)
	local a = RPG.AFFIXES[key]
	return "+" .. value .. " " .. a.name
end

function Loot:StatsText(stats)
	local parts = {}
	for k, v in pairs(stats) do
		table.insert(parts, Loot:AffixLine(k, v))
	end
	return table.concat(parts, ", ")
end

function Loot:Describe(item)
	Loot:EnsureRolled(item)
	local def = RPG.GEAR[item:GetAbilityName()]
	local rar = RPG.RARITY[item.rpg.rarity]
	local lines = {}
	for _, e in ipairs(item.rpg.list) do
		table.insert(lines, Loot:AffixLine(e.key, e.value))
	end
	local title = rar.name .. " " .. string.lower(def.name)
	if item.rpg.set then
		title = title .. " [" .. RPG.SETS[item.rpg.set].name .. "]"
	end
	return { name = title, color = rar.color, lines = table.concat(lines, "\n") }
end

function Loot:Publish(item)
	if not item or item:IsNull() or not Loot:IsGear(item) then return end
	Loot:EnsureRolled(item)
	local d = Loot:Describe(item)
	CustomNetTables:SetTableValue("rpg_items", tostring(item:GetEntityIndex()), {
		name = d.name,
		color = d.color,
		lines = d.lines,
		set = item.rpg.set and RPG.SETS[item.rpg.set].name or "",
	})
end

function Loot:SendHeroGear(hero)
	if not hero or hero:IsNull() then return end
	local player = PlayerResource:GetPlayer(hero:GetPlayerOwnerID())
	if not player then return end

	local payload = { items = {}, set_text = "" }
	local n = 0
	local sets = {}
	for slot = 0, 8 do
		local item = hero:GetItemInSlot(slot)
		if item and Loot:IsGear(item) then
			Loot:EnsureRolled(item)
			Loot:Publish(item)
			if slot <= 5 then
				n = n + 1
				local d = Loot:Describe(item)
				payload.items[n] = { name = d.name, color = d.color, lines = d.lines, slot = slot }
				if item.rpg.set then
					sets[item.rpg.set] = (sets[item.rpg.set] or 0) + 1
				end
			end
		end
	end

	local bonus = {}
	for id, count in pairs(sets) do
		local def = RPG.SETS[id]
		if count >= 2 then table.insert(bonus, def.name .. " (2): " .. Loot:StatsText(def.bonus2)) end
		if count >= 3 then table.insert(bonus, def.name .. " (3): " .. Loot:StatsText(def.bonus3)) end
	end
	payload.set_text = table.concat(bonus, "\n")
	CustomGameEventManager:Send_ServerToPlayer(player, "rpg_gear_state", payload)
end

local DROP_TABLE = {
	"item_rpg_weapon", "item_rpg_weapon", "item_rpg_weapon",
	"item_rpg_armor", "item_rpg_armor", "item_rpg_armor",
	"item_rpg_ring", "item_rpg_ring", "item_rpg_ring",
	"item_rpg_relic",
}

function Loot:Drop(pos, wave, min_rarity, boost)
	local name = DROP_TABLE[RandomInt(1, #DROP_TABLE)]
	local item = CreateItem(name, nil, nil)
	Loot:Roll(item, wave, Loot:RollRarity(wave, min_rarity, boost))
	CreateItemOnPositionSync(pos, item)
	item:LaunchLoot(false, 250, 0.6, pos + RandomVector(RandomInt(80, 220)))
	CustomGameEventManager:Send_ServerToAllClients("rpg_loot", Loot:Describe(item))
end
