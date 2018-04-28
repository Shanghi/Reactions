RSGUI.tags = {}
RSGUI.tags.__index = RSGUI.tags

local MAX_TAGS_SHOWN = 11 -- maximum amount of tags shown at once when showing all tags

----------------------------------------------------------------------------------------------------
-- create tags panel
----------------------------------------------------------------------------------------------------
function RSGUI.tags.new(main)
	local self = setmetatable({}, RSGUI.tags)

	self.frame = CreateFrame("frame", "RSGUI_Tags", nil)
	local panel = self.frame

	self.main = main
	main:AddContentFrame("tags", self)
	panel:SetScript("OnShow", function() main:HideContentExcept(panel) end)

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		if self.slider:IsVisible() then
			self.slider:SetValue(self.slider:GetValue() + (-delta))
		end
	end)

	----------------------------------------
	-- top section
	----------------------------------------
	-- Name: the text
	self.textName = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textName:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	self.textName:SetText("Tag name:")

	-- Name: the edit box
	self.inputName = CreateFrame("EditBox", "RSGUI_Tags_inputName", panel, "InputBoxTemplate")
	self.inputName:SetWidth(155)
	self.inputName:SetHeight(12)
	self.inputName:SetPoint("LEFT", self.textName, "RIGHT", 10, 0)
	self.inputName:SetAutoFocus(false)
	self.inputName:SetScript("OnEnterPressed",	 function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)

	-- Submenu: the text
	self.textSubmenu = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textSubmenu:SetPoint("LEFT", self.inputName, "RIGHT", 10, 0)
	self.textSubmenu:SetText("Submenu:")

	-- Submenu: the edit box
	self.inputSubmenu = CreateFrame("EditBox", "RSGUI_Tags_inputSubmenu", panel, "InputBoxTemplate")
	self.inputSubmenu:SetWidth(155)
	self.inputSubmenu:SetHeight(12)
	self.inputSubmenu:SetPoint("LEFT", self.textSubmenu, "RIGHT", 10, 0)
	self.inputSubmenu:SetAutoFocus(false)
	self.inputSubmenu:SetScript("OnEnterPressed", function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)

	-- be able to tab through some options
	self.inputName:SetScript("OnTabPressed",	 function() this:HighlightText(0,0) self.inputSubmenu:SetFocus() end)
	self.inputSubmenu:SetScript("OnTabPressed", function() this:HighlightText(0,0) self.inputName:SetFocus() end)

	-- create tag button
	self.buttonCreateOrChange = RSGUI.Utility.CreateButton("Tags_CreateChange", panel, 70, "Create")
	self.buttonCreateOrChange:SetPoint("LEFT", self.inputSubmenu, "RIGHT", 10, 0)
	self.buttonCreateOrChange.text = _G[self.buttonCreateOrChange:GetName().."Text"] -- will change depending on creating or editing
	self.buttonCreateOrChange:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()

		local name = self.inputName:GetText()
		local submenu = self.inputSubmenu:GetText()

		if name == "" then
			message("You must set a tag name.")
			return
		end

		local raidTargetIconList = {
			["star"]=1, ["circle"]=1, ["diamond"]=1, ["triangle"]=1, ["moon"]=1, ["square"]=1, ["cross"]=1, ["skull"]=1,
			["rt1"]=1, ["rt2"]=1, ["rt3"]=1, ["rt4"]=1, ["rt5"]=1, ["rt6"]=1, ["rt7"]=1, ["rt8"]=1,
			-- in case they're not using an english client:
			[RAID_TARGET_1]=1, [RAID_TARGET_2]=1, [RAID_TARGET_3]=1, [RAID_TARGET_4]=1, [RAID_TARGET_5]=1,
			[RAID_TARGET_6]=1, [RAID_TARGET_7]=1, [RAID_TARGET_8]=1,
		}
		if raidTargetIconList[name:lower()] then
			message("Tags can't have the same name as raid target markers.")
			return
		end

		local mode = self.buttonCreateOrChange:GetText()
		if mode == "Create" then
			-- if it already exists, just go to it
			if main.settings.tagList[name] then
				self:ShowSpecific(name)
				return
			end

			newTag = {}
			newTag.text = ""
			newTag.amount = 1
			newTag.submenu = submenu ~= "" and submenu or nil
			main.settings.tagList[name] = newTag
		elseif mode == "Change" then
			local oldName = self.contentTable[1].nameText:GetText()
			local tag = main.settings.tagList[oldName]

			if oldName ~= name then
				if main.settings.tagList[name] then
					message("A tag with that name already exists!\nYou must delete it first.")
					return
				end
				main.settings.tagList[name] = tag
				main.settings.tagList[oldName] = nil
				self.main:RemoveHistory("tag", oldName)
			end
			tag.submenu = submenu ~= "" and submenu or nil
		end

		self:BuildTagInformation(true)
		main:BuildTagsMenu(true)
		self:ShowSpecific(name)
	end)

	-- Delete button
	self.buttonDelete = RSGUI.Utility.CreateButton("Tags_Delete", panel, 70, "Delete")
	self.buttonDelete:SetPoint("LEFT", self.buttonCreateOrChange, "RIGHT", 3, 0)
	self.buttonDelete:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() self:Delete(1) end)

	-- be able to tab through some options
	self.inputName:SetScript("OnTabPressed",	 function() this:HighlightText(0,0) self.inputSubmenu:SetFocus() end)
	self.inputSubmenu:SetScript("OnTabPressed", function() this:HighlightText(0,0) self.inputName:SetFocus() end)

	----------------------------------------
	-- border
	----------------------------------------
	self.borderTop = panel:CreateTexture()
	self.borderTop:SetTexture(.4, .4, .4)
	self.borderTop:SetWidth(panel:GetWidth())
	self.borderTop:SetHeight(1)
	self.borderTop:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textName:GetBottom())-11)

	----------------------------------------
	-- scrollbar-like slider thing on side
	----------------------------------------
	self.slider = CreateFrame("Slider", "RSGUI_Tags_slider", panel, "OptionsSliderTemplate")
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
		for i=1,MAX_TAGS_SHOWN do
			if self.contentTable[i].phraseInput:HasFocus() then
				local newIndex = this.previousValue < this:GetValue() and i-1 or i+1
				if newIndex < 1 or newIndex > MAX_TAGS_SHOWN then
					focusOnInput = self.contentTable[i].phraseInput
				else
					focusOnInput = self.contentTable[newIndex].phraseInput
					cursorPosition = self.contentTable[i].phraseInput:GetCursorPosition()
				end
				self.contentTable[i].phraseInput:ClearFocus()
				break
			end
		end
		this.previousValue = this:GetValue() -- save to know which direction it's going
		self:ShowAll(this:GetValue())
		if focusOnInput then
			focusOnInput:SetFocus()
			focusOnInput:SetCursorPosition(cursorPosition or 0)
		end
	end)

	----------------------------------------
	-- scrollable tag data - built as groups of widgets
	----------------------------------------
	self.contentTable = {} -- widgets and data to control the groups
	local contentTable = self.contentTable

	-- build the widgets
	for i=1,MAX_TAGS_SHOWN do
		contentTable[i] = {}

		-- delete button
		contentTable[i].deleteButton = CreateFrame("Button", "RSGUI_Tags_deleteButton"..i, panel, "UIPanelCloseButton")
		contentTable[i].deleteButton:SetWidth(22)
		contentTable[i].deleteButton:SetHeight(22)
		if i == 1 then
			contentTable[i].deleteButton:SetPoint("TOPLEFT", self.borderTop, "BOTTOMLEFT", 0, -12)
		else
			contentTable[i].deleteButton:SetPoint("TOPLEFT", contentTable[i-1].phraseInput, "BOTTOMLEFT", 0, -10)
		end

		-- the name
		contentTable[i].nameText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		contentTable[i].nameText:SetPoint("LEFT", contentTable[i].deleteButton, "RIGHT", 5, 0)

		-- the edit box
		contentTable[i].phraseInput = CreateFrame("EditBox", "RSGUI_Tags_phraseInput"..i, panel, "InputBoxTemplate")
		contentTable[i].phraseInput:SetWidth(panel:GetWidth() - (panel:GetRight()-self.slider:GetLeft()) - 12)
		contentTable[i].phraseInput:SetHeight(10)
		contentTable[i].phraseInput:SetPoint("TOPLEFT", contentTable[i].deleteButton, "BOTTOMLEFT", 0, -2)
		contentTable[i].phraseInput:SetAutoFocus(false)
		contentTable[i].phraseInput:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	end

	-- larger edit box when only showing one
	contentTable.singlePhrase = CreateFrame("frame", "RSGUI_Tags_singlePhrase", panel)
	contentTable.singlePhrase:SetWidth(panel:GetWidth() - (panel:GetRight()-self.slider:GetLeft()) - 12)
	contentTable.singlePhrase:SetHeight(contentTable[1].deleteButton:GetTop() - panel:GetBottom())
	contentTable.singlePhrase:SetPoint("TOPLEFT", contentTable[1].deleteButton, "TOPLEFT", 0, 0)
	contentTable.singlePhrase:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=16,
		insets={left=5, right=5, top=5, bottom=5}})
	contentTable.singlePhrase:SetBackdropColor(0,0,0,1)

	contentTable.singlePhraseInput = CreateFrame("EditBox", "RSGUI_Tags_singlePhraseInput", contentTable.singlePhrase)
	contentTable.singlePhraseInput:SetMultiLine(true)
	contentTable.singlePhraseInput:SetAutoFocus(false)
	contentTable.singlePhraseInput:EnableMouse(true)
	contentTable.singlePhraseInput:SetFont("Fonts/ARIALN.ttf", 16)
	contentTable.singlePhraseInput:SetWidth(contentTable.singlePhrase:GetWidth()-20)
	contentTable.singlePhraseInput:SetHeight(contentTable.singlePhrase:GetHeight()-8)
	contentTable.singlePhraseInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	contentTable.singlePhraseInput:SetScript("OnTabPressed", function()
		self:TestTagPhrases(this:GetText())
		-- save too
		this.changed = true
		this:GetScript("OnEditFocusLost")(this)
		this.canChange = true
	end)
	contentTable.singlePhraseInput:SetScript("OnTextChanged", function()
		local scrollbar = _G[contentTable.singlePhraseScroll:GetName().."ScrollBar"]
		local min, max = scrollbar:GetMinMaxValues()
		if max > 0 and this.max ~= max then
			this.max = max
			scrollbar:SetValue(max)
		end

		if this.canChange then
			this.changed = true
		end
	end)
	contentTable.singlePhraseInput:SetScript("OnEditFocusGained", function()
		this.canChange = true
	end)
	contentTable.singlePhraseInput:SetScript("OnEditFocusLost", function()
		self:TestSave(1)
		this.canChange = false
	end)

	contentTable.singlePhraseScroll = CreateFrame("ScrollFrame", "RSGUI_Tags_singlePhraseScroll", contentTable.singlePhrase, "UIPanelScrollFrameTemplate")
	contentTable.singlePhraseScroll:SetPoint("TOPLEFT", contentTable.singlePhrase, "TOPLEFT", 8, -8)
	contentTable.singlePhraseScroll:SetPoint("BOTTOMRIGHT", contentTable.singlePhrase, "BOTTOMRIGHT", -6, 8)
	contentTable.singlePhraseScroll:EnableMouse(true)
	contentTable.singlePhraseScroll:SetScript("OnMouseDown", function() contentTable.singlePhraseInput:SetFocus() end)
	contentTable.singlePhraseScroll:SetScrollChild(contentTable.singlePhraseInput)
	contentTable.singlePhraseInput:SetScript("OnUpdate", function(this)
		ScrollingEdit_OnUpdate(contentTable.singlePhraseScroll)
	end)
	contentTable.singlePhraseInput:SetScript("OnCursorChanged", function()
		ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
	end)

	for i=1,MAX_TAGS_SHOWN do
		contentTable[i].deleteButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() self:Delete(i) end)

		contentTable[i].phraseInput:SetScript("OnTabPressed",function()
			self:TestTagPhrases(this:GetText())
			-- save too
			this.changed = true
			this:GetScript("OnEditFocusLost")(this)
			this.canChange = true
		end)
		contentTable[i].phraseInput:SetScript("OnTextChanged", function()
			if this.canChange then
				this.changed = true
			end
		end)
		contentTable[i].phraseInput:SetScript("OnEditFocusGained", function()
			this.canChange = true
		end)
		contentTable[i].phraseInput:SetScript("OnEditFocusLost", function()
			self:TestSave(i)
			this.canChange = false
		end)
	end

	return self
