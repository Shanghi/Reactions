RSGUI.search = {}
RSGUI.search.__index = RSGUI.search

local MAX_SEARCHES_SHOWN = 11 -- maximum amount of searches shown at once

----------------------------------------------------------------------------------------------------
-- create search panel
----------------------------------------------------------------------------------------------------
function RSGUI.search.new(main)
	local self = setmetatable({}, RSGUI.search)

	self.frame = CreateFrame("frame", "RSGUI_Search", nil)
	local panel = self.frame

	self.main = main
	main:AddContentFrame("search", self)
	panel:SetScript("OnShow", function() main:HideContentExcept(panel) end)

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		if self.slider:IsVisible() then
			self.slider:SetValue(self.slider:GetValue() + (-delta))
		end
	end)

	--------------------------------------------------
	-- top section
	--------------------------------------------------
	-- text
	self.textSearch = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textSearch:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0) -- will be centered below
	self.textSearch:SetText("Find text in reactions and tags:")

	-- edit box
	self.inputSearch = CreateFrame("EditBox", "RSGUI_Search_inputText", panel, "InputBoxTemplate")
	self.inputSearch:SetWidth(400)
	self.inputSearch:SetHeight(12)
	self.inputSearch:SetPoint("LEFT", self.textSearch, "RIGHT", 10, 0)
	self.inputSearch:SetAutoFocus(false)
	self.inputSearch:SetScript("OnEnterPressed", function() this:ClearFocus() self.buttonSearch:GetScript("OnClick")() end)

	-- search button
	self.buttonSearch = RSGUI.Utility.CreateButton("Search_Search", panel, 70, "Search")
	self.buttonSearch:SetPoint("LEFT", self.inputSearch, "RIGHT", 10, 0)
	self.buttonSearch:SetScript("OnClick", function() self:Search(self.inputSearch:GetText()) end)

	-- center top section
	self.textSearch:SetPoint("TOPLEFT", panel, "TOPLEFT",
		(panel:GetWidth()/2)-((self.buttonSearch:GetRight()-self.textSearch:GetLeft())/2), 0)

	--------------------------------------------------
	-- border
	--------------------------------------------------
	self.borderTop = panel:CreateTexture()
	self.borderTop:SetTexture(.4, .4, .4)
	self.borderTop:SetWidth(panel:GetWidth())
	self.borderTop:SetHeight(1)
	self.borderTop:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textSearch:GetBottom())-11)

	--------------------------------------------------
	-- not found text
	--------------------------------------------------
	self.textNotFound = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textNotFound:SetPoint("TOP", self.borderTop, "BOTTOM", 0, -30)
	self.textNotFound:SetText("That text wasn't found in any reaction or tag.")
	self.textNotFound:Hide()

	--------------------------------------------------
	-- scrollbar-like slider thing on side
	--------------------------------------------------
	self.slider = CreateFrame("Slider", "RSGUI_Search_slider", panel, "OptionsSliderTemplate")
	self.slider:SetWidth(16)
	self.slider:SetHeight(panel:GetHeight()+(self.borderTop:GetBottom()-panel:GetTop()))
	self.slider:SetValueStep(1)
	self.slider:SetOrientation("VERTICAL")
	_G[self.slider:GetName().."Low"]:SetText("")
	_G[self.slider:GetName().."High"]:SetText("")
	_G[self.slider:GetName().."Text"]:SetText("")
	self.slider:SetPoint("TOPRIGHT", self.borderTop, "BOTTOMRIGHT", 0, -5)
	self.slider:Hide()
	self.slider:SetScript("OnValueChanged", function()
		-- if an input box has focus, move the focus up or down with it and keep the cursor position if possible
		local focusOnInput, cursorPosition
		for i=1,MAX_SEARCHES_SHOWN do
			if self.contentTable[i].inputText:HasFocus() then
				local newIndex = this.previousValue < this:GetValue() and i-1 or i+1
				if newIndex < 1 or newIndex > MAX_SEARCHES_SHOWN then
					focusOnInput = self.contentTable[i].inputText
				else
					focusOnInput = self.contentTable[newIndex].inputText
					cursorPosition = self.contentTable[i].inputText:GetCursorPosition()
				end
				self.contentTable[i].inputText:ClearFocus()
				break
			end
		end
		this.previousValue = this:GetValue() -- save to know which direction it's going
		self:ShowResults(this:GetValue())
		if focusOnInput then
			focusOnInput:SetFocus()
			focusOnInput:SetCursorPosition(cursorPosition or 0)
		end
	end)

	--------------------------------------------------
	-- scrollable search data - built as groups of widgets
	--------------------------------------------------
	self.contentTable = {} -- widgets and data to control the groups
	local contentTable = self.contentTable

	-- build the widgets
	for i=1,MAX_SEARCHES_SHOWN do
		contentTable[i] = {}

		-- description at top
		contentTable[i].textDescription = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		contentTable[i].textDescription:SetHeight(10.5)
		if i == 1 then
			contentTable[i].textDescription:SetPoint("TOPLEFT", self.borderTop, "BOTTOMLEFT", 0, -12)
		else
			contentTable[i].textDescription:SetPoint("TOPLEFT", contentTable[i-1].buttonOpen, "BOTTOMLEFT", 0, -9)
		end
		contentTable[i].textDescription:Hide()

		-- open button
		contentTable[i].buttonOpen = RSGUI.Utility.CreateButton("Search_Open"..i, panel, 60, "Open")
		contentTable[i].buttonOpen:SetPoint("TOPLEFT", contentTable[i].textDescription, "BOTTOMLEFT", 0, -2)
		contentTable[i].buttonOpen:Hide()
		contentTable[i].buttonOpen:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() self:OpenResult(self.contentTable[i].onResult) end)

		-- edit box
		contentTable[i].inputText = CreateFrame("EditBox", "RSGUI_Search_inputText"..i, panel, "InputBoxTemplate")
		contentTable[i].inputText:SetWidth(panel:GetWidth() - (panel:GetRight()-self.slider:GetLeft()) - contentTable[i].buttonOpen:GetWidth() - 20)
		contentTable[i].inputText:SetHeight(10)
		contentTable[i].inputText:SetPoint("LEFT", contentTable[i].buttonOpen, "RIGHT", 8, 0)
		contentTable[i].inputText:SetAutoFocus(false)
		contentTable[i].inputText:SetScript("OnEnterPressed", function() this:ClearFocus() end)
		contentTable[i].inputText:Hide()

		contentTable[i].inputText:SetScript("OnTabPressed",function()
			self:PrintOutput(i)
			-- save too
			this.changed = true
			this:GetScript("OnEditFocusLost")(this)
			this.canChange = true
		end)
		contentTable[i].inputText:SetScript("OnTextChanged", function()
			if this.canChange then
				this.changed = true
			end
		end)
		contentTable[i].inputText:SetScript("OnEditFocusGained", function()
			this.canChange = true
		end)
		contentTable[i].inputText:SetScript("OnEditFocusLost", function()
			self:TestSave(i)
			this.canChange = false
		end)
	end
	return self
