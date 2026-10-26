-- Эталон героя: Axe. Три билда: Вихрь (Counter Helix), Клич (Berserker's Call), Палач (Culling Blade).
-- Чтобы добавить другого героя, скопируйте этот файл, поменяйте имя героя, билды и перки,
-- и напишите модификатор по образцу modifiers/modifier_rpg_axe.lua
RPG.HEROES["npc_dota_hero_axe"] = {
	modifier = "modifier_rpg_axe",
	builds = { helix = "Вихрь", call = "Клич", exec = "Палач" },

	perks = {
		-- ===== Билд «Вихрь» =====
		{ id = "axe_helix_1",     tier = 2, build = "helix", name = "Острый вихрь",
		  desc = "Контр-хеликс при срабатывании наносит +35 (+0.5 за силу) чистого урона. За уровень", max = 3 },
		{ id = "axe_helix_fire",  tier = 3, build = "helix", name = "Пылающий вихрь",
		  desc = "После срабатывания Контр-хеликса вокруг остаётся огненная зона на 4 с", max = 1 },
		{ id = "axe_helix_stacks",tier = 4, build = "helix", name = "Вихрь ярости",
		  desc = "Каждое срабатывание Контр-хеликса даёт стак (до 10, 6 с): каждый стак усиливает вихрь на +10 (+0.15 за силу) урона", max = 1 },
		{ id = "axe_mythic_helix",tier = 5, build = "helix", name = "Око бури",
		  desc = "БИЛД «ВИХРЬ». Радиус вихря +40%, каждое срабатывание повторяется ещё дважды (эхо 70% урона) и лечит 2% здоровья", max = 1 },

		-- ===== Билд «Клич» =====
		{ id = "axe_call_heal",   tier = 2, build = "call", name = "Железная глотка",
		  desc = "Клич лечит вас на 4% здоровья за каждого врага вокруг (до 40%). За уровень", max = 3 },
		{ id = "axe_call_stun",   tier = 3, build = "call", name = "Раскат грома",
		  desc = "Клич оглушает всех врагов вокруг на 0.5 с", max = 1 },
		{ id = "axe_call_dmg",    tier = 4, build = "call", name = "Ярость берсерка",
		  desc = "После Клича 3 с наносится урон врагам вокруг каждые 0.5 с: 20 (+0.5 за силу)", max = 1 },
		{ id = "axe_mythic_call", tier = 5, build = "call", name = "Владыка клича",
		  desc = "БИЛД «КЛИЧ». Перезарядка Клича -40%, после Клича вы получаете -30% входящего урона на 4 с", max = 1 },

		-- ===== Билд «Палач» =====
		{ id = "axe_cull_dmg",    tier = 2, build = "exec", name = "Острие палача",
		  desc = "Клинок палача наносит +150 (+1.5 за силу) чистого урона по цели. За уровень", max = 3 },
		{ id = "axe_exec_heal",   tier = 3, build = "exec", name = "Охота за головами",
		  desc = "Каждое убийство лечит вас на 3% здоровья. За уровень", max = 2 },
		{ id = "axe_cull_cd",     tier = 4, build = "exec", name = "Гильотина",
		  desc = "Перезарядка Клинка палача уменьшается вдвое", max = 1 },
		{ id = "axe_mythic_cull", tier = 5, build = "exec", name = "Палач",
		  desc = "БИЛД «ПАЛАЧ». Убийство Клинком мгновенно сбрасывает его перезарядку и навсегда даёт +6 к урону (до 15 стаков)", max = 1 },
	},

	on_kill = function(hero, keys, victim)
		local r = hero.rpg.perk_count
		if (r.axe_exec_heal or 0) > 0 then
			hero:Heal(hero:GetMaxHealth() * 0.03 * r.axe_exec_heal, hero)
		end
		if (r.axe_mythic_cull or 0) > 0 and keys.entindex_inflictor then
			local inf = EntIndexToHScript(keys.entindex_inflictor)
			if inf and not inf:IsNull() and inf.GetAbilityName and inf:GetAbilityName() == "axe_culling_blade" then
				inf:EndCooldown()
				hero:AddNewModifier(hero, nil, "modifier_rpg_cull_stacks", {})
			end
		end
	end,
}