end

----------------------------------------------------------------------------------------------------
-- content table functions
----------------------------------------------------------------------------------------------------
-- testing phrase selection with tab key
function RSGUI.tags:TestTagPhrases(text)
	local choices = {}
	for phrase in text:gmatch("[^|]+") do
		table.insert(choices, (phrase:gsub("%c","")))
	end
	local chosen = #choices>0 and choices[math.random(1,#choices)] or ""
	DEFAULT_CHAT_FRAME:AddMessage("Random phrase: " .. chosen)
end

-- handling saving
function RSGUI.tags:TestSave(index)
	local main = self.main
	local contentTable = self.contentTable

	local inputBox
	if index == 1 and contentTable.singlePhraseInput:IsVisible() then
		inputBox = contentTable.singlePhraseInput
	else
		inputBox = contentTable[index].phraseInput
	end

	if inputBox.changed then
		inputBox.changed = nil
		local name = contentTable[index].nameText:GetText()
		if name and name ~= "" then
			local tag = main.settings["tagList"][name]
			tag.text = inputBox:GetText():gsub("||","|"):gsub("%c","")
			tag.amount = (select(2, tag.text:gsub("|", "|"))) + 1
			-- if using the big phrase box, then set the text to get rid of any visible new lines that might have been added
			if inputBox == contentTable.singlePhraseInput then
				inputBox.canChange = false
				inputBox:SetText(tag.text:gsub("|","||"))
				if inputBox:HasFocus() then
					inputBox.canChange = true
				end
			end
		end
	end
