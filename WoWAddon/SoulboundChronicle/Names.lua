local _, ns = ...

-- Gives gray, white and green items better names. Names are generated
-- from a stored seed (so they stay put), earned through deeds, or chosen
-- by the player.
local N = {}
ns.Names = N

local MAX_QUALITY = 2 -- gray, white, green
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

-- Swedish genitive: "Hogger" -> "Hoggers", "Barnabus" stays "Barnabus".
local function genitive(name)
	if name:find("[sxzSXZ]$") then return name end
	return name .. "s"
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
	local seed = rec.seed or 0
	local kind = itemKind(rec.id)
	local noun = S.Pick(L.names.nouns[kind] or L.names.nouns.generic, seed, 3)
	local person = S.Pick(L.names.persons, seed, 17)
	return {
		noun = type(noun) == "table" and noun[1] or noun,
		nounDef = type(noun) == "table" and noun[2] or noun,
		person = person,
		personGen = genitive(person),
		zone = rec.z ~= "" and rec.z or "Azeroth",
	}
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- The name an item has earned, if any, with the reason and a key that
-- changes only when a new name is earned.
local function earned(rec, L)
	local S = ns.Stories
	local why = L.names.why
	local seed = rec.seed or 0

	if rec.bane then
		local vars = words(rec, L)
		vars.name, vars.nameGen = rec.bane.n, genitive(rec.bane.n)
		return S.Format(S.Pick(L.names.bane, seed, 2), vars),
			S.Format(why.bane, { name = rec.bane.n }), "bane:" .. rec.bane.n
	end

	local _, isWeapon = itemKind(rec.id)
	if isWeapon and rec.slain then
		local best, count
		for ctype, n in pairs(rec.slain) do
			if n >= SLAYER_KILLS and (not count or n > count or (n == count and ctype < best)) then
				best, count = ctype, n
			end
		end
		if best then
			local vars = words(rec, L)
			vars.title = L.names.slayerTitle[best] or L.names.slayerTitle.default
			return S.Format(L.names.slayer, vars),
				S.Format(why.slayer, { count = count, ctype = best }), "slayer:" .. best
		end
	end

	if (rec.levels or 0) >= FAITHFUL_LEVELS then
		return S.Format(S.Pick(L.names.faithful, seed, 2), words(rec, L)),
			S.Format(why.faithful, { levels = rec.levels }), "faithful"
	end

	if (rec.deaths or 0) >= CURSED_DEATHS then
		return S.Format(S.Pick(L.names.cursed, seed, 2), words(rec, L)),
			S.Format(why.cursed, { deaths = rec.deaths }), "cursed"
	end
end

local function generated(rec, link, q, L)
	local S = ns.Stories
	local names = L.names
	local seed = rec.seed or 0
	local vars = words(rec, L)
	local templates

	if q == 0 then
		templates = names.junk
		vars.junk = S.Pick(names.junkAdj, seed, 5)
	else
		local t = q >= 2 and theme(link)
		if t then
			templates = names.themed
			vars.themeAdj = S.Pick(names.themes[t].adj, seed, 11)
			vars.themeNoun = S.Pick(names.themes[t].noun, seed, 13)
		else
			templates = names.plain
			vars.plain = S.Pick(names.plainAdj, seed, 5)
		end
	end
	return S.Format(S.Pick(templates, seed, 1), vars)
end

-- Returns the item's name and why it has it, or nil to keep the real name.
function N.Get(rec, link)
	local L = ns.L()
	if rec.custom then return rec.custom, L.names.why.custom end
	if not ns.db.autonames then return end
	local q = quality(rec, link)
	if not q or q > MAX_QUALITY then return end
	local name, why = earned(rec, L)
	if name then return name, why end
	return generated(rec, link, q, L)
end

-- Notices when an item has earned a new name and announces it.
function N.Check(rec, link)
	local name = N.Get(rec, link)
	local _, _, key = earned(rec, ns.L())
	if key ~= rec.earnedKey then
		if key and rec.lastName and name and name ~= rec.lastName and not rec.custom then
			local L = ns.L()
			ns.Print(L.ui.renamed:format(rec.lastName, name))
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

StaticPopupDialogs = StaticPopupDialogs or {}
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

ns.Listen("DB_READY", function()
	local ui = ns.L().ui
	BINDING_HEADER_SOULBOUNDCHRONICLE = ui.bindingHeader
	BINDING_NAME_SOULBOUNDCHRONICLE_RENAME = ui.bindingRename
end)
