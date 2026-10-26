# RPG Арена (Dota 2 Custom Game)

Кооп 2-4 игрока, стандартные герои, 30 волн, босс каждые 5 волн.

## Установка
1. Установите Dota 2 Workshop Tools (Steam, Dota 2 -> Свойства -> DLC -> Dota 2 Workshop Tools).
2. В Dota 2 Tools создайте аддон с именем `rpg_arena`.
3. Скопируйте:
   - `game/*`    -> `...\dota 2 beta\game\dota_addons\rpg_arena\`
   - `content/*` -> `...\dota 2 beta\content\dota_addons\rpg_arena\`
   (перезапишите addoninfo.txt)

## Карта (обязательно, я её сделать не могу)
Откройте Hammer, создайте карту `rpg_arena` (удобно взять за основу template_map / dota.vmap) и добавьте:
- `info_player_start_goodguys` (несколько штук в центре)
- `ent_dota_game_events` и `dota_world_entity`
- `ent_dota_shop` + `trigger_shop` (иначе нельзя покупать предметы)
- `info_target` с именем `arena_center` — центр арены (необязательно, иначе точка 0,0,128)
- `info_target` с именами `rpg_spawn_1` ... `rpg_spawn_8` — точки спавна врагов (необязательно, иначе кольцо вокруг центра)
- Сгенерируйте навигацию: Tools -> Build World -> Generate Nav (+ Walkable Area / GridNav)
Сохраните как `game/dota_addons/rpg_arena/maps/rpg_arena.vmap` и соберите.

## Запуск
В консоли Dota 2 Tools: `dota_launch_custom_game rpg_arena rpg_arena`
Отладка Lua: `script_reload` в консоли, ошибки видны в консоли.

## Структура
- `game/scripts/vscripts/game/config.lua` — все настройки: волны, редкости, свойства, сеты
- `.../waves.lua` — менеджер волн, модификаторы волн, боссы, вайп и «жизни»
- `.../loot.lua` — генерация предметов и дроп
- `.../progression.lua` — очки характеристик, перки, выдача кастомных способностей
- `.../stats.lua` + `modifiers/` — применение бонусов героя
- `items/`, `abilities/` — Lua-предметы и способности; KV в `scripts/npc/`
- `content/panorama/` — HUD

## Ограничения
- Сохранение прогресса между матчами в кастомках невозможно без внешнего сервера (CreateHTTPRequest).
- Пути моделей юнитов нужно проверить в Asset Browser, если крип появится без модели.
