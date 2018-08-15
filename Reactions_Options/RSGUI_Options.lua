RSGUI.options = {}
RSGUI.options.__index = RSGUI.options

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- create an input box with text beside it for the options section
function RSGUI.options:CreateOptionsInput(name, maxLetters, numericType, position, text, tooltip)
	local textString = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	textString:SetText(text)

	local input = CreateFrame("EditBox", "RSGUI_Options_Input_"..name, self.frame, "InputBoxTemplate")
	input:SetWidth(46)
	input:SetHeight(12)
	input:SetPoint("LEFT", textString, "LEFT", position, 0)
	input:SetNumeric(numericType == 1)
	input:SetMaxLetters(maxLetters)
	input:SetAutoFocus(false)
	if numericType == 2 then
		input:SetScript("OnTextChanged", function() RSGUI.Utility.FixChanceNumber(this) end)
	end
	input:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	if tooltip then
		input.tooltipText = tooltip
		input:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
		input:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)
	end

	return textString, input
end

-- for showing tooltips on role items
local function RoleItemButton_OnEnter(options, index)
	if options.main.settings.roleItems[index] then
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink("item:" .. options.main.settings.roleItems[index][2])
		GameTooltip:Show()
	end
end

-- dragging an item onto a role item button
local function InputReceiveItem(options, index)
	local cursorType, _, link = GetCursorInfo()
	if cursorType == "item" then
		local id = link:match("item:(%d+)")
		local slot1, slot2
		local name, _, _, _, _, _, _, _, slotType, texture = GetItemInfo(id)
		ClearCursor()

		-- convert the slot type to slot IDs
		if slotType then
			if     slotType == "INVTYPE_2HWEAPON"       then slot1 = 16; slot2 = nil;
			elseif slotType == "INVTYPE_AMMO"           then slot1 =  0; slot2 = nil;
			elseif slotType == "INVTYPE_BODY"           then slot1 =  4; slot2 = nil;
			elseif slotType == "INVTYPE_CHEST"          then slot1 =  5; slot2 = nil;
			elseif slotType == "INVTYPE_CLOAK"          then slot1 = 15; slot2 = nil;
			elseif slotType == "INVTYPE_FEET"           then slot1 =  8; slot2 = nil;
			elseif slotType == "INVTYPE_FINGER"         then slot1 = 11; slot2 =  12;
			elseif slotType == "INVTYPE_HAND"           then slot1 = 10; slot2 = nil;
			elseif slotType == "INVTYPE_HEAD"           then slot1 =  1; slot2 = nil;
			elseif slotType == "INVTYPE_HOLDABLE"       then slot1 = 17; slot2 = nil;
			elseif slotType == "INVTYPE_LEGS"           then slot1 =  7; slot2 = nil;
			elseif slotType == "INVTYPE_NECK"           then slot1 =  2; slot2 = nil;
			elseif slotType == "INVTYPE_RANGED"         then slot1 = 18; slot2 = nil;
			elseif slotType == "INVTYPE_RANGEDRIGHT"    then slot1 = 18; slot2 = nil;
			elseif slotType == "INVTYPE_RELIC"          then slot1 = 18; slot2 = nil;
			elseif slotType == "INVTYPE_ROBE"           then slot1 =  5; slot2 = nil;
			elseif slotType == "INVTYPE_SHIELD"         then slot1 = 17; slot2 = nil;
			elseif slotType == "INVTYPE_SHOULDER"       then slot1 =  3; slot2 = nil;
			elseif slotType == "INVTYPE_TABARD"         then slot1 = 19; slot2 = nil;
			elseif slotType == "INVTYPE_THROWN"         then slot1 = 18; slot2 = nil;
			elseif slotType == "INVTYPE_TRINKET"        then slot1 = 13; slot2 =  14;
			elseif slotType == "INVTYPE_WAIST"          then slot1 =  6; slot2 = nil;
			elseif slotType == "INVTYPE_WEAPON"         then slot1 = 16; slot2 =  17;
			elseif slotType == "INVTYPE_WEAPONMAINHAND" then slot1 = 16; slot2 = nil;
			elseif slotType == "INVTYPE_WEAPONOFFHAND"  then slot1 = 17; slot2 = nil;
			elseif slotType == "INVTYPE_WRIST"          then slot1 =  9; slot2 = nil;
			else
				message("The item must be wearable equipment.")
				return
			end
		end

		options.main.settings.roleItems[index] = {name, tonumber(id), texture, slot1, slot2}
		options.main.content.reactions:CreateRoleItemMenu()
		SetItemButtonTexture(options.roleItems[index], texture)
	end
