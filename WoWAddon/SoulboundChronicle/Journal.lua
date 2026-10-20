local _, ns = ...

-- The chronicle: a running diary of the character's life.
local J = {}
ns.Journal = J

local MAX_ENTRIES = 3000
local NEAR_DEATH = 0.1
local NEAR_DEATH_COOLDOWN = 300

function J.Add(kind, data)
	if not ns.char then return end
	local zone, sub = ns.Place()
	data = data or {}
	data.k = kind
	data.t = time()
	data.z = data.z or zone
	data.sz = data.sz or sub
	data.l = data.l or UnitLevel("player")
	data.seed = math.random(0, 9999)
	local journal = ns.char.journal
	table.insert(journal, data)
	while #journal > MAX_ENTRIES do table.remove(journal, 1) end
	ns.Fire("JOURNAL_CHANGED")
end

-- Rares and world bosses always count. Elites only out in the world,
-- since every mob in a dungeon is elite; dungeon bosses come from
-- ENCOUNTER_END instead.
function J.IsNotable(kill)
	local cls = kill.cls
	if cls == "rare" or cls == "rareelite" or cls == "worldboss" then return true end
	return cls == "elite" and not IsInInstance()
end

ns.Listen("KILL", function(kill)
	if not J.IsNotable(kill) or not kill.name then return end
	local slain = ns.char.slain
	slain[kill.name] = (slain[kill.name] or 0) + 1
	if slain[kill.name] == 1 then
		J.Add("kill", { name = kill.name, lvl = kill.level, cls = kill.cls })
	end
end)

ns.Listen("BOSS", function(name)
	if not ns.char.bosses[name] then
		ns.char.bosses[name] = time()
		J.Add("boss", { name = name })
	end
end)

ns.Listen("LEVEL", function(level)
	J.Add("level", { l = level })
end)

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------

local function checkZone()
	if not ns.char then return end
	local zone = GetRealZoneText()
	if not zone or zone == "" or ns.char.seenZones[zone] then return end
	ns.char.seenZones[zone] = time()
	local inInstance, kind = IsInInstance()
	J.Add(inInstance and (kind == "party" or kind == "raid") and "instance" or "zone")
end

ns.Listen("LOGIN", function()
	if #ns.char.journal == 0 then
		ns.char.seenZones[GetRealZoneText() or ""] = time()
		J.Add("begin", { player = UnitName("player") })
	end
end)

ns.On("ZONE_CHANGED_NEW_AREA", checkZone)
ns.On("PLAYER_ENTERING_WORLD", checkZone)

---------------------------------------------------------------------------
-- Life and death
---------------------------------------------------------------------------

local lowest
local lastNearDeath = 0

local function onHealth(unit)
	if unit ~= "player" or not UnitAffectingCombat("player") then return end
	local max = UnitHealthMax("player")
	if not max or max == 0 then return end
	local pct = UnitHealth("player") / max
	if pct > 0 and pct < NEAR_DEATH and (not lowest or pct < lowest) then
		lowest = pct
	end
end
ns.On("UNIT_HEALTH", onHealth)
ns.On("UNIT_HEALTH_FREQUENT", onHealth)

ns.On("PLAYER_REGEN_ENABLED", function()
	if lowest and not UnitIsDeadOrGhost("player") and time() - lastNearDeath > NEAR_DEATH_COOLDOWN then
		lastNearDeath = time()
		J.Add("neardeath", { pct = math.max(1, math.floor(lowest * 100 + 0.5)) })
	end
	lowest = nil
end)

ns.Listen("DEATH", function(killer)
	lowest = nil
	J.Add("death", { killer = killer })
end)
