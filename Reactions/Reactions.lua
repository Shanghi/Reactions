--[[
	Ideas:
		* low health/mana events for other people - can't decide on a good way to remove people/mobs
		  that are no longer nearby/relevant, and also have to be careful about performance.
		* wearing/changing/removing equipment events - would add a time check to the OnUpdate script
		  that I'd rather avoid if possible. It would also need a way to only trigger on certain items
		  or would probably be a waste to have!
		* Be able to expand the custom lua edit boxes on chat trigger settings, and maybe set them to
		  use a fixed-width font.
		* Figure out a good way to reload menus including submenus in TBC so the conditions menu can
		  be updated instantly.

	Technical notes:
		* When both actions exist, "Group member dodges/resists" is used instead of "Non-grouped person's spell misses/is resisted"
		* For channeling start/stop actions, <spell_link> only works if the spell is in the player's spellbook because no ID is known.

		ReactionsSave:
			["enabled"]          - bool   - if automatic reactions are enabled
			["testing"]          - bool   - if messages will be printed instead of said/executed
			["globalCooldown"]   - number - wait this many seconds before using another reaction
			["messageCooldown"]  - number - individual message cooldown - avoid picking it again for this long unless impossible
			["chanceMultiplier"] - number - multiply the chance of reactions happening by this much
			["quietStealth"]     - bool   - if true, don't speak when stealthed and out in the world or a battleground
			["shoutMode"]        - bool   - if messages are converted to uppercase before using
			["roleItems"]        - table  - {[index] = {name, ID, texture, slot1, slot2}}
			["fightLength"]      - number - how long in seconds a fight must last to count as one
			["groupCounter"]     - number - counter for groups you join
			["fightCounter"]     - number - counter for fights started - only counts if they last at least 5 seconds
			["reactionList"]     - table  - {[name]=value,...} list of reactions - explained more below
			["groupList"]        - table  - {[name]=enabled,...} list of action groups and if they're enabled
			["tagList"]          - table  - {[name]={text="a|b|c",submenu=""}, ...} list of tags and their text
			["chatList"]         - table  - ReactionsSave.chatList["trigger"] = {[trigger name] = {settings}, ...}
			                                ReactionsSave.chatList["channel"] = {[channel name] = {"Trigger Name 1", "Trigger 2", ...}}

		ReactionsSave.reactionList["Spell"] =
			["Spell"].event      - bool/nil   - true if it's a special event instead of a spell
			["Spell"].submenu    - string/nil - Where it goes on the gui menu, like: "Druid>Feral>"
			["Spell"].nickname   - string/nil - How it's shown on the menu (so you can name IDs with something recognizable)
			["Spell"].<action>   - table      - hit/hit_by/miss/etc - table values explained below

		ReactionsSave.reactionList["Spell"]["<action>"] =
			["<action>"].group             - string/nil - the name of the group it's in
			["<action>"].chance            - number     - chance of reacting when it happens
			["<action>"].cooldown          - number/nil - overwrite global cooldown
			["<action>"].limitAura         - bool/nil   - only use it once until its aura is gone
			["<action>"].limitGroup        - bool/nil   - only use it once per group you're in
			["<action>"].limitFights       - bool/nil   - only use it once per limitFightsAmount of fights
			["<action>"].limitFightsAmount - number/nil - if limitFights is set, then how many fights must pass before able to use the reaction again
			["<action>"].limitName         - bool/nil   - only use it once on each target name per fight
			["<action>"].usedOnGroupNumber - number/nil - the ReactionsSave["groupCounter"] the reaction was used on if limitGroup is enabled
			["<action>"].usedOnFightNumber - number/nil - the ReactionsSave["fightCounter"] the reaction was used on if limitFights is enabled
			["<action>"].usedNames[onFight] = {[name]=1,[name]=1,...} - the names already used during this fight - table deleted/remade each new use to get rid of old names
			["<action>"].lastReactionTime  - number/nil - time() of last time the reaction was successful
			["<action>"].lastChosen        - number/nil - last reaction index number chosen
			["<action>"].<reactions>       - table      - {{table explained below}, ...}

		ReactionsSave.reactionList["Spell"]["action"][<reaction>] =
			[1] = channel
			[2] = action or message text
			[3] = last used time
			[4] = language to use (can be nil): nil or 1=common, 2=racial, 3=random
			[5] = form/stance condition (con be nil): which form you must be in to be able to use the reaction (formButtonMenu in gui file for list)
			[6] = table of various conditions (can be nil): to save memory, if an item exists in the table then the reaction is NOT used if that condition is true (conditionsButtonMenu in gui file for list)
			[7] = role item: nil or 1 to 10 - for ReactionsSave.roleItems[number]
--]]

local MINOR_VERSION = 24.1 -- minor version number - major is always 1

ReactionsSave = nil -- saved settings - defaults set up during ADDON_LOADED event

-- local references to some functions and settings
	-- wow
local time                   = time
local GetTime                = GetTime
local IsFalling              = IsFalling
local IsSwimming             = IsSwimming
local IsFlying               = IsFlying
local UnitName               = UnitName
local UnitIsFriend           = UnitIsFriend
local UnitInParty            = UnitInParty
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local UnitInRaid             = UnitInRaid
local UnitPlayerOrPetInRaid  = UnitPlayerOrPetInRaid
local UnitAffectingCombat    = UnitAffectingCombat
	-- lua
local lower   = string.lower
local upper   = string.upper
local gsub    = string.gsub
local find    = string.find
local sub     = string.sub
local rep     = string.rep
local match   = string.match
local gmatch  = string.gmatch
local tinsert = table.insert
local tremove = table.remove
local tconcat = table.concat
	-- settings
local mainSettings            = nil
local groupList               = nil
local tagList                 = nil
local reactionList            = nil
local chatList                = nil
local actionTriggerList       = nil
local battlegroundTriggerList = nil
local channelTriggerList      = nil
local emoteTriggerList        = nil
local errorTriggerList        = nil
local guildTriggerList        = nil
local lootTriggerList         = nil
local officerTriggerList      = nil
local partyTriggerList        = nil
local raidTriggerList         = nil
local sayTriggerList          = nil
local systemTriggerList       = nil
local tradeskillTriggerList   = nil
local whisperTriggerList      = nil
local yellTriggerList         = nil

-- miscellaneous information
local trackedAuras      = {}  -- table of tracked "limitAura" auras for group members and yourself
local lastReactionTime  = 0   -- the last time() a reaction was successfully used
local lastFightStart    = nil -- the GetTime() the last fight started, to make sure it's long enough to count
local inGroup           = nil -- if the player is in a group
local hasFullyLoggedIn  = nil -- if the player has logged in enough for all required information to be known by the client
local playerClass       = select(2, UnitClass("player")) -- used for checking shaman and priest forms
local nextAutomaticTime = 999 -- time left before the next Automatic event triggers - real time set in ADDON_LOADED
local eventData         = {}  -- data used in parsing events and checking some conditions
-- names and information used by reaction variables
local messagePlayerName        = UnitName("player")
local messageCasterName        = nil
local messageTargetName        = nil
local messageExtraTargetName   = nil
local messageMemberName        = nil
local currentSpellName         = nil
local currentSpellId           = nil
local currentExtraSpellName    = nil      -- for actions with 2 spells, like "Kick" interrupting "Heal"
local currentExtraSpellId      = nil      -- for actions with 2 spells, like "Kick" interrupting "Heal"
local currentChatMessage       = nil
local currentChatChannel       = nil
local currentChatChannelNumber = nil      -- the number of a numbered channel chat type, like 1 for General Chat
local eventDirection           = "nearby" -- a direction description for things like minimap pings

-- global table to use in chat trigger custom lua scripts - probably better than setfenv or the annoyance of having to get values from ...
rs = {} -- not a very good name for a global, but something short is wanted and it doesn't seem to be used by anything popular
rs.capture = {}
local customLuaTable = rs
local customLuaCapture = customLuaTable.capture

-- forward declaration
local AttemptReaction

-- table of bosses that aren't actually classified as bosses - used in conditions and events
local bossList = {
	-- Auchindoun: Auchenai Crypts
	["Shirrak the Dead Watcher"]=1,
	["Exarch Maladaar"]=1,
	["Avatar of the Martyred"]=1,
	-- Auchindoun: Mana Tombs
	["Pandemonius"]=1,
	["Tavarok"]=1,
	["Nexus-Prince Shaffar"]=1,
	-- Auchindoun: Sethekk Halls
	["Darkweaver Syth"]=1,
	["Talon King Ikiss"]=1,
	-- Auchindoun: Shadow Labyrinth
	["Ambassador Hellmaw"]=1,
	["Blackheart the Inciter"]=1,
	["Grandmaster Vorpil"]=1,
	["Murmur"]=1,
	-- Caverns of Time: Old Hillsbrad Foothills
	["Lieutenant Drake"]=1,
	["Captain Skarloc"]=1,
	["Epoch Hunter"]=1,
	-- Caverns of Time: The Black Morass
	["Chrono Lord Deja"]=1,
	["Temporus"]=1,
	["Aeonus"]=1,
	-- Coilfang Reservoir: The Slave Pens
	["Ahune"]=1,
	["Mennu the Betrayer"]=1,
	["Rokmar the Crackler"]=1,
	["Quagmirran"]=1,
	-- Coilfang Reservoir: The Steamvault
	["Hydromancer Thespia"]=1,
	["Mekgineer Steamrigger"]=1,
	["Warlord Kalithresh"]=1,
	-- Coilfang Reservoir: The Underbog
	["Hungarfen"]=1,
	["Ghaz'an"]=1,
	["Swamplord Musel'ek"]=1,
	["The Black Stalker"]=1,
	-- Hellfire Citadel: Hellfire Ramparts
	["Watchkeeper Gargolmar"]=1,
	["Omor the Unscarred"]=1,
	["Vazruden"]=1,
	-- Hellfire Citadel: The Blood Furnace
	["The Maker"]=1,
	["Broggok"]=1,
	["Keli'dan the Breaker"]=1,
	-- Hellfire Citadel: The Shattered Halls
	["Grand Warlock Nethekurse"]=1,
	["Blood Guard Porung"]=1,
	["Warbringer O'mrogg"]=1,
	["Warchief Kargath Bladefist"]=1,
	-- Magisters' Terrace
	["Selin Fireheart"]=1,
	["Vexallus"]=1,
	["Priestess Delrissa"]=1,
	["Kael'thas Sunstrider"]=1,
	-- Tempest Keep: The Arcatraz
	["Zereketh the Unbound"]=1,
	["Dalliah the Doomsayer"]=1,
	["Wrath-Scryer Soccothrates"]=1,
	["Harbinger Skyriss"]=1,
	-- Tempest Keep: The Botanica
	["Commander Sarannis"]=1,
	["High Botanist Freywinn"]=1,
	["Thorngrin the Tender"]=1,
	["Laj"]=1,
	["Warp Splinter"]=1,
	-- Tempest Keep: The Mechanar
	["Mechano-Lord Capacitus"]=1,
	["Nethermancer Sepethrea"]=1,
	["Pathaleon the Calculator"]=1,
}

-- types of conditions used to check if certain conditions actually need to be checked
local CONDITION_TYPE_MISCELLANEOUS = 10001
local CONDITION_TYPE_COMBAT        = 10002
local CONDITION_TYPE_PARTY         = 10003
local CONDITION_TYPE_PLACE         = 10004
local CONDITION_TYPE_PLAYER        = 10005
local CONDITION_TYPE_GROUP_MEMBER  = 10006
local CONDITION_TYPE_CASTER        = 10007
local CONDITION_TYPE_TARGET        = 10008
local CONDITION_TYPE_AFFECTED      = 10009

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- find a spell/event in the reaction list - first by its name and then by its ID if it wasn't found
local function GetSpellSettings(spellName, spellId)
	return (spellId and reactionList[spellId]) or (spellName and reactionList[spellName]) or nil
end

-- set the time left until the next automatic event happens
local function SetNextAutomaticTime()
	nextAutomaticTime = random(mainSettings.automaticMinimum*60, mainSettings.automaticMaximum*60)
end

-- try to find a unitid based on a name
local function FindUnitID(name)
	return    (UnitExists(name) and name)
			 or (UnitName("target")    == name and "target")
			 or (UnitName("mouseover") == name and "mouseover")
			 or (UnitName("focus")     == name and "focus")
			 or (messageMemberName and UnitName(messageMemberName.."-target") == name and (messageMemberName.."-target"))
			 or (UnitExists("pet") and UnitName("pettarget") == name and "pettarget")
			 or nil
end

-- return true if target has an aura
local function HasAura(target, auraName)
	local found = false
	local name
	for i=1,40 do
		name = UnitDebuff(target, i)
		if not name then
			break
		elseif name == auraName then
			return true
		end
	end
	for i=1,40 do
		name = UnitBuff(target, i)
		if not name then
			break
		elseif name == auraName then
			return true
		end
	end
end

-- return the name of a random party member
local function RandomPartyMember(excludePlayer)
	if GetNumPartyMembers() > 0 then
		local chosen = random(1, GetNumPartyMembers() + (excludePlayer and 0 or 1))
		if chosen == GetNumPartyMembers() + 1 then
			return messagePlayerName
		end
		return UnitName("party"..chosen)
	end
	return nil
end

-- return the name of a random raid member
local function RandomRaidMember(excludePlayer)
	if GetNumRaidMembers() > 0 then
		local chosen = random(1, GetNumRaidMembers() - (excludePlayer and 1 or 0))
		local name
		for i=1,40 do
			name = (GetRaidRosterInfo(i))
			if name and (not excludePlayer or name ~= messagePlayerName) then
				chosen = chosen - 1
				if  chosen == 0 then
					return name
				end
			end
		end
	end
	return nil
end

-- return the name of a random online guild member
local function RandomGuildMember(excludePlayer)
	if IsInGuild() then
		local list = {}
		for i=1,GetNumGuildMembers() do
			local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
			if online and (not excludePlayer or name ~= messagePlayerName) then
				tinsert(list, name)
			end
		end
		return #list > 0 and list[random(1, #list)] or nil
	end
	return nil
end

