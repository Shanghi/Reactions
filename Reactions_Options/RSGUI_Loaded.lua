local gui

function RSGUI:GetGUI(settings)
	if not gui then
		gui = RSGUI.main.new(settings)
		RSGUI.chat.new(gui)
		RSGUI.options.new(gui)
		RSGUI.reactions.new(gui)
		RSGUI.search.new(gui)
		RSGUI.tags.new(gui)

		gui:HideContentExcept(nil)
		gui.frame:Hide()
	end
	return gui
end
