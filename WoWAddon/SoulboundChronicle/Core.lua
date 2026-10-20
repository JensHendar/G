local ADDON, ns = ...

---------------------------------------------------------------------------
-- Events and internal messages
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Registers fn for a game event. Events the client does not know are
-- skipped, so one file can serve several game versions.
function ns.On(event, fn)
	if not handlers[event] then
		if not pcall(frame.RegisterEvent, frame, event) then return end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local listeners = {}

function ns.Listen(msg, fn)
	listeners[msg] = listeners[msg] or {}
	table.insert(listeners[msg], fn)
end

function ns.Fire(msg, ...)
	for _, fn in ipairs(listeners[msg] or {}) do fn(...) end
end

---------------------------------------------------------------------------
-- API compatibility (Classic-style clients have moved functions around)
---------------------------------------------------------------------------

local C = C_Container
ns.GetNumSlots = C and C.GetContainerNumSlots or GetContainerNumSlots
ns.GetBagItemID = C and C.GetContainerItemID or GetContainerItemID
ns.GetBagItemLink = C and C.GetContainerItemLink or GetContainerItemLink
ns.GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
ns.GetItemInfoInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
ns.GetItemStats = GetItemStats or (C_Item and C_Item.GetItemStats)
ns.SendAddonMessage = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
ns.RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

function ns.Place()
	local zone = GetRealZoneText() or ""
	local sub = GetSubZoneText() or ""
	return zone, sub
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9d7bffSoulbound Chronicle|r: " .. msg)
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local function defaults(t, d)
	for k, v in pairs(d) do
		if t[k] == nil then
			t[k] = type(v) == "table" and defaults({}, v) or v
		end
	end
	return t
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	SoulboundChronicleDB = defaults(SoulboundChronicleDB or {}, {
		tooltip = true,
		autonames = true,
		rares = true,
		others = true,
	})
	SoulboundChronicleCharDB = defaults(SoulboundChronicleCharDB or {}, {
		version = 1,
		nextId = 1,
		items = {},    -- record id -> item record
		slots = {},    -- location key -> { id, guid, rec, bank }
		limbo = {},    -- records whose item left our sight (bank, sold, used)
		journal = {},  -- chronicle entries, oldest first
		seenZones = {},
		slain = {},    -- name -> times slain (notable foes only)
		bosses = {},
	})
	ns.db = SoulboundChronicleDB
	ns.char = SoulboundChronicleCharDB
	ns.Fire("DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
	ns.playerGUID = UnitGUID("player")
	ns.playerName = UnitName("player")
	ns.loginTime = GetTime()
	ns.Fire("LOGIN")
end)

---------------------------------------------------------------------------
-- Secret values: on modern clients (Forever, Midnight) many unit and chat
-- values are opaque inside instances. Comparing them is an error, so
-- everything read from a unit or a chat message goes through Plain first.
---------------------------------------------------------------------------

local isSecret = issecretvalue or function() return false end

-- Returns v, or nil if it is a secret value we are not allowed to read.
function ns.Plain(v)
	if isSecret(v) then return nil end
	return v
end
local Plain = ns.Plain

---------------------------------------------------------------------------
-- Unit memory: remember what we saw of a unit so a kill or a corpse can be
-- described after the unit is gone.
---------------------------------------------------------------------------

local units, unitCount = {}, 0
ns.units = units

function ns.RememberUnit(unit)
	local guid = Plain(UnitGUID(unit))
	if not guid or Plain(UnitIsPlayer(unit)) ~= false then return end
	if not units[guid] then
		unitCount = unitCount + 1
		if unitCount > 500 then
			wipe(units)
			unitCount = 1
		end
	end
	units[guid] = {
		name = Plain(UnitName(unit)),
		level = Plain(UnitLevel(unit)),
		cls = Plain(UnitClassification(unit)),
		ctype = Plain(UnitCreatureType(unit)),
	}
	return units[guid]
end

---------------------------------------------------------------------------
-- Combat: kills and killers.
--
-- The combat log is off limits to addons on Forever (registering for it
-- is blocked), so kills are worked out from unit events instead: a hostile
-- unit that has us on its threat list is "engaged", and an engaged unit we
-- later see dead counts as a kill.
---------------------------------------------------------------------------

local engaged = {}  -- guid -> time it last fought us
local lastAttacker  -- the last hostile unit seen targeting us

local function isHostile(unit)
	return Plain(UnitCanAttack("player", unit)) and Plain(UnitIsPlayer(unit)) == false
end

