local _, ns = ...

-- Shares item names with other players who run the addon. Messages are
-- hidden addon messages; players without the addon never see them.
--
--   N <tab> key <tab> name   "my item <key> is called <name>"
--   Q <tab> key              "what do you call your item <key>?"
--
-- An item key is itemID:suffixID:uniqueID from the item link.
local C = {}
ns.Comm = C

local PREFIX = "SBChronicle"
local SEND_INTERVAL = 0.25
local MAX_BROADCAST = 40
local MAX_REMOTE_NAME = 50

local queue = {}
local sending = false
local own = {}        -- key -> { rec, link } for our own items
local remote = {}     -- player -> key -> name
local lastOwner = {}  -- key -> who last showed us that item in chat
local asked = {}

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------

function C.KeyFromLink(link)
	local data = link and link:match("item:([%-%d:]+)")
	if not data then return end
	local fields = {}
	for value in (data .. ":"):gmatch("([^:]*):") do
		fields[#fields + 1] = value
	end
	local function field(i)
		local v = fields[i]
		return (v and v ~= "") and v or "0"
	end
	return field(1) .. ":" .. field(7) .. ":" .. field(8)
end

ns.Listen("ITEMS_CHANGED", function()
	wipe(own)
	ns.Tracker.ForEach(function(rec, _, entry)
		local key = C.KeyFromLink(entry.link)
		if key then own[key] = { rec = rec, link = entry.link, bank = entry.bank } end
	end)
end)

-- Name of the item with this key, as owner calls it. Without an owner,
-- or when the owner is us, our own items are used.
function C.Lookup(key, owner)
	if not key then return end
	if not owner or owner == ns.playerName then
		local item = own[key]
		if item then return ns.Names.Get(item.rec, item.link) end
		return
	end
	local name = ns.db.others and remote[owner] and remote[owner][key]
	if name then
		return name, ns.Stories.Format(ns.L().names.why.remote, { owner = owner })
	end
end

function C.OwnRecord(key)
	local item = key and own[key]
	return item and item.rec, item and item.link
end

function C.LastOwner(key)
	return lastOwner[key]
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function pump()
	local m = table.remove(queue, 1)
	if not m then
		sending = false
		return
	end
	pcall(ns.SendAddonMessage, PREFIX, m.text, m.channel, m.target)
	C_Timer.After(SEND_INTERVAL, pump)
end

local function send(text, channel, target)
	table.insert(queue, { text = text, channel = channel, target = target })
	if not sending then
		sending = true
		pump()
	end
end

local function nameMessage(key)
	local item = own[key]
	local name = item and ns.Names.Get(item.rec, item.link)
	if name then return "N\t" .. key .. "\t" .. name end
end

local function groupChannel()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
end

-- Sends the names of everything we carry (not the bank) to channel.
function C.SendAll(channel, target)
	local count = 0
	for key, item in pairs(own) do
		local text = not item.bank and nameMessage(key)
		if text and count < MAX_BROADCAST then
			count = count + 1
			send(text, channel, target)
		end
	end
end

local function sendOne(rec)
	for key, item in pairs(own) do
		if item.rec == rec then
			local text = nameMessage(key)
			if text then
				if IsInGuild() then send(text, "GUILD") end
				local group = groupChannel()
				if group then send(text, group) end
			end
		end
	end
end
ns.Listen("NAME_SET", sendOne)

function C.Ask(owner, key)
	if not ns.db.others or not owner or owner == "" then return end
	local id = owner .. ":" .. key
	if asked[id] then return end
	asked[id] = true
	send("Q\t" .. key, "WHISPER", owner)
end

ns.Listen("LOGIN", function()
	ns.RegisterPrefix(PREFIX)
	C_Timer.After(10, function()
		if IsInGuild() then C.SendAll("GUILD") end
	end)
end)

local groupSize = 0
ns.On("GROUP_ROSTER_UPDATE", function()
	local size = GetNumGroupMembers and GetNumGroupMembers() or 0
	local grew = size > groupSize and size > 1
	groupSize = size
	if grew then
		C_Timer.After(3, function()
			local group = groupChannel()
			if group then C.SendAll(group) end
		end)
	end
end)

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

ns.On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
	if prefix ~= PREFIX or not sender then return end
	local who = Ambiguate(sender, "none")
	if who == ns.playerName then return end

	local kind, key, name = text:match("^(%a)\t([%-%d:]+)\t?(.*)$")
	if kind == "N" then
		name = ns.Names.Clean(name, MAX_REMOTE_NAME)
		if name ~= "" then
			remote[who] = remote[who] or {}
			remote[who][key] = name
		end
	elseif kind == "Q" then
		local reply = nameMessage(key)
		if reply then send(reply, "WHISPER", sender) end
	end
end)

---------------------------------------------------------------------------
-- Chat: show item links with their names
---------------------------------------------------------------------------

local CHAT_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function filter(_, event, msg, author, ...)
	if type(msg) ~= "string" or not msg:find("|Hitem:", 1, true) then return false end
	-- In a sent whisper the author is the person we wrote to.
	local mine = event == "CHAT_MSG_WHISPER_INFORM" or Ambiguate(author or "", "none") == ns.playerName
	local owner = mine and ns.playerName or Ambiguate(author or "", "none")

	local renamed = msg:gsub("(|Hitem:[^|]+|h)%[(.-)%](|h)", function(open, original, close)
		local key = C.KeyFromLink(open)
		if not key then return end
		lastOwner[key] = owner
		local name = C.Lookup(key, owner)
		if not name then
			if not mine then C.Ask(author, key) end
			return
		end
		return open .. "[" .. name .. "]" .. close
	end)
	return false, renamed, author, ...
end

if ChatFrame_AddMessageEventFilter then
	for _, event in ipairs(CHAT_EVENTS) do
		ChatFrame_AddMessageEventFilter(event, filter)
	end
end