end

----------------------------------------------------------------------------------------------------
-- helper functoins
----------------------------------------------------------------------------------------------------
-- set the main panel header text to show the current search, if any
function RSGUI.search:SetHeader()
	local text = self.inputSearch:GetText()
	if text == "" then
		text = "Search"
		self.borderTop:Hide()
	else
		text = "Search: " .. text
		self.borderTop:Show()
	end
	self.main:SetHeaderText(text)
end

----------------------------------------------------------------------------------------------------
-- doing a search
----------------------------------------------------------------------------------------------------
function RSGUI.search:Search(text)
	-- a result = {type, description, name, reference to settings table with text, action type (for spells/events)}
	self.results = {}

	if not text or text == "" then
		self:SetHeader()
		self:ShowResults()
		return
	end

	local format = string.format
	local results = self.results
	local settings = self.main.settings
	text = text:lower()

	-- reactions
	for spellName,spellValue in pairs(settings.reactionList) do
		for actionKey,actionValue in pairs(spellValue) do -- actions
			if type(actionValue) == "table" then -- looking for you_hit/you_miss/etc action tables, not other settings
				local actionReactions = actionValue["reactions"]
				if actionReactions then
					for i=1,#actionReactions do -- reaction list for the action
						if (actionReactions[i][2]:lower():find(text)) then
							local actionDescription
							local nickname
							if spellValue.event then
								for i,v in ipairs(RSGUI.reactions.eventInformationList) do
									if spellName == v[3] then
										nickname = v[1]
										local actionType
										if actionKey == "you_hit" then actionType = 1
										elseif actionKey == "member_hit" then actionType = 2
										elseif actionKey == "other_hit" then actionType = 3
										end
										actionDescription = actionType and v[5][actionType] or ""
										break
									end
								end
							else
								nickname = spellValue.nickname
								for _,v in ipairs(RSGUI.reactions.actionTypeList) do
									if actionKey == v[1] then
										actionDescription = v[2]
										break
									end
								end
							end
							results[#results+1] = {
								spellValue.event and "event" or "spell",
								format("%s: %s%s - %s",
									spellValue.event and "Event" or "Spell",
									spellValue.event and nickname or spellName,
									not spellValue.event and nickname and (" ("..nickname..")") or "",
									actionDescription or "unknown action"),
								spellName,
								actionReactions[i],
								actionKey
							}
						end
					end
				end
			end
		end
	end
	-- chat triggers
	for name,trigger in pairs(settings.chatList.trigger) do
		if trigger.useReply and trigger.useReply:lower():find(text) then
			results[#results+1] = {"chat", format("Chat Trigger: %s", name), name, trigger}
		end
	end
	-- tags
	for name,value in pairs(settings.tagList) do
		if (value.text:lower():find(text)) then
			results[#results+1] = {"tag", format("Tag: %s", name), name, value}
		end
	end

	self:SetHeader()
	self:ShowResults()
end

----------------------------------------------------------------------------------------------------
-- content table functions
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- show a test result of the text
--------------------------------------------------
function RSGUI.search:PrintOutput(index)
	local group = self.contentTable[index]
	local result = self.results[group.onResult]
	local rType = result[1]
	if rType == "spell" or rType == "event" or rType == "chat" then
		_G.SlashCmdList.REACTIONS("testmessage " .. group.inputText:GetText():gsub("||","|"))
	elseif rType == "tag" then
		self.main.content.tags:TestTagPhrases(group.inputText:GetText())
	end
end

--------------------------------------------------
-- save edited text
--------------------------------------------------
function RSGUI.search:TestSave(index)
	local group = self.contentTable[index]
	if group.inputText.changed then
		group.inputText.changed = nil

		local result = self.results[group.onResult]
		local rType = result[1]
		local reference = result[4]
		local newText = group.inputText:GetText()
		if rType == "spell" or rType == "event" then
			reference[2] = newText:gsub("||","|"):gsub("^%s+/", "/")
		elseif rType == "chat" then
			reference.useReply = newText:gsub("||","|"):gsub("^%s+/", "/")
		elseif rType == "tag" then
			reference.text = newText:gsub("||","|"):gsub("%c","")
			reference.amount = (select(2, reference.text:gsub("|", "|"))) + 1
		end
	end
end

--------------------------------------------------
-- go to a certain result
--------------------------------------------------
function RSGUI.search:OpenResult(onResult)
	local result = self.results[onResult]
	local rType = result[1]
	local name = result[3]
	if rType == "spell" or rType == "event" then
		self.main.content.reactions:Open(name, (rType == "event"), result[5])
	elseif rType == "chat"then
		self.main.content.chat:Open(name)
	elseif rType == "tag"
		then self.main.content.tags:Open(name)
	end
end

--------------------------------------------------
-- set a content table group as a result
--------------------------------------------------
function RSGUI.search:Set(index, onResult)
	self:TestSave(index) -- check if the previous tag needs to be saved before overwriting it

	local result = self.results[onResult]
	local group = self.contentTable[index]
	group.onResult = onResult
	group.textDescription:Show()
	group.textDescription:SetText(result[2])
	group.buttonOpen:Show()
	group.inputText:Show()

	local text
	local rType = result[1]
	if rType == "spell" or rType == "event" then
		text = result[4][2]
	elseif rType == "chat" then
		text = result[4].useReply
	elseif rType == "tag" then
		text = result[4].text
	end
	group.inputText.canChange = false
	group.inputText:SetText((text and text:gsub("|","||") or ""))
	group.inputText:SetCursorPosition(0)
	if group.inputText:HasFocus() then
		group.inputText.canChange = true
	end

end

--------------------------------------------------
-- show the search results
--------------------------------------------------
function RSGUI.search:ShowResults(startPos)
	if self.resultsSettingUp then
		return
	end

	self.textNotFound:Hide()
	if self.results[1] == nil then
		if self.inputSearch:GetText() ~= "" then
			self.textNotFound:Show()
		end
		for i=1,MAX_SEARCHES_SHOWN do
			local group = self.contentTable[i]
			group.textDescription:Hide()
			group.buttonOpen:Hide()
			group.inputText:Hide()
		end
		return
	end

	startPos = startPos or 1
	local resultAmount = #self.results
	local onResult = startPos
	for i=1,MAX_SEARCHES_SHOWN do
		local group = self.contentTable[i]

		if self.results[onResult] then
			self:Set(i, onResult)
		else
			group.textDescription:Hide()
			group.buttonOpen:Hide()
			group.inputText:Hide()
		end
		onResult = onResult + 1
	end

	-- set the slider
	self.resultsSettingUp = true -- so showing the slider doesn't use this function again
	if resultAmount <= MAX_SEARCHES_SHOWN then
		self.slider:Hide()
	else
		local extraAmount = resultAmount - MAX_SEARCHES_SHOWN
		self.slider:SetMinMaxValues(1, extraAmount+1)
		self.slider:SetValue(startPos)
		self.slider:Show()
	end
	self.resultsSettingUp = nil
end

----------------------------------------------------------------------------------------------------
-- showing/hiding
----------------------------------------------------------------------------------------------------
function RSGUI.search:Open()
	CloseDropDownMenus()
	self.frame:Show()
	self:SetHeader()
	self.inputSearch:SetFocus()
end
