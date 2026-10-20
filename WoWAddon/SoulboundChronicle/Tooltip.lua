local _, ns = ...

local HEADER = { 0.62, 0.48, 1 }
local TEXT = { 0.85, 0.8, 0.65 }

local function setTitle(tooltip, name)
	local line = _G[tooltip:GetName() .. "TextLeft1"]
	if line then line:SetText(name) end
end

local function addLines(tooltip, lines)
	tooltip:AddLine(" ")
	tooltip:AddLine(ns.L().ui.title, HEADER[1], HEADER[2], HEADER[3])
	for _, line in ipairs(lines) do
		tooltip:AddLine(line, TEXT[1], TEXT[2], TEXT[3], true)
	end
end

-- One of our own items: new name on top, its story below.
local function showOwn(tooltip, rec, link)
	if not rec or not ns.db then return end
	ns.Names.SetHovered(rec, link)
	local name = ns.Names.Get(rec, link)
	if name then setTitle(tooltip, name) end
	if ns.db.tooltip then addLines(tooltip, ns.Stories.ItemLines(rec, link)) end
	tooltip:Show()
end

-- Someone else's item: only the name they gave it.
local function showRemote(tooltip, link, owner)
	local key = ns.Comm.KeyFromLink(link)
	local name, reasons = ns.Comm.Lookup(key, owner)
	if not name then return false end
	setTitle(tooltip, name)
	local original = link:match("|h%[(.-)%]|h") or ns.GetItemInfo(link)
	local lines = { ns.Stories.Format(ns.L().names.originally, { name = original or "?" }) }
	for _, reason in ipairs(reasons or {}) do table.insert(lines, reason) end
	addLines(tooltip, lines)
	tooltip:Show()
	return true
end

-- The main bank slots show their tooltips as inventory slots.
local function bankKey(invSlot)
	if not BankButtonIDToInvSlotID then return end
	for i = 1, NUM_BANKGENERIC_SLOTS or 28 do
		if BankButtonIDToInvSlotID(i) == invSlot then
			return "b:" .. (BANK_CONTAINER or -1) .. ":" .. i
		end
	end
end

hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
	showOwn(tooltip, ns.Tracker.RecordAt("b:" .. bag .. ":" .. slot), ns.GetBagItemLink(bag, slot))
end)

hooksecurefunc(GameTooltip, "SetInventoryItem", function(tooltip, unit, slot)
	if not slot or not ns.db then return end
	if UnitIsUnit(unit, "player") then
		local key = slot <= 19 and "e:" .. slot or bankKey(slot)
		if key then showOwn(tooltip, ns.Tracker.RecordAt(key), GetInventoryItemLink("player", slot)) end
		return
	end
	-- Inspecting someone else.
	local link = GetInventoryItemLink(unit, slot)
	local full = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
	if not link or not full then return end
	if not showRemote(tooltip, link, Ambiguate(full, "none")) then
		ns.Comm.Ask(full, ns.Comm.KeyFromLink(link))
	end
end)

-- Item links in chat.
local function onHyperlink(tooltip, link)
	if not ns.db or type(link) ~= "string" or not link:find("item:", 1, true) then return end
	local key = ns.Comm.KeyFromLink(link)
	local owner = ns.Comm.LastOwner(key)
	if not owner or owner == ns.playerName then
		local rec, ownLink = ns.Comm.OwnRecord(key)
		if rec then showOwn(tooltip, rec, ownLink) end
	else
		showRemote(tooltip, link, owner)
	end
end

hooksecurefunc(GameTooltip, "SetHyperlink", onHyperlink)
if ItemRefTooltip then hooksecurefunc(ItemRefTooltip, "SetHyperlink", onHyperlink) end
