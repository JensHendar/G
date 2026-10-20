-- Minimal WoW API mock to exercise Soulbound Chronicle without the game.
-- Run from the repository root: lua5.1 WoWAddon/tests/mock_test.lua
local DIR = arg[1] or "WoWAddon/SoulboundChronicle"
local now = 1000
function GetTime() return now end
local clock = 1760000000
time = function() return clock end
date = os.date
bit = { band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a = math.floor(a/2); b = math.floor(b/2); p = p*2 end return r end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
Ambiguate = function(name) return (name:gsub("%-.*$", "")) end
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
UISpecialFrames = {}
SlashCmdList = {}
ACCEPT, CANCEL = "Accept", "Cancel"
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }

local function stub()
  local o = { scripts = {} }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
    if k == "GetStringHeight" or k == "GetVerticalScrollRange" then return function() return 100 end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetText" then return function(self, s) self.text = s end end
    if k == "GetText" then return function(self) return self.text end end
    return function() return stub() end
  end })
end
local frames = {}
function CreateFrame() local f = stub(); table.insert(frames, f); return f end
local timers = {}
C_Timer = {
  After = function(delay, f) table.insert(timers, { due = now + delay, fn = f }) end,
  NewTicker = function(_, f) TICK = f end,
}
local function flush()
  local ran = true
  while ran do
    ran = false
    for i, t in ipairs(timers) do
      if t.due <= now then table.remove(timers, i); t.fn(); ran = true; break end
    end
  end
end

-- Tooltips
local ttLines = {}
GameTooltipTextLeft1 = stub()
GameTooltip = stub()
GameTooltip.GetName = function() return "GameTooltip" end
GameTooltip.AddLine = function(_, s) table.insert(ttLines, s) end
local hooks = {}
function hooksecurefunc(obj, name, fn) if obj == GameTooltip then hooks[name] = fn end end
local function resetTooltip() ttLines = {}; GameTooltipTextLeft1.text = nil end

-- Chat and addon messages
local filters = {}
function ChatFrame_AddMessageEventFilter(event, fn) filters[event] = fn end
local sent = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(prefix, text, channel, target) table.insert(sent, { text = text, channel = channel, target = target }) end,
}
function IsInGuild() return true end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
StaticPopupDialogs = {}
local popup
function StaticPopup_Show(name, text) popup = text end

-- Items: name, quality, equipLoc, maxStack, classID, subclassID, stats
local items = {
  [100] = { "Worn Shortsword", 1, "INVTYPE_WEAPON", 1, 2, 7 },
  [101] = { "Rusty Hatchet", 0, "INVTYPE_WEAPON", 1, 2, 0 },
  [102] = { "Feral Leggings of the Bear", 2, "INVTYPE_LEGS", 1, 4, 2, { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_STAMINA_SHORT = 4 } },
  [200] = { "Blue Helm", 3, "INVTYPE_HEAD", 1, 4, 4 },
  [201] = { "Purple Axe", 4, "INVTYPE_2HWEAPON", 1, 2, 1, { ITEM_MOD_STRENGTH_SHORT = 20 } },
  [300] = { "Potion", 1, "", 20, 0, 0 },
}
function GetItemInfoInstant(id) local i = items[id]; return id, nil, nil, i and i[3], nil, i and i[5], i and i[6] end
local function idOf(x) if type(x) == "string" then return tonumber(x:match("item:(%d+)")) end return x end
local function link(id, unique) return "|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:" .. (unique or 0) .. "|h[" .. items[id][1] .. "]|h|r" end
function GetItemInfo(x)
  local id = idOf(x); local i = items[id]; if not i then return end
  return i[1], link(id), i[2], nil, nil, nil, nil, i[4]
end
function GetItemStats(l) local i = items[idOf(l)]; return i and i[7] end

local bags = { [0] = {}, {}, {}, {}, {} }
local equip = {}
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and 16 or 0 end,
  GetContainerItemID = function(b, s) return bags[b] and bags[b][s] end,
  GetContainerItemLink = function(b, s) local id = bags[b] and bags[b][s]; return id and link(id) end,
}
function GetInventoryItemID(_, s) return equip[s] end
function GetInventoryItemLink(unit, s) if unit == "player" then return equip[s] and link(equip[s]) end return INSPECT_LINK end

