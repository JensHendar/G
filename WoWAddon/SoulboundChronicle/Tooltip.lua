local _, ns = ...

local HEADER = { 0.62, 0.48, 1 }
local TEXT = { 0.85, 0.8, 0.65 }

local function addStory(tooltip, rec)
	if not rec or not ns.db.tooltip then return end
	tooltip:AddLine(" ")
	tooltip:AddLine(ns.L().ui.title, HEADER[1], HEADER[2], HEADER[3])
	for _, line in ipairs(ns.Stories.ItemLines(rec)) do
		tooltip:AddLine(line, TEXT[1], TEXT[2], TEXT[3], true)
	end
	tooltip:Show()
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
	addStory(tooltip, ns.Tracker.RecordAt("b:" .. bag .. ":" .. slot))
end)

hooksecurefunc(GameTooltip, "SetInventoryItem", function(tooltip, unit, slot)
	if not slot or not UnitIsUnit(unit, "player") then return end
	local key = slot <= 19 and "e:" .. slot or bankKey(slot)
	if key then addStory(tooltip, ns.Tracker.RecordAt(key)) end
end)
