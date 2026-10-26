Progression = Progression or {}

function Progression:Init()
	CustomGameEventManager:RegisterListener("rpg_spend_point", function(_, data) Progression:OnSpend(data) end)
	CustomGameEventManager:RegisterListener("rpg_perk_pick", function(_, data) Progression:OnPick(data) end)
	GameRules:GetGameModeEntity():SetContextThink("rpg_progression", function()
		Progression:Think()
		return 1
	end, 1)
end

function Progression:InitHero(hero)
	hero.rpg = {
		points = RPG.CFG.START_POINTS,
		level_seen = hero:GetLevel(),
		spent = { str = 0, agi = 0, int = 0 },
		perk_stats = Stats:Empty(),
		perk_count = {},
		build = nil,         -- выбранный билд (после мифического перка)
		offer = nil,
	}
	hero:AddNewModifier(hero, nil, "modifier_rpg_stats", {})
	local def = RPG.HEROES[hero:GetUnitName()]
	if def and def.modifier then
		hero:AddNewModifier(hero, nil, def.modifier, {})
	end
	hero:AddItemByName("item_rpg_potion")
	FindClearSpaceForUnit(hero, Waves:Center() + RandomVector(250), true)
	Stats:QueueRecalc(hero)
	self:SendState(hero)
end

function Progression:GetPlayer(hero)
	return PlayerResource:GetPlayer(hero:GetPlayerOwnerID())
end

function Progression:SendState(hero)
	local player = self:GetPlayer(hero)
	if not player then return end
	CustomGameEventManager:Send_ServerToPlayer(player, "rpg_hero_state", {
		points = hero.rpg.points,
		str = hero.rpg.spent.str,
		agi = hero.rpg.spent.agi,
		int = hero.rpg.spent.int,
	})
end

-- Очки за уровни (+ периодическая пересылка состояния, чтобы HUD не терял данные при загрузке)
function Progression:Think()
	self.tick = (self.tick or 0) + 1
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if hero.rpg then
			local lvl = hero:GetLevel()
			if lvl > hero.rpg.level_seen then
				hero.rpg.points = hero.rpg.points + (lvl - hero.rpg.level_seen) * RPG.CFG.POINTS_PER_LEVEL
				hero.rpg.level_seen = lvl
				self:SendState(hero)
			elseif self.tick % 3 == 0 then
				self:SendState(hero)
			end
		end
	end
end

function Progression:OnSpend(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero.rpg then return end
	local amount = math.min(tonumber(data.amount) or 1, hero.rpg.points)
	if amount <= 0 then return end
	local gain = amount * RPG.CFG.STAT_GAIN

	if data.stat == "str" then hero:ModifyStrength(gain)
	elseif data.stat == "agi" then hero:ModifyAgility(gain)
	elseif data.stat == "int" then hero:ModifyIntellect(gain)
	else return end

	hero.rpg.points = hero.rpg.points - amount
	hero.rpg.spent[data.stat] = hero.rpg.spent[data.stat] + amount
	hero:CalculateStatBonus(true)
	self:SendState(hero)
end

-- Предложение перков (редкость растёт с волной, см. game/perks.lua)
function Progression:Offer(hero)
	local list = Perks:Roll(hero, math.max(1, Waves.wave), RPG.CFG.PERK_CHOICES)
	hero.rpg.offer = {}
	local payload = {}
	for i, p in ipairs(list) do
		hero.rpg.offer[i] = p.id
		payload[i] = Perks:Payload(hero, p)
	end
	local player = self:GetPlayer(hero)
	if player and #list > 0 then
		CustomGameEventManager:Send_ServerToPlayer(player, "rpg_perk_offer", { perks = payload })
	end
end

function Progression:OnPick(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero.rpg or not hero.rpg.offer then return end
	local id = hero.rpg.offer[tonumber(data.index)]
	if not id then return end
	hero.rpg.offer = nil
	self:Apply(hero, Perks:Find(id))
end

-- Не выбравшие до начала волны получают случайный перк из предложенных
function Progression:CloseOffers()
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if hero.rpg and hero.rpg.offer then
			local id = hero.rpg.offer[RandomInt(1, #hero.rpg.offer)]
			hero.rpg.offer = nil
			self:Apply(hero, Perks:Find(id))
		end
	end
	CustomGameEventManager:Send_ServerToAllClients("rpg_perk_close", {})
end

function Progression:Apply(hero, perk)
	if not perk then return end
	local r = hero.rpg
	r.perk_count[perk.id] = (r.perk_count[perk.id] or 0) + 1
	if perk.stats then
		Stats:Add(r.perk_stats, perk.stats)
		Stats:QueueRecalc(hero)
	end
	if perk.ability then
		self:GrantAbility(hero, perk.ability)
	end
	if perk.tier == 5 and perk.build then
		r.build = perk.build
	end
	local rar = Perks.RARITY[perk.tier]
	local who = PlayerResource:GetPlayerName(hero:GetPlayerOwnerID())
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", {
		text = (perk.tier == 5 and "★ " or "") .. who .. " [" .. rar.name .. "]: " .. perk.name,
		color = rar.color,
	})
end

-- Кастомная способность занимает скрытый слот (generic_hidden); повторный выбор повышает уровень
function Progression:GrantAbility(hero, name)
	local ab = hero:FindAbilityByName(name)
	if ab then
		if ab:GetLevel() < ab:GetMaxLevel() then ab:SetLevel(ab:GetLevel() + 1) end
		return
	end
	local hidden = hero:FindAbilityByName("generic_hidden")
	ab = hero:AddAbility(name)
	if not ab then return end
	ab:SetLevel(1)
	if hidden then
		hero:SwapAbilities("generic_hidden", name, false, true)
	end
end
