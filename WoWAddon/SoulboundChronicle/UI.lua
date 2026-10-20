local _, ns = ...

-- The chronicle window: a chronicle page, an items page and settings.
-- Built from plain textures and stock templates so it looks the same on
-- every client.
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 540, 580
local PAD = 16
local HEADER_HEIGHT = 64
local TAB_BAR_Y = -HEADER_HEIGHT - 4
local BODY_TOP = TAB_BAR_Y - 34
local SCROLLBAR = 26
local ROW_WIDTH = WIDTH - PAD * 2 - SCROLLBAR
local MAX_SHOWN = 300

local C = {
	bg = { 0.055, 0.047, 0.04, 0.97 },
	header = { 0.13, 0.095, 0.06, 1 },
	border = { 0.6, 0.47, 0.24, 1 },
	line = { 0.6, 0.47, 0.24, 0.35 },
	rowHover = { 1, 0.85, 0.5, 0.06 },
	card = { 1, 1, 1, 0.03 },
	text = { 0.92, 0.88, 0.78 },
	dim = { 0.62, 0.57, 0.48 },
	gold = { 1, 0.82, 0 },
}

local ICONS = {
	begin = "Interface\\Icons\\INV_Misc_Book_09",
	level = "Interface\\Icons\\Spell_Holy_InnerFire",
	zone = "Interface\\Icons\\INV_Misc_Map_01",
	instance = "Interface\\Icons\\INV_Misc_Key_03",
	kill = "Interface\\Icons\\INV_Sword_04",
	boss = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	death = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
	neardeath = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
	item = "Interface\\Icons\\INV_Misc_Bag_10",
	renamed = "Interface\\Icons\\INV_Misc_Note_01",
}
local HEADER_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local getQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor

local frame, scroll, content, settingsPage
local tabs = {}
local mode = "chronicle"
local query = ""

---------------------------------------------------------------------------
-- Small building blocks
---------------------------------------------------------------------------

local function fill(parent, color, layer)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function border(f, color)
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", nil, 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
	}
	for _, e in ipairs(edges) do
		local t = fill(f, color, "BORDER")
		t:SetPoint(e[1])
		t:SetPoint(e[2])
		if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
	end
end

local function hline(parent, y, color)
	local t = fill(parent, color or C.line, "ARTWORK")
	t:SetHeight(1)
	t:SetPoint("TOPLEFT", PAD, y)
	t:SetPoint("TOPRIGHT", -PAD, y)
	return t
end

