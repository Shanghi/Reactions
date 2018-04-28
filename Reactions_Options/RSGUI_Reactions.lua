RSGUI.reactions = {}
RSGUI.reactions.__index = RSGUI.reactions

----------------------------------------------------------------------------------------------------
-- variables / constants
----------------------------------------------------------------------------------------------------
local MAX_REACTIONS_SHOW = 13  -- maximum amount of reaction lines to show

-- information about the types of actions each spell/event can do
RSGUI.reactions.actionTypeList = {
	-- table in settings         text for spell dropdown                         conditions: hits,caster,group,target,combat
	{"you_hit"                 , "Your spell hit someone else"                             , {true, nil , nil , true, true}},
	{"you_hit_self"            , "Your spell hit yourself"                                 , {true, nil , nil , nil , true}},
	{"you_miss"                , "Your spell is dodged/resisted"                           , {true, nil , nil , true, true}},
	{"you_get_hit"             , "You are hit"                                             , {true, true, nil , nil , true}},
	{"you_dodge"               , "You dodge/resist"                                        , {true, true, nil , nil , true}},
	{"start_cast"              , "You begin casting"                                       , {nil , nil , nil , true, true}},
	{"you_channel_stop"        , "Your channeling spell stops"                             , {nil , nil , nil , nil , true}, true}, -- [4] adds empty line

	{"member_hit"              , "Group member's spell hit someone else"                   , {true, nil , true, true, true}},
	{"member_hit_self"         , "Group member's spell hit themselves"                     , {true, nil , true, nil , true}},
	{"member_miss"             , "Group member's spell misses/is resisted"                 , {true, nil , true, true, true}},
	{"member_get_hit"          , "Group member is hit"                                     , {true, true, true, nil , true}},
	{"member_dodge"            , "Group member dodges/resists"                             , {true, true, true, nil , true}, true},

	{"other_hit"               , "Non-grouped person's spell hit someone else"             , {true, true, nil , true, true}},
	{"other_hit_self"          , "Non-grouped person's spell hit themselves"               , {true, true, nil , nil , true}},
	{"other_miss"              , "Non-grouped person's spell misses/is resisted"           , {true, true, nil , true, true}, true},

	{"periodic_you_hit"        , "Your spell periodically hit someone else"                , {true, nil , nil , true, true}},
	{"periodic_you_hit_self"   , "Your spell periodically hit yourself"                    , {true, nil , nil , nil , true}},
	{"periodic_you_get_hit"    , "You are hit periodically"                                , {true, true, nil , nil , true}},
	{"periodic_member_hit"     , "Group member's spell periodically hit someone else"      , {true, nil , true, true, true}},
	{"periodic_member_hit_self", "Group member's spell periodically hit themselves"        , {true, nil , true, nil , true}},
	{"periodic_member_get_hit" , "Group member is hit periodically"                        , {true, true, true, nil , true}},
	{"periodic_other_hit"      , "Non-grouped person's spell periodically hit someone else", {true, true, nil , true, true}},
	{"periodic_other_hit_self" , "Non-grouped person's spell periodically hit themselves"  , {true, true, nil , nil , true}, true},

	{"aura_gained_you"         , "Aura gained on you"                                      , {nil , nil , nil , nil , true}},
	{"aura_gained_member"      , "Aura gained on group member"                             , {nil , nil , true, nil , true}},
	{"aura_gained_other"       , "Aura gained on non-grouped person"                       , {nil , nil , nil , true, true}},
	{"aura_removed_you"        , "Aura removed from you"                                   , {nil , nil , nil , nil , true}},
	{"aura_removed_member"     , "Aura removed from group member"                          , {nil , nil , true, nil , true}},
	{"aura_removed_other"      , "Aura removed from non-grouped person"                    , {nil , nil , nil , true, true}},
}
local actionTypeList = RSGUI.reactions.actionTypeList

