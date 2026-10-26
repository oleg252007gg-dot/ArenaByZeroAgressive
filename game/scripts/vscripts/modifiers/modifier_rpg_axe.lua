-- Скрытый модификатор Axe: подслушивает стандартные скиллы и добавляет эффекты по выбранным перкам
modifier_rpg_axe = class({})

local function pc(hero, id)
	return (hero.rpg and hero.rpg.perk_count[id]) or 0
end

local function enemies_around(hero, pos, radius)
	return FindUnitsInRadius(hero:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

function modifier_rpg_axe:IsHidden() return true end
function modifier_rpg_axe:IsPurgable() return false end
function modifier_rpg_axe:RemoveOnDeath() return false end
function modifier_rpg_axe:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_rpg_axe:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ABILITY_EXECUTED }
end

function modifier_rpg_axe:OnCreated()
	if not IsServer() then return end
	self.helix_cd = false
	self:StartIntervalThink(0.05)
end

-- Контр-хеликс пассивный и события не даёт, поэтому ловим момент, когда он уходит на перезарядку
function modifier_rpg_axe:OnIntervalThink()
	local hero = self:GetParent()
	if not hero.rpg then return end
	local ab = hero:FindAbilityByName("axe_counter_helix")
	if not ab or ab:GetLevel() == 0 then return end
	if ab:GetCooldownTimeRemaining() > 0 then
		if not self.helix_cd then
			self.helix_cd = true
			self:OnHelix()
		end
	else
		self.helix_cd = false
	end
end

function modifier_rpg_axe:HelixHit(hero, damage, radius)
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
	ParticleManager:ReleaseParticleIndex(fx)
	for _, e in ipairs(enemies_around(hero, hero:GetAbsOrigin(), radius)) do
		ApplyDamage({ victim = e, attacker = hero, damage = damage, damage_type = DAMAGE_TYPE_PURE })
	end
end

function modifier_rpg_axe:OnHelix()
	local hero = self:GetParent()
	local str = hero:GetStrength()
	local mythic = pc(hero, "axe_mythic_helix") > 0
	local extra = pc(hero, "axe_helix_1") * (35 + str * 0.5)

	if pc(hero, "axe_helix_stacks") > 0 then
		local m = hero:FindModifierByName("modifier_rpg_helix_stacks")
		local stacks = m and m:GetStackCount() or 0
		extra = extra + stacks * (10 + str * 0.15)
		hero:AddNewModifier(hero, nil, "modifier_rpg_helix_stacks", { duration = 6 })
	end
	if mythic then extra = math.max(extra, 60 + str * 0.8) end

	local radius = mythic and 385 or 275
	if extra > 0 then
		self:HelixHit(hero, extra, radius)
		if mythic then
			for i = 1, 2 do
				hero:SetContextThink("rpg_axe_echo" .. i, function()
					if hero:IsAlive() then self:HelixHit(hero, extra * 0.7, radius) end
					return nil
				end, 0.25 * i)
			end
			hero:Heal(hero:GetMaxHealth() * 0.02, hero)
		end
	end

	if pc(hero, "axe_helix_fire") > 0 then
		CreateModifierThinker(hero, nil, "modifier_rpg_fire_zone",
			{ duration = 4, radius = radius, damage = 25 + str * 0.5 }, hero:GetAbsOrigin(), hero:GetTeamNumber(), false)
	end
end

function modifier_rpg_axe:OnAbilityExecuted(p)
	if not IsServer() then return end
	local hero = self:GetParent()
	if p.unit ~= hero or not hero.rpg then return end
	local name = p.ability:GetAbilityName()
	if name == "axe_berserkers_call" then
		self:OnCall(hero, p.ability)
	elseif name == "axe_culling_blade" then
		self:OnCull(hero, p.ability, p.target)
	end
end

-- Передвинуть перезарядку на долю (после старта кулдауна, поэтому с задержкой)
local function scale_cooldown(hero, ability, factor, tag)
	hero:SetContextThink(tag, function()
		local cd = ability:GetCooldownTimeRemaining()
		if cd > 0 then
			ability:EndCooldown()
			ability:StartCooldown(cd * factor)
		end
		return nil
	end, 0.03)
end

function modifier_rpg_axe:OnCall(hero, ability)
	local str = hero:GetStrength()
	local enemies = enemies_around(hero, hero:GetAbsOrigin(), 450)

	local heal_n = pc(hero, "axe_call_heal")
	if heal_n > 0 and #enemies > 0 then
		hero:Heal(hero:GetMaxHealth() * math.min(0.4, #enemies * 0.04 * heal_n), hero)
	end

	if pc(hero, "axe_call_stun") > 0 then
		for _, e in ipairs(enemies) do e:AddNewModifier(hero, nil, "modifier_stunned", { duration = 0.5 }) end
	end

	if pc(hero, "axe_call_dmg") > 0 then
		local ticks = 6
		hero:SetContextThink("rpg_axe_call_dot", function()
			if ticks <= 0 or not hero:IsAlive() then return nil end
			ticks = ticks - 1
			for _, e in ipairs(enemies_around(hero, hero:GetAbsOrigin(), 450)) do
				ApplyDamage({ victim = e, attacker = hero, damage = 20 + str * 0.5, damage_type = DAMAGE_TYPE_MAGICAL })
			end
			return 0.5
		end, 0.5)
	end

	if pc(hero, "axe_mythic_call") > 0 then
		scale_cooldown(hero, ability, 0.6, "rpg_axe_call_cd")
		hero:AddNewModifier(hero, nil, "modifier_rpg_dmg_reduction", { duration = 4, reduction = 30 })
	end
end

function modifier_rpg_axe:OnCull(hero, ability, target)
	local n = pc(hero, "axe_cull_dmg")
	if n > 0 and target and not target:IsNull() and target:IsAlive() then
		ApplyDamage({ victim = target, attacker = hero, damage = n * (150 + hero:GetStrength() * 1.5), damage_type = DAMAGE_TYPE_PURE })
	end
	if pc(hero, "axe_cull_cd") > 0 then
		scale_cooldown(hero, ability, 0.5, "rpg_axe_cull_cd")
	end
end