local function text(parent, font, color, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function plain(s)
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

local function matches(...)
	if query == "" then return true end
	for i = 1, select("#", ...) do
		local s = select(i, ...)
		if s and plain(s):lower():find(query, 1, true) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Row pools: rows are reused between refreshes.
---------------------------------------------------------------------------

local pools = {}

local function acquire(kind, create)
	local pool = pools[kind]
	if not pool then
		pool = { used = 0 }
		pools[kind] = pool
	end
	pool.used = pool.used + 1
	local row = pool[pool.used]
	if not row then
		row = create()
		pool[pool.used] = row
	end
	row:Show()
	return row
end

local function releaseAll()
	for _, pool in pairs(pools) do
		for i = 1, #pool do pool[i]:Hide() end
		pool.used = 0
	end
end

local function place(row, y, height)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	row:SetSize(ROW_WIDTH, height)
	return y + height
end

---------------------------------------------------------------------------
-- Chronicle page
---------------------------------------------------------------------------

local function newDateRow()
	local row = CreateFrame("Frame", nil, content)
	row.label = text(row, "GameFontNormal", C.gold)
	row.label:SetPoint("LEFT", 2, -2)
	row.line = fill(row, C.line, "ARTWORK")
	row.line:SetHeight(1)
	row.line:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
	row.line:SetPoint("RIGHT", -2, -2)
	return row
end

local function newEntryRow()
	local row = CreateFrame("Frame", nil, content)
	row:EnableMouse(true)
	row.hover = fill(row, C.rowHover)
	row.hover:SetAllPoints()
	row.hover:Hide()
	row:SetScript("OnEnter", function(self) self.hover:Show() end)
	row:SetScript("OnLeave", function(self) self.hover:Hide() end)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("TOPLEFT", 4, -4)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.time = text(row, "GameFontDisableSmall", nil, "RIGHT")
	row.time:SetPoint("TOPRIGHT", -4, -6)
	row.time:SetWidth(40)

	row.text = text(row, "GameFontHighlight", C.text)
	row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
	row.text:SetWidth(ROW_WIDTH - 32 - 48)
	row.text:SetSpacing(2)
	return row
end

local function showChronicle()
	local L = ns.L()
	local journal = ns.char.journal
	local y, lastDate, shown, total = 0, nil, 0, 0

	for i = #journal, 1, -1 do
		local e = journal[i]
		local line = ns.Stories.Entry(e)
		if line then
			total = total + 1
			if shown < MAX_SHOWN and matches(line) then
				shown = shown + 1
				local day = ns.Stories.Date(e.t)
				if day ~= lastDate then
					local header = acquire("date", newDateRow)
					header.label:SetText(day)
					y = place(header, y + (lastDate and 8 or 0), 22)
					lastDate = day
				end
				local row = acquire("entry", newEntryRow)
				row.icon:SetTexture(ICONS[e.k] or ICONS.begin)
				row.time:SetText(date("%H:%M", e.t))
				row.text:SetText(line)
				y = place(row, y, math.max(28, row.text:GetStringHeight() + 12))
			end
		end
	end

	if total == 0 then return L.ui.noEntries, "" end
	if shown == 0 then return L.ui.noMatches, "" end
	local status = shown < total
		and ns.Stories.Format(L.ui.showing, { shown = shown, count = total })
		or (total == 1 and L.ui.entriesOne or ns.Stories.Format(L.ui.entries, { count = total }))
	return nil, status, y
end

---------------------------------------------------------------------------
-- Items page
---------------------------------------------------------------------------

local function itemTooltip(row)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local key = row.key
	local slot = key:match("^e:(%d+)$")
	local bag, bagSlot = key:match("^b:(%-?%d+):(%d+)$")
	if slot then
		GameTooltip:SetInventoryItem("player", tonumber(slot))
	elseif bag and not row.bank then
		GameTooltip:SetBagItem(tonumber(bag), tonumber(bagSlot))
	elseif row.link then
		GameTooltip:SetHyperlink(row.link)
	end
	GameTooltip:Show()
end

local function newSectionRow()
	local row = CreateFrame("Frame", nil, content)
	row.label = text(row, "GameFontNormal", C.gold)
	row.label:SetPoint("LEFT", 2, -2)
	row.count = text(row, "GameFontDisableSmall")
	row.count:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
	row.line = fill(row, C.line, "ARTWORK")
	row.line:SetHeight(1)
	row.line:SetPoint("LEFT", row.count, "RIGHT", 8, 0)
	row.line:SetPoint("RIGHT", -2, -2)
	return row
end

local function newItemRow()
	local row = CreateFrame("Button", nil, content)
	row:RegisterForClicks("RightButtonUp")
	row.bg = fill(row, C.card)
	row.bg:SetAllPoints()
	row.hover = fill(row, C.rowHover, "BACKGROUND")
	row.hover:SetAllPoints()
	row.hover:Hide()

	row.iconBorder = fill(row, C.border, "ARTWORK")
	row.iconBorder:SetSize(38, 38)
	row.iconBorder:SetPoint("TOPLEFT", 6, -6)
	row.icon = row:CreateTexture(nil, "OVERLAY")
	row.icon:SetSize(36, 36)
	row.icon:SetPoint("CENTER", row.iconBorder)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.name = text(row, "GameFontNormal")
	row.name:SetPoint("TOPLEFT", row.iconBorder, "TOPRIGHT", 10, -1)
	row.name:SetWidth(ROW_WIDTH - 62)
	row.original = text(row, "GameFontDisableSmall")
	row.original:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.original:SetWidth(ROW_WIDTH - 62)
	row.story = text(row, "GameFontHighlightSmall", C.dim)
	row.story:SetPoint("TOPLEFT", row.original, "BOTTOMLEFT", 0, -5)
	row.story:SetWidth(ROW_WIDTH - 62)
	row.story:SetSpacing(2)

	row:SetScript("OnEnter", function(self)
		self.hover:Show()
		itemTooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(self)
		ns.Names.SetHovered(self.rec, self.link)
		ns.Names.PromptRename()
	end)
	return row
end

local function itemTitle(rec, link)
	local name = ns.Names.Get(rec, link)
	local original = link and link:match("|h%[(.-)%]|h") or ns.GetItemInfo(rec.id) or "?"
	return name or original, name and original or nil
end

local function showItems()
	local L = ns.L()
	local groups = { equipped = {}, bags = {}, bank = {} }
	local total = 0
	ns.Tracker.ForEach(function(rec, key, entry)
		total = total + 1
		local link = entry.link or rec.link
		local title, original = itemTitle(rec, link)
		local story = ns.Stories.ItemLines(rec, link)
		if matches(title, original, table.concat(story, " ")) then
			local group = key:sub(1, 1) == "e" and "equipped" or entry.bank and "bank" or "bags"
			table.insert(groups[group], {
				rec = rec, link = link, key = key, bank = entry.bank,
				title = title, original = original, story = story,
			})
		end
	end)

	local y, shown = 0, 0
	for _, group in ipairs({ "equipped", "bags", "bank" }) do
		local list = groups[group]
		if #list > 0 then
			table.sort(list, function(a, b) return a.key < b.key end)
			local header = acquire("section", newSectionRow)
			header.label:SetText(L.ui[group])
			header.count:SetText(#list)
			y = place(header, y + (shown > 0 and 10 or 0), 24)

			for _, item in ipairs(list) do
				shown = shown + 1
				local row = acquire("item", newItemRow)
				row.rec, row.link, row.key, row.bank = item.rec, item.link, item.key, item.bank

				local _, _, _, _, icon = ns.GetItemInfoInstant(item.rec.id)
				row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				local _, _, quality = ns.GetItemInfo(item.link or item.rec.id)
				local r, g, b = 1, 1, 1
				if quality and getQualityColor then r, g, b = getQualityColor(quality) end
				row.iconBorder:SetColorTexture(r, g, b, 0.9)
				row.name:SetText(item.title)
				row.name:SetTextColor(r, g, b)

				-- The original name is the first story line when renamed.
				local story = item.story
				if item.original then
					row.original:SetText(story[1])
					story = { select(2, unpack(story)) }
				else
					row.original:SetText("")
				end
				row.story:SetText(table.concat(story, "\n"))

				local height = 14 + row.name:GetStringHeight() + row.original:GetStringHeight()
					+ row.story:GetStringHeight() + 12
				y = place(row, y, math.max(50, height)) + 4
			end
		end
	end

	if total == 0 then return L.ui.noItems, "" end
	if shown == 0 then return L.ui.noMatches, "" end
	local count = total == 1 and L.ui.itemCountOne or ns.Stories.Format(L.ui.itemCount, { count = total })
	return nil, count .. "  ·  " .. L.ui.renameHint, y
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------

local function buildSettings()
	settingsPage = CreateFrame("Frame", nil, frame)
	settingsPage:SetPoint("TOPLEFT", PAD, BODY_TOP)
	settingsPage:SetPoint("BOTTOMRIGHT", -PAD, 40)
	settingsPage.checks = {}

	local y = -6
	for _, option in ipairs(ns.L().ui.options) do
		local check = CreateFrame("CheckButton", nil, settingsPage, "UICheckButtonTemplate")
		check:SetSize(26, 26)
		check:SetPoint("TOPLEFT", 0, y)
		check.key = option.key
		check:SetScript("OnClick", function(self)
			ns.db[self.key] = self:GetChecked() and true or false
			ns.Fire("NAMES_CHANGED")
		end)

		local label = text(settingsPage, "GameFontNormal", C.gold)
		label:SetPoint("TOPLEFT", check, "TOPRIGHT", 6, -4)
		label:SetText(option.label)
		local desc = text(settingsPage, "GameFontHighlightSmall", C.dim)
		desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
		desc:SetWidth(WIDTH - PAD * 2 - 40)
		desc:SetText(option.text)

		table.insert(settingsPage.checks, check)
		y = y - 52
	end

	local hint = text(settingsPage, "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 4, y - 8)
	hint:SetWidth(WIDTH - PAD * 2 - 8)
	hint:SetText(ns.L().ui.help[3] .. "\n" .. ns.L().ui.help[4])
end

local function showSettings()
	for _, check in ipairs(settingsPage.checks) do
		check:SetChecked(ns.db[check.key] and true or false)
	end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function savePosition()
	local point, _, relPoint, x, y = frame:GetPoint()
	ns.db.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function makeTab(key, label)
	local tab = CreateFrame("Button", nil, frame)
	tab:SetHeight(24)
	tab.label = text(tab, "GameFontNormal")
	tab.label:SetPoint("CENTER", 0, 1)
	tab.label:SetText(label)
	tab:SetWidth(tab.label:GetStringWidth() + 24)
	tab.underline = fill(tab, C.gold, "ARTWORK")
	tab.underline:SetHeight(2)
	tab.underline:SetPoint("BOTTOMLEFT", 6, 0)
	tab.underline:SetPoint("BOTTOMRIGHT", -6, 0)
	tab:SetScript("OnClick", function() UI.Show(key) end)
	tab:SetScript("OnEnter", function(self) if mode ~= key then self.label:SetTextColor(1, 1, 1) end end)
	tab:SetScript("OnLeave", function() UI.UpdateTabs() end)
	tabs[key] = tab
	return tab
end

function UI.UpdateTabs()
	for key, tab in pairs(tabs) do
		local active = key == mode
		tab.underline:SetShown(active)
		local c = active and C.gold or C.dim
		tab.label:SetTextColor(c[1], c[2], c[3])
	end
end

local function build()
	local L = ns.L()
	frame = CreateFrame("Frame", "SoulboundChronicleFrame", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	local pos = ns.db.window
	if pos then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER")
	end
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	frame:Hide()
	table.insert(UISpecialFrames, "SoulboundChronicleFrame")

	fill(frame, C.bg):SetAllPoints()
	border(frame, C.border)

	-- Header
	local header = fill(frame, C.header, "BORDER")
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_HEIGHT)
	local headerLine = fill(frame, C.border, "ARTWORK")
	headerLine:SetHeight(1)
	headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

	local iconBorder = fill(frame, C.border, "ARTWORK")
	iconBorder:SetSize(42, 42)
	iconBorder:SetPoint("TOPLEFT", PAD, -11)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetSize(40, 40)
	icon:SetPoint("CENTER", iconBorder)
	icon:SetTexture(HEADER_ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.title = text(frame, "GameFontNormalLarge", C.gold)
	frame.title:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 12, -4)
	frame.title:SetText(L.ui.title)
	frame.subtitle = text(frame, "GameFontHighlightSmall", C.dim)
	frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	-- Tabs and search
	local prev
	for _, key in ipairs({ "chronicle", "items", "settings" }) do
		local tab = makeTab(key, L.ui[key])
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
		else
			tab:SetPoint("TOPLEFT", PAD - 6, TAB_BAR_Y)
		end
		prev = tab
	end

	local search = CreateFrame("EditBox", "SoulboundChronicleSearch", frame, "InputBoxTemplate")
	search:SetSize(150, 20)
	search:SetPoint("TOPRIGHT", -PAD, TAB_BAR_Y - 2)
	search:SetAutoFocus(false)
	search.placeholder = text(search, "GameFontDisableSmall")
	search.placeholder:SetPoint("LEFT", 2, 0)
	search.placeholder:SetText(L.ui.search)
	search:SetScript("OnTextChanged", function(self)
		local value = strtrim(self:GetText() or "")
		self.placeholder:SetShown(value == "")
		value = value:lower()
		if value ~= query then
			query = value
			UI.Refresh()
		end
	end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	frame.search = search

	hline(frame, BODY_TOP + 6)

	-- Scrolling body for the chronicle and items pages
	scroll = CreateFrame("ScrollFrame", "SoulboundChronicleScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PAD, BODY_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR + 4, 40)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(ROW_WIDTH, 10)
	scroll:SetScrollChild(content)

	frame.empty = text(frame, "GameFontDisable", nil, "CENTER")
	frame.empty:SetPoint("TOP", 0, BODY_TOP - 60)
	frame.empty:SetWidth(WIDTH - PAD * 4)

	buildSettings()

	-- Footer
	hline(frame, -(HEIGHT - 36))
	frame.status = text(frame, "GameFontDisableSmall")
	frame.status:SetPoint("BOTTOMLEFT", PAD, 14)
	frame.status:SetWidth(WIDTH - PAD * 2 - 110)

	frame.export = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.export:SetSize(96, 22)
	frame.export:SetPoint("BOTTOMRIGHT", -PAD, 8)
	frame.export:SetText(L.ui.export)
	frame.export:SetScript("OnClick", function() UI.Export() end)
end

function UI.Refresh()
	if not frame or not frame:IsShown() then return end
	local L = ns.L()
	UI.UpdateTabs()
	frame.subtitle:SetText(ns.Stories.Format(L.ui.subtitle, {
		player = ns.playerName or UnitName("player"),
		level = UnitLevel("player"),
	}))

	local isSettings = mode == "settings"
	settingsPage:SetShown(isSettings)
	scroll:SetShown(not isSettings)
	frame.search:SetShown(not isSettings)
	frame.export:SetShown(mode == "chronicle")
	releaseAll()

	if isSettings then
		frame.empty:Hide()
		frame.status:SetText("")
		showSettings()
		return
	end

	local empty, status, height
	if mode == "items" then
		empty, status, height = showItems()
	else
		empty, status, height = showChronicle()
	end
	frame.empty:SetText(empty or "")
	frame.empty:SetShown(empty ~= nil)
	frame.status:SetText(status or "")
	content:SetHeight(math.max(10, height or 0))
end

function UI.Show(newMode)
	if not frame then build() end
	if newMode and newMode ~= mode then
		mode = newMode
		scroll:SetVerticalScroll(0)
	end
	frame:Show()
	UI.Refresh()
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
ns.Listen("NAMES_CHANGED", function() if mode ~= "chronicle" then UI.Refresh() end end)

---------------------------------------------------------------------------
-- Export window: plain text to copy out of the game
---------------------------------------------------------------------------

local exportFrame

function UI.Export()
	if not exportFrame then
		exportFrame = CreateFrame("Frame", "SoulboundChronicleExport", UIParent)
		exportFrame:SetSize(WIDTH - 40, 400)
		exportFrame:SetPoint("CENTER", 40, -40)
		exportFrame:SetFrameStrata("DIALOG")
		exportFrame:SetClampedToScreen(true)
		exportFrame:SetMovable(true)
		exportFrame:EnableMouse(true)
		exportFrame:RegisterForDrag("LeftButton")
		exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
		exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
		table.insert(UISpecialFrames, "SoulboundChronicleExport")
		fill(exportFrame, C.bg):SetAllPoints()
		border(exportFrame, C.border)

		exportFrame.title = text(exportFrame, "GameFontNormal", C.gold)
		exportFrame.title:SetPoint("TOPLEFT", PAD, -12)
		local close = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)
		hline(exportFrame, -34)

		local s = CreateFrame("ScrollFrame", "SoulboundChronicleExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
		s:SetPoint("TOPLEFT", PAD, -42)
		s:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR + 4, 14)

		local edit = CreateFrame("EditBox", nil, s)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(WIDTH - 40 - PAD * 2 - SCROLLBAR)
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
	exportFrame.title:SetText(L.ui.export .. "  ·  " .. L.ui.exportHint)
	exportFrame:Show()
	exportFrame.edit:SetText(table.concat(lines, "\n"))
	exportFrame.edit:SetFocus()
	exportFrame.edit:HighlightText()
end
