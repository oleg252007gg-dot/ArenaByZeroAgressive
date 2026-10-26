"use strict";

function Q(id) { return $("#" + id); }

// ---- Волны ----
GameEvents.Subscribe("rpg_wave_update", function (d) {
	var title = Q("WaveTitle"), info = Q("WaveInfo");
	if (d.state == "break") {
		title.text = "Волна " + (d.wave + 1) + " / " + d.final;
		info.text = "Старт через " + d.countdown + " с";
	} else if (d.state == "active") {
		title.text = "Волна " + d.wave + " / " + d.final + (d.mod ? " • " + d.mod : "");
		info.text = "Врагов: " + d.left;
	} else {
		title.text = "";
		info.text = "";
	}
	Q("LivesLabel").text = "Жизни отряда: " + d.lives;
});

// ---- Очки характеристик ----
function Spend(stat) {
	GameEvents.SendCustomGameEventToServer("rpg_spend_point", { stat: stat, amount: 1 });
}

GameEvents.Subscribe("rpg_hero_state", function (d) {
	Q("PointsLabel").text = "Очки: " + d.points;
	Q("StrLabel").text = "+ Сила (" + d.str + ")";
	Q("AgiLabel").text = "+ Ловкость (" + d.agi + ")";
	Q("IntLabel").text = "+ Интеллект (" + d.int + ")";
});

// ---- Перки ----
function PickPerk(index) {
	GameEvents.SendCustomGameEventToServer("rpg_perk_pick", { index: index });
	Q("PerkBox").AddClass("Hidden");
}

GameEvents.Subscribe("rpg_perk_offer", function (d) {
	var cards = Q("PerkCards");
	cards.RemoveAndDeleteChildren();
	// Массивы из Lua приходят как объект с ключами "1", "2", ...
	for (var k in d.perks) {
		var p = d.perks[k];
		var idx = parseInt(k, 10);
		var card = $.CreatePanel("Button", cards, "");
		card.AddClass("PerkCard");
		card.AddClass("Rarity" + p.tier);

		var rar = $.CreatePanel("Label", card, ""); rar.AddClass("PerkRarity"); rar.text = p.rarity; rar.style.color = p.color;
		var name = $.CreatePanel("Label", card, ""); name.AddClass("PerkName"); name.text = p.name;
		if (p.build) {
			var b = $.CreatePanel("Label", card, ""); b.AddClass("PerkBuild"); b.text = "Путь: " + p.build;
		}
		var desc = $.CreatePanel("Label", card, ""); desc.AddClass("PerkDesc"); desc.text = p.desc;
		var cnt = $.CreatePanel("Label", card, ""); cnt.AddClass("PerkCount"); cnt.text = "Уровень: " + p.count + " / " + p.max;

		card.SetPanelEvent("onactivate", (function (i) { return function () { PickPerk(i); }; })(idx));
	}
	Q("PerkBox").RemoveClass("Hidden");
});

GameEvents.Subscribe("rpg_perk_close", function () {
	Q("PerkBox").AddClass("Hidden");
});

// ---- Всплывающие сообщения и лут ----
function ShowToast(text, color) {
	var l = $.CreatePanel("Label", Q("ToastBox"), "");
	l.AddClass("Toast");
	l.text = text;
	l.style.color = color;
	$.Schedule(6, function () { if (l && l.IsValid()) l.DeleteAsync(0); });
}

GameEvents.Subscribe("rpg_toast", function (d) { ShowToast(d.text, d.color); });
GameEvents.Subscribe("rpg_loot", function (d) {
	var lines = (d.lines || "").replace(/\n/g, ", ");
	ShowToast("Выпало: " + d.name + " — " + lines, d.color);
});

// ---- Снаряжение: панель + тултип с реальными свойствами ----
function IsRpgGearName(name) {
	return name == "item_rpg_weapon" || name == "item_rpg_armor" || name == "item_rpg_ring" || name == "item_rpg_relic";
}

function FillItemTip(d) {
	if (!d) return;
	Q("ItemTipName").text = d.name || "";
	Q("ItemTipName").style.color = d.color || "#ffffff";
	Q("ItemTipSet").text = d.set ? ("Сет: " + d.set) : "";
	Q("ItemTipBody").text = d.lines || "";
	Q("ItemTip").RemoveClass("Hidden");
	PlaceItemTip();
}

function HideItemTip() {
	Q("ItemTip").AddClass("Hidden");
}

function PlaceItemTip() {
	var tip = Q("ItemTip");
	if (!tip || tip.BHasClass("Hidden")) return;
	var pos = GameUI.GetCursorPosition();
	var x = pos[0] + 24;
	var y = pos[1] + 18;
	tip.style.marginLeft = x + "px";
	tip.style.marginTop = y + "px";
}

function ShowRpgTipFromArgs() {
	var ent = -1;
	var name = "";
	for (var i = 0; i < arguments.length; i++) {
		var a = arguments[i];
		if (typeof a === "number" && a > 0) ent = a;
		if (typeof a === "string") name = a;
	}
	if (ent > 0) {
		var d = CustomNetTables.GetTableValue("rpg_items", String(ent));
		if (d) { FillItemTip(d); return; }
	}
	if (IsRpgGearName(name)) {
		FillItemTip({
			name: "Снаряжение арены",
			color: "#ffd24a",
			lines: "Свойства бросаются при покупке или подборе.\nНаведите на предмет уже в инвентаре — там будут точные статы.",
			set: ""
		});
		return;
	}
	HideItemTip();
}

function BindTipEvent(evt, fn) {
	try { $.RegisterForUnhandledEvent(evt, fn); } catch (e) {}
}

BindTipEvent("DOTAShowAbilityTooltipForEntityIndex", ShowRpgTipFromArgs);
BindTipEvent("DOTAShowAbilityTooltip", ShowRpgTipFromArgs);
BindTipEvent("DOTAHideAbilityTooltip", HideItemTip);

GameEvents.Subscribe("rpg_gear_state", function (d) {
	var list = Q("GearList");
	list.RemoveAndDeleteChildren();
	for (var k in d.items) {
		var it = d.items[k];
		var row = $.CreatePanel("Panel", list, "");
		row.AddClass("GearRow");
		row.hittest = true;
		var name = $.CreatePanel("Label", row, "");
		name.AddClass("GearName");
		name.text = it.name;
		name.style.color = it.color;
		var lines = $.CreatePanel("Label", row, "");
		lines.AddClass("GearLines");
		lines.text = it.lines;
		row.SetPanelEvent("onmouseover", (function (payload) {
			return function () { FillItemTip(payload); };
		})(it));
		row.SetPanelEvent("onmouseout", HideItemTip);
	}
	Q("GearSets").text = d.set_text || "";
});

(function TipFollow() {
	PlaceItemTip();
	$.Schedule(0.05, TipFollow);
})();