-- events only have a few possible actionTypes from the above list, so create a table to quickly look up those values
local actionTypeEventLookup = {}
for i=1,#actionTypeList do
	if actionTypeList[i][1] == "you_hit" or actionTypeList[i][1] == "member_hit" or actionTypeList[i][1] == "other_hit" then
		actionTypeEventLookup[#actionTypeEventLookup+1] = i
	end
end

-- information about each event
-- the condition table can be overridden in 2 ways - by making a table like in actionTypeList, or by
-- setting it as one of the EventCondition.* variables. If I had realized there were going to be so
-- many special cases (there were only 2 at first!) then bit flags would have been used instead.
local EventCondition = {
	SIMPLE_ALL       = 1, -- only one unit - group/target units - they could be either player or mob
	SIMPLE_ALL_NC    = 2, -- like SIMPLE_ALL, but with no combat options
	SIMPLE_ALL_SPELL = 3, -- like SIMPLE_ALL, but with spell info
	SIMPLE_PLAYER    = 4, -- only one unit - group/target units - they could only be a player
	SIMPLE_PLAYER_NC = 5, -- like SIMPLE_PLAYER, but with no combat options
	SIMPLE_MOB       = 6, -- only one unit - group/target units - they could only be a mob/npc
	PAIR_NOHIT       = 7, -- a unit and a target or caster, but no hit settings - standard you/group/target units
	TARGET_PLAYER    = 8, -- only one unit - for you_hit
	TARGET_MOB       = 9, -- only one unit - for you_hit
}

RSGUI.reactions.eventInformationList = {
 -- menu nickname                      submenu         "spell" name   conditions: hits,caster,group,target,combat  you_hit, member_hit, and other_hit names (or nil) - must be in same order of actionTypeEventLookup
	{"Focus (Friend)"                 , "Character"   , "FocusFriend"            , EventCondition.SIMPLE_ALL      , {"You /focus yourself", "You /focus a group member", "You /focus a non-grouped person"}},
	{"Focus (Enemy)"                  , "Character"   , "FocusEnemy"             , {nil , nil , nil , true, true} , {nil, nil, "You /focus an enemy"}},
	{"Full Rage"                      , "Character"   , "FullRage"               , EventCondition.SIMPLE_PLAYER   , {"You reach full rage", "A group member reaches full rage", "A non-grouped person reaches full rage"}},
	{"Low Health (Begin)"             , "Character"   , "LowHealthBegin"         , {nil , nil , nil , nil , true} , {"You reach low health", nil, nil}},
	{"Low Health (Continuing & Lower)", "Character"   , "LowHealthLower"         , {nil , nil , nil , nil , true} , {"Your already low health drops even lower", nil, nil}},
	{"Low Health (End)"               , "Character"   , "LowHealthEnd"           , {nil , nil , nil , nil , true} , {"Your low health ends", nil, nil}},
	{"Low Mana (Begin)"               , "Character"   , "LowManaBegin"           , {nil , nil , nil , nil , true} , {"You reach low mana", nil, nil}},
	{"Low Mana (Continuing & Lower)"  , "Character"   , "LowManaLower"           , {nil , nil , nil , nil , true} , {"Your already low mana drops even lower", nil, nil}},
	{"Low Mana (End)"                 , "Character"   , "LowManaEnd"             , {nil , nil , nil , nil , true} , {"Your low mana ends", nil, nil}},
	{"New Target (Friend)"            , "Character"   , "NewTargetFriend"        , EventCondition.SIMPLE_ALL      , {"You target yourself", "You target a group member", "You target a non-grouped person"}},
	{"New Target (Enemy)"             , "Character"   , "NewTargetEnemy"         , {nil , nil , nil , true, true} , {nil, nil, "You target an enemy"}},
	{"New Target (Dead Friend)"       , "Character"   , "NewTargetDeadFriend"    , EventCondition.SIMPLE_ALL      , {"You target your ghost", "You target a dead group member", "You target a dead non-grouped person"}},
	{"New Target (Dead Enemy)"        , "Character"   , "NewTargetDeadEnemy"     , {nil , nil , nil , true, true} , {nil, nil, "You target a dead enemy"}},
	{"Combat (Begin)"                 , "Combat"      , "CombatBegin"            , {nil , nil , nil , nil , nil } , {"You enter combat", nil, nil}},
	{"Combat (End)"                   , "Combat"      , "CombatEnd"              , {nil , nil , nil , nil , nil } , {"You leave combat", nil, nil}},
	{"Combat Target (Friend)"         , "Combat"      , "CombatTargetFriend"     , EventCondition.SIMPLE_ALL_NC   , {"You target yourself while in combat", "You target a group member while in combat", "You target a non-grouped person while in combat"}},
	{"Combat Target (Enemy)"          , "Combat"      , "CombatTargetEnemy"      , {nil , nil , nil , true, nil } , {nil, nil, "You target an enemy while in combat"}},
	{"Combat Target (Dead Friend)"    , "Combat"      , "CombatTargetDeadFriend" , EventCondition.SIMPLE_ALL_NC   , {nil, "You target a dead group member while in combat", "You target a dead non-grouped person while in combat"}},
	{"Combat Target (Dead Enemy)"     , "Combat"      , "CombatTargetDeadEnemy"  , {nil , nil , nil , true, nil } , {nil, nil, "You target a dead enemy while in combat"}},
	{"Critically Hit By (Normal)"     , "Combat"      , "CriticallyHitByNormal"  , {nil , nil , nil , true, true} , {"You are critically hit by someone's normal attack", nil, nil}},
	{"Critically Hit By (Heal)"       , "Combat"      , "CriticallyHitByHeal"    , EventCondition.SIMPLE_ALL      , {"You critically heal yourself", "A group member critically heals you", "A non-grouped person critically heals you"}},
	{"Critically Hit By (Spell)"      , "Combat"      , "CriticallyHitBySpell"   , {nil , nil , nil , true, true} , {"You are critically hit by someone's spell", nil, nil}},
	{"Critical Hit (Normal)"          , "Combat"      , "CriticalHitNormal"      , EventCondition.PAIR_NOHIT      , {"You critically hit someone with a normal attack", "A group member crits someone with a normal attack", "A non-grouped person crits someone with a normal attack"}},
	{"Critical Hit (Heal)"            , "Combat"      , "CriticalHitHeal"        , EventCondition.PAIR_NOHIT      , {"You critically heal someone", "A group member critically heals someone", "A non-grouped person critically heals someone"}},
	{"Critical Hit (Spell)"           , "Combat"      , "CriticalHitSpell"       , EventCondition.PAIR_NOHIT      , {"You critically hit someone with a spell", "A group member critically hits someone with a spell", "A non-grouped person critically hits someone with a spell"}},
	{"Death (Creature)"               , "Combat"      , "Death"                  , EventCondition.SIMPLE_ALL      , {"You die", "A group member dies", "A non-grouped person dies"}},
	{"Death (Totem)"                  , "Combat"      , "DeathTotem"             , EventCondition.SIMPLE_MOB      , {nil, nil, "A totem is destroyed"}},
	{"Duel Request"                   , "Combat"      , "DuelRequest"            , EventCondition.SIMPLE_PLAYER_NC, {"You request a duel with someone", "A group member requests a duel with you", "A non-grouped person requests a duel with you"}},
	{"Interrupting"                   , "Combat"      , "Interrupting"           , EventCondition.PAIR_NOHIT      , {"You interrupt someone else's spell", "A group member interrupts someone else's spell", "A non-grouped person interrupts someone else's spell"}},
	{"Interrupted"                    , "Combat"      , "Interrupted"            , {nil , nil , nil , true, true} , {"Your spell is interrupted by someone else", nil, nil}},
	{"Killing Blow"                   , "Combat"      , "KillingBlow"            , EventCondition.PAIR_NOHIT      , {"You get the killing blow", "A group member (in your subgroup) gets the killing blow", nil}},
	{"Killing Blow (Boss)"            , "Combat"      , "KillingBlowBoss"        , EventCondition.PAIR_NOHIT      , {"You get the killing blow", "A group member (in your subgroup) gets the killing blow", nil}},
	{"Lose Control (Begin)"           , "Combat"      , "LoseControlBegin"       , {nil , nil , nil , nil , true} , {"You lose control of your character", nil, nil}},
	{"Lose Control (Continuing)"      , "Combat"      , "LoseControl"            , {nil , nil , nil , nil , true} , {"You continue to have no control over your character", nil, nil}},
	{"Lose Control (End)"             , "Combat"      , "LoseControlEnd"         , {nil , nil , nil , nil , true} , {"You regain control of your character", nil, nil}},
	{"Resurrected"                    , "Combat"      , "Resurrected"            , {nil , nil , nil , nil , true} , {"You resurrect", nil, nil}},
	{"Automatic"                      , "Environment" , "Automatic"              , {nil , nil , nil , nil , true} , {"The automatic event happens", nil, nil}},
	{"Backpedal"                      , "Environment" , "Backpedal"              , {nil , nil , nil , nil , true} , {"You begin moving backwards", nil, nil}},
	{"Changed Zone"                   , "Environment" , "ChangedZone"            , {nil , nil , nil , nil , true} , {"You change zones", nil, nil}},
	{"Changed Subzone"                , "Environment" , "ChangedSubzone"         , {nil , nil , nil , nil , true} , {"You change subzones", nil, nil}},
	{"Environment (Drowning)"         , "Environment" , "EnvironmentDrown"       , EventCondition.SIMPLE_PLAYER   , {"You are damaged by drowning", "A group member is damaged by drowning", "A non-grouped person is damaged by drowning"}},
	{"Environment (Drowning - Death)" , "Environment" , "EnvironmentDrownDeath"  , EventCondition.SIMPLE_PLAYER   , {"You die by drowning", "A group member dies by drowning", nil}},
	{"Environment (Fall)"             , "Environment" , "EnvironmentFall"        , EventCondition.SIMPLE_PLAYER   , {"You are damaged by falling", "A group member is damaged by falling", "A non-grouped person is damaged by falling"}},
	{"Environment (Fall - Death)"     , "Environment" , "EnvironmentFallDeath"   , EventCondition.SIMPLE_PLAYER   , {"You die by falling", "A group member dies by falling", nil}},
	{"Environment (Fire)"             , "Environment" , "EnvironmentFire"        , EventCondition.SIMPLE_PLAYER   , {"You are damaged by fire", "A group member is damaged by fire", "A non-grouped person is damaged by fire"}},
	{"Environment (Fire - Death)"     , "Environment" , "EnvironmentFireDeath"   , EventCondition.SIMPLE_PLAYER   , {"You die by fire", "A group member dies by fire", nil}},
	{"Environment (Lava)"             , "Environment" , "EnvironmentLava"        , EventCondition.SIMPLE_PLAYER   , {"You are damaged by lava", "A group member is damaged by lava", "A non-grouped person is damaged by lava"}},
	{"Environment (Lava - Death)"     , "Environment" , "EnvironmentLavaDeath"   , EventCondition.SIMPLE_PLAYER   , {"You die by lava", "A group member dies by lava", nil}},
	{"Environment (Slime)"            , "Environment" , "EnvironmentSlime"       , EventCondition.SIMPLE_PLAYER   , {"You are damaged by slime", "A group member is damaged by slime", "A non-grouped person is damaged by slime"}},
	{"Environment (Slime - Death)"    , "Environment" , "EnvironmentSlimeDeath"  , EventCondition.SIMPLE_PLAYER   , {"You die by slime", "A group member dies by slime", nil}},
	{"Falling"                        , "Environment" , "Falling"                , {nil , nil , nil , nil , true} , {"You fall for 3 seconds", nil, nil}},
	{"Jump"                           , "Environment" , "Jump"                   , {nil , nil , nil , nil , true} , {"You jump", nil, nil}},
	{"Minimap Ping"                   , "Environment" , "MinimapPing"            , EventCondition.SIMPLE_PLAYER   , {"You ping the minimap", "A group member pings the minimap", nil}},
	{"Swimming (Begin)"               , "Environment" , "SwimmingBegin"          , {nil , nil , nil , nil , true} , {"You begin swimming", nil, nil}},
	{"Swimming (Continuing)"          , "Environment" , "Swimming"               , {nil , nil , nil , nil , true} , {"You continue to swim", nil, nil}},
	{"Swimming (End)"                 , "Environment" , "SwimmingEnd"            , {nil , nil , nil , nil , true} , {"You stop swimming (doesn't trigger if going underwater)", nil, nil}},
	{"Underwater (Begin)"             , "Environment" , "UnderwaterBegin"        , {nil , nil , nil , nil , true} , {"You begin swimming underwater (and can't breathe)", nil, nil}},
	{"Underwater (Continuing)"        , "Environment" , "Underwater"             , {nil , nil , nil , nil , true} , {"You continue swimming underwater (and can't breathe)", nil, nil}},
	{"Underwater (End)"               , "Environment" , "UnderwaterEnd"          , {nil , nil , nil , nil , true} , {"You stop swimming underwater (if you couldn't breathe)", nil, nil}},
	{"Bank (Open)"                    , "Objects"     , "BankOpen"               , EventCondition.TARGET_MOB      , {"You open your bank", nil, nil}},
	{"Bank (Close)"                   , "Objects"     , "BankClose"              , EventCondition.TARGET_MOB      , {"You close your bank", nil, nil}},
	{"Consume Alcohol"                , "Objects"     , "ConsumeAlcohol"         , {nil , nil , nil , nil , true} , {"You drink alcohol", nil, nil}},
	{"Consume Drink"                  , "Objects"     , "ConsumeDrink"           , {nil , nil , nil , nil , nil } , {"You begin drinking", nil, nil}},
	{"Consume Food"                   , "Objects"     , "ConsumeFood"            , {nil , nil , nil , nil , nil } , {"You begin eating", nil, nil}},
	{"Destroy Item"                   , "Objects"     , "DestroyItem"            , {nil , nil , nil , nil , true} , {"You destroy an item", nil, nil}},
	{"Durability (Low)"               , "Objects"     , "DurabilityLow"          , {nil , nil , nil , nil , true} , {"An item's durability becomes low", nil, nil}},
	{"Durability (Broken)"            , "Objects"     , "DurabilityBroken"       , {nil , nil , nil , nil , true} , {"An item breaks", nil, nil}},
	{"Guild Bank (Open)"              , "Objects"     , "GuildBankOpen"          , {nil , nil , nil , nil , true} , {"You open your guild's bank", nil, nil}},
	{"Guild Bank (Close)"             , "Objects"     , "GuildBankClose"         , {nil , nil , nil , nil , true} , {"You close your guild's bank", nil, nil}},
	{"Loot (Autoloot)"                , "Objects"     , "LootAutoloot"           , {nil , nil , nil , nil , true} , {"You loot something using autoloot", nil, nil}},
	{"Loot (Open)"                    , "Objects"     , "LootOpen"               , {nil , nil , nil , nil , true} , {"You open a loot window (without autoloot)", nil, nil}},
	{"Loot (Close)"                   , "Objects"     , "LootClose"              , {nil , nil , nil , nil , true} , {"You close a loot window (without autoloot)", nil, nil}},
	{"Loot (Close Fast)"              , "Objects"     , "LootCloseFast"          , {nil , nil , nil , nil , true} , {"You close a loot window quickly (without autoloot)", nil, nil}},
	{"Mailbox (Open)"                 , "Objects"     , "MailboxOpen"            , {nil , nil , nil , nil , true} , {"You open a mailbox", nil, nil}},
	{"Mailbox (Close)"                , "Objects"     , "MailboxClose"           , {nil , nil , nil , nil , true} , {"You close a mailbox", nil, nil}},
	{"Opening World Object"           , "Objects"     , "OpeningWorldObject"     , {nil , nil , nil , nil , true} , {"You begin opening a world object", nil, nil}},
	{"Repair Items"                   , "Objects"     , "RepairItems"            , EventCondition.TARGET_MOB      , {"You repair all your items", nil, nil}},
	{"Auction House (Open)"           , "Society"     , "AuctionHouseOpen"       , EventCondition.TARGET_MOB      , {"You open the auction house window", nil, nil}},
	{"Auction House (Close)"          , "Society"     , "AuctionHouseClose"      , EventCondition.TARGET_MOB      , {"You close the auction house window", nil, nil}},
	{"Flight Master (Open)"           , "Society"     , "FlightMasterOpen"       , EventCondition.TARGET_MOB      , {"You open the flight path window", nil, nil}},
	{"Flight Master (Close)"          , "Society"     , "FlightMasterClose"      , EventCondition.TARGET_MOB      , {"You cancel and close the flight path window", nil, nil}},
	{"Flight Master (Flight Begin)"   , "Society"     , "FlightMasterFlightBegin", {nil , nil , nil , nil , true} , {"Your flight on a flight path begins", nil, nil}},
	{"Flight Master (Flight End)"     , "Society"     , "FlightMasterFlightEnd"  , {nil , nil , nil , nil , true} , {"Your flight on a flight path ends", nil, nil}},
	{"Follow (Begin)"                 , "Society"     , "FollowBegin"            , EventCondition.TARGET_PLAYER   , {"You begin following someone", nil, nil}},
	{"Follow (End)"                   , "Society"     , "FollowEnd"              , EventCondition.TARGET_PLAYER   , {"You stop following someone", nil, nil}},
	{"Group (Join)"                   , "Society"     , "GroupJoin"              , EventCondition.SIMPLE_PLAYER   , {"You join a group", "Someone else joins your group", nil}},
	{"Group (Leave)"                  , "Society"     , "GroupLeave"             , EventCondition.SIMPLE_PLAYER   , {"You leave a group", nil, "Someone else leaves your group"}},
	{"Login"                          , "Society"     , "Login"                  , {nil , nil , nil , nil , true} , {"You log in", nil, nil}},
	{"Logout (Countdown)"             , "Society"     , "LogoutStart"            , {nil , nil , nil , nil , true} , {"You begin the logout countdown", nil, nil}},
	{"Logout (Instantly)"             , "Society"     , "LogoutInstant"          , {nil , nil , nil , nil , true} , {"You log out without a countdown", nil, nil}},
	{"Merchant (Open)"                , "Society"     , "MerchantOpen"           , EventCondition.TARGET_MOB      , {"You open a merchant window", nil, nil}},
	{"Merchant (Close)"               , "Society"     , "MerchantClose"          , EventCondition.TARGET_MOB      , {"You close a merchant window", nil, nil}},
	{"Ready Check (Begin)"            , "Society"     , "ReadyCheckBegin"        , EventCondition.SIMPLE_PLAYER   , {"You start a ready check", "A group member starts a ready check", nil}},
	{"Ready Check (Is Ready)"         , "Society"     , "ReadyCheckIsReady"      , EventCondition.SIMPLE_PLAYER   , {"You answer a ready check as being ready", "A group member answers a ready check as being ready", nil}},
	{"Ready Check (Not Ready)"        , "Society"     , "ReadyCheckNotReady"     , EventCondition.SIMPLE_PLAYER   , {"You answer a ready check as being not ready", "A group member answers a ready check as being not ready", nil}},
	{"Summon Accept (Before)"         , "Society"     , "SummonAcceptBefore"     , EventCondition.TARGET_PLAYER   , {"You accept a summon (before teleporting)", nil, nil}},
	{"Summon Accept (After)"          , "Society"     , "SummonAcceptAfter"      , EventCondition.TARGET_PLAYER   , {"You accept a summon (after teleporting)", nil, nil}},
	{"Summon Cancel"                  , "Society"     , "SummonCancel"           , EventCondition.TARGET_PLAYER   , {"You decline a summon", nil, nil}},
	{"Trade (Open)"                   , "Society"     , "TradeOpen"              , EventCondition.TARGET_PLAYER   , {"You start a trade with someone", nil, nil}},
	{"Trade (Accept)"                 , "Society"     , "TradeAccept"            , EventCondition.TARGET_PLAYER   , {"Your trade is accepted", nil, nil}},
	{"Trade (Cancel)"                 , "Society"     , "TradeCancel"            , EventCondition.TARGET_PLAYER   , {"Your trade is canceled", nil, nil}},
	{"Bandage (Begin)"                , "Spell Effect", "BandageBegin"           , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by bandage", "A group member is affected by bandage", "A non-grouped person is affected by bandage"}},
	{"Bandage (End)"                  , "Spell Effect", "BandageEnd"             , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by bandage", "A group member is no longer affected by bandage", "A non-grouped person is no longer affected by bandage"}},
	{"Banish (Begin)"                 , "Spell Effect", "BanishBegin"            , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by banish", "A group member is affected by banish", "A non-grouped person is affected by banish"}},
	{"Banish (End)"                   , "Spell Effect", "BanishEnd"              , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by banish", "A group member is no longer affected by banish", "A non-grouped person is no longer affected by banish"}},
	{"Bleed (Begin)"                  , "Spell Effect", "BleedBegin"             , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by bleed", "A group member is affected by bleed", "A non-grouped person is affected by bleed"}},
	{"Bleed (End)"                    , "Spell Effect", "BleedEnd"               , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by bleed", "A group member is no longer affected by bleed", "A non-grouped person is no longer affected by bleed"}},
	{"Charm (Begin)"                  , "Spell Effect", "CharmBegin"             , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by charm", "A group member is affected by charm", "A non-grouped person is affected by charm"}},
	{"Charm (End)"                    , "Spell Effect", "CharmEnd"               , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by charm", "A group member is no longer affected by charm", "A non-grouped person is no longer affected by charm"}},
	{"Disarm (Begin)"                 , "Spell Effect", "DisarmBegin"            , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by disarm", "A group member is affected by disarm", "A non-grouped person is affected by disarm"}},
	{"Disarm (End)"                   , "Spell Effect", "DisarmEnd"              , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by disarm", "A group member is no longer affected by disarm", "A non-grouped person is no longer affected by disarm"}},
	{"Disorient (Begin)"              , "Spell Effect", "DisorientBegin"         , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by disorient", "A group member is affected by disorient", "A non-grouped person is affected by disorient"}},
	{"Disorient (End)"                , "Spell Effect", "DisorientEnd"           , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by disorient", "A group member is no longer affected by disorient", "A non-grouped person is no longer affected by disorient"}},
	{"Fear (Begin)"                   , "Spell Effect", "FearBegin"              , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by fear", "A group member is affected by fear", "A non-grouped person is affected by fear"}},
	{"Fear (End)"                     , "Spell Effect", "FearEnd"                , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by fear", "A group member is no longer affected by fear", "A non-grouped person is no longer affected by fear"}},
	{"Freeze (Begin)"                 , "Spell Effect", "FreezeBegin"            , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by freeze", "A group member is affected by freeze", "A non-grouped person is affected by freeze"}},
	{"Freeze (End)"                   , "Spell Effect", "FreezeEnd"              , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by freeze", "A group member is no longer affected by freeze", "A non-grouped person is no longer affected by freeze"}},
	{"Immunity (Begin)"               , "Spell Effect", "ImmunityBegin"          , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by immunity", "A group member is affected by immunity", "A non-grouped person is affected by immunity"}},
	{"Immunity (End)"                 , "Spell Effect", "ImmunityEnd"            , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by immunity", "A group member is no longer affected by immunity", "A non-grouped person is no longer affected by immunity"}},
	{"Polymorph (Begin)"              , "Spell Effect", "PolymorphBegin"         , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by polymorph", "A group member is affected by polymorph", "A non-grouped person is affected by polymorph"}},
	{"Polymorph (End)"                , "Spell Effect", "PolymorphEnd"           , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by polymorph", "A group member is no longer affected by polymorph", "A non-grouped person is no longer affected by polymorph"}},
	{"Root (Begin)"                   , "Spell Effect", "RootBegin"              , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by root", "A group member is affected by root", "A non-grouped person is affected by root"}},
	{"Root (End)"                     , "Spell Effect", "RootEnd"                , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by root", "A group member is no longer affected by root", "A non-grouped person is no longer affected by root"}},
	{"Sapped (Begin)"                 , "Spell Effect", "SappedBegin"            , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by sapped", "A group member is affected by sapped", "A non-grouped person is affected by sapped"}},
	{"Sapped (End)"                   , "Spell Effect", "SappedEnd"              , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by sapped", "A group member is no longer affected by sapped", "A non-grouped person is no longer affected by sapped"}},
	{"Shield (Begin)"                 , "Spell Effect", "ShieldBegin"            , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by shield", "A group member is affected by shield", "A non-grouped person is affected by shield"}},
	{"Shield (End)"                   , "Spell Effect", "ShieldEnd"              , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by shield", "A group member is no longer affected by shield", "A non-grouped person is no longer affected by shield"}},
	{"Silence (Begin)"                , "Spell Effect", "SilenceBegin"           , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by silence", "A group member is affected by silence", "A non-grouped person is affected by silence"}},
	{"Silence (End)"                  , "Spell Effect", "SilenceEnd"             , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by silence", "A group member is no longer affected by silence", "A non-grouped person is no longer affected by silence"}},
	{"Sleep (Begin)"                  , "Spell Effect", "SleepBegin"             , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by sleep", "A group member is affected by sleep", "A non-grouped person is affected by sleep"}},
	{"Sleep (End)"                    , "Spell Effect", "SleepEnd"               , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by sleep", "A group member is no longer affected by sleep", "A non-grouped person is no longer affected by sleep"}},
	{"Snare (Begin)"                  , "Spell Effect", "SnareBegin"             , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by snare", "A group member is affected by snare", "A non-grouped person is affected by snare"}},
	{"Snare (End)"                    , "Spell Effect", "SnareEnd"               , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by snare", "A group member is no longer affected by snare", "A non-grouped person is no longer affected by snare"}},
	{"Stun (Begin)"                   , "Spell Effect", "StunBegin"              , EventCondition.SIMPLE_ALL_SPELL, {"You are affected by stun", "A group member is affected by stun", "A non-grouped person is affected by stun"}},
	{"Stun (End)"                     , "Spell Effect", "StunEnd"                , EventCondition.SIMPLE_ALL_SPELL, {"You are no longer affected by stun", "A group member is no longer affected by stun", "A non-grouped person is no longer affected by stun"}},
}

-- list of channels/actions that each reaction can use
local channelList = {"Chat Command", "Say and Yell", "Group", "/w Target", "/w Caster", "Print to Chat", "Print to Warning", "Spell/Event"}

-- list of forms/stances and their icons
local formButtonIcon = {
 --["Any"]              = "Interface/ICONS/Spell_Nature_WispSplode.blp",
	["Any"]              = "Interface/PVPFrame/Icons/PVP-Banner-Emblem-73.blp",
	["Normal"]           = "Interface/ICONS/INV_Misc_Head_Gnome_01.blp",
	["Aquatic Form"]     = "Interface/ICONS/Ability_Druid_AquaticForm.blp",
	["Cat Form"]         = "Interface/ICONS/Ability_Druid_CatForm.blp",
	["Bear Form"]        = "Interface/ICONS/Ability_Racial_BearForm.blp",
	["Flight Form"]      = "Interface/ICONS/Ability_Druid_FlightForm.blp",
	["Moonkin Form"]     = "Interface/ICONS/spell_nature_forceofnature.blp",
	["Travel Form"]      = "Interface/ICONS/Ability_Druid_TravelForm.blp",
	["Tree Form"]        = "Interface/ICONS/Ability_Druid_TreeofLife.blp",
	["Battle Stance"]    = "Interface/ICONS/Ability_Warrior_OffensiveStance.blp",
	["Defensive Stance"] = "Interface/ICONS/Ability_Warrior_DefensiveStance.blp",
	["Berserker Stance"] = "Interface/ICONS/Ability_Racial_Avatar",
	["Shadowform"]       = "Interface/ICONS/Spell_Shadow_Shadowform",
	["Ghost Wolf"]       = "Interface/ICONS/Spell_Nature_SpiritWolf.blp",
}

-- list of player languages and their icons
local LanguageButtonIcon = {
	["Common"] = "Interface/MINIMAP/TRACKING/Class.blp",
	["Racial"] = "Interface/MINIMAP/TRACKING/BattleMaster.blp",
	["Random"] = "Interface/BUTTONS/UI-GroupLoot-Dice-Up.blp",
}

-- Default role item icon when an item isn't set
local RoleItemButtonIcon = "Interface/MINIMAP/TRACKING/Banker.blp"

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- find and return the eventInformationList data for a specific event based on the name
function FindEventInformation(name)
	local eventInformationList = RSGUI.reactions.eventInformationList
	for i=1,#eventInformationList do
		if name == eventInformationList[i][3] then
			return eventInformationList[i]
		end
	end
end

-- create (if needed) and return the action table (hit/member_hit/miss/etc) of a spell/event
function RSGUI.reactions:GetCurrentActionData()
	local currentAction = self.currentAction
	if not currentAction.name then
		return nil
	end

	local settings = self.main.settings
	if not settings["reactionList"][currentAction.name] then
		settings["reactionList"][currentAction.name] = {}
		if currentAction.isEvent then
			settings["reactionList"][currentAction.name].event = true
		end
	end
	if not settings["reactionList"][currentAction.name][actionTypeList[currentAction.action][1]] then
		settings["reactionList"][currentAction.name][actionTypeList[currentAction.action][1]] = {}
	end
	return settings["reactionList"][currentAction.name][actionTypeList[currentAction.action][1]]
end

-- return the amount of actions a spell/event is watching for and the total amount of possible reactions they all have
function RSGUI.reactions:CountReactionActions(name)
	local info = self.main.settings["reactionList"][name]
	if not info then
		return 0, 0
	end

	local actionCount = 0
	local reactionCount = 0
	for i=1,#actionTypeList do
		local actionInfo = info[actionTypeList[i][1]]
		if actionInfo then
			actionCount = actionCount + 1
			reactionCount = reactionCount + (actionInfo.reactions and #actionInfo.reactions or 0)
		end
	end

	return actionCount, reactionCount
end

-- deleting events with no reactions
function RSGUI.reactions:CheckEventForDeletion(name)
	if not name then return end

	local data = self.main.settings["reactionList"][name]
	if not data or not data.event or select(2, self:CountReactionActions(name)) > 0 then return end

	self.main.settings["reactionList"][name] = nil
end

function RSGUI.reactions:CreateAndShowSpell(name, nickname, submenu)
	if not name or name == "" then
		return
	end
	local reaction = self.main.settings["reactionList"][name]
	if reaction then
		self:Open(name)
		return
	end

	self.main.settings["reactionList"][name] = {}
	self.main.settings["reactionList"][name].nickname = nickname ~= "" and nickname or nil
	self.main.settings["reactionList"][name].submenu = submenu ~= "" and submenu or nil
	self.main:BuildSpellsMenu(true)
	self:Open(name)
end

----------------------------------------------------------------------------------------------------
-- dropdown widget actions
----------------------------------------------------------------------------------------------------
--------------------
-- channel dropdown
--------------------
local function DropdownChannel_OnClick(self)
	RSGUI.Utility.ClearAnyFocus()
	local dropdown = _G[UIDROPDOWNMENU_OPEN_MENU]
	UIDropDownMenu_SetSelectedValue(dropdown, this.value)
	self.contentTable.list[dropdown.listIndex][1] = this.value
end

local dropdownChannelItem = {}
local function DropdownChannel_Initialize(self)
	for channel=1,#channelList do
		dropdownChannelItem.func = DropdownChannel_OnClick
		dropdownChannelItem.arg1 = self
		dropdownChannelItem.checked = nil
		dropdownChannelItem.value = channelList[channel]
		dropdownChannelItem.text = channelList[channel]
		UIDropDownMenu_AddButton(dropdownChannelItem)
	end
end

--------------------
-- action dropdowns
--------------------
-- set up action dropdown menus
local function DropdownSpellAction_OnClick(self)
	RSGUI.Utility.ClearAnyFocus()
	UIDropDownMenu_SetSelectedValue(self.dropdownSpellAction, this.value)
	self.currentAction.action = this.value
	self:ShowAction()
end
local function DropdownEventAction_OnClick(self)
	RSGUI.Utility.ClearAnyFocus()
	UIDropDownMenu_SetSelectedValue(self.dropdownEventAction, this.value)
	self.currentAction.action = this.value
	self:ShowAction()
end

local dropdownSpellActionItem = {}
local function DropdownSpellAction_Initialize(self)
	local spell = self.currentAction.name and self.main.settings["reactionList"][self.currentAction.name] or nil
	-- initializing variable used to know when the selection should be cleared, like when opening a new spell/event
	if self.dropdownSpellAction.initializing then
		self.dropdownSpellAction.initializing = nil
		UIDropDownMenu_SetSelectedValue(self.dropdownSpellAction)
		UIDropDownMenu_SetText(nil, self.dropdownSpellAction)
	end
	for i=1,#actionTypeList do
		local action = spell and spell[actionTypeList[i][1]]
		dropdownSpellActionItem.func = DropdownSpellAction_OnClick
		dropdownSpellActionItem.arg1 = self
		dropdownSpellActionItem.checked = nil
		dropdownSpellActionItem.value = i
		-- change the text to green if a reaction exists
		dropdownSpellActionItem.text = (action and action.reactions and next(action.reactions) ~= nil and "|cff00ff00" or "") .. actionTypeList[i][2]
		UIDropDownMenu_AddButton(dropdownSpellActionItem)
		if actionTypeList[i][4] then
			UIDropDownMenu_AddButton({notCheckable=1, text="", notClickable=1})
		end
	end
end

local dropdownEventActionItem = {}
local function DropdownEventAction_Initialize(self)
	local spell = self.currentAction.name and self.main.settings["reactionList"][self.currentAction.name] or nil
	-- initializing variable used to know when the selection should be cleared, like when opening a new spell/event
	if self.dropdownEventAction.initializing then
		self.dropdownEventAction.initializing = nil
		UIDropDownMenu_SetSelectedValue(self.dropdownEventAction)
		UIDropDownMenu_SetText(nil, self.dropdownEventAction)
	end

	local eventInfo = FindEventInformation(self.currentAction.name)
	local actionsAllowed = eventInfo and eventInfo[5]

	if actionsAllowed then
		local count = 0
		for i=1,#actionTypeEventLookup do
			if actionsAllowed[i] then
				local action = spell and spell[actionTypeList[actionTypeEventLookup[i]][1]]
				dropdownEventActionItem.func = DropdownEventAction_OnClick
				dropdownEventActionItem.arg1 = self
				dropdownEventActionItem.checked = nil
				dropdownEventActionItem.value = actionTypeEventLookup[i]
				-- change the name to green if a reaction exists
				dropdownEventActionItem.text = (action and action.reactions and next(action.reactions) ~= nil and "|cff00ff00" or "") .. actionsAllowed[i]
				UIDropDownMenu_AddButton(dropdownEventActionItem)
				count = count + 1
			end
		end
		-- disable the dropdown if only one thing is in it
		if count == 1 then
			_G[self.dropdownEventAction:GetName().."Button"]:Disable()
		else
			_G[self.dropdownEventAction:GetName().."Button"]:Enable()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- create spell/event reactions panel
----------------------------------------------------------------------------------------------------
function RSGUI.reactions.new(main)
	local self = setmetatable({}, RSGUI.reactions)

	self.frame = CreateFrame("frame", "RSGUI_Reactions", nil)
	local panel = self.frame

	self.main = main
	main:AddContentFrame("reactions", self)
	panel:SetScript("OnShow", function() main:HideContentExcept(panel) end)
	panel:SetScript("OnHide", function() self:CheckEventForDeletion(self.currentAction.name) end)

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		if self.slider:IsVisible() then
			self.slider:SetValue(self.slider:GetValue() + (-delta))
		end
	end)

	self.currentAction = {}
	self.currentAction.name    = nil -- the name of spell/event that was opened last
	self.currentAction.isEvent = nil -- if the currently opened spell/event is an event type
	self.currentAction.action  = nil -- the current action type of the spell/event being edited

	--------------------------------------------------
	-- top section
	--------------------------------------------------
	-- set spell name or ID
	self.textName = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textName:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	self.textName:SetText("Name/ID:")

	self.inputName = CreateFrame("EditBox", "RSGUI_Reactions_inputName", panel, "InputBoxTemplate")
	self.inputName:SetWidth(155)
	self.inputName:SetHeight(12)
	self.inputName:SetPoint("LEFT", self.textName, "RIGHT", 10, 0)
	self.inputName:SetAutoFocus(false)
	self.inputName:SetScript("OnTextChanged", function()
		if this.protect and this.protect ~= this:GetText() then
			this:SetText(this.protect)
		end
	end)

	-- set nickname for menu
	self.textNickname = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textNickname:SetPoint("LEFT", self.inputName, "RIGHT", 14, 0)
	self.textNickname:SetText("Nickname:")

	self.inputNickname = CreateFrame("EditBox", "RSGUI_Reactions_inputNickname", panel, "InputBoxTemplate")
	self.inputNickname:SetWidth(155)
	self.inputNickname:SetHeight(12)
	self.inputNickname:SetPoint("LEFT", self.textNickname, "RIGHT", 10, 0)
	self.inputNickname:SetAutoFocus(false)
	self.inputNickname:SetScript("OnTextChanged", function()
		if this.protect and this.protect ~= this:GetText() then
			this:SetText(this.protect)
		end
	end)

	-- set Submenu
	self.textSubmenu = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textSubmenu:SetPoint("LEFT", self.inputNickname, "RIGHT", 14, 0)
	self.textSubmenu:SetText("Submenu:")

	self.inputSubmenu = CreateFrame("EditBox", "RSGUI_Reactions_inputSubmenu", panel, "InputBoxTemplate")
	self.inputSubmenu:SetWidth(155)
	self.inputSubmenu:SetHeight(12)
	self.inputSubmenu:SetPoint("LEFT", self.textSubmenu, "RIGHT", 10, 0)
	self.inputSubmenu:SetAutoFocus(false)
	self.inputSubmenu:SetScript("OnTextChanged", function()
		if this.protect and this.protect ~= this:GetText() then
			this:SetText(this.protect)
		end
	end)

	-- Save/Change button
	self.buttonCreateOrChange = RSGUI.Utility.CreateButton("Reactions_CreateChange", panel, 70, "Create")
	self.buttonCreateOrChange:SetPoint("LEFT", self.inputSubmenu, "RIGHT", 10, 0)
	self.buttonCreateOrChange.text = _G[self.buttonCreateOrChange:GetName().."Text"] -- will change depending on creating or editing
	self.buttonCreateOrChange:SetScript("OnClick", function()
		CloseDropDownMenus()
		RSGUI.Utility.ClearAnyFocus()

		if self.currentAction.isEvent then
			return
		end

		local name = self.inputName:GetText()
		if name == "" then
			self.inputName:SetText(self.currentAction.name or "")
			message("You must set a name or ID number.")
			return
		end
		local lowerName = name:lower()
		local eventInformationList = RSGUI.reactions.eventInformationList
		for i=1,#eventInformationList do
			if eventInformationList[i][3]:lower() == lowerName then
				self.inputName:SetText(self.currentAction.name or "")
				message(eventInformationList[i][3] .. " is already an event name.")
				return
			end
		end

		local nickname = self.inputNickname:GetText()
		local submenu = self.inputSubmenu:GetText()

		local mode = self.buttonCreateOrChange:GetText()
		local reaction = self.main.settings["reactionList"][name]
		if mode == "Create" then
			self:CreateAndShowSpell(name, nickname, submenu)
		elseif mode == "Change" then
			local oldName = self.currentAction.name
			if name ~= oldName then
				if reaction then
					message("A spell/event with that name already exists! You must delete it first.")
					return
				end

				-- move the table to a new name
				reaction = self.main.settings["reactionList"][oldName]
				self.main.settings["reactionList"][name] = reaction
				self.main.settings["reactionList"][oldName] = nil

				self.currentAction.name = name
				self.main:SetHeaderText("Spell: " .. name)
			end

			self.main.settings["reactionList"][name].submenu = submenu ~= "" and submenu or nil
			self.main.settings["reactionList"][name].nickname = nickname ~= "" and nickname or nil
			self.main:RenameReactionHistory(oldName, name, string.format("%s%s", name, nickname ~= "" and (" ("..nickname..")") or ""))

			self.main:BuildSpellsMenu(true)
		end
	end)

	-- Delete button
	self.buttonDeleteAll = RSGUI.Utility.CreateButton("Reactions_DeleteAll", panel, 70, "Delete")
	self.buttonDeleteAll:SetPoint("LEFT", self.buttonCreateOrChange, "RIGHT", 3, 0)
	self.buttonDeleteAll:SetScript("OnClick", function()
		self.main:RemoveHistory(self.currentAction.isEvent and "event" or "spell", self.currentAction.name)
		local reaction = self.currentAction.name and self.main.settings["reactionList"][self.currentAction.name] or nil
		if reaction then
			self.main.settings["reactionList"][self.currentAction.name] = nil
			self.main:BuildSpellsMenu(true)
			self.main:BuildGroupsMenu(true)
			if self.currentAction.isEvent then
				self.main:RenameEventsMenuItem(self.currentAction.name)
			end
		end

		self.currentAction.name = nil
		self.main:SetHeaderText("")
		self.frame:Hide()
	end)

	-- pressing enter on any input field will add/change the reaction
	self.inputNickname:SetScript("OnEnterPressed", function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)
	self.inputName:SetScript("OnEnterPressed",     function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)
	self.inputSubmenu:SetScript("OnEnterPressed",  function() this:ClearFocus() self.buttonCreateOrChange:GetScript("OnClick")() end)

	-- be able to tab through fields
	self.inputName:SetScript("OnTabPressed",     function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputSubmenu:SetFocus()  else self.inputNickname:SetFocus() end end)
	self.inputNickname:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputName:SetFocus()     else self.inputSubmenu:SetFocus()  end end)
	self.inputSubmenu:SetScript("OnTabPressed",  function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputNickname:SetFocus() else self.inputName:SetFocus()     end end)

	--------------------------------------------------
	-- middle section
	--------------------------------------------------
	-- top border
	self.borderTop = panel:CreateTexture()
	self.borderTop:SetTexture(.4, .4, .4)
	self.borderTop:SetHeight(1)
	self.borderTop:SetWidth(panel:GetWidth())
	self.borderTop:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textName:GetBottom())-11)

	-- tip about dragging icons
	self.textTip = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.textTip:SetPoint("TOP", self.borderTop, "BOTTOM", 0, -30)
	self.textTip:SetText("You can also drag and drop your spellbook spells and inventory items to the window.\nThe spell an item uses won't always be the same name as the item.")

	-- action type dropdown selection
	self.dropdownActionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.dropdownActionText:SetPoint("TOPLEFT", self.borderTop, "BOTTOMLEFT", 0, -12)
	self.dropdownActionText:SetText("Action:")

	self.dropdownSpellAction = CreateFrame("frame", "RSGUI_Reactions_dropdownSpellAction", panel, "UIDropDownMenuTemplate")
	self.dropdownSpellAction:SetPoint("LEFT", self.dropdownActionText, "RIGHT", -9, -3)
	self.dropdownEventAction = CreateFrame("frame", "RSGUI_Reactions_dropdownEventAction", panel, "UIDropDownMenuTemplate")
	self.dropdownEventAction:SetPoint("LEFT", self.dropdownActionText, "RIGHT", -9, -3)

	UIDropDownMenu_SetWidth(340, self.dropdownSpellAction)
	UIDropDownMenu_SetWidth(340, self.dropdownEventAction)
	UIDropDownMenu_JustifyText("LEFT", self.dropdownSpellAction)
	UIDropDownMenu_JustifyText("LEFT", self.dropdownEventAction)

	-- travel time
	self.checkboxTravelTime = RSGUI.Utility.CreateCheckbox("reactionsTravelTime", panel, "Has travel time",
			"Check this for spells like Wrath that travel through the air before hitting/missing a target.")
	self.checkboxTravelTime:SetPoint("LEFT", self.dropdownSpellAction, "RIGHT", -15, 0)
	self.checkboxTravelTime:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local spell = self.currentAction.name and self.main.settings["reactionList"][self.currentAction.name]
		if spell then
			spell.travelTime = self.checkboxTravelTime:GetChecked() or nil
		end
	end)

	-- delete action button
	self.buttonDeleteAction = RSGUI.Utility.CreateButton("Reactions_DeleteAction", panel, 120, "Delete Action")
	self.buttonDeleteAction:SetPoint("RIGHT", self.dropdownActionText, "LEFT", self.borderTop:GetRight()-self.dropdownActionText:GetLeft(), 0)
	self.buttonDeleteAction:SetScript("OnClick", function()
		if self.currentAction.name and self.currentAction.action then
			self.main:RemoveHistory(self.currentAction.isEvent and "event" or "spell",
				self.currentAction.name, actionTypeList[self.currentAction.action][1])
			local spell = self.main.settings["reactionList"][self.currentAction.name]
			if spell then
				spell.lastActionOpened = nil
				spell[actionTypeList[self.currentAction.action][1]] = nil
				self.main:BuildGroupsMenu(true)
				if self.currentAction.isEvent then
					self.main:RenameEventsMenuItem(self.currentAction.name)
				end
			end
		end
		self:Open(self.currentAction.name, self.currentAction.isEvent)
	end)

	-- group - text
	self.textGroup = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textGroup:SetPoint("TOPLEFT", self.dropdownActionText, "BOTTOMLEFT", 0, -22)
	self.textGroup:SetText("Group:")

	-- chance - text
	self.textChance = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textChance:SetPoint("TOPLEFT", self.textGroup, "BOTTOMLEFT", 0, -12)
	self.textChance:SetText("Chance:")

	-- override global cooldown - text
	self.textCooldown = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.textCooldown:SetPoint("TOPLEFT", self.textChance, "BOTTOMLEFT", 0, -12)
	self.textCooldown:SetText("Override GCD:")

	-- group - input
	self.inputGroup = CreateFrame("EditBox", "RSGUI_Reactions_inputGroup", panel, "InputBoxTemplate")
	self.inputGroup:SetWidth(100)
	self.inputGroup:SetHeight(12)
	self.inputGroup:SetPoint("LEFT", self.textGroup, "LEFT", self.textCooldown:GetWidth() + 8, 0)
	self.inputGroup:SetMaxLetters(16)
	self.inputGroup:SetAutoFocus(false)
	self.inputGroup:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputGroup:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentActionData()
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
	self.inputChance = CreateFrame("EditBox", "RSGUI_Reactions_inputChance", panel, "InputBoxTemplate")
	self.inputChance:SetWidth(46)
	self.inputChance:SetHeight(12)
	self.inputChance:SetPoint("LEFT", self.textChance, "LEFT", self.textCooldown:GetWidth() + 8, 0)
	self.inputChance:SetMaxLetters(5)
	self.inputChance:SetAutoFocus(false)
	self.inputChance:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputChance:SetScript("OnTextChanged", function() RSGUI.Utility.FixChanceNumber(self.inputChance) end)
	self.inputChance:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentActionData()
		if not data then return end
		data.chance = RSGUI.Utility.FixChanceNumber(self.inputChance)
		if data.chance == 0 then
			self.inputChance:SetText(0)
		end
	end)

	-- override global cooldown - input
	self.inputCooldown = CreateFrame("EditBox", "RSGUI_Reactions_inputCooldown", panel, "InputBoxTemplate")
	self.inputCooldown:SetWidth(46)
	self.inputCooldown:SetHeight(12)
	self.inputCooldown:SetPoint("LEFT", self.textCooldown, "LEFT", self.textCooldown:GetWidth() + 8, 0)
	self.inputCooldown:SetNumeric(true)
	self.inputCooldown:SetMaxLetters(5)
	self.inputCooldown:SetAutoFocus(false)
	self.inputCooldown:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputCooldown:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentActionData()
		if data then
			data.cooldown = tonumber(self.inputCooldown:GetText())
		end
	end)
	self.inputCooldown.tooltipText = "Seconds to wait before being able to react again after a spell or event triggers a global cooldown, or blank to use the default time from the options."
	self.inputCooldown:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
	self.inputCooldown:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)

	-- be able to tab through some options
	self.inputGroup:SetScript("OnTabPressed",    function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputCooldown:SetFocus() else self.inputChance:SetFocus()   end end)
	self.inputChance:SetScript("OnTabPressed",   function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputGroup:SetFocus()    else self.inputCooldown:SetFocus() end end)
	self.inputCooldown:SetScript("OnTabPressed", function() this:HighlightText(0,0) if IsShiftKeyDown() then self.inputChance:SetFocus()   else self.inputGroup:SetFocus()    end end)

	-- limit once per fight setting
	self.checkboxLimitFights = RSGUI.Utility.CreateCheckbox("limitFights", panel, "Limit once per fight(s):")
	self.checkboxLimitFights:SetPoint("LEFT", self.textGroup, "LEFT", 200, 0)

	self.inputLimitFights = CreateFrame("EditBox", "RSGUI_Reactions_inputLimitFights", panel, "InputBoxTemplate")
	self.inputLimitFights:SetWidth(46)
	self.inputLimitFights:SetHeight(12)

	self.inputLimitFights:SetPoint("LEFT", self.checkboxLimitFights, "LEFT",
		self.checkboxLimitFights:GetWidth() + _G[self.checkboxLimitFights:GetName().."Text"]:GetWidth() + 6, 0)
	self.inputLimitFights:SetNumeric(true)
	self.inputLimitFights:SetMaxLetters(5)
	self.inputLimitFights:SetAutoFocus(false)
	self.inputLimitFights:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	self.inputLimitFights:SetScript("OnEditFocusLost", function()
		local data = self:GetCurrentActionData()
		if not data then return end
		data.limitFightsAmount = tonumber(self.inputLimitFights:GetText())
		if not data.limitFightsAmount then
			data.limitFightsAmount = 1
			self.inputLimitFights:SetText(1)
		end
	end)

	self.checkboxLimitFights:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentActionData()
		if not data then return end
		data.limitFights = self.checkboxLimitFights:GetChecked() or nil
		if data.limitFights then
			data.limitFightsAmount = tonumber(self.inputLimitFights:GetText())
			if not data.limitFightsAmount then
				data.limitFightsAmount = 1
				self.inputLimitFights:SetText(1)
			end
		else
			data.limitFightsAmount = nil
		end
	end)

	-- limit once per group setting
	self.checkboxLimitGroup = RSGUI.Utility.CreateCheckbox("reactionsLimitGroup", panel, "Limit once per group")
	self.checkboxLimitGroup:SetPoint("LEFT", self.textChance, "LEFT", 200, 0)
	self.checkboxLimitGroup:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentActionData()
		if data then
			data.limitGroup = self.checkboxLimitGroup:GetChecked() or nil
		end
	end)

	-- limit once per aura setting
	self.checkboxLimitAura = RSGUI.Utility.CreateCheckbox("reactionsLimitAura", panel, "Limit once per aura",
			[[Some mobs have special cases (like Vashj's static charge thing) that counts every periodic hit as "You are hit." To only react to the first hit until its aura is gone, use this.]])
	self.checkboxLimitAura:SetPoint("LEFT", self.textCooldown, "LEFT", 200, 0)
	self.checkboxLimitAura:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentActionData()
		if data then
			data.limitAura = self.checkboxLimitAura:GetChecked() or nil
		end
	end)

	-- limit once per target name setting
	self.checkboxLimitName = RSGUI.Utility.CreateCheckbox("reactionsLimitName", panel, "Limit once per target name in fight")
	self.checkboxLimitName:SetPoint("LEFT", self.textGroup, "LEFT", 420, 0)
	self.checkboxLimitName:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentActionData()
		if data then
			data.limitName = self.checkboxLimitName:GetChecked() or nil
		end
	end)

	-- don't trigger global cooldown
	self.checkboxNoGCD = RSGUI.Utility.CreateCheckbox("reactionsNoGCD", panel, "Don't activate global cooldown on use")
	self.checkboxNoGCD:SetPoint("LEFT", self.textChance, "LEFT", 420, 0)
	self.checkboxNoGCD:SetScript("OnClick", function()
		RSGUI.Utility.ClearAnyFocus()
		local data = self:GetCurrentActionData()
		if data then
			data.noGCD = self.checkboxNoGCD:GetChecked() or nil
		end
	end)

	-- new reaction button
	self.buttonNewReaction = RSGUI.Utility.CreateButton("Reactions_NewReaction", panel, 120, "Add Reaction")
	self.buttonNewReaction:SetPoint("LEFT", self.textCooldown, "LEFT", self.buttonDeleteAction:GetLeft()-self.textCooldown:GetLeft(), 0)

	-- bottom border
	self.borderBottom = panel:CreateTexture()
	self.borderBottom:SetTexture(.4, .4, .4)
	self.borderBottom:SetWidth(panel:GetWidth())
	self.borderBottom:SetHeight(1)
	self.borderBottom:SetPoint("TOP", panel, "TOP", 0, 0-(panel:GetTop()-self.textCooldown:GetBottom())-11)

	--------------------------------------------------
	-- scrollable reaction list section
	--------------------------------------------------
	self.contentTable      = {}  -- widgets and data to control the groups
	self.contentTable.list = nil -- reference to the current action's reactions

	--------------------
	-- Language button
	--------------------
	local settingLanguageButton -- index of the language button being set

	local function SetLanguageFromMenu(self)
		self:SetLanguageIcon(settingLanguageButton, this.value)
		local reaction = self.contentTable.list[self.contentTable[settingLanguageButton].channelDropdown.listIndex]
		if reaction then
			reaction[4] = this.value ~= "Common" and this.value or nil
		end
	end

	-- language
	self.languageButtonMenu = nil -- only set if they know at least 2 languages
	if GetNumLanguages() > 1 then
		self.languageButtonMenu = {
			{notCheckable=1, text="Language to use", isTitle=true},
			{notCheckable=1, func=SetLanguageFromMenu, arg1=self,  value="Common", icon=LanguageButtonIcon["Common"], text=(GetLanguageByIndex(1))},
		}
		self.languageButtonMenu[#self.languageButtonMenu+1] = {notCheckable=1, func=SetLanguageFromMenu, arg1=self, value="Racial", icon=LanguageButtonIcon["Racial"], text=(GetLanguageByIndex(2))}
		self.languageButtonMenu[#self.languageButtonMenu+1] = {notCheckable=1, func=SetLanguageFromMenu, arg1=self, value="Random", icon=LanguageButtonIcon["Random"], text="Random"}
		self.languageButtonMenu[#self.languageButtonMenu+1] = {notCheckable=1, text="Close"}
	end

	--------------------
	-- Form button
	--------------------
	local settingFormButton -- index of the form button being set

	local function SetFormFromMenu(self)
		self:SetFormIcon(settingFormButton, this.value)
		local reaction = self.contentTable.list[self.contentTable[settingFormButton].channelDropdown.listIndex]
		if reaction then
			reaction[5] = this.value ~= "Any" and this.value or nil
		end
	end

	self.formButtonMenu = nil -- only set if the class actually has forms or stances
	do
		local _, class = UnitClass("player")
		if class == "DRUID" then
			self.formButtonMenu = {
				{notCheckable=1, text="Required Form", isTitle=true},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Any",              icon=formButtonIcon["Any"],              text="Use in any form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Normal",           icon=formButtonIcon["Normal"],           text="Only use in caster form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Aquatic Form",     icon=formButtonIcon["Aquatic Form"],     text="Only use in Aquatic Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Cat Form",         icon=formButtonIcon["Cat Form"],         text="Only use in Cat Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Bear Form",        icon=formButtonIcon["Bear Form"],        text="Only use in Bear Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Flight Form",      icon=formButtonIcon["Flight Form"],      text="Only use in Flight Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Moonkin Form",     icon=formButtonIcon["Moonkin Form"],     text="Only use in Moonkin Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Travel Form",      icon=formButtonIcon["Travel Form"],      text="Only use in Travel Form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Tree Form",        icon=formButtonIcon["Tree Form"],        text="Only use in Tree Form"},
				{notCheckable=1, text="Close"},
			}
		elseif class == "WARRIOR" then
			self.formButtonMenu = {
				{notCheckable=1, text="Required Stance", isTitle=true},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Any",              icon=formButtonIcon["Any"],              text="Use in any stance"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Battle Stance",    icon=formButtonIcon["Battle Stance"],    text="Only use in Battle Stance"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Berserker Stance", icon=formButtonIcon["Berserker Stance"], text="Only use in Berserker Stance"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Defensive Stance", icon=formButtonIcon["Defensive Stance"], text="Only use in Defensive Stance"},
				{notCheckable=1, text="Close"},
			}
		elseif class == "PRIEST" then
			self.formButtonMenu = {
				{notCheckable=1, text="Required Form", isTitle=true},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Any",              icon=formButtonIcon["Any"],              text="Use in any form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Normal",           icon=formButtonIcon["Normal"],           text="Only use in normal form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Shadowform",       icon=formButtonIcon["Shadowform"],       text="Only use in shadowform"},
				{notCheckable=1, text="Close"},
			}
		elseif class == "SHAMAN" then
			self.formButtonMenu = {
				{notCheckable=1, text="Required Form", isTitle=true},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Any",              icon=formButtonIcon["Any"],              text="Use in any form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Normal",           icon=formButtonIcon["Normal"],           text="Only use in caster form"},
				{notCheckable=1, func=SetFormFromMenu, arg1=self, value="Ghost Wolf",       icon=formButtonIcon["Ghost Wolf"],       text="Only use as Ghost Wolf"},
				{notCheckable=1, text="Close"},
			}
		end
	end

	--------------------
	-- role item button
	--------------------
	self.roleItemButtonMenu = nil
	local settingRoleItemButton -- index of the role item button being set

	function SetRoleItemFromMenu(self)
		self:SetRoleItemIcon(settingRoleItemButton, this.value)
		local reaction = self.contentTable.list[self.contentTable[settingRoleItemButton].channelDropdown.listIndex]
		if reaction then
			reaction[7] = this.value > 0 and this.value or 0
		end
	end

	--------------------
	-- Conditions button
	--------------------
	self.currentConditionButton = nil -- index of the conditions button being set

	local function SetConditionsFromMenu(conditionType, _, checked)
		local reaction = self.contentTable.list[self.contentTable[self.currentConditionButton].channelDropdown.listIndex]
		local conditionTable
		if reaction then
			-- only unchecked things go on the list, so if it's checked then remove it and possibly the whole table
			if not checked then
				reaction[6] = reaction[6] or {}
				reaction[6][this.value] = true
				reaction[6][conditionType] = reaction[6][conditionType] and (reaction[6][conditionType] + 1) or 1
			elseif reaction[6] then
				reaction[6][this.value] = nil
				if reaction[6][conditionType] then
					reaction[6][conditionType] = reaction[6][conditionType] - 1
					if reaction[6][conditionType] <= 0 then
						reaction[6][conditionType] = nil
					end
				end
				-- remove the table if it's empty
				if next(reaction[6]) == nil then
					reaction[6] = nil
				end
			end
			self:SetConditionsIcon(self.currentConditionButton, reaction[6])
		end
	end

	-- Extreme condition tables creation!
	-- * Names start with color codes to be easily toggled between white and red.
	-- * conditionsButtonMenu.All contains menus that every action will show. An attempt will be made
	--   to only add the other tables like conditionsButtonMenu.TargetMobs if they are relevant.
	-- * Some condition values have names to make them faster to check - like misses being named as
	--   a value you get from an event.
	local CONDITION_TYPE_MISCELLANEOUS = 10001
	local CONDITION_TYPE_COMBAT        = 10002
	local CONDITION_TYPE_PARTY         = 10003
	local CONDITION_TYPE_PLACE         = 10004
	local CONDITION_TYPE_PLAYER        = 10005
	local CONDITION_TYPE_GROUP_MEMBER  = 10006
	local CONDITION_TYPE_CASTER        = 10007
	local CONDITION_TYPE_TARGET        = 10008
	local CONDITION_TYPE_AFFECTED      = 10009

	local conditionsButtonMenu = {}
	conditionsButtonMenu.Title = {notCheckable=1, text="Allowed Conditions", isTitle=true}
	conditionsButtonMenu.All = {
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffGroups|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("Ungrouped")        end, value="Ungrouped",        text="|cffffffffWhile ungrouped|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("Party")            end, value="Party",            text="|cffffffffWhile in a party|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("Raid")             end, value="Raid",             text="|cffffffffWhile in a raid|r"},
			{notCheckable=1,  notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("GroupLeader")      end, value="GroupLeader",      text="|cffffffffWhile a group leader/assistant|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("NotGroupLeader")   end, value="NotGroupLeader",   text="|cffffffffWhile not a group leader/assistant|r"},
			{notCheckable=1,  notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("MasterLooter")     end, value="MasterLooter",     text="|cffffffffWhile master looter|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("NotMasterLooter")  end, value="NotMasterLooter",  text="|cffffffffWhile not master looter|r"},
			{notCheckable=1,  notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("HavePet")          end, value="HavePet",          text="|cffffffffCombat pet is summoned|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PARTY, checked=function() return self:IsConditionsItemChecked("HaveNoPet")        end, value="HaveNoPet",        text="|cffffffffCombat pet isn't summoned|r"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffCharacter|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharMounted")      end, value="CharMounted",      text="|cffffffffWhile mounted|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharNotMounted")   end, value="CharNotMounted",   text="|cffffffffWhile not mounted|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharFlying")       end, value="CharFlying",       text="|cffffffffWhile flying|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharNotFlying")    end, value="CharNotFlying",    text="|cffffffffWhile not flying|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharSwimming")     end, value="CharSwimming",     text="|cffffffffWhile swimming|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharNotSwimming")  end, value="CharNotSwimming",  text="|cffffffffWhile not swimming|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharStealthed")    end, value="CharStealthed",    text="|cffffffffWhile stealthed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharNotStealthed") end, value="CharNotStealthed", text="|cffffffffWhile not stealthed|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharHighHealth")   end, value="CharHighHealth",   text="|cffffffffWhile at high health|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharMediumHealth") end, value="CharMediumHealth", text="|cffffffffWhile at medium health|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharLowHealth")    end, value="CharLowHealth",    text="|cffffffffWhile at low health|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharHighPower")    end, value="CharHighPower",    text="|cffffffffWhile at high power|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharMediumPower")  end, value="CharMediumPower",  text="|cffffffffWhile at medium power|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLAYER, checked=function() return self:IsConditionsItemChecked("CharLowPower")     end, value="CharLowPower",     text="|cffffffffWhile at low power|r"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffAffected By|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(12) end, value=12, text="|cffffffffYou are asleep|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(15) end, value=15, text="|cffffffffYou are bandaging|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(6)  end, value=6,  text="|cffffffffYou are banished|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(3)  end, value=3,  text="|cffffffffYou are bleeding|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(10) end, value=10, text="|cffffffffYou are charmed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(17) end, value=17, text="|cffffffffYou are disarmed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(7)  end, value=7,  text="|cffffffffYou are disoriented|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(2)  end, value=2,  text="|cffffffffYou are feared|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(13) end, value=13, text="|cffffffffYou are frozen|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(14) end, value=14, text="|cffffffffYou are immune|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(5)  end, value=5,  text="|cffffffffYou are polymorphed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(4)  end, value=4,  text="|cffffffffYou are rooted|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(9)  end, value=9,  text="|cffffffffYou are sapped|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(16) end, value=16, text="|cffffffffYou are shielded|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(11) end, value=11, text="|cffffffffYou are silenced|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(8)  end, value=8,  text="|cffffffffYou are snared or dazed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(1)  end, value=1,  text="|cffffffffYou are stunned|r"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffNot Affected By|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-12) end, value=-12, text="|cffffffffYou are not asleep|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-15) end, value=-15, text="|cffffffffYou are not bandaging|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-6)  end, value=-6,  text="|cffffffffYou are not banished|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-3)  end, value=-3,  text="|cffffffffYou are not bleeding|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-10) end, value=-10, text="|cffffffffYou are not charmed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-17) end, value=-17, text="|cffffffffYou are not disarmed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-7)  end, value=-7,  text="|cffffffffYou are not disoriented|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-2)  end, value=-2,  text="|cffffffffYou are not feared|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-13) end, value=-13, text="|cffffffffYou are not frozen|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-14) end, value=-14, text="|cffffffffYou are not immune|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-5)  end, value=-5,  text="|cffffffffYou are not polymorphed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-4)  end, value=-4,  text="|cffffffffYou are not rooted|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-9)  end, value=-9,  text="|cffffffffYou are not sapped|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-16) end, value=-16, text="|cffffffffYou are not shielded|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-11) end, value=-11, text="|cffffffffYou are not silenced|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-8)  end, value=-8,  text="|cffffffffYou are not snared or dazed|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_AFFECTED, checked=function() return self:IsConditionsItemChecked(-1)  end, value=-1,  text="|cffffffffYou are not stunned|r"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffPlaces|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Indoors")  end, value="Indoors",  text="|cffffffffIn indoor locations|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Outdoors") end, value="Outdoors", text="|cffffffffIn outdoor locations|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("WorldZones")    end, value="WorldZones",    text="|cffffffffIn world zones|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Instances")     end, value="Instances",     text="|cffffffffIn instances|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Battlegrounds") end, value="Battlegrounds", text="|cffffffffIn battlegrounds|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Arenas")        end, value="Arenas",        text="|cffffffffIn arenas|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Friendly")  end, value="Friendly",  text="|cffffffffIn a friendly area|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Hostile")   end, value="Hostile",   text="|cffffffffIn a hostile area|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Contested") end, value="Contested", text="|cffffffffIn a contested area|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_PLACE, checked=function() return self:IsConditionsItemChecked("Sanctuary") end, value="Sanctuary", text="|cffffffffIn a sanctuary area|r"},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffTimes|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Morning")   end, value="Morning",   text="|cffffffffDuring game time morning (5:00 - 11:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Afternoon") end, value="Afternoon", text="|cffffffffDuring game time afternoon (12:00 - 16:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Evening")   end, value="Evening",   text="|cffffffffDuring game time evening (17:00 - 18:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Night")     end, value="Night",     text="|cffffffffDuring game time night (19:00 - 4:59)|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("RealMorning")   end, value="RealMorning",   text="|cffffffffDuring real time morning (5:00 - 11:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("RealAfternoon") end, value="RealAfternoon", text="|cffffffffDuring real time afternoon (12:00 - 16:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("RealEvening")   end, value="RealEvening",   text="|cffffffffDuring real time evening (17:00 - 18:59)|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("RealNight")     end, value="RealNight",     text="|cffffffffDuring real time night (19:00 - 4:59)|r"},
		}},
	}

	conditionsButtonMenu.Combat =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffCombat|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("InCombat") end, value="InCombat", text="|cffffffffWhile you are in combat|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("NoCombat") end, value="NoCombat", text="|cffffffffWhile you are out of combat|r"},
		}}

	conditionsButtonMenu.HitsAndMisses =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffHits & Misses|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("Normal")   end, value="Normal",   text="|cffffffffHit is normal|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("Critical") end, value="Critical", text="|cffffffffHit is critical|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("Crushing") end, value="Crushing", text="|cffffffffHit is crushing blow|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("Glancing") end, value="Glancing", text="|cffffffffHit is glancing blow|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("MISS")     end, value="MISS",     text="|cffffffffMiss type is miss|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("DODGE")    end, value="DODGE",    text="|cffffffffMiss type is dodge|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("RESIST")   end, value="RESIST",   text="|cffffffffMiss type is resist|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("ABSORB")   end, value="ABSORB",   text="|cffffffffMiss type is absorb|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("REFLECT")  end, value="REFLECT",  text="|cffffffffMiss type is reflect|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("PARRY")    end, value="PARRY",    text="|cffffffffMiss type is parry|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("BLOCK")    end, value="BLOCK",    text="|cffffffffMiss type is block|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("IMMUNE")   end, value="IMMUNE",   text="|cffffffffMiss type is immune|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_COMBAT, checked=function() return self:IsConditionsItemChecked("EVADE")    end, value="EVADE",    text="|cffffffffMiss type is evade|r"},
		}}

	conditionsButtonMenu.SpellRanks =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffSpell Rank|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 1")   end, value="Rank 1",   text="|cffffffffRank 1|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 2")   end, value="Rank 2",   text="|cffffffffRank 2|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 3")   end, value="Rank 3",   text="|cffffffffRank 3|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 4")   end, value="Rank 4",   text="|cffffffffRank 4|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 5")   end, value="Rank 5",   text="|cffffffffRank 5|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 6")   end, value="Rank 6",   text="|cffffffffRank 6|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 7")   end, value="Rank 7",   text="|cffffffffRank 7|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 8")   end, value="Rank 8",   text="|cffffffffRank 8|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 9")   end, value="Rank 9",   text="|cffffffffRank 9|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 10")  end, value="Rank 10",  text="|cffffffffRank 10|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 11")  end, value="Rank 11",  text="|cffffffffRank 11|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 12")  end, value="Rank 12",  text="|cffffffffRank 12|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 13")  end, value="Rank 13",  text="|cffffffffRank 13|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 14")  end, value="Rank 14",  text="|cffffffffRank 14|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 15")  end, value="Rank 15",  text="|cffffffffRank 15|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_MISCELLANEOUS, checked=function() return self:IsConditionsItemChecked("Rank 16")  end, value="Rank 16",  text="|cffffffffRank 16|r"},
		}}

	conditionsButtonMenu.GroupAll =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffGroup Member|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupMyPet")      end, value="GroupMyPet",      text="|cffffffffGroup member is your pet|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupNotMyPet")   end, value="GroupNotMyPet",   text="|cffffffffGroup member is another's pet|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupSexMale")    end, value="GroupSexMale",    text="|cffffffffGroup member's sex is male|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupSexFemale")  end, value="GroupSexFemale",  text="|cffffffffGroup member's sex is female|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupSexUnknown") end, value="GroupSexUnknown", text="|cffffffffGroup member's sex is unknown|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupFriend")     end, value="GroupFriend",     text="|cffffffffGroup member is on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupNotFriend")  end, value="GroupNotFriend",  text="|cffffffffGroup member is not on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupGuild")      end, value="GroupGuild",      text="|cffffffffGroup member is guild member|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupNotGuild")   end, value="GroupNotGuild",   text="|cffffffffGroup member is not guild member|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupHuman")      end, value="GroupHuman",      text="|cffffffffGroup member's race is Human|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupDwarf")      end, value="GroupDwarf",      text="|cffffffffGroup member's race is Dwarf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupNightElf")   end, value="GroupNightElf",   text="|cffffffffGroup member's race is Night Elf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupGnome")      end, value="GroupGnome",      text="|cffffffffGroup member's race is Gnome|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupDraenei")    end, value="GroupDraenei",    text="|cffffffffGroup member's race is Draenei|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupOrc")        end, value="GroupOrc",        text="|cffffffffGroup member's race is Orc|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupScourge")    end, value="GroupScourge",    text="|cffffffffGroup member's race is Undead|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupTauren")     end, value="GroupTauren",     text="|cffffffffGroup member's race is Tauren|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupTroll")      end, value="GroupTroll",      text="|cffffffffGroup member's race is Troll|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_GROUP_MEMBER, checked=function() return self:IsConditionsItemChecked("GroupBloodElf")   end, value="GroupBloodElf",   text="|cffffffffGroup member's race is Blood Elf|r"},
		}}

	conditionsButtonMenu.CasterAll =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffCaster (All)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterSelf")       end, value="CasterSelf",       text="|cffffffffCaster is yourself|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNotSelf")    end, value="CasterNotSelf",    text="|cffffffffCaster is not yourself|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterMyPet")      end, value="CasterMyPet",      text="|cffffffffCaster is your pet|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNotMyPet")   end, value="CasterNotMyPet",   text="|cffffffffCaster is group member's pet|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterFriendly")   end, value="CasterFriendly",   text="|cffffffffCaster is friendly|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNeutral")    end, value="CasterNeutral",    text="|cffffffffCaster is neutral|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterHostile")    end, value="CasterHostile",    text="|cffffffffCaster is hostile|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterSexMale")    end, value="CasterSexMale",    text="|cffffffffCaster's sex is male|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterSexFemale")  end, value="CasterSexFemale",  text="|cffffffffCaster's sex is female|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterSexUnknown") end, value="CasterSexUnknown", text="|cffffffffCaster's sex is unknown|r"},
		}}

	conditionsButtonMenu.TargetAll =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffTarget (All)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetSelf")      end, value="TargetSelf",       text="|cffffffffTarget is yourself|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNotSelf")   end, value="TargetNotSelf",    text="|cffffffffTarget is not yourself|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetMyPet")     end, value="TargetMyPet",      text="|cffffffffTarget is your pet|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNotMyPet")  end, value="TargetNotMyPet",   text="|cffffffffTarget is group member's pet|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetFriendly")  end, value="TargetFriendly",   text="|cffffffffTarget is friendly|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNeutral")   end, value="TargetNeutral",    text="|cffffffffTarget is neutral|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetHostile")   end, value="TargetHostile",    text="|cffffffffTarget is hostile|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetSexMale")    end, value="TargetSexMale",    text="|cffffffffTarget's sex is male|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetSexFemale")  end, value="TargetSexFemale",  text="|cffffffffTarget's sex is female|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetSexUnknown") end, value="TargetSexUnknown", text="|cffffffffTarget's sex is unknown|r"},
		}}

	conditionsButtonMenu.CasterMobs =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffCaster (Mobs)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterMob")            end, value="CasterMob",            text="|cffffffffCaster is a mob/NPC|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Casterworldboss")      end, value="Casterworldboss",      text="|cffffffffCaster is boss|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Casterrareelite")      end, value="Casterrareelite",      text="|cffffffffCaster is rare-elite|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Casterelite")          end, value="Casterelite",          text="|cffffffffCaster is elite|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Casterrare")           end, value="Casterrare",           text="|cffffffffCaster is rare|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Casternormal")         end, value="Casternormal",         text="|cffffffffCaster is normal|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("Castertrivial")        end, value="Castertrivial",        text="|cffffffffCaster is trivial|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterBeast")          end, value="CasterBeast",          text="|cffffffffCaster type is Beast|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterDragonkin")      end, value="CasterDragonkin",      text="|cffffffffCaster type is Dragonkin|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterDemon")          end, value="CasterDemon",          text="|cffffffffCaster type is Demon|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterElemental")      end, value="CasterElemental",      text="|cffffffffCaster type is Elemental|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterGiant")          end, value="CasterGiant",          text="|cffffffffCaster type is Giant|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterUndead")         end, value="CasterUndead",         text="|cffffffffCaster type is Undead|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterHumanoid")       end, value="CasterHumanoid",       text="|cffffffffCaster type is Humanoid|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterCritter")        end, value="CasterCritter",        text="|cffffffffCaster type is Critter|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterMechanical")     end, value="CasterMechanical",     text="|cffffffffCaster type is Mechanical|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNot specified")  end, value="CasterNot specified",  text="|cffffffffCaster type is Not specified|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterTotem")          end, value="CasterTotem",          text="|cffffffffCaster type is Totem|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNon-combat Pet") end, value="CasterNon-combat Pet", text="|cffffffffCaster type is Non-combat Pet|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterGas Cloud")      end, value="CasterGas Cloud",      text="|cffffffffCaster type is Gas Cloud|r"},
		}}

	conditionsButtonMenu.TargetMobs =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffTarget (Mobs)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetMob")            end, value="TargetMob",            text="|cffffffffTarget is a mob/NPC|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targetworldboss")      end, value="Targetworldboss",      text="|cffffffffTarget is boss|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targetrareelite")      end, value="Targetrareelite",      text="|cffffffffTarget is rare-elite|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targetelite")          end, value="Targetelite",          text="|cffffffffTarget is elite|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targetrare")           end, value="Targetrare",           text="|cffffffffTarget is rare|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targetnormal")         end, value="Targetnormal",         text="|cffffffffTarget is normal|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("Targettrivial")        end, value="Targettrivial",        text="|cffffffffTarget is trivial|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetBeast")          end, value="TargetBeast",          text="|cffffffffTarget type is Beast|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetDragonkin")      end, value="TargetDragonkin",      text="|cffffffffTarget type is Dragonkin|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetDemon")          end, value="TargetDemon",          text="|cffffffffTarget type is Demon|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetElemental")      end, value="TargetElemental",      text="|cffffffffTarget type is Elemental|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetGiant")          end, value="TargetGiant",          text="|cffffffffTarget type is Giant|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetUndead")         end, value="TargetUndead",         text="|cffffffffTarget type is Undead|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetHumanoid")       end, value="TargetHumanoid",       text="|cffffffffTarget type is Humanoid|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetCritter")        end, value="TargetCritter",        text="|cffffffffTarget type is Critter|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetMechanical")     end, value="TargetMechanical",     text="|cffffffffTarget type is Mechanical|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNot specified")  end, value="TargetNot specified",  text="|cffffffffTarget type is Not specified|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetTotem")          end, value="TargetTotem",          text="|cffffffffTarget type is Totem|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNon-combat Pet") end, value="TargetNon-combat Pet", text="|cffffffffTarget type is Non-combat Pet|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetGas Cloud")      end, value="TargetGas Cloud",      text="|cffffffffTarget type is Gas Cloud|r"},
		}}

	conditionsButtonMenu.CasterPlayers =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffCaster (Players)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterPlayer")    end, value="CasterPlayer",    text="|cffffffffCaster is a player|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterFriend")    end, value="CasterFriend",    text="|cffffffffCaster is on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNotFriend") end, value="CasterNotFriend", text="|cffffffffCaster is not on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterGuild")     end, value="CasterGuild",     text="|cffffffffCaster is guild member|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNotGuild")  end, value="CasterNotGuild",  text="|cffffffffCaster is not guild member|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterHuman")     end, value="CasterHuman",     text="|cffffffffCaster's race is Human|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterDwarf")     end, value="CasterDwarf",     text="|cffffffffCaster's race is Dwarf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterNightElf")  end, value="CasterNightElf",  text="|cffffffffCaster's race is Night Elf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterGnome")     end, value="CasterGnome",     text="|cffffffffCaster's race is Gnome|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterDraenei")   end, value="CasterDraenei",   text="|cffffffffCaster's race is Draenei|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterOrc")       end, value="CasterOrc",       text="|cffffffffCaster's race is Orc|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterScourge")   end, value="CasterScourge",   text="|cffffffffCaster's race is Undead|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterTauren")    end, value="CasterTauren",    text="|cffffffffCaster's race is Tauren|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterTroll")     end, value="CasterTroll",     text="|cffffffffCaster's race is Troll|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_CASTER, checked=function() return self:IsConditionsItemChecked("CasterBloodElf")  end, value="CasterBloodElf",  text="|cffffffffCaster's race is Blood Elf|r"},
		}}

	conditionsButtonMenu.TargetPlayers =
		{notCheckable=1, notClickable=1, hasArrow=1, text="|cffffffffTarget (Players)|r", menuList={
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetPlayer")    end, value="TargetPlayer",    text="|cffffffffTarget is a player|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetFriend")    end, value="TargetFriend",    text="|cffffffffTarget is on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNotFriend") end, value="TargetNotFriend", text="|cffffffffTarget is not on friends list|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetGuild")     end, value="TargetGuild",     text="|cffffffffTarget is guild member|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNotGuild")  end, value="TargetNotGuild",  text="|cffffffffTarget is not guild member|r"},
			{notCheckable=1, notClickable=1, text=""},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetHuman")     end, value="TargetHuman",     text="|cffffffffTarget's race is Human|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetDwarf")     end, value="TargetDwarf",     text="|cffffffffTarget's race is Dwarf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetNightElf")  end, value="TargetNightElf",  text="|cffffffffTarget's race is Night Elf|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetGnome")     end, value="TargetGnome",     text="|cffffffffTarget's race is Gnome|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetDraenei")   end, value="TargetDraenei",   text="|cffffffffTarget's race is Draenei|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetOrc")       end, value="TargetOrc",       text="|cffffffffTarget's race is Orc|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetScourge")   end, value="TargetScourge",   text="|cffffffffTarget's race is Undead|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetTauren")    end, value="TargetTauren",    text="|cffffffffTarget's race is Tauren|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetTroll")     end, value="TargetTroll",     text="|cffffffffTarget's race is Troll|r"},
			{keepShownOnClick=1, func=SetConditionsFromMenu, arg1=CONDITION_TYPE_TARGET, checked=function() return self:IsConditionsItemChecked("TargetBloodElf")  end, value="TargetBloodElf",  text="|cffffffffTarget's race is Blood Elf|r"},
		}}
	conditionsButtonMenu.Close = {notCheckable=1, text="Close"}

	-- build the conditions menu based on what's allowed by the action and color unchecked items
	local function CreateAndOpenConditionMenu(index)
		local reaction = self.contentTable.list[self.contentTable[index].channelDropdown.listIndex]
		local conditions = reaction and reaction[6]

		-- building the menu - first add the sections that are always in it
		local menu = {}

		menu[1] = conditionsButtonMenu.Title

		-- add menu sections based on what's relevant to the action
		-- as usual there's very many special cases! Events can override the action type settings, but
		-- can also use special case values that may need to use some of the action type settings
		-- specialOverride is the EventCondition.* setting explained at the eventInformationList
		local conditionSettings = actionTypeList[self.currentAction.action][3]
		local override = self.currentAction.isEvent and FindEventInformation(self.currentAction.name)[4]
		local specialOverride = override and type(override) ~= "table" and override
		if specialOverride then
			override = nil
		end

		-- combat options
		if specialOverride ~= EventCondition.SIMPLE_ALL_NC and specialOverride ~= EventCondition.SIMPLE_PLAYER_NC then
			if (override and override[5]) or (not override and conditionSettings[5]) then
				menu[#menu+1] = conditionsButtonMenu.Combat
			end
		end

		-- main options
		for i=1,#conditionsButtonMenu.All do
			menu[#menu+1] = conditionsButtonMenu.All[i]
		end

		-- spell ranks
		if not self.currentAction.isEvent or specialOverride == EventCondition.SIMPLE_ALL_SPELL then
			menu[#menu+1] = conditionsButtonMenu.SpellRanks
		end

		-- specialOverride is the EventCondition.* setting explained at the eventInformationList
		if specialOverride then
			-- you
			if actionTypeList[self.currentAction.action][1] == "you_hit" then
				if specialOverride == EventCondition.TARGET_PLAYER then
					menu[#menu+1] = conditionsButtonMenu.TargetAll
					menu[#menu+1] = conditionsButtonMenu.TargetPlayers
				elseif specialOverride == EventCondition.TARGET_MOB then
					menu[#menu+1] = conditionsButtonMenu.TargetAll
					menu[#menu+1] = conditionsButtonMenu.TargetMobs
				elseif specialOverride == EventCondition.PAIR_NOHIT then
					menu[#menu+1] = conditionsButtonMenu.TargetAll
					menu[#menu+1] = conditionsButtonMenu.TargetPlayers
					menu[#menu+1] = conditionsButtonMenu.TargetMobs
				end
			else
				-- group member
				if conditionSettings[3] then
					menu[#menu+1] = conditionsButtonMenu.GroupAll
					if specialOverride == EventCondition.PAIR_NOHIT then
						menu[#menu+1] = conditionsButtonMenu.TargetAll
						menu[#menu+1] = conditionsButtonMenu.TargetPlayers
						menu[#menu+1] = conditionsButtonMenu.TargetMobs
					end
				-- non-group person
				else
					if specialOverride == EventCondition.PAIR_NOHIT then
						menu[#menu+1] = conditionsButtonMenu.CasterAll
						menu[#menu+1] = conditionsButtonMenu.CasterPlayers
						menu[#menu+1] = conditionsButtonMenu.CasterMobs
					end
					menu[#menu+1] = conditionsButtonMenu.TargetAll
					if specialOverride ~= EventCondition.SIMPLE_MOB then
						menu[#menu+1] = conditionsButtonMenu.TargetPlayers
					end
					if specialOverride ~= EventCondition.SIMPLE_PLAYER and specialOverride ~= EventCondition.SIMPLE_PLAYER_NC then
						menu[#menu+1] = conditionsButtonMenu.TargetMobs
					end
				end
			end
		else
			-- hits/misses
			if (override and override[1]) or (not override and conditionSettings[1]) then
				menu[#menu+1] = conditionsButtonMenu.HitsAndMisses
			end
			-- caster
			if (override and override[2]) or (not override and conditionSettings[2]) then
				menu[#menu+1] = conditionsButtonMenu.CasterAll
				menu[#menu+1] = conditionsButtonMenu.CasterPlayers
				menu[#menu+1] = conditionsButtonMenu.CasterMobs
			end
			-- group
			if (override and override[3]) or (not override and conditionSettings[3]) then
				menu[#menu+1] = conditionsButtonMenu.GroupAll
			end
			-- target
			if (override and override[4]) or (not override and conditionSettings[4]) then
				menu[#menu+1] = conditionsButtonMenu.TargetAll
				menu[#menu+1] = conditionsButtonMenu.TargetPlayers
				menu[#menu+1] = conditionsButtonMenu.TargetMobs
			end
		end

		menu[#menu+1] = conditionsButtonMenu.Close

		-- go though the menu to set the color for things
		local WHITE, RED = "|cffffffff", "|cffff0000"
		local unset -- if a submenu item was colored red, to know to set the parent red too
		local submenu
		for i=2,#menu-1 do -- skip the title and Close item
			submenu = menu[i].menuList
			unset = nil
			for j=1,#submenu do
				if not submenu[j].notCheckable then
					if conditions and conditions[submenu[j].value] then
						unset = true
						submenu[j].text = submenu[j].text:gsub(WHITE, RED)
					else
						submenu[j].text = submenu[j].text:gsub(RED, WHITE)
					end
				end
			end
			if unset then
				menu[i].text = menu[i].text:gsub(WHITE, RED)
			else
				menu[i].text = menu[i].text:gsub(RED, WHITE)
			end
		end

		RSGUI.menu:Open(menu, self.contentTable[index].conditionsButton)
	end

	-- scrollbar-like slider thing on side
	self.slider = CreateFrame("Slider", "RSGUI_Reactions_slider", panel, "OptionsSliderTemplate")
	self.slider:SetWidth(16)
	self.slider:SetHeight(panel:GetHeight()+(self.borderBottom:GetBottom()-panel:GetTop()))
	self.slider:SetPoint("TOPRIGHT", self.borderBottom, "BOTTOMRIGHT", 0, -5)
	self.slider:SetValueStep(1)
	self.slider:SetOrientation("VERTICAL")
	_G[self.slider:GetName().."Low"]:SetText("")
	_G[self.slider:GetName().."High"]:SetText("")
	_G[self.slider:GetName().."Text"]:SetText("")
	self.slider:Hide()
	self.slider:SetScript("OnValueChanged", function()
		-- if an input box has focus, move the focus up or down with it and keep the cursor position if possible
		local focusOnInput, cursorPosition
		for i=1,MAX_REACTIONS_SHOW do
			if self.contentTable[i].reactionInput:HasFocus() then
				local newIndex = this.previousValue < this:GetValue() and i-1 or i+1
				if newIndex < 1 or newIndex > MAX_REACTIONS_SHOW then
					focusOnInput = self.contentTable[i].reactionInput
				else
					focusOnInput = self.contentTable[newIndex].reactionInput
					cursorPosition = self.contentTable[i].reactionInput:GetCursorPosition()
				end
				self.contentTable[i].reactionInput:ClearFocus()
				break
			end
		end
		this.previousValue = this:GetValue() -- save to know which direction it's going
		self:ShowReactions(this:GetValue())
		if focusOnInput then
			focusOnInput:SetFocus()
			focusOnInput:SetCursorPosition(cursorPosition or 0)
		end
	end)

	-- build the widgets
	for i=1,MAX_REACTIONS_SHOW do
		self.contentTable[i] = {}

		-- delete button
		self.contentTable[i].deleteButton = CreateFrame("Button", "RSGUI_Reactions_deleteButton"..i, panel, "UIPanelCloseButton")
		self.contentTable[i].deleteButton:SetWidth(22)
		self.contentTable[i].deleteButton:SetHeight(22)
		if i == 1 then
			self.contentTable[i].deleteButton:SetPoint("TOPLEFT", self.borderBottom, "BOTTOMLEFT", -3, -16)
		else
			self.contentTable[i].deleteButton:SetPoint("TOPLEFT", self.contentTable[i-1].deleteButton, "BOTTOMLEFT", 0, -7)
		end

		-- the channel
		self.contentTable[i].channelDropdown = CreateFrame("frame", "RSGUI_Reactions_channelDropdown"..i, panel, "UIDropDownMenuTemplate")
		UIDropDownMenu_SetWidth(120, self.contentTable[i].channelDropdown)
		self.contentTable[i].channelDropdown:SetPoint("LEFT", self.contentTable[i].deleteButton, "RIGHT", -17, 0)

		-- language usage button
		if self.languageButtonMenu then
			self.contentTable[i].languageButton = CreateFrame("Button", "RSGUI_Reactions_languageButton"..i, panel)
			self.contentTable[i].languageButton:SetWidth(16)
			self.contentTable[i].languageButton:SetHeight(16)
			self.contentTable[i].languageButton:SetPoint("LEFT", self.contentTable[i].channelDropdown, "RIGHT", -13, 1)
			self.contentTable[i].languageButtonTexture = self.contentTable[i].languageButton:CreateTexture(nil, "BACKGROUND")
			self.contentTable[i].languageButtonTexture:SetTexture(LanguageButtonIcon["Common"])
			self.contentTable[i].languageButtonTexture:SetAllPoints(self.contentTable[i].languageButton)
		end

		-- form/stance options button
		if self.formButtonMenu then
			self.contentTable[i].formButton = CreateFrame("Button", "RSGUI_Reactions_formButton"..i, panel)
			self.contentTable[i].formButton:SetWidth(16)
			self.contentTable[i].formButton:SetHeight(16)
			if self.languageButtonMenu then
				self.contentTable[i].formButton:SetPoint("LEFT", self.contentTable[i].languageButton, "RIGHT", 2, 0)
			else
				self.contentTable[i].formButton:SetPoint("LEFT", self.contentTable[i].channelDropdown, "RIGHT", -13, 1)
			end
			self.contentTable[i].formButtonTexture = self.contentTable[i].formButton:CreateTexture(nil, "BACKGROUND")
			self.contentTable[i].formButtonTexture:SetAllPoints(self.contentTable[i].formButton)
			self:SetFormIcon(i, nil)
		end

		-- conditions button
		self.contentTable[i].conditionsButton = CreateFrame("Button", "RSGUI_Reactions_conditionsButton"..i, panel)
		self.contentTable[i].conditionsButton:SetWidth(16)
		self.contentTable[i].conditionsButton:SetHeight(16)
		if self.formButtonMenu or self.languageButtonMenu then
			self.contentTable[i].conditionsButton:SetPoint("LEFT", (self.formButtonMenu and self.contentTable[i].formButton) or self.contentTable[i].languageButton, "RIGHT", 2, 0)
		else
			self.contentTable[i].conditionsButton:SetPoint("LEFT", self.contentTable[i].channelDropdown, "RIGHT", -13, 1)
		end
		self.contentTable[i].conditionsButtonTexture = self.contentTable[i].conditionsButton:CreateTexture(nil, "BACKGROUND")
		self.contentTable[i].conditionsButtonTexture:SetTexture("Interface/BUTTONS/UI-GuildButton-PublicNote-Up.blp")
		self.contentTable[i].conditionsButtonTexture:SetAllPoints(self.contentTable[i].conditionsButton)

		-- role item button
		self.contentTable[i].roleItemButton = CreateFrame("Button", "RSGUI_Reactions_roleItemButton"..i, panel)
		self.contentTable[i].roleItemButton:SetWidth(16)
		self.contentTable[i].roleItemButton:SetHeight(16)
		self.contentTable[i].roleItemButton:SetPoint("LEFT", self.contentTable[i].conditionsButton, "RIGHT", 2, 0)
		self.contentTable[i].roleItemButtonTexture = self.contentTable[i].roleItemButton:CreateTexture(nil, "BACKGROUND")
		self.contentTable[i].roleItemButtonTexture:SetTexture(RoleItemButtonIcon)
		self.contentTable[i].roleItemButtonTexture:SetAllPoints(self.contentTable[i].roleItemButton)

		-- the edit box
		self.contentTable[i].reactionInput = CreateFrame("EditBox", "RSGUI_Reactions_reactionInput"..i, panel, "InputBoxTemplate")
		self.contentTable[i].reactionInput:SetHeight(10)
		self.contentTable[i].reactionInput:SetAutoFocus(false)
		self.contentTable[i].reactionInput:SetScript("OnEnterPressed", function() this:ClearFocus() end)
		self.contentTable[i].reactionInput:SetScript("OnTabPressed", function()
			_G.SlashCmdList["REACTIONS"]("testmessage " .. self.contentTable[i].reactionInput:GetText():gsub("||", "|"))
			-- save it too
			this.changed = true
			this:GetScript("OnEditFocusLost")(this)
			this.canChange = true
		end)
		self.contentTable[i].reactionInput:SetScript("OnEnterPressed", function()
			this:ClearFocus()
			if IsControlKeyDown() then
				self.buttonNewReaction:GetScript("OnClick")(this, nil, self.contentTable.list[i])
			end
		end)
	end

	for i=1,MAX_REACTIONS_SHOW do
		self.contentTable[i].reactionInput:SetScript("OnTextChanged", function()
			if this.canChange then
				this.changed = true
			end
		end)
		self.contentTable[i].reactionInput:SetScript("OnEditFocusGained", function()
			this.canChange = true
		end)
		self.contentTable[i].reactionInput:SetScript("OnEditFocusLost", function()
			self:TestSave(i)
			this.canChange = false
		end)
	end

	--------------------
	-- Button tooltips
	--------------------
	do
		local formButtonTooltipText = "Required " .. (select(2, UnitClass("player")) == "WARRIOR" and "Stance" or "Form")

		for i=1,MAX_REACTIONS_SHOW do
			if self.languageButtonMenu then
				self.contentTable[i].languageButton:SetScript("OnClick", function()
					settingLanguageButton = i
					RSGUI.menu:Open(self.languageButtonMenu, this)
				end)
				self.contentTable[i].languageButton.tooltipText = "Language to use"
				self.contentTable[i].languageButton:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
				self.contentTable[i].languageButton:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)
			end

			if self.formButtonMenu then
				self.contentTable[i].formButton:SetScript("OnClick", function()
					settingFormButton = i
					if self.formButtonMenu then
						RSGUI.menu:Open(self.formButtonMenu, this)
					end
				end)
				self.contentTable[i].formButton.tooltipText = formButtonTooltipText
				self.contentTable[i].formButton:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
				self.contentTable[i].formButton:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)
			end

			self.contentTable[i].conditionsButton:SetScript("OnClick", function()
				self.currentConditionButton = i
				CreateAndOpenConditionMenu(self.currentConditionButton)
			end)
			self.contentTable[i].conditionsButton.tooltipText = "Allowed conditions"
			self.contentTable[i].conditionsButton:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
			self.contentTable[i].conditionsButton:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)

			self.contentTable[i].roleItemButton:SetScript("OnClick", function()
				settingRoleItemButton = i
				RSGUI.menu:Open(self.roleItemButtonMenu, this)
			end)
			self.contentTable[i].roleItemButton.tooltipText = "Required equipment"
			self.contentTable[i].roleItemButton:SetScript("OnEnter", RSGUI.Utility.WidgetTooltip_OnEnter)
			self.contentTable[i].roleItemButton:SetScript("OnLeave", RSGUI.Utility.WidgetTooltip_OnLeave)
		end
	end

	for i=1,MAX_REACTIONS_SHOW do
		self.contentTable[i].deleteButton:SetScript("OnClick", function() RSGUI.Utility.ClearAnyFocus() self:DeleteReaction(i) end)
	end

	--------------------
	-- Adding reaction
	--------------------
	-- lastEntry is the entry to copy settings from and if nil, then it uses the last in the array
	self.buttonNewReaction:SetScript("OnClick", function(widget, button, lastEntry)
		RSGUI.Utility.ClearAnyFocus()
		-- in case it was a previously empty list, create it now and set the content table list again
		local actionData = self:GetCurrentActionData()
		if not actionData then return end
		actionData.reactions = actionData.reactions or {}
		self.contentTable.list = actionData.reactions

		lastEntry = lastEntry or self.contentTable.list[#self.contentTable.list]
		if lastEntry then
			table.insert(self.contentTable.list, {lastEntry[1] or "Chat Command", "", nil, lastEntry[4], lastEntry[5]})
			local newReaction = self.contentTable.list[#self.contentTable.list]
			if lastEntry[1] == "Chat Command" then
				local command = lastEntry[2]:match("^%s*(/%S+)")
				if command then
					newReaction[2] = command .. " "
				end
			end
			if lastEntry[6] then
				newReaction[6] = {}
				for k in pairs(lastEntry[6]) do
					newReaction[6][k] = true
				end
			end
			newReaction[7] = lastEntry[7]
		else
			table.insert(self.contentTable.list, {"Chat Command", ""})
		end

		local showTop = #self.contentTable.list - MAX_REACTIONS_SHOW+1
		self:ShowReactions(showTop <= 0 and 1 or showTop)

		-- set focus to the new reaction's input field
		for i=MAX_REACTIONS_SHOW,1,-1 do
			local input = self.contentTable[i].reactionInput
			if input:IsVisible() then
				input:SetFocus()
				input:SetCursorPosition(input:GetNumLetters()+1)
				break
			end
		end

		-- Add a green highlight to menu names to know that an action (and event if it is one) have reactions
		if self.currentAction.isEvent then
			local eventInfo = FindEventInformation(self.currentAction.name)
			for i=1,#actionTypeEventLookup do
				if actionTypeEventLookup[i] == self.currentAction.action then
					UIDropDownMenu_SetText("|cff00ff00" .. eventInfo[5][i], self.dropdownEventAction)
					break
				end
			end
			self.main:RenameEventsMenuItem(self.currentAction.name)
		else
			UIDropDownMenu_SetText("|cff00ff00" .. actionTypeList[self.currentAction.action][2], self.dropdownSpellAction)
		end
	end)

	return self
end

----------------------------------------------------------------------------------------------------
-- action section function
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- show the action section - must set self.currentAction.action before calling
--------------------------------------------------
function RSGUI.reactions:ShowAction()
	self.textGroup:Show()
	self.inputGroup:Show()
	self.textChance:Show()
	self.inputChance:Show()
	self.inputGroup:Show()
	self.textCooldown:Show()
	self.inputCooldown:Show()
	self.checkboxLimitFights:Show()
	self.inputLimitFights:Show()
	self.checkboxLimitGroup:Show()
	self.checkboxLimitName:Show()
	self.checkboxNoGCD:Show()
	self.buttonNewReaction:Show()
	self.buttonDeleteAction:Show()
	self.borderBottom:Show()

	-- disable the limit per aura option on events
	self.checkboxLimitAura:Show()
	if self.currentAction.action and self.currentAction.isEvent then
		self.checkboxLimitAura:Disable();
		_G[self.checkboxLimitAura:GetName().."Text"]:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	else
		self.checkboxLimitAura:Enable();
		_G[self.checkboxLimitAura:GetName().."Text"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		self.checkboxLimitAura:SetChecked(action and action.limitAura)
	end

	-- fix the positioning of reaction input boxes based on if the role item icon should be shown
	local showRoleIcon = next(self.main.settings.roleItems) ~= nil
	for i=1,MAX_REACTIONS_SHOW do
		local group = self.contentTable[i]
		local button = showRoleIcon and group.roleItemButton or group.conditionsButton
		group.reactionInput:SetPoint("LEFT", button, "RIGHT", 9, 0)
		group.reactionInput:SetWidth(self.slider:GetLeft() - button:GetRight() - 14)
	end

	local action
	local spell = self.currentAction.name and self.main.settings["reactionList"][self.currentAction.name] or nil
	if spell then
		action = self.currentAction.action and spell[actionTypeList[self.currentAction.action][1]]
		spell.lastActionOpened = actionTypeList[self.currentAction.action][1]
		-- the "Has travel time" option for spells only
		if self.currentAction.action and not self.currentAction.isEvent and (actionTypeList[self.currentAction.action][1] == "you_hit" or actionTypeList[self.currentAction.action][1] == "you_miss") then
			self.checkboxTravelTime:Show()
			self.checkboxTravelTime:SetChecked(spell.travelTime)
		else
			self.checkboxTravelTime:Hide()
		end
	end

	-- add history
	if self.currentAction.action and self.currentAction.name then
		local actionType = actionTypeList[self.currentAction.action][1]
		if self.currentAction.isEvent then
			local eventInfo = FindEventInformation(self.currentAction.name)
			local description
			if     actionType == "you_hit"    then description = eventInfo[5][1]
			elseif actionType == "member_hit" then description = eventInfo[5][2]
			elseif actionType == "other_hit"  then description = eventInfo[5][3]
			end
			self.main:AddHistory("event", self.currentAction.name,
				string.format("Event: %s - %s", self.inputNickname.protect, description),
				actionType
			)
		else
			self.main:AddHistory("spell", self.currentAction.name,
				string.format("Spell: %s%s - %s", self.currentAction.name, spell.nickname and (" ("..spell.nickname..")") or "", actionTypeList[self.currentAction.action][2]),
				actionType
			)
		end
	end

	self.inputGroup:SetText(action and action.group or "")
	self.inputChance:SetText(action and action.chance or 0)
	self.inputCooldown:SetText(action and action.cooldown or "")
	self.checkboxLimitFights:SetChecked(action and action.limitFights)
	self.inputLimitFights:SetText(action and action.limitFightsAmount or 1)
	self.checkboxLimitGroup:SetChecked(action and action.limitGroup)
	self.checkboxLimitName:SetChecked(action and action.limitName)
	self.checkboxNoGCD:SetChecked(action and action.noGCD)
	self.contentTable.list = action and action.reactions or {}
	self:ShowReactions(1)
end

----------------------------------------------------------------------------------------------------
-- reaction section (content table) functions
----------------------------------------------------------------------------------------------------
function RSGUI.reactions:SetLanguageIcon(index, setting)
	local icon = setting and LanguageButtonIcon[setting]
	self.contentTable[index].languageButtonTexture:SetTexture(icon or LanguageButtonIcon["Common"])
end

function RSGUI.reactions:SetFormIcon(index, setting)
	local icon = setting and formButtonIcon[setting]
	self.contentTable[index].formButtonTexture:SetTexture(icon or formButtonIcon["Any"])
	if not icon or setting == "Any" then
		self.contentTable[index].formButtonTexture:SetVertexColor(0, 1, 1)
	else
		self.contentTable[index].formButtonTexture:SetVertexColor(1, 1, 1)
	end
end

function RSGUI.reactions:SetConditionsIcon(index, conditionTable)
	if conditionTable then
		self.contentTable[index].conditionsButtonTexture:SetVertexColor(1, 0, 0)
	else
		self.contentTable[index].conditionsButtonTexture:SetVertexColor(0, 1, 0)
	end
end

function RSGUI.reactions:IsConditionsItemChecked(value)
	local reaction = self.contentTable.list[self.contentTable[self.currentConditionButton].channelDropdown.listIndex]
	return reaction and (not reaction[6] or not reaction[6][value])
end

function RSGUI.reactions:SetRoleItemIcon(index, setting)
	local item = self.main.settings.roleItems[setting]
	self.contentTable[index].roleItemButtonTexture:SetTexture(item and item[3] or RoleItemButtonIcon)
end

function RSGUI.reactions:CreateRoleItemMenu()
	if next(self.main.settings.roleItems) == nil then
		self.roleItemButtonMenu = nil
		return
	end

	self.roleItemButtonMenu = {
		{notCheckable=1, text="Required equipment", isTitle=true},
		{notCheckable=1, func=SetRoleItemFromMenu, arg1=self, value=0, icon=RoleItemButtonIcon, text="No equipment requirement"},
	}
	local item
	for i=1,10 do
		item = self.main.settings.roleItems[i]
		if item then
			self.roleItemButtonMenu[#self.roleItemButtonMenu+1] = {
				notCheckable = 1,
				func  = SetRoleItemFromMenu,
				arg1  = self,
				value = i,
				icon  = item[3],
				text  = "Must be wearing #" .. i .. ": " .. item[1]
			}
		end
	end
	self.roleItemButtonMenu[#self.roleItemButtonMenu+1] = {notCheckable=1, text="Close"}
end

-- handling reaction saving
function RSGUI.reactions:TestSave(index)
	if self.contentTable[index].reactionInput.changed and self.contentTable.list then
		self.contentTable[index].reactionInput.changed = nil
		local reaction = self.contentTable.list[self.contentTable[index].channelDropdown.listIndex]
		if reaction then
			-- fix accidental spaces before something like /y and /run
			reaction[2] = self.contentTable[index].reactionInput:GetText():gsub("||","|"):gsub("^%s+/", "/")
		end
	end
end

-- Setting reactions
function RSGUI.reactions:SetReaction(index, reactionNumber)
	self:TestSave(index) -- check if the previous reaction needs to be saved before overwriting it

	local group = self.contentTable[index]
	group.deleteButton:Show()
	group.channelDropdown:Show()
	group.reactionInput:Show()
	if self.languageButtonMenu then
		group.languageButton:Show()
	end
	if self.formButtonMenu then
		group.formButton:Show()
	end
	group.conditionsButton:Show()
	if next(self.main.settings.roleItems) ~= nil then
		group.roleItemButton:Show()
	end

	local list = self.contentTable.list

	group.reactionInput.canChange = false -- so that SetText() won't count as a change
	if list[reactionNumber] then
		group.reactionInput:SetText(list[reactionNumber][2]:gsub("|","||"))
		group.reactionInput:SetCursorPosition(0)
		if self.languageButtonMenu then
			self:SetLanguageIcon(index, list[reactionNumber][4])
		end
		if self.formButtonMenu then
			self:SetFormIcon(index, list[reactionNumber][5])
		end
		self:SetConditionsIcon(index, list[reactionNumber][6])
		self:SetRoleItemIcon(index, list[reactionNumber][7])

		UIDropDownMenu_Initialize(self.contentTable[index].channelDropdown, function() DropdownChannel_Initialize(self) end)
		UIDropDownMenu_SetSelectedValue(self.contentTable[index].channelDropdown, list[reactionNumber][1])
		self.contentTable[index].channelDropdown.listIndex = reactionNumber
	else
		group.reactionInput:SetText("")
		UIDropDownMenu_Initialize(self.contentTable[index].channelDropdown, function() DropdownChannel_Initialize(self) end)
		UIDropDownMenu_SetSelectedValue(self.contentTable[index].channelDropdown, "Chat Command")
		if self.languageButtonMenu then
			self:SetLanguageIcon(index, "Common")
		end
		if self.formButtonMenu then
			self:SetFormIcon(index, "Any")
		end
		self:SetRoleItemIcon(index, 0)
		self:SetConditionsIcon(index, nil)
	end
	if group.reactionInput:HasFocus() then
		group.reactionInput.canChange = true
	end
end

-- show as many reactions as possible
function RSGUI.reactions:ShowReactions(startAt)
	local list = self.contentTable.list
	if not startAt then
		startAt = 1
	end

	local amount = #list
	local onReaction = startAt
	for i=1,MAX_REACTIONS_SHOW do
		local group = self.contentTable[i]
		if list[onReaction] then
			self:SetReaction(i, onReaction)
		else
			group.deleteButton:Hide()
			group.channelDropdown:Hide()
			group.reactionInput:Hide()
			if self.languageButtonMenu then
				group.languageButton:Hide()
			end
			if self.formButtonMenu then
				group.formButton:Hide()
			end
			group.conditionsButton:Hide()
			group.roleItemButton:Hide()
		end
		onReaction = onReaction + 1
	end

	-- set the slider
	if amount <= MAX_REACTIONS_SHOW then
		self.slider:Hide()
	else
		local extraAmount = #list - MAX_REACTIONS_SHOW
		self.slider:SetMinMaxValues(1, extraAmount+1)
		self.slider:SetValue(startAt)
		self.slider:Show()
	end
end

-- deleting reaction
function RSGUI.reactions:DeleteReaction(index)
	local group = self.contentTable[index]
	local action = self:GetCurrentActionData()
	local reactionIndex = group.channelDropdown.listIndex

	-- fix the action's last chosen recard if needed
	if action.lastChosen then
		if action.lastChosen == reactionIndex then
			action.lastChosen = nil
		elseif action.lastChosen > reactionIndex then
			action.lastChosen = action.lastChosen - 1
		end
	end

	table.remove(self.contentTable.list, reactionIndex)

	local topShown = self.slider:IsVisible() and self.slider:GetValue() or 1
	self:ShowReactions(topShown)

	-- check if the green highlight should be removed if no reactions exist
	if next(self.contentTable.list) == nil then
		if self.currentAction.isEvent then
			local eventInfo = FindEventInformation(self.currentAction.name)
			for i=1,#actionTypeEventLookup do
				if actionTypeEventLookup[i] == self.currentAction.action then
					UIDropDownMenu_SetText(eventInfo[5][i], self.dropdownEventAction)
					break
				end
			end
			self.main:RenameEventsMenuItem(self.currentAction.name)
		else
			UIDropDownMenu_SetText(actionTypeList[self.currentAction.action][2], self.dropdownSpellAction)
		end
	end
end

-- Hiding reactions
function RSGUI.reactions:HideContentTable()
	local group
	for i=1,MAX_REACTIONS_SHOW do
		group = self.contentTable[i]
		group.deleteButton:Hide()
		group.channelDropdown:Hide()
		group.reactionInput:Hide()
		if self.languageButtonMenu then
			group.languageButton:Hide()
		end
		if self.formButtonMenu then
			group.formButton:Hide()
		end
		group.conditionsButton:Hide()
		group.roleItemButton:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------------------------------------
function RSGUI.reactions:Open(name, isEvent, actionType)
	CloseDropDownMenus()
	self:CheckEventForDeletion(self.currentAction.name)

	local reaction = name and self.main.settings["reactionList"][name] or nil
	local openAction = reaction and (actionType or reaction.lastActionOpened or nil)

	-- convert it to a number
	if openAction then
		for i=1,#actionTypeList do
			if actionTypeList[i][1] == openAction then
				openAction = i
				break
			end
		end
		if tonumber(openAction) == nil then
			openAction = nil
		end
	end

	self.textTip:Hide()
	-- middle section
	self.textGroup:Hide()
	self.inputGroup:Hide()
	self.textChance:Hide()
	self.inputChance:Hide()
	self.inputGroup:Hide()
	self.textCooldown:Hide()
	self.inputCooldown:Hide()
	self.checkboxLimitFights:Hide()
	self.inputLimitFights:Hide()
	self.checkboxLimitAura:Hide()
	self.checkboxLimitGroup:Hide()
	self.checkboxLimitName:Hide()
	self.checkboxNoGCD:Hide()
	self.buttonNewReaction:Hide()
	self.buttonDeleteAction:Hide()
	self.borderBottom:Hide()
	-- reaction list section
	self:HideContentTable()
	self.currentAction.action = nil

	local isNew = false
	if isEvent or (reaction and reaction.event) then
		self.currentAction.name = name
		self.currentAction.isEvent = true
		self.main:SetHeaderText("Event: " .. name)
		-- top section
		local eventInfo = FindEventInformation(name)
		self.inputName.protect = name
		self.inputName:SetText(self.inputName.protect)
		self.inputName:SetCursorPosition(0)
		self.inputNickname.protect = eventInfo and eventInfo[1] or ""
		self.inputNickname:SetText(self.inputNickname.protect)
		self.inputNickname:SetCursorPosition(0)
		self.inputSubmenu.protect = eventInfo and eventInfo[2] or ""
		self.inputSubmenu:SetText(self.inputSubmenu.protect)
		self.inputSubmenu:SetCursorPosition(0)
		self.buttonCreateOrChange.text:SetText("Change")
		self.buttonCreateOrChange:Disable()
		self.buttonDeleteAll:Show()
		self.borderTop:Show()
		-- middle section dropdown
		-- if no last action was opened, then set the first possible one to be opened
		if not openAction then
			local firstAction = nil
			if     eventInfo[5][1] then firstAction = "you_hit"
			elseif eventInfo[5][2] then firstAction = "member_hit"
			elseif eventInfo[5][3] then firstAction = "other_hit"
			end
			if firstAction then
				for i=1,#actionTypeList do
					if actionTypeList[i][1] == firstAction then
						openAction = i
						break
					end
				end
			end
		end

		self.dropdownActionText:Show()
		self.dropdownEventAction:Show()
		self.dropdownSpellAction:Hide()
		self.checkboxTravelTime:Hide()
		self.dropdownEventAction.initializing = true
		UIDropDownMenu_Initialize(self.dropdownEventAction, function() DropdownEventAction_Initialize(self) end)
		if openAction then
			UIDropDownMenu_SetSelectedValue(self.dropdownEventAction, openAction)
			self.currentAction.action = openAction
			self:ShowAction()
		end
	elseif reaction then
		self.currentAction.name = name
		self.currentAction.isEvent = false
		self.main:SetHeaderText("Spell: " .. name)
		-- top section
		self.inputName.protect = nil
		self.inputName:SetText(name)
		self.inputName:SetCursorPosition(0)
		self.inputNickname.protect = nil
		self.inputNickname:SetText(reaction.nickname or "")
		self.inputNickname:SetCursorPosition(0)
		self.inputSubmenu.protect = nil
		self.inputSubmenu:SetText(reaction.submenu or "")
		self.inputSubmenu:SetCursorPosition(0)
		self.buttonCreateOrChange.text:SetText("Change")
		self.buttonCreateOrChange:Enable()
		self.buttonDeleteAll:Show()
		self.borderTop:Show()
		-- middle section dropdown
		self.dropdownActionText:Show()
		self.dropdownEventAction:Hide()
		self.dropdownSpellAction:Show()
		self.checkboxTravelTime:Hide()
		self.dropdownSpellAction.initializing = true
		UIDropDownMenu_Initialize(self.dropdownSpellAction, function() DropdownSpellAction_Initialize(self) end)
		if openAction then
			UIDropDownMenu_SetSelectedValue(self.dropdownSpellAction, openAction)
			self.currentAction.action = openAction
			self:ShowAction()
		end
	else
		isNew = true
		self.currentAction.name = nil
		self.currentAction.isEvent = false
		self.main:SetHeaderText("New Spell")
		self.inputName.protect = nil
		self.inputName:SetText(name or "")
		self.inputNickname.protect = nil
		self.inputNickname:SetText("")
		self.inputSubmenu.protect = nil
		self.inputSubmenu:SetText("")
		self.buttonCreateOrChange.text:SetText("Create")
		self.buttonCreateOrChange:Enable()
		self.buttonDeleteAll:Hide()
		self.borderTop:Hide()
		self.textTip:Show()
		-- middle section dropdown
		self.dropdownActionText:Hide()
		self.dropdownEventAction:Hide()
		self.dropdownSpellAction:Hide()
		self.checkboxTravelTime:Hide()
	end

	-- center top buttons
	self.textName:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
		(self.frame:GetWidth()/2)-(((isNew and self.buttonCreateOrChange:GetRight() or self.buttonDeleteAll:GetRight())-self.textName:GetLeft())/2), 0)

	self.frame:Show()
	if not self.currentAction.name then
		self.inputName:SetFocus()
	end
end
