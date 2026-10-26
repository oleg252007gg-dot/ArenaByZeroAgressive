-- Невидимый триггер: срабатывает, когда предмет попадает в слоты 0-5 или покидает их
modifier_rpg_item = class({})

function modifier_rpg_item:IsHidden() return true end
function modifier_rpg_item:IsPurgable() return false end
function modifier_rpg_item:RemoveOnDeath() return false end
function modifier_rpg_item:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_rpg_item:OnCreated()
	if not IsServer() then return end
	local item = self:GetAbility()
	if item then Loot:Publish(item) end
	Stats:QueueRecalc(self:GetParent())
end

function modifier_rpg_item:OnDestroy()
	if IsServer() then Stats:QueueRecalc(self:GetParent()) end
end