end

-- create a numbered role item frame from the options panel
local function CreateRoleItemFrame(options, index)
	local button = CreateFrame("Button", "RSGUI_Options_RoleButton"..index, options.frame, "ItemButtonTemplate")
	options.roleItems[index] = button

	if index == 1 then
		button:SetPoint("BOTTOM", options.textLowManaBegin, "BOTTOM", 0, -3)
		button:SetPoint("LEFT", options.checkboxQuietStealth, "LEFT", 0, 0)
	else
		button:SetPoint("LEFT", options.roleItems[index-1], "RIGHT", 4, 0)
	end

	button:SetPushedTexture(nil)
	button:SetScript("OnEnter", function() RoleItemButton_OnEnter(options, index) end)
	button:SetScript("OnLeave", WidgetTooltip_OnLeave)
	button:SetScript("OnReceiveDrag", function() InputReceiveItem(options, index) end)
	button:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			InputReceiveItem(options, index)
		elseif button == "RightButton" then
			SetItemButtonTexture(self, nil)
			options.main.settings.roleItems[index] = nil
			options.main.content.reactions:CreateRoleItemMenu()
			GameTooltip:Hide()
		end
	end)

	_G[button:GetName().."Count"]:SetText(index)
	_G[button:GetName().."Count"]:Show()
end

