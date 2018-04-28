RSGUI.main = {}
RSGUI.main.__index = RSGUI.main

local MAX_HISTORY = 10

----------------------------------------------------------------------------------------------------
-- create a main panel
----------------------------------------------------------------------------------------------------
function RSGUI.main.new(settings)
	local self = setmetatable({}, RSGUI.main)

	self.settings = settings

	self.frame = CreateFrame("frame", "RSGUI_Main", UIParent)
	local panel = self.frame

	--------------------------------------------------
	-- the main window settings
	--------------------------------------------------
	panel:SetFrameStrata("HIGH")
	table.insert(UISpecialFrames, panel:GetName()) -- make it closable with escape key
	panel:SetBackdrop({
		bgFile="Interface/Tooltips/UI-Tooltip-Background",
		edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=32,
		insets={left=11, right=12, top=12, bottom=11}
	})
	panel:SetBackdropColor(0,0,0,1)
	panel:SetPoint("CENTER")
	local scaledWidth = math.floor(GetScreenWidth() * .65)
	panel:SetWidth(scaledWidth > 850 and scaledWidth or 850)
	panel:SetHeight(630)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

	--------------------------------------------------
	-- handle receiving an item/spell icon
	--------------------------------------------------
	local function ReceiveIcon()
		local cursorType, cursorId, cursorData = GetCursorInfo()
		if cursorType == "spell" then
			local submenu = cursorData == "pet" and "Pet" or UnitClass("player")
			self.content.reactions:CreateAndShowSpell((GetSpellName(cursorId, cursorData)), nil, submenu)
			ClearCursor()
		elseif cursorType == "item" then
			self.content.reactions:CreateAndShowSpell(cursorData:match("%[(.-)]"), nil, "Items")
			ClearCursor()
		end
	end

	--------------------------------------------------
	-- handle moving the window
	--------------------------------------------------
	panel:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not self.isMoving then
			ReceiveIcon()
			self:StartMoving()
			self.isMoving = true
		end
	end)
	panel:SetScript("OnReceiveDrag", function(self)
		local cursorType, cursorId, cursorData = GetCursorInfo()
		ReceiveIcon()
	end)
	panel:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
		end
	end)
	panel:SetScript("OnHide", function(self)
		if self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
		end
		CloseDropDownMenus()
	end)

	--------------------------------------------------
	-- left side
	--------------------------------------------------
	-- Enable/Disable checkbox
	self.enableCheckbox = RSGUI.Utility.CreateCheckbox("enable", panel, "Enable")
	self.enableCheckbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -15)
	self.enableCheckbox:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		_G.SlashCmdList["REACTIONS"]((this:GetChecked() and "on" or "off") .. " quiet")
	end)

	-- Test mode checkbox
	self.testModeCheckbox = RSGUI.Utility.CreateCheckbox("testMode", panel, "Test Mode", "This makes all reactions only be printed to you instead of really saying/doing them.")
	self.testModeCheckbox:SetPoint("LEFT", self.enableCheckbox, "RIGHT", 40, 0)
	self.testModeCheckbox:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		if self.settings then
			self.settings["testing"] = this:GetChecked()
		end
	end)

	-- Options button
	self.optionsButton = RSGUI.Utility.CreateButton("Main_Options", panel, 128, "Options & Info")
	self.optionsButton:SetPoint("TOPLEFT", self.enableCheckbox, "BOTTOMLEFT", 3, 0)
	self.optionsButton:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		self.content.options:Open()
	end)

	--------------------------------------------------
	-- main buttons
	--------------------------------------------------
	-- [<] history button
	self.historyButton = RSGUI.Utility.CreateButton("Main_History", panel, 24, "<")
	self.historyButton:SetPoint("BOTTOM", self.enableCheckbox, "BOTTOM", 0, 5) -- horizontally centered below
	self.historyButton:SetScript("OnClick", function()
		if not self.historyMenu then
			self:BuildHistoryMenu()
		end
		RSGUI.Utility.ClearAnyFocus()
		RSGUI.menu:Open(self.historyMenu, this)
	end)

	-- Groups button
	self.groupsButton = RSGUI.Utility.CreateButton("Main_Groups", panel, 80, "Groups")
	self.groupsButton:SetPoint("LEFT", self.historyButton, "RIGHT", 5, 0)
	self.groupsButton:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		RSGUI.menu:Open(self.groupsMenu, this)
	end)

	-- Events button
	self.eventsButton = RSGUI.Utility.CreateButton("Main_Events", panel, self.groupsButton:GetWidth(), "Events")
	self.eventsButton:SetPoint("LEFT", self.groupsButton, "RIGHT", 5, 0)
	self.eventsButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() RSGUI.menu:Open(self.eventsMenu, this) end)

	-- Spells button
	self.spellsButton = RSGUI.Utility.CreateButton("Main_Spells", panel, self.groupsButton:GetWidth(), "Spells")
	self.spellsButton:SetPoint("LEFT", self.eventsButton, "RIGHT", 5, 0)
	self.spellsButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() RSGUI.menu:Open(self.spellsMenu, this) end)

	-- Tags button
	self.tagsButton = RSGUI.Utility.CreateButton("Main_Tags", panel, self.groupsButton:GetWidth(), "Tags")
	self.tagsButton:SetPoint("LEFT", self.spellsButton, "RIGHT", 5, 0)
	self.tagsButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() RSGUI.menu:Open(self.tagsMenu, this) end)

	-- Chat button
	self.chatButton = RSGUI.Utility.CreateButton("Main_Chat", panel, self.groupsButton:GetWidth(), "Chat")
	self.chatButton:SetPoint("LEFT", self.tagsButton, "RIGHT", 5, 0)
	self.chatButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() RSGUI.menu:Open(self.chatMenu, this) end)

	-- Search button
	self.searchButton = RSGUI.Utility.CreateButton("Main_Search", panel, self.groupsButton:GetWidth(), "Search")
	self.searchButton:SetPoint("LEFT", self.chatButton, "RIGHT", 5, 0)
	self.searchButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() self.content.search:Open() end)

	-- [?] help button
	self.helpButton = RSGUI.Utility.CreateButton("Main_Help", panel, 24, "?")
	self.helpButton:SetPoint("LEFT", self.searchButton, "RIGHT", 5, 0)
	self.helpButton:SetScript("OnClick", function() RSGUI.menu:Open(self.helpMenu, this) end)

	-- center the top buttons
	self.historyButton:SetPoint("LEFT", panel, "CENTER", 0-((self.helpButton:GetRight()-self.historyButton:GetLeft())/2), 0)

	--------------------------------------------------
	-- Currently opened text
	--------------------------------------------------
	self.textHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textHeader:SetFont("Fonts/ARIALN.ttf", 18, "OUTLINE")
	self.textHeader:SetWidth(400)
	self.textHeader:SetPoint("LEFT", panel, "CENTER", 0 - self.textHeader:GetWidth()/2, 0)
	self.textHeader:SetPoint("TOP", self.groupsButton, "BOTTOM", 0, -5)

	--------------------------------------------------
	-- close button
	--------------------------------------------------
	self.closeButton = CreateFrame("Button", "RSGUI_Main_closeButton", panel, "UIPanelCloseButton")
	self.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)

	--------------------------------------------------
	-- border between top and content part
	--------------------------------------------------
	self.separator = panel:CreateTexture()
	self.separator:SetTexture(.4, .4, .4)
	self.separator:SetWidth(panel:GetWidth()-32)
	self.separator:SetHeight(3)
	self.separator:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.optionsButton:GetBottom())-4)

	--------------------------------------------------
	-- content frame
	--------------------------------------------------
	-- main contents panel - all other content panels go on top of it
	self.content = CreateFrame("frame", "RSGUI_Main_content", panel)

	self.content:SetWidth(panel:GetWidth()-46)
	self.content:SetHeight(panel:GetHeight()-(panel:GetTop()-self.separator:GetBottom())-30)
	self.content:SetPoint("TOP", self.separator, "TOP", 0, -15)

	--------------------------------------------------
	-- opening function
	--------------------------------------------------
	panel:SetScript("OnShow", function()
		if self.settings then
			self:BuildGroupsMenu(false)
			self:BuildSpellsMenu(false)
			self:BuildEventsMenu()
			self:BuildTagsMenu(false)
			self:BuildChatMenu(false)
			self:UpdateWidgets()
			self.content.reactions:CreateRoleItemMenu()
		end
	end)

	return self
