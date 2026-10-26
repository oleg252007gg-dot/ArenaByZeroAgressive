-- Все предметы снаряжения живут в одном файле (в KV у них одинаковый ScriptFile)
LinkLuaModifier("modifier_rpg_item", "modifiers/modifier_rpg_item", LUA_MODIFIER_MOTION_NONE)

item_rpg_weapon = class({})
item_rpg_armor  = class({})
item_rpg_ring   = class({})
item_rpg_relic  = class({})
item_rpg_potion = class({})

for _, cls in pairs({ item_rpg_weapon, item_rpg_armor, item_rpg_ring, item_rpg_relic }) do
	function cls:GetIntrinsicModifierName() return "modifier_rpg_item" end
end

-- Реликвия: активная способность, сила зависит от волны выпадения и интеллекта
function item_rpg_relic:OnSpellStart()
	local caster = self:GetCaster()
	local pos = caster:GetAbsOrigin()
	Loot:EnsureRolled(self)

	local damage = 120 + self.rpg.wave * 12 + caster:GetIntellect(false) * 1.5
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_crystal_maiden/maiden_crystal_nova.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 1, Vector(600, 2, 600))
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Crystal.CrystalNova", caster)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, 600, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, e in ipairs(enemies) do
		ApplyDamage({ victim = e, attacker = caster, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL, ability = self })
	end
end

-- Зелье: лечит 40% здоровья и 25% маны
function item_rpg_potion:OnSpellStart()
	local caster = self:GetCaster()
	caster:Heal(caster:GetMaxHealth() * 0.4, caster)
	caster:GiveMana(caster:GetMaxMana() * 0.25)
	self:SpendCharge()
end