-- Word wrapping - barely modified version from http://rosettacode.org/wiki/Word_wrap#Lua
local function SplitTokens(text)
	local res = {}
	for word in gmatch(text, "%S+") do
		res[#res+1] = word
	end
	return res
end

local function WordWrap(text, linewidth)
	if not linewidth then
		linewidth = 250
	end

	-- replace all spaces in text inside [ ] with a character no item/spell/quest uses
	local changedLink = false
	text = gsub(text, "(%[.-%])", function(link) changedLink = true; return gsub(link, " ", "@") end)

	local spaceleft = linewidth
	local res = {}
	local line = {}
	for _, word in ipairs(SplitTokens(text)) do
		if #word + 1 > spaceleft then
			tinsert(res, tconcat(line, ' '))
			line = {word}
			spaceleft = linewidth - #word
		else
			tinsert(line, word)
			spaceleft = spaceleft - (#word + 1)
		end
	end
	tinsert(res, tconcat(line, ' '))

	-- convert links back to using spaces
	if changedLink then
		for i=1,#res do
			res[i] = gsub(res[i], "(%[.-%])", function(link) return gsub(link, "@", " ") end)
		end
	end
	return res
end

-- return the lowest durability percent found from all equipped items
local function GetLowestEquipmentDurability()
	local current, maximum, percent, lowest
	for i=1,18 do
		current, maximum = GetInventoryItemDurability(i)
		if current then
			percent = current / maximum * 100
			if not lowest or percent < lowest then
				lowest = percent
			end
		end
	end
	return lowest
end

-- add a ' or 's to the end of a name
local function ApostropheName(name)
	return name and (name..(name:sub(-1) == "s" and "'" or "'s")) or ""
end

----------------------------------------------------------------------------------------------------
-- event and message variables
----------------------------------------------------------------------------------------------------
-- actions that describe what the spell/event is
local ActionType = {
	HIT          = 1,
	MISS         = 2,
	START_CAST   = 3,
	PERIODIC     = 4,
	CHANNEL_STOP = 5,
	AURA_GAINED  = 6,
	AURA_REMOVED = 7,
	EVENT_AURA   = 8,
}

-- list of special cases for when deciding to use "a" or "an" - ListA will be checked first, then
-- listAn, then if neither match it's assumed "a" is the right choice
local ArticleListA = {
	"^on[c]?e.*",
	"^unicorn.*",
	"^union.*",
	"^unit.*",
	"^univ.*",
	"^us[a]?$",
	"^use.*",
	"^util.*",
	"^euro.*",
	"^utopi.*",
	"^herbi.*", -- so the herb* in "an" doesn't match herbivore
	"^us[a]?$",
	"^u[k]?$",
	"^ufo$",
}
local ArticleListAn = {
	"^[aeiou].*",
	"^heir.*",
	"^herb.*",     -- Europeans may need to remove this one
 --"^historic.*", -- you can uncomment this if you're an old person
	"^honest.*",
	"^hono[u]?r.*",
	"^hour.*",
	"^8.*",
	"^1[18]$",
	"^mvp$",
	"^[fhlmnrsx]$", -- single letters, like "Pierre gets an F for that attack"
}

--------------------------------------------------
-- functions used by multiple variables
--------------------------------------------------
local function VariableRace(unitid)
	if not unitid or unitid == "" then
		return "sturdy being"
	elseif UnitIsPlayer(unitid) then
		return lower(UnitRace(unitid))
	else
		local creatureType = UnitCreatureType(unitid)
		return (creatureType and creatureType ~= "Not specified" and lower(creatureType)) or "mysterious being"
	end
end

local function VariableClass(unitid)
	if not unitid or unitid == "" then
		return "champion for their cause"
	elseif UnitIsPlayer(unitid) then
		return lower(UnitClass(unitid))
	else
		local classification = lower(UnitClassification(unitid) or "normal")
		if classification == "worldboss" then
			return "boss"
		elseif classification == "rareelite" then
			return "rare-elite"
		elseif classification == "normal" or classification == "trivial" then
			return classification .. " being"
		else
			return classification
		end
	end
end

local function VariableGuild(unitid)
	local guild = unitid and GetGuildInfo(unitid)
	return guild or "The Organization"
end

local function VariableHeShe(unitid)
	local gender = unitid and UnitSex(unitid)
	return (gender==2 and "he") or (gender==3 and "she") or "it"
end
local function VariableHimHer(unitid)
	local gender = unitid and UnitSex(unitid)
	return (gender==2 and "him") or (gender==3 and "her") or "it"
end
local function VariableHisHer(unitid)
	local gender = unitid and UnitSex(unitid)
	return (gender==2 and "his") or (gender==3 and "her") or "their"
end
local function VariableGender(unitid, pattern)
	local male, female, other = match(pattern, "(.-):(.-):(.+)")
	local gender = unitid and UnitSex(unitid)
	return (gender==2 and (male or "male")) or (gender==3 and (female or "female")) or other or "thing"
end

-- list of variables and functions to do the replacements
local variableNormalList = {
	-- player section
	["player_name"]  = function() return messagePlayerName end,
	["player_name_title"] = function()
		local id = GetCurrentTitle() or 0
		if id == 0 then
			return messagePlayerName
		elseif id == 36 or id == 38 or id == 39 then -- titles that use suffix instead of prefix
			return messagePlayerName .. (id == 38 and " " or ", ") .. GetTitleName(id)
		else
			return GetTitleName(id) .. " " .. messagePlayerName
		end
	end,
	["player_race"]       = function() return lower(UnitRace("player")) end,
	["player_class"]      = function() return lower(UnitClass("player")) end,
	["player_guild"]      = function() return GetGuildInfo("player") end,
	["player_title"]      = function() local id = GetCurrentTitle(); return id and GetTitleName(id) or "champion" end,
	["player_hearth"]     = function() return GetBindLocation() or "Parts Unknown" end,
	["player_home"]       = function() return GetBindLocation() or "Parts Unknown" end,
	["player_gold"]       = function() return math.floor(GetMoney() / 10000) end,
	["player_money_text"] = function() return GetCoinText(GetMoney()) end,
	["pet_name"]          = function() return UnitName("pet") or "my good pet" end,
	-- event targets section
	["target_name"]    = function() return messageTargetName or "secret target" end,
	["target_race"]    = function() return VariableRace(FindUnitID(messageTargetName)) end,
	["target_class"]   = function() return VariableClass(FindUnitID(messageTargetName)) end,
	["target_guild"]   = function() return VariableGuild(FindUnitID(messageTargetName)) end,
	["target_he_she"]  = function() return VariableHeShe(FindUnitID(messageTargetName)) end,
	["target_him_her"] = function() return VariableHimHer(FindUnitID(messageTargetName)) end,
	["target_his_her"] = function() return VariableHisHer(FindUnitID(messageTargetName)) end,
	["target_gender"]  = function(pattern) return VariableGender(FindUnitID(messageTargetName), pattern) end,

	["extra_target_name"]    = function() return messageExtraTargetName or "someone who probably deserves it" end,
	["extra_target_race"]    = function() return VariableRace(FindUnitID(messageExtraTargetName)) end,
	["extra_target_class"]   = function() return VariableClass(FindUnitID(messageExtraTargetName)) end,
	["extra_target_guild"]   = function() return VariableGuild(FindUnitID(messageExtraTargetName)) end,
	["extra_target_he_she"]  = function() return VariableHeShe(FindUnitID(messageExtraTargetName)) end,
	["extra_target_him_her"] = function() return VariableHimHer(FindUnitID(messageExtraTargetName)) end,
	["extra_target_his_her"] = function() return VariableHisHer(FindUnitID(messageExtraTargetName)) end,
	["extra_target_gender"]  = function(pattern) return VariableGender(FindUnitID(messageExtraTargetName), pattern) end,

	["group_name"]    = function() return messageMemberName or "friendly teammate" end,
	["group_race"]    = function() return VariableRace(FindUnitID(messageMemberName)) end,
	["group_class"]   = function() return VariableClass(FindUnitID(messageMemberName)) end,
	["group_guild"]   = function() return VariableGuild(FindUnitID(messageMemberName)) end,
	["group_he_she"]  = function() return VariableHeShe(FindUnitID(messageMemberName)) end,
	["group_him_her"] = function() return VariableHimHer(FindUnitID(messageMemberName)) end,
	["group_his_her"] = function() return VariableHisHer(FindUnitID(messageMemberName)) end,
	["group_gender"]  = function(pattern) return VariableGender(FindUnitID(messageMemberName), pattern) end,

	-- event info section
	["spell_link"]        = function() return (currentSpellId and GetSpellLink(currentSpellId)) or (currentSpellName and GetSpellLink(currentSpellName)) or GetSpellLink(39477) end, -- 39477 = "Bad Luck"
	["spell_name"]        = function() return currentSpellName or "Bad Luck Aura" end,
	["spell_rank"]        = function(spell) -- name or ID
		spell = spell ~= "" and spell or currentSpellId
		local rank = spell and (select(2, GetSpellInfo(spell)))
		return rank and rank ~= "" and rank:lower() or "unrankable rank"
	end,
	["extra_spell_link"]  = function() return (currentExtraSpellId and GetSpellLink(currentExtraSpellId)) or (currentExtraSpellName and GetSpellLink(currentExtraSpellName)) or GetSpellLink(39477) end, -- 39477 = "Bad Luck"
	["extra_spell_name"]  = function() return currentExtraSpellName or "Bad Luck Aura" end,
	["extra_spell_rank"]  = function() return tonumber(currentExtraSpellId) and (select(2, GetSpellInfo(currentExtraSpellId))):lower() or "unrankable rank" end,
	["spell_name_after"]  = function(prefix) return (currentSpellName and currentSpellName:match(prefix.."(.+)") or currentSpellName) or "Bad Luck Aura" end,

	-- macro-style targets
	["name"]    = function(unitid)  return UnitName(unitid or "none") or "mystery person" end,
	["race"]    = function(unitid)  return VariableRace(unitid) end,
	["class"]   = function(unitid)  return VariableClass(unitid) end,
	["guild"]   = function(Unitid)  return VariableGuild(unitid) end,
	["he_she"]  = function(unitid)  return VariableHeShe(unitid) end,
	["him_her"] = function(unitid)  return VariableHimHer(unitid) end,
	["his_her"] = function(unitid)  return VariableHisHer(unitid) end,
	["gender"]  = function(pattern) return VariableGender(unitid, pattern) end,

	-- equipment
	["eq_head_link"]     = function() return GetInventoryItemLink("player",  1) or "invisible helmet"          end,
	["eq_neck_link"]     = function() return GetInventoryItemLink("player",  2) or "invisible necklace"        end,
	["eq_shoulder_link"] = function() return GetInventoryItemLink("player",  3) or "invisible shoulderpads"    end,
	["eq_back_link"]     = function() return GetInventoryItemLink("player", 15) or "invisible cape"            end,
	["eq_chest_link"]    = function() return GetInventoryItemLink("player",  5) or "invisible chestpiece"      end,
	["eq_shirt_link"]    = function() return GetInventoryItemLink("player",  4) or "invisible shirt"           end,
	["eq_tabard_link"]   = function() return GetInventoryItemLink("player", 19) or "invisible tabard"          end,
	["eq_wrist_link"]    = function() return GetInventoryItemLink("player",  9) or "invisible wristbands"      end,
	["eq_hands_link"]    = function() return GetInventoryItemLink("player", 10) or "invisible gloves"          end,
	["eq_waist_link"]    = function() return GetInventoryItemLink("player",  6) or "invisible belt"            end,
	["eq_legs_link"]     = function() return GetInventoryItemLink("player",  7) or "invisible pants"           end,
	["eq_feet_link"]     = function() return GetInventoryItemLink("player",  8) or "invisible boots"           end,
	["eq_finger1_link"]  = function() return GetInventoryItemLink("player", 11) or "invisible ring"            end,
	["eq_finger2_link"]  = function() return GetInventoryItemLink("player", 12) or "invisible ring"            end,
	["eq_trinket1_link"] = function() return GetInventoryItemLink("player", 13) or "invisible trinket"         end,
	["eq_trinket2_link"] = function() return GetInventoryItemLink("player", 14) or "invisible trinket"         end,
	["eq_mainhand_link"] = function() return GetInventoryItemLink("player", 16) or "invisible weapon"          end,
	["eq_offhand_link"]  = function() return GetInventoryItemLink("player", 17) or "invisible handheld object" end,
	["eq_ranged_link"]   = function() return GetInventoryItemLink("player", 18) or "invisible weapon or relic" end,
	["eq_ammo_link"]     = function() return GetInventoryItemLink("player",  0) or "invisible ammo"            end,
	["eq_head_name"]     = function() local link = GetInventoryItemLink("player",  1) return link and link:match("%[(.-)]") or "invisible helmet"          end,
	["eq_neck_name"]     = function() local link = GetInventoryItemLink("player",  2) return link and link:match("%[(.-)]") or "invisible necklace"        end,
	["eq_shoulder_name"] = function() local link = GetInventoryItemLink("player",  3) return link and link:match("%[(.-)]") or "invisible shoulderpads"    end,
	["eq_back_name"]     = function() local link = GetInventoryItemLink("player", 15) return link and link:match("%[(.-)]") or "invisible cape"            end,
	["eq_chest_name"]    = function() local link = GetInventoryItemLink("player",  5) return link and link:match("%[(.-)]") or "invisible chestpiece"      end,
	["eq_shirt_name"]    = function() local link = GetInventoryItemLink("player",  4) return link and link:match("%[(.-)]") or "invisible shirt"           end,
	["eq_tabard_name"]   = function() local link = GetInventoryItemLink("player", 19) return link and link:match("%[(.-)]") or "invisible tabard"          end,
	["eq_wrist_name"]    = function() local link = GetInventoryItemLink("player",  9) return link and link:match("%[(.-)]") or "invisible wristbands"      end,
	["eq_hands_name"]    = function() local link = GetInventoryItemLink("player", 10) return link and link:match("%[(.-)]") or "invisible gloves"          end,
	["eq_waist_name"]    = function() local link = GetInventoryItemLink("player",  6) return link and link:match("%[(.-)]") or "invisible belt"            end,
	["eq_legs_name"]     = function() local link = GetInventoryItemLink("player",  7) return link and link:match("%[(.-)]") or "invisible pants"           end,
	["eq_feet_name"]     = function() local link = GetInventoryItemLink("player",  8) return link and link:match("%[(.-)]") or "invisible boots"           end,
	["eq_finger1_name"]  = function() local link = GetInventoryItemLink("player", 11) return link and link:match("%[(.-)]") or "invisible ring"            end,
	["eq_finger2_name"]  = function() local link = GetInventoryItemLink("player", 12) return link and link:match("%[(.-)]") or "invisible ring"            end,
	["eq_trinket1_name"] = function() local link = GetInventoryItemLink("player", 13) return link and link:match("%[(.-)]") or "invisible trinket"         end,
	["eq_trinket2_name"] = function() local link = GetInventoryItemLink("player", 14) return link and link:match("%[(.-)]") or "invisible trinket"         end,
	["eq_mainhand_name"] = function() local link = GetInventoryItemLink("player", 16) return link and link:match("%[(.-)]") or "invisible weapon"          end,
	["eq_offhand_name"]  = function() local link = GetInventoryItemLink("player", 17) return link and link:match("%[(.-)]") or "invisible handheld object" end,
	["eq_ranged_name"]   = function() local link = GetInventoryItemLink("player", 18) return link and link:match("%[(.-)]") or "invisible weapon or relic" end,
	["eq_ammo_name"]     = function() local link = GetInventoryItemLink("player",  0) return link and link:match("%[(.-)]") or "invisible ammo"            end,

	-- random section
	["number"] = function(text)
		local low, high = match(text, "%s*([%-%d]+)%s*([%-%d]*)")
		low, high = tonumber(low), tonumber(high)
		if not low then
			return random(1, 100)
		elseif not high then
			low, high = 1, low
		end
		if low > high then
			low, high = high, low
		end
		return random(low, high)
	end,
	["random_target_icon"]    = function() return "{rt" .. math.random(1, 8) .. "}" end,
	["random_guild_member"]   = function() return RandomGuildMember(true) or "my imaginary friend" end,
	["random_party_member"]   = function() return RandomPartyMember(true) or "my imaginary friend" end,
	["random_group_member"]   = function()
		local name
		if GetNumRaidMembers() > 0 then
			name = RandomRaidMember(true)
		else
			name = RandomPartyMember(true)
		end
		return name or "my imaginary friend"
	end,
	["random_roll"] = function() return random(1, 100) end,
	["random_tutorial_message"] = function() return _G["TUTORIAL"..random(1,51)]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r",""):gsub("\n", " ") end,
	-- miscellaneous
	["make_spell_link"] = function(id) return tonumber(id) and GetSpellLink(id) or GetSpellLink(39477) end, -- 39477 = "Bad Luck"
	["zone"]      = function() local zone = GetRealZoneText() return zone ~= "" and zone or "The Land Down Under" end,
	["subzone"]   = function() local subzone = GetSubZoneText() return subzone ~= "" and subzone or "Parts Unknown" end,
	["zone_full"] = function()
		local zone = GetRealZoneText()
		local subzone = GetSubZoneText()
		if not zone or zone == "" then
			return "The Land Down Under"
		elseif not subzone or subzone == "" or subzone == zone then
			return zone
		else
			return subzone .. " in " .. zone
		end
	end,
	["coords"]       = function() local x,y = GetPlayerMapPosition("player"); if x==0.0 and y==0.0 then return "a secret location" end return string.format("%.0f, %.0f", x*100, y*100) end,
	["coords_exact"] = function() local x,y = GetPlayerMapPosition("player"); if x==0.0 and y==0.0 then return "a secret location" end return string.format("%.1f, %.1f", x*100, y*100) end,
	["summon_last_zone"] = function() return GetSummonConfirmAreaName() or "Twisting Nether" end,
	["summon_time_left"] = function() return GetSummonConfirmTimeLeft() or 0 end,
	["direction"]        = function() return eventDirection end,
	["game_time_simple"] = function()
		local hour = GetGameTime()
		if     hour < 5  then return "early morning"
		elseif hour < 12 then return "morning"
		elseif hour < 17 then return "afternoon"
		else                  return "evening"
		end
	end,
	["real_time_simple"] = function()
		local hour = date("*t").hour
		if     hour < 5  then return "early morning"
		elseif hour < 12 then return "morning"
		elseif hour < 17 then return "afternoon"
		else                  return "evening"
		end
	end,
	["game_time_general"] = function()
		local hour = GetGameTime()
		if     hour < 5 or hour >= 21 then return "night"
		elseif hour < 12              then return "morning"
		elseif hour < 17              then return "afternoon"
		else                               return "evening"
		end
	end,
	["real_time_general"] = function()
		local hour = date("*t").hour
		if     hour < 5 or hour >= 21 then return "night"
		elseif hour < 12              then return "morning"
		elseif hour < 17              then return "afternoon"
		else                               return "evening"
		end
	end,
	["game_time_description"] = function()
		local hour, minute = GetGameTime()
		if     (hour == 0 and minute < 15) or (hour == 23 and minute >= 45) then return "around midnight"
		elseif hour < 5                  then return "late at night"
		elseif hour < 7                  then return "early in the morning"
		elseif hour < 12 and minute < 45 then return "in the morning"
		elseif hour < 13 and minute < 15 then return "around noon"
		elseif hour < 16                 then return "in the afternoon"
		elseif hour < 17                 then return "in the late afternoon"
		elseif hour < 20                 then return "in the evening"
		elseif hour < 21                 then return "late in the evening"
		else                                  return "at night"
		end
	end,
	["real_time_description"] = function()
		local currentTime = date("*t")
		local hour = currentTime.hour
		local minute = currentTime.min
		if     (hour == 0 and minute < 15) or (hour == 23 and minute >= 45) then return "around midnight"
		elseif hour < 5                  then return "late at night"
		elseif hour < 7                  then return "early in the morning"
		elseif hour < 12 and minute < 45 then return "in the morning"
		elseif hour < 13 and minute < 15 then return "around noon"
		elseif hour < 16                 then return "in the afternoon"
		elseif hour < 17                 then return "in the late afternoon"
		elseif hour < 20                 then return "in the evening"
		elseif hour < 21                 then return "late in the evening"
		else                                  return "at night"
		end
	end,
	-- chat
	["channel"] = function() return currentChatChannel or "tunnel of puzzles" end,
	["message"] = function() return currentChatMessage or "an alphabet in another language" end,
	["channel_number"] = function() return currentChatChannelNumber or "0" end,
	["capture"] = function(index) return customLuaCapture[tonumber(index) or "none"] or "Unknown" end,
}

if SS_Data then
	variableNormalList["random_item"]   = function() return SS_Data.GetRandomItem() end
	variableNormalList["random_quest"]  = function() return SS_Data.GetRandomQuest() end
	variableNormalList["random_npc"]    = function() return SS_Data.GetRandomNPC() end
	variableNormalList["random_spell"]  = function() return SS_Data.GetRandomSpell() end
	variableNormalList["random_pspell"] = function(class) return SS_Data.GetRandomPlayerSpell(class) end
	variableNormalList["random_craft"]  = function(profession) return SS_Data.GetRandomCraft(profession) or "handiwork craftsmanship" end

	variableNormalList["random_talent"]     = function(class) return SS_Data.GetRandomTalent(class)       or "magical maneuver" end
	variableNormalList["random_talent_min"] = function(class) return SS_Data.GetRandomTalent(class, 0, 0) or "magical maneuver" end
	variableNormalList["random_talent_max"] = function(class) return SS_Data.GetRandomTalent(class, 5, 5) or "magical maneuver" end

	variableNormalList["random_faction"]          = function() return SS_Data.GetRandomFaction(true, true, true)   or "no one" end
	variableNormalList["random_alliance_faction"] = function() return SS_Data.GetRandomFaction(false, true, false) or "no one" end
	variableNormalList["random_horde_faction"]    = function() return SS_Data.GetRandomFaction(false, false, true) or "no one" end
	variableNormalList["random_neutral_faction"]  = function() return SS_Data.GetRandomFaction(true, false, false) or "no one" end

	variableNormalList["random_zone"]                   = function() return SS_Data.GetRandomZone(true,  true,  true,  false) or "Parts Unknown" end
	variableNormalList["random_subzone"]                = function() return SS_Data.GetRandomSubzone(true, true, true)        or "Parts Unknown" end
	variableNormalList["random_full_zone"]              = function() return SS_Data.GetRandomZone(true,  true,  true,  true)  or "Parts Unknown" end
	variableNormalList["random_instance_zone"]          = function() return SS_Data.GetRandomZone(false, false, true,  false) or "Parts Unknown" end
	variableNormalList["random_instance_full_zone"]     = function() return SS_Data.GetRandomZone(false, false, true,  true)  or "Parts Unknown" end
	variableNormalList["random_battleground_zone"]      = function() return SS_Data.GetRandomZone(false, true,  false, false) or "Parts Unknown" end
	variableNormalList["random_battleground_full_zone"] = function() return SS_Data.GetRandomZone(false, true,  false, true)  or "Parts Unknown" end
	variableNormalList["random_world_zone"]             = function() return SS_Data.GetRandomZone(true,  false, false, false) or "Parts Unknown" end
	variableNormalList["random_world_full_zone"]        = function() return SS_Data.GetRandomZone(true,  false, false, true)  or "Parts Unknown" end
end

-- symbol section - parsed separately
local variableSymbolList = {
	["<tm>"]    = "™",
	["<r>"]     = "®",
	["<c>"]     = "©",
	["<cross>"] = "†",
	["<lts>"]   = "<",
	["<gts>"]   = ">",
	["<opar>"]  = "(",
	["<cpar>"]  = ")",
	["<obra>"]  = "{",
	["<cbra>"]  = "}",
	["<pipe>"]  = "||",
}

-- clear message names after using them so that ParseAndSendMessage() won't be polluted with bad values
local function ClearMessageNames()
	messageExtraTargetName = nil
	messageTargetName      = nil
	messageMemberName      = nil
	messageCasterName      = nil
end

----------------------------------------------------------------------------------------------------
-- send a message
----------------------------------------------------------------------------------------------------
-- used to execute slash commands
local MacroEditBox = MacroEditBox
local MacroEditBox_OnEvent = MacroEditBox:GetScript("OnEvent")

-- to know if they're sending a whisper so long messages can be split up properly
local whisperCommands = {}
do
	local i = 1
	local command
	repeat
		command = _G["SLASH_WHISPER"..i]
		if command then
			whisperCommands[command] = 1
			i = i + 1
		end
	until not command
end

-- for faster checking when stealthed and wanting to be quiet
local quietCommands = {[SLASH_SAY1]=1, [SLASH_YELL1]=1, [SLASH_EMOTE1]=1}
do
	local i, j = 1
	local emoteGeneric, emoteCommand
	repeat
		emoteGeneric = _G["EMOTE"..i.."_TOKEN"] -- generic name like BYE that can be used by multiple commands
		if emoteGeneric then
			j=1
			repeat
				emoteCommand = _G["EMOTE"..i.."_CMD"..j] -- each command for the generic name, like /goodbye and /farewell
				if emoteCommand then
					quietCommands[emoteCommand] = 1
					j = j + 1
				end
			until not emoteCommand
			i = i + 1
		end
	until not emoteGeneric
end

local function UseMessage(message, channel, language)
	if channel == "force_message" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFE0Test message:|r " .. message)
		return
	end
	if mainSettings.testing then
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFE0Reaction:|r " .. channel .. "" .. (target and (" " .. target) or "") .. ": " .. message)
		return
	end
	if channel == "chat command" then
		if message:sub(1,1) ~= "/" then
			message = SLASH_SAY1.." " .. message -- have to add the /s or sticky channels may make them use something else
		end
		local command = message:match("^(%S+)"):lower()
		if IsSecureCmd(command) then
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFE0Reactions:|r The slash command \"" .. message .. "\" can't be used automatically.")
			return
		elseif IsStealthed() and mainSettings.quietStealth and quietCommands[command] then
			local inInstance, instanceType = IsInInstance()
			if not inInstance or instanceType == "pvp" then
				return
			end
		end

		-- switch to the desired language if needed
		local previousLanguage
		if language then
			-- set to false if none exists so that it can be erased later
			previousLanguage = MacroEditBox.language or false
			MacroEditBox.language = language
		end

		-- finally use the command, splitting it up if needed
		-- get the full command including a possible whisper target and trailing space
		local fullCommand = whisperCommands[command] and message:match("^(/%S+%s+%S+ )") or (command.." ")
		if #message - #fullCommand <= 255 then
			MacroEditBox_OnEvent(MacroEditBox, "EXECUTE_CHAT_LINE", message)
		else
			-- must remove the command before splitting, then add it back each line
			local splitMessage = WordWrap((message:match("^"..fullCommand.."(.+)")), 255)
			for i=1,#splitMessage do
				MacroEditBox_OnEvent(MacroEditBox, "EXECUTE_CHAT_LINE", fullCommand..splitMessage[i])
			end
		end

		-- set the language back to what it was
		if previousLanguage ~= nil then
			MacroEditBox.language = previousLanguage or nil
		end
		return
	end
	if channel == "script" then
		RunScript(message)
		return
	end
	if channel == "print to chat" then
		DEFAULT_CHAT_FRAME:AddMessage(message)
		return
	end
	if channel == "print to warning" then
		RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
		PlaySoundFile("Sound/Interface/RaidWarning.wav")
		return
	end
end

----------------------------------------------------------------------------------------------------
-- future reaction queue for reactions using <new #>
----------------------------------------------------------------------------------------------------
local futureReactionFrame = CreateFrame("frame") -- for OnUpdate to check for future reactions
local futureReactionList = {} -- table of future reaction messages - see AddFutureReaction() for structure - soonest time left goes on end
local nextFutureReaction = 0 -- GetTime() of the soonest future message

-- check if it's time for future messages to be used - only runs when future messages exist
local function Reactions_FutureReactions_OnUpdate()
	if GetTime() < nextFutureReaction then
		return
	end

	-- the shortest time starts at the end of the table, so go backwards
	local size = #futureReactionList
	for i=#futureReactionList,1,-1 do
		if GetTime() < futureReactionList[i][1] then
			break
		else
			UseMessage(futureReactionList[i][2], futureReactionList[i][3], futureReactionList[i][4])
			futureReactionList[i] = nil
			size = size - 1
		end
	end

	-- set the next time to check the messages, or stop checking if there are no more
	if size == 0 then
		futureReactionFrame:Hide() -- stops OnUpdate()
	else
		nextFutureReaction = futureReactionList[size][1]
	end
end
futureReactionFrame:SetScript("OnUpdate", Reactions_FutureReactions_OnUpdate)
futureReactionFrame:Hide() -- stops OnUpdate()

-- add a message to the queue - the shortest time goes on the end
local function AddFutureReaction(message, channel, language, seconds)
	local newMessage = {GetTime() + seconds, message, channel, language}

	local size = #futureReactionList
	local isSoonest = true

	if size == 0 then
		futureReactionList[1] = newMessage
	else
		local added
		for i=size,1,-1 do
			if newMessage[1] < futureReactionList[i][1] then
				tinsert(futureReactionList, i+1, newMessage)
				added = true
				break
			end
			isSoonest = false
		end
		if not added then
			tinsert(futureReactionList, 1, newMessage)
		end
	end

	if isSoonest then
		nextFutureReaction = newMessage[1]
		futureReactionFrame:Show() -- starts OnUpdate()
	end
end

-- remove any actions that will try to whisper a certain name (probably because they ignored you)
local function RemoveFutureReactionWhispers(name)
	if not name then
		return
	end
	local lowercaseName = name:lower()

	local canceled = false
	local size = #futureReactionList
	local message, command, target
	for i=size,1,-1 do
		message = futureReactionList[i][2]:lower()
		if futureReactionList[i][3] == "chat command" then
			command, target = message:match("^(/%S+)%s+(%S+) ")
			if target and whisperCommands[command] and target:lower() == lowercaseName then
				tremove(futureReactionList, i)
				size = size - 1
				canceled = true
			end
		end
	end
	if size == 0 then
		futureReactionFrame:Hide() -- stops OnUpdate()
	else
		nextFutureReaction = futureReactionList[size][1]
	end
	if canceled then
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFE0Reactions:|r Future whispers to " .. name .. " have been canceled.")
	end
end

----------------------------------------------------------------------------------------------------
-- parse a message
----------------------------------------------------------------------------------------------------
local raidTargetIconList = {
	["star"]=1, ["circle"]=1, ["diamond"]=1, ["triangle"]=1, ["moon"]=1, ["square"]=1, ["cross"]=1, ["skull"]=1,
	["rt1"]=1, ["rt2"]=1, ["rt3"]=1, ["rt4"]=1, ["rt5"]=1, ["rt6"]=1, ["rt7"]=1, ["rt8"]=1,
	-- in case they're not using an english client:
	[RAID_TARGET_1]=1, [RAID_TARGET_2]=1, [RAID_TARGET_3]=1, [RAID_TARGET_4]=1, [RAID_TARGET_5]=1,
	[RAID_TARGET_6]=1, [RAID_TARGET_7]=1, [RAID_TARGET_8]=1,
}

local capitalizeChannels = {
	[SLASH_BATTLEGROUND1]=1, [SLASH_GUILD1]=1, [SLASH_OFFICER1]=1, [SLASH_PARTY1]=1, [SLASH_RAID1]=1,
	[SLASH_RAID_WARNING1]=1, [SLASH_SAY1]=1, [SLASH_WHISPER1]=1, [SLASH_YELL1]=1,
}

local function ExpandOptions(text)
	text = gsub(text, "(%b())", function(fullStr)
		local str = sub(fullStr, 2, -2)

		if find(str, "%(") then
			str = ExpandOptions(str)
		end

		local _, amount = gsub(str, "|", "|")
		if amount == 0 then
			return fullStr
		else
			local choice = random(0, amount)
			local pattern = rep("[^|]+.-|", choice) .. "([^|]+)"
			return (match(str, pattern)) or ""
		end
	end)
	return text
end

local function ParseAndSendMessage(text, channel, target, language, reactionData, addTime)
	channel = lower(channel)

	-- convert <new> variables into a special pattern to make it easy to iterate through lines:
	-- \1\2time\2channel\2
	text = string.gsub(text, "<new%s*(%d*)%s*(%d*)[:]*(.-)>", function(time1, time2, channel)
		if time2 ~= "" then
			time1 = random(tonumber(time1) or 1, tonumber(time2) or 1)
		else
			time1 = time1 ~= "" and time1 or "0"
		end
		-- "chat" is short for "chat command"
		return "\1\2" .. time1 .. "\2" .. (channel == "chat" and "chat command" or channel) .. "\2"
	end)

	-- go through each line separated by \1
	local lineTime = addTime or 0
	for line in gmatch(text, "[^\1]+") do
	repeat -- to be able to use break as continue
		local lineChannel = nil
		-- if it's a <new> line, get the time and channel
		line = line:gsub("^\2(%d+)\2(.-)\2", function(time, channel)
			lineTime = lineTime + tonumber(time)
			lineChannel = channel
			return ""
		end)
		if line == "" then
			break -- acts as continue
		end
		if channel == "force_message" then
			lineChannel = "force_message"
		else
			lineChannel = lineChannel ~= "" and lineChannel or channel
		end

		--------------------------------------------------
		-- scripts
		--------------------------------------------------
		if lineChannel == "chat command" and (line:find("^"..SLASH_SCRIPT1) or line:find("^"..SLASH_SCRIPT2)) then
			-- only replace normal variables in scripts
			line = gsub(line, "<(.-)>", function(variable)
				local apostropheCheck
				if variable:sub(-2) == "'s" then
					variable = variable:sub(1, -3)
					apostropheCheck = true
				end
				local name, arg = match(variable, "([%w_]+)[:]*(.*)")
				local info = variableNormalList[name]
				local text = info and info(arg) or "<"..variable..">"
				return apostropheCheck and ApostropheName(text) or text
			end)

			if lineTime > 0 then
				AddFutureReaction(line, lineChannel, nil, lineTime)
			else
				UseMessage(line, lineChannel)
			end
			break -- acts as continue
		end

		--------------------------------------------------
		-- non-script channels
		--------------------------------------------------
		-- replace {} tags
		line = gsub(line, "{(.-)}", function(tags)
			if raidTargetIconList[tags] then -- don't replace raid target icons
				return "{"..tags.."}"
			end
			local apostropheCheck
			if tags:sub(-2) == "'s" then
				tags = tags:sub(1, -3)
				apostropheCheck = true
			end
			local list = {}
			local total = 0
			for name in gmatch(tags, "([^|]+)") do
				if tagList[name] then
					list[#list+1] = tagList[name]
					total = total + tagList[name].amount
				else
					DEFAULT_CHAT_FRAME:AddMessage("Reactions: Unknown tag '" .. name .. "' tried to be used!", 1, 0, 0)
				end
			end
			if total == 0 then
				return apostropheCheck and "strange thought process'" or "strange thought process"
			end
			local chosen = random(1, total)
			for i=1,#list do
				if chosen <= list[i].amount then
					local pattern = rep("[^|%(%)]+|", chosen - 1) .. "([^%(|%)]+)"
					local text = match(list[i].text, pattern) or "strange thought process"
					return apostropheCheck and ApostropheName(text) or text
				end
				chosen = chosen - list[i].amount
			end
		end)

		-- replace () options
		line = ExpandOptions(line)

		-- replace normal variables
			line = gsub(line, "<(.-)>", function(variable)
				local apostropheCheck
				if variable:sub(-2) == "'s" then
					variable = variable:sub(1, -3)
					apostropheCheck = true
				end
				local name, arg = match(variable, "([%w_]+)[:]*(.*)")
				local info = variableNormalList[name]
				local text = info and info(arg) or "<"..variable..">"
				return apostropheCheck and ApostropheName(text) or text
			end)

		-- replace symbol variables
		line = gsub(line, "(<[%w_]->)", function(variable)
			local info = variableSymbolList[variable]
			return info or variable
		end)

		-- fix the usage of "a" and "an"
		line = gsub(line, "%f[%w](%s?)([aA][nN]?) (%w+)", function(before, an, word)
			local lowerWord = lower(word) or ""
			for i=1,#ArticleListA do
				if find(lowerWord, ArticleListA[i]) then
					return before .. (sub(an, 1,1) == "A" and "A " or "a ") .. word
				end
			end
			for i=1,#ArticleListAn do
				if find(lowerWord, ArticleListAn[i]) then
					return before .. ((#an == 2 and an .. " ") or (sub(an, 1,1) == "A" and "An " or "an ")) .. word
				end
			end
			return before .. (sub(an, 1,1) == "A" and "A " or "a ") .. word
		end)

		-- redirect to another spell/event
		if lineChannel == "spell/event" then
			-- reactionData is {hitType, messageCasterName, messageTargetName, actionType, force, forceMessage, redirectionSpellName or spellName, redirectionSpellId or spellId, redirectionFromEvent, redirectionCount}
			if reactionData then
				reactionData[10] = reactionData[10] and (reactionData[10] + 1) or 1
				if reactionData[10] and reactionData[10] > 7 then
					DEFAULT_CHAT_FRAME:AddMessage("Reactions: Too many spell/event redirections! Last redirection to: " .. (reactionData[7] or "Unknown Name") .. " (ID " .. (reactionData[8] or "unknown") .. ")")
					break -- acts as continue
				end
				AttemptReaction(line, 0, reactionData[1], reactionData[2], reactionData[3], reactionData[4],
									 reactionData[5], reactionData[6], reactionData[7], reactionData[8],
									 reactionData[9], reactionData[10], lineTime)
			else
				AttemptReaction(line, 0, nil, messagePlayerName, nil, ActionType.HIT, nil, nil, nil, nil, nil, 1, lineTime)
			end
			break -- acts as continue
		end

		-- convert special channels to their actual channel
		if lineChannel ~= "chat command" and lineChannel ~= "print to chat" and lineChannel ~= "print to warning" and
			lineChannel ~= "force_message" and lineChannel ~= "say and yell" then
			if lineChannel == "group" then
				lineChannel = "chat command"
				local inInstance, instanceType = IsInInstance()
				if inInstance and instanceType == "pvp" then
					line = SLASH_BATTLEGROUND1 .. " " .. line
				elseif GetNumRaidMembers() > 0 then
					line = SLASH_RAID1 .. " " .. line
				elseif GetNumPartyMembers() > 0 then
					line = SLASH_PARTY1 .. " " .. line
				else
					break -- acts as continue
				end
			elseif lineChannel == "whisper" or lineChannel == "/w target" then
				if not messageTargetName and not messageExtraTargetName and not messageMemberName then
					break -- acts as continue
				end
				lineChannel = "chat command"
				line = SLASH_WHISPER1 .. " " .. (messageExtraTargetName or messageTargetName or messageMemberName) .. " " .. line
			elseif lineChannel == "/w caster" then
				if not messageCasterName and not messageTargetName then
					break -- acts as continue
				end
				lineChannel = "chat command"
				line = SLASH_WHISPER1 .. " " .. (messageCasterName or messageTargetName) .. " " .. line
			else
				break -- acts as continue
			end
		end

		-- shout mode
		if mainSettings.shoutMode then
			-- can't capitalize everything because parts of item/spell/etc links must be the proper case
			-- example link: "text |cff9d9d9d|Hitem:7073:0:0:0:0:0:0:0:80:0:0:0:0|h[Broken Fang]|h|r text"
			-- |c|r|h must be lowercase, except at |Hitem where |H must be capital and "item" must be lowercase
			-- so 1. make all uppercase, 2. make all "|<letter>" lowercase, 3. make "|h<word>:" be "|H<lowercase word>:"
			--
			-- This should work for all normal links and all intentionally messed up links except for where they remove
			-- the [] around the name and the first word of the name has : at the end, like: |Hitem:199:0:0:0:0:0:0:0:80:0:0:0:0|hSomething: bad name|h
			-- This can't be fixed by using "|H(%u+:%d)" because name links don't have a number after the : and I don't
			-- want to check the word after |H to see if it is item/name/enchant/spell/etc just for this one strange case
			line = line:upper():gsub("|[CRH]", string.lower):gsub("|h(%u+:)", function(w) return "|H" .. w:lower() end)
		else
			-- capitalize the first letter of some things
			local command = line:match("^(/%S)")
			if not command then
				line = gsub(line, "^%l", upper)
			elseif capitalizeChannels[command:lower()] then
				line = gsub(line, "^(/%S )(%l)", function(cmd, letter) return cmd..letter:upper() end)
			end
		end

		-- decide language to use
		local languageName = nil
		if language and language ~= "Common" and GetNumLanguages() > 1 then
			if language == "Racial" then
				if UnitFactionGroup("player") == "Horde" then
					languageName = GetLanguageByIndex(GetLanguageByIndex(1) == "Orcish" and 2 or 1)
				else
					languageName = GetLanguageByIndex(GetLanguageByIndex(1) == "Common" and 2 or 1)
				end
			else
				languageName = GetLanguageByIndex(random(1, GetNumLanguages()))
			end
		end

		--------------------------------------------------
		-- show/use the message
		--------------------------------------------------
		if lineChannel == "say and yell" then
			if lineTime > 0 then
				AddFutureReaction(SLASH_SAY1.." "..line, "chat command", languageName, lineTime)
				AddFutureReaction(SLASH_YELL1.." "..line, "chat command", languageName, lineTime)
			else
				UseMessage(SLASH_SAY1.." "..line, "chat command", languageName)
				UseMessage(SLASH_YELL1.." "..line, "chat command", languageName)
			end
		else
			if lineTime > 0 then
				AddFutureReaction(line, lineChannel, languageName, lineTime)
			else
				UseMessage(line, lineChannel, languageName)
			end
		end
	until true
	end
end

----------------------------------------------------------------------------------------------------
-- check if a reaction can be used based on set conditions
----------------------------------------------------------------------------------------------------
local conditionFriendCache
local conditionGuildCache

local function CheckUnitConditions(conditionTable, name, prefix)
	if not name then
		return true
	end

	local unitid
	local targetIsNpc -- also used to skip guild/friend checking if possible
	local unitid = FindUnitID(name)
	if unitid then
		targetIsNpc = (not UnitIsPlayer(unitid))

		if UnitIsEnemy("player", unitid) then
			if conditionTable[prefix.."Hostile"] then return false end
		elseif UnitCanAttack("player", unitid) then
			if conditionTable[prefix.."Neutral"] then return false end
		else
			if conditionTable[prefix.."Friendly"] then return false end
		end

		if not targetIsNpc then
			if name == messagePlayerName then
				if conditionTable[prefix.."Self"] then return false end
			else
				if conditionTable[prefix.."NotSelf"] then return false end
				if conditionTable[prefix.."Player"] then return false end
			end

			local _, race = UnitRace(unitid)
			if conditionTable[prefix..race] then return false end
		else
			-- pets don't count as being/not being a mob
			if UnitIsUnit(unitid, "pet") then
				if conditionTable[prefix.."MyPet"] then return false end
			elseif UnitPlayerOrPetInParty(unitid) then
				if conditionTable[prefix.."NotMyPet"] then return false end
			else
				if conditionTable[prefix.."Mob"] then return false end
			end
			if conditionTable[prefix.."NotSelf"] then return false end

			local classification = bossList[UnitName(unitid)] and "worldboss" or UnitClassification(unitid)
			if classification then -- not sure if it can be nil
				if conditionTable[prefix..classification] then return false end
			end
			if conditionTable[prefix..UnitCreatureType(unitid)] then return false end
		end

		local sex = UnitSex(unitid)
		if  (sex == 2 and conditionTable[prefix.."SexMale"])
		 or (sex == 3 and conditionTable[prefix.."SexFemale"])
		 or (sex == 1 and conditionTable[prefix.."SexUnknown"]) then
			return false
		end
	end

	-- friend/guild conditions
	if not targetIsNpc and messagePlayerName ~= name then
		local checkFriends = conditionTable[prefix.."Friend"] or conditionTable[prefix.."NotFriend"]
		local checkGuild = (conditionTable[prefix.."Guild"] or conditionTable[prefix.."NotGuild"]) and IsInGuild()
		if checkFriends or checkGuild then
			local isFriend = conditionFriendCache[name]
			local isGuildMember = conditionGuildCache[name]

			if checkFriends and isFriend == nil then
				for i=1,GetNumFriends() do
					if name == GetFriendInfo(i) then
						isFriend = true
						break
					end
				end
				conditionFriendCache[name] = isFriend or false
			end
			if checkGuild and isGuildMember == nil then
				for i=1,GetNumGuildMembers() do
					if name == GetGuildRosterInfo(i) then
						isGuildMember = true
						break
					end
				end
				conditionGuildCache[name] = isGuildMember or false
			end

			-- special handling for guild/friends - if they're allowed on any of the options then
			-- they're accepted at targets
			if not ( (isGuildMember and not conditionTable[prefix.."Guild"])
				or (not isGuildMember and not conditionTable[prefix.."NotGuild"])
				or (isFriend and not conditionTable[prefix.."Friend"])
				or (not isFriend and not conditionTable[prefix.."NotFriend"]) ) then
				return false
			end
		end
	end

	-- if information wasn't known about them, disqualify them if they have any flags besides the
	-- guild and friends ones
	if not unitid then
		local search, exception1, exception2 = "^"..prefix..".", "Guild$", "Friend$"
		for k in pairs(conditionTable) do
			if (k:find(search)) and not (k:find(exception1)) and not (k:find(exception2)) then
				return false
			end
		end
	end

	return true
end

-- Something being in the table means it's NOT allowed - done this way to save memory and to skip
-- checking since most cases will probably allow everything so the table won't even need to exist.
local function ReactionConditionsUsable(conditionTable, usableCombat, hitType, spellId)
	if not conditionTable then
		return true
	end

	-- combat and hit/miss conditions
	if conditionTable[CONDITION_TYPE_COMBAT] then
		if conditionTable[usableCombat] then
			return false
		end
		if hitType then
			if conditionTable[hitType] then
				return false
			end
		elseif conditionTable["Normal"] then
			return false
		end
	end

	-- caster/target/group unit conditions
	if (conditionTable[CONDITION_TYPE_TARGET] and not CheckUnitConditions(conditionTable, messageExtraTargetName or messageTargetName or (messageCasterName == messagePlayerName and messagePlayerName), "Target"))
	or (conditionTable[CONDITION_TYPE_GROUP_MEMBER]  and not CheckUnitConditions(conditionTable, messageMemberName, "Group"))
	or (conditionTable[CONDITION_TYPE_CASTER] and not CheckUnitConditions(conditionTable, messageCasterName, "Caster")) then
		return false
	end

	-- party conditions
	if conditionTable[CONDITION_TYPE_PARTY] then
		if UnitExists("pet") then
			if conditionTable["HavePet"] then return false end
		else
			if conditionTable["HaveNoPet"] then return false end
		end

		if inGroup then
			if GetNumRaidMembers() > 0 then
				if conditionTable["Raid"] then return false end
				if IsRaidOfficer() then
					if conditionTable["GroupLeader"] then return false end
				else
					if conditionTable["NotGroupLeader"] then return false end
				end
			elseif GetNumPartyMembers() > 0 then
				if conditionTable["Party"] then return false end
				if IsPartyLeader() then
					if conditionTable["GroupLeader"] then return false end
				else
					if conditionTable["NotGroupLeader"] then return false end
				end
			end
			local _, masterLooter = GetLootMethod()
			if masterLooter == 0 then
				if conditionTable["MasterLooter"] then return false end
			else
				if conditionTable["NotMasterLooter"] then return false end
			end
		elseif conditionTable["Ungrouped"] then
			return false
		end
	end

	if conditionTable[CONDITION_TYPE_AFFECTED] then
		local effects = eventData.playerSpellEffects
		for i=1,17 do
			if effects[i] == 0 then
				if conditionTable[-i] then
					return false
				end
			elseif conditionTable[i] then
				return false
			end
		end
	end

	-- player conditions
	if conditionTable[CONDITION_TYPE_PLAYER] then
		if IsMounted() then
			if conditionTable["CharMounted"] then return false end
		else
			if conditionTable["CharNotMounted"] then return false end
		end
		if IsSwimming() then
			if conditionTable["CharSwimming"] then return false end
		else
			if conditionTable["CharNotSwimming"] then return false end
		end
		if IsFlying() then
			if conditionTable["CharFlying"] then return false end
		else
			if conditionTable["CharNotFlying"] then return false end
		end
		if IsStealthed() then
			if conditionTable["CharStealthed"] then return false end
		else
			if conditionTable["CharNotStealthed"] then return false end
		end

		local health = floor(UnitHealth("player") / UnitHealthMax("player") * 100)
		if health <= mainSettings.lowHealthBegin then
			if conditionTable["CharLowHealth"] then return false end
		elseif health >= mainSettings.lowHealthEnd then
			if conditionTable["CharHighHealth"] then return false end
		else
			if conditionTable["CharMediumHealth"] then return false end
		end

		local Power = floor(UnitMana("player") / UnitManaMax("player") * 100)
		if Power <= mainSettings.lowManaBegin then
			if conditionTable["CharLowPower"] then return false end
		elseif Power >= mainSettings.lowManaEnd then
			if conditionTable["CharHighPower"] then return false end
		else
			if conditionTable["CharMediumPower"] then return false end
		end
	end

	-- location conditions
	if conditionTable[CONDITION_TYPE_PLACE] then
		if UnitInBattleground("player") then
			if conditionTable["Battlegrounds"] then return false end
		elseif IsActiveBattlefieldArena() then
			if conditionTable["Arenas"] then return false end
		elseif IsInInstance() then
			if conditionTable["Instances"] then return false end
		else
			if conditionTable["WorldZones"] then return false end
		end

		if IsIndoors() then
			if conditionTable["Indoors"] then return false end
		else
			if conditionTable["Outdoors"] then return false end
		end

		local pvpStatus = (GetZonePVPInfo())
		if pvpStatus and conditionTable[pvpStatus] then
			return false
		end
	end

	-- miscellaneous conditions
	if conditionTable[CONDITION_TYPE_MISCELLANEOUS] then
		-- spell ranks
		if spellId then
			local _, rank = GetSpellInfo(spellId)
			if rank and conditionTable[rank] then
				return false
			end
		end

		-- time conditions
		local realHour = date("*t").hour
		if realHour < 5 or realHour >= 21  then
			if conditionTable["RealNight"] then return false end
		elseif realHour < 12 then
			if conditionTable["RealMorning"] then return false end
		elseif realHour < 17 then
			if conditionTable["RealAfternoon"] then return false end
		else
			if conditionTable["RealEvening"] then return false end
		end

		local gameHour = GetGameTime()
		if gameHour < 5 or gameHour >= 21 then
			if conditionTable["Night"] then return false end
		elseif gameHour < 12 then
			if conditionTable["Morning"] then return false end
		elseif gameHour < 17 then
			if conditionTable["Afternoon"] then return false end
		else
			if conditionTable["Evening"] then return false end
		end
	end

	return true
end

-- check if a specific role item is being worn
local function ReactionWearingRoleItem(number)
	local item = mainSettings.roleItems[number]
	if item then
		local link = GetInventoryItemLink("player", item[4])
		if link and link:match("%[(.-)]") == item[1] then
			return true
		end
		if item[5] then
			link = GetInventoryItemLink("player", item[5])
			if link and link:match("%[(.-)]") == item[1] then
				tanking = true
			end
		end
		return nil
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- attempt to use a spell/event reaction - return true if successfully used
----------------------------------------------------------------------------------------------------
local exactLastReactionTime = {} -- GetTime() of when a spell/event was last used

-- spellName, spellId = the name and/or ID number of the spell or event to react to
-- hitType = nil/Normal, Critical, Crushing, or Glancing - or miss type: MISS, DODGE, BLOCK, PARRY, etc
-- caster, target = the caster and target of the spell/event
-- actionType = value from the ActionType table (HIT/MISS/START_CAST/etc)
-- force = don't check certain things like cooldowns
-- forceMessage = just create a test message
-- redirectionSpellName = if using the "Spell/Event" channel, it will send this so that the <spellName> variable works
-- redirectionSpellId = if using the "Spell/Event" channel, it will send this so that the <spell_link> variable works
-- redirectionFromEvent = if the "Spell/Event" channel originated from an event - to be able to get you_hit/member_hit/other_hit properly
-- redirectionCount = counter of how many times "Spell/Event" channel has redirection to another reaction list - to be able to exit an endless loop
AttemptReaction = function(spellName, spellId, hitType, caster, target, actionType, force, forceMessage,
									redirectionSpellName, redirectionSpellId, redirectionFromEvent, redirectionCount, redirectionTime)
	if not mainSettings.enabled and not forceMessage then
		return
	end

	local spellSettings
	if not forceMessage then
		spellSettings = GetSpellSettings(spellName, spellId)
		if not spellSettings then
			return
		end

		-- only allow 1 trigger for each spell/event every 1/5th of a second to stop those that have multiple events at once
		if not force then
			local lastUsed = exactLastReactionTime[spellId and spellId ~= 0 and spellId or spellName]
			if lastUsed and GetTime() - lastUsed < .20 and not redirectionCount then
				return
			end
		end
	end

	-- when someone casts on themselves, remove the target if there is one and and set a flag to know its a self-cast
	-- don't do this for events so that they can use a simpler system of just you_hit, member_hit, other_hit to tell who it's affecting
	local targetSelf = nil
	if spellSettings and not spellSettings.event and not redirectionFromEvent then
		if caster == target or target == nil then
			targetSelf = true
			target = nil
		end
	end

	-- figure out which message type to use and set up variable names
	local actionInfo      = nil -- refence to the action table that contains the settings and reactions
	local reactions        = nil -- reference to the list of reactions for the action
	local chosenReaction   = nil -- indice of the reaction that's chosen to be used
	local auraUnitName     = nil -- name of the person to check auras on in limitAura=true messages
	messageMemberName      = nil
	messageTargetName      = nil
	messageExtraTargetName = nil
	messageCasterName      = caster

	if forceMessage then
		messageCasterName = caster or messagePlayerName
		messageMemberName = target or "Illidan"
		messageTargetName = target or "Hogger"
		messageExtraTargetName = target or "Wood Man"
	else
		-- figure out the type of action (you_hit, member_miss, etc)
		-- player casting something
		if (messageCasterName == messagePlayerName or (messageCasterName == nil and actionType ~= ActionType.EVENT_AURA)) and actionType ~= ActionType.AURA_GAINED and actionType ~= ActionType.AURA_REMOVED then
			actionInfo =  (actionType == ActionType.HIT and ((targetSelf and spellSettings.you_hit_self) or (not targetSelf and spellSettings.you_hit)))
							or (actionType == ActionType.PERIODIC and ((targetSelf and spellSettings.periodic_you_hit_self) or (not targetSelf and spellSettings.periodic_you_hit)))
							or (actionType == ActionType.MISS and spellSettings.you_miss)
							or (actionType == ActionType.START_CAST and spellSettings.start_cast)
							or (actionType == ActionType.CHANNEL_STOP and spellSettings.you_channel_stop)
							or nil -- end of assigning actionInfo
			messageTargetName = target
			messageMemberName = (UnitPlayerOrPetInParty(target) or UnitPlayerOrPetInRaid(target) or UnitIsUnit(target or "player", "pet")) and target or nil
			auraUnitName = target or messageCasterName
		-- someone casting something on the player
		elseif target == messagePlayerName then
			actionInfo =  (actionType == ActionType.HIT and spellSettings.you_get_hit)
							or (actionType == ActionType.PERIODIC and spellSettings.periodic_you_get_hit)
							or (actionType == ActionType.MISS and spellSettings.you_dodge)
							or (actionType == ActionType.AURA_GAINED and spellSettings.aura_gained_you)
							or (actionType == ActionType.AURA_REMOVED and spellSettings.aura_removed_you)
							or (actionType == ActionType.EVENT_AURA and spellSettings.you_hit) -- spell effect events
							or nil -- end of assigning actionInfo
			messageTargetName = messageCasterName
			messageMemberName = (UnitPlayerOrPetInParty(messageCasterName) or UnitPlayerOrPetInRaid(messageCasterName) or UnitIsUnit(messageCasterName or "player", "pet")) and messageCasterName or nil
			auraUnitName = target or messageCasterName
		-- group member casting something
		elseif UnitPlayerOrPetInParty(messageCasterName) or UnitPlayerOrPetInRaid(messageCasterName) or UnitIsUnit(messageCasterName or "player", "pet") then
			actionInfo =  (actionType == ActionType.HIT and ((targetSelf and spellSettings.member_hit_self) or (not targetSelf and spellSettings.member_hit)))
							or (actionType == ActionType.PERIODIC and ((targetSelf and spellSettings.periodic_member_hit_self) or (not targetSelf and spellSettings.periodic_member_hit)))
							or (actionType == ActionType.MISS and spellSettings.member_miss)
							or nil -- end of assigning actionInfo
			messageTargetName = target
			messageMemberName = messageCasterName
			auraUnitName = target or messageMemberName
		-- someone casting something on a group member
		elseif UnitPlayerOrPetInParty(target) or UnitPlayerOrPetInRaid(target) or UnitIsUnit(target or "player", "pet") then
			actionInfo =  (actionType == ActionType.HIT and spellSettings.member_get_hit)
							or (actionType == ActionType.PERIODIC and spellSettings.periodic_member_get_hit)
							or (actionType == ActionType.MISS and spellSettings.member_dodge)
							or (actionType == ActionType.AURA_GAINED and spellSettings.aura_gained_member)
							or (actionType == ActionType.AURA_REMOVED and spellSettings.aura_removed_member)
							or (actionType == ActionType.EVENT_AURA and spellSettings.member_hit) -- spell effect events
							or nil -- end of assigning actionInfo
			messageTargetName = messageCasterName or (actionType == ActionType.EVENT_AURA and target)
			messageMemberName = target
			auraUnitName = target or messageMemberName
			-- special case when there's no "Group member dodges/resists" but there is "Non-grouped person's spell misses/is resisted"
			if not actionInfo and actionType == ActionType.MISS and (not UnitPlayerOrPetInParty(caster) and not UnitPlayerOrPetInRaid(caster) and not UnitIsUnit(caster or "player", "pet")) then
				actionInfo = spellSettings.other_miss
			end
		-- non-group member casting or being hit by something
		else
			actionInfo =  (actionType == ActionType.HIT and ((targetSelf and spellSettings.other_hit_self) or (not targetSelf and spellSettings.other_hit)))
							or (actionType == ActionType.PERIODIC and ((targetSelf and spellSettings.periodic_other_hit_self) or (not targetSelf and spellSettings.periodic_other_hit)))
							or (actionType == ActionType.MISS and spellSettings.other_miss)
							or (actionType == ActionType.AURA_GAINED and spellSettings.aura_gained_other)
							or (actionType == ActionType.AURA_REMOVED and spellSettings.aura_removed_other)
							or (actionType == ActionType.EVENT_AURA and spellSettings.other_hit) -- spell effect events
							or nil -- end of assigning actionInfo
			if actionType == ActionType.AURA_GAINED or actionType == ActionType.AURA_REMOVED or actionType == ActionType.EVENT_AURA then
				messageTargetName = target
			else
				messageTargetName = messageCasterName
				messageExtraTargetName = target
			end
			auraUnitName = messageExtraTargetName or messageTargetName
		end

		if not actionInfo then
			return
		end

		if not force then
			-- set the chance modifier and check the chance
			local chance = actionInfo.chance
			if not chance or chance * mainSettings.chanceMultiplier < random() * 100 then
				return
			end
			-- check if it's in a group that's disabled
			if (actionInfo.group and not groupList[actionInfo.group]) or (not actionInfo.group and not groupList["Ungrouped"]) then
				return
			end
			-- if it has a travel time, then it must have a hit type or else UNIT_SPELLCAST_SUCCEEDED would trigger it as soon as the cast was complete
			if not hitType and spellSettings.travelTime and actionType ~= ActionType.START_CAST then
				return
			end
			-- check cooldown time
			if actionInfo.cooldown then
				if actionInfo.lastReactionTime and actionInfo.lastReactionTime > time() - actionInfo.cooldown then
					return
				end
			elseif lastReactionTime > time() - mainSettings.globalCooldown then
				return
			end
			-- check limitAura
			if actionInfo.limitAura and (UnitPlayerOrPetInRaid(auraUnitName) or UnitPlayerOrPetInParty(auraUnitName)) then
				local auraName = spellName or GetSpellInfo(spellId)
				if trackedAuras[auraUnitName] and trackedAuras[auraUnitName][auraName] then
					return
				end
				if not HasAura(auraUnitName, auraName) then
					return
				end
			end
			-- check limitGroup - if they're in the same group as the last time it was used then stop
			if actionInfo.limitGroup and inGroup and actionInfo.usedOnGroupNumber and actionInfo.usedOnGroupNumber == mainSettings.groupCounter then
				return
			end
			-- check limitFights - if enough fights haven't passed since the last time it was used then stop
			if actionInfo.limitFights and actionInfo.usedOnFightNumber and mainSettings.fightCounter < actionInfo.usedOnFightNumber + actionInfo.limitFightsAmount then
				return
			end
			-- check limitName - if a name has been involved with this action during this fight, then stop
			if actionInfo.limitName then
				local list = actionInfo.usedNames and actionInfo.usedNames[mainSettings.fightCounter]
				if list and auraUnitName and list[auraUnitName] then
					return
				end
			end
		end

		-- check if any reactions exist to use
		reactions = actionInfo.reactions
		if not reactions or next(reactions) == nil then
			return
		end

		local lastChosen = actionInfo.lastChosen
		local totalReactions = #reactions

		-- create a list of possible things to say - save the indice from the reactions table so the last chosen and time used can be updated if needed.
		-- reactions[i][3] is the last time used, [4] is language used, [5] is form/stance settings, [6] is table of not allowed conditions
		local possibleReactions = {}
		local possibleCount = 0

		-- find out which combat and form settings the player is compatible with to be able to compare it easily
		local usableCombat = UnitAffectingCombat("player") and "InCombat" or "NoCombat"
		local formNumber = GetShapeshiftForm()
		if formNumber == 0 then
			usableForm = "Normal"
		elseif playerClass == "SHAMAN" then
			usableForm = "Ghost Wolf"
		elseif playerClass == "PRIEST" then
			usableForm = "Shadowform"
		else
			local _
			_, usableForm = GetShapeshiftFormInfo(formNumber)
			if usableForm == "Dire Bear Form" then
				usableForm = "Bear Form"
			elseif usableForm == "Swift Flight Form" then
				usableForm = "Flight Form"
			end
		end

		-- clear the cache that keeps the more intensive checking results stored to reuse through all
		-- the checking here
		conditionFriendCache = {}
		conditionGuildCache = {}

		-- first add ones that have not been used yet or in a long enough time
		-- TODO: rethink the whole random picking process - shuffling would normally be better but
		--       it's not that simple now that there are restrictions on using each reaction
		for i=1,totalReactions do
			if i ~= lastChosen
			 and (not reactions[i][3] or reactions[i][3] < time()-mainSettings.messageCooldown)
			 and (reactions[i][1] ~= "Group" or inGroup)
			 and (not reactions[i][5] or usableForm == reactions[i][5])
			 and ReactionConditionsUsable(reactions[i][6], usableCombat, hitType, spellId)
			 and (not reactions[i][7] or ReactionWearingRoleItem(reactions[i][7])) then
				tinsert(possibleReactions, i)
				possibleCount = possibleCount + 1
			end
		end

		-- if none were found, add some messages that are on cooldown
		if possibleCount == 0 then
			-- first create a list of the messages on cooldown so they can be picked among equally
			local cooldowns = {}
			for i=1,totalReactions do
				if i ~= lastChosen
				 and (reactions[i][3] and reactions[i][3] >= time()-mainSettings.messageCooldown)
				 and (reactions[i][1] ~= "Group" or inGroup)
				 and (not reactions[i][5] or usableForm == reactions[i][5])
				 and ReactionConditionsUsable(reactions[i][6], usableCombat, hitType, spellId)
				 and (not reactions[i][7] or ReactionWearingRoleItem(reactions[i][7])) then
					tinsert(cooldowns, i)
				end
			end
			-- keep picking until there's enough in the possible message list
			local cooldownCount = #cooldowns
			if cooldownCount > 0 then
				local needed = 3
				repeat
					local picked = random(1, cooldownCount)
					tinsert(possibleReactions, cooldowns[picked])
					tremove(cooldowns, picked)
					cooldownCount = cooldownCount - 1
					possibleCount = possibleCount + 1
					needed = needed - 1
				until needed <= 0 or cooldownCount <= 0
			end
		end

		-- if nothing was possible, then add the last chosen one if it exists and is possible to use
		if possibleCount == 0
		 and lastChosen
		 and (not reactions[lastChosen][5] or usableForm == reactions[lastChosen][5])
		 and (reactions[lastChosen][1] ~= "Group" or inGroup)
		 and ReactionConditionsUsable(reactions[lastChosen][6], usableCombat, hitType, spellId)
		 and (not reactions[lastChosen][7] or ReactionWearingRoleItem(reactions[lastChosen][7])) then
			possibleReactions[1] = lastChosen
			possibleCount = 1
		end

		if possibleCount <= 0 then
			return
		end
		chosenReaction = possibleReactions[random(1, possibleCount)]
	end

	-- update cooldowns, limits, and last chosen
	if not force then
		actionInfo.lastChosen = chosenReaction
		actionInfo.lastReactionTime = time()
		reactions[chosenReaction][3] = time()
		if not actionInfo.noGCD then
			lastReactionTime = time()
		end
		exactLastReactionTime[spellId and spellId ~= 0 and spellId or spellName] = GetTime()

		-- limitGroup
		if actionInfo.limitGroup and inGroup then
			actionInfo.usedOnGroupNumber = mainSettings.groupCounter
		end
		-- limitFights
		if actionInfo.limitFights then
			actionInfo.usedOnFightNumber = mainSettings.fightCounter
		end
		-- limitAura
		if actionInfo.limitAura and (UnitPlayerOrPetInParty(auraUnitName) or UnitPlayerOrPetInRaid(auraUnitName)) then
			local name = spellName or GetSpellInfo(spellId)
			trackedAuras[auraUnitName] = trackedAuras[auraUnitName] or {}
			trackedAuras[auraUnitName][name] = true
		end
		--limitName
		if actionInfo.limitName and auraUnitName then
			local list = actionInfo.usedNames and actionInfo.usedNames[mainSettings.fightCounter]
			if not list then
				actionInfo.usedNames = {} -- rebuild it to erase any old tables
				actionInfo.usedNames[mainSettings.fightCounter] = {}
				list = actionInfo.usedNames[mainSettings.fightCounter]
			end
			list[auraUnitName] = true
		end
	end

	-- some events (like Interrupting) may set current spells, so don't overwrite those
	if spellSettings and not spellSettings.event and not redirectionFromEvent then
		currentSpellName = redirectionSpellName or spellName
		currentSpellId = redirectionSpellId or spellId
	end

	if forceMessage then
		ParseAndSendMessage(forceMessage, "force_message")
	elseif chosenReaction then
		local reactionData = {
			hitType,
			messageCasterName,
			messageTargetName,
			actionType,
			force,
			forceMessage,
			redirectionSpellName or spellName,
			redirectionSpellId or spellId,
			redirectionFromEvent or (spellSettings and spellSettings.event),
			redirectionCount
		}
		ParseAndSendMessage(reactions[chosenReaction][2], reactions[chosenReaction][1], messageTargetName, reactions[chosenReaction][4], reactionData, redirectionTime)
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- set up settings, creating them if needed
----------------------------------------------------------------------------------------------------
local channelData = nil

local function UpgradeSettings()
	-- 1.7 upgrade: set up the amount variable in each tag
	if not mainSettings.version or mainSettings.version < 7 then
		for k,v in pairs(tagList) do
			v.amount = (select(2, v.text:gsub("|", "|"))) + 1
		end
	end

	if not mainSettings.version then
		return
	end

	-- 1.9 upgrade: convert chat triggers to use "Spell/Event" channel; convert old combat/hit settings to the allowance list
	if mainSettings.version < 9 then
		-- chat triggers
		for _, trigger in pairs(chatList) do
			if trigger.useReaction then
				trigger.replyChannel = "Spell/Event"
				trigger.useReply = trigger.useReaction
				trigger.useReaction = nil
			end
			trigger.forceReaction = nil
		end
		-- reactions
		local reaction
		for spellKey,spellValue in pairs(reactionList) do -- Spell/Event
			for actionKey,actionValue in pairs(spellValue) do -- actions
				if type(actionValue) == "table" then -- looking for you_hit/you_miss/etc action tables, not other settings
					local actionReactions = actionValue["reactions"]
					if actionReactions then
						for i=1,#actionReactions do -- reaction list for the action
							reaction = actionReactions[i]
							-- combat settings
							if reaction[4] then
								reaction[10] = reaction[10] or {} -- temporary use [10] because [6] (it's final placement) may still be used
								if reaction[4] == "In Combat" then
									reaction[10]["NoCombat"] = true -- remember the allowance table is the opposite - things on it means to NOT use the reaction then
								else
									reaction[10]["InCombat"] = true
								end
								reaction[4] = nil
							end
							-- hit settings
							if reaction[6] then
								-- easiest way is to add all options and remove (which means it's allowed) the old setting
								reaction[10] = reaction[10] or {}
								reaction[10]["Normal"] = true
								reaction[10]["Critical"] = true
								reaction[10]["Crushing"] = true
								reaction[10]["Glancing"] = true
								reaction[10][reaction[6]] = nil
								reaction[6] = nil
							end
							-- move settings if there are any
							if reaction[10] then
								reaction[6] = reaction[10]
								reaction[10] = nil
							end
						end
					end
				end
			end
		end
	end -- end 1.9 upgrade

	-- 1.11 upgrade: convert chat channel trigger lists to be in alphabetical order
	if mainSettings.version < 11 then
		local nameList
		for channel,list in pairs(mainSettings.chatList.channel) do
			-- save the name of each trigger
			nameList = {}
			for name in pairs(list) do
				nameList[#nameList+1] = name
			end
			-- empty the list, then readd all names to it
			mainSettings.chatList.channel[channel] = {}
			list = mainSettings.chatList.channel[channel]
			for i=1,#nameList do
				local name = nameList[i]
				local insertAt = 1
				for j=1,#list do
					if list[j]:lower() > name:lower() then
						break
					end
					insertAt = insertAt + 1
				end
				table.insert(list, insertAt, name)
			end
		end
	end  -- end 1.11 upgrade

	-- 1.15 upgrade: remove chanceModifier
	if mainSettings.version < 15 then
		mainSettings.chanceModifier = nil
	end

	-- 1.16 upgrade: change chat match excluding to allowing
	if mainSettings.version < 16 then
		local triggers = mainSettings.chatList.trigger
		if triggers then
			for _,settings in pairs(triggers) do
				settings.matchGuild   = settings.excludeGuild   ~= true and true or nil
				settings.matchFriends = settings.excludeFriends ~= true and true or nil
				settings.matchOthers  = true
				settings.excludeGuild = nil
				settings.excludeFriends = nil
			end
		end
	end

	-- 1.17 upgrade: convert reactions and <new> to use the chat command channel option if possible
	if mainSettings.version < 17 then
		local convertChannels = {
			["say"] = SLASH_SAY1.." ",
			["yell"] = SLASH_YELL1.." ",
			["say or yell"] = "("..SLASH_SAY1.."|"..SLASH_YELL1..") ",
			["raid"] = SLASH_RAID1.." ",
			["raid warning"] = SLASH_RAID_WARNING1.." ",
			["party"] = SLASH_PARTY1.." ",
			["emote"] = SLASH_EMOTE1.." ",
			["emote action"] = "/",
			["guild"] = SLASH_GUILD1.." ",
			["officer"] = SLASH_OFFICER1.." ",
			["battleground"] = SLASH_BATTLEGROUND1.." ",
			["/w yourself"] = SLASH_WHISPER1.." <player_name> ",
			["/w group"] = SLASH_WHISPER1.." <group_name> ",
			["script"] = SLASH_SCRIPT1.." ",
		}
		local specialChannels = { -- used when converting things like <new:3> and <new:name>
			["chat command"] = true,
			["say and yell"] = true,
			["group"] = true,
			["/w target"] = true,
			["/w caster"] = true,
			["print to chat"] = true,
			["print to warning"] = true,
			["spell/event"] = true,
		}
		function ConvertReaction(channel, text)
			if not text then
				return convertChannels[channel:lower()] and "Chat Command" or channel, nil
			end

			local chatCommand = convertChannels[channel:lower()]
			if text ~= "" then
				-- first replace <new> tags
				if chatCommand then
					text = gsub(text, "<new(%s*%d*%s*%d*)>", "<new%1>"..chatCommand)
				end
				-- next <new:channel> tags
				text = gsub(text, "<new(%s*%d*%s*%d*):(.-)>", function(timing, newChannel)
					local converted = convertChannels[newChannel:lower()]
					if not converted then
						if specialChannels[channel:lower()] then
							return "<new"..timing..":"..newChannel..">"
						elseif tonumber(newChannel) then
							converted = "/" .. newChannel .. " "
						else
							converted = SLASH_WHISPER1 .. " " .. newChannel .. " "
						end
					end
					if chatCommand then
						return "<new"..timing..">"..converted
					else
						return "<new"..timing..":chat>"..converted
					end
				end)
				-- finally add the chat command to the beginning if needed
				if chatCommand and not text:find("^<new%s*%d*%s*%d*>") and not text:find("^<new%s*%d*%s*%d*:[%a/]+>") then
					text = chatCommand .. text
				end
			end
			return chatCommand and "Chat Command" or channel, text
		end

		-- chat triggers
		for _, trigger in pairs(chatList) do
			trigger.replyChannel, trigger.useReply = ConvertReaction(trigger.replyChannel, trigger.useReply)
		end
		-- reactions
		local reaction
		for spellKey,spellValue in pairs(reactionList) do -- Spell/Event
			for actionKey,actionValue in pairs(spellValue) do -- actions
				if type(actionValue) == "table" then -- looking for you_hit/you_miss/etc action tables, not other settings
					local actionReactions = actionValue["reactions"]
					if actionReactions then
						for i=1,#actionReactions do -- reaction list for the action
							reaction = actionReactions[i]
							reaction[1], reaction[2] = ConvertReaction(reaction[1], reaction[2])
						end
					end
				end
			end
		end
	end -- end 1.17 upgrade

	-- 1.23 upgrade: remove elite72 conditions
	if mainSettings.version < 23 then
		local function RemoveElite72(reaction, unit)
			if reaction[6][unit.."elite72"] then
				reaction[6][unit.."elite72"] = nil
				local found
				for k in pairs(reaction[6]) do
					if k:find("^"..unit..".") then
						found = true
						break
					end
				end
				if not found then
					reaction[6][unit] = nil
					if next(reaction[6]) == nil then
						reaction[6] = nil
					end
				end
			end
		end
		-- reactions
		local reaction
		for spellKey,spellValue in pairs(reactionList) do -- Spell/Event
			for actionKey,actionValue in pairs(spellValue) do -- actions
				if type(actionValue) == "table" then -- looking for you_hit/you_miss/etc action tables, not other settings
					local actionReactions = actionValue["reactions"]
					if actionReactions then
						for i=1,#actionReactions do -- reaction list for the action
							reaction = actionReactions[i]
							if reaction[6] then
								RemoveElite72(reaction, "Caster")
							end
							if reaction[6] then
								RemoveElite72(reaction, "Target")
							end
						end
					end
				end
			end
		end
	end -- end 1.23 upgrade
end

local function SetDefaultSettings()
	local firstUse = (ReactionsSave == nil)

	if ReactionsSave == nil then
		ReactionsSave = {}
	end
	mainSettings = ReactionsSave

	if mainSettings.enabled          == nil then mainSettings.enabled          = false end
	if mainSettings.testing          == nil then mainSettings.testing          = false end
	if mainSettings.globalCooldown   == nil then mainSettings.globalCooldown   = 180   end
	if mainSettings.messageCooldown  == nil then mainSettings.messageCooldown  = 3600  end
	if mainSettings.automaticMinimum == nil then mainSettings.automaticMinimum = 30    end
	if mainSettings.automaticMaximum == nil then mainSettings.automaticMaximum = 90    end
	if mainSettings.lowHealthBegin   == nil then mainSettings.lowHealthBegin   = 25    end
	if mainSettings.lowHealthEnd     == nil then mainSettings.lowHealthEnd     = 75    end
	if mainSettings.lowManaBegin     == nil then mainSettings.lowManaBegin     = 20    end
	if mainSettings.lowManaEnd       == nil then mainSettings.lowManaEnd       = 75    end
	if mainSettings.fightLength      == nil then mainSettings.fightLength      = 10    end
	if mainSettings.lowDurability    == nil then mainSettings.lowDurability    = 25    end
	if mainSettings.chanceMultiplier == nil then mainSettings.chanceMultiplier = 1     end
	if mainSettings.groupList        == nil then mainSettings.groupList        = {["Ungrouped"]=true} end
	if mainSettings.tagList          == nil then mainSettings.tagList          = {}    end
	if mainSettings.reactionList     == nil then mainSettings.reactionList     = {}    end
	if mainSettings.chatList         == nil then mainSettings.chatList         = {}    end
	if mainSettings.groupCounter     == nil then mainSettings.groupCounter     = 0     end
	if mainSettings.fightCounter     == nil then mainSettings.fightCounter     = 0     end
	if mainSettings.quietStealth     == nil then mainSettings.quietStealth     = true  end
	if mainSettings.shoutMode        == nil then mainSettings.shoutMode        = false end
	if mainSettings.roleItems        == nil then mainSettings.roleItems        = {}    end
	if mainSettings.history          == nil then mainSettings.history          = {}    end

	chatList = ReactionsSave.chatList
	if chatList["trigger"] == nil then chatList["trigger"] = {} end
	if chatList["channel"] == nil then chatList["channel"] = {} end
	if chatList.channel["Action"]       == nil then chatList.channel["Action"]       = {} end
	if chatList.channel["Battleground"] == nil then chatList.channel["Battleground"] = {} end
	if chatList.channel["Channel"]      == nil then chatList.channel["Channel"]      = {} end
	if chatList.channel["Emote"]        == nil then chatList.channel["Emote"]        = {} end
	if chatList.channel["Error"]        == nil then chatList.channel["Error"]        = {} end
	if chatList.channel["Guild"]        == nil then chatList.channel["Guild"]        = {} end
	if chatList.channel["Loot"]         == nil then chatList.channel["Loot"]         = {} end
	if chatList.channel["Officer"]      == nil then chatList.channel["Officer"]      = {} end
	if chatList.channel["Party"]        == nil then chatList.channel["Party"]        = {} end
	if chatList.channel["Raid"]         == nil then chatList.channel["Raid"]         = {} end
	if chatList.channel["Say"]          == nil then chatList.channel["Say"]          = {} end
	if chatList.channel["System"]       == nil then chatList.channel["System"]       = {} end
	if chatList.channel["Tradeskill"]   == nil then chatList.channel["Tradeskill"]   = {} end
	if chatList.channel["Whisper"]      == nil then chatList.channel["Whisper"]      = {} end
	if chatList.channel["Yell"]         == nil then chatList.channel["Yell"]         = {} end
	if chatList.channel["Disabled"]     == nil then chatList.channel["Disabled"]     = {} end

	-- create some default tags
	if firstUse then
		mainSettings.tagList["race"]             = {submenu="Character", amount=10, text="draenei|blood elf|dwarf|orc|gnome|tauren|human|troll|night elf|undead"}
		mainSettings.tagList["class"]            = {submenu="Character", amount=9,  text="druid|hunter|mage|paladin|priest|rogue|shaman|warlock|warrior"}
		mainSettings.tagList["profession"]       = {submenu="Character", amount=13, text="alchemy|blacksmithing|enchanting|engineering|herbalism|jewelcrafting|leatherworking|mining|skinning|tailoring|cooking|first aid|fishing"}
		mainSettings.tagList["zone"]             = {submenu="Locations", amount=53, text="Azuremyst Isle|Dun Morogh|Durotar|Elwynn Forest|Eversong Woods|Mulgore|Teldrassil|Tirisfal Glades|Bloodmyst Isle|Darkshore|Ghostlands|Loch Modan|Silverpine Forest|Westfall|Barrens|Redridge Mountains|Stonetalon Mountains|Ashenvale|Duskwood|Hillsbrad Foothills|Wetlands|Thousand Needles|Alterac Mountains|Arathi Highlands|Desolace|Stranglethorn Vale|Dustwallow Marsh|Badlands|Swamp of Sorrows|Feralas|Hinterlands|Tanaris|Searing Gorge|Azshara|Blasted Lands|Un'goro Crater|Felwood|Burning Steppes|Western Plaguelands|Deadwind Pass|Eastern Plaguelands|Winterspring|Moonglade|Silithus|Hellfire Peninsula|Zangarmarsh|Terokkar Forest|Nagrand|Blade's Edge Mountains|Netherstorm|Shadowmoon Valley|Deadwind Pass|Isle of Quel'Danas"}
		mainSettings.tagList["outland"]          = {submenu="Locations", amount=8,  text="Blade's Edge Mountains|Hellfire Peninsula|Nagrand|Netherstorm|Shadowmoon Valley|Skettis|Terokkar Forest|Zangarmarsh"}
		mainSettings.tagList["instance"]         = {submenu="Locations", amount=34, text="Auchenai Crypts|Blackfathom Deeps|Blackrock Depths|Blackrock Spire|Caverns of Time|Dire Maul|Gnomeregan|Hellfire Ramparts|Magisters' Terrace|Mana-Tombs|Maraudon|Old Hillsbrad Foothills|Ragefire Chasm|Razorfen Downs|Razorfen Kraul|Scarlet Monastery|Scholomance|Sethekk Halls|Shadow Labyrinth|Shadowfang Keep|Stratholme|Sunken Temple|the Arcatraz|the Black Morass|the Blood Furnace|the Botanica|the Mechanar|the Shattered Halls|the Slave Pens|the Steamvault|the Underbog|Uldaman|Wailing Caverns|Zul'Farrak"}
		mainSettings.tagList["raid"]             = {submenu="Locations", amount=14, text="Blackwing Lair|Hyjal Summit|Karazhan|Magtheridon's Lair|Molten Core|Naxxramas|Onyxia's Lair|Ruins of Ahn'Qiraj|Sunwell Plateau|Temple of Ahn'Qiraj|The Black Temple|The Eye|Zul'Aman|Zul'Gurub"}
		mainSettings.tagList["battleground"]     = {submenu="Locations", amount=4,  text="Alterac Valley|Arathi Basin|Eye of the Storm|Warsong Gulch"}
		mainSettings.tagList["horde capital"]    = {submenu="Locations", amount=4,  text="Orgrimmar|Thunder Bluff|Silvermoon City|Undercity"}
		mainSettings.tagList["alliance capital"] = {submenu="Locations", amount=4,  text="Stormwind|Ironforge|Darnassus|The Exodar"}
		mainSettings.tagList["eightball"]        = {submenu="Random",    amount=20, text="It is certain|It is decidedly so|Without a doubt|Yes definitely|You may rely on it|As I see it, yes|Most likely|Outlook good|Yes|Signs point to yes|Reply hazy try again|Ask again later|Better not tell you now|Cannot predict now|Concentrate and ask again|Don't count on it|My reply is no|My sources say no|Outlook not so good|Very doubtful"}
	end

	-- set local references to look up things a bit faster
	groupList               = mainSettings.groupList
	reactionList            = mainSettings.reactionList
	tagList                 = mainSettings.tagList
	chatList                = mainSettings.chatList.trigger
	actionTriggerList       = mainSettings.chatList.channel.Action
	battlegroundTriggerList = mainSettings.chatList.channel.Battleground
	channelTriggerList      = mainSettings.chatList.channel.Channel
	emoteTriggerList        = mainSettings.chatList.channel.Emote
	errorTriggerList        = mainSettings.chatList.channel.Error
	guildTriggerList        = mainSettings.chatList.channel.Guild
	lootTriggerList         = mainSettings.chatList.channel.Loot
	officerTriggerList      = mainSettings.chatList.channel.Officer
	partyTriggerList        = mainSettings.chatList.channel.Party
	raidTriggerList         = mainSettings.chatList.channel.Raid
	sayTriggerList          = mainSettings.chatList.channel.Say
	systemTriggerList       = mainSettings.chatList.channel.System
	tradeskillTriggerList   = mainSettings.chatList.channel.Tradeskill
	whisperTriggerList      = mainSettings.chatList.channel.Whisper
	yellTriggerList         = mainSettings.chatList.channel.Yell

	-- remove old chat trigger person cooldowns
	for name,info in pairs(chatList) do
		if info.personCooldownList then
			for person,usedTime in pairs(info.personCooldownList) do
				if not info.personCooldown or usedTime <= time() - info.personCooldown then
					info.personCooldownList[person] = nil
				end
			end
			if next(info.personCooldownList) == nil then
				info.personCooldownList = nil
			end
		end
	end

	UpgradeSettings()

	-- set up information about each channel watched
	channelData = {
		-- CHAT_MSG_*              usable name     reference to the chat trigger list for this channel
		["BATTLEGROUND"]        = {"battleground", battlegroundTriggerList},
		["BATTLEGROUND_LEADER"] = {"battleground", battlegroundTriggerList},
		["CHANNEL"]             = {"channel",      channelTriggerList},
		["EMOTE"]               = {"emote",        emoteTriggerList},
		["GUILD"]               = {"guild",        guildTriggerList},
		["IGNORED"]             = {"system",       systemTriggerList},
		["LOOT"]                = {"loot",         lootTriggerList},
		["MONEY"]               = {"money",        lootTriggerList},
		["MONSTER_EMOTE"]       = {"emote",        emoteTriggerList},
		["MONSTER_SAY"]         = {"say",          sayTriggerList},
		["MONSTER_YELL"]        = {"yell",         yellTriggerList},
		["OFFICER"]             = {"officer",      officerTriggerList},
		["PARTY"]               = {"party",        partyTriggerList},
		["RAID"]                = {"raid",         raidTriggerList},
		["RAID_LEADER"]         = {"raid",         raidTriggerList},
		["RAID_WARNING"]        = {"raid",         raidTriggerList},
		["SAY"]                 = {"say",          sayTriggerList},
		["SYSTEM"]              = {"system",       systemTriggerList},
		["TEXT_EMOTE"]          = {"emote action", actionTriggerList},
		["TRADESKILLS"]         = {"tradeskill",   tradeskillTriggerList},
		["UI_ERROR_MESSAGE"]    = {"error",        errorTriggerList}, -- Special case: no CHAT_MSG_ before it
		["WHISPER"]             = {"whisper",      whisperTriggerList},
	 --["WHISPER_INFORM"]      = {"whisper",      whisperTriggerList},
		["YELL"]                = {"yell",         yellTriggerList},
	}

	-- set the version at the end after any possible upgrading
	mainSettings.version = MINOR_VERSION
end

----------------------------------------------------------------------------------------------------
-- tracking spell successes/failures, movement, and more
----------------------------------------------------------------------------------------------------
-- miscellaneous tracking
local isUnderwater         = nil -- if currently underwater (only if not able to breathe)
local fallTimeLeft         = nil -- time left while falling before another fall event triggers
local currentlySwimming    = nil -- if the player is currently swimming
local nextSwimmingCheck    = 1   -- time left before the next swimming check
local nextLostControlCheck = nil -- time left before the next check to see if control is still lost
local nextFlightCheck      = nil -- time left before the next taxi flight check
local flightVerified       = nil -- if the taxi flight has been verified to start (it won't start if they pick their current location)
local flightLocationName   = nil -- the destination of the current taxi flight, to be able to set <target_name> for landing

-- spell tracking
-- when a spell cast completes, it's not immediately known if it was a success. The failure messages
-- come soon after the finished event, so a time very near in the future (about 1/2 a second) is set
-- to allow the parsing of the other possible messages. If a message is found, then the tracking
-- variables about it are erased and a miss action occurs. If one isn't found, then the spell is
-- assumed to be successful.
local playerCastingSpellName = nil -- the current watched spell name being casted by the player
local playerCastingSpellId   = nil -- the current watched spell ID being casted by the player
local playerCastingTarget    = nil -- the name of the target that's currently being casted on by the player
local castChecks             = {}  -- tables like: {[1]=GetTime(), [2]=caster, [3]=target, [4]=spell name, [5]=spell ID}
local nextCastCheck          = nil -- castChecks[1][1] or nil - set here just for faster checking in OnUpdate

-- add a "successfully" cast spell to the list - if it's still on the list in about half a second
-- then it's assumed to have worked
local function AddCastCheck(caster, target, spell, id)
	local check = {GetTime()+.5, caster, target, spell, id}
	if not castChecks[1] then
		nextCastCheck = check[1]
		castChecks[1] = check
	else
		castChecks[#castChecks+1] = check
	end
end

-- remove a spell from a list, optionally trying a reaction - used when seeing a miss event or an
-- event that it did damage/healed/something
local function RemoveCastCheck(caster, spell, useReaction)
	local info
	for i=1,#castChecks do
		info = castChecks[i]
		if info[2] == caster and info[4] == spell then
			if useReaction then
				AttemptReaction(info[4], info[5], nil, info[2], info[3], ActionType.HIT)
			end
			tremove(castChecks, i)
			nextCastCheck = castChecks[1] and castChecks[1][1] or nil
			return
		end
	end
end

-- return true if a certain spell from a caster is still on the list
local function HasCastCheck(caster, spellId)
	local info
	for i=1,#castChecks do
		info = castChecks[i]
		if info[5] == spellId and info[2] == caster then
			return true
		end
	end
	return nil
end

-- use the first spell on the list and possibly more if their times are up
local function UseCastChecks()
	local info
	repeat
		info = castChecks[1]
		AttemptReaction(info[4], info[5], nil, info[2], info[3], ActionType.HIT)
		tremove(castChecks, 1)
	until castChecks[1] == nil or GetTime() < castChecks[1][1]
	nextCastCheck = castChecks[1] and castChecks[1][1] or nil
end

local elapsedTime = 0
local function Reactions_OnUpdate(self, elapsed)
	elapsedTime = elapsedTime + elapsed
	if elapsedTime < .15 then
		return
	end

	-- check for pending spell cast results - if it's still on the cast check list when its time
	-- passes then it can be assumed that it worked - more miss or hit events would have removed it
	if nextCastCheck and GetTime() > nextCastCheck then
		UseCastChecks()
	end

	-- check if it's time for the "automatic" event
	nextAutomaticTime = nextAutomaticTime - elapsedTime
	if nextAutomaticTime <= 0 then
		AttemptReaction("Automatic", 0, nil, messagePlayerName, nil, ActionType.HIT)
		SetNextAutomaticTime()
	end

	-- check if you've still lost control of the character
	if nextLostControlCheck then
		nextLostControlCheck = nextLostControlCheck - elapsedTime
		if nextLostControlCheck <= 0 then
			nextLostControlCheck = 1
			AttemptReaction("LoseControl", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
	end

	-- check falling
	if IsFalling() then
		fallTimeLeft = fallTimeLeft and fallTimeLeft - elapsedTime or 3
		if fallTimeLeft <= 0 then
			fallTimeLeft = 3
			if hasFullyLoggedIn then -- for some reason you're falling when logging in
				AttemptReaction("Falling", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
	else
		-- check swimming/underwater - doesn't check if falling so that jumping won't stop swimming
		fallTimeLeft  = nil
		nextSwimmingCheck = nextSwimmingCheck - elapsedTime
		if nextSwimmingCheck <= 0 then
			nextSwimmingCheck = 1
			if isUnderwater then
				AttemptReaction("Underwater", 0, nil, messagePlayerName, nil, ActionType.HIT)
			elseif IsSwimming() then
				if not currentlySwimming then
					currentlySwimming = true
					if hasFullyLoggedIn then
						AttemptReaction("SwimmingBegin", 0, nil, messagePlayerName, nil, ActionType.HIT)
					end
				else
					AttemptReaction("Swimming", 0, nil, messagePlayerName, nil, ActionType.HIT)
				end
			elseif currentlySwimming then
				currentlySwimming = nil
				AttemptReaction("SwimmingEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
	end

	-- check for a flight landing
	if nextFlightCheck then
		nextFlightCheck = nextFlightCheck - elapsedTime
		if nextFlightCheck <= 0 then
			if not flightVerified then -- not sure yet if the flight actually started, so check now
				if UnitOnTaxi("player") then
					flightVerified = true
					nextFlightCheck = 1
				else
					nextFlightCheck = nil
				end
			elseif UnitOnTaxi("player") then -- the flight has started and they're still on it
				nextFlightCheck = 1
			else -- the flight had started, but now they've landed
				flightVerified = nil
				nextFlightCheck = nil
				AttemptReaction("FlightMasterFlightEnd", 0, nil, messagePlayerName, flightLocationName, ActionType.HIT)
			end
		end
	end

	elapsedTime = 0 -- must be reset at the end so that the above checks can use it
end

----------------------------------------------------------------------------------------------------
-- data for parsing events
----------------------------------------------------------------------------------------------------
local reactionFrame = CreateFrame("frame") -- for listening for events

eventData.lastZone              = nil   -- the last non-blank zone the player has moved into and reacted to
eventData.lastSubzone           = nil   -- the last non-blank subzone the player has moved into and reacted to
eventData.onLowHealth           = nil   -- if low health has been reached, this is the lowest seen so far
eventData.onLowMana             = nil   -- if low mana has been reached, this is the lowest seen so far
eventData.lowestDurability      = 100   -- tracks the lowest durability percentage so events are only used once
eventData.autoLootOrTime        = nil   -- 1 if autoloot was used, else the GetTime() the last loot openend event happened
eventData.usedStartCast         = nil   -- if the current spell has tried a "You begin casting" action
eventData.hasLoggedIn           = nil   -- PLAYER_ALIVE is sent when logging in - this is to know if it's a login or resurrection
eventData.isDead                = nil   -- if the player is currently dead
eventData.followingPlayer       = nil   -- the name of the character the player is following
eventData.pendingGroupJoinName  = nil   -- the name of someone joining the group (only if the chat message comes before them actually joining)
eventData.pendingGroupLeaveName = nil   -- the name of someone leaving the group (only if the chat message comes before they actually leave)
eventData.playerSpellEffects = {        -- counters of how many of each type of spell effect is on the player
	[1]  = 0, -- 12:stun + 14:knockout
	[2]  = 0, -- 5:fear + 24:horror + 23:turn
	[3]  = 0, -- 15:bleed
	[4]  = 0, -- 7:root
	[5]  = 0, -- 17:polymorph
	[6]  = 0, -- 18:banish
	[7]  = 0, -- 2:disoriented
	[8]  = 0, -- 11:snare + 27:daze
	[9]  = 0, -- 30:sapped
	[10] = 0, -- 1:charm
	[11] = 0, -- 9:silence
	[12] = 0, -- 10:sleep
	[13] = 0, -- 13:freeze
	[14] = 0, -- 29:immune_shield
	[15] = 0, -- 16:bandage
	[16] = 0, -- 19:shield
	[17] = 0, -- 3:disarm
}
-- variables to keep track of when something is open because they have 2 closing events and only 1 is wanted!
eventData.auctioneerName        = nil   -- also the name of the auctioneer
eventData.mailboxOpened         = nil   -- if the mailbox is opened
eventData.merchantName          = nil   -- also the name of the merchant
eventData.tradePartner          = nil   -- also the name of the player trading with
eventData.flightMasterOpened    = nil   -- also the name of the flight master
-- localized spell names - speed isn't critical for these since they're only checked for the player, not everyone
eventData.DRINK             = (GetSpellInfo(430))
eventData.FOOD              = (GetSpellInfo(433))
eventData.OPENING           = (GetSpellInfo(3365))
eventData.WEAK_ALCOHOL      = (GetSpellInfo(11007))
eventData.STANDARD_ALCOHOL  = (GetSpellInfo(11008))
eventData.STRONG_ALCOHOL    = (GetSpellInfo(11009))
eventData.POTENT_ALCOHOL    = (GetSpellInfo(11629))
eventData.MOONGLOW_ALCOHOL  = (GetSpellInfo(26389))
eventData.DARK_IRON_ALCOHOL = (GetSpellInfo(44540))

-- totems are rudely treated like people in TBC, so make a list of their NPC IDs to handle them as objects
local totemMobList = {
	--[[earthbind totem        ]] [2630]=1, [22486]=1,
	--[[fire elemental totem   ]] [15439]=1,
	--[[fire nova totem        ]] [5879]=1, [6110]=1, [6111]=1, [7844]=1, [7845]=1, [15482]=1, [15483]=1,
	--[[magma totem            ]] [5929]=1, [7464]=1, [7465]=1, [7466]=1, [15484]=1,
	--[[searing totem          ]] [2523]=1, [21995]=1, [3902]=1, [3903]=1, [3904]=1, [7400]=1, [7402]=1, [15480]=1, [22895]=1,
	--[[totem of wrath         ]] [17539]=1,
	--[[earth elemental totem  ]] [15430]=1,
	--[[fire resistance totem  ]] [5927]=1, [7424]=1, [7425]=1, [15487]=1,
	--[[frost resistance totem ]] [5926]=1, [7412]=1, [7413]=1, [15486]=1,
	--[[grace of air totem     ]] [7486]=1, [7487]=1, [15463]=1,
	--[[grounding totem        ]] [5925]=1,
	--[[nature resistance totem]] [7467]=1, [7468]=1, [7469]=1, [15490]=1,
	--[[stoneskin totem        ]] [5873]=1, [21994]=1, [5919]=1, [5920]=1, [7366]=1, [7367]=1, [7368]=1, [15470]=1, [15474]=1,
	--[[windwall totem         ]] [9687]=1, [9688]=1, [9689]=1, [15492]=1,
	--[[strength of earth totem]] [5874]=1, [21992]=1, [5921]=1, [5922]=1, [7403]=1, [15464]=1, [15479]=1,
	--[[windfury totem         ]] [6112]=1, [7483]=1, [7484]=1, [15496]=1, [15497]=1,
	--[[wrath of air totem     ]] [15447]=1,
	--[[mana spring totem      ]] [3573]=1, [7414]=1, [7415]=1, [7416]=1, [15489]=1,
	--[[healing stream totem   ]] [3527]=1, [3906]=1, [3907]=1, [3908]=1, [3909]=1, [15488]=1,
	--[[mana tide totem        ]] [10467]=1, [11100]=1, [11101]=1, [17061]=1,
	--[[disease cleansing totem]] [5924]=1,
	--[[poison cleansing totem ]] [5923]=1, [22487]=1,
	--[[tranquil air totem     ]] [15803]=1,
	--[[tremor totem           ]] [5913]=1,
}

--------------------------------------------------
-- tables used to check a spell's effect
--------------------------------------------------
local spellEffectList = {
	-- charm
	[605]=1, [1098]=1, [6358]=1, [7645]=1, [8345]=1, [10911]=1, [10912]=1, [11446]=1, [11725]=1, [11726]=1, [12888]=1, [13181]=1, [14515]=1, [15859]=1, [16053]=1, [17405]=1, [19469]=1, [20604]=1, [20740]=1, [20882]=1, [24327]=1, [26740]=1, [29490]=1, [29516]=1, [29546]=1, [30850]=1, [31865]=1, [32764]=1, [33502]=1, [35120]=1, [35280]=1, [36241]=1, [36274]=1, [36661]=1, [36866]=1, [37122]=1, [37162]=1, [37200]=1, [38626]=1, [38915]=1, [41345]=1, [43550]=1, [44547]=1, [46427]=1,
	-- disoriented
	[2094]=2, [26108]=2, [42805]=2,
	-- disarm
	[676]=3, [5259]=3, [6608]=3, [6713]=3, [8379]=3, [10851]=3, [11879]=3, [13534]=3, [14180]=3, [15752]=3, [22419]=3, [22691]=3, [23365]=3, [25057]=3, [25655]=3, [27581]=3, [30013]=3, [31955]=3, [33126]=3, [35055]=3, [36207]=3, [36208]=3, [36209]=3, [36510]=3, [39489]=3, [41054]=3, [45205]=3, [45206]=3,
	-- fear
	[1513]=5, [3109]=5, [5134]=5, [5246]=5, [5484]=5, [5782]=5, [6213]=5, [6215]=5, [6605]=5, [7093]=5, [7399]=5, [8122]=5, [8124]=5, [8225]=5, [8715]=5, [10888]=5, [10890]=5, [12096]=5, [12542]=5, [13704]=5, [14100]=5, [14326]=5, [14327]=5, [16096]=5, [16508]=5, [17928]=5, [18431]=5, [19134]=5, [19408]=5, [20511]=5, [21330]=5, [21869]=5, [21898]=5, [22678]=5, [22686]=5, [22884]=5, [23275]=5, [25260]=5, [25815]=5, [26042]=5, [26070]=5, [26580]=5, [26641]=5, [26661]=5, [27610]=5, [27641]=5, [27990]=5, [28315]=5, [29168]=5, [29321]=5, [29419]=5, [29544]=5, [29685]=5, [30002]=5, [30530]=5, [30584]=5, [30615]=5, [30752]=5, [31013]=5, [31358]=5, [31365]=5, [31404]=5, [31970]=5, [32040]=5, [32241]=5, [32421]=5, [33547]=5, [33789]=5, [33829]=5, [33924]=5, [34259]=5, [34322]=5, [35198]=5, [35474]=5, [36629]=5, [36922]=5, [36950]=5, [37939]=5, [38154]=5, [38258]=5, [38595]=5, [38660]=5, [38945]=5, [38946]=5, [39048]=5, [39119]=5, [39176]=5, [39210]=5, [39415]=5, [39427]=5, [40221]=5, [40454]=5, [40636]=5, [41150]=5, [41436]=5, [42690]=5, [43432]=5, [43590]=5, [44863]=5, [46561]=5,
	-- root
	[113]=7, [339]=7, [512]=7, [745]=7, [1062]=7, [3542]=7, [4962]=7, [5195]=7, [5196]=7, [5567]=7, [6533]=7, [8142]=7, [8312]=7, [8346]=7, [8377]=7, [9852]=7, [9853]=7, [9915]=7, [10017]=7, [10852]=7, [11264]=7, [11820]=7, [11831]=7, [11922]=7, [12023]=7, [12024]=7, [12252]=7, [12494]=7, [12674]=7, [12747]=7, [12748]=7, [13099]=7, [13119]=7, [13138]=7, [13608]=7, [14030]=7, [14907]=7, [15063]=7, [15474]=7, [15531]=7, [15532]=7, [15609]=7, [16469]=7, [16566]=7, [19185]=7, [19229]=7, [19970]=7, [19971]=7, [19972]=7, [19973]=7, [19974]=7, [19975]=7, [20654]=7, [20699]=7, [21331]=7, [22127]=7, [22415]=7, [22519]=7, [22645]=7, [22744]=7, [22800]=7, [22924]=7, [22994]=7, [23694]=7, [24110]=7, [24648]=7, [25999]=7, [26071]=7, [26989]=7, [27010]=7, [28297]=7, [28858]=7, [28991]=7, [29849]=7, [29991]=7, [30094]=7, [31287]=7, [31290]=7, [31409]=7, [31983]=7, [32173]=7, [32192]=7, [32365]=7, [32859]=7, [33844]=7, [34326]=7, [34725]=7, [34740]=7, [34746]=7, [34779]=7, [34782]=7, [35107]=7, [35234]=7, [35247]=7, [35831]=7, [35963]=7, [36786]=7, [36827]=7, [36989]=7, [37480]=7, [37823]=7, [38033]=7, [38051]=7, [38316]=7, [38338]=7, [38661]=7, [38843]=7, [38900]=7, [38912]=7, [39035]=7, [39063]=7, [39584]=7, [40082]=7, [40333]=7, [40363]=7, [40727]=7, [41580]=7, [43362]=7, [43426]=7, [43585]=7, [44177]=7, [45825]=7, [45905]=7, [46555]=7, [47168]=7, [50762]=7,
	-- silence
	[1330]=9, [3589]=9, [6726]=9, [6942]=9, [7074]=9, [8281]=9, [8988]=9, [9552]=9, [12528]=9, [12946]=9, [15487]=9, [16838]=9, [18278]=9, [18327]=9, [18425]=9, [18469]=9, [18498]=9, [19393]=9, [19821]=9, [22666]=9, [23207]=9, [23918]=9, [24259]=9, [24687]=9, [25046]=9, [26069]=9, [27559]=9, [28730]=9, [29505]=9, [29904]=9, [29943]=9, [30225]=9, [30849]=9, [31015]=9, [31069]=9, [31273]=9, [31344]=9, [33390]=9, [33686]=9, [33913]=9, [34087]=9, [34088]=9, [34089]=9, [34922]=9, [35892]=9, [36022]=9, [36297]=9, [37031]=9, [37160]=9, [38491]=9, [38913]=9, [39052]=9, [40823]=9, [42201]=9, [42205]=9,
	-- sleep
	[700]=10, [1090]=10, [2637]=10, [3636]=10, [7967]=10, [8040]=10, [8399]=10, [8901]=10, [8902]=10, [9159]=10, [12098]=10, [15822]=10, [15970]=10, [16798]=10, [18657]=10, [18658]=10, [19386]=10, [20663]=10, [20669]=10, [20989]=10, [24004]=10, [24132]=10, [24133]=10, [24335]=10, [24360]=10, [27068]=10, [28504]=10, [29148]=10, [29679]=10, [31292]=10, [31541]=10, [34039]=10, [34801]=10, [36333]=10, [36402]=10, [37990]=10, [38510]=10, [38886]=10, [41186]=10, [41396]=10,
	-- snare
	[89]=11, [246]=11, [3409]=11, [3600]=11, [3604]=11, [5116]=11, [5159]=11, [6136]=11, [6146]=11, [6984]=11, [7279]=11, [7321]=11, [7992]=11, [8078]=11, [8147]=11, [8716]=11, [8732]=11, [9080]=11, [9462]=11, [10855]=11, [10987]=11, [11201]=11, [11436]=11, [12323]=11, [12484]=11, [12485]=11, [12486]=11, [12531]=11, [12551]=11, [12705]=11, [13496]=11, [13747]=11, [13810]=11, [14897]=11, [15548]=11, [15588]=11, [16050]=11, [16568]=11, [17134]=11, [17165]=11, [17174]=11, [18099]=11, [18101]=11, [18118]=11, [18223]=11, [18328]=11, [18802]=11, [18972]=11, [19137]=11, [19496]=11, [22356]=11, [22639]=11, [22914]=11, [22919]=11, [23600]=11, [23931]=11, [23953]=11, [24225]=11, [24415]=11, [25022]=11, [25603]=11, [25809]=11, [26078]=11, [26141]=11, [26143]=11, [26211]=11, [26379]=11, [26554]=11, [27634]=11, [27640]=11, [27993]=11, [29292]=11, [29407]=11, [29539]=11, [29540]=11, [29570]=11, [29667]=11, [29703]=11, [29990]=11, [30035]=11, [30109]=11, [30494]=11, [30633]=11, [30981]=11, [30984]=11, [30989]=11, [31125]=11, [31257]=11, [31467]=11, [31473]=11, [31478]=11, [31553]=11, [31589]=11, [31741]=11, [32000]=11, [32013]=11, [32024]=11, [32065]=11, [32317]=11, [32417]=11, [32651]=11, [32921]=11, [32922]=11, [33061]=11, [33628]=11, [33967]=11, [35032]=11, [35101]=11, [35240]=11, [35244]=11, [35263]=11, [35351]=11, [35493]=11, [35507]=11, [35542]=11, [35545]=11, [35546]=11, [35547]=11, [35548]=11, [35919]=11, [36148]=11, [36214]=11, [36414]=11, [36415]=11, [36416]=11, [36417]=11, [36448]=11, [36457]=11, [36458]=11, [36464]=11, [36474]=11, [36475]=11, [36508]=11, [36518]=11, [36580]=11, [36659]=11, [36706]=11, [36824]=11, [36839]=11, [36843]=11, [36974]=11, [37276]=11, [37330]=11, [37359]=11, [37478]=11, [37591]=11, [37621]=11, [37654]=11, [37986]=11, [38243]=11, [38256]=11, [38262]=11, [38537]=11, [38663]=11, [38767]=11, [38821]=11, [38822]=11, [38880]=11, [38985]=11, [38986]=11, [38987]=11, [38988]=11, [38989]=11, [38990]=11, [38995]=11, [39049]=11, [39538]=11, [39665]=11, [39900]=11, [41086]=11, [41264]=11, [41978]=11, [42396]=11, [43130]=11, [43131]=11, [43357]=11, [43530]=11, [43583]=11, [44033]=11, [44120]=11, [44289]=11, [45195]=11, [46434]=11, [46745]=11, [47106]=11,
	-- stun
	[45]=12, [56]=12, [408]=12, [835]=12, [853]=12, [1833]=12, [2880]=12, [3143]=12, [3242]=12, [3263]=12, [3446]=12, [3551]=12, [3609]=12, [3635]=12, [5106]=12, [5164]=12, [5211]=12, [5276]=12, [5403]=12, [5530]=12, [5588]=12, [5589]=12, [5648]=12, [5649]=12, [5703]=12, [5708]=12, [5918]=12, [6253]=12, [6266]=12, [6304]=12, [6409]=12, [6435]=12, [6466]=12, [6524]=12, [6607]=12, [6728]=12, [6730]=12, [6749]=12, [6798]=12, [6927]=12, [6945]=12, [6982]=12, [7139]=12, [7803]=12, [7922]=12, [7964]=12, [8150]=12, [8151]=12, [8208]=12, [8242]=12, [8285]=12, [8391]=12, [8643]=12, [8646]=12, [8983]=12, [10308]=12, [10856]=12, [11020]=12, [11428]=12, [11430]=12, [11650]=12, [11836]=12, [11876]=12, [12355]=12, [12461]=12, [12734]=12, [12798]=12, [12809]=12, [13005]=12, [13237]=12, [13902]=12, [14102]=12, [14902]=12, [15239]=12, [15269]=12, [15283]=12, [15398]=12, [15535]=12, [15593]=12, [15618]=12, [15621]=12, [15652]=12, [15655]=12, [15743]=12, [15753]=12, [15847]=12, [15878]=12, [16075]=12, [16104]=12, [16350]=12, [16497]=12, [16600]=12, [16727]=12, [16740]=12, [16790]=12, [16803]=12, [16869]=12, [16922]=12, [17011]=12, [17276]=12, [17286]=12, [17293]=12, [17308]=12, [17500]=12, [18093]=12, [18103]=12, [18144]=12, [18395]=12, [18763]=12, [18812]=12, [19128]=12, [19136]=12, [19364]=12, [19410]=12, [19482]=12, [19641]=12, [19780]=12, [19798]=12, [20170]=12, [20276]=12, [20277]=12, [20310]=12, [20549]=12, [20683]=12, [20685]=12, [21099]=12, [21152]=12, [21748]=12, [21749]=12, [21808]=12, [21990]=12, [22289]=12, [22427]=12, [22592]=12, [22692]=12, [22915]=12, [23103]=12, [23364]=12, [23454]=12, [23919]=12, [24213]=12, [24333]=12, [24375]=12, [24394]=12, [24600]=12, [24671]=12, [25056]=12, [25189]=12, [25654]=12, [25852]=12, [27615]=12, [27758]=12, [27880]=12, [28125]=12, [28314]=12, [28445]=12, [28725]=12, [29670]=12, [29676]=12, [29690]=12, [29711]=12, [29896]=12, [30621]=12, [30688]=12, [30732]=12, [30761]=12, [30832]=12, [30986]=12, [31046]=12, [31274]=12, [31286]=12, [31367]=12, [31368]=12, [31390]=12, [31408]=12, [31422]=12, [31480]=12, [31610]=12, [31718]=12, [31719]=12, [31755]=12, [31819]=12, [31843]=12, [31864]=12, [31964]=12, [31994]=12, [32015]=12, [32023]=12, [32109]=12, [32361]=12, [32416]=12, [32588]=12, [32654]=12, [32752]=12, [32864]=12, [32905]=12, [33487]=12, [33709]=12, [33781]=12, [33792]=12, [33919]=12, [34108]=12, [34243]=12, [34267]=12, [34357]=12, [34510]=12, [34716]=12, [34752]=12, [34885]=12, [35011]=12, [35202]=12, [35238]=12, [35313]=12, [35492]=12, [35783]=12, [35856]=12, [36138]=12, [36254]=12, [36809]=12, [36835]=12, [36877]=12, [36924]=12, [36929]=12, [37012]=12, [37029]=12, [37369]=12, [37592]=12, [37991]=12, [38169]=12, [38357]=12, [38682]=12, [38737]=12, [38911]=12, [39002]=12, [39017]=12, [39021]=12, [39077]=12, [39157]=12, [39229]=12, [39313]=12, [39796]=12, [39865]=12, [40077]=12, [40184]=12, [40262]=12, [40380]=12, [40846]=12, [40864]=12, [40936]=12, [41182]=12, [41274]=12, [41356]=12, [41358]=12, [41389]=12, [41468]=12, [41534]=12, [43437]=12, [44415]=12, [44799]=12, [45065]=12, [45122]=12, [46024]=12, [46026]=12, [46183]=12, [46184]=12, [46288]=12,
	-- freeze
	[3355]=13, [14308]=13, [14309]=13, [34973]=13, [36527]=13, [36911]=13, [41590]=13, [43448]=13,
	-- knockout
	[12540]=14, [13327]=14, [13579]=14, [15091]=14, [15744]=14, [16046]=14, [17145]=14, [17277]=14, [20066]=14, [22424]=14, [23039]=14, [23113]=14, [24698]=14, [30600]=14, [30980]=14, [32779]=14, [34940]=14, [36862]=14, [38064]=14, [38863]=14,
	-- bleed
	[703]=15, [772]=15, [1079]=15, [1943]=15, [3147]=15, [4102]=15, [4244]=15, [5597]=15, [5598]=15, [6546]=15, [6547]=15, [6548]=15, [8631]=15, [8632]=15, [8633]=15, [8639]=15, [8640]=15, [8818]=15, [9007]=15, [9492]=15, [9493]=15, [9752]=15, [9824]=15, [9826]=15, [9894]=15, [9896]=15, [10266]=15, [11273]=15, [11274]=15, [11275]=15, [11289]=15, [11290]=15, [11572]=15, [11573]=15, [11574]=15, [11977]=15, [12054]=15, [12162]=15, [12721]=15, [12850]=15, [12868]=15, [13318]=15, [13443]=15, [13445]=15, [13738]=15, [14087]=15, [14118]=15, [14331]=15, [14874]=15, [14903]=15, [15583]=15, [15976]=15, [16095]=15, [16393]=15, [16403]=15, [16406]=15, [16509]=15, [17153]=15, [17504]=15, [18075]=15, [18078]=15, [18106]=15, [18200]=15, [18202]=15, [19771]=15, [21949]=15, [23256]=15, [24192]=15, [24331]=15, [24332]=15, [25208]=15, [26839]=15, [26867]=15, [26884]=15, [27007]=15, [27008]=15, [27555]=15, [27556]=15, [27638]=15, [28913]=15, [29574]=15, [29578]=15, [29583]=15, [29906]=15, [29915]=15, [29935]=15, [30069]=15, [30070]=15, [30285]=15, [30639]=15, [31041]=15, [31410]=15, [31956]=15, [32019]=15, [32901]=15, [33865]=15, [33912]=15, [35144]=15, [35321]=15, [36023]=15, [36054]=15, [36332]=15, [36383]=15, [36450]=15, [36590]=15, [36617]=15, [36789]=15, [36965]=15, [36991]=15, [37066]=15, [37487]=15, [37662]=15, [37937]=15, [37973]=15, [38056]=15, [38363]=15, [38772]=15, [38801]=15, [38810]=15, [38848]=15, [39198]=15, [39215]=15, [39382]=15, [40199]=15, [41092]=15, [41932]=15, [43093]=15, [43100]=15, [43104]=15, [43246]=15,
	-- bandage
	[746]=16, [1159]=16, [3267]=16, [3268]=16, [7926]=16, [7927]=16, [10838]=16, [10839]=16, [18608]=16, [18610]=16, [23567]=16, [23568]=16, [23569]=16, [23696]=16, [24412]=16, [24413]=16, [24414]=16, [27030]=16, [27031]=16, [30020]=16, [35207]=16, [36348]=16, [38919]=16, [40330]=16,
	-- polymorph
	[118]=17, [228]=17, [851]=17, [4060]=17, [10253]=17, [11641]=17, [12824]=17, [12825]=17, [12826]=17, [13323]=17, [14621]=17, [15534]=17, [16097]=17, [16707]=17, [16708]=17, [16709]=17, [17172]=17, [17738]=17, [18503]=17, [22274]=17, [22566]=17, [23603]=17, [24053]=17, [24708]=17, [24709]=17, [24710]=17, [24711]=17, [24712]=17, [24713]=17, [24717]=17, [24718]=17, [24719]=17, [24720]=17, [24723]=17, [24724]=17, [24732]=17, [24733]=17, [24735]=17, [24736]=17, [24737]=17, [24740]=17, [24741]=17, [26157]=17, [26272]=17, [26273]=17, [26274]=17, [27760]=17, [28271]=17, [28272]=17, [29044]=17, [29314]=17, [29848]=17, [30077]=17, [30501]=17, [30504]=17, [30506]=17, [30838]=17, [32826]=17, [33173]=17, [34639]=17, [36700]=17, [36840]=17, [38245]=17, [38896]=17, [40400]=17, [41334]=17, [43309]=17, [46280]=17, [46295]=17,
	-- banish
	[710]=18, [8994]=18, [16045]=18, [16451]=18, [18647]=18, [27565]=18, [30231]=18, [30940]=18, [31797]=18, [33786]=18, [35182]=18, [37546]=18, [38009]=18, [38456]=18, [38505]=18, [38791]=18, [39622]=18, [40578]=18, [43528]=18, [44765]=18,
	-- shield
	[17]=19, [592]=19, [600]=19, [3747]=19, [6065]=19, [6066]=19, [6788]=19, [10898]=19, [10899]=19, [10900]=19, [10901]=19, [20706]=19, [22752]=19, [25217]=19, [25218]=19, [27607]=19, [32504]=19, [34788]=19, [41363]=19, [44175]=19, [44291]=19, [46193]=19,
	-- turn
	[2878]=23, [5627]=23, [10326]=23, [32724]=23, [32725]=23, [35774]=23, [35775]=23, [45350]=23, [45352]=23,
	-- horror
	[33130]=24, [34984]=24,
	-- daze
	[32674]=27, [32774]=27, [35853]=27, [37554]=27, [38631]=27, [40019]=27, [46873]=27,
	-- immune shield
	[498]=29, [642]=29, [1020]=29, [1022]=29, [5573]=29, [5599]=29, [10278]=29, [27619]=29, [41367]=29, [45438]=29, [46604]=29,
	-- sapped
	[2070]=30, [6770]=30, [11297]=30,
}

-- a table to look up which events to use and which indice to use in eventData.playerSpellEffects
local spellEffectLookup = {
	[1]  = {10, "CharmBegin",     "CharmEnd"},
	[2]  = {7,  "DisorientBegin", "DisorientEnd"},
	[3]  = {17, "DisarmBegin",    "DisarmEnd"},
	[5]  = {5,  "FearBegin",      "FearEnd"},
	[7]  = {4,  "RootBegin",      "RootEnd"},
	[9]  = {11, "SilenceBegin",   "SilenceEnd"},
	[10] = {12, "SleepBegin",     "SleepEnd"},
	[11] = {8,  "SnareBegin",     "SnareEnd"},
	[12] = {1,  "StunBegin",      "StunEnd"},
	[13] = {13, "FreezeBegin",    "FreezeEnd"},
	[15] = {3,  "BleedBegin",     "BleedEnd"},
	[16] = {15, "BandageBegin",   "BandageEnd"},
	[17] = {5,  "PolymorphBegin", "PolymorphEnd"},
	[18] = {6,  "BanishBegin",    "BanishEnd"},
	[19] = {16, "ShieldBegin",    "ShieldEnd"},
	[29] = {14, "ImmunityBegin",  "ImmunityEnd"},
	[30] = {9,  "SappedBegin",    "SappedEnd"},
}
spellEffectLookup[14] = spellEffectLookup[12] -- knockout to stun
spellEffectLookup[23] = spellEffectLookup[4]  -- turn to fear
spellEffectLookup[24] = spellEffectLookup[4]  -- horror to fear
spellEffectLookup[27] = spellEffectLookup[11] -- daze to snare

-- return true if the player has any kind of incapacitating effect (stun/knockout/fear/etc) on them
local function IsPlayerIncapacitated()
	local e = eventData.playerSpellEffects
	return (e[1] > 0 or e[2] > 0 or e[4] > 0 or e[5] > 0 or e[6] > 0 or e[7] > 0 or e[9] > 0 or e[10] > 0 or e[12] > 0 or e[13] > 0)
end

----------------------------------------------------------------------------------------------------
-- set up events
----------------------------------------------------------------------------------------------------
local eventList = {
	"AUCTION_HOUSE_CLOSED",
	"AUCTION_HOUSE_SHOW",
	"AUTOFOLLOW_BEGIN",
	"AUTOFOLLOW_END",
	"BANKFRAME_CLOSED",
	"BANKFRAME_OPENED",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"DUEL_REQUESTED",
	"GUILDBANKFRAME_CLOSED",
	"GUILDBANKFRAME_OPENED",
	"LOOT_CLOSED",
	"LOOT_OPENED",
	"MAIL_CLOSED",
	"MAIL_SHOW",
	"MERCHANT_CLOSED",
	"MERCHANT_SHOW",
	"MINIMAP_PING",
	"MIRROR_TIMER_START", -- timer bar starts for breath/fatigue/etc
	"MIRROR_TIMER_STOP",  -- timer bar ends for breath/fatigue/etc
	"PARTY_MEMBERS_CHANGED",
	"PLAYER_ALIVE",
	"PLAYER_CONTROL_GAINED",
	"PLAYER_CONTROL_LOST",
	"PLAYER_DEAD",
	"PLAYER_ENTERING_WORLD", -- for SummonAcceptAfter
	"PLAYER_LEAVING_WORLD",  -- for SummonAcceptAfter
	"PLAYER_REGEN_DISABLED", -- entering combat
	"PLAYER_REGEN_ENABLED",  -- exiting combat
	"PLAYER_TARGET_CHANGED",
	"PLAYER_UNGHOST",
	"READY_CHECK",
	"READY_CHECK_CONFIRM",
	"TAXIMAP_CLOSED",
	"TAXIMAP_OPENED",
	"TRADE_ACCEPT_UPDATE",
	"TRADE_CLOSED",
	"TRADE_SHOW",
	"UNIT_HEALTH",
	"UNIT_MANA",
	"UNIT_RAGE",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_SENT", -- for saving the target name since SPELLCAST_START won't give it
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UPDATE_INVENTORY_DURABILITY",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
}

-- register all events that need to be watched
local function RegisterReactionsEvents()
	reactionFrame:SetScript("OnUpdate", Reactions_OnUpdate)
	-- non-chat events
	for i=1,#eventList do
		reactionFrame:RegisterEvent(eventList[i])
	end
	-- chat events
	for name in pairs(channelData) do
		if name == "UI_ERROR_MESSAGE" then -- no CHAT_MSG_ before this
			reactionFrame:RegisterEvent(name)
		else
			reactionFrame:RegisterEvent("CHAT_MSG_" .. name)
		end
	end
end

-- unregister all the events that need to be watched
local function UnregisterReactionsEvents()
	reactionFrame:SetScript("OnUpdate", nil)
	-- non-chat events
	for i=1,#eventList do
		reactionFrame:UnregisterEvent(eventList[i])
	end
	-- chat events
	for name in pairs(channelData) do
		if name == "UI_ERROR_MESSAGE" then -- no CHAT_MSG_ before this
			reactionFrame:UnregisterEvent(name)
		else
			reactionFrame:UnregisterEvent("CHAT_MSG_" .. name)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- handle chat events
----------------------------------------------------------------------------------------------------
local function Reactions_OnEventChat(chatType, message, author, language, channelDescription)
	ClearMessageNames()

	local channelInformation = channelData[chatType]
	if not channelInformation then
		return
	end

	local triggerList = channelInformation[2]
	currentChatChannel = channelInformation[1]
	currentChatMessage, messageTargetName = message, author
	if currentChatChannel == "channel" then
		currentChatChannelNumber, currentChatChannel = match(channelDescription, "^(%d+)%. (.+)")
	else
		currentChatChannelNumber = nil
	end

	local trigger
	local triggerName
	local lowercaseMessage = lower(gsub(message, "^%s*(.-)%s*$", "%1"))
	local isFriend       = nil -- nil if not checked, true/false if the target was/wasn't on the friends list
	local isGuildMember = nil -- nil if not checked, true/false if the target was/wasn't in the same guild
	for i=1,#triggerList do
		repeat -- to be able to use "break" like "continue"
			triggerName = triggerList[i]
			trigger = chatList[triggerName]
			if not trigger then
				break
			end

			-- check if it's yourself
			if (author == messagePlayerName and not trigger.matchYourself) then
				break
			end

			-- check if it's in a group that's disabled
			if (trigger.group and not groupList[trigger.group]) or (not trigger.group and not groupList["Ungrouped"]) then
				break
			end

			-- check chance
			if trigger.chance ~= 100 and trigger.chance < random() * 100 then
				break
			end

			-- check cooldown time
			if trigger.globalCooldown and trigger.lastUsed and trigger.lastUsed > time() - trigger.globalCooldown then
				break
			end
			if trigger.personCooldown and trigger.personCooldownList and trigger.personCooldownList[author]
				and trigger.personCooldownList[author] > time() - trigger.personCooldown then
				break
			end

			-- check if they're allowed to have matches
			if author ~= ""
			 and (not trigger.matchGuild or not trigger.matchOthers or not trigger.matchFriends)
			 and (not trigger.matchYourself or author ~= messagePlayerName) then
				-- only look them up if nil - the results are saved for any other triggers
				if isGuildMember == nil then
					if IsInGuild() then
						isGuildMember = false
						for i=1,GetNumGuildMembers() do
							if author == GetGuildRosterInfo(i)  then
								isGuildMember = true
								break
							end
						end
					end
				end
				if isFriend == nil then
					isFriend = false
					for i=1,GetNumFriends() do
						if author == GetFriendInfo(i) then
							isFriend = true
							break
						end
					end
				end

				if  (trigger.matchGuild and isGuildMember)
				 or (trigger.matchFriends and isFriend)
				 or (trigger.matchOthers and not isFriend and not isGuildMember) then
					-- do nothing here since they're allowed - just easier to visualize it this way
				else
					break
				end
			end

			-- perform message modifications
			local modifiedMessage = trigger.removeCapitalization and lowercaseMessage or message
			if trigger.removePunctuation then
				modifiedMessage = gsub(modifiedMessage, "%p+", ""):gsub("%s+", " ") -- also fix extra leftover spaces to be one space
			end
			if trigger.plainTextLinks then
				modifiedMessage = gsub(modifiedMessage, "|c.-(%[.-])|h|r", "%1") -- convert a link to be only the [text] part
			end

			-- check phrases for a match
			local customLuaTableSet = false
			local matched = false
			if trigger.phraseMatches then
				local phraseList = trigger.phraseMatches
				for i=1,#phraseList do
					-- before matching, surround the pattern with () (except the beginning ^ end ending $) so there will always be at least one capture available
					-- changed to reuse the same table - not for speed because that's unnoticeable even with millions of patterns checked, but just to make fewer tables to clean up (which is probably unnoticeable too)
					--customLuaTable.capture = {match(modifiedMessage, gsub(phraseList[i], "^([%^]?)(.-)([$]?)$", "%1(%2)%3"))}
					customLuaCapture[1], customLuaCapture[2], customLuaCapture[3], customLuaCapture[4], customLuaCapture[5], customLuaCapture[6],
					customLuaCapture[7], customLuaCapture[8], customLuaCapture[9], customLuaCapture[10], customLuaCapture[11], customLuaCapture[12],
					customLuaCapture[13], customLuaCapture[14], customLuaCapture[15] = match(modifiedMessage, gsub(phraseList[i], "^([%^]?)(.-)([$]?)$", "%1(%2)%3"))
					if customLuaCapture[1] ~= nil then
						matched = true
						break
					end
				end
			end

			-- check custom lua function for match
			if not matched and trigger.luaMatch then
				if not trigger.luaMatchFunc then
					local func, errorMessage = loadstring(trigger.luaMatch)
					if errorMessage then
						DEFAULT_CHAT_FRAME:AddMessage("Error in lua matching in chat trigger " .. triggerName .. ": " .. errorMessage)
						func = nil
					else
						trigger.luaMatchFunc = func
					end
				end
				if trigger.luaMatchFunc then
					for i=1,15 do
						customLuaCapture[i] = nil
					end
					customLuaTable.message = message
					customLuaTable.modifiedMessage = modifiedMessage
					customLuaTable.target = author
					customLuaTable.channel = currentChatChannel
					customLuaTable.channelNumber = currentChatChannelNumber
					customLuaTableSet = true
					matched = trigger.luaMatchFunc()
				end
			end

			-- reacting to a match
			if matched then
				if not customLuaTableSet then
					customLuaTable.message = message
					customLuaTable.modifiedMessage = modifiedMessage
					customLuaTable.target = author
					customLuaTable.channel = currentChatChannel
					customLuaTable.channelNumber = currentChatChannelNumber
				end

				-- using a message
				if trigger.useReply then
					if trigger.replyChannel == "Spell/Event" then
						AttemptReaction(trigger.useReply, 0, nil, messagePlayerName, author, ActionType.HIT, nil, nil, nil, nil, 1)
					else
						local channel
						if trigger.replyChannel == "Same Channel" and currentChatChannelNumber then
							channel = currentChatChannelNumber
						else
							channel = trigger.replyChannel == "Same Channel" and currentChatChannel or trigger.replyChannel
						end
						ParseAndSendMessage(trigger.useReply, channel, author)
					end
				end

				-- using custom lua
				if trigger.luaReaction then
					if not trigger.luaReactionFunc then
						local func, errorMessage = loadstring(trigger.luaReaction)
						if errorMessage then
							DEFAULT_CHAT_FRAME:AddMessage("Error in lua reaction in chat trigger " .. triggerName .. ": " .. errorMessage)
							func = nil
						else
							trigger.luaReactionFunc = func
						end
					end
					if trigger.luaReactionFunc then
						if mainSettings.testing then
							DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFE0Reactions:|r Custom lua on chat trigger " .. triggerName)
						else
							trigger.luaReactionFunc()
						end
					end
				end

				-- set last used times since the message was successful
				if trigger.globalCooldown then
					trigger.lastUsed = time()
				end
				if trigger.personCooldown and author then
					if trigger.personCooldownList == nil then
						trigger.personCooldownList = {}
					end
					trigger.personCooldownList[author] = time()
				end

				-- cancel checking other triggers if wanted
				if trigger.stopTriggers then
					return
				end
			end -- if matched then
		until true -- repeat
	end -- for i=1,#triggerList do
end

----------------------------------------------------------------------------------------------------
-- handle the events
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- jump
--------------------------------------------------
hooksecurefunc("JumpOrAscendStart", function()
	if not IsFalling() and not IsFlying() and not IsPlayerIncapacitated() and not IsSwimming() and not UnitOnTaxi("player") then
		AttemptReaction("Jump", 0, nil, messagePlayerName, nil, ActionType.HIT)
	end
end)

--------------------------------------------------
-- focus friend/enemy
--------------------------------------------------
hooksecurefunc("FocusUnit", function()
	local name = UnitName("focus")
	if name and name ~= "Unknown" then
		AttemptReaction(UnitIsFriend("player", "focus") and "FocusFriend" or "FocusEnemy", 0, nil, name, nil, ActionType.HIT)
	end
end)

--------------------------------------------------
-- backpedal
--------------------------------------------------
hooksecurefunc("MoveBackwardStart", function()
	if not IsFalling() and not IsFlying() and not IsPlayerIncapacitated() and not IsSwimming() and not UnitOnTaxi("player") then
		AttemptReaction("Backpedal", 0, nil, messagePlayerName, nil, ActionType.HIT)
	end
end)

--------------------------------------------------
-- destroy item
--------------------------------------------------
local DeleteCursorItemOriginal = DeleteCursorItem
DeleteCursorItem = function()
	local infoType, _, link = GetCursorInfo()
	if infoType == "item" then
		AttemptReaction("DestroyItem", 0, nil, messagePlayerName, link, ActionType.HIT)
	end
	DeleteCursorItemOriginal()
end

--------------------------------------------------
-- repairing
--------------------------------------------------
local RepairAllItemsOriginal = RepairAllItems
RepairAllItems = function(guildBankRepair)
	local cost, canRepair = GetRepairAllCost()
	if canRepair and cost <= GetMoney() then
		AttemptReaction("RepairItems", 0, nil, messagePlayerName, UnitName("npc"), ActionType.HIT)
	end
	RepairAllItemsOriginal(guildBankRepair)
end

--------------------------------------------------
-- logout start/instantly
--------------------------------------------------
local LogoutOriginal = Logout
Logout = function()
	if not UnitAffectingCombat("player") and not IsFalling() and not UnitOnTaxi("player") then
		AttemptReaction(IsResting() and "LogoutInstant" or "LogoutStart", 0, nil, messagePlayerName, nil, ActionType.HIT)
	end
	LogoutOriginal()
end
local QuitOriginal = Quit
Quit = function()
	if not UnitAffectingCombat("player") and not IsFalling() and not UnitOnTaxi("player") then
		AttemptReaction(IsResting() and "LogoutInstant" or "LogoutStart", 0, nil, messagePlayerName, nil, ActionType.HIT)
	end
	QuitOriginal()
end

--------------------------------------------------
-- summon accept before/after, cancel
--------------------------------------------------
-- To be able to use a reaction after taking the summon, the GetTime() of accepting it is saved.
-- For short non-loading summons, if a ZONE_CHANGED event happens in less than a second of that time
-- then SummonAcceptAfter is used. For longer summons, if the PLAYER_LEAVING_WORLD event happens in
-- less than a second, then acceptSummonTime is set to 1. When PLAYER_ENTERING_WORLD happens, if it
-- is set to 1 then SummonAcceptAfter is used.
local acceptSummonTime = 0

local ConfirmSummonOriginal = ConfirmSummon
ConfirmSummon = function()
	if not UnitAffectingCombat("player") and not UnitOnTaxi("player") and GetSummonConfirmTimeLeft() > 0 then
		AttemptReaction("SummonAcceptBefore", 0, nil, messagePlayerName, GetSummonConfirmSummoner(), ActionType.HIT)
		acceptSummonTime = GetTime()
	end
	ConfirmSummonOriginal()
end
local CancelSummonOriginal = CancelSummon
CancelSummon = function()
	if GetSummonConfirmTimeLeft() > 0 then
		AttemptReaction("SummonCancel", 0, nil, messagePlayerName, GetSummonConfirmSummoner(), ActionType.HIT)
	end
	CancelSummonOriginal()
end

--------------------------------------------------
-- taxi flight begin
--------------------------------------------------
hooksecurefunc("TakeTaxiNode", function(index)
	-- Change the full location name to something reasonable - a list of them is in the notes file.
	-- I think only normal non-quest flights go through this function, but since I can't check them
	-- all, all the names will be fixed here just in case! If discovering a good way to detect quest
	-- flights happens, then this can be moved out to a function that taxis and that can use.
	local fullName = TaxiNodeName(index) or ""
	local finalName
	local isQuest = select(2, find(fullName, "Quest %- "))

	-- quest flights like "Quest - Netherstorm - Manaforge Ultris (Start)" to "Manaforge Ultris"
	if isQuest then
		-- remove the opening "*Quest - " part. "Quest" doesn't have to start at the beginning
		finalName = sub(fullName, isQuest + 1)
		-- remove certain endings like "(Second Pass)" or " - End"
		local endPlace = find(finalName, " %(") or find(finalName, " %- End") or find(finalName, " %- Start") or
							  find(finalName, " Start") or find(finalName, " End")
		if endPlace then
			finalName = sub(finalName, 1, endPlace - 1)
		end
		-- if it's now like "Zone - Location", then remove the Zone part
		finalName = match(finalName, "[%w%s' ]?%- (.+)") or finalName
	-- special case for the Halaa flights
	elseif find(fullName, "^Nagrand %- PvP") then
		finalName = "bomb Halaa"
	-- special case for this one rude name that is probably missing "Quest - " at the beginning
	elseif fullName == "Eversong - Duskwither Teleport End" then
		finalName = "The Duskwither Teleport"
	-- all other non-quest or special case names
	else
		-- for names like "location, zone" remove the 2nd part to remove the zone
		finalName = match(fullName, "([^,]+).*")
		-- special case for "Hellfire Peninsula, The Dark Portal, Horde/Alliance"
		if finalName == "Hellfire Peninsula" then
			finalName = "The Dark Portal"
		-- names starting with Transport or Generic should be the opposite: show the 2nd part instead
		-- single part names like "Moonglade" or "Shattered Sun Staging Area" won't be changed
		elseif finalName == "Transport" or finalName == "Generic" then
			finalName = match(fullName, "%w, ([^%(]+).*")
		end
	end

	flightLocationName = finalName or "parts unknown" -- saved so FlightMasterFlightLand can use it for <target_name>
	AttemptReaction("FlightMasterFlightBegin", 0, nil, messagePlayerName, flightLocationName, ActionType.HIT)
	nextFlightCheck = 5 -- will check if a flight really started after 5 seconds
end)

--------------------------------------------------
-- incoming events
--------------------------------------------------
-- convert group joining/leaving messages into lua pattern matching strings
local PARTY_STRING_JOINED = "^"..JOINED_PARTY:gsub("%%s", "(%%S+)")
local PARTY_STRING_LEFT   = "^"..LEFT_PARTY:gsub("%%s", "(%%S+)")
local RAID_STRING_JOINED  = "^"..ERR_RAID_MEMBER_ADDED_S:gsub("%%s", "(%%S+)")
local RAID_STRING_LEFT    = "^"..ERR_RAID_MEMBER_REMOVED_S:gsub("%%s", "(%%S+)")
-- other localized text
local ERR_DUEL_REQUESTED  = ERR_DUEL_REQUESTED
local LIFEBLOOM           = (GetSpellInfo(33763))

-- Using all these arg1/arg2/etc parameters instead of ... and select() gives a small but measurable
-- performance increase - the same with using all the "if event == something" instead of a table of
-- functions like table[event](...). Normally something being easier to read would beat a tiny
-- performance gain, but in a big addon like this that's constantly checking things I'd rather have
-- the performance!
local function Reactions_OnEvent(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20)
	--------------------------------------------------
	-- new combat event
	--------------------------------------------------
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- arg1 = timestamp (unused)
		-- arg2 = action
		-- arg3 = sourceGUID (unused)
		-- arg4 = sourceName
		-- arg5 = sourceFlags (unused)
		-- arg6 = destGUID
		-- arg7 = destName
		-- arg8 = destFlags (unused)
		-- arg9 = spellId unless noted
		-- arg10 = spellName unless noted

		-- normal attack
		if arg2 == "SWING_DAMAGE" or arg2 == "RANGE_DAMAGE" then
			if arg14 then -- critical
				if arg7 == messagePlayerName then
					AttemptReaction("CriticallyHitByNormal", 0, nil, arg7, arg4, ActionType.HIT)
				else
					AttemptReaction("CriticalHitNormal", 0, nil, arg4, arg7, ActionType.HIT)
				end
			end
			return
		end

		-- handle spells that do damage/healing when hitting - both instant and cast-time spells
		if arg2 == "SPELL_DAMAGE" or arg2 == "SPELL_HEAL" then
			-- arg12 = amount
			if arg12 > 0 and arg10 ~= LIFEBLOOM then -- lifebloom's end triggers this - ignore it
				local critical, glancing, crushing, hitType
				if arg2 == "SPELL_DAMAGE" then
					if     arg17 then hitType = "Critical"
					elseif arg18 then hitType = "Glancing"
					elseif arg19 then hitType = "Crushing"
					else              hitType = "Normal"
					end
				else
					if     arg13 then hitType = "Critical"
					elseif arg14 then hitType = "Glancing"
					elseif arg15 then hitType = "Crushing"
					else              hitType = "Normal"
					end
				end

				RemoveCastCheck(arg4, arg10)
				if not AttemptReaction(arg10, arg9, hitType, arg4, arg7, ActionType.HIT) and critical then
					-- try generic crit events - must set the current spell manually
					currentSpellName = arg10
					currentSpellId = arg9
					if arg7 == messagePlayerName then
						AttemptReaction(arg2 == "SPELL_HEAL" and "CriticallyHitByHeal" or "CriticallyHitBySpell", 0, hitType, arg7, arg4, ActionType.HIT)
					else
						AttemptReaction(arg2 == "SPELL_HEAL" and "CriticalHitHeal" or "CriticalHitSpell", 0, hitType, arg4, arg7, ActionType.HIT)
					end
				end
			end
			return
		end

		-- handle periodic damage/healing
		if arg2 == "SPELL_PERIODIC_DAMAGE" then
			local hitType
			if     arg17 then hitType = "Critical"
			elseif arg18 then hitType = "Glancing"
			elseif arg19 then hitType = "Crushing"
			else              hitType = "Normal"
			end
			AttemptReaction(arg10, arg9, hitType, arg4, arg7, ActionType.PERIODIC)
			return
		end
		if arg2 == "SPELL_PERIODIC_HEAL" then
			local hitType
			if     arg13 then hitType = "Critical"
			elseif arg14 then hitType = "Glancing"
			elseif arg15 then hitType = "Crushing"
			else              hitType = "Normal"
			end
			AttemptReaction(arg10, arg9, hitType, arg4, arg7, ActionType.PERIODIC)
			return
		end

		-- handle spells that are cast instantly and do no immediate damage/healing
		if arg2 == "SPELL_CAST_SUCCESS" then
			local spellSettings = GetSpellSettings(arg10, arg9)
			if spellSettings then
				AddCastCheck(arg4, arg7, arg10, arg9)
			end
			return
		end

		-- for spells with a cast time that do no damage - save the spell being cast and the target for UNIT_SPELLCAST_SUCCEEDED to use
		if arg2 == "SPELL_CAST_START" then
			if not eventData.usedStartCast then
				eventData.usedStartCast = true
				local spellSettings = GetSpellSettings(arg10, arg9)
				if spellSettings then
					if arg4 == messagePlayerName then
						playerCastingSpellName = arg10
						playerCastingSpellId = arg9
						-- playerCastingTarget set up during UNIT_SPELLCAST_SENT event
						AttemptReaction(arg10, arg9, nil, arg4, playerCastingTarget, ActionType.START_CAST)
					end
				end
			end
			return
		end

		-- handle procs - ignore them if the spell is currently being checked for success
		if arg2 == "SPELL_ENERGIZE" or arg2 == "SPELL_DRAIN" or arg2 == "SPELL_LEECH" then
			if not HasCastCheck(arg4, arg9) then
				AttemptReaction(arg10, arg9, nil, arg4, arg7, ActionType.HIT)
			end
			return
		end

		-- aura was added/refreshed on someone
		if arg2 == "SPELL_AURA_APPLIED" or arg2 == "SPELL_AURA_REFRESH" or arg2 == "SPELL_AURA_APPLIED_DOSE" then
			AttemptReaction(arg10, arg9, nil, arg4, arg7, ActionType.AURA_GAINED)
			if arg2 == "SPELL_AURA_APPLIED" then
				local effect = spellEffectList[arg9]
				if effect then
					local effectInfo = spellEffectLookup[effect]
					if arg7 == messagePlayerName then
						if eventData.playerSpellEffects[effectInfo[1]] == 0 then
							AttemptReaction(effectInfo[2], arg9, nil, arg4, arg7, ActionType.EVENT_AURA)
						end
						eventData.playerSpellEffects[effectInfo[1]] = eventData.playerSpellEffects[effectInfo[1]] + 1
					else
						AttemptReaction(effectInfo[2], arg9, nil, arg4, arg7, ActionType.EVENT_AURA)
					end
				end
			end
			return
		end

		-- aura was removed from someone
		if arg2 == "SPELL_AURA_REMOVED" then
			-- if they have any limitAura auras tracked, remove them
			local auras = trackedAuras[arg7]
			if auras and not HasAura(arg7, arg10) then
				auras[arg10] = nil
			end

			AttemptReaction(arg10, arg9, nil, arg4, arg7, ActionType.AURA_REMOVED)

			local effect = spellEffectList[arg9]
			if effect then
				local effectInfo = spellEffectLookup[effect]
				if arg7 == messagePlayerName then
					local effectId = effectInfo[1]
					eventData.playerSpellEffects[effectId] = eventData.playerSpellEffects[effectId] - 1
					if eventData.playerSpellEffects[effectId] < 0 then -- shouldn't happen, but just in case
						eventData.playerSpellEffects[effectId] = 0
					end
					if eventData.playerSpellEffects[effectId] == 0 then
						AttemptReaction(effectInfo[3], arg9, nil, arg4, arg7, ActionType.EVENT_AURA)
					end
				else
					AttemptReaction(effectInfo[3], arg9, nil, arg4, arg7, ActionType.EVENT_AURA)
				end
			end
			return
		end

		-- for non-damage spells there's a tiny delay before the end of the spell and considering it
		-- successful. If these happen during that tiny delay then it was a miss or resist.
		if arg2 == "SPELL_MISSED" then
			-- arg12 = miss type
			RemoveCastCheck(arg4, arg10)
			AttemptReaction(arg10, arg9, arg12, arg4, arg7, ActionType.MISS)
			return
		end

		-- interrupting someone's spell
		if arg2 == "SPELL_INTERRUPT" then
			-- arg12 = extraSpellId
			-- arg13 = extraSpellName
			currentSpellId        = arg9
			currentSpellName      = arg10
			currentExtraSpellId   = arg12
			currentExtraSpellName = arg13
			if arg7 == messagePlayerName then
				AttemptReaction("Interrupted", 0, nil, arg7, arg4, ActionType.HIT)
			else
				AttemptReaction("Interrupting", 0, nil, arg4, arg7, ActionType.HIT)
			end
			return
		end

		-- handle some spells that create or summon things
		if arg2 == "SPELL_CREATE" or arg2 == "SPELL_SUMMON" then
			AttemptReaction(arg10, arg9, nil, arg4, arg7, ActionType.HIT)
			return
		end

		-- killing blow by you or someone in the group - doesn't work for other raid subgroups
		if arg2 == "PARTY_KILL" then
			-- find someone looking at the mob (or same-named one) to figure out if it's a boss or not
			local classification = bossList[arg7] and "worldboss"
			if not classification then
				if UnitName("target") == arg7 then
					classification = UnitClassification("target")
				else
					if GetNumRaidMembers() > 0 then
						for i=1,40 do
							if UnitName("raid" .. i .. "target") == arg7 then
								classification = UnitClassification("party" .. i .. "target")
								break
							end
						end
					else
						for i=1,4 do
							if UnitName("party" .. i .. "target") == arg7 then
								classification = UnitClassification("party" .. i .. "target")
								break
							end
						end
					end
				end
			end
			if classification then
				if classification == "worldboss" then
					AttemptReaction("KillingBlowBoss", 0, nil, arg4, arg7, ActionType.HIT)
				else
					AttemptReaction("KillingBlow", 0, nil, arg4, arg7, ActionType.HIT)
				end
			end
			return
		end

		-- something died
		if arg2 == "UNIT_DIED" then
			-- specific named deaths first
			if AttemptReaction(arg7, 0, nil, messagePlayerName, arg7, ActionType.HIT) then
				return
			end

			-- generic death events if no specific name was found to react to
			-- get the NPC ID of the creature to check if it's a totem or similar object
			local targetId = tonumber(sub(arg6, 9, 12), 16)
			if targetId ~= 0 and totemMobList[targetId] then
				AttemptReaction("DeathTotem", 0, nil, arg7, nil, ActionType.HIT)
			else
				if arg7 == messagePlayerName then
					eventData.onLowHealth = 0
					eventData.onLowMana   = 0
				end
				AttemptReaction("Death", 0, nil, arg7, nil, ActionType.HIT)
			end

			trackedAuras[arg7] = nil
			return
		end

		-- someone took environmental damage - slime/fatigue not tracked because they're broken/rare
		if arg2 == "ENVIRONMENTAL_DAMAGE" then
			-- arg9 = damageType
			-- arg10 = damageAmount
			if arg9 then
				local eventType = nil
				local health = UnitHealth(arg7)
				local death = (health and arg10 >= health)
				if arg9 == "FALLING" then
					if death then
						eventType = "EnvironmentFallDeath"
					else
						-- only show if losing a certain health pencentage (or amount if that can't be seen)
						local max = UnitHealthMax(arg7)
						if max then
							if arg10 * 100 / max < 30 then
								return
							end
						elseif arg10 < 1800 then
							return
						end
						eventType = "EnvironmentFall"
					end
				elseif arg9 == "FIRE" then
					eventType = death and "EnvironmentFireDeath" or "EnvironmentFire"
				elseif arg9 == "LAVA" then
					eventType = death and "EnvironmentLavaDeath" or "EnvironmentLava"
				elseif arg9 == "SLIME" then
					eventType = death and "EnvironmentSlimeDeath" or "EnvironmentSlime"
				elseif arg9 == "DROWNING" then
					eventType = death and "EnvironmentDrownDeath" or "EnvironmentDrown"
				end

				if eventType then
					AttemptReaction(eventType, 0, nil, arg7, nil, ActionType.HIT)
				end
			end
			return
		end
		return
	end -- if event == "COMBAT_LOG_EVENT_UNFILTERED" then

	--------------------------------------------------
	-- health / mana / rage
	--------------------------------------------------
	if event == "UNIT_HEALTH" then
		if arg1 == "player" then
			local percent = floor(UnitHealth("player") / UnitHealthMax("player") * 100)
			if eventData.onLowHealth then
				if percent < eventData.onLowHealth then
					eventData.onLowHealth = percent
					AttemptReaction("LowHealthLower", 0, nil, messagePlayerName, nil, ActionType.HIT)
				elseif percent >= mainSettings.lowHealthEnd then
					eventData.onLowHealth = nil
					AttemptReaction("LowHealthEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
				end
			elseif percent <= mainSettings.lowHealthBegin then
				eventData.onLowHealth = percent
				AttemptReaction("LowHealthBegin", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
		return
	end

	if event == "UNIT_MANA" then
		if arg1 == "player" and UnitPowerType("player") == SPELL_POWER_MANA then
			local percent = floor(UnitMana("player") / UnitManaMax("player") * 100)
			if eventData.onLowMana then
				if percent < eventData.onLowMana then
					eventData.onLowMana = percent
					AttemptReaction("LowManaLower", 0, nil, messagePlayerName, nil, ActionType.HIT)
				elseif percent >= mainSettings.lowManaEnd then
					eventData.onLowMana = nil
					AttemptReaction("LowManaEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
				end
			elseif percent <= mainSettings.lowManaBegin then
				eventData.onLowMana = percent
				AttemptReaction("LowManaBegin", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
		return
	end

	if event == "UNIT_RAGE" then
		-- arg1 = unitID
		if UnitMana(arg1) == 100 and UnitPowerType(arg1) == SPELL_POWER_RAGE then
			AttemptReaction("FullRage", 0, nil, UnitName(arg1), nil, ActionType.HIT)
		end
		return
	end

	--------------------------------------------------
	-- more spell casting handling
	--------------------------------------------------
	-- handle spells with a cast time that do no damage
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		eventData.usedStartCast = false
		-- arg1 = unitID
		-- arg2 = spellName
		-- arg3 = rank
		if arg1 == "player" then
			if playerCastingSpellName == arg2 then
				AddCastCheck(messagePlayerName, playerCastingTarget, arg2, playerCastingSpellId)
			elseif arg2 == eventData.DRINK then
				AttemptReaction("ConsumeDrink", 0, nil, messagePlayerName, nil, ActionType.HIT)
			elseif arg2 == eventData.FOOD then
				AttemptReaction("ConsumeFood", 0, nil, messagePlayerName, nil, ActionType.HIT)
			elseif arg2 == eventData.STRONG_ALCOHOL or arg2 == eventData.WEAK_ALCOHOL or arg2 == eventData.STANDARD_ALCOHOL
			 or arg2 == eventData.POTENT_ALCOHOL or arg2 == eventData.MOONGLOW_ALCOHOL or arg2 == eventData.DARK_IRON_ALCOHOL then
				AttemptReaction("ConsumeAlcohol", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
		return
	end

	-- a cast has ended
	if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		if arg1 == "player" then
			eventData.usedStartCast = false
		end
		return
	end

	-- opening an object, or save the player's target because it's not available in SPELLCAST_START events
	if event == "UNIT_SPELLCAST_SENT" then
		-- arg1 = unit casting spell
		-- arg2 = spell name
		-- arg3 = rank
		-- arg4 = target
		if arg2 == eventData.OPENING then
			AttemptReaction("OpeningWorldObject", 0, nil, messagePlayerName, arg4, ActionType.HIT)
		else
			playerCastingTarget = arg4
		end
		return
	end

	-- the player started casting a spell - most spells will use the combat event SPELL_CAST_START
	-- action first, but some won't so this has to be used. The spell ID isn't known in these cases.
	if event == "UNIT_SPELLCAST_START" then
		-- arg1 = unit casteng spell
		-- arg2 = spell name
		-- arg3 = rank
		if not eventData.usedStartCast then
			eventData.usedStartCast = true
			local spellSettings = GetSpellSettings(arg2)
			if spellSettings then
				playerCastingSpellName = arg2
				playerCastingSpellId = nil
				-- playerCastingTarget set up during UNIT_SPELLCAST_SENT event
				AttemptReaction(arg2, nil, nil, messagePlayerName, playerCastingTarget, ActionType.START_CAST)
			end
		end
		return
	end

	-- the player started or ended a channeling spell (like hurricane)
	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		-- arg1 = unitID
		-- arg2 = spell name
		if arg1 == "player" then
			AttemptReaction(arg2, 0, nil, messagePlayerName, nil, ActionType.START_CAST)
		end
		return
	end
	if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		-- arg1 = unitID
		-- arg2 = spell name
		if arg1 == "player" then
			AttemptReaction(arg2, 0, nil, messagePlayerName, nil, ActionType.CHANNEL_STOP)
		end
		return
	end

	--------------------------------------------------
	-- switching targets
	--------------------------------------------------
	if event == "PLAYER_TARGET_CHANGED" then
		local targetName = UnitName("target")
		if CheckInteractDistance("target", 1) then
			if UnitAffectingCombat("player") then -- in combat
				if UnitIsFriend("player", "target") then
					AttemptReaction((UnitIsDeadOrGhost("target") and "CombatTargetDeadFriend" or "CombatTargetFriend"), 0, nil, targetName, nil, ActionType.HIT)
				else
					AttemptReaction((UnitIsDeadOrGhost("target") and "CombatTargetDeadEnemy" or "CombatTargetEnemy"), 0, nil, targetName, nil, ActionType.HIT)
				end
			else -- not in combat
				if UnitIsFriend("player", "target") then
					AttemptReaction((UnitIsDeadOrGhost("target") and "NewTargetDeadFriend" or "NewTargetFriend"), 0, nil, targetName, nil, ActionType.HIT)
				else
					AttemptReaction((UnitIsDeadOrGhost("target") and "NewTargetDeadEnemy" or "NewTargetEnemy"), 0, nil, targetName, nil, ActionType.HIT)
				end
			end
		end
		return
	end

	--------------------------------------------------
	-- messages
	--------------------------------------------------
	local chatType = event == "UI_ERROR_MESSAGE" and event or match(event, "^CHAT_MSG_(.+)")
	if chatType then
		if chatType == "SYSTEM" and hasFullyLoggedIn then
			-- arg1 = message

			-- duel request by player - done here because the message is shown only when a request is
			-- successfully made while the Duel cast "success" can be spammed and not work.
			if arg1 == ERR_DUEL_REQUESTED then
				AttemptReaction("DuelRequest", 0, nil, messagePlayerName, playerCastingTarget, ActionType.HIT)
				return
			end

			-- group changes - PARTY_MEMBERS_CHANGED handles when you join or leave the group because
			-- these messages are too unreliable for you because the group type won't be known
			local player

			-- someone joins the group
			player = match(arg1, PARTY_STRING_JOINED)
			player = player or match(arg1, RAID_STRING_JOINED)
			if player then
				-- sometimes the message comes before they're in the group - if that happens, then set
				-- the group pending name and wait for the group changing event
				if UnitInParty(player) or UnitInRaid(player) then
					AttemptReaction("GroupJoin", 0, nil, player, nil, ActionType.HIT)
				else
					eventData.pendingGroupJoinName = player
				end
				return
			end
			-- someone leaves the group
			player = match(arg1, PARTY_STRING_LEFT)
			player = player or match(arg1, RAID_STRING_LEFT)
			if player then
				-- sometimes the message comes before they're out of the group - if that happens, then set
				-- the group pending name and wait for the group changing event
				if not UnitInParty(player) and not UnitInRaid(player) then
					AttemptReaction("GroupLeave", 0, nil, player, nil, ActionType.HIT)
				else
					eventData.pendingGroupLeaveName = player
				end
				return
			end
		end

		-- check chat triggers
		if chatType == "IGNORED" then
			RemoveFutureReactionWhispers(arg1)
			-- The message for being ignored is just their name, so make it into something to match
			Reactions_OnEventChat(chatType, string.format(CHAT_IGNORED, arg1), arg1)
		else
			Reactions_OnEventChat(chatType, arg1, arg2, arg3, arg4)
		end
		return
	end

	--------------------------------------------------
	-- entering and exiting combat
	--------------------------------------------------
	if event == "PLAYER_REGEN_DISABLED" then
		lastFightStart = GetTime()
		AttemptReaction("CombatBegin", 0, nil, messagePlayerName, nil, ActionType.HIT)
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if lastFightStart and GetTime() - lastFightStart >= mainSettings.fightLength then
			mainSettings.fightCounter = mainSettings.fightCounter + 1
		end
		AttemptReaction("CombatEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
		return
	end

	--------------------------------------------------
	-- equipment durability
	-- only use each event once until the durability is raised above the trigger amounts
	--------------------------------------------------
	if event == "UPDATE_INVENTORY_DURABILITY" then
		local lowest = GetLowestEquipmentDurability()
		if lowest then
			if lowest == 0 then
				if eventData.lowestDurability > 0 then
					AttemptReaction("DurabilityBroken", 0, nil, messagePlayerName, nil, ActionType.HIT)
				end
			elseif eventData.lowestDurability > mainSettings.lowDurability then
				if lowest <= mainSettings.lowDurability then
					AttemptReaction("DurabilityLow", 0, nil, messagePlayerName, nil, ActionType.HIT)
				end
			end
			eventData.lowestDurability = lowest
		end
		return
	end

	--------------------------------------------------
	-- looting
	--------------------------------------------------
	if event == "LOOT_OPENED" then
		-- arg1 = if autolooting
		eventData.autoLootOrTime = arg1 == 1 and 1 or GetTime()
		if eventData.autoLootOrTime == 1 then
			AttemptReaction("LootAutoloot", 0, nil, messagePlayerName, nil, ActionType.HIT)
		else
			AttemptReaction("LootOpen", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
		return
	end
	if event == "LOOT_CLOSED" then
		-- sometimes LOOT_CLOSED can come first with empty bags, so must check if autoLootOrTime
		-- was actually set first
		if eventData.autoLootOrTime and eventData.autoLootOrTime ~= 1 then
			-- closing the loot very fast triggers the CloseFast since it makes sense for messages for
			-- such speedy looting to be different! It's always possible to set a Spell/Event reaction
			-- on LootCloseFast to use LootClose if this isn't wanted.
			if GetTime() - eventData.autoLootOrTime <= 1 then
				AttemptReaction("LootCloseFast", 0, nil, messagePlayerName, nil, ActionType.HIT)
			else
				AttemptReaction("LootClose", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
		end
		eventData.autoLootOrTime = nil
		return
	end

	--------------------------------------------------
	-- losing or gaining control
	--------------------------------------------------
	if event == "PLAYER_CONTROL_GAINED" then
		if UnitAffectingCombat("player") then
			AttemptReaction("LoseControlEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
			nextLostControlCheck = 1
		end
		return
	end
	if event == "PLAYER_CONTROL_LOST" then
		if UnitAffectingCombat("player") then
			nextLostControlCheck = nil
			AttemptReaction("LoseControlStart", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
		return
	end

	--------------------------------------------------
	-- changing zone or subzone
	--------------------------------------------------
	if event == "ZONE_CHANGED_NEW_AREA" then
		if GetTime() - acceptSummonTime <= 1 then
			acceptSummonTime = 0
			AttemptReaction("SummonAcceptAfter", 0, nil, messagePlayerName, GetSummonConfirmSummoner(), ActionType.HIT)
		end
		local zone = GetRealZoneText()
		if zone and zone ~= "" and zone ~= eventData.lastZone and AttemptReaction("ChangedZone", 0, nil, messagePlayerName, nil, ActionType.HIT) then
			eventData.lastZone = zone
		end
		return
	end
	if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
		if GetTime() - acceptSummonTime <= 1 then
			acceptSummonTime = 0
			AttemptReaction("SummonAcceptAfter", 0, nil, messagePlayerName, GetSummonConfirmSummoner(), ActionType.HIT)
		end
		local subzone = GetSubZoneText()
		if subzone and subzone ~= "" and subzone ~= eventData.lastSubzone and subzone ~= GetRealZoneText and AttemptReaction("ChangedSubzone", 0, nil, messagePlayerName, nil, ActionType.HIT) then
			eventData.lastSubzone = subzone
		end
		return
	end

	if event == "PLAYER_LEAVING_WORLD" then
		if GetTime() - acceptSummonTime <= 1 then
			acceptSummonTime = 1
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		if acceptSummonTime == 1 then
			acceptSummonTime = 0
			AttemptReaction("SummonAcceptAfter", 0, nil, messagePlayerName, GetSummonConfirmSummoner(), ActionType.HIT)
		end
		return
	end

	--------------------------------------------------
	-- handle pending party member changes - only needed sometimes depending on the order of the events received
	--------------------------------------------------
	if event == "PARTY_MEMBERS_CHANGED" then
		if not inGroup then
			if not IsPartyLeader() and hasFullyLoggedIn then
				AttemptReaction("GroupJoin", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
			inGroup = true
		elseif GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then -- left the group
			inGroup = false
			-- clean up tracked auras in case any were left behind somehow
			for k,v in pairs(trackedAuras) do
				if k ~= messagePlayerName then
					trackedAuras[k] = nil
				end
			end
		end

		if eventData.pendingGroupJoinName and (UnitInParty(eventData.pendingGroupJoinName) or UnitInRaid(eventData.pendingGroupJoinName)) then
			AttemptReaction("GroupJoin", 0, nil, eventData.pendingGroupJoinName, nil, ActionType.HIT)
			eventData.pendingGroupJoinName = nil
		end
		if eventData.pendingGroupLeaveName and not UnitInParty(eventData.pendingGroupLeaveName) and not UnitInRaid(eventData.pendingGroupLeaveName) then
			AttemptReaction("GroupLeave", 0, nil, eventData.pendingGroupLeaveName, nil, ActionType.HIT)
			inGroup = (GetNumPartyMembers() ~= 0 or GetNumRaidMembers() ~= 0)
			eventData.pendingGroupLeaveName = nil
		end
		return
	end

	--------------------------------------------------
	-- underwater checking
	--------------------------------------------------
	if event == "MIRROR_TIMER_START" then
		-- arg1 = timer type
		if not isUnderwater and arg1 == "BREATH" then
			isUnderwater = true
			currentlySwimming = true
			if hasFullyLoggedIn then
				AttemptReaction("UnderwaterBegin", 0, nil, messagePlayerName, nil, ActionType.HIT)
			end
			nextSwimmingCheck = 1
		end
		return
	end
	if event == "MIRROR_TIMER_STOP" then
		-- arg1 = timer type
		if isUnderwater and arg1 == "BREATH" then
			isUnderwater = nil
			AttemptReaction("UnderwaterEnd", 0, nil, messagePlayerName, nil, ActionType.HIT)
			nextSwimmingCheck = 1
		end
		return
	end

	--------------------------------------------------
	-- opening/closing a merchant window
	--------------------------------------------------
	if event == "MERCHANT_SHOW" then
		eventData.merchantName = UnitName("npc")
		AttemptReaction("MerchantOpen", 0, nil, messagePlayerName, eventData.merchantName, ActionType.HIT)
		return
	end
	if event == "MERCHANT_CLOSED" then
		if eventData.merchantName then
			AttemptReaction("MerchantClose", 0, nil, messagePlayerName, eventData.merchantName, ActionType.HIT)
			eventData.merchantName = nil
		end
		return
	end

	--------------------------------------------------
	-- minimap ping
	--------------------------------------------------
	if event == "MINIMAP_PING" then
		-- arg1 = unitID
		-- arg2 = x
		-- arg3 = y
		if abs(arg2) <= .5 and abs(arg3) <= .5 then
			eventDirection = ""
			if     arg3 <= -0.15 then eventDirection = "south"
			elseif arg3 >= 0.15  then eventDirection = "north"
			end
			if     arg2 <= -0.15 then eventDirection = eventDirection .. "west"
			elseif arg2 >= 0.15  then eventDirection = eventDirection .. "east"
			end
			if eventDirection ~= "" then
				eventDirection = "to the " .. eventDirection
			else
				eventDirection = "nearby"
			end
			AttemptReaction("MinimapPing", 0, nil, UnitName(arg1), nil, ActionType.HIT)
		end
		return
	end

	--------------------------------------------------
	-- opening/closing bank and guild bank
	--------------------------------------------------
	if event == "BANKFRAME_OPENED" then
		AttemptReaction("BankOpen", 0, nil, messagePlayerName, UnitName("npc"), ActionType.HIT)
		return
	end
	if event == "BANKFRAME_CLOSED" then
		AttemptReaction("BankClose", 0, nil, messagePlayerName, UnitName("npc"), ActionType.HIT)
		return
	end
	if event == "GUILDBANKFRAME_OPENED" then
		AttemptReaction("GuildBankOpen", 0, nil, messagePlayerName, nil, ActionType.HIT)
		return
	end
	if event == "GUILDBANKFRAME_CLOSED" then
		AttemptReaction("GuildBankClose", 0, nil, messagePlayerName, nil, ActionType.HIT)
		return
	end

	--------------------------------------------------
	-- opening/closing mailbox
	--------------------------------------------------
	if event == "MAIL_SHOW" then
		AttemptReaction("MailboxOpen", 0, nil, messagePlayerName, nil, ActionType.HIT)
		eventData.mailboxOpened = true
		return
	end
	if event == "MAIL_CLOSED" then
		if eventData.mailboxOpened then
			eventData.mailboxOpened = nil
			AttemptReaction("MailboxClose", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
		return
	end

	--------------------------------------------------
	-- duel request by someone else
	--------------------------------------------------
	if event == "DUEL_REQUESTED" then
		-- arg1 = opponent name
		AttemptReaction("DuelRequest", 0, nil, arg1, nil, ActionType.HIT)
		return
	end

	--------------------------------------------------
	-- trading
	--------------------------------------------------
	if event == "TRADE_SHOW" then
		eventData.tradePartner = UnitName("npc")
		AttemptReaction("TradeOpen", 0, nil, messagePlayerName, eventData.tradePartner, ActionType.HIT)
		return
	end
	if event == "TRADE_ACCEPT_UPDATE" then
		-- arg1 = player - 1 if agree to trade, 0 if not
		-- arg2 = partner - 1 if agree to trade, 0 if not
		if arg1 == 1 and arg2 == 1 then
			AttemptReaction("TradeAccept", 0, nil, messagePlayerName, eventData.tradePartner, ActionType.HIT)
			eventData.tradePartner = nil
		end
		return
	end
	if event == "TRADE_CLOSED" then
		if eventData.tradePartner then
			AttemptReaction("TradeCancel", 0, nil, messagePlayerName, eventData.tradePartner, ActionType.HIT)
			eventData.tradePartner = nil
		end
		return
	end

	--------------------------------------------------
	-- opening/closing auction house
	--------------------------------------------------
	if event == "AUCTION_HOUSE_SHOW" then
		eventData.auctioneerName = UnitName("npc")
		AttemptReaction("AuctionHouseOpen", 0, nil, messagePlayerName, eventData.auctioneerName, ActionType.HIT)
		return
	end
	if event == "AUCTION_HOUSE_CLOSED" then
		if eventData.auctioneerName then
			AttemptReaction("AuctionHouseClose", 0, nil, messagePlayerName, eventData.auctioneerName, ActionType.HIT)
			eventData.auctioneerName = nil
		end
		return
	end

	--------------------------------------------------
	-- ready checks
	--------------------------------------------------
	if event == "READY_CHECK" then
		-- arg1 = name of character requesting
		AttemptReaction("ReadyCheckBegin", 0, nil, arg1, nil, ActionType.HIT)
		return
	end
	if event == "READY_CHECK_CONFIRM" then
		-- arg1 = unitID
		-- arg2 = 1 if ready, 0 if not
		local name = (GetRaidRosterInfo(arg1))
		AttemptReaction(arg2 == 1 and "ReadyCheckIsReady" or "ReadyCheckNotReady", 0, nil, name, nil, ActionType.HIT)
		return
	end

	--------------------------------------------------
	-- start/stop following another player
	--------------------------------------------------
	if event == "AUTOFOLLOW_BEGIN" then
		eventData.followingPlayer = UnitName("target")
		AttemptReaction("FollowBegin", 0, nil, messagePlayerName, eventData.followingPlayer, ActionType.HIT)
		return
	end
	if event == "AUTOFOLLOW_END" then
		AttemptReaction("FollowStop", 0, nil, messagePlayerName, eventData.followingPlayer, ActionType.HIT)
		eventData.followingPlayer = nil
		return
	end

	--------------------------------------------------
	-- opening/closing the flight master
	--------------------------------------------------
	if event == "TAXIMAP_OPENED" then
		eventData.flightMasterOpened = UnitName("npc")
		AttemptReaction("FlightMasterOpen", 0, nil, messagePlayerName, eventData.flightMasterOpened, ActionType.HIT)
		return
	end
	if event == "TAXIMAP_CLOSED" then
		if eventData.flightMasterOpened then
			AttemptReaction("FlightMasterClose", 0, nil, messagePlayerName, eventData.flightMasterOpened, ActionType.HIT)
			eventData.flightMasterOpened = nil
		end
		return
	end

	--------------------------------------------------
	-- logging in or coming back to life
	--------------------------------------------------
	-- Login process: PLAYER_UNGHOST (login), PLAYER_LOGIN (login/reloadui), PLAYER_ALIVE (login)

	-- for when entering instances or resurrecting at your corpse - also happens when logging in and
	-- loading areas
	if event == "PLAYER_UNGHOST" then
		if not eventData.hasLoggedIn then
			eventData.hasLoggedIn = true
			AttemptReaction("Login", 0, nil, messagePlayerName, nil, ActionType.HIT)
		elseif eventData.isDead then
			eventData.isDead = false
			AttemptReaction("Resurrected", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
		return
	end

	-- set as being logged in so that future PLAYER_UNGHOST events won't trigger login messages. This
	-- is important because PLAYER_UNGHOST is used to tell if it's a real login instead of reloadui,
	-- so when reloadui is used there won't be one to set eventData.hasLoggedIn to true!
	if event == "PLAYER_LOGIN" then
		reactionFrame:UnregisterEvent(event)
		eventData.hasLoggedIn = true

		-- update these with valid information now that it should be available
		inGroup = (GetNumPartyMembers() ~= 0 or GetNumRaidMembers() ~= 0)
		eventData.isDead = UnitIsDeadOrGhost("player")
		eventData.lowestDurability = GetLowestEquipmentDurability() or 100
		if inGroup then -- must have been reloading UI
			hasFullyLoggedIn = true
		end
		return
	end

	-- happens during login/loading areas or when resurrected by someone/soulstone/spirit healer
	if event == "PLAYER_ALIVE" then
		if eventData.hasLoggedIn and eventData.isDead and not UnitIsDeadOrGhost("player") then
			eventData.isDead = false
			AttemptReaction("Resurrected", 0, nil, messagePlayerName, nil, ActionType.HIT)
		end
		return
	end

	-- played died
	if event == "PLAYER_DEAD" then
		eventData.isDead = true
		return
	end

	--------------------------------------------------
	-- gathering information after logging in
	--------------------------------------------------
	if event == "UPDATE_PENDING_MAIL" then
		reactionFrame:UnregisterEvent(event)
		inGroup = (GetNumPartyMembers() ~= 0 or GetNumRaidMembers() ~= 0)
		eventData.isDead  = UnitIsDeadOrGhost("player")
		hasFullyLoggedIn = true

		-- update guild member and friend list information
		GuildRoster()
		ShowFriends()
		return
	end

	--------------------------------------------------
	-- addon variables have finished loading
	--------------------------------------------------
	if event == "ADDON_LOADED" and arg1 == "Reactions" then
		reactionFrame:UnregisterEvent(event)

		SetDefaultSettings()
		SetNextAutomaticTime()

		if mainSettings.enabled then
			RegisterReactionsEvents()
		end
		return
	end
end

-- temporarily register loading events
reactionFrame:SetScript("OnEvent", Reactions_OnEvent)
reactionFrame:RegisterEvent("ADDON_LOADED")        -- temporary - load settings
reactionFrame:RegisterEvent("PLAYER_LOGIN")        -- temporary - set the player as logged in
reactionFrame:RegisterEvent("UPDATE_PENDING_MAIL") -- temporary - for setting info after logging in

----------------------------------------------------------------------------------------------------
-- /reactions command
----------------------------------------------------------------------------------------------------
_G.SLASH_REACTIONS1 = "/reactions"
_G.SLASH_REACTIONS2 = "/rs"
function SlashCmdList.REACTIONS(input)
	input = input or ""

	local command, value = match(input, "(%w+)%s*(.*)%s*$")
	command = command or input
	command = command:lower()

	-- check if it's a test message now so that value can be changed to lowercase for other options
	if command == "testmessage" then
		AttemptReaction(nil, 0, nil, messagePlayerName, nil, ActionType.HIT, true, value)
		return
	elseif command == "use" then
		-- the spell name may have quotation marks around it (and must if it's a multiple word spell)
		-- /reactions use "Multiple Word Spell" [target1] [target2]
		-- /reactions use SingleWordSpell [target1] [target2]
		local spell, target
		if value:find("^[\"']") then
			spell, target = value:match("^[\"'](.-)[\"']%s*(%S*)")
		else
			spell, target = value:match("^(%a+)%s*(%S*)")
		end
		if spell then
			AttemptReaction(spell, 0, nil, nil, target, ActionType.HIT)
		end
		return
	end
	if value then
		value = value:lower()
	end

	local gui = RSGUI and RSGUI:GetGUI()

	if command == "" then
		if not gui then
			local loaded, reason = LoadAddOn("Reactions_Options")
			if not loaded or not RSGUI then
				DEFAULT_CHAT_FRAME:AddMessage("Unable to load the Reactions_Options addon: " .. (reason or "no error message given!"), 1, 0, 0)
				return
			end
			gui = RSGUI:GetGUI(ReactionsSave)
		end
		gui:Show()
	--------------------------------------------------
	-- /reactions on
	--------------------------------------------------
	elseif command == "on" then
		mainSettings.enabled = true
		RegisterReactionsEvents()
		if not value == "quiet" then
			DEFAULT_CHAT_FRAME:AddMessage("Reactions are now enabled.")
		end
		if gui then
			gui:UpdateWidgets()
		end
	--------------------------------------------------
	-- /reactions off
	--------------------------------------------------
	elseif command == "off" then
		mainSettings.enabled = false
		UnregisterReactionsEvents()
		-- cancel queued actions
		futureReactionFrame:Hide()
		futureReactionList = {}
		if not value == "quiet" then
			DEFAULT_CHAT_FRAME:AddMessage("Reactions are now disabled.")
		end
		if gui then
			gui:UpdateWidgets()
		end
	--------------------------------------------------
	-- /reactions test
	--------------------------------------------------
	elseif command == "test" then
		value = lower(value)
		if value == "on" then
			mainSettings.testing = true
			DEFAULT_CHAT_FRAME:AddMessage("Test mode is now enabled (only you will see messages said).")
		elseif value == "off" then
			mainSettings.testing = false
			DEFAULT_CHAT_FRAME:AddMessage("Test mode is now disabled.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /reactions test <"on"|"off">')
		end
		if gui then
			gui:UpdateWidgets()
		end
	--------------------------------------------------
	-- /reactions mod
	--------------------------------------------------
	elseif (command == "chance" or command == "mod") and value and value ~= "" then
		local mod = tonumber(value)
		if mod and mod > 0 and mod <= 99999 then
			mainSettings.chanceMultiplier = mod
			DEFAULT_CHAT_FRAME:AddMessage("The chance multiplier has been set to: " .. mainSettings.chanceMultiplier)
		else
			DEFAULT_CHAT_FRAME:AddMessage("The multiplier value must be a number above 0 up to 99,999.")
		end
		if gui then
			gui:UpdateWidgets()
		end
	--------------------------------------------------
	-- /reactions cooldown
	--------------------------------------------------
	elseif command == "cooldown" and value and value ~= "" then
		local seconds = tonumber(value)
		if seconds and seconds >= 0 then
			mainSettings.globalCooldown = seconds
			DEFAULT_CHAT_FRAME:AddMessage("The global cooldown time between each reaction is now " .. seconds .. ".")
			if gui then
				gui:UpdateWidgets()
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("The wait value must be a number 0 or above.")
		end
	--------------------------------------------------
	-- /reactions shout
	--------------------------------------------------
	elseif command == "shout" then
		value = lower(value)
		if value == "on" then
			mainSettings.shoutMode = true
			DEFAULT_CHAT_FRAME:AddMessage("Shout mode is now enabled.")
		elseif value == "off" then
			mainSettings.shoutMode = false
			DEFAULT_CHAT_FRAME:AddMessage("Shout mode is now disabled.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /reactions shout <"on"|"off">')
		end
		if gui then
			gui:UpdateWidgets()
		end
	--------------------------------------------------
	-- /reactions group <name> on/off
	--------------------------------------------------
	elseif command == "group" and value and value ~= "" then
		local group, setting = value:match("(.+) (%a+)$")
		if setting and (setting == "on" or setting == "off") then
			for name in pairs(groupList) do
				if name:lower() == group then
					groupList[name] = setting == "on" and true or false
					DEFAULT_CHAT_FRAME:AddMessage("The " .. name .. " group in now " .. setting .. ".")
					return
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage("The group '" .. group .. "' doesn't exist.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /reactions group <name> <"on"|"off">')
		end
	--------------------------------------------------
	-- hidden - used from GUI
	--------------------------------------------------
	elseif command == "updateautomatic" then -- automatic event time changed, so set a new time for the next one
		SetNextAutomaticTime()
	--------------------------------------------------
	-- bod command - show syntax
	--------------------------------------------------
	else
		DEFAULT_CHAT_FRAME:AddMessage('Reactions commands:', 1, 1, 0)
		DEFAULT_CHAT_FRAME:AddMessage('/rs |cffffff00(will open settings window)|r')
		DEFAULT_CHAT_FRAME:AddMessage('/rs <"on"|"off">')
		DEFAULT_CHAT_FRAME:AddMessage('/rs test <"on"|"off">')
		DEFAULT_CHAT_FRAME:AddMessage('/rs cooldown <seconds>')
		DEFAULT_CHAT_FRAME:AddMessage('/rs chance <multiplier>')
		DEFAULT_CHAT_FRAME:AddMessage('/rs shout <"on"|"off">')
		DEFAULT_CHAT_FRAME:AddMessage('/rs group <name> <"on"|"off">')
		DEFAULT_CHAT_FRAME:AddMessage('/rs use "<spell>" [target]')
		DEFAULT_CHAT_FRAME:AddMessage(" ")

		if not mainSettings.enabled then
			DEFAULT_CHAT_FRAME:AddMessage("The addon is currently disabled.")
		elseif mainSettings.testing then
			DEFAULT_CHAT_FRAME:AddMessage("The addon is currently in test mode.")
		end
		DEFAULT_CHAT_FRAME:AddMessage("The global cooldown for reacting is " .. mainSettings.globalCooldown .. " seconds.")
		if mainSettings.chanceMultiplier and mainSettings.chanceMultiplier ~= 1 then
			DEFAULT_CHAT_FRAME:AddMessage("The chance multiplier is set to: " .. mainSettings.chanceMultiplier .. "%")
		end
		if mainSettings.shoutMode then
			DEFAULT_CHAT_FRAME:AddMessage("SHOUT MODE IS ENABLED.")
		end
	end
end