end

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- return true if a spell/event has at least one reaction set
function RSGUI.main:SpellHasReaction(name)
	local data = self.settings["reactionList"][name]
	if data then
		for _,action in pairs(data) do
			if type(action) == "table" then
				if action.reactions and #action.reactions > 0 then
					return true
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- setting contents
----------------------------------------------------------------------------------------------------
-- set the header text above the content panel
function RSGUI.main:SetHeaderText(text)
	if #text > 35 then
		text = text:sub(1, 35) .. "..."
	end
	self.textHeader:SetText(text)
end

function RSGUI.main:AddContentFrame(name, contents)
	contents.frame:SetParent(self.content)
	contents.frame:SetWidth(self.content:GetWidth())
	contents.frame:SetHeight(self.content:GetHeight())
	contents.frame:SetPoint("CENTER", self.content)
	self.content[name] = contents
end

-- hide all content frame panels except an optional specific one
function RSGUI.main:HideContentExcept(frame)
	CloseDropDownMenus()
	local children = {self.content:GetChildren()}
	for i=1,#children do
		if frame ~= children[i] then
			children[i]:Hide()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- opening GUI
----------------------------------------------------------------------------------------------------
-- updating display of options - called from the command line if settings are changed there
function RSGUI.main:UpdateWidgets()
	local settings = self.settings
	self.enableCheckbox:SetChecked(settings["enabled"])
	self.testModeCheckbox:SetChecked(settings["testing"])
	self.content.options:Update()
