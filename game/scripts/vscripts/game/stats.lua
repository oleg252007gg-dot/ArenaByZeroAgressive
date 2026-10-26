-- Сведение всех бонусов (экипировка + перки + сеты) в один модификатор героя
Stats = Stats or {}

function Stats:Empty()
	local t = {}
	for key in pairs(RPG.AFFIXES) do t[key] = 0 end
	return t
end

function Stats:Add(dst, src)
	for k, v in pairs(src) do dst[k] = (dst[k] or 0) + v end
end

function Stats:Recalc(hero)
	if not hero or hero:IsNull() or not hero.rpg then return end
	local mod = hero:FindModifierByName("modifier_rpg_stats")
	if not mod then return end

	local total = Stats:Empty()
	Stats:Add(total, hero.rpg.perk_stats)

	local sets = {}
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item and Loot:IsGear(item) then
			Loot:EnsureRolled(item)
			Stats:Add(total, item.rpg.stats)
			if item.rpg.set then sets[item.rpg.set] = (sets[item.rpg.set] or 0) + 1 end
		end
	end
	for id, count in pairs(sets) do
		local def = RPG.SETS[id]
		if count >= 2 then Stats:Add(total, def.bonus2) end
		if count >= 3 then Stats:Add(total, def.bonus3) end
	end

	mod:SetStats(total)
	hero:CalculateStatBonus(true)
	Loot:SendHeroGear(hero)
end

-- Отложенный пересчёт (инвентарь меняется пачкой событий)
function Stats:QueueRecalc(hero)
	if not hero or hero:IsNull() or hero.rpg_recalc_pending then return end
	hero.rpg_recalc_pending = true
	hero:SetContextThink("rpg_recalc", function()
		hero.rpg_recalc_pending = false
		Stats:Recalc(hero)
		return nil
	end, 0.05)
end
