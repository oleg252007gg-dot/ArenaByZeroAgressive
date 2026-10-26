Waves = Waves or {}

Waves.MODS = {
	swarm     = { name = "Рой",            count = 1.6, hp = 0.6 },
	fast      = { name = "Быстрые",        ms = 90 },
	armored   = { name = "Бронированные",  armor = 6, hp = 1.3 },
	explosive = { name = "Взрывные",       explode = true },
}
Waves.MOD_IDS = { "swarm", "fast", "armored", "explosive" }


function Waves:Init()
	self.wave = 0
	self.state = "idle"       -- idle -> break -> active -> break ... -> done
	self.alive = {}
	self.alive_count = 0
	self.queue = {}
	self.lives = RPG.CFG.LIVES
	self.countdown = 0
	self.players = 1
	GameRules:GetGameModeEntity():SetContextThink("rpg_waves", function() return Waves:Think() end, 1)
end

-- Центр арены: info_target с именем "arena_center" или значение из конфига
function Waves:Center()
	if not self.center then
		local ent = Entities:FindByName(nil, "arena_center")
		self.center = ent and ent:GetAbsOrigin() or RPG.CFG.ARENA_CENTER
	end
	return self.center
end

-- Точки спавна: info_target с именами rpg_spawn_1 ... rpg_spawn_8 (необязательно)
function Waves:SpawnPoints()
	if not self.spawn_points then
		self.spawn_points = {}
		for i = 1, 8 do
			local ent = Entities:FindByName(nil, "rpg_spawn_" .. i)
			if ent then table.insert(self.spawn_points, ent:GetAbsOrigin()) end
		end
	end
	return self.spawn_points
end

function Waves:Heroes(only_alive)
	local out = {}
	for _, h in ipairs(HeroList:GetAllHeroes()) do
		if h:GetTeamNumber() == DOTA_TEAM_GOODGUYS and h:IsRealHero() and (not only_alive or h:IsAlive()) then
			table.insert(out, h)
		end
	end
	return out
end

function Waves:Toast(text, color)
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = text, color = color or "#ffffff" })
end

function Waves:Broadcast()
	CustomGameEventManager:Send_ServerToAllClients("rpg_wave_update", {
		wave = self.wave,
		final = RPG.CFG.FINAL_WAVE,
		state = self.state,
		countdown = self.countdown,
		left = self.alive_count + #self.queue,
		lives = self.lives,
		mod = self.mod and Waves.MODS[self.mod].name or "",
	})
end

function Waves:Start()
	self.state = "break"
	self.countdown = RPG.CFG.FIRST_BREAK
	self:Toast("Готовьтесь! Первая волна скоро начнётся.", "#ffffff")
end

function Waves:Think()
	if self.state == "break" then
		self.countdown = self.countdown - 1
		if self.countdown <= 0 then self:StartWave() end
	elseif self.state == "active" then
		self:SpawnTick()
		if #self.queue == 0 and self.alive_count <= 0 then self:EndWave() end
	end
	if self.state ~= "idle" then self:Broadcast() end
	return 1
end

-- Состав волны (враги и боссы берутся из game/enemies.lua)
function Waves:Compose()
	local w = self.wave
	local list = {}
	local mod = self.mod and Waves.MODS[self.mod]

	if w % RPG.CFG.BOSS_EVERY == 0 then
		local idx = ((w / RPG.CFG.BOSS_EVERY) - 1) % #Enemies.BOSSES + 1
		local boss = Enemies.BOSSES[idx]
		table.insert(list, { def = boss, boss = true })
		self.boss_name = boss.name
		for _ = 1, 4 + self.players * 2 do table.insert(list, { def = Enemies:Pick(w) }) end
	else
		local n = (6 + w * 1.8) * (0.6 + 0.4 * self.players) * RPG.CFG.COUNT_MULT
		if mod and mod.count then n = n * mod.count end
		for _ = 1, math.floor(n) do table.insert(list, { def = Enemies:Pick(w) }) end
	end
	return list
end

