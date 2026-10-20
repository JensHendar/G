local _, ns = ...

-- Follows tracked items between bags, bank and equipment, gives new items
-- an origin, and keeps count of what they live through.
local T = {}
ns.Tracker = T

local BANK_CONTAINER = BANK_CONTAINER or -1
local NUM_BAGS = NUM_BAG_SLOTS or 4
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 6
local LIMBO_MAX = 200
local MAX_DEEDS = 3

local bankOpen = false

---------------------------------------------------------------------------
-- What gets a memory: gear that does not stack.
---------------------------------------------------------------------------

local IGNORED_SLOTS = {
	[""] = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true,
	INVTYPE_AMMO = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true,
}
local trackedCache = {}

local function isTracked(itemID)
	if trackedCache[itemID] ~= nil then return trackedCache[itemID] end
	local _, _, _, equipLoc = ns.GetItemInfoInstant(itemID)
	local tracked = equipLoc ~= nil and not IGNORED_SLOTS[equipLoc]
	if tracked then
		local _, _, _, _, _, _, _, maxStack = ns.GetItemInfo(itemID)
		if maxStack == nil then return true end -- not cached yet; ask again later
		tracked = maxStack <= 1
	end
	trackedCache[itemID] = tracked
	return tracked
end

-- Classic-style clients have a bank container plus bank bags; modern ones
-- have bank tabs instead.
local BANK_BAGS = {}
local bagIndex = Enum and Enum.BagIndex
if bagIndex and bagIndex.CharacterBankTab_1 then
	for i = 1, 6 do
		local bag = bagIndex["CharacterBankTab_" .. i]
		if bag then table.insert(BANK_BAGS, bag) end
	end
else
	table.insert(BANK_BAGS, BANK_CONTAINER)
	for bag = NUM_BAGS + 1, NUM_BAGS + NUM_BANK_BAGS do table.insert(BANK_BAGS, bag) end
end
local IS_BANK_BAG = {}
for _, bag in ipairs(BANK_BAGS) do IS_BANK_BAG[bag] = true end

local function isBankBag(bag)
	return IS_BANK_BAG[bag] or false
end

-- Item GUIDs tell two identical items apart. Clients without them fall
-- back to matching on item ID.
local function itemGUID(bag, slot)
	if not (C_Item and C_Item.GetItemGUID and ItemLocation) then return nil end
	local ok, guid = pcall(function()
		local loc = bag and ItemLocation:CreateFromBagAndSlot(bag, slot)
			or ItemLocation:CreateFromEquipmentSlot(slot)
		if C_Item.DoesItemExist(loc) then return C_Item.GetItemGUID(loc) end
	end)
	return ok and guid or nil
end

local function forEachLocation(fn)
	for slot = 1, 19 do fn("e:" .. slot, nil, slot) end
	local function bagSlots(bag)
		for slot = 1, ns.GetNumSlots(bag) or 0 do fn("b:" .. bag .. ":" .. slot, bag, slot) end
	end
	for bag = 0, NUM_BAGS do bagSlots(bag) end
	if bankOpen then
		for _, bag in ipairs(BANK_BAGS) do bagSlots(bag) end
	end
end

---------------------------------------------------------------------------
-- Origin context: what were we doing when an item showed up?
---------------------------------------------------------------------------

local contexts = {}

local function openContext(kind, data)
	data.k = data.k or kind
	contexts[kind] = { data = data, open = true, at = GetTime() }
end

local function closeContext(kind, grace)
	local c = contexts[kind]
	if c and c.open then
		c.open = false
		c.expires = GetTime() + (grace or 3)
	end
end

local function currentOrigin()
	local best
	local now = GetTime()
	for _, c in pairs(contexts) do
		if (c.open or c.expires > now) and (not best or c.at > best.at) then
			best = c
		end
	end
	return best and best.data
end

ns.On("LOOT_OPENED", function()
	if IsFishingLoot and IsFishingLoot() then
		openContext("loot", { k = "fish" })
		return
	end
	local info
	local ok, guid = pcall(GetLootSourceInfo, 1)
	guid = ok and ns.Plain(guid)
	if guid then info = ns.units[guid] end
	if not info and ns.Plain(UnitIsDead("target")) then
		info = ns.RememberUnit("target")
	end
	if info and info.name then
		openContext("loot", { k = "loot", src = info.name, lvl = info.level })
	else
		openContext("loot", { k = "container" })
	end
end)
ns.On("LOOT_CLOSED", function() closeContext("loot") end)