local function watch(unit)
	if not unit or not Plain(UnitExists(unit)) then return end
	local guid = Plain(UnitGUID(unit))
	if not guid then return end

	-- Corpses may no longer count as attackable, so check deaths first.
	if Plain(UnitIsDead(unit)) then
		local since = engaged[guid]
		if not since then return end
		engaged[guid] = nil
		if GetTime() - since > 120 then return end
		local info = units[guid] or ns.RememberUnit(unit) or {}
		local zone, sub = ns.Place()
		ns.Fire("KILL", {
			guid = guid, name = info.name, level = info.level,
			cls = info.cls, ctype = info.ctype, zone = zone, sub = sub,
		})
		return
	end
	if not isHostile(unit) then return end

	local threat = UnitThreatSituation and Plain(UnitThreatSituation("player", unit))
	local targetsUs = Plain(UnitIsUnit(unit .. "target", "player"))
	if threat or targetsUs then
		if not engaged[guid] then ns.RememberUnit(unit) end
		engaged[guid] = GetTime()
	end
	if targetsUs then
		lastAttacker = { name = (units[guid] or {}).name, t = GetTime() }
	end
end
ns.WatchUnit = watch

local function watchEvent(unit) watch(unit) end
ns.On("UNIT_THREAT_LIST_UPDATE", watchEvent)
ns.On("UNIT_TARGET", watchEvent)
ns.On("UNIT_HEALTH", watchEvent)
ns.On("UNIT_FLAGS", watchEvent)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit) ns.RememberUnit(unit); watch(unit) end)
ns.On("NAME_PLATE_UNIT_REMOVED", watchEvent)
ns.On("PLAYER_TARGET_CHANGED", function() ns.RememberUnit("target"); watch("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() ns.RememberUnit("mouseover"); watch("mouseover") end)

-- Looting a corpse proves it died, even if we never saw it fall.
ns.On("LOOT_OPENED", function()
	local ok, guid = pcall(GetLootSourceInfo, 1)
	guid = ok and Plain(guid)
	if guid and engaged[guid] and units[guid] then
		local info = units[guid]
		engaged[guid] = nil
		local zone, sub = ns.Place()
		ns.Fire("KILL", {
			guid = guid, name = info.name, level = info.level,
			cls = info.cls, ctype = info.ctype, zone = zone, sub = sub,
		})
	end
end)

ns.On("ENCOUNTER_END", function(_, name, _, _, success)
	name = Plain(name)
	if Plain(success) == 1 and name then ns.Fire("BOSS", name) end
end)

ns.On("PLAYER_DEAD", function()
	local killer = lastAttacker and GetTime() - lastAttacker.t < 15 and lastAttacker.name or nil
	lastAttacker = nil
	wipe(engaged)
	ns.Fire("DEATH", killer)
end)

ns.On("PLAYER_LEVEL_UP", function(level) ns.Fire("LEVEL", level) end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

SLASH_SOULBOUNDCHRONICLE1 = "/chronicle"
SLASH_SOULBOUNDCHRONICLE2 = "/sbc"
SlashCmdList.SOULBOUNDCHRONICLE = function(input)
	local cmd = strtrim(input or ""):lower():match("^(%S*)")
	local L = ns.L()
	if cmd == "" then
		ns.UI.Toggle("chronicle")
	elseif cmd == "items" then
		ns.UI.Show("items")
	elseif cmd == "export" then
		ns.UI.Export()
	elseif cmd == "tooltip" then
		ns.db.tooltip = not ns.db.tooltip
		ns.Print(ns.db.tooltip and L.ui.tooltipOn or L.ui.tooltipOff)
	elseif cmd == "name" then
		-- Keep the player's own capitalisation for the new name.
		local name = strtrim(input):match("^%S+%s*(.-)$")
		if name == "" then
			ns.Names.PromptRename()
		else
			ns.Names.RenameHovered(name)
		end
	elseif cmd == "autonames" then
		ns.db.autonames = not ns.db.autonames
		ns.Print(ns.db.autonames and L.ui.autonamesOn or L.ui.autonamesOff)
		ns.Fire("NAMES_CHANGED")
	elseif cmd == "rares" then
		ns.db.rares = not ns.db.rares
		ns.Print(ns.db.rares and L.ui.raresOn or L.ui.raresOff)
		ns.Fire("NAMES_CHANGED")
	elseif cmd == "others" then
		ns.db.others = not ns.db.others
		ns.Print(ns.db.others and L.ui.othersOn or L.ui.othersOff)
	else
		for _, line in ipairs(L.ui.help) do ns.Print(line) end
	end
end