end

-- build an ordered list of tags
function RSGUI.tags:BuildTagInformation(rebuild)
	if self.contentTable.tagList and not rebuild then return end
	CloseDropDownMenus()
	self.contentTable.tagList = {}
	for name in pairs(self.main.settings.tagList) do
		local inserted = false
		for i=1,#self.contentTable.tagList do
			if name < self.contentTable.tagList[i] then
				table.insert(self.contentTable.tagList, i, name)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(self.contentTable.tagList, name)
		end
	end
end

-- set a group as a tag
function RSGUI.tags:Set(index, tagName)
	local contentTable = self.contentTable
	local group = contentTable[index]
	self:TestSave(index) -- check if the previous tag needs to be saved before overwriting it

	group.nameText:SetText(tagName) -- set even if editing a specific one - used when deleting

	local text = self.main.settings["tagList"][tagName].text
	if contentTable.singlePhrase:IsVisible() then
		group.nameText:Hide()
		group.deleteButton:Hide()
		group.phraseInput:Hide()
		contentTable.singlePhrase.canChange = false
		contentTable.singlePhraseInput:SetText((text and text:gsub("|","||") or ""))
		contentTable.singlePhraseInput:SetCursorPosition(0)
		if contentTable.singlePhraseInput:HasFocus() then
			contentTable.singlePhrase.canChange = true
		end
	else
		contentTable.singlePhrase:Hide()
		group.nameText:Show()
		group.nameText:SetText(tagName)
		group.deleteButton:Show()
		group.phraseInput:Show()
		group.phraseInput.canChange = false
		group.phraseInput:SetText((text and text:gsub("|","||") or ""))
		group.phraseInput:SetCursorPosition(0)
		if group.phraseInput:HasFocus() then
			group.phraseInput.canChange = true
		end
	end