----------------------------------------------------------------------------------------------------
-- create options panel
----------------------------------------------------------------------------------------------------
function RSGUI.options.new(main)
	local self = setmetatable({}, RSGUI.options)

	self.frame = CreateFrame("frame", "RSGUI_Options", nil)
	local panel = self.frame

	self.main = main
	main:AddContentFrame("options", self)
	panel:SetScript("OnShow", function()
		main:HideContentExcept(panel)
		main.optionsButton:Disable()
	end)
	panel:SetScript("OnHide", function () main.optionsButton:Enable() end)

	--------------------------------------------------
	-- panel widgets
	--------------------------------------------------
	-- Global cooldown
	self.textGlobalCooldown, self.inputGlobalCooldown = self:CreateOptionsInput("optionsGlobalCooldown", 5, 1, 170,
		"Default global cooldown:", "Seconds before another spell or event reaction can happen. Chat triggers don't use this.")
	self.textGlobalCooldown:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	self.inputGlobalCooldown:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local time = tonumber(self.inputGlobalCooldown:GetText())
		if not time or time == "" then
			time = 0
			self.inputGlobalCooldown:SetText(0)
		end
		self.main.settings["globalCooldown"] = time
	end)

	-- Reaction cooldown
	self.textMessageCooldown, self.inputMessageCooldown = self:CreateOptionsInput("optionsMessageCooldown", 5, 1, 170,
		"Individual reaction cooldown:", "Wait this many seconds before choosing the same reaction again (unless there's no others to choose).")
	self.textMessageCooldown:SetPoint("TOPLEFT", self.textGlobalCooldown, "BOTTOMLEFT", 0, -10)
	self.inputMessageCooldown:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local time = tonumber(self.inputMessageCooldown:GetText())
		if not time or time == "" then
			time = 0
			self.inputMessageCooldown:SetText(0)
		end
		self.main.settings["messageCooldown"] = time
	end)

	-- Chance multiplier
	self.textChanceMultiplier, self.inputChanceMultiplier = self:CreateOptionsInput("optionsChanceMultiplier", 5, 2, 170,
		"Chance multiplier:", "Multiply the chance on every spell, event, and chat reaction by this much.")
	self.textChanceMultiplier:SetPoint("TOPLEFT", self.textMessageCooldown, "BOTTOMLEFT", 0, -10)
	self.inputChanceMultiplier:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local multiplier = FixChanceNumber(self.inputChanceMultiplier)
		if multiplier <= 0 then
			multiplier = 1
			self.inputChanceMultiplier:SetText("1")
		elseif multiplier > 99999 then
			multiplier = 99999
			self.inputChanceMultiplier:SetText("99999")
		end
		self.main.settings["chanceMultiplier"] = multiplier
	end)

	-- Fight length
	self.textFightLength, self.inputFightLength = self:CreateOptionsInput("optionsFightLength", 3, 1, 170,
		"Minimum fight length:", "How many seconds combat must last to count as a fight.")
	self.textFightLength:SetPoint("TOPLEFT", self.textChanceMultiplier, "BOTTOMLEFT", 0, -10)
	self.inputFightLength:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local length = tonumber(self.inputFightLength:GetText())
		if not length or length == "" then
			length = 0
			self.inputFightLength:SetText(0)
		end
		self.main.settings["fightLength"] = length
	end)

	-- Low durability
	self.textLowDurability, self.inputLowDurability = self:CreateOptionsInput("optionsLowDurability", 2, 1, 170,
		"Low durability percentage:", "The equipment durability percentage that triggers the Durability (Low) event.")
	self.textLowDurability:SetPoint("TOPLEFT", self.textFightLength, "BOTTOMLEFT", 0, -10)
	self.inputLowDurability:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local percent = tonumber(self.inputLowDurability:GetText())
		if not percent then
			percent = 25
		elseif percent < 1 then
			percent = 1
		elseif percent > 99 then
			percent = 99
		end
		self.inputLowDurability:SetText(percent)
		self.main.settings["lowDurability"] = percent
	end)

	-- automatic event time
	self.textAutomaticMinimum, self.inputAutomaticMinimum = self:CreateOptionsInput("optionsAutomaticMinimum", 3, 1, 170,
		"Automatic event time:", "Minimum amount of minutes before the Automatic event is used.")
	self.textAutomaticMinimum:SetPoint("TOPLEFT", self.textLowDurability, "BOTTOMLEFT", 0, -10)
	self.inputAutomaticMinimum:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local minutes = tonumber(self.inputAutomaticMinimum:GetText())
		if not minutes or minutes < 1 then
			minutes = 1
		elseif minutes > self.main.settings["automaticMaximum"] then
			minutes = self.main.settings["automaticMaximum"]
		end
		self.inputAutomaticMinimum:SetText(minutes)
		self.main.settings["automaticMinimum"] = minutes
		_G.SlashCmdList["REACTIONS"]("updateautomatic")
	end)

	self.textAutomaticMaximum, self.inputAutomaticMaximum = self:CreateOptionsInput("optionsAutomaticMaximum", 3, 1, 13,
		"-", "Maximum amount of minutes before the Automatic event is used.")
	self.textAutomaticMaximum:SetPoint("LEFT", self.inputAutomaticMinimum, "RIGHT", 2, 0)
	self.inputAutomaticMaximum:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local minutes = tonumber(self.inputAutomaticMaximum:GetText())
		if not minutes or minutes < self.main.settings["automaticMinimum"] then
			minutes = self.main.settings["automaticMinimum"]
			self.inputAutomaticMaximum:SetText(minutes)
		end
		self.main.settings["automaticMaximum"] = minutes
		_G.SlashCmdList["REACTIONS"]("updateautomatic")
	end)

	-- low health
	self.textLowHealthBegin, self.inputLowHealthBegin = self:CreateOptionsInput("optionsLowHealthBegin", 2, 1, 170,
		"Low/High health percentages:", "The percentage that the Low Health (Begin) event is used.")
	self.textLowHealthBegin:SetPoint("TOPLEFT", self.textAutomaticMinimum, "BOTTOMLEFT", 0, -10)
	self.inputLowHealthBegin:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local percent = tonumber(self.inputLowHealthBegin:GetText())
		if not percent or percent < 1 then
			percent = 1
		elseif percent >= self.main.settings["lowHealthEnd"] then
			percent = self.main.settings["lowHealthEnd"] - 1
		elseif percent >= 99 then
			percent = 99
		end
		self.inputLowHealthBegin:SetText(percent)
		self.main.settings["lowHealthBegin"] = percent
	end)

	self.textLowHealthEnd, self.inputLowHealthEnd = self:CreateOptionsInput("optionsLowHealthEnd", 3, 1, 13,
		"-", "The percentage that the Low Health (End) event is used (only after Low Health (Begin) happens).")
	self.textLowHealthEnd:SetPoint("LEFT", self.inputLowHealthBegin, "RIGHT", 2, 0)
	self.inputLowHealthEnd:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local percent = tonumber(self.inputLowHealthEnd:GetText())
		if not percent or percent > 100 then
			percent = 100
		elseif percent <= self.main.settings["lowHealthBegin"] then
			percent = self.main.settings["lowHealthBegin"] + 1
		end
		self.inputLowHealthEnd:SetText(percent)
		self.main.settings["lowHealthEnd"] = percent
	end)

	-- low mana
	self.textLowManaBegin, self.inputLowManaBegin = self:CreateOptionsInput("optionsLowManaBegin", 2, 1, 170,
		"Low/High mana percentages:", "The percentage that the Low Mana (Begin) event is used.")
	self.textLowManaBegin:SetPoint("TOPLEFT", self.textLowHealthBegin, "BOTTOMLEFT", 0, -10)
	self.inputLowManaBegin:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local percent = tonumber(self.inputLowManaBegin:GetText())
		if not percent or percent < 1 then
			percent = 1
		elseif percent >= self.main.settings["lowManaEnd"] then
			percent = self.main.settings["lowManaEnd"] - 1
		elseif percent >= 99 then
			percent = 99
		end
		self.inputLowManaBegin:SetText(percent)
		self.main.settings["lowManaBegin"] = percent
	end)

	self.textLowManaEnd, self.inputLowManaEnd = self:CreateOptionsInput("optionsLowManaEnd", 3, 1, 13,
		"-", "The percentage that the Low Mana (End) event is used (only after Low Mana (Begin) happens).")
	self.textLowManaEnd:SetPoint("LEFT", self.inputLowManaBegin, "RIGHT", 2, 0)
	self.inputLowManaEnd:SetScript("OnEditFocusLost", function()
		if not self.main.settings then return end
		local percent = tonumber(self.inputLowManaEnd:GetText())
		if not percent or percent > 100 then
			percent = 100
		elseif percent <= self.main.settings["lowManaBegin"] then
			percent = self.main.settings["lowManaBegin"] + 1
		end
		self.inputLowManaEnd:SetText(percent)
		self.main.settings["lowManaEnd"] = percent
	end)

	-- be able to tab through options
	self.inputGlobalCooldown:SetScript("OnTabPressed",   function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowManaEnd:SetFocus()       else self.inputMessageCooldown:SetFocus()  end end)
	self.inputMessageCooldown:SetScript("OnTabPressed",  function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputGlobalCooldown:SetFocus()   else self.inputChanceMultiplier:SetFocus() end end)
	self.inputChanceMultiplier:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputMessageCooldown:SetFocus()  else self.inputFightLength:SetFocus()      end end)
	self.inputFightLength:SetScript("OnTabPressed",      function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowManaEnd:SetFocus()       else self.inputLowDurability:SetFocus()    end end)
	self.inputLowDurability:SetScript("OnTabPressed",    function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputFightLength:SetFocus()      else self.inputAutomaticMinimum:SetFocus() end end)
	self.inputAutomaticMinimum:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowDurability:SetFocus()    else self.inputAutomaticMaximum:SetFocus() end end)
	self.inputAutomaticMaximum:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputAutomaticMinimum:SetFocus() else self.inputLowHealthBegin:SetFocus()   end end)
	self.inputLowHealthBegin:SetScript("OnTabPressed",   function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputAutomaticMaximum:SetFocus() else self.inputLowHealthEnd:SetFocus()     end end)
	self.inputLowHealthEnd:SetScript("OnTabPressed",     function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowHealthBegin:SetFocus()   else self.inputLowManaBegin:SetFocus()     end end)
	self.inputLowManaBegin:SetScript("OnTabPressed",     function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowHealthEnd:SetFocus()     else self.inputLowManaEnd:SetFocus()       end end)
	self.inputLowManaEnd:SetScript("OnTabPressed",       function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputLowManaBegin:SetFocus()     else self.inputGlobalCooldown:SetFocus()   end end)

	-- quiet while stealthed option
	self.checkboxQuietStealth = RSGUI.Utility.CreateCheckbox("quietStealth", panel, "Quiet stealth mode",
		"You won't say, yell, or emote if you're stealthed in the world, battleground, or arena.")
	self.checkboxQuietStealth:SetPoint("LEFT", self.textGlobalCooldown, "LEFT", 330, 0)
	self.checkboxQuietStealth:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		if self.main.settings then
			self.main.settings["quietStealth"] = this:GetChecked() and true or false
		end
	end)

	-- shout mode option
	self.checkboxShoutMode = RSGUI.Utility.CreateCheckbox("shoutMode", panel, "SHOUT MODE",
		"CONVERT MESSAGES TO ALL CAPS BEFORE USING THEM.")
	self.checkboxShoutMode:SetPoint("TOPLEFT", self.checkboxQuietStealth, "BOTTOMLEFT", 0, 8)
	self.checkboxShoutMode:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		if self.main.settings then
			self.main.settings["shoutMode"] = this:GetChecked() and true or false
		end
	end)

	--------------------------------------------------
	-- role items
	--------------------------------------------------
	self.roleItems = {} -- item icons
	for i=1,10 do
		CreateRoleItemFrame(self, i)
	end

	self.textRoleItem = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textRoleItem:SetJustifyH("LEFT")
	self.textRoleItem:SetText("Role items - used in reaction conditions to only react if wearing one of these.\n"..
		"Drag and drop an item to set and right click to unset.")
	self.textRoleItem:SetPoint("BOTTOMLEFT", self.roleItems[1], "TOPLEFT", 0, 4)



	--------------------------------------------------
	-- statistics
	--------------------------------------------------
	self.textStatistics = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textStatistics:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
	self.textStatistics:SetTextColor(1,1,1,1)
	self.textStatistics:SetJustifyH("RIGHT")

	--------------------------------------------------
	-- help text
	--------------------------------------------------
	local tutorial = CreateFrame("frame", "RSGUI_Options_tutorial", panel)
	tutorial:SetWidth(self.frame:GetWidth()-20)
	tutorial:SetHeight(self.inputLowManaBegin:GetBottom() - self.frame:GetBottom() - 15)
	tutorial:SetPoint("BOTTOM", self.frame, "BOTTOM", -10, -5)
	tutorial:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=16,
		insets={left=5, right=5, top=5, bottom=5}})
	tutorial:SetBackdropColor(0,0,0,1)

	local tutorialTextContainer = CreateFrame("frame", "RSGUI_Options_tutorialTextContainer", tutorial)
	tutorialTextContainer:SetWidth(tutorial:GetWidth()-30)

	tutorialTextContainer.text = tutorialTextContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	tutorialTextContainer.text:SetJustifyH("LEFT")
	tutorialTextContainer.text:SetJustifyV("TOP")
	tutorialTextContainer.text:SetTextColor(1,1,1,1)
	tutorialTextContainer.text:SetFont("Fonts/ARIALN.ttf", 14)
	tutorialTextContainer.text:SetWidth(tutorialTextContainer:GetWidth())
	tutorialTextContainer.text:SetPoint("TOPLEFT", tutorialTextContainer, "TOPLEFT")
	tutorialTextContainer.text:SetPoint("BOTTOMRIGHT", tutorialTextContainer, "BOTTOMRIGHT")
	tutorialTextContainer.text:SetText(RSGUI.options.guideText)
	tutorialTextContainer:SetHeight(tutorialTextContainer.text:GetStringHeight())

	local tutorialScroll = CreateFrame("ScrollFrame", "RSGUI_Options_tutorialScroll", tutorial, "UIPanelScrollFrameTemplate")
	tutorialScroll:SetPoint("TOPLEFT", tutorial, "TOPLEFT", 8, -8)
	tutorialScroll:SetPoint("BOTTOMRIGHT", tutorial, "BOTTOMRIGHT", -6, 8)
	tutorialScroll:EnableMouse(true)
	tutorialScroll:SetScrollChild(tutorialTextContainer)

	return self
