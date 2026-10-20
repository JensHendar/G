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
		lang = "en",
		tooltip = true,
		autonames = true,
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
-- Unit memory: remember what we saw of a unit so a kill or a corpse can be
-- described after the unit is gone.
---------------------------------------------------------------------------

local units, unitCount = {}, 0
ns.units = units

function ns.RememberUnit(unit)
	local guid = UnitGUID(unit)
	if not guid or UnitIsPlayer(unit) then return end
	if not units[guid] then
		unitCount = unitCount + 1
		if unitCount > 500 then
			wipe(units)
			unitCount = 1
		end
	end
	units[guid] = {
		name = UnitName(unit),
		level = UnitLevel(unit),
		cls = UnitClassification(unit),
		ctype = UnitCreatureType(unit),
	}
	return units[guid]
end

ns.On("PLAYER_TARGET_CHANGED", function() ns.RememberUnit("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() ns.RememberUnit("mouseover") end)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit) ns.RememberUnit(unit) end)

---------------------------------------------------------------------------
-- Combat: kills and killers
---------------------------------------------------------------------------

local band = bit.band
local FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x10
local engaged = {}       -- guid -> time we last hit it
local lastHit            -- who last hurt the player

local function isMine(guid)
	return guid and (guid == ns.playerGUID or guid == UnitGUID("pet"))
end

ns.On("COMBAT_LOG_EVENT_UNFILTERED", function()
	local _, sub, _, srcGUID, srcName, _, _, dstGUID, dstName, dstFlags, _, a12 = CombatLogGetCurrentEventInfo()

	if isMine(srcGUID) and dstGUID ~= ns.playerGUID and band(dstFlags or 0, FRIENDLY) == 0 then
		engaged[dstGUID] = GetTime()
		if not units[dstGUID] then
			units[dstGUID] = { name = dstName }
		end
	end

	if dstGUID == ns.playerGUID then
		if sub == "ENVIRONMENTAL_DAMAGE" then
			lastHit = { env = a12, t = GetTime() }
		elseif sub:find("_DAMAGE$") and srcName and srcGUID ~= ns.playerGUID then
			lastHit = { name = srcName, t = GetTime() }
		end
	end

	if sub == "UNIT_DIED" and engaged[dstGUID] then
		local fresh = GetTime() - engaged[dstGUID] < 120
		engaged[dstGUID] = nil
		if not fresh then return end
		local info = units[dstGUID] or { name = dstName }
		local zone, subzone = ns.Place()
		ns.Fire("KILL", {
			guid = dstGUID, name = info.name or dstName, level = info.level,
			cls = info.cls, ctype = info.ctype, zone = zone, sub = subzone,
		})
	end
end)

ns.On("ENCOUNTER_END", function(_, name, _, _, success)
	if success == 1 then ns.Fire("BOSS", name) end
end)

ns.On("PLAYER_DEAD", function()
	local killer
	if lastHit and GetTime() - lastHit.t < 15 then
		if lastHit.env then
			killer = ns.L().env[lastHit.env] or lastHit.env:lower()
		else
			killer = lastHit.name
		end
	end
	lastHit = nil
	ns.Fire("DEATH", killer)
end)

ns.On("PLAYER_LEVEL_UP", function(level) ns.Fire("LEVEL", level) end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

SLASH_SOULBOUNDCHRONICLE1 = "/chronicle"
SLASH_SOULBOUNDCHRONICLE2 = "/sbc"
SLASH_SOULBOUNDCHRONICLE3 = "/kronika"
SlashCmdList.SOULBOUNDCHRONICLE = function(input)
	local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
	local L = ns.L()
	if cmd == "" then
		ns.UI.Toggle("chronicle")
	elseif cmd == "items" then
		ns.UI.Show("items")
	elseif cmd == "export" then
		ns.UI.Export()
	elseif cmd == "lang" and ns.Locales[arg] then
		ns.db.lang = arg
		ns.Print(ns.L().ui.langSet)
		ns.UI.Refresh()
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
	elseif cmd == "others" then
		ns.db.others = not ns.db.others
		ns.Print(ns.db.others and L.ui.othersOn or L.ui.othersOff)
	else
		for _, line in ipairs(L.ui.help) do ns.Print(line) end
	end
end
