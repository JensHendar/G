local _, ns = ...

-- Turns stored facts into text.
local S = {}
ns.Stories = S

local function fmt(template, vars)
	return (template:gsub("{(%w+)}", function(key)
		local v = vars[key]
		if v == nil then return "?" end
		return tostring(v)
	end))
end
S.Format = fmt

local function pick(list, seed, salt)
	if type(list) ~= "table" then return list end
	return list[((seed or 0) + (salt or 0)) % #list + 1]
end
S.Pick = pick

local function place(zone, sub)
	zone = zone ~= "" and zone or nil
	sub = sub ~= "" and sub ~= zone and sub or nil
	if zone and sub then return sub .. ", " .. zone end
	return sub or zone or "?"
end
S.Place = place

local function lvl(level)
	if not level or level <= 0 then return "" end
	return fmt(ns.L().level, { lvl = level })
end

function S.Duration(seconds)
	local t = ns.L().time
	local h = math.floor((seconds or 0) / 3600)
	local m = math.floor((seconds or 0) % 3600 / 60)
	return fmt(h > 0 and t.h or t.m, { h = h, m = m })
end

function S.Date(t)
	return date("%Y-%m-%d", t)
end

-- One sentence on where an item came from.
function S.Origin(rec)
	local L = ns.L()
	local o = rec.o or { k = "found" }
	return fmt(pick(L.origin[o.k] or L.origin.found, rec.seed), {
		src = o.src or "?",
		lvl = lvl(o.lvl),
		place = place(rec.z, rec.sz),
	})
end

-- Lines shown in the tooltip and on the items page.
function S.ItemLines(rec, link)
	local L = ns.L()
	local lines = {}

	local name, reasons = ns.Names.Get(rec, link)
	if name then
		local original = link and link:match("|h%[(.-)%]|h") or ns.GetItemInfo(rec.id)
		if original then table.insert(lines, fmt(L.names.originally, { name = original })) end
		for _, reason in ipairs(reasons or {}) do table.insert(lines, reason) end
	end

	table.insert(lines, S.Origin(rec))
	if rec.o and rec.o.k ~= "before" then
		table.insert(lines, fmt(L.when, { date = S.Date(rec.t), plvl = rec.pl }))
	end
	if rec.eqLevel then
		table.insert(lines, fmt(L.wornSince, { lvl = rec.eqLevel }))
		table.insert(lines, fmt(L.wornStats, {
			levels = rec.levels or 0,
			time = S.Duration(rec.worn),
			kills = rec.kills or 0,
			deaths = rec.deaths or 0,
		}))
	end
	for _, deed in ipairs(rec.deeds or {}) do
		table.insert(lines, fmt(L.deed, { name = deed.n }))
	end
	return lines
end

-- One chronicle entry as a sentence.
function S.Entry(e)
	local L = ns.L()
	local templates = L.journal[e.k]
	if e.k == "death" and not e.killer then
		templates = L.journal.deathUnknown
	end
	if not templates then return nil end
	return fmt(pick(templates, e.seed), {
		player = e.player,
		l = e.l,
		zone = e.z,
		place = place(e.z, e.sz),
		name = e.name,
		lvl = lvl(e.lvl),
		cls = L.cls[e.cls or ""] or "",
		killer = e.killer,
		pct = e.pct,
		link = e.link,
		old = e.old,
		new = e.new,
		origin = e.rec and S.Origin(e.rec) or "",
	})
end
