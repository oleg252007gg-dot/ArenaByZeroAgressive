-- Мелкие модификаторы мода (замедление, снижение урона, стаки, огненная зона)

-- Без коллизий на спавне, чтобы крипы не склеивались в кучу
modifier_rpg_phase = class({})
function modifier_rpg_phase:IsHidden() return true end
function modifier_rpg_phase:IsPurgable() return false end
function modifier_rpg_phase:CheckState()
	return { [MODIFIER_STATE_NO_UNIT_COLLISION] = true }
end

-- ===== Замедление (используется врагами) =====
modifier_rpg_slow = class({})
function modifier_rpg_slow:IsHidden() return false end
function modifier_rpg_slow:IsDebuff() return true end
function modifier_rpg_slow:IsPurgable() return true end
function modifier_rpg_slow:GetTexture() return "crystal_maiden_frostbite" end
function modifier_rpg_slow:OnCreated(kv) self.slow = kv.slow or 30 end
function modifier_rpg_slow:OnRefresh(kv) self.slow = kv.slow or 30 end
function modifier_rpg_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_slow:GetModifierMoveSpeedBonus_Percentage() return -(self.slow or 0) end

-- ===== Снижение входящего урона =====
modifier_rpg_dmg_reduction = class({})
function modifier_rpg_dmg_reduction:IsHidden() return false end
function modifier_rpg_dmg_reduction:IsPurgable() return false end
function modifier_rpg_dmg_reduction:GetTexture() return "axe_berserkers_call" end
function modifier_rpg_dmg_reduction:OnCreated(kv) self.reduction = kv.reduction or 30 end
function modifier_rpg_dmg_reduction:OnRefresh(kv) self.reduction = kv.reduction or 30 end
function modifier_rpg_dmg_reduction:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE } end
function modifier_rpg_dmg_reduction:GetModifierIncomingDamage_Percentage() return -(self.reduction or 0) end

-- ===== Стаки Вихря ярости (временные) =====
modifier_rpg_helix_stacks = class({})
function modifier_rpg_helix_stacks:IsHidden() return false end
function modifier_rpg_helix_stacks:IsPurgable() return false end
function modifier_rpg_helix_stacks:RemoveOnDeath() return false end
function modifier_rpg_helix_stacks:GetTexture() return "axe_counter_helix" end
function modifier_rpg_helix_stacks:OnCreated()
	if IsServer() then self:SetStackCount(1) end
end
function modifier_rpg_helix_stacks:OnRefresh()
	if IsServer() then self:SetStackCount(math.min(self:GetStackCount() + 1, 10)) end
end

-- ===== Стаки Палача (постоянные, +6 урона за стак) =====
modifier_rpg_cull_stacks = class({})
function modifier_rpg_cull_stacks:IsHidden() return false end
function modifier_rpg_cull_stacks:IsPurgable() return false end
function modifier_rpg_cull_stacks:RemoveOnDeath() return false end
function modifier_rpg_cull_stacks:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end
function modifier_rpg_cull_stacks:GetTexture() return "axe_culling_blade" end
function modifier_rpg_cull_stacks:OnCreated()
	if IsServer() then self:SetStackCount(1) end
end
function modifier_rpg_cull_stacks:OnRefresh()
	if IsServer() then self:SetStackCount(math.min(self:GetStackCount() + 1, 15)) end
end
function modifier_rpg_cull_stacks:DeclareFunctions() return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE } end
function modifier_rpg_cull_stacks:GetModifierPreAttack_BonusDamage() return self:GetStackCount() * 6 end

-- ===== Огненная зона (вешается на thinker) =====
modifier_rpg_fire_zone = class({})
function modifier_rpg_fire_zone:IsHidden() return true end
function modifier_rpg_fire_zone:IsPurgable() return false end

function modifier_rpg_fire_zone:OnCreated(kv)
	if not IsServer() then return end
	self.radius = kv.radius or 275
	self.damage = kv.damage or 30
	self.pos = self:GetParent():GetAbsOrigin()
	self:StartIntervalThink(0.5)
end

function modifier_rpg_fire_zone:OnIntervalThink()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then self:Destroy() return end
	-- Эффект огня; замените путь частицы, если он вам не нравится
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, self.pos)
	ParticleManager:ReleaseParticleIndex(fx)
	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), self.pos, nil, self.radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, e in ipairs(enemies) do
		ApplyDamage({ victim = e, attacker = caster, damage = self.damage, damage_type = DAMAGE_TYPE_MAGICAL })
	end
end

function modifier_rpg_fire_zone:OnDestroy()
	if IsServer() then UTIL_Remove(self:GetParent()) end
end
