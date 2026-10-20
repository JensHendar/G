-- Minimal WoW API mock to exercise Soulbound Chronicle logic.
local DIR = arg[1] or "WoWAddon/SoulboundChronicle"
local now = 1000
function GetTime() return now end
local clock = 1760000000
date = os.date
time = function() return clock end
bit = { band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a = math.floor(a/2); b = math.floor(b/2); p = p*2 end return r end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. m) end }

local function stub()
  local o = { scripts = {} }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
    if k == "GetStringHeight" or k == "GetVerticalScrollRange" then return function() return 100 end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetText" then return function(self, s) self.text = s end end
    return function() return stub() end
  end })
end
local frames = {}
function CreateFrame(...) local f = stub(); table.insert(frames, f); return f end
C_Timer = { After = function(_, f) f() end, NewTicker = function(_, f) TICK = f end }

-- Tooltip
local ttLines = {}
GameTooltip = stub()
GameTooltip.AddLine = function(_, s) table.insert(ttLines, s) end
local hooks = {}
function hooksecurefunc(obj, name, fn) hooks[name] = fn end

-- World state
local bags = { [0] = {}, {}, {}, {}, {} }
local equip = {}
local items = {
  [6265] = { "Soul Shard", 1, "", 1 },
  [100] = { "Worn Shortsword", 1, "INVTYPE_WEAPON", 1 },
  [200] = { "Epic Helm", 4, "INVTYPE_HEAD", 1 },
  [300] = { "Potion", 1, "", 20 },
}
function GetItemInfoInstant(id) local i = items[id]; return id, nil, nil, i and i[3] end
function GetItemInfo(id)
  if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) end
  local i = items[id]; if not i then return end
  return i[1], nil, i[2], nil, nil, nil, nil, i[4]
end
local function link(id) return "|cffffffff|Hitem:" .. id .. "|h[" .. items[id][1] .. "]|h|r" end
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and 16 or 0 end,
  GetContainerItemID = function(b, s) return bags[b] and bags[b][s] end,
  GetContainerItemLink = function(b, s) local id = bags[b] and bags[b][s]; return id and link(id) end,
}
function GetInventoryItemID(_, s) return equip[s] end
function GetInventoryItemLink(_, s) return equip[s] and link(equip[s]) end

local level = 10
local target = nil
function UnitGUID(u) if u == "player" then return "P" end if u == "target" then return target and target.guid end end
function UnitName(u) if u == "player" then return "Jens" end return target and target.name end
function UnitLevel(u) if u == "player" then return level end return target and target.level end
function UnitIsPlayer() return false end
function UnitClassification(u) return target and target.cls or "normal" end
function UnitCreatureType(u) return target and target.ctype end
function UnitExists(u) return target ~= nil end
function UnitIsDead() return target and target.dead end
function UnitIsUnit(a, b) return a == b end
function UnitAffectingCombat() return true end
function UnitHealth() return 5 end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return false end
function GetRealZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "Fargodeep Mine" end
function GetGameTime() return 22, 0 end
function IsInInstance() return false end
function GetSpellInfo(id) if id == 1120 or id == 11675 then return "Drain Soul" end return "Summon Voidwalker" end
function IsFishingLoot() return false end
function GetLootSourceInfo() return target and target.guid end
local cleu
function CombatLogGetCurrentEventInfo() return unpack(cleu) end

-- Load addon
local ns = {}
for _, f in ipairs({ "Locales", "Core", "Stories", "Tracker", "Journal", "Tooltip", "UI" }) do
  assert(loadfile(DIR .. "/" .. f .. ".lua"))("SoulboundChronicle", ns)
end
local events = frames[1]
local function fire(e, ...) events.scripts.OnEvent(events, e, ...) end

-- Existing gear before install
bags[0][1] = 100
fire("ADDON_LOADED", "SoulboundChronicle")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end
local function rec(key) return ns.Tracker.RecordAt(key) end
check(rec("b:0:1") and rec("b:0:1").o.k == "before", "existing item gets 'before' origin")

-- Equip it, move along
now = now + 60
bags[0][1] = nil; equip[16] = 100
fire("PLAYER_EQUIPMENT_CHANGED"); fire("BAG_UPDATE_DELAYED")
check(rec("e:16") and rec("e:16").eqLevel == 10, "equipping keeps record and notes level")