end

function RSGUI.main:Show()
	self.frame:Show()
end

----------------------------------------------------------------------------------------------------
-- build main button menus
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- History
--------------------------------------------------
function RSGUI.main:AddHistory(historyType, name, text, action)
	self:RemoveHistory(historyType, name, action)
	for i=#self.settings.history, MAX_HISTORY, -1 do -- not MAX_HISTORY+1 because the new one hasn't been added
		self.settings.history[i] = nil
	end
	table.insert(self.settings.history, 1, {historyType, name, text, action})
	self.historyMenu = nil
end

function RSGUI.main:RemoveHistory(historyType, name, action)
	local history = self.settings.history
	local item
	for i=#history,1,-1 do
		item = history[i]
		if item[2] == name and item[1] == historyType and (not action or item[4] == action) then
			table.remove(self.settings.history, i)
			self.historyMenu = nil
		end
	end
end

function RSGUI.main:RenameReactionHistory(oldName, newName, displayName)
	for i,v in ipairs(self.settings.history) do
		if v[2] == oldName then
			v[2] = newName
			v[3] = v[3]:gsub("^Spell: .+ %- (.+)$", function(action) return "Spell: " .. displayName .. " - " .. action end)
			self.historyMenu = nil
		end
	end
end

local function OpenHistory(self, index)
	local item = self.settings.history[index]
	if item then
		local hType = item[1]
		if hType == "spell" or hType == "event" then
			self.content.reactions:Open(item[2], (hType == "event"), item[4])
		elseif hType == "chat" then
			self.content.chat:Open(item[2])
		elseif hType == "tag" then
			self.content.tags:Open(item[2])
		end
	end
end

