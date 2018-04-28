RSGUI.chat = {}
RSGUI.chat.__index = RSGUI.chat

local replyList = {"Same Channel", "Chat Command", "Say and Yell", "Group", "Whisper", "Print to Chat", "Print Warning", "Spell/Event"}

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- create (if needed) and return the action table (hit/member_hit/miss/etc) of a spell/event
function RSGUI.chat:GetCurrentTriggerData()
	if not self.currentTriggerName then
		return nil
	end
	local settings = self.main.settings
	if not settings.chatList.trigger[self.currentTriggerName] then
		settings.chatList.trigger[self.currentTriggerName] = {}
		table.insert(settings.chatList.channel["Disabled"], self.currentTriggerName)
	end
	return settings.chatList.trigger[self.currentTriggerName]
end

-- return true if a channel type has a trigger with a certain name
function RSGUI.chat:HasChatChannelTrigger(channel, name)
	local list = self.main.settings.chatList.channel[channel]
	if list then
		for i=1,#list do
			if list[i] == name then
				return true
			end
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- create chat panel
----------------------------------------------------------------------------------------------------
function RSGUI.chat.new(main)
	local self = setmetatable({}, RSGUI.chat)

	self.frame = CreateFrame("frame", "RSGUI_Chat", nil)
	local panel = self.frame
	panel.instance = self

	self.main = main
	main:AddContentFrame("chat", self)
	panel:SetScript("OnShow", function() main:HideContentExcept(panel) end)

	local settings = self.main.settings
	self.currentTriggerName = nil -- name of the trigger currently opened

	--------------------------------------------------
	-- top section
	--------------------------------------------------
	-- Name: the text
	self.textName = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textName:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	self.textName:SetText("Chat trigger name:")

	-- Name: the edit box
	self.inputName = CreateFrame("EditBox", "RSGUI_Chat_inputName", panel, "InputBoxTemplate")
	self.inputName:SetWidth(155)
	self.inputName:SetHeight(14)
	self.inputName:SetPoint("LEFT", self.textName, "RIGHT", 10, 0)
	self.inputName:SetAutoFocus(false)

	-- Create/Change button
	self.buttonCreateOrChange = RSGUI.Utility.CreateButton("Chat_CreateChange", panel, 70, "Create")
	self.buttonCreateOrChange:SetPoint("LEFT", self.inputName, "RIGHT", 10, 0)
	self.buttonCreateOrChange.text = _G[self.buttonCreateOrChange:GetName().."Text"] -- will change depending on creating or editing
	self.inputName:SetScript("OnEnterPressed", function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)

	self.buttonCreateOrChange:SetScript("OnClick", function()
		CloseDropDownMenus()
		RSGUI.Utility.ClearAnyFocus()

		local name = self.inputName:GetText()
		if name == "" then
			message("You must set a trigger name.")
			return
		end

		local settings = self.main.settings
		local mode = self.buttonCreateOrChange:GetText()
		local trigger = settings.chatList.trigger[name]
		if mode == "Create" then
			if trigger then
				self:Open(name)
				return
			end

			table.insert(settings.chatList.channel["Disabled"], name)
			settings.chatList.trigger[name] = {}
			local data = settings.chatList.trigger[name]
			data.chance = 100
			data.stopTriggers = true
			data.removeCapitalization = true
			data.removePunctuation = true
			data.matchGuild = true
			data.matchFriends = true
			data.matchOthers = true
			data.replyChannel = "Same Channel"
			self.main:BuildChatMenu(true)
			self:Open(name)
		elseif mode == "Change" then
			if name ~= self.currentTriggerName then
				if trigger then
					message("A chat trigger with that name already exists! You must delete it first.")
					return
				end

				-- move the table to a new name
				trigger = settings.chatList.trigger[self.currentTriggerName]
				settings.chatList.trigger[name] = trigger
				settings.chatList.trigger[self.currentTriggerName] = nil
				self.main:RemoveHistory("chat", self.currentTriggerName)

				-- fix channel lists now
				for _,list in pairs(settings.chatList.channel) do
					for i=1,#list do
						if list[i] == self.currentTriggerName then
							table.remove(list, i)

							local insertAt = 1
							local lowerName = name:lower()
							for j=1,#list do
								if list[j]:lower() > lowerName then
									break
								end
								insertAt = insertAt + 1
							end
							table.insert(list, insertAt, name)
							break
						end
					end
				end
				self.main:BuildChatMenu(true)
				self:Open(name)
			end
		end
	end)

	-- Delete button
	self.buttonDelete = RSGUI.Utility.CreateButton("Chat_Delete", panel, 70, "Delete")
	self.buttonDelete:SetPoint("LEFT", self.buttonCreateOrChange, "RIGHT", 3, 0)

	self.buttonDelete:SetScript("OnClick", function()
		local settings = self.main.settings
		local trigger = self.currentTriggerName and settings.chatList.trigger[self.currentTriggerName] or nil
		if trigger then
			settings.chatList.trigger[self.currentTriggerName] = nil
			for _,list in pairs(settings.chatList.channel) do
				for i=1,#list do
					if list[i] == self.currentTriggerName then
						table.remove(list, i)
						self.main:RemoveHistory("chat", self.currentTriggerName)
						break
					end
				end
			end
			self.main:BuildChatMenu(true)
			self.main:BuildGroupsMenu(true)
		end

		self.currentTriggerName = nil
		self.main:SetHeaderText("")
		self.frame:Hide()
	end)

	--------------------------------------------------
	-- trigger settings - left section
	--------------------------------------------------
	-- top border
	self.borderTop = panel:CreateTexture()
	self.borderTop:SetTexture(.4, .4, .4)
	self.borderTop:SetWidth(panel:GetWidth())
	self.borderTop:SetHeight(1)
	self.borderTop:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textName:GetBottom())-11)

	-- main section header
	self.textMainHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textMainHeader:SetPoint("TOPLEFT", self.borderTop, "BOTTOMLEFT", 0, -10)
	self.textMainHeader:SetText("Trigger Settings:")

	-- group - text
	self.textGroup = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textGroup:SetPoint("TOPLEFT", self.textMainHeader, "BOTTOMLEFT", 0, -10)
	self.textGroup:SetText("Group:")

	-- chance - text
	self.textChance = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textChance:SetPoint("TOPLEFT", self.textGroup, "BOTTOMLEFT", 0, -12)
	self.textChance:SetText("Chance:")

	-- global cooldown - text
	self.textGlobalCooldown = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textGlobalCooldown:SetPoint("TOPLEFT", self.textChance, "BOTTOMLEFT", 0, -12)
	self.textGlobalCooldown:SetText("Global Cooldown:")

	-- person cooldown - text
	self.textPersonCooldown = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textPersonCooldown:SetPoint("TOPLEFT", self.textGlobalCooldown, "BOTTOMLEFT", 0, -12)
	self.textPersonCooldown:SetText("Person Cooldown:")

	-- group - input
	self.inputGroup = CreateFrame("EditBox", "RSGUI_Chat_inputGroup", panel, "InputBoxTemplate")
	self.inputGroup:SetWidth(100)
	self.inputGroup:SetHeight(12)
	self.inputGroup:SetPoint("LEFT", self.textGroup, "LEFT", self.textPersonCooldown:GetWidth() + 8, 0)
	self.inputGroup:SetMaxLetters(16)
	self.inputGroup:SetAutoFocus(false)
	self.inputGroup:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputGroup:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		local newGroup = self.inputGroup:GetText()
		if newGroup == "" then
			newGroup = nil
		end

		if data.group ~= newGroup then
			data.group = newGroup
			if newGroup and self.main.settings["groupList"][newGroup] == nil then
				self.main.settings["groupList"][newGroup] = true -- enable new groups by default
			end
			self.main:BuildGroupsMenu(true)
		end
	end)
	self.inputGroup.tooltipText = "If you set a group name, you can enable/disable everything in that group by using the Groups button at the top."
	self.inputGroup:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
	self.inputGroup:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)

	-- chance - input
	self.inputChance = CreateFrame("EditBox", "RSGUI_Chat_inputChance", panel, "InputBoxTemplate")
	self.inputChance:SetWidth(46)
	self.inputChance:SetHeight(12)
	self.inputChance:SetPoint("LEFT", self.textChance, "LEFT", self.textPersonCooldown:GetWidth() + 8, 0)
	self.inputChance:SetMaxLetters(5)
	self.inputChance:SetAutoFocus(false)
	self.inputChance:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputChance:SetScript("OnTextChanged", function() RSGUI.Utility.FixChanceNumber(self.inputChance) end)
	self.inputChance:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.chance = RSGUI.Utility.FixChanceNumber(self.inputChance)
		if data.chance == 0 then
			self.inputChance:SetText(0)
		end
	end)

	-- global cooldown - input
	self.inputGlobalCooldown = CreateFrame("EditBox", "RSGUI_Chat_inputGlobalCooldown", panel, "InputBoxTemplate")
	self.inputGlobalCooldown:SetWidth(46)
	self.inputGlobalCooldown:SetHeight(12)
	self.inputGlobalCooldown:SetPoint("LEFT", self.textGlobalCooldown, "LEFT", self.textPersonCooldown:GetWidth() + 8, 0)
	self.inputGlobalCooldown:SetNumeric(true)
	self.inputGlobalCooldown:SetMaxLetters(5)
	self.inputGlobalCooldown:SetAutoFocus(false)
	self.inputGlobalCooldown:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputGlobalCooldown:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.globalCooldown = tonumber(self.inputGlobalCooldown:GetText())
	end)
	self.inputGlobalCooldown.tooltipText = "Seconds to wait before this can be triggered again by anyone, or blank for no cooldown time (chat triggers don't use the default cooldown time in the options)."
	self.inputGlobalCooldown:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
	self.inputGlobalCooldown:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)

	-- person cooldown - input
	self.inputPersonCooldown = CreateFrame("EditBox", "RSGUI_Chat_inputPersonCooldown", panel, "InputBoxTemplate")
	self.inputPersonCooldown:SetWidth(46)
	self.inputPersonCooldown:SetHeight(12)
	self.inputPersonCooldown:SetPoint("LEFT", self.textPersonCooldown, "LEFT", self.textPersonCooldown:GetWidth() + 8, 0)
	self.inputPersonCooldown:SetNumeric(true)
	self.inputPersonCooldown:SetMaxLetters(5)
	self.inputPersonCooldown:SetAutoFocus(false)
	self.inputPersonCooldown:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputPersonCooldown:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.personCooldown = tonumber(self.inputPersonCooldown:GetText())
	end)
	self.inputPersonCooldown.tooltipText = "Seconds to wait before each individual person can trigger this reaction again, or blank for no cooldown time."
	self.inputPersonCooldown:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
	self.inputPersonCooldown:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)

	-- be able to tab through the top things
	self.inputGroup:SetScript("OnTabPressed",          function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputPersonCooldown:SetFocus() else self.inputChance:SetFocus()         end end)
	self.inputChance:SetScript("OnTabPressed",         function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputGroup:SetFocus()          else self.inputGlobalCooldown:SetFocus() end end)
	self.inputGlobalCooldown:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputChance:SetFocus()         else self.inputPersonCooldown:SetFocus() end end)
	self.inputPersonCooldown:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputGlobalCooldown:SetFocus() else self.inputGroup:SetFocus()          end end)

	--------------------------------------------------
	-- trigger settings - right section
	--------------------------------------------------
	self.checkboxChannels = {}

	-- channel checkboxes
	local function SetCurrentTriggerChannel(channel, enable)
		RSGUI.Utility.ClearAnyFocus()

		local settings = self.main.settings
		if enable then
			-- remove from Disabled list
			local list = settings.chatList.channel["Disabled"]
			for i=1,#list do
				if list[i] == self.currentTriggerName then
					table.remove(list, i)
					break
				end
			end
			-- insert into the specific channel list alphabetically
			list = settings.chatList.channel[channel]
			local insertAt = 1
			local name = self.currentTriggerName:lower()
			for i=1,#list do
				if list[i]:lower() > name then
					break
				end
				insertAt = insertAt + 1
			end
			table.insert(list, insertAt, self.currentTriggerName)
		else
			-- remove from channel list
			local list = settings.chatList.channel[channel]
			for i=1,#list do
				if list[i] == self.currentTriggerName then
					table.remove(list, i)
					break
				end
			end
			-- go through each channel list to see if it should be put into the Disabled group or not
			for _,triggerList in pairs(settings.chatList.channel) do
				for i=1,#triggerList do
					if triggerList[i] == self.currentTriggerName then
						-- it's in another channel, so no need to check more
						self.main:BuildChatMenu(true)
						return
					end
				end
			end
			table.insert(settings.chatList.channel["Disabled"], self.currentTriggerName)
		end
		self.main:BuildChatMenu(true)
	end

	local function CreateChannelCheckbox(name, belowThis, column, tooltip)
		local checkbox = RSGUI.Utility.CreateCheckbox("chatChannel"..name, panel, name, tooltip)
		checkbox:SetWidth(26)
		checkbox:SetHeight(26)
		if not belowThis then
			checkbox:SetPoint("TOP", self.textChannels, "BOTTOM")
			checkbox:SetPoint("LEFT", panel, "RIGHT", -(column*100), 0)
		else
			checkbox:SetPoint("TOPLEFT", belowThis, "BOTTOMLEFT", 0, 7)
		end
		checkbox:SetScript("OnClick", function() SetCurrentTriggerChannel(name, this:GetChecked()) end)
		return checkbox
	end

	-- text above
	self.textChannels = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textChannels:SetPoint("TOP", self.textMainHeader, "TOP", 0, 0)
	self.textChannels:SetPoint("LEFT", panel, "RIGHT", -300, 0)
	self.textChannels:SetText("Watch on these channels:")

	-- column 1
	self.checkboxChannels.Say          = CreateChannelCheckbox("Say",         nil,                               3)
	self.checkboxChannels.Yell         = CreateChannelCheckbox("Yell",        self.checkboxChannels.Say,         3)
	self.checkboxChannels.Emote        = CreateChannelCheckbox("Emote",       self.checkboxChannels.Yell,        3)
	self.checkboxChannels.Action       = CreateChannelCheckbox("Action",      self.checkboxChannels.Emote,       3,
		'Commands like /bow and /slap, but not /emote - the full text is received, like "Shanghi greets you warmly."')
	self.checkboxChannels.Whisper      = CreateChannelCheckbox("Whisper",     self.checkboxChannels.Action,      3)
	-- column 2
	self.checkboxChannels.Party        = CreateChannelCheckbox("Party",        nil,                              2)
	self.checkboxChannels.Raid         = CreateChannelCheckbox("Raid",         self.checkboxChannels.Party,      2)
	self.checkboxChannels.Guild        = CreateChannelCheckbox("Guild",        self.checkboxChannels.Raid,       2)
	self.checkboxChannels.Officer      = CreateChannelCheckbox("Officer",      self.checkboxChannels.Guild,      2)
	self.checkboxChannels.Battleground = CreateChannelCheckbox("Battleground", self.checkboxChannels.Officer,    2)
	-- column 3
	self.checkboxChannels.Channel      = CreateChannelCheckbox("Channel",      nil,                              1,
		"Any numbered channel like General and Trade chat.")
	self.checkboxChannels.System       = CreateChannelCheckbox("System",       self.checkboxChannels.Channel,    1,
		"Server messages like shutdown warnings and notices of a friend/guild member coming online. These have no <target_name>.")
	self.checkboxChannels.Loot         = CreateChannelCheckbox("Loot",         self.checkboxChannels.System,     1,
		"Messages about looting/rolling/winning items and money. These have no <target_name>.")
	self.checkboxChannels.Tradeskill   = CreateChannelCheckbox("Tradeskill",   self.checkboxChannels.Loot,       1,
		"Someone crafts something. These have no <target_name>.")
	self.checkboxChannels.Error        = CreateChannelCheckbox("Error",        self.checkboxChannels.Tradeskill, 1,
		'Errors like "Spell is not ready yet." and "Out of range." These have no <target_name>.')

	--------------------------------------------------
	-- trigger settings - middle section
	--------------------------------------------------
	-- text above
	self.textAllowMatches = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textAllowMatches:SetPoint("BOTTOM", self.textMainHeader, "BOTTOM", 0, 0) -- will be centered horizontally below
	self.textAllowMatches:SetText("Allow matches from:")

	-- allow matches from yourself
	self.checkboxMatchYourself = RSGUI.Utility.CreateCheckbox("chatMatchYourself", panel, "Yourself")
	self.checkboxMatchYourself:SetPoint("TOPLEFT", self.textAllowMatches, "BOTTOMLEFT", 0, 0)
	self.checkboxMatchYourself:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.matchYourself = self.checkboxMatchYourself:GetChecked() or nil
	end)

	-- allow matches from guild members
	self.checkboxMatchGuild = RSGUI.Utility.CreateCheckbox("chatMatchGuild", panel, "Guild")
	self.checkboxMatchGuild:SetPoint("LEFT", self.checkboxMatchYourself, "LEFT", 85, 0)
	self.checkboxMatchGuild:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.matchGuild = self.checkboxMatchGuild:GetChecked() or nil
	end)

	-- allow matches from friends
	self.checkboxMatchFriends = RSGUI.Utility.CreateCheckbox("chatMatchFriends", panel, "Friends")
	self.checkboxMatchFriends:SetPoint("TOPLEFT", self.checkboxMatchYourself, "BOTTOMLEFT", 0, 8)
	self.checkboxMatchFriends:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.matchFriends = self.checkboxMatchFriends:GetChecked() or nil
	end)

	-- allow matches from others
	self.checkboxMatchOthers = RSGUI.Utility.CreateCheckbox("chatMatchOthers", panel, "Others")
	self.checkboxMatchOthers:SetPoint("LEFT", self.checkboxMatchFriends, "LEFT", 85, 0)
	self.checkboxMatchOthers:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.matchOthers = self.checkboxMatchOthers:GetChecked() or nil
	end)

	-- stop checking for other triggers
	self.checkboxStopTriggers = RSGUI.Utility.CreateCheckbox("chatStopOnMatch", panel, "On match, stop checking other triggers")
	self.checkboxStopTriggers:SetPoint("LEFT", self.checkboxMatchFriends, "LEFT", 0, 0)
	self.checkboxStopTriggers:SetPoint("TOP", self.textPersonCooldown, "TOP", 0, 10)
	self.checkboxStopTriggers:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.stopTriggers = self.checkboxStopTriggers:GetChecked() or nil
	end)

	-- center the section
	local spaceLeft = self.textChannels:GetLeft() - self.inputGroup:GetRight()
	local sectionWidth = self.checkboxStopTriggers:GetWidth() + _G[self.checkboxStopTriggers:GetName().."Text"]:GetWidth()
	self.textAllowMatches:SetPoint("LEFT", self.inputGroup, "RIGHT", (spaceLeft/2) - (sectionWidth/2), 0)

	--------------------------------------------------
	-- trigger matching
	--------------------------------------------------
	-- match border
	self.borderMatch = panel:CreateTexture()
	self.borderMatch:SetTexture(.4, .4, .4)
	self.borderMatch:SetWidth(panel:GetWidth())
	self.borderMatch:SetHeight(1)
	self.borderMatch:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textPersonCooldown:GetBottom())-20)

	-- match section header
	self.textMatchHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textMatchHeader:SetPoint("TOPLEFT", self.borderMatch, "BOTTOMLEFT", 0, -10)
	self.textMatchHeader:SetText("Message Matching:")

	-- remove capitalization
	self.checkboxRemoveCapitalization = RSGUI.Utility.CreateCheckbox("chatRemoveCapitalization", panel, "Remove capitalization")
	self.checkboxRemoveCapitalization:SetPoint("TOPLEFT", self.textMatchHeader, "BOTTOMLEFT", 0, -6)
	self.checkboxRemoveCapitalization:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.removeCapitalization = self.checkboxRemoveCapitalization:GetChecked() or nil
	end)

	-- remove punctuation
	self.checkboxRemovePunctuation = RSGUI.Utility.CreateCheckbox("chatRemovePunctuation", panel, "Remove punctuation")
	self.checkboxRemovePunctuation:SetPoint("TOPLEFT", self.checkboxRemoveCapitalization, "BOTTOMLEFT", 0, 10)
	self.checkboxRemovePunctuation:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.removePunctuation = self.checkboxRemovePunctuation:GetChecked() or nil
	end)

	-- convert links to plain text
	self.checkboxPlainTextLinks = RSGUI.Utility.CreateCheckbox("chatPlainLinks", panel, "Plain text links",
			"Links have hidden text like an ID and color, but checking this will remove all that, making it plain like [Name] to match more easily.")
	self.checkboxPlainTextLinks:SetPoint("TOPLEFT", self.checkboxRemovePunctuation, "BOTTOMLEFT", 0, 10)
	self.checkboxPlainTextLinks:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		data.plainTextLinks = self.checkboxPlainTextLinks:GetChecked() or nil
	end)

	-- phrase list
	self.textPhrase = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textPhrase:SetPoint("TOPLEFT", self.checkboxPlainTextLinks, "BOTTOMLEFT", 0, -43)
	self.textPhrase:SetText("Match phrases:")

	self.inputPhrase = CreateFrame("EditBox", "RSGUI_Chat_inputPhrase", panel, "InputBoxTemplate")
	self.inputPhrase:SetWidth(panel:GetRight() - self.textPhrase:GetRight() - 12)
	self.inputPhrase:SetHeight(14)
	self.inputPhrase:SetPoint("LEFT", self.textPhrase, "RIGHT", 10, 0)
	self.inputPhrase:SetAutoFocus(false)
	self.inputPhrase:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputPhrase:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentTriggerData()
		if not data then return end
		local phrases = self.inputPhrase:GetText()
		if phrases == "" then
			data.phraseMatches = nil
		else
			data.phraseMatches = {}
			for phrase in phrases:gmatch("[^|]+") do
				table.insert(data.phraseMatches, phrase)
			end
		end
	end)

	-- custom lua
	self.luaBoxMatch = CreateFrame("frame", "RSGUI_Chat_luaBoxMatch", panel)
	self.luaBoxMatch:SetWidth(panel:GetRight()-self.textMatchHeader:GetRight()-40)
	self.luaBoxMatch:SetHeight(130)
	self.luaBoxMatch:SetPoint("BOTTOMRIGHT", self.inputPhrase, "TOPRIGHT", -20, 7)
	self.luaBoxMatch:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=16,
		insets={left=5, right=5, top=5, bottom=5}})
	self.luaBoxMatch:SetBackdropColor(0,0,0,1)

	self.luaBoxMatchInput = CreateFrame("EditBox", "RSGUI_Chat_luaBoxMatchInput", self.luaBoxMatch)
	self.luaBoxMatchInput:SetMultiLine(true)
	self.luaBoxMatchInput:SetAutoFocus(false)
	self.luaBoxMatchInput:EnableMouse(true)
	self.luaBoxMatchInput:SetFont("Fonts/ARIALN.ttf", 15)
	self.luaBoxMatchInput:SetWidth(self.luaBoxMatch:GetWidth()-20)
	self.luaBoxMatchInput:SetHeight(self.luaBoxMatch:GetHeight()-8)
	self.luaBoxMatchInput:SetScript("OnEscapePressed", function() self.luaBoxMatchInput:ClearFocus() end)
	self.luaBoxMatchInput:SetScript("OnTabPressed", function() self.luaBoxMatchInput:Insert("	") end)
	self.luaBoxMatchInput:SetScript("OnEditFocusLost", function()
		data = self:GetCurrentTriggerData()
		if not data then return end
		data.luaMatch = self.luaBoxMatchInput:GetText():gsub("||","|")
		if data.luaMatch == "" then
			data.luaMatch = nil
		end
		data.luaMatchFunc = nil
	end)

	self.luaBoxMatchScroll = CreateFrame("ScrollFrame", "RSGUI_Chat_luaBoxMatchScroll", self.luaBoxMatch, "UIPanelScrollFrameTemplate")
	self.luaBoxMatchScroll:SetPoint("TOPLEFT", self.luaBoxMatch, "TOPLEFT", 8, -8)
	self.luaBoxMatchScroll:SetPoint("BOTTOMRIGHT", self.luaBoxMatch, "BOTTOMRIGHT", -6, 8)
	self.luaBoxMatchScroll:EnableMouse(true)
	self.luaBoxMatchScroll:SetScript("OnMouseDown", function() self.luaBoxMatchInput:SetFocus() end)
	self.luaBoxMatchScroll:SetScrollChild(self.luaBoxMatchInput)

	-- taken from Blizzard's macro UI XML to handle scrolling
	self.luaBoxMatchInput:SetScript("OnTextChanged", function()
		local scrollbar = _G[self.luaBoxMatchScroll:GetName().."ScrollBar"]
		local min, max = scrollbar:GetMinMaxValues()
		if max > 0 and this.max ~= max then
		this.max = max
		scrollbar:SetValue(max)
		end
	end)
	self.luaBoxMatchInput:SetScript("OnUpdate", function(this)
		ScrollingEdit_OnUpdate(self.luaBoxMatchScroll)
	end)
	self.luaBoxMatchInput:SetScript("OnCursorChanged", function()
		ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
	end)

	self.luaBoxMatchText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.luaBoxMatchText:SetPoint("BOTTOM", self.luaBoxMatch, "TOP", 0, 0)
	self.luaBoxMatchText:SetText("Custom Lua for matching (return true if matched):")

	--------------------------------------------------
	-- reaction
	--------------------------------------------------
	-- match border
	self.borderReaction = panel:CreateTexture()
	self.borderReaction:SetTexture(.4, .4, .4)
	self.borderReaction:SetWidth(panel:GetWidth())
	self.borderReaction:SetHeight(1)
	self.borderReaction:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textPhrase:GetBottom())-20)

	-- match section header
	self.textReactionhHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textReactionhHeader:SetPoint("TOPLEFT", self.borderReaction, "BOTTOMLEFT", 0, -10)
	self.textReactionhHeader:SetText("Reaction:")

	-- lua note at the bottom right
	self.textLuaNote = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textLuaNote:SetPoint("BOTTOM", panel, "BOTTOM", 0, 0)
	self.textLuaNote:SetText("Variables for Lua: rs.message, rs.modifiedMessage, rs.target, rs.channel, rs.channelNumber, rs.capture[#]")

	-- reply message
	self.dropdownChannel = CreateFrame("frame", "RSGUI_Chat_dropdownChannel", panel, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(120, self.dropdownChannel)
	self.dropdownChannel:SetPoint("TOPLEFT", self.textReactionhHeader, "BOTTOMLEFT", -17, -6)

	-- the edit box
	self.inputReply = CreateFrame("EditBox", "RSGUI_Chat_inputReply", panel, "InputBoxTemplate")
	self.inputReply:SetWidth(panel:GetRight()-self.dropdownChannel:GetRight()+5)
	self.inputReply:SetHeight(14)
	self.inputReply:SetPoint("LEFT", self.dropdownChannel, "RIGHT", -4, 0)
	self.inputReply:SetAutoFocus(false)
	self.inputReply:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputReply:SetScript("OnTabPressed", function()
		_G.SlashCmdList.REACTIONS("testmessage " .. self.inputReply:GetText():gsub("||","|"))
		this:GetScript("OnEditFocusLost")(this)
		this.canChange = true
	end)
	self.inputReply:SetScript("OnEditFocusLost", function()
		data = self:GetCurrentTriggerData()
		if not data then return end
		-- fix accidental spaces before something like /y and /run
		data.useReply = self.inputReply:GetText():gsub("||","|"):gsub("^%s+/", "/")
		if data.useReply == "" then
			data.useReply = nil
		end
	end)

	-- custom lua
	self.luaBoxReaction = CreateFrame("frame", "RSGUI_Chat_luaBoxReaction", panel)
	self.luaBoxReaction:SetWidth(self.luaBoxMatch:GetRight()-self.textReactionhHeader:GetLeft())
	self.luaBoxReaction:SetHeight(self.inputReply:GetBottom()-self.textLuaNote:GetTop() - 20)
	self.luaBoxReaction:SetPoint("TOPLEFT", self.textReactionhHeader, "BOTTOMLEFT", 0, -47)
	self.luaBoxReaction:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=16,
		insets={left=5, right=5, top=5, bottom=5}})
	self.luaBoxReaction:SetBackdropColor(0,0,0,1)
	self.luaBoxReactionInput = CreateFrame("EditBox", "RSGUI_Chat_luaBoxReactionInput", self.luaBoxReaction)
	self.luaBoxReactionInput:SetMultiLine(true)
	self.luaBoxReactionInput:SetAutoFocus(false)
	self.luaBoxReactionInput:EnableMouse(true)
	self.luaBoxReactionInput:SetFont("Fonts/ARIALN.ttf", 15)
	self.luaBoxReactionInput:SetWidth(self.luaBoxReaction:GetWidth()-20)
	self.luaBoxReactionInput:SetHeight(self.luaBoxReaction:GetHeight()-8)
	self.luaBoxReactionInput:SetScript('OnEscapePressed', function()self.luaBoxReactionInput:ClearFocus() end)
	self.luaBoxReactionInput:SetScript('OnTabPressed', function() self.luaBoxReactionInput:Insert("	") end)
	self.luaBoxReactionInput:SetScript("OnEditFocusLost", function()
		data = self:GetCurrentTriggerData()
		if not data then return end
		data.luaReaction = self.luaBoxReactionInput:GetText():gsub("||","|")
		if data.luaReaction == "" then
			data.luaReaction = nil
		end
		data.luaReactionFunc = nil
	end)
	self.luaBoxReactionScroll = CreateFrame("ScrollFrame", "RSGUI_Chat_luaBoxReactionScroll", self.luaBoxReaction, "UIPanelScrollFrameTemplate")
	self.luaBoxReactionScroll:SetPoint("TOPLEFT", self.luaBoxReaction, "TOPLEFT", 8, -8)
	self.luaBoxReactionScroll:SetPoint("BOTTOMRIGHT", self.luaBoxReaction, "BOTTOMRIGHT", -6, 8)
	self.luaBoxReactionScroll:EnableMouse(true)
	self.luaBoxReactionScroll:SetScript("OnMouseDown", function() self.luaBoxReactionInput:SetFocus() end)
	self.luaBoxReactionScroll:SetScrollChild(self.luaBoxReactionInput)

	-- taken from Blizzard's macro UI XML to handle scrolling
	self.luaBoxReactionInput:SetScript("OnTextChanged", function()
		local scrollbar = _G[self.luaBoxReactionScroll:GetName().."ScrollBar"]
		local min, max = scrollbar:GetMinMaxValues()
		if max > 0 and this.max ~= max then
		this.max = max
		scrollbar:SetValue(max)
		end
	end)
	self.luaBoxReactionInput:SetScript("OnUpdate", function(this)
		ScrollingEdit_OnUpdate(self.luaBoxReactionScroll)
	end)
	self.luaBoxReactionInput:SetScript("OnCursorChanged", function()
		ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
	end)

	self.luaBoxReactionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.luaBoxReactionText:SetPoint("BOTTOM", self.luaBoxReaction, "TOP", 0, 0)
	self.luaBoxReactionText:SetText("Custom Lua for reacting:")

	return self