-- Kill a rare with Drain Soul -> soul shard
target = { guid = "C1", name = "Mother Fang", level = 10, cls = "rare", ctype = "Beast" }
fire("PLAYER_TARGET_CHANGED")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "x", 1120)
cleu = { 0, "SPELL_PERIODIC_DAMAGE", false, "P", "Jens", 0, 0, "C1", "Mother Fang", 0x40, 0 }
fire("COMBAT_LOG_EVENT_UNFILTERED")
cleu = { 0, "UNIT_DIED", false, "", nil, 0, 0, "C1", "Mother Fang", 0x40, 0 }
fire("COMBAT_LOG_EVENT_UNFILTERED")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
now = now + 1
bags[0][2] = 6265
fire("BAG_UPDATE_DELAYED")
local shard = rec("b:0:2")
check(shard and shard.soul and shard.soul.name == "Mother Fang", "soul shard remembers its soul")
check(rec("e:16").kills == 1 and #rec("e:16").deeds == 1, "equipped weapon counts kill and deed")

-- Loot an epic from the corpse
target.dead = true
fire("LOOT_OPENED")
bags[1][1] = 200
fire("BAG_UPDATE_DELAYED")
fire("LOOT_CLOSED")
check(rec("b:1:1").o.k == "loot" and rec("b:1:1").o.src == "Mother Fang", "looted item knows its source")

-- Move shard to another slot
now = now + 30
bags[0][2] = nil; bags[2][5] = 6265
fire("BAG_UPDATE_DELAYED")
check(rec("b:2:5") and rec("b:2:5").soul.name == "Mother Fang", "moved shard keeps its story")

-- Bank round trip
fire("BANKFRAME_OPENED")
bags[1][1] = nil; bags[-1] = { [3] = 200 }
fire("BAG_UPDATE_DELAYED")
check(rec("b:-1:3") and rec("b:-1:3").o.src == "Mother Fang", "item moved to bank keeps story")
fire("BANKFRAME_CLOSED")
bags[-1] = nil
fire("BAG_UPDATE_DELAYED")
check(rec("b:-1:3") ~= nil, "bank memory survives when bank is closed")

-- Spend the shard on a spell
now = now + 30
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "y", 697)
bags[2][5] = nil
fire("BAG_UPDATE_DELAYED")
check(#ns.char.limbo == 0, "spent shard is gone, not in limbo")

-- New shard without a kill shouldn't inherit anything
now = now + 30
bags[3][1] = 6265
fire("BAG_UPDATE_DELAYED")
check(rec("b:3:1") and rec("b:3:1").soul == nil, "unknown shard is nameless")

-- Potions are not tracked
bags[3][2] = 300
fire("BAG_UPDATE_DELAYED")
check(rec("b:3:2") == nil, "stackable items are ignored")

-- Level up, near death, death
level = 11; fire("PLAYER_LEVEL_UP", 11)
fire("UNIT_HEALTH", "player"); fire("PLAYER_REGEN_ENABLED")
cleu = { 0, "SWING_DAMAGE", false, "C9", "Hogger", 0, 0, "P", "Jens", 0, 0 }
fire("COMBAT_LOG_EVENT_UNFILTERED")
fire("PLAYER_DEAD")
check(rec("e:16").levels == 1 and rec("e:16").deaths == 1, "weapon counts levels and deaths")

-- Tooltip
hooks.SetBagItem(GameTooltip, 3, 1)
hooks.SetInventoryItem(GameTooltip, "player", 16)
check(#ttLines > 0, "tooltip lines added")

print("\n--- Tooltip (en) ---")
for _, l in ipairs(ttLines) do print(l) end
print("\n--- Chronicle (en) ---")
for _, e in ipairs(ns.char.journal) do print(ns.Stories.Entry(e)) end
SlashCmdList.SOULBOUNDCHRONICLE("lang sv")
print("\n--- Mother Fang shard / weapon (sv) ---")
for _, l in ipairs(ns.Stories.ItemLines(shard)) do print(l) end
for _, l in ipairs(ns.Stories.ItemLines(rec("e:16"))) do print(l) end
print("\n--- Chronicle (sv) ---")
for _, e in ipairs(ns.char.journal) do print(ns.Stories.Entry(e)) end
SlashCmdList.SOULBOUNDCHRONICLE("")
SlashCmdList.SOULBOUNDCHRONICLE("items")
SlashCmdList.SOULBOUNDCHRONICLE("export")
SlashCmdList.SOULBOUNDCHRONICLE("help")
print("UI ok")