ns.On("QUEST_COMPLETE", function()
	openContext("quest", { src = GetTitleText() })
end)
ns.On("QUEST_FINISHED", function() closeContext("quest") end)

ns.On("MERCHANT_SHOW", function()
	openContext("vendor", { src = ns.Plain(UnitName("npc")) })
end)
ns.On("MERCHANT_CLOSED", function() closeContext("vendor") end)

ns.On("TRADE_SHOW", function()
	openContext("trade", { src = ns.Plain(UnitName("NPC")) })
end)
ns.On("TRADE_CLOSED", function() closeContext("trade", 5) end)

ns.On("MAIL_SHOW", function() openContext("mail", {}) end)
ns.On("MAIL_CLOSED", function() closeContext("mail") end)

local createdPattern
ns.On("CHAT_MSG_LOOT", function(msg)
	msg = ns.Plain(msg)
	if not msg then return end
	if not createdPattern and LOOT_ITEM_CREATED_SELF then
		createdPattern = "^" .. LOOT_ITEM_CREATED_SELF:gsub("%.", "%%."):gsub("%%s", ".+")
	end
	if createdPattern and msg:find(createdPattern) then
		openContext("craft", {})
		closeContext("craft")
	end
end)

---------------------------------------------------------------------------
-- Records
---------------------------------------------------------------------------

local function newRecord(entry)
	local char = ns.char
	local id = char.nextId
	char.nextId = id + 1
	local zone, sub = ns.Place()
	local rec = {
		id = entry.id,
		link = entry.link,
		t = time(),
		pl = UnitLevel("player"),
		z = zone,
		sz = sub,
		seed = math.random(0, 9999),
	}

	local recentLogin = GetTime() - (ns.loginTime or 0) < 10
	rec.o = currentOrigin() or { k = recentLogin and "before" or "found" }

	if rec.o.k ~= "before" then
		local _, _, quality = ns.GetItemInfo(entry.link or entry.id)
		if quality and quality >= 3 then
			ns.Journal.Add("item", {
				link = entry.link,
				rec = { o = rec.o, z = rec.z, sz = rec.sz, seed = rec.seed },
			})
		end
	end

	char.items[id] = rec
	return id
end

-- Finds the entry in list that is the same item as entry, preferring an
-- exact GUID match over a plain item ID match.
local function takeMatch(list, entry)
	local fallback
	for i, other in ipairs(list) do
		if other.id == entry.id then
			if entry.guid and other.guid == entry.guid then
				return table.remove(list, i)
			end
			if not fallback and not (entry.guid and other.guid) then
				fallback = i
			end
		end
	end
	if fallback then return table.remove(list, fallback) end
end

local function onEquipped(rec)
	if not rec.eqLevel then rec.eqLevel = UnitLevel("player") end
end

local function onGone(entry)
	entry.t = time()
	table.insert(ns.char.limbo, entry)
	while #ns.char.limbo > LIMBO_MAX do table.remove(ns.char.limbo, 1) end
end

---------------------------------------------------------------------------
-- Scanning: compare what we see now with what we saw last time.
---------------------------------------------------------------------------

function T.Scan()
	if not ns.char then return end
	local old = ns.char.slots
	local new, seen, removed, added = {}, {}, {}, {}

	forEachLocation(function(key, bag, slot)
		seen[key] = true
		local id, link
		if bag then
			id = ns.GetBagItemID(bag, slot)
			link = id and ns.GetBagItemLink(bag, slot)
		else
			id = GetInventoryItemID("player", slot)
			link = id and GetInventoryItemLink("player", slot)
		end
		if id and not isTracked(id) then id = nil end

		local prev = old[key]
		if id then
			local guid = itemGUID(bag, slot)
			if prev and prev.id == id and not (prev.guid and guid and prev.guid ~= guid) then
				prev.guid = guid or prev.guid
				prev.link = link
				new[key] = prev
				return
			end
			local entry = { id = id, guid = guid, link = link, bank = bag and isBankBag(bag) or nil }
			new[key] = entry
			table.insert(added, entry)
			if not bag then entry.equipped = true end
		end
		if prev then table.insert(removed, prev) end
	end)

	-- Bank slots we cannot see right now keep their memories.
	for key, entry in pairs(old) do
		if not seen[key] then
			if entry.bank and not bankOpen then
				new[key] = entry
			else
				table.insert(removed, entry)
			end
		end
	end

	for _, entry in ipairs(added) do
		local match = takeMatch(removed, entry) or takeMatch(ns.char.limbo, entry)
		entry.rec = match and match.rec or newRecord(entry)
		entry.guid = entry.guid or (match and match.guid)
		local rec = ns.char.items[entry.rec]
		if rec and entry.equipped then onEquipped(rec) end
		entry.equipped = nil
		entry.t = nil
	end

	for _, entry in ipairs(removed) do onGone(entry) end

	ns.char.slots = new
	ns.Fire("ITEMS_CHANGED")