function RSGUI.main:BuildHistoryMenu()
	local historyMenu = {}
	self.historyMenu = historyMenu

	historyMenu[1] = {notCheckable=1, text="History", isTitle=true}
	for i,v in ipairs(self.settings.history) do
		local item = {}
		item.notCheckable = 1
		item.func         = OpenHistory
		item.arg1         = self
		item.arg2         = i
		item.text         = v[3] or "Unknown"
		historyMenu[#historyMenu+1] = item
	end
	historyMenu[#historyMenu+1] = {notCheckable=1, text="Close"}
end

--------------------------------------------------
-- Groups
--------------------------------------------------
function RSGUI.main:BuildGroupsMenu(rebuild)
	local settings = self.settings
	local menuTable = self.groupsMenu

	if menuTable and not rebuild then
		return
	end

	CloseDropDownMenus()

	-- go through spells/events to collect all groups
	local groupsFound = {["Ungrouped"] = true}
	for _,spell in pairs(settings["reactionList"]) do
		if type(spell) == "table" then
			for _,action in pairs(spell) do
				if type(action) == "table" and action.group then
					groupsFound[action.group] = true
				end
			end
		end
	end
	for _,trigger in pairs(settings.chatList.trigger) do
		if trigger.group then
			groupsFound[trigger.group] = true
		end
	end

	-- build the menu with those groups found
	menuTable = {}
	self.groupsMenu = menuTable

	local item
	for name in pairs(groupsFound) do
		item = RSGUI.Utility.InsertIntoMenu(menuTable, name, nil)
		item.keepShownOnClick = 1
		item.arg1             = name
		item.func             = function(name, _, checked) self.settings["groupList"][name] = checked and true or false end
		item.checked          = function() return settings["groupList"][name] end
	end
	table.insert(menuTable, {notCheckable=1, text="Close"})

	-- remove any non-enabled or non-existing groups from the settings table to stay tidy!
	for name,value in pairs(settings["groupList"]) do
		if not value or not groupsFound[name] then
			settings["groupList"][name] = nil
		end
	end
end

--------------------------------------------------
-- Events
--------------------------------------------------
local function OpenEventContent(reactionsContent, name)
	reactionsContent:Open(name, true)
end

function RSGUI.main:BuildEventsMenu()
	if self.eventMenu then return end

	self.eventMenu = {}
	local item
	local info, lastSubmenu, lastSubmenuName
	local eventInformationList = RSGUI.reactions.eventInformationList
	for i=1,#eventInformationList do
		info = eventInformationList[i]
		-- create this event's submenu if needed
		if info[2] ~= lastSubmenuName then
			item = {text=info[2], hasArrow=1, notClickable=1, notCheckable=1, menuList={}}
			self.eventMenu[#self.eventMenu+1] = item
			lastSubmenu = item.menuList
			lastSubmenuName = info[2]
		end
		-- add the event to the latest created submenu
		item = {notCheckable=1, func=OpenEventContent, arg1=self.content.reactions, arg2=info[3]}
		item.text = (self:SpellHasReaction(info[3]) and "|cff00ff00" or "") .. info[1]
		lastSubmenu[#lastSubmenu+1] = item
	end
	self.eventMenu[#self.eventMenu+1] = {notCheckable=1, text="Close"}

	self.eventsButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() RSGUI.menu:Open(self.eventMenu, this) end)
end

-- Add or remove green name coloring based on if it has any reactions set
function RSGUI.main:RenameEventsMenuItem(eventName)
	-- get the event's menu name
	local nickname = nil
	local eventInformationList = RSGUI.reactions.eventInformationList
	for i=1,#eventInformationList do
		if eventInformationList[i][3] == eventName then
			nickname = eventInformationList[i][1]
			break
		end
	end
	if not nickname then
		return
	end

	-- set the menu name based on if it has reactions set
	local submenu
	local fixedName
	for i=1,#self.eventMenu do
		submenu = self.eventMenu[i].menuList
		if submenu then
			for j=1,#submenu do
				fixedName = nickname:gsub("[%(%)]", "%%%1").."$"
				if submenu[j].text:find("^|cff00ff00"..fixedName) or submenu[j].text:find("^"..fixedName) then
					submenu[j].text = (self:SpellHasReaction(eventName) and "|cff00ff00" or "") .. nickname
					return
				end
			end
		end
	end
end

--------------------------------------------------
-- Spells
--------------------------------------------------
local function OpenSpellContent(reactionsContent, name)
	reactionsContent:Open(name)
end

function RSGUI.main:BuildSpellsMenu(rebuild)
	if self.spellsMenu and not rebuild then
		return
	end
	self.spellsMenu = {}
	for name, info in pairs(self.settings["reactionList"]) do
		if not info.event then
			local item =  RSGUI.Utility.InsertIntoMenu(self.spellsMenu, info.nickname ~= "" and info.nickname or name, info.submenu)
			item.notCheckable = 1
			item.func = OpenSpellContent
			item.arg1 = self.content.reactions
			item.arg2 = name
		end
	end
	table.insert(self.spellsMenu, 1, {func=OpenSpellContent, arg1=self.content.reactions, notCheckable=1, text="Add spell"})
	table.insert(self.spellsMenu,    {notCheckable=1, text="Close"})
end

--------------------------------------------------
-- Tags
--------------------------------------------------
local function OpenTagContent(tagsContent, name)
	tagsContent:Open(name)
end

function RSGUI.main:BuildTagsMenu(rebuild)
	if self.tagsMenu and not rebuild then
		return
	end
	self.tagsMenu = {}
	for name, info in pairs(self.settings["tagList"]) do
		if not info.event then
			local item = RSGUI.Utility.InsertIntoMenu(self.tagsMenu, name, info.submenu)
			item.notCheckable = 1
			item.arg1 = self.content.tags
			item.arg2 = name
			item.func = OpenTagContent
		end
	end
	table.insert(self.tagsMenu, 1, {func=OpenTagContent, arg1=self.content.tags, notCheckable=1, text="All tags"})
	table.insert(self.tagsMenu,    {notCheckable=1, text="Close"})
end

--------------------------------------------------
-- Chat
--------------------------------------------------
local function OpenChatContent(chatContent, name)
	chatContent:Open(name)
end

function RSGUI.main:BuildChatMenu(rebuild)
	if self.chatMenu and not rebuild then
		return
	end
	CloseDropDownMenus()
	self.chatMenu = {}
	for channel,list in pairs(self.settings.chatList.channel) do
		for i=1,#list do
			local item = RSGUI.Utility.InsertIntoMenu(self.chatMenu, list[i], channel..">")
			item.notCheckable = 1
			item.arg1 = self.content.chat
			item.arg2 = list[i]
			item.func = OpenChatContent
		end
	end
	table.insert(self.chatMenu, 1, {func=OpenChatContent, arg1=self.content.chat, notCheckable=1, text="Add Trigger"})
	table.insert(self.chatMenu,    {notCheckable=1, text="Close"})
end

----------------------------------------------------------------------------------------------------
-- the help menu
----------------------------------------------------------------------------------------------------
local function InsertHelpVariable()
	local inputBox = GetCurrentKeyBoardFocus()
	if inputBox then
		inputBox:Insert(this.value)
	end
	CloseDropDownMenus()
end

RSGUI.main.helpMenu = {
	{notCheckable=1, text="Help", isTitle=true},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Player", menuList={
		{notCheckable=1, text="Player Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<player_name>", text="<player_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_name_title>", text="<player_name_title>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_race>", text="<player_race>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_class>", text="<player_class>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_guild>", text="<player_guild>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_title>", text="<player_title>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_hearth>", text="<player_hearth>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_gold>", text="<player_gold>"},
		{notCheckable=1, func=InsertHelpVariable, value="<player_money_text>", text="<player_money_text>"},
		{notCheckable=1, func=InsertHelpVariable, value="<pet_name>", text="<pet_name>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Action Units", menuList={
		{notCheckable=1, text="Action Units Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<target_name>", text="<target_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_race>", text="<target_race>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_class>", text="<target_class>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_guild>", text="<target_guild>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_he_she>", text="<target_he_she>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_him_her>", text="<target_him_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_his_her>", text="<target_his_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<target_gender:male:female:other>", text="<target_gender:male:female:other>"},
		{notCheckable=1, notClickable=1, text=""},
		{notCheckable=1, func=InsertHelpVariable, value="<group_name>", text="<group_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_race>", text="<group_race>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_class>", text="<group_class>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_guild>", text="<group_guild>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_he_she>", text="<group_he_she>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_him_her>", text="<group_him_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_his_her>", text="<group_his_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<group_gender:male:female:other>", text="<group_gender:male:female:other>"},
		{notCheckable=1, notClickable=1, text=""},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_name>", text="<extra_target_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_race>", text="<extra_target_race>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_class>", text="<extra_target_class>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_guild>", text="<extra_target_guild>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_he_she>", text="<extra_target_he_she>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_him_her>", text="<extra_target_him_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_his_her>", text="<extra_target_his_her>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_target_gender:male:female:other>", text="<extra_target_gender:male:female:other>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Action Information", menuList={
		{notCheckable=1, text="Action Information Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<spell_link>", text="<spell_link>"},
		{notCheckable=1, func=InsertHelpVariable, value="<spell_name>", text="<spell_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<spell_rank>", text="<spell_rank>"},
		{notCheckable=1, func=InsertHelpVariable, value="<spell_rank:*>", text="<spell_rank:*> (* = name or ID)"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_spell_link>", text="<extra_spell_link>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_spell_name>", text="<extra_spell_name>"},
		{notCheckable=1, func=InsertHelpVariable, value="<extra_spell_rank>", text="<extra_spell_rank>"},
		{notCheckable=1, func=InsertHelpVariable, value="<spell_name_after:*>", text="<spell_name_after:*>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Macro-Style Units", menuList={
		{notCheckable=1, text="Macro-Style Variables", isTitle=true},
		{notCheckable=1, text="Replace * with UnitID", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="<name:*>", text="<name:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<race:*>", text="<race:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<class:*>", text="<class:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<guild:*>", text="<guild:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<he_she:*>", text="<he_she:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<him_her:*>", text="<him_her:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<his_her:*>", text="<his_her:*>"},
		{notCheckable=1, func=InsertHelpVariable, value="<gender:*:male:female:other>", text="<gender:*:male:female:other>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Equipment", menuList={
		{notCheckable=1, text="Equipment", isTitle=true},
		{notCheckable=1, notClickable=1, hasArrow=1, text="Names", menuList={
			{notCheckable=1, text="Equipment Name Variables", isTitle=true},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_head_name>",	  text="<eq_head_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_neck_name>",	  text="<eq_neck_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_shoulder_name>", text="<eq_shoulder_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_back_name>",	  text="<eq_back_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_chest_name>",	 text="<eq_chest_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_shirt_name>",	 text="<eq_shirt_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_tabard_name>",	text="<eq_tabard_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_wrist_name>",	 text="<eq_wrist_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_hands_name>",	 text="<eq_hands_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_waist_name>",	 text="<eq_waist_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_legs_name>",	  text="<eq_legs_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_feet_name>",	  text="<eq_feet_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_finger1_name>",  text="<eq_finger1_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_finger2_name>",  text="<eq_finger2_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_trinket1_name>", text="<eq_trinket1_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_trinket2_name>", text="<eq_trinket2_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_mainhand_name>", text="<eq_mainhand_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_offhand_name>",  text="<eq_offhand_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_ranged_name>",	text="<eq_ranged_name>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_ammo_name>",	  text="<eq_ammo_name>"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="Links", menuList={
			{notCheckable=1, text="Equipment Link Variables", isTitle=true},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_head_link>",	  text="<eq_head_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_neck_link>",	  text="<eq_neck_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_shoulder_link>", text="<eq_shoulder_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_back_link>",	  text="<eq_back_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_chest_link>",	 text="<eq_chest_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_shirt_link>",	 text="<eq_shirt_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_tabard_link>",	text="<eq_tabard_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_wrist_link>",	 text="<eq_wrist_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_hands_link>",	 text="<eq_hands_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_waist_link>",	 text="<eq_waist_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_legs_link>",	  text="<eq_legs_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_feet_link>",	  text="<eq_feet_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_finger1_link>",  text="<eq_finger1_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_finger2_link>",  text="<eq_finger2_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_trinket1_link>", text="<eq_trinket1_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_trinket2_link>", text="<eq_trinket2_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_mainhand_link>", text="<eq_mainhand_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_offhand_link>",  text="<eq_offhand_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_ranged_link>",	text="<eq_ranged_link>"},
			{notCheckable=1, func=InsertHelpVariable, value="<eq_ammo_link>",	  text="<eq_ammo_link>"},
		}},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Random", menuList={
		{notCheckable=1, text="Random Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<number:* *>",  text="<number:* *> (* * = low & high)"},
		{notCheckable=1, func=InsertHelpVariable, value="<random_target_icon>",  text="<random_target_icon>"},
		{notCheckable=1, func=InsertHelpVariable, value="<random_party_member>", text="<random_party_member>"},
		{notCheckable=1, func=InsertHelpVariable, value="<random_group_member>", text="<random_group_member>"},
		{notCheckable=1, func=InsertHelpVariable, value="<random_guild_member>", text="<random_guild_member>"},
		{notCheckable=1, func=InsertHelpVariable, value="<random_tutorial_message>", text="<random_tutorial_message>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Miscellaneous", menuList={
	{notCheckable=1, text="Miscellaneous Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<make_spell_link:*>", text="<make_spell_link:*> (* = ID)"},
		{notCheckable=1, func=InsertHelpVariable, value="<zone>", text="<zone>"},
		{notCheckable=1, func=InsertHelpVariable, value="<subzone>", text="<subzone>"},
		{notCheckable=1, func=InsertHelpVariable, value="<zone_full>", text="<zone_full>"},
		{notCheckable=1, func=InsertHelpVariable, value="<coords>", text="<coords>"},
		{notCheckable=1, func=InsertHelpVariable, value="<coords_exact>", text="<coords_exact>"},
		{notCheckable=1, func=InsertHelpVariable, value="<summon_last_zone>", text="<summon_last_zone>"},
		{notCheckable=1, func=InsertHelpVariable, value="<summon_time_left>", text="<summon_time_left>"},
		{notCheckable=1, func=InsertHelpVariable, value="<direction>", text="<direction>"},
		{notCheckable=1, func=InsertHelpVariable, value="<game_time_simple>", text="<game_time_simple>"},
		{notCheckable=1, func=InsertHelpVariable, value="<game_time_general>", text="<game_time_general>"},
		{notCheckable=1, func=InsertHelpVariable, value="<game_time_description>", text="<game_time_description>"},
		{notCheckable=1, func=InsertHelpVariable, value="<real_time_simple>", text="<real_time_simple>"},
		{notCheckable=1, func=InsertHelpVariable, value="<real_time_general>", text="<real_time_general>"},
		{notCheckable=1, func=InsertHelpVariable, value="<real_time_description>", text="<real_time_description>"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Symbol", menuList={
		{notCheckable=1, text="Symbol Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<tm>", text="<tm> = trademark: ™"},
		{notCheckable=1, func=InsertHelpVariable, value="<r>", text="<r> = registered trademark: ®"},
		{notCheckable=1, func=InsertHelpVariable, value="<c>", text="<c> = copyright: ©"},
		{notCheckable=1, func=InsertHelpVariable, value="<cross>", text="<cross> = †"},
		{notCheckable=1, func=InsertHelpVariable, value="<pipe>", text="<pipe> = ||"},
		{notCheckable=1, func=InsertHelpVariable, value="<lts>", text="<lts> = less-than sign: <"},
		{notCheckable=1, func=InsertHelpVariable, value="<gts>", text="<gts> = greater-than sign: >"},
		{notCheckable=1, func=InsertHelpVariable, value="<opar>", text="<opar> = opening parenthesis: ("},
		{notCheckable=1, func=InsertHelpVariable, value="<cpar>", text="<cpar> = closing parenthesis: )"},
		{notCheckable=1, func=InsertHelpVariable, value="<obra>", text="<obra> = opening brace: {"},
		{notCheckable=1, func=InsertHelpVariable, value="<cbra>", text="<cbra> = closing brace: }"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Chat", menuList={
		{notCheckable=1, text="Chat Variables", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="<message>", text="<message>"},
		{notCheckable=1, func=InsertHelpVariable, value="<channel>", text="<channel>"},
		{notCheckable=1, func=InsertHelpVariable, value="<channel_number>", text="<channel_number>"},
		{notCheckable=1, func=InsertHelpVariable, value="<capture:#>", text="<capture:#> - replace #"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Raid Target Icons", menuList={
		{notCheckable=1, text="Raid Target Icons", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_1.blp", value="{rt1}", text="{rt1}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_2.blp", value="{rt2}", text="{rt2}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_3.blp", value="{rt3}", text="{rt3}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_4.blp", value="{rt4}", text="{rt4}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_5.blp", value="{rt5}", text="{rt5}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_6.blp", value="{rt6}", text="{rt6}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_7.blp", value="{rt7}", text="{rt7}"},
		{notCheckable=1, func=InsertHelpVariable, icon="Interface/TargetingFrame/UI-RaidTargetingIcon_8.blp", value="{rt8}", text="{rt8}"},
	}},
	{notCheckable=1, notClickable=1, hasArrow=1, text="Pattern Matching", menuList={
	{notCheckable=1, text="Lua Pattern Matching", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value=".",  text=".  = any character"},
		{notCheckable=1, func=InsertHelpVariable, value="%w", text="%w = an alphanumeric character"},
		{notCheckable=1, func=InsertHelpVariable, value="%a", text="%a = a letter"},
		{notCheckable=1, func=InsertHelpVariable, value="%l", text="%l = a lowercase letter"},
		{notCheckable=1, func=InsertHelpVariable, value="%u", text="%u = an uppercase letter"},
		{notCheckable=1, func=InsertHelpVariable, value="%d", text="%d = a digit"},
		{notCheckable=1, func=InsertHelpVariable, value="%s", text="%s = a whitespace character"},
		{notCheckable=1, func=InsertHelpVariable, value="%p", text="%p = a punctuation character"},
		{notCheckable=1, func=InsertHelpVariable, value="%x", text="%x = a hexadecimal digit"},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="Use capital letter for the opposite:", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%D = anything except a digit", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="Matching different amounts using: + * - ?", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%d = exactly 1 digit", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%d+ = 1 or more digits, as many as possible", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%d* = 0 or more digits, usually as many as possible", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%d- = 0 or more digits, as few as possible", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="%d? = 0 or 1 digit, usually 1 if possible", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="A set of possible characters inside [ ]", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="[aeiouAEIOU] = letter is a vowel", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="[%a%s]+ = 1 or more letters or spaces", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="", notClickable=1},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="Special characters: ( ) . % + - * ? [ ^ $", isTitle=true},
		{notCheckable=1, func=InsertHelpVariable, value="",	text="Put % before them. [Hello?] = %[Hello%?] ", notClickable=1},
	}},
	{notCheckable=1, text="Close"},
}

-- add more variables to the Random section if SS_Data is being used
if SS_Data then
	local list = RSGUI.main.helpMenu[7].menuList
	table.insert(list, {notCheckable=1, notClickable=1, text=""})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_craft:*>", text='<random_craft:*> (* = "all" or profession)'})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_item>", text="<random_item>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_npc>", text="<random_npc>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_quest>", text="<random_quest>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_spell>", text="<random_spell>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_pspell>", text='<random_pspell:*> (* = "all" or class/race'})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_talent:*>", text='<random_talent:*> (* = "all" or class)'})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_talent_min:*>", text='<random_talent_min:*> (* = "all" or class)'})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_talent_max:*>", text='<random_talent_max:*> (* = "all" or class)'})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_faction>", text="<random_faction>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_alliance_faction>", text="<random_alliance_faction>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_horde_faction>", text="<random_horde_faction>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_neutral_faction>", text="<random_neutral_faction>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_zone>", text="<random_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_subzone>", text="<random_subzone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_full_zone>", text="<random_full_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_instance_zone>", text="<random_instance_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_instance_full_zone>", text="<random_instance_full_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_battleground_zone>", text="<random_battleground_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_battleground_full_zone>", text="<random_battleground_full_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_world_zone>", text="<random_world_zone>"})
	table.insert(list, {notCheckable=1, func=InsertHelpVariable, value="<random_world_full_zone>", text="<random_world_full_zone>"})
end
