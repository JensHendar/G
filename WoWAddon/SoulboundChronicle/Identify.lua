local _, ns = ...

-- Unidentified items: some looted gear arrives with its name hidden until
-- an innkeeper identifies it, revealing its name and a legend. Only the
-- name is hidden; stats show as normal.
local I = {}
ns.Identify = I

local CHANCE = { [2] = 0.10, [3] = 0.25, [4] = 0.50 }
local FROM = { loot = true, fish = true, container = true }
local JEWELRY = { neck = true, finger = true, trinket = true }
local MAX_REVEALED = 4
local BINDER_ICON = 132052 -- "Make this inn your home"

function I.IsHidden(rec)
	return rec.unid and ns.db.identify
end

-- Decides, once, whether a new item arrives unidentified.
function I.Roll(rec, link)
	if not ns.db.identify or not FROM[rec.o.k] then return end
	local _, _, quality = ns.GetItemInfo(link or rec.id)
	local chance = quality and CHANCE[quality]
	if chance and math.random() < chance then rec.unid = true end
end

function I.Noun(rec)
	local nouns = ns.L().identify.nouns
	return nouns[ns.Names.Kind(rec.id)] or nouns.generic
end

function I.Name(rec)
	return ns.Stories.Format(ns.L().identify.name, { noun = I.Noun(rec) })
end

function I.Mystery(rec)
	local L = ns.L().identify
	local kind, isWeapon = ns.Names.Kind(rec.id)
	local group = isWeapon and "weapon" or JEWELRY[kind] and "jewelry" or "armor"
	return { ns.Stories.Pick(L.mystery[group], rec.seed, 31), L.hint }
end

-- The item's legend, built from its seed so it never changes.
function I.Legend(rec)
	local S = ns.Stories
	local L = ns.L().identify
	local seed = rec.seed or 0
	local vars = {
		forge = S.Pick(L.forges, seed, 37),
		owner = S.Pick(L.owners, seed, 41),
		fall = S.Pick(L.falls, seed, 43),
		count = 2 + seed % 6,
	}
	return S.Format(S.Pick(L.origin, seed, 47), vars) .. " "
		.. S.Format(S.Pick(L.history, seed, 53), vars) .. " "
		.. S.Pick(L.fate, seed, 59)
end

---------------------------------------------------------------------------
-- Innkeepers
---------------------------------------------------------------------------

local function innkeeperName()
	local name = ns.Plain(UnitName("npc"))
	if not name then return end
	if name:find("^Innkeeper ") then return name end
	if C_GossipInfo and C_GossipInfo.GetOptions then
		for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
			if option.icon == BINDER_ICON or option.type == "binder" then return name end
		end
	elseif GetGossipOptions then
		local options = { GetGossipOptions() }
		for i = 2, #options, 2 do
			if options[i] == "binder" then return name end
		end
	end
end

-- Identifies everything unidentified we carry (not the bank).
function I.Visit(npc)
	if not ns.db.identify then return end
	local found = {}
	ns.Tracker.ForEach(function(rec, _, entry)
		if rec.unid and not entry.bank then
			table.insert(found, { rec = rec, link = entry.link })
		end
	end)
	if #found == 0 then return end

	local L = ns.L()
	local zone, sub = ns.Place()
	for _, item in ipairs(found) do
		local rec = item.rec
		rec.unid = nil
		rec.idBy, rec.idT, rec.idZ, rec.idSz = npc, time(), zone, sub
		item.name = ns.Names.Get(rec, item.link) or (item.link and item.link:match("|h%[(.-)%]|h")) or "?"
		item.quote = ns.Stories.Format(ns.Stories.Pick(L.identify.quote, rec.seed, 61), { npc = npc, name = item.name })
		item.legend = I.Legend(rec)
		rec.lastName = item.name
		ns.Journal.Add("identified", { npc = npc, new = item.name })
		ns.Print(item.quote)
		ns.Fire("NAME_SET", rec)
	end
	ns.Fire("NAMES_CHANGED")
	ns.UI.ShowReveal(npc, found, MAX_REVEALED)
end

local function onInteract()
	local npc = innkeeperName()
	if npc then I.Visit(npc) end
end
ns.On("GOSSIP_SHOW", onInteract)
ns.On("MERCHANT_SHOW", onInteract)