end

local scanQueued = false
function T.QueueScan()
	if scanQueued then return end
	scanQueued = true
	C_Timer.After(0.1, function()
		scanQueued = false
		T.Scan()
	end)
end

ns.On("BAG_UPDATE_DELAYED", T.QueueScan)
ns.On("PLAYER_EQUIPMENT_CHANGED", T.QueueScan)
ns.On("PLAYERBANKSLOTS_CHANGED", T.QueueScan)
ns.On("BANKFRAME_OPENED", function()
	bankOpen = true
	T.QueueScan()
end)
ns.On("BANKFRAME_CLOSED", function()
	-- Look one last time before the bank closes, then stop looking.
	T.Scan()
	bankOpen = false
end)
ns.On("GET_ITEM_INFO_RECEIVED", function() wipe(trackedCache) end)

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------

function T.RecordAt(key)
	local entry = ns.char and ns.char.slots[key]
	return entry and ns.char.items[entry.rec]
end

-- Calls fn(rec, key) for every remembered item we can see or have seen in
-- the bank.
function T.ForEach(fn)
	for key, entry in pairs(ns.char.slots) do
		local rec = ns.char.items[entry.rec]
		if rec then fn(rec, key, entry) end
	end
end

-- Calls fn(rec, entry) for every remembered item being worn.
function T.ForEachEquipped(fn)
	for slot = 1, 19 do
		local entry = ns.char.slots["e:" .. slot]
		local rec = entry and ns.char.items[entry.rec]
		if rec then fn(rec, entry) end
	end
end

---------------------------------------------------------------------------
-- What equipped items live through
---------------------------------------------------------------------------

local function addDeed(rec, name)
	rec.deeds = rec.deeds or {}
	table.insert(rec.deeds, 1, { n = name, t = time() })
	while #rec.deeds > MAX_DEEDS do table.remove(rec.deeds) end
end

ns.Listen("KILL", function(kill)
	local notable = ns.Journal.IsNotable(kill)
	T.ForEachEquipped(function(rec)
		rec.kills = (rec.kills or 0) + 1
		if kill.ctype then
			rec.slain = rec.slain or {}
			rec.slain[kill.ctype] = (rec.slain[kill.ctype] or 0) + 1
		end
		if notable then addDeed(rec, kill.name) end
	end)
end)

ns.Listen("BOSS", function(name)
	T.ForEachEquipped(function(rec) addDeed(rec, name) end)
end)

ns.Listen("DEATH", function()
	T.ForEachEquipped(function(rec) rec.deaths = (rec.deaths or 0) + 1 end)
end)

ns.Listen("LEVEL", function()
	T.ForEachEquipped(function(rec) rec.levels = (rec.levels or 0) + 1 end)
end)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Drops records that no slot or limbo entry points to any more.
local function collectGarbage()
	local used = {}
	for _, entry in pairs(ns.char.slots) do used[entry.rec] = true end
	for _, entry in ipairs(ns.char.limbo) do used[entry.rec] = true end
	for id in pairs(ns.char.items) do
		if not used[id] then ns.char.items[id] = nil end
	end
end

ns.Listen("LOGIN", function()
	collectGarbage()
	C_Timer.NewTicker(60, function()
		T.ForEachEquipped(function(rec) rec.worn = (rec.worn or 0) + 60 end)
	end)
end)

ns.On("PLAYER_ENTERING_WORLD", T.QueueScan)
