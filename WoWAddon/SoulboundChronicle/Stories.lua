local _, ns = ...

-- Turns stored facts into text. Nothing here is saved, so switching
-- language rewrites every story.
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

local function timeOfDay(hour)
	local tod = ns.L().tod
	if not hour then return tod.day end
	if hour >= 5 and hour < 9 then return tod.dawn end
	if hour >= 9 and hour < 17 then return tod.day end
	if hour >= 17 and hour < 21 then return tod.dusk end
	return tod.night
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

function S.Soul(soul, seed)
	local L = ns.L()
	if not soul then return { L.soulUnknown } end
	local story = fmt(pick(L.soul, seed), {
		name = soul.name or "?",
		lvl = lvl(soul.level),
		tod = timeOfDay(soul.hour),
		place = place(soul.zone, soul.sub),
	})
	local flavor = L.soulFlavor[soul.ctype or ""] or L.soulFlavor.default
	return { story, pick(flavor, seed, 7) }
end

-- Lines shown in the tooltip and on the items page.
function S.ItemLines(rec)
	local L = ns.L()
	local lines = {}
	if rec.isShard then
		for _, line in ipairs(S.Soul(rec.soul, rec.seed)) do
			table.insert(lines, line)
		end
		table.insert(lines, fmt(L.when, { date = S.Date(rec.t), plvl = rec.pl }))
		return lines
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
		spell = e.spell,
		link = e.link,
		origin = e.rec and S.Origin(e.rec) or "",
	})
end
