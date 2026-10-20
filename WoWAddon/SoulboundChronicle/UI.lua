local _, ns = ...

local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 480, 540
local TEXT_WIDTH = WIDTH - 60
local MAX_SHOWN = 300
local DATE_COLOR = "|cffffd100"
local DIM_COLOR = "|cffb8ad8f"

local frame, scroll, text, tabs
local mode = "chronicle"

---------------------------------------------------------------------------
-- Page text
---------------------------------------------------------------------------

local function chronicleText()
	local journal = ns.char.journal
	if #journal == 0 then return ns.L().ui.noEntries end
	local out, lastDate = {}, nil
	for i = math.max(1, #journal - MAX_SHOWN + 1), #journal do
		local e = journal[i]
		local line = ns.Stories.Entry(e)
		if line then
			local day = ns.Stories.Date(e.t)
			if day ~= lastDate then
				if lastDate then table.insert(out, "") end
				table.insert(out, DATE_COLOR .. day .. "|r")
				lastDate = day
			end
			table.insert(out, "  " .. date("%H:%M", e.t) .. "  " .. line)
		end
	end
	return table.concat(out, "\n")
end

local function itemsText()
	local L = ns.L()
	local groups = { equipped = {}, bags = {}, bank = {} }
	ns.Tracker.ForEach(function(rec, key, entry)
		local group = key:sub(1, 1) == "e" and "equipped" or entry.bank and "bank" or "bags"
		table.insert(groups[group], { rec = rec, link = entry.link or rec.link, key = key })
	end)

	local out = {}
	for _, group in ipairs({ "equipped", "bags", "bank" }) do
		local list = groups[group]
		if #list > 0 then
			table.sort(list, function(a, b) return a.key < b.key end)
			if #out > 0 then table.insert(out, "") end
			table.insert(out, DATE_COLOR .. L.ui[group] .. "|r")
			for _, item in ipairs(list) do
				table.insert(out, "")
				local name = ns.Names.Get(item.rec, item.link)
				local shown = item.link or "?"
				if name and item.link then
					shown = item.link:gsub("%[.-%]", function() return "[" .. name .. "]" end, 1)
				end
				table.insert(out, shown)
				for _, line in ipairs(ns.Stories.ItemLines(item.rec, item.link)) do
					table.insert(out, "  " .. DIM_COLOR .. line .. "|r")
				end
			end
		end
	end
	if #out == 0 then return L.ui.noItems end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------

local function setMode(newMode)
	mode = newMode
	for name, tab in pairs(tabs) do
		if name == mode then tab:LockHighlight() else tab:UnlockHighlight() end
	end
	UI.Refresh()
end

local function makeButton(parent, label, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function build()
	frame = CreateFrame("Frame", "SoulboundChronicleFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()
	table.insert(UISpecialFrames, "SoulboundChronicleFrame")

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)

	scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -32)
	scroll:SetPoint("BOTTOMRIGHT", -32, 42)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(TEXT_WIDTH, 10)
	scroll:SetScrollChild(content)

	text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT")
	text:SetWidth(TEXT_WIDTH)
	text:SetJustifyH("LEFT")
	text:SetSpacing(3)
	frame.content = content

	tabs = {
		chronicle = makeButton(frame, "", 110, function() setMode("chronicle") end),
		items = makeButton(frame, "", 110, function() setMode("items") end),
	}
	tabs.chronicle:SetPoint("BOTTOMLEFT", 12, 12)
	tabs.items:SetPoint("LEFT", tabs.chronicle, "RIGHT", 6, 0)
	frame.exportButton = makeButton(frame, "", 110, function() UI.Export() end)
	frame.exportButton:SetPoint("BOTTOMRIGHT", -12, 12)
end

function UI.Refresh()
	if not frame or not frame:IsShown() then return end
	local L = ns.L()
	frame.title:SetText(L.ui.title)
	tabs.chronicle:SetText(L.ui.chronicle)
	tabs.items:SetText(L.ui.items)
	frame.exportButton:SetText(L.ui.export)

	text:SetText(mode == "items" and itemsText() or chronicleText())
	frame.content:SetHeight(math.max(10, text:GetStringHeight()))
	C_Timer.After(0, function()
		scroll:SetVerticalScroll(mode == "chronicle" and scroll:GetVerticalScrollRange() or 0)
	end)
end

function UI.Show(newMode)
	if not frame then build() end
	frame:Show()
	setMode(newMode or mode)
end

function UI.Toggle(newMode)
	if frame and frame:IsShown() and (newMode or mode) == mode then
		frame:Hide()
	else
		UI.Show(newMode)
	end
end

ns.Listen("JOURNAL_CHANGED", function() if mode == "chronicle" then UI.Refresh() end end)
ns.Listen("ITEMS_CHANGED", function() if mode == "items" then UI.Refresh() end end)
ns.Listen("NAMES_CHANGED", function() if mode == "items" then UI.Refresh() end end)

---------------------------------------------------------------------------
-- Export window: plain text to copy out of the game
---------------------------------------------------------------------------

local exportFrame

local function plain(s)
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

function UI.Export()
	if not exportFrame then
		exportFrame = CreateFrame("Frame", "SoulboundChronicleExport", UIParent, "BasicFrameTemplateWithInset")
		exportFrame:SetSize(WIDTH, 400)
		exportFrame:SetPoint("CENTER", 40, -40)
		exportFrame:SetFrameStrata("DIALOG")
		exportFrame:SetMovable(true)
		exportFrame:EnableMouse(true)
		exportFrame:RegisterForDrag("LeftButton")
		exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
		exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
		table.insert(UISpecialFrames, "SoulboundChronicleExport")

		exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		exportFrame.title:SetPoint("TOP", 0, -5)

		local s = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
		s:SetPoint("TOPLEFT", 14, -32)
		s:SetPoint("BOTTOMRIGHT", -32, 14)

		local edit = CreateFrame("EditBox", nil, s)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(TEXT_WIDTH)
		edit:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
		s:SetScrollChild(edit)
		exportFrame.edit = edit
	end

	local L = ns.L()
	local lines = {}
	for _, e in ipairs(ns.char.journal) do
		local line = ns.Stories.Entry(e)
		if line then table.insert(lines, date("%Y-%m-%d %H:%M", e.t) .. "  " .. plain(line)) end
	end
	exportFrame.title:SetText(L.ui.title .. " - " .. L.ui.exportHint)
	exportFrame:Show()
	exportFrame.edit:SetText(table.concat(lines, "\n"))
	exportFrame.edit:SetFocus()
	exportFrame.edit:HighlightText()
end