end

----------------------------------------------------------------------------------------------------
-- updating and opening
----------------------------------------------------------------------------------------------------
function RSGUI.options:Update()
	-- settings
	local settings = self.main.settings
	self.inputGlobalCooldown:SetText(settings["globalCooldown"])
	self.inputMessageCooldown:SetText(settings["messageCooldown"])
	self.inputAutomaticMinimum:SetText(settings["automaticMinimum"])
	self.inputAutomaticMaximum:SetText(settings["automaticMaximum"])
	self.inputLowHealthBegin:SetText(settings["lowHealthBegin"])
	self.inputLowHealthEnd:SetText(settings["lowHealthEnd"])
	self.inputLowManaBegin:SetText(settings["lowManaBegin"])
	self.inputLowManaEnd:SetText(settings["lowManaEnd"])
	self.inputFightLength:SetText(settings["fightLength"])
	self.inputLowDurability:SetText(settings["lowDurability"])
	self.inputChanceMultiplier:SetText(settings["chanceMultiplier"])
	self.checkboxQuietStealth:SetChecked(settings["quietStealth"])
	self.checkboxShoutMode:SetChecked(settings["shoutMode"])
	local item
	for i=1,10 do
		item = settings.roleItems[i]
		if item then
			SetItemButtonTexture(self.roleItems[i], item[3])
		end
	end

	-- statistics
	local spellCount = 0
	local eventCount = 0
	local actionCount = 0
	local reactionCount = 0
	local CountReactionActions = self.main.content.reactions.CountReactionActions
	local reactionsContent = self.main.content.reactions
	for name,info in pairs(self.main.settings["reactionList"]) do
		if info.event then
			eventCount = eventCount + 1
		else
			spellCount = spellCount + 1
		end
		local newActions, newReactions = CountReactionActions(reactionsContent, name)
		actionCount = actionCount + newActions
		reactionCount = reactionCount + newReactions
	end
	local tagCount = 0
	for _ in pairs(self.main.settings["tagList"]) do
		tagCount = tagCount + 1
	end
	local chatCount = 0
	for _ in pairs(self.main.settings.chatList.trigger) do
		chatCount = chatCount + 1
	end

	self.textStatistics:SetText(string.format("Version 1.%.1f\n%d spell%s and %d event%s watched\n%d action%s with %d total reaction%s\n%d chat trigger%s\n%d tag%s",
		self.main.settings.version,
		spellCount,    (spellCount    == 1 and "" or "s"),
		eventCount,    (eventCount    == 1 and "" or "s"),
		actionCount,   (actionCount   == 1 and "" or "s"),
		reactionCount, (reactionCount == 1 and "" or "s"),
		chatCount,     (chatCount     == 1 and "" or "s"),
		tagCount,      (tagCount      == 1 and "" or "s"))
	)
