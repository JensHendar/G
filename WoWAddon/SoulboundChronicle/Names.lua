local _, ns = ...

-- Gives items better names. Names are generated from a stored seed (so
-- they stay put), earned through deeds, or chosen by the player.
local N = {}
ns.Names = N

local MAX_QUALITY = 4    -- up to epic
local RARE_QUALITY = 3   -- blue and up can be switched off
local MAX_LENGTH = 40
local SLAYER_KILLS = 100
local FAITHFUL_LEVELS = 10
local CURSED_DEATHS = 5
local HOVER_MEMORY = 60
local BANE_TIER = { elite = 1, rare = 2, rareelite = 3, boss = 4, worldboss = 5 }

local WEAPONS = {
	[0] = "axe", [1] = "axe", [2] = "bow", [3] = "gun", [4] = "mace", [5] = "mace",
	[6] = "polearm", [7] = "sword", [8] = "sword", [10] = "staff", [13] = "fist",
	[15] = "dagger", [16] = "thrown", [18] = "crossbow", [19] = "wand", [20] = "fishing",
}
local SLOTS = {
	INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder",
	INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WAIST = "waist",
	INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist",
	INVTYPE_HAND = "hands", INVTYPE_FINGER = "finger", INVTYPE_TRINKET = "trinket",
	INVTYPE_CLOAK = "back", INVTYPE_SHIELD = "shield", INVTYPE_HOLDABLE = "holdable",
	INVTYPE_BODY = "shirt", INVTYPE_TABARD = "tabard",
}
-- Fixed order so ties between stats always resolve the same way.
local STATS = {
	{ "ITEM_MOD_STRENGTH_SHORT", "strength" },
	{ "ITEM_MOD_AGILITY_SHORT", "agility" },
	{ "ITEM_MOD_STAMINA_SHORT", "stamina" },
	{ "ITEM_MOD_INTELLECT_SHORT", "intellect" },
	{ "ITEM_MOD_SPIRIT_SHORT", "spirit" },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function itemKind(itemID)
	local _, _, _, equipLoc, _, classID, subclassID = ns.GetItemInfoInstant(itemID)
	if classID == 2 then return WEAPONS[subclassID] or "generic", true end
	return SLOTS[equipLoc] or "generic", false
end

local function quality(rec, link)
	local _, _, q = ns.GetItemInfo(link or rec.id)
	return q
end

local function theme(link)
	if not link or not ns.GetItemStats then return end
	local ok, stats = pcall(ns.GetItemStats, link)
	if not ok or not stats then return end
	local best, bestValue
	for _, stat in ipairs(STATS) do
		local value = stats[stat[1]]
		if value and (not bestValue or value > bestValue) then
			best, bestValue = stat[2], value
		end
	end
	return best
end

-- Cuts a string to at most max characters without splitting a UTF-8
-- character in half.
local function truncate(s, max)
	local count, cut = 0, #s
	for pos in s:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
		count = count + 1
		if count > max then
			cut = pos - 1
			break
		end
	end
	return s:sub(1, cut)
end

function N.Clean(name, max)
	-- Drop colour codes, links and textures, then any stray escape bars.
	name = (name or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|", ""):gsub("%c", " ")
	return truncate(strtrim(name), max or MAX_LENGTH)
end

-- Words every name template can use.
local function words(rec, L)
	local S = ns.Stories
	local names = L.names
	local seed = rec.seed or 0
	local kind, isWeapon = itemKind(rec.id)
	local start = S.Pick(names.compoundStart, seed, 23)
	local endings = names.compoundEnd[isWeapon and "weapon" or "armor"]
	local ending = S.Pick(endings, seed, 19)
	-- Avoid doubled letters at the seam, like "Thunderreaver".
	if start:sub(-1):lower() == ending:sub(1, 1) then ending = S.Pick(endings, seed, 20) end
	return {
		noun = S.Pick(names.nouns[kind] or names.nouns.generic, seed, 3),
		person = S.Pick(names.persons, seed, 17),
		zone = rec.z ~= "" and rec.z or "Azeroth",
		compound = start .. ending,
		epithet = S.Pick(names.epithets, seed, 29),
	}
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- The creature type a weapon has slain at least SLAYER_KILLS of (the most
-- slain one if several), and how many.
local function slayerType(rec)
	local best, count
	for ctype, n in pairs(rec.slain or {}) do
		if n >= SLAYER_KILLS and (not count or n > count or (n == count and ctype < best)) then
			best, count = ctype, n
		end
	end
	return best, count
end

-- The name an item has earned through its deeds, if any. Deeds stack:
-- [Cursed] [Old Faithful] [Beastslayer's] Sword[, Bane of Mother Fang].
-- Returns the name, the reasons, and a key that changes only when the
-- set of deeds changes.
local function earned(rec, L)
	local S = ns.Stories
	local names = L.names
	local why = names.why
	local reasons, keys, prefixes = {}, {}, {}
	local _, isWeapon = itemKind(rec.id)
	local vars = words(rec, L)

	local bane = isWeapon and rec.bane and rec.bane.n
	if bane then
		table.insert(reasons, S.Format(why.bane, { name = bane }))
		table.insert(keys, "bane:" .. bane)
	end

	local ctype, count
	if isWeapon then ctype, count = slayerType(rec) end
	if ctype then
		table.insert(reasons, S.Format(why.slayer, { count = count, ctype = ctype }))
		table.insert(keys, "slayer:" .. ctype)
	end

	if (rec.deaths or 0) >= CURSED_DEATHS then
		table.insert(prefixes, names.prefix.cursed)
		table.insert(reasons, S.Format(why.cursed, { deaths = rec.deaths }))
		table.insert(keys, "cursed")
	end
	if (rec.levels or 0) >= FAITHFUL_LEVELS then
		table.insert(prefixes, names.prefix.faithful)
		table.insert(reasons, S.Format(why.faithful, { levels = rec.levels }))
		table.insert(keys, "faithful")
	end

	if #keys == 0 then return end

	local name
	if not ctype and #prefixes == 0 then
		name = S.Format(S.Pick(names.baneAlone, rec.seed, 2), { name = bane })
	else
		local core = vars.noun
		if ctype then
			core = (names.slayerTitle[ctype] or names.slayerTitle.default) .. "'s " .. core
		end
		table.insert(prefixes, core)
		name = table.concat(prefixes, " ")
		if bane then name = name .. ", " .. S.Format(names.baneSuffix, { name = bane }) end
	end
	return name, reasons, table.concat(keys, "|")
end

local function generated(rec, link, q, L)
	local S = ns.Stories
	local names = L.names
	local seed = rec.seed or 0
	local vars = words(rec, L)
	local t = q >= 2 and theme(link)
	if t then
		vars.themeAdj = S.Pick(names.themes[t].adj, seed, 11)
		vars.themeNoun = S.Pick(names.themes[t].noun, seed, 13)
	end
	vars.junk = S.Pick(names.junkAdj, seed, 5)
	vars.plain = S.Pick(names.plainAdj, seed, 5)

	local templates
	if q == 0 then
		templates = names.junk
	elseif q == 1 then
		templates = names.plain
	elseif q == 2 then
		templates = t and names.themed or names.plain
	elseif q == 3 then
		templates = t and names.rare or names.rarePlain
	else
		templates = names.epic
	end
	return S.Format(S.Pick(templates, seed, 1), vars)
end

-- Returns the item's name and a list of reasons, or nil to keep the real
-- name.
function N.Get(rec, link)
	local L = ns.L()
	if rec.custom then return rec.custom, { L.names.why.custom } end
	if not ns.db.autonames then return end
	local q = quality(rec, link)
	if not q or q > MAX_QUALITY or (q >= RARE_QUALITY and not ns.db.rares) then return end
	local name, reasons = earned(rec, L)
	if name then return name, reasons end
	return generated(rec, link, q, L)
end

-- Notices when an item has earned a new name and announces it.
function N.Check(rec, link)
	local name = N.Get(rec, link)
	local _, _, key = earned(rec, ns.L())
	if key ~= rec.earnedKey then
		if key and rec.lastName and name and name ~= rec.lastName and not rec.custom then
			ns.Print(ns.L().ui.renamed:format(rec.lastName, name))
			ns.Journal.Add("renamed", { old = rec.lastName, new = name })
			ns.Fire("NAME_SET", rec)
		end
		rec.earnedKey = key
	end
	rec.lastName = name
end

local function checkEquipped()
	ns.Tracker.ForEachEquipped(function(rec, entry) N.Check(rec, entry.link) end)
end

ns.Listen("ITEMS_CHANGED", checkEquipped)
ns.Listen("LEVEL", checkEquipped)
ns.Listen("DEATH", checkEquipped)

local function earnBane(name, tier)
	ns.Tracker.ForEachEquipped(function(rec)
		local _, isWeapon = itemKind(rec.id)
		if isWeapon and (not rec.bane or tier > rec.bane.tier) then
			rec.bane = { n = name, tier = tier }
		end
	end)
end

ns.Listen("KILL", function(kill)
	if kill.name and ns.Journal.IsNotable(kill) then
		earnBane(kill.name, BANE_TIER[kill.cls] or 1)
	end
	checkEquipped()
end)

ns.Listen("BOSS", function(name)
	earnBane(name, BANE_TIER.boss)
	checkEquipped()
end)

---------------------------------------------------------------------------
-- Renaming by hand
---------------------------------------------------------------------------

local hovered

function N.SetHovered(rec, link)
	hovered = { rec = rec, link = link, t = GetTime() }
end

local function currentHovered()
	if hovered and GetTime() - hovered.t < HOVER_MEMORY then return hovered end
	ns.Print(ns.L().ui.noHovered)
end

local function displayName(rec, link)
	return N.Get(rec, link) or (link and link:match("|h%[(.-)%]|h")) or "?"
end

function N.RenameHovered(newName)
	local h = currentHovered()
	if not h then return end
	local L = ns.L()
	local old = displayName(h.rec, h.link)
	if newName:lower() == "reset" then
		h.rec.custom = nil
		ns.Print(L.ui.renameReset:format(old))
	else
		newName = N.Clean(newName)
		if newName == "" then return end
		h.rec.custom = newName
		ns.Print(L.ui.renamed:format(old, newName))
		ns.Journal.Add("renamed", { old = old, new = newName })
	end
	h.rec.lastName = N.Get(h.rec, h.link)
	ns.Fire("NAME_SET", h.rec)
	ns.Fire("NAMES_CHANGED")
end

-- Only add our own entry; never reassign Blizzard's StaticPopupDialogs.
StaticPopupDialogs.SOULBOUNDCHRONICLE_RENAME = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = MAX_LENGTH,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self)
		local box = self.editBox or self.EditBox
		box:SetText(N.pendingName or "")
		box:HighlightText()
	end,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox
		N.RenameHovered(box:GetText())
	end,
	EditBoxOnEnterPressed = function(self)
		N.RenameHovered(self:GetText())
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

function N.PromptRename()
	local h = currentHovered()
	if not h then return end
	N.pendingName = displayName(h.rec, h.link)
	StaticPopup_Show("SOULBOUNDCHRONICLE_RENAME", ns.L().ui.renamePrompt:format(N.pendingName))
end

-- Used by the key binding in Bindings.xml.
function SoulboundChronicle_RenameHovered()
	N.PromptRename()
end

BINDING_HEADER_SOULBOUNDCHRONICLE = ns.L().ui.bindingHeader
BINDING_NAME_SOULBOUNDCHRONICLE_RENAME = ns.L().ui.bindingRename