end

-- show as many tags as possible
function RSGUI.tags:ShowAll(startPos)
	if self.showAllSettingUp then
		return
	end
	self.showAllSettingUp = true -- so showing the slider doesn't use this function again

	local contentTable = self.contentTable
	contentTable.singlePhrase:Hide()

	startPos = startPos or 1
	local tagAmount = #contentTable.tagList
	local onTag = startPos
	for i=1,MAX_TAGS_SHOWN do
		local group = contentTable[i]
		if contentTable.tagList[onTag] then
			self:Set(i, contentTable.tagList[onTag])
		else
			group.deleteButton:Hide()
			group.nameText:Hide()
			group.phraseInput:Hide()
		end
		onTag = onTag + 1
	end

	-- set the slider
	if tagAmount <= MAX_TAGS_SHOWN then
		self.slider:Hide()
	else
		local extraAmount = tagAmount - MAX_TAGS_SHOWN
		self.slider:SetMinMaxValues(1, extraAmount+1)
		self.slider:SetValue(startPos)
		self.slider:Show()
	end

	-- top sections
	if tagAmount == 0 then
		self.main:SetHeaderText("Tags")
		self.borderTop:Hide()
	else
		self.main:SetHeaderText("Tags: All")
		self.borderTop:Show()
	end
	self.buttonCreateOrChange.text:SetText("Create")
	self.buttonDelete:Hide()
	self.inputName:SetText("")
	self.inputSubmenu:SetText("")
	self.textName:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
		(self.frame:GetWidth()/2)-((self.buttonCreateOrChange:GetRight()-self.textName:GetLeft())/2), 0)

	self.showAllSettingUp = nil
