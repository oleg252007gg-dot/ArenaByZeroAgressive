RPG = RPG or {}
RPG.HEROES = RPG.HEROES or {}

RPG.CFG = {
    MAX_PLAYERS      = 4,
    FINAL_WAVE       = 100,
    BOSS_EVERY       = 5,
    FIRST_BREAK      = 30,
    BREAK_TIME       = 25,
    LIVES            = 3,
    ARENA_CENTER     = Vector(0, 0, 128),
    SPAWN_RADIUS     = 2300,
    START_POINTS     = 5,
    POINTS_PER_LEVEL = 3,
    STAT_GAIN        = 2,
    MAX_LEVEL        = 40,
    PERK_CHOICES     = 3,
    GOLD_PER_WAVE    = 150,
    DROP_CHANCE      = 0.07,
    ENEMY_HP_GROWTH  = 0.20,
    ENEMY_DMG_GROWTH = 0.12,
    COUNT_MULT       = 1.0,
    BOSS_HP_MULT     = 6,

    AXE_CULLING_PCT = {
        [1] = 0.12,
        [2] = 0.16,
        [3] = 0.20,
    }
}

RPG.RARITY = {
    { id = "common",    name = "Обычный",     color = "#b8b8b8", affixes = 1, mult = 1.0 },
    { id = "rare",      name = "Редкий",      color = "#4a90e2", affixes = 2, mult = 1.4 },
    { id = "epic",      name = "Эпический",   color = "#b050e0", affixes = 3, mult = 1.9 },
    { id = "legendary", name = "Легендарный", color = "#ff9a1e", affixes = 4, mult = 2.6 },
}

RPG.AFFIXES = {
    damage    = { name = "к урону",                base = 8,   step = 1.5 },
    armor     = { name = "к броне",                base = 2,   step = 0.25 },
    hp        = { name = "к здоровью",             base = 80,  step = 14 },
    mana      = { name = "к мане",                 base = 60,  step = 8 },
    ms        = { name = "к скорости движения",    base = 6,   step = 0.4 },
    as        = { name = "к скорости атаки",       base = 12,  step = 1.0 },
    crit      = { name = "% шанс крита",           base = 4,   step = 0.3,  pct = true },
    lifesteal = { name = "% вампиризм",            base = 3,   step = 0.15, pct = true },
    spellamp  = { name = "% к силе умений",        base = 4,   step = 0.4,  pct = true },
    hpregen   = { name = "к регенерации здоровья", base = 1.5, step = 0.3 },
    manaregen = { name = "к регенерации маны", base = 1,   step = 0.15 },
    cdr       = { name = "% снижение перезарядки", base = 3,   step = 0.15, pct = true },
}

RPG.GEAR = {
    item_rpg_weapon = { name = "Оружие",   pool = { "damage", "as", "crit", "lifesteal" } },
    item_rpg_armor  = { name = "Броня",    pool = { "armor", "hp", "hpregen", "ms" } },
    item_rpg_ring   = { name = "Кольцо",   pool = { "spellamp", "mana", "cdr", "hpregen" } },
    item_rpg_relic  = { name = "Реликвия", pool = { "damage", "hp", "spellamp", "cdr", "as", "lifesteal", "armor" }, min_rarity = 3 },
}

RPG.SET_IDS = { "titan", "arcane", "storm" }
RPG.SETS = {
    titan  = { name = "Титан",    bonus2 = { hp = 300, armor = 5 },       bonus3 = { damage = 40, lifesteal = 8 } },
    arcane = { name = "Арканист", bonus2 = { spellamp = 15, mana = 250 }, bonus3 = { cdr = 12, spellamp = 15 } },
    storm  = { name = "Буря",     bonus2 = { as = 40, ms = 30 },          bonus3 = { crit = 15, damage = 30 } },
}
