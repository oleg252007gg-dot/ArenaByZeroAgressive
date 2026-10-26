modifier_axe_culling_move = class({})

function modifier_axe_culling_move:IsHidden() return false end
function modifier_axe_culling_move:IsPurgable() return false end
function modifier_axe_culling_move:GetTexture() return "axe_culling_blade" end

function modifier_axe_culling_move:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_axe_culling_move:GetModifierMoveSpeedBonus_Percentage()
    return 30
end