local level = 10
local target
function UnitGUID(u) if u == "player" then return "P" end if u == "target" then return target and target.guid end end
function UnitName(u) if u == "player" then return "Jens" end return target and target.name end
function GetUnitName(u) return UnitName(u) end
function UnitLevel(u) if u == "player" then return level end return target and target.level end
function UnitIsPlayer() return false end
function UnitClassification() return target and target.cls or "normal" end
function UnitCreatureType() return target and target.ctype end
function UnitExists() return target ~= nil end
function UnitIsDead() return target and target.dead end
function UnitIsUnit(a, b) return a == b end
function UnitAffectingCombat() return true end
function UnitHealth() return 50 end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return false end
function GetRealZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "Fargodeep Mine" end
function IsInInstance() return false end
function IsFishingLoot() return false end
function GetLootSourceInfo() return target and target.guid end
local cleu
function CombatLogGetCurrentEventInfo() return unpack(cleu) end

-- Load the addon in TOC order.
local ns = {}
for line in io.lines(DIR .. "/SoulboundChronicle.toc") do
  if line:match("%.lua$") then assert(loadfile(DIR .. "/" .. line))("SoulboundChronicle", ns) end
end
local events = frames[1]
local function fire(e, ...) events.scripts.OnEvent(events, e, ...); now = now + 0.2; flush() end
local function wait(sec) now = now + sec; flush() end
local function scan() fire("BAG_UPDATE_DELAYED") end
local slash = function(...) SlashCmdList.SOULBOUNDCHRONICLE(...); wait(1) end
local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end
local function rec(key) return ns.Tracker.RecordAt(key) end
local function name(key, l) return ns.Names.Get(rec(key), l) end
local guidN = 0
local function kill(n, cls, ctype)
  guidN = guidN + 1
  target = { guid = "C" .. guidN, name = n, level = 10, cls = cls, ctype = ctype }
  fire("PLAYER_TARGET_CHANGED")
  cleu = { 0, "SWING_DAMAGE", false, "P", "Jens", 0, 0, target.guid, n, 0x40, 0 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
  cleu = { 0, "UNIT_DIED", false, "", nil, 0, 0, target.guid, n, 0x40, 0 }
  fire("COMBAT_LOG_EVENT_UNFILTERED")
end

-- Install with some gear already in the bags.
bags[0][1] = 100; bags[0][2] = 101; bags[0][3] = 102; bags[0][4] = 200; bags[0][5] = 300
fire("ADDON_LOADED", "SoulboundChronicle")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
wait(11)

check(rec("b:0:1").o.k == "before", "existing item gets 'before' origin")
check(name("b:0:1", link(100)) ~= nil, "white item gets a name: " .. tostring(name("b:0:1", link(100))))
check(name("b:0:2", link(101)) ~= nil, "gray item gets a name: " .. tostring(name("b:0:2", link(101))))
local green = name("b:0:3", link(102))
check(green ~= nil, "green item gets a name: " .. tostring(green))
check(name("b:0:4", link(200)) ~= nil, "blue item gets a name: " .. tostring(name("b:0:4", link(200))))
slash("rares")
check(name("b:0:4", link(200)) == nil, "/chronicle rares turns blue names off")
slash("rares")
check(rec("b:0:5") == nil, "stackable items are ignored")
check(#sent > 0 and sent[1].channel == "GUILD", "names are shared with the guild on login")

-- Equip the sword and slay 100 beasts.
now = now + 60
bags[0][1] = nil; equip[16] = 100
fire("PLAYER_EQUIPMENT_CHANGED"); scan()
check(rec("e:16").eqLevel == 10, "equipping keeps record and notes level")
local before = name("e:16", link(100))
for _ = 1, 100 do kill("Forest Wolf", "normal", "Beast") end
local slayer = name("e:16", link(100))
local noun = slayer:match("(%S+)$")
check(slayer == "Beastslayer's " .. noun, "100 beast kills earn a slayer name: " .. slayer)
check(chat[#chat]:find(before, 1, true) and chat[#chat]:find(slayer, 1, true), "new name is announced")

-- A rare outranks that.
kill("Mother Fang", "rare", "Beast")
local bane = name("e:16", link(100))
check(bane == slayer .. ", Bane of Mother Fang", "deeds combine: " .. bane)
kill("Some Elite", "elite", "Humanoid")
check(name("e:16", link(100)) == bane, "a lesser foe does not replace the bane name")

-- Tooltip shows the new name and story.
resetTooltip()
hooks.SetInventoryItem(GameTooltip, "player", 16)
check(GameTooltipTextLeft1.text == bane, "tooltip title shows the new name")
check(table.concat(ttLines, "\n"):find("Originally: Worn Shortsword", 1, true), "tooltip shows the original name")

-- Rename by hand.
slash("name Ondskans Smörkniv")
check(name("e:16", link(100)) == "Ondskans Smörkniv", "custom name via /chronicle name")
slash("name")
check(popup and popup:find("Ondskans Smörkniv", 1, true), "rename popup opens for hovered item")
slash("name reset")
check(name("e:16", link(100)) == bane, "reset brings back the earned name")
slash("name |cffff0000Evil|r\tName")
check(name("e:16", link(100)) == "Evil Name", "control codes are stripped from custom names")
slash("name reset")

-- Our own links in chat show our names.
local filter = filters.CHAT_MSG_SAY
local _, out = filter(nil, "CHAT_MSG_SAY", "look " .. link(100), "Jens")
check(out:find("[" .. bane .. "]", 1, true), "own chat link shows the new name")

-- Someone else's links: unknown at first, so we ask them.
sent = {}
local theirs = link(101, 777)
_, out = filter(nil, "CHAT_MSG_GUILD", "my axe " .. theirs, "Kalle-Realm")
check(out:find("[Rusty Hatchet]", 1, true), "unknown foreign link is left alone")
wait(1)
check(sent[1] and sent[1].text == "Q\t101:0:777" and sent[1].channel == "WHISPER", "we ask the owner for its name")
fire("CHAT_MSG_ADDON", "SBChronicle", "N\t101:0:777\tKalles |cff00ff00Bästa|r Yxa", "WHISPER", "Kalle-Realm")
_, out = filter(nil, "CHAT_MSG_GUILD", "again " .. theirs, "Kalle-Realm")
check(out:find("[Kalles Bästa Yxa]", 1, true), "foreign link shows their name, without escape codes")
resetTooltip()
hooks.SetHyperlink(GameTooltip, theirs)
check(GameTooltipTextLeft1.text == "Kalles Bästa Yxa" and table.concat(ttLines):find("Named by Kalle", 1, true), "foreign link tooltip shows their name and who named it")
slash("others")
_, out = filter(nil, "CHAT_MSG_GUILD", "again " .. theirs, "Kalle-Realm")
check(out:find("[Rusty Hatchet]", 1, true), "others' names can be hidden")
slash("others")

-- Someone asks about ours.
sent = {}
fire("CHAT_MSG_ADDON", "SBChronicle", "Q\t100:0:0", "WHISPER", "Kalle-Realm")
wait(1)
check(sent[1] and sent[1].text == "N\t100:0:0\t" .. bane and sent[1].target == "Kalle-Realm", "we answer when asked")

-- Inspecting someone with the addon.
INSPECT_LINK = theirs
target = { name = "Kalle" }
resetTooltip()
hooks.SetInventoryItem(GameTooltip, "target", 16)
check(GameTooltipTextLeft1.text == "Kalles Bästa Yxa", "inspect tooltip shows their name")

-- Ten levels with an item earns "faithful" (armor never gets bane names).
bags[0][3] = nil; equip[7] = 102; scan()
for l = 11, 20 do level = l; fire("PLAYER_LEVEL_UP", l) end
check(rec("e:7").bane == nil, "armor does not take bane names")
check(name("e:7", link(102)):find("^Old Faithful "), "ten levels earn a faithful name: " .. name("e:7", link(102)))
check(name("e:16", link(100)) == "Old Faithful " .. bane, "all three deeds combine: " .. name("e:16", link(100)))

-- Taking an item off and on again keeps its counts.
local kills = rec("e:16").kills
equip[16] = nil; bags[1][1] = 100; fire("PLAYER_EQUIPMENT_CHANGED"); scan()
kill("Forest Wolf", "normal", "Beast")
check(rec("b:1:1").kills == kills, "kills are not counted while unequipped")
bags[1][1] = nil; equip[16] = 100; fire("PLAYER_EQUIPMENT_CHANGED"); scan()
kill("Forest Wolf", "normal", "Beast")
check(rec("e:16").kills == kills + 1 and rec("e:16").levels == 10, "re-equipping continues the counts")

-- Autonames off keeps real names but custom ones stay.
slash("autonames")
check(name("b:0:2", link(101)) == nil, "autonames off keeps real names")
slash("autonames")

-- UI and other commands do not crash.
slash("")
slash("items")
slash("export")
slash("help")
check(true, "UI commands run")

-- Show a spread of generated names in both languages.
local function samples()
  print("\n--- Sample names ---")
  for _, id in ipairs({ 101, 100, 102, 200, 201 }) do
    local out = {}
    for seed = 0, 5 do
      table.insert(out, ns.Names.Get({ id = id, seed = seed * 7, z = "Westfall" }, link(id)))
    end
    print(items[id][1] .. ": " .. table.concat(out, " | "))
  end
  print("Earned: " .. name("e:16", link(100)) .. " | " .. name("e:7", link(102)))
end
samples()
print("\n--- Chronicle ---")
for _, e in ipairs(ns.char.journal) do print(ns.Stories.Entry(e)) end