end

----------------------------------------------------------------------------------------------------
-- showing/hiding
----------------------------------------------------------------------------------------------------
local function DropdownChannel_OnClick(self)
	RSGUI.Utility.ClearAnyFocus()
	data = self:GetCurrentTriggerData()
	if not data then return end
	data.replyChannel = this.value
	UIDropDownMenu_SetSelectedValue(self.dropdownChannel, this.value)
end

local dropdownChannelItem = {}
local function DropdownChannel_Initialize(self)
	for channel=1,#replyList do
		dropdownChannelItem.func = DropdownChannel_OnClick
		dropdownChannelItem.arg1 = self
		dropdownChannelItem.checked = nil
		dropdownChannelItem.value = replyList[channel]
		dropdownChannelItem.text = replyList[channel]
		UIDropDownMenu_AddButton(dropdownChannelItem)
	end
end

function RSGUI.chat:Open(name)
	CloseDropDownMenus()

	local trigger = name and self.main.settings.chatList.trigger[name]
	if not trigger then
		self.currentTriggerName = nil
		self.main:SetHeaderText("New Chat Trigger")
		self.buttonCreateOrChange.text:SetText("Create")
		self.inputName:SetText("")
		self.buttonDelete:Hide()

		self.borderTop:Hide()
		self.textMainHeader:Hide()
		self.textGroup:Hide()
		self.inputGroup:Hide()
		self.textChance:Hide()
		self.inputChance:Hide()
		self.textGlobalCooldown:Hide()
		self.inputGlobalCooldown:Hide()
		self.textPersonCooldown:Hide()
		self.inputPersonCooldown:Hide()
		self.checkboxMatchYourself:Hide()
		self.checkboxMatchGuild:Hide()
		self.checkboxMatchFriends:Hide()
		self.checkboxMatchOthers:Hide()
		self.checkboxStopTriggers:Hide()
		self.borderMatch:Hide()
		self.textMatchHeader:Hide()
		self.checkboxRemoveCapitalization:Hide()
		self.checkboxRemovePunctuation:Hide()
		self.checkboxPlainTextLinks:Hide()
		self.textPhrase:Hide()
		self.inputPhrase:Hide()
		self.luaBoxMatchText:Hide()
		self.luaBoxMatch:Hide()
		self.luaBoxMatchInput:Hide()
		self.luaBoxMatchScroll:Hide()
		self.borderReaction:Hide()
		self.textReactionhHeader:Hide()
		self.dropdownChannel:Hide()
		self.inputReply:Hide()
		self.luaBoxReactionText:Hide()
		self.luaBoxReaction:Hide()
		self.luaBoxReactionInput:Hide()
		self.luaBoxReactionScroll:Hide()
		self.textLuaNote:Hide()
		self.textChannels:Hide()
		self.textAllowMatches:Hide()
		for _,v in pairs(self.checkboxChannels) do
			v:Hide()
		end
	else
		self.currentTriggerName = name
		self.main:SetHeaderText("Chat Trigger: " .. name)
		self.inputName:SetText(name)
		self.buttonCreateOrChange.text:SetText("Change")
		self.buttonDelete:Show()

		self.main:AddHistory("chat", name, "Chat: " .. name)

		self.borderTop:Show()
		self.textMainHeader:Show()
		self.textGroup:Show()
		self.inputGroup:Show()
		self.inputGroup:SetText(trigger.group or "")
		self.textChance:Show()
		self.inputChance:Show()
		self.inputChance:SetText(trigger.chance or 0)
		self.textGlobalCooldown:Show()
		self.inputGlobalCooldown:Show()
		self.inputGlobalCooldown:SetText(trigger.globalCooldown or "")
		self.textPersonCooldown:Show()
		self.inputPersonCooldown:Show()
		self.inputPersonCooldown:SetText(trigger.personCooldown or "")
		self.checkboxMatchYourself:Show()
		self.checkboxMatchYourself:SetChecked(trigger.matchYourself)
		self.checkboxMatchGuild:Show()
		self.checkboxMatchGuild:SetChecked(trigger.matchGuild)
		self.checkboxMatchFriends:Show()
		self.checkboxMatchFriends:SetChecked(trigger.matchFriends)
		self.checkboxMatchOthers:Show()
		self.checkboxMatchOthers:SetChecked(trigger.matchOthers)
		self.checkboxStopTriggers:Show()
		self.checkboxStopTriggers:SetChecked(trigger.stopTriggers)
		self.borderMatch:Show()
		self.textMatchHeader:Show()
		self.checkboxRemoveCapitalization:Show()
		self.checkboxRemoveCapitalization:SetChecked(trigger.removeCapitalization)
		self.checkboxRemovePunctuation:Show()
		self.checkboxRemovePunctuation:SetChecked(trigger.removePunctuation)
		self.checkboxPlainTextLinks:Show()
		self.checkboxPlainTextLinks:SetChecked(trigger.plainTextLinks)
		self.textPhrase:Show()
		self.inputPhrase:Show()
		self.inputPhrase:SetText(trigger.phraseMatches and table.concat(trigger.phraseMatches, "||") or "")
		self.inputPhrase:SetCursorPosition(0)
		self.luaBoxMatchText:Show()
		self.luaBoxMatch:Show()
		self.luaBoxMatchInput:Show()
		self.luaBoxMatchInput:SetText((trigger.luaMatch and trigger.luaMatch:gsub("||","|") or ""))
		self.luaBoxMatchInput:SetCursorPosition(0)
		self.luaBoxMatchScroll:Show()
		self.borderReaction:Show()
		self.textReactionhHeader:Show()
		self.dropdownChannel:Show()
		UIDropDownMenu_Initialize(self.dropdownChannel, function() DropdownChannel_Initialize(self) end)
		UIDropDownMenu_SetSelectedValue(self.dropdownChannel, trigger.replyChannel or replyList[1])
		self.inputReply:Show()
		self.inputReply:SetText((trigger.useReply and trigger.useReply:gsub("|","||") or ""))
		self.inputReply:SetCursorPosition(0)
		self.luaBoxReactionText:Show()
		self.luaBoxReaction:Show()
		self.luaBoxReactionInput:Show()
		self.luaBoxReactionInput:SetText((trigger.luaReaction and trigger.luaReaction:gsub("||","|") or ""))
		self.luaBoxReactionInput:SetCursorPosition(0)
		self.luaBoxReactionScroll:Show()
		self.textLuaNote:Show()
		self.textChannels:Show()
		self.textAllowMatches:Show()
		for k,v in pairs(self.checkboxChannels) do
			v:Show()
			v:SetChecked(self:HasChatChannelTrigger(k, name))
		end
	end

	-- center top section
	self.textName:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
		(self.frame:GetWidth()/2)-(((trigger and self.buttonDelete:GetRight() or self.buttonCreateOrChange:GetRight())-self.textName:GetLeft())/2), 0)

	self.frame:Show()
	if not self.currentTriggerName then
		self.inputName:SetFocus()
	end
end