end

-- show a specific tag
function RSGUI.tags:ShowSpecific(tagName)
	local contentTable = self.contentTable

	local group
	for i=1,MAX_TAGS_SHOWN do
		group = contentTable[i]
		group.deleteButton:Hide()
		group.nameText:Hide()
		group.phraseInput:Hide()
	end
	self.slider:Hide()
	contentTable.singlePhrase:Show()
	self:Set(1, tagName)
	contentTable.singlePhraseInput:SetFocus()
	contentTable.singlePhraseInput:SetCursorPosition(#contentTable.singlePhraseInput:GetText()+1)


	-- top sections
	self.main:SetHeaderText("Tags: " .. tagName)
	self.buttonCreateOrChange.text:SetText("Change")
	self.buttonDelete:Show()
	self.borderTop:Show()
	self.inputName:SetText(tagName)
	self.inputSubmenu:SetText(self.main.settings.tagList[tagName].submenu or "")
	self.textName:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
		(self.frame:GetWidth()/2)-((self.buttonDelete:GetRight()-self.textName:GetLeft())/2), 0)

	-- history
	self.main:AddHistory("tag", tagName, "Tag: " .. tagName)
end

-- deleting a tag
function RSGUI.tags:Delete(index)
	local contentTable = self.contentTable
	local group = contentTable[index]
	local name = contentTable[index].nameText:GetText()
	local list = contentTable.tagList
	for i=1,#list do
		if name == list[i] then
			table.remove(list, i)
			RSGUI.Utility.DeleteFromMenu(self.main.tagsMenu, name, self.main.settings.tagList[name].submenu)
			self.main.settings.tagList[name] = nil
			self.main:RemoveHistory("tag", name)

			if not contentTable[2].nameText:IsVisible() then
				-- was only showing one tag, so hide the first group
				group.deleteButton:Hide()
				group.nameText:Hide()
				group.phraseInput:Hide()
				contentTable.singlePhrase:Hide()
				self.borderTop:Hide()
				-- top sections
				self.main:SetHeaderText("Tags")
				self.buttonCreateOrChange.text:SetText("Create")
				self.buttonDelete:Hide()
				self.inputName:SetText("")
				self.inputSubmenu:SetText("")
				self.textName:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
					(self.frame:GetWidth()/2)-((self.buttonCreateOrChange:GetRight()-self.textName:GetLeft())/2), 0)
			else
				-- was showing all tags
				local newAmount = #list
				if newAmount <= MAX_TAGS_SHOWN then
					self:ShowAll()
				else
					local topShown = self.slider:GetValue()
					self:ShowAll((newAmount - topShown < MAX_TAGS_SHOWN) and topShown-1 or topShown)
				end
				if newAmount == 0 then
					self.main:SetHeaderText("Tags")
					self.borderTop:Hide()
				end
			end
			break
		end
	end
end

----------------------------------------------------------------------------------------------------
-- showing/hiding
----------------------------------------------------------------------------------------------------
function RSGUI.tags:Open(name)
	CloseDropDownMenus()
	self:BuildTagInformation()
	self.frame:Show()
	if name and self.main.settings["tagList"][name] then
		self:ShowSpecific(name)
	else
		self:ShowAll()
	end
end