function Waves:StartWave()
	Progression:CloseOffers()
	self.wave = self.wave + 1
	self.players = math.max(1, #self:Heroes(false))
	self.mod = nil
	local boss_wave = self.wave % RPG.CFG.BOSS_EVERY == 0
	if self.wave >= 3 and not boss_wave and RandomFloat(0, 1) < 0.5 then
		self.mod = Waves.MOD_IDS[RandomInt(1, #Waves.MOD_IDS)]
	end
	self.queue = self:Compose()
	self.state = "active"

	if boss_wave then
		self:Toast("Волна " .. self.wave .. ": БОСС — " .. self.boss_name .. "!", "#ff5a4a")
	elseif self.mod then
		self:Toast("Волна " .. self.wave .. ": " .. Waves.MODS[self.mod].name, "#ffd24a")
	else
		self:Toast("Волна " .. self.wave, "#ffffff")
	end
end

function Waves:SpawnTick()
	local per_tick = math.max(1, math.min(3, math.ceil(#self.queue / 10)))
	for _ = 1, per_tick do
		local entry = table.remove(self.queue)
		if not entry then return end
		self:SpawnUnit(entry)
	end
end

function Waves:PickSpawnPos()
	local points = self:SpawnPoints()
	self.spawn_seq = (self.spawn_seq or 0) + 1
	if #points > 0 then
		return points[(self.spawn_seq - 1) % #points + 1] + RandomVector(RandomInt(80, 320))
	end
	local ang = self.spawn_seq * 2.399963
	local r = RPG.CFG.SPAWN_RADIUS + RandomFloat(-140, 140)
	return self:Center() + Vector(math.cos(ang), math.sin(ang), 0) * r
end

function Waves:SetupEnemy(unit)
	if not unit then return end
	unit.rpg_wave = self.wave
	self.alive[unit:entindex()] = unit
	self.alive_count = self.alive_count + 1
	unit:SetAcquisitionRange(6000)
	unit:SetIdleAcquire(true)
	unit:AddNewModifier(unit, nil, "modifier_rpg_phase", { duration = 1.8 })
	unit:SetContextThink("rpg_chase", function()
		return Waves:UnitThink(unit)
	end, RandomFloat(0.05, 0.35))
	self:ChaseHero(unit)
end

function Waves:SpawnUnit(entry)
	local unit = CreateUnitByName(entry.def.unit, self:PickSpawnPos(), true, nil, nil, DOTA_TEAM_BADGUYS)
	if not unit then return end
	unit.rpg_boss = entry.boss
	self:Scale(unit, entry)
	self:SetupEnemy(unit)
	Enemies:Attach(unit, entry.def)
end

-- Прислужники, призванные в ходе волны
function Waves:SpawnMinion(name, pos)
	local unit = CreateUnitByName(name, pos + RandomVector(80), true, nil, nil, DOTA_TEAM_BADGUYS)
	if not unit then return end
	self:Scale(unit, {})
	self:SetupEnemy(unit)
end

function Waves:Scale(unit, entry)
	local w = self.wave
	local mod = self.mod and Waves.MODS[self.mod]
	local hpm = (1 + RPG.CFG.ENEMY_HP_GROWTH * (w - 1) + 0.004 * w * w) * (1 + 0.35 * (self.players - 1))
	local dmgm = 1 + RPG.CFG.ENEMY_DMG_GROWTH * (w - 1)
	if mod and mod.hp then hpm = hpm * mod.hp end
	if entry.boss then hpm = hpm * RPG.CFG.BOSS_HP_MULT; dmgm = dmgm * 1.5 end

	local hp = math.floor(unit:GetMaxHealth() * hpm)
	unit:SetBaseMaxHealth(hp)
	unit:SetMaxHealth(hp)
	unit:SetHealth(hp)

	unit:SetBaseDamageMin(math.floor(unit:GetBaseDamageMin() * dmgm))
	unit:SetBaseDamageMax(math.floor(unit:GetBaseDamageMax() * dmgm))

	local armor = unit:GetPhysicalArmorBaseValue() + w * 0.35 + ((mod and mod.armor) or 0)
	unit:SetPhysicalArmorBaseValue(armor)

	if mod and mod.ms then unit:SetBaseMoveSpeed(unit:GetBaseMoveSpeed() + mod.ms) end
	if mod and mod.explode then unit.rpg_explode = true end

	local gold = math.floor(unit:GetGoldBounty() * (1 + 0.05 * w))
	unit:SetMinimumGoldBounty(gold)
	unit:SetMaximumGoldBounty(gold)
	unit:SetDeathXP(math.floor(unit:GetDeathXP() * (1 + 0.08 * w)))
end

function Waves:ChaseHero(unit)
	if not IsValidEntity(unit) or not unit:IsAlive() then return end
	local hero = Enemies:NearestHero(unit, 12000)
	if not hero then
		local heroes = self:Heroes(true)
		if #heroes == 0 then return end
		hero = heroes[RandomInt(1, #heroes)]
	end
	ExecuteOrderFromTable({
		UnitIndex = unit:entindex(),
		OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
		TargetIndex = hero:entindex(),
		Queue = false,
	})
end

function Waves:UnitThink(unit)
	if not IsValidEntity(unit) or not unit:IsAlive() then return nil end
	if self.state ~= "active" then return 0.5 end

	local target = unit:GetAttackTarget()
	if not target or target:IsNull() then target = unit:GetAggroTarget() end
	local on_hero = target and not target:IsNull() and target:IsAlive() and target:IsRealHero()

	if on_hero and unit:IsAttacking() then
		unit.rpg_stuck = 0
		unit.rpg_last_pos = unit:GetAbsOrigin()
		return 0.5
	end

	if not on_hero or unit:IsIdle() then
		self:ChaseHero(unit)
	end
	self:Unstick(unit)
	return 0.5
end

function Waves:Unstick(unit)
	local pos = unit:GetAbsOrigin()
	local last = unit.rpg_last_pos
	unit.rpg_last_pos = pos
	if last and (pos - last):Length2D() < 50 then
		unit.rpg_stuck = (unit.rpg_stuck or 0) + 1
	else
		unit.rpg_stuck = 0
		return
	end
	if unit.rpg_stuck < 4 then return end

	unit.rpg_stuck = 0
	unit:AddNewModifier(unit, nil, "modifier_rpg_phase", { duration = 1.2 })
	local hero = Enemies:NearestHero(unit, 12000)
	if hero then
		local dir = hero:GetAbsOrigin() - pos
		if dir:Length2D() > 80 then
			FindClearSpaceForUnit(unit, pos + dir:Normalized() * 220, true)
		end
	end
	self:ChaseHero(unit)
end

function Waves:OrderAttack(unit)
	self:ChaseHero(unit)
end

function Waves:OnCreepKilled(unit)
	local idx = unit:entindex()
	if not self.alive[idx] then return end
	self.alive[idx] = nil
	self.alive_count = self.alive_count - 1

	local pos = unit:GetAbsOrigin()
	if unit.rpg_explode then self:Explode(unit, pos) end

	if unit.rpg_boss then
		for _ = 1, 2 + self.players do Loot:Drop(pos, self.wave, 3, 2) end
	elseif RandomFloat(0, 1) < RPG.CFG.DROP_CHANCE then
		Loot:Drop(pos, self.wave)
	end
end

function Waves:Explode(unit, pos)
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:ReleaseParticleIndex(fx)
	local targets = FindUnitsInRadius(DOTA_TEAM_BADGUYS, pos, nil, 260, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, t in ipairs(targets) do
		ApplyDamage({ victim = t, attacker = unit, damage = t:GetMaxHealth() * 0.08, damage_type = DAMAGE_TYPE_MAGICAL })
	end
end

-- Топот: урон и оглушение вокруг юнита
function Waves:Slam(unit, radius, mult, stun)
	local pos = unit:GetAbsOrigin()
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_ABSORIGIN, unit)
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Ursa.Earthshock", unit)
	local targets = FindUnitsInRadius(unit:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, t in ipairs(targets) do
		ApplyDamage({ victim = t, attacker = unit, damage = unit:GetAverageTrueAttackDamage(unit) * mult, damage_type = DAMAGE_TYPE_MAGICAL })
		if stun and stun > 0 then t:AddNewModifier(unit, nil, "modifier_stunned", { duration = stun }) end
	end
end

function Waves:EndWave()
	local w = self.wave
	if w >= RPG.CFG.FINAL_WAVE then
		self:Toast("Победа! Все волны отбиты!", "#ffd24a")
		self.state = "done"
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		return
	end

	self.state = "break"
	self.countdown = RPG.CFG.BREAK_TIME
	self.mod = nil
	for _, hero in ipairs(self:Heroes(false)) do
		if not hero:IsAlive() then hero:RespawnHero(false, false) end
		hero:SetHealth(hero:GetMaxHealth())
		hero:SetMana(hero:GetMaxMana())
		PlayerResource:ModifyGold(hero:GetPlayerOwnerID(), RPG.CFG.GOLD_PER_WAVE + w * 20, true, DOTA_ModifyGold_GameTick)
		Progression:Offer(hero)
	end
	self:Toast("Волна " .. w .. " отбита! Выберите улучшение и закупитесь.", "#7dff9a")
end

function Waves:CheckWipe()
	if self.state ~= "active" then return end
	if #self:Heroes(true) == 0 and #self:Heroes(false) > 0 then
		self:OnWipe()
	end
end

-- Вайпе: теряем жизнь, волна переигрывается
function Waves:OnWipe()
	self.lives = self.lives - 1
	for _, unit in pairs(self.alive) do
		unit.rpg_wave = nil
		if IsValidEntity(unit) then UTIL_Remove(unit) end
	end
	self.alive = {}
	self.alive_count = 0
	self.queue = {}

	if self.lives <= 0 then
		self:Toast("Все жизни потрачены. Поражение.", "#ff5a4a")
		self.state = "done"
		GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
		return
	end

	self.wave = self.wave - 1
	self.state = "break"
	self.countdown = RPG.CFG.BREAK_TIME
	self.mod = nil
	for _, hero in ipairs(self:Heroes(false)) do
		hero:RespawnHero(false, false)
		hero:SetHealth(hero:GetMaxHealth())
		hero:SetMana(hero:GetMaxMana())
	end
	self:Toast("Отряд повержен! Осталось жизней: " .. self.lives .. ". Волна повторится.", "#ff9a4a")
end