end

function RSGUI.options:Open()
	self.main:SetHeaderText("Options")
	self.frame:Show() -- before gathering stats or else other things may not be closed and fixed yet
	self:Update()
end

----------------------------------------------------------------------------------------------------
-- the guide's text
----------------------------------------------------------------------------------------------------
RSGUI.options.guideText =
[[|cff00ff00Quick Guide:|r

Test Mode will only show reaction messages to you and won't actually say/do them.

|cffffff00Variables in messages:|r
Variables are certain text surrounded by |cff999900< >|r that will insert things like the target's name or class into the reaction message. The [?] button at the top right will list all variables, and clicking on one will insert it into whatever you're editing.

Example: |cff999900I, <player_name> the <player_class>, hit <target_name> with my spell! My pet, <pet_name>, was happy!|r

The macro-style variables let you use Unit ID names ( http://www.wowwiki.com/UnitId ) that are used in macros, like |cff999900target|r, |cff999900focus|r, |cff999900mouseover|r, etc. For these, "target" is your actual, current target and may not be the same as |cff999900<target_name>|r.

Example: |cff999900I am resurrecting <name:mouseover> the <class:mouseover>!

|cffffff00Tags in messages:|r
Tags are similar to variables and are surrounded by curly brackets/braces |cff999900{ }|r. They are phrase lists you create that will pick a random phrase when used in a message. These are meant to be generic lists like months or standard locations that multiple messages could use. Phrases are separated by the |cff999900|||r character, like: |cff999900First||Second phrase||Third|r

Example: |cff999900My favorite color is {color} and I am not afraid of {megaman robot}|r

You can combine tags by separating them with |cff999900|||r to get one random choice, like: |cff999900Today I'm going to {alliance capital||horde capital}|r

|cffffff00Randomized phrases:|r
Randomized phrases are like tags, but used directly in messages instead of being created separately. The phrase list is surrounded by paratheses |cff999900( )|r. You can use variables and tags inside the phrase list. They can also be nested, with one group put inside another.

Example: |cff999900When I visit (the store||<zone>||the {color} building), I (remember||forget) many things.|r
Nested example: |cff999900The (big (monster||fish)||small (raccoon||rooster)) is troubled.|r

|cffffff00Multiple actions and timing:|r
To do another action (like say a 2nd message), put |cff999900<new>|r at the end of the first message.

Example: |cff999900My first message<new>I'm saying a second thing!<new>This is my 3rd message!|r

You can set a time to wait before doing the next message. The time adds on to previous time.
Example: |cff999900Hello<new 3>I waited 3 seconds to say this!<new 2>I waited 2 more after the 2nd message!|r
Example of random time: |cff999900Hello<new 5 10>I waited five to ten seconds to say this!|r
Example of waiting at beginning: |cff999900<new 5>I waited 5 seconds before reacting at all like a sloth!|r

Each new message uses the dropdown channel setting (like "Chat Command" or "/w Target") by default, but you can change it:
Example: |cff999900Hmmm<new:group>I'm thinking<new 3:group>Now I understand!<new 3>I'm back to using "chat command" by default!|r
Example using Group dropdown: |cff999900Let's go!<new:chat>/y We're not scared of any naga<new 3>We must rescue these slaves.|r

* You can use |cff999900<new:chat>|r instead of |cff999900<new:chat command>|r.
* If you're ignored by someone, all future whispers to them will be canceled.
* Disabling the addon will cancel all future actions instantly.

|cffffff00Groups:|r
Each action type (hit/miss/start cast/etc) of each spell/event can be placed into a named group. The Groups button will automatically collect a list of any groups you assign. From there, you're able to temporarily disable all reactions in a group by unchecking its name on the list.

There's also an Ungrouped option on the list that can toggle everything without a group assigned. This would let you put only the most important things into groups and be able to easily disable the rest.

|cffffff00Cooldowns:|r
Spells/Events that have a blank "Override GCD" setting will all share the one set here in the options. To have no cooldown, set the override to 0. Each chat trigger has its own individual cooldowns, with the global cooldown affecting everyone that triggers it and its person cooldown being specific to each person triggering it.

|cffffff00Event notes:|r
* Killing blows are only detected when the killer is in your party or raid subgroup.
* Targeting events only happen if they're in the range where you can inspect someone.
* Swimming and underwater events can happen every second, so a low chance combined with overriding the GCD might be wise! If both swimming and underwater, only the underwater event is used.
* Incapacitated and Silenced relies on a list of spells to be detected. While most normal cases should be known about, there may be spells (especially from pre-TBC mobs) that were missed.

|cffffff00Chat triggers:|r
To search for multiple phrases in a chat trigger, separate each with |cff999900|||r like: |cff999900gold||give me||boost|r. Each phrase is checked using lua patterns so you can do more than just plain text matching. A simple tutorial is at http://bit.ly/199QSAD

System messages don't have a sender, so the |cff999900<target_name>|r variable will be blank, even for messages like someone rolling.

To get a certain part of a message, you can use pattern matching captures in the phrase list (explained in the lua matching tutorial). The |cff999900<capture:#>|r variables will have the captured text in them. |cff999900<capture:1>|r will always be the full message that matched, even if you use no captures yourself. You can capture up to 14 things, going up to |cff999900<capture:15>|r. In lua scripts, you access them with |cff999900rs.capture[1]|r to |cff999900rs.capture[15]|r. An example:

The phrase pattern: |cff999900^(%a+) rolls (%d+) %(1%-100%)|r
The text that matched: |cff999900Mcduck rolls 51 (1-100)|r
<capture:1> = |cff999900Mcduck rolls 51 (1-100)|r
<capture:2> = |cff999900Mcduck|r
<capture:3> = |cff99990051|r
Example reply: |cff999900<capture:2> rolled a <capture:3> in front of my eyes!|r
Example script: |cff999900if tonumber(rs.capture[3]) > 50 then SendChatMessage("You rolled over 50!", "whisper", nil, rs.capture[2]) end|r

|cffffff00Miscellaneous things:|r
* Press Tab when editing a reaction message or tag phrase list to show a test message/phrase in the chat window.
* Very long messages will be automatically split up into multiple messages.
* A/An grammar problems caused by randomized text will be fixed automatically.
* Grammarians are split on this rule, but putting |cff999900's|r after a variable or tag name, like |cff999900<target_name's>|r or |cff999900<name:focus's>|r, adds ' if the last letter is S and 's if it's not.
* The Group channel will use the appropriate channel for battlegrounds, raids, and normal parties.
* To react to the death of a specific creature, use its name as a spell and "Your spell hit someone else" as the action.
* Certain AOE spells like Demoralizing Roar count as the action "Your spell hits yourself."
* Some mob DOTs, like Vashj's Static Shock, have each periodic hit act like a normal hit causing it to trigger every time the DOT causes damage. To make it react only once, you can use the "Limit once per aura" option, but this only works on you and your group and won't have a <target_name> variable.
* The submenu option on spells and tags allows you to organize them into categories in the dropdown menus. To use multiple levels, separate each submenu name with |cff999900>|r (or any punctuation/symbol), like: |cff999900Druid>Feral|r.
* When editing the text of a reaction, pressing ctrl-enter will add a new reaction and set the keyboard focus on it.
]]
