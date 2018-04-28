RSGUI = {}

----------------------------------------------------------------------------------------------------
-- dropdown menu frame
----------------------------------------------------------------------------------------------------
RSGUI.menu = CreateFrame("Frame", "RSGUI_menu", UIParent, "UIDropDownMenuTemplate")

-- open a menu table under a specific frame
function RSGUI.menu:Open(contents, frame)
	CloseDropDownMenus()
	self:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	EasyMenu(contents, self, frame, 0, 0, "MENU")
end

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
RSGUI.Utility = {}

-- clear focus from any input field
function RSGUI.Utility.ClearAnyFocus()
	if GetCurrentKeyBoardFocus() then GetCurrentKeyBoardFocus():ClearFocus() end
end

-- for showing tooltips
function RSGUI.Utility.WidgetTooltip_OnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(this.tooltipText, nil, nil, nil, nil, 1)
	GameTooltip:Show()
end
function RSGUI.Utility.WidgetTooltip_OnLeave()
	GameTooltip:Hide()
end

-- delete a menu item from a menu - if it was in a submenu that no longer has other items, delete that item too
function RSGUI.Utility.DeleteFromMenu(menu, name, submenu_text)
	CloseDropDownMenus()

	if submenu_text then
		-- separate each menu name in the text
		local submenu_list = {}
		for submenu_name in submenu_text:gmatch("[^%p]+") do
			table.insert(submenu_list, submenu_name)
		end

		-- find and save each submenu on the way to finding the submenu the item is in
		local submenu = {} -- {menu,index} for each submenu found, to be able to test if they're empty after the item is removed
		for i=1,#submenu_list do
			for menu_item=1,#menu do
				if menu[menu_item].text == submenu_list[i] and menu[menu_item].menuList then
					table.insert(submenu, {menu, menu_item})
					menu = menu[menu_item].menuList
					break
				end
			end
		end

		RSGUI.Utility.DeleteFromMenu(menu, name, nil) -- menu is now the submenu that contains the item - send it to be deleted

		-- go backwards from the submenus to check if each submenu menu item has any items in its menuList
		for i=#submenu,1,-1 do
			if next(submenu[i][1][submenu[i][2]].menuList) == nil then
				table.remove(submenu[i][1], submenu[i][2])
			end
		end
		return
	end

	-- no submenus to look through, so just delete it from the menu
	for i=1,#menu do
		if menu[i].text == name then
			table.remove(menu, i)
			return
		end
	end
end

--------------------------------------------------
-- create and return a menu item at the proper submenu and in alphabetical order
-- if it should go in a submenu, then submenu_text is a string in a format like: "Druid>Feral>"
--------------------------------------------------
function RSGUI.Utility.InsertIntoMenu(menu, name, submenu_text)
	if submenu_text then
		-- separate each menu name in the text
		local submenu_list = {}
		for submenu_name in submenu_text:gmatch("[^%p]+") do
			local found = false
			local insert_at = 1
			for menu_item=1,#menu do
				if menu[menu_item].text == submenu_name then
					found = true
					break
				end
				if menu[menu_item].text:lower() > submenu_name:lower() then
					break
				end
				insert_at = insert_at + 1
			end
			if not found then
				table.insert(menu, insert_at, {text=submenu_name, hasArrow=1, notClickable=1, notCheckable=1, menuList={}})
			end
			menu = menu[insert_at].menuList
		end
	end

	-- insert the item into the menu (or submenu) alphabetically
	local insert_at = 1
	for i=1,#menu do
		if menu[i].text:lower() > name:lower() then
			break
		end
		insert_at = insert_at + 1
	end
	table.insert(menu, insert_at, {text=name})
	return menu[insert_at]
end

-- fix chance input to only allow numbers (with up to one decimal point) and return the fixed number (or 0)
function RSGUI.Utility.FixChanceNumber(inputbox)
	local number = inputbox:GetText()
	if number == "" then
		return 0
	end
	-- only allow 1 decimal point
	local decimal_used = false
	local fixed = number:gsub("[^%d]", function(ch)
		if ch == "." and not decimal_used then
			decimal_used = true
			return ch
		end
		return ""
	end)
	if number ~= fixed then
		inputbox:SetText(fixed)
	end
	if fixed == "" or fixed == "." then
		return 0
	end
	return tonumber(fixed)
end

-- create a checkbox and fix the hit detection on it
function RSGUI.Utility.CreateCheckbox(name, parent, text, tooltip)
	local frame = CreateFrame("CheckButton", "RSGUI_Checkbutton_"..name, parent, "OptionsCheckButtonTemplate")
	_G[frame:GetName().."Text"]:SetText(text)
	local width = _G[frame:GetName().."Text"]:GetStringWidth()
	if width > 150 then
		width = 150
	end
	frame:SetHitRectInsets(0, -width, 4, 4)
	if tooltip then
		frame.tooltipText = tooltip
	end
	return frame
end

-- create a button and move the text up a tiny bit
function RSGUI.Utility.CreateButton(name, parent, width, text)
	local button = CreateFrame("Button", "RSGUI_Button_"..name, parent, "UIPanelButtonTemplate2")
	button:SetWidth(width)
	button:SetHeight(23)
	-- set the text and move it up a little
	local fontString = _G[button:GetName().."Text"]
	fontString:SetText(text)
	fontString:ClearAllPoints()
	fontString:SetPoint("BOTTOM", fontString:GetParent(), "BOTTOM", 0, 6)
	return button
end
