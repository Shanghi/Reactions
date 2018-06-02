1. Slash commands
2. Quick tips
3. Options
4. Spells
5. Events
6. Tags / Variables / Randomization
7. Chat triggers
8. Special examples

# **1. Slash commands**

| Commands&nbsp;(/rs&nbsp;or&nbsp;/reactions) | Description |
| --- | --- |
| /rs | _opens the settings window -<br/>all shortcut commands below can be set there_ |
| /rs \<"on"\|"off">               | _shortcut to enable/disable the addon_ |
| /rs test \<"on"\|"off">          | _shortcut to turn test mode on or off_ |
| /rs cooldown \<seconds>          | _shortcut to set the global cooldown time between actions_ |
| /rs chance \<multiplier>         | _shortcut to set a chance multiplier for reactions_ |
| /rs shout \<"on"\|"off">         | _shortcut to turn shout mode on or off_ |
| /rs&nbsp;group&nbsp;\<name>&nbsp;\<"on"\|"off"> | _shortcut to enable or disable a group of reactions_ |
| /rs use "\<spell>" [target]      | _use a "spell" reaction, optionally on a target name_ |

# **2. Quick tips**
* Test Mode will only print reactions to you instead of using/saying them.
* Press Tab when editing a reaction or tag to show yourself a test message using it.
* Very long messages will automatically be split up into multiple messages.
* A/An grammar problems will be fixed automatically.
* The Group channel will use the appropriate channel for battlegrounds, raids, and normal parties.
* Certain AOE spells like Demoralizing Roar count as the action "Your spell hits yourself."
* When editing a reaction message, pressing ctrl-enter will create a new one and move to it.
* Most editbox settings save after the keyboard focus leaves them or using Tab to test.

# **3. Options**
Most settings in the options section have tooltips and won't need more explanations, but here's some extra details:

**Default global cooldown:**<br/>
This many seconds must pass before any spell/event reaction can happen again, unless the action being tested has its "Override GCD" set to something else. Chat triggers don't use this.

**Chance multiplier:**<br/>
Each time a chance to react is calculated, it's multiplied by this. A multiplier of 1 doesn't change anything, 2 would double its chance, and .5 would halve it. This is to let you temporarily make reactions happen more or less without having to change every chance setting.

**Role items:**<br/>
To only do a reaction when wearing a certain item, first drag it to any of these boxes. When setting up a reaction, an icon beside its editbox will let you pick which of these items you must wear for that reaction to happen. That icon won't show up if you have no role items set. It's done this way so that if you ever upgrade the item, you only have to change it in the options instead of having to find and fix all the reactions using it.

# **4. Spells**

## Adding


Click "Spells > Add spell"

**Name/ID:**<br/>
Exact name of the spell to match, or its ID number.

**Nickname:**<br/>
Can be left blank, but if used then will be the name shown on the Spells dropdown list. It can be
useful if you've used an ID number for the name.

**Submenu:**<br/>
Can be left blank, but if you add a lot of spells then it can be helpful to keep them organized in the Spells dropdown menu. The added spell will go into a submenu named here. You can put submenus inside submenus by separating each name with a **`|`** or **`>`**. For example, you might add Entangling Roots to the submenu **`Class>Druid>Balance`** if you're organized.

All of these can be changed later if needed. Click [Create] to create and show the spell settings.

## Action section
An action is what is happening with the spell, such as hitting someone or it hitting you. Each can have their own sets of reactions. Pick an action to react to from the dropdown menu and the action's settings will be shown.

**Group:**
Each action can optionally have a group name. The Groups button at the top will keep an up to date list of all groups in a checklist. If you uncheck a group on that list, all actions using it will be disabled until it's checked again. If that's too much work, there's an "Ungrouped" option on the checklist to toggle things without a named group. This let's you put only important actions (like maybe a resurrection message) in a group and toggle the rest on and off easily.

**Chance:**<br/>
When the action happens, this is the chance percentage for a reaction to happen. 100 would cause a reaction to happen every time. You can use decimal places like 0.25.

**Override GCD:**<br/>
All events/spells share a global cooldown set in the options. No other reactions will happen until this global cooldown is over. To override that for this action, you can set a specific cooldown time for it here. To have no cooldown time at all, use 0.

**Limit once per fight(s):**<br/>
If checked, a reaction will only happen once until the set amount of fights occur. For a fight to count, it has to last as long as the minimum fight length setting in the options (mostly so that critters won't count).

**Limit once per group:**<br/>
If checked and in a group, reactions will only happen once until you leave it.

**Limit once per aura:**<br/>
This is to fix certain mob spells that act differently than player spells. When you use a DoT, each "tick" counts as a "Your spell periodically hit" action. Some mob spells (like Vashj's Static Shock) make every tick count as "You are hit" instead of "You are hit periodically." This difference makes it harder to have just one warning message when you get it, but checking this option will make it so that a reaction is only used once until the aura is removed. Unfortunately, the variable **`<target_name>`** can not be used if this is checked.

**Limit once per target name in fight:**<br/>
If checked, you won't react to the same person (or same-named mob) doing this action more than once
during a single fight.

**Don't activate global cooldown on use:**<br/>
If checked, the global cooldown that spells/event follow by default won't be triggered, so other spell/event reactions can still happen immediately after this one.

**[Delete Action]:**<br/>
This deletes any settings and reactions for the selected action.

**[Add Reaction]:**<br/>
Click this to add another possible reaction to do when the action happens. There is no set limit to the amount you can have. New reactions will copy the settings of the previous one.

## Reaction section
You can have any amount of reactions for each action type. When one is used, it gets it's own individual cooldown time (set in the options) and won't be selected again during that time unless there's no other choice. When an action has at least one reaction, its name will change to green.

**[x]:** click the X button at the left side to delete the reaction.

| Channel&nbsp;dropdown&nbsp;menu | Where your reaction message is sent |
| --- | --- |
| Chat Command | Like typing in chat normally. It defaults to **`/say`**, but you can use slash commands like **`/y`**, **`/bow`**, and **`/invite`** to change it. Protected commands like **`/cast`** can't be used. |
| Say and Yell     | Say and yell the message at the same time. |
| Group            | Picks the proper group chat you're in: battleground, raid, or party |
| /w Target        | Whispers the target of the reaction. |
| /w Caster        | Whispers the caster that triggered the reaction. |
| Print to Chat    | Prints the message to yourself in the first chat tab. |
| Print to Warning | Prints the message to yourself in the style of a raid warning. |
| Spell/Event      | Uses a reaction from another event/spell. An example use is to make a fake spell named "Healing Spells" and then have each real spell redirect to use that if you want them to use the same messages. It will pick from the same action type, so if you reacted to a "You begin casting" event on Regrowth, then it will pick something from "You begin casting" from the "Healing Spells" spell. |
<br/>

**[various option icons]:**
* **Language button:** The first icon lets you pick which game language to say your message in (if that channel supports languages). It won't be shown if you only know 1 language.

* **Form/Stance button:** The second icon lets you pick which form/stance you have to be in to be able to pick this reaction. By default, you can be in any form. It won't be shown if you don't have any forms or stances.

* **Allowed conditions button:** The third icon lets you choose if the reaction can be chosen under various conditions. By default, every condition is allowed. For example, if you wanted to only use the reaction on a critical hit, you would uncheck "Hit is normal," "Hit is crushing blow," and "Hit is glancing blow."
  - If you allow friend targets but not guild members (or the other way around), someone who is both will be accepted as a valid target.
  - "Target is neutral" is for non-hostile things that you can attack, like critters.
  - Group leader/assistant and Master Looter checking is only done when in a group.
  - The mob type (humanoid/critter/demon) only works for English clients.
  - "While at low/medium/high health/power" uses the values set in the options.
  - Most information about someone (like race or creature type) won't be known unless they're in your group, you see them as a target, focus, or mouseover unit, or your pet or the group member involved in the action is targeting them.
    If a condition can't find the information it needs, that reaction won't be used. Some things will always be known, like guild and friend conditions or if a caster is friendly/neutral/hostile.

* **Required equipment button:** The fourth icon lets you pick an item from the "role items" (set up in the options) that require you to be wearing it for the reaction to be allowed to happen. It won't be shown if no role items are set.

**\[message line]:**<br/>
Here is where you write the text the reaction will say (or whatever the chosen channel does). Very
long messages will automatically split into multiple messages when used. Section 6 of the guide
explains how to make fancier messages using randomized text and variables like the target's name.
Press Tab to show a test message. Press Ctrl-Enter to create a new reaction and set the focus to it.

## Multiple actions
You can use multiple actions in a single reaction line by using **`<new>`** in it. By default, each new
action you add will use the same channel as the dropdown menu action.<br/>
`My first message<new>Now I'm saying something else<new>/y Now I'm yelling this third thing!`

You can have the new messages wait a certain amount of seconds. The time adds on to previous time.<br/>
`Hello<new 2>This is 2 seconds later<new 3>/e is emoting 3 seconds after the second message!`

If you want the first message to wait, then just add the **`<new>`** at the beginning:<br/>
`<new 5>I'm saying this 5 seconds after the event happened!`

You can use a second number as a random range:<br/>
`My first message<new 2 5>I'm saying this between 2 and 5 seconds later!`

You can use special channels from the dropdown list (like "group"):<br/>
`Pleased to meet you, <target_name>!<new:group>They're here, so be respectful<new>/bow <target_name>`

You can add them all together:<br/>
`Hmmm<new>/e searches his pouch<new 3 6:group>I've found it!<new>/cheer<new 2>/1 I've got the digrat!`

Notes:
* If someone ignores you, all future messages that will whisper them will be canceled.
* Disabling the addon will immediately cancel all future actions.
* You can use **`<new:chat>`** instead of **`<new:chat command>`** if you need to switch to using it.

## Special "spells"
You can react to the death of a specific creature/player by using their exact name as a spell name. It uses the "Your spell hit someone else" action. If this action is used successfully, a generic death event won't be tried.

You can create a "spell" of any name to use manually in macros. It uses the "Your spell hit someone else" action. For example, you could create a "Cryptic Whisper" spell with a lot of possible whisper messages, then use this macro to use one (%t is your target's name): **`/rs use "Cryptic Whisper" %t`**

# **5. Events**
Reacting to events is the same as reacting to a spell. Since events are pre-made with all their capabilities known, their Actions dropdown will only show what's possible to detect. If you use [Delete] on an event, it will delete all its action settings but will stay on the Events list.

* The Targeting events only happen if they're in the range where you can inspect someone.
* Incapacitated/Silence events rely on spell lists, so some may be missing (especially old ones).
* Below, [T] means that the **`<target_name>`** variable (and **`<group_name>`**/etc if applicable) will work.


| Character Events | Description |
| --- | --- |
| Focus (Enemy)                   | [T] You /focus on an enemy mob/player. |
| Focus (Friend)                  | [T] You /focus on a friendly mob/player. |
| Full Rage                       | [T] When reaching 100 rage. |
| Low Health (Begin)              | Your health drops at or below the percentage set in the options. It won't trigger again until first reaching the 2nd percentage set. |
| Low&nbsp;Health&nbsp;(Continuing&nbsp;&&nbsp;Lower) | After reaching Low Health (Begin), your health drops even lower. |
| Low Health (End)                | After Low Health (Begin), your health rises to the end percentage. |
| Low Mana (Begin)                | Your mana drops at or below the percentage set in the options. It won't trigger again until first reaching the 2nd percentage set. |
| Low Mana (Continuing & Lower)   | After reaching Low Mana (Begin), your mana drops even lower. |
| Low Mana (End)                  | After Low Mana (Begin), your mana rises to the end percentage. |
| New Target (Dead Enemy)         | [T] While out of combat, you target a dead enemy mob/player. |
| New Target (Dead Friend)        | [T] While out of combat, you target a dead friendly mob/player. |
| New Target (Enemy)              | [T] While out of combat, you target an alive enemy mob/player. |
| New Target (Friend)             | [T] While out of combat, you target an alive friendly mob/player. |
<br/>

| Combat Events | Description |
| --- | --- |
| Combat (Begin)              | When you enter combat. |
| Combat (End)                | When you exit combat - checks "minimum fight length" from the options |
| Combat&nbsp;Target&nbsp;(Dead&nbsp;Enemy)  | [T] While in combat, you target a dead enemy mob/player |
| Combat&nbsp;Target&nbsp;(Dead&nbsp;Friend) | [T] While in combat, you target a dead friendly mob/player |
| Combat Target (Enemy)       | [T] While in combat, you target an alive enemy mob/player |
| Combat Target (Friend)      | [T] While in combat, you target an alive friendly mob/player |
| Critically Hit By (Heal)    | [T] You get critically hit by a heal. |
| Critically Hit By (Normal)  | [T] You get critically hit by a normal attack. |
| Critically Hit By (Spell)   | [T] You get critically hit by a spell. |
| Critical Hit (Heal)         | [T] Someone critically hits someone (except you) with a heal.<br/>This generic critical hit event won't happen if a specific spell reaction was used. |
| Critical Hit (Normal)       | [T] Someone critically hits someone (except you) with a normal attack.<br/>This generic critical hit event won't happen if a specific spell reaction was used. |
| Critical Hit (Spell)        | [T] Someone critically hits someone (except you) with a spell.<br/>This generic critical hit event won't happen if a specific spell reaction was used. |
| Death (Creature)            | A mob/player dies. |
| Death (Totem)               | A totem is destroyed. |
| Duel Request                | [T] You challenge someone or someone challenges you to a duel. |
| Interrupting                | [T] Someone interrupts someone else's spell.<br/>**`<spell_link>`**/**`<spell_name>`** is for the interrupting spell (like Kick).<br/>**`<extra_spell_link>`**/**`<extra_spell_name>`** is for what was interrupted. |
| Interrupted                 | [T] Your spell gets interrupted. The Interrupting event won't trigger.<br/>**`<spell_link>`**/**`<spell_name>`** is for the interrupting spell (like Kick).<br/>**`<extra_spell_link>`**/**`<extra_spell_name>`** is for what was interrupted. |
| Killing Blow                | [T] You or your party/raid subgroup gets a killing blow on a non-boss. |
| Killing Blow (Boss)         | [T] You or your party/raid subgroup gets a killing blow on a boss. |
| Lose Control (Begin)        | You lose control from fear/mind control/etc. |
| Lose Control (Continuing)   | Every second after losing control, until you regain control. |
| Lose Control (End)          | The fear/mind control/etc ends and you regain control. |
| Resurrected                 | You come back to life in any way. |
<br/>

| Environment Events | Description |
| --- | --- |
| Automatic                      | Triggers every ___ to ___ minutes which is set up in the options. |
| Backpedal                      | You walk backwards. |
| Changed Subzone                | You move into a differently named subzone (like "Lower City"). It won't trigger if the subzone is blank or the same as the last one. |
| Changed Zone                   | You move into another area, like from Mulgore to The Barrens. |
| Environment (Drowning)         | [T] Drowning damage was taken by someone. |
| Environment&nbsp;(Drowning&nbsp;-&nbsp;Death) | [T] Drowning killed you or a group member. |
| Environment (Fall)             | [T] Fall damage of at least 30% health (or 1800 health if the percentage can't be seen) was taken by someone. |
| Environment (Fall - Death)     | [T] Fall damage killed you or a group member. |
| Environment (Fire)             | [T] Fire (from the environment) damage was taken by someone. |
| Environment (Fire - Death)     | [T] Fire (from the environment) damage killed you or a group member. |
| Environment (Lava)             | [T] Lava damage was taken by someone. |
| Environment (Lava - Death)     | [T] Lava damage killed you or a group member. |
| Environment (Slime)            | [T] Slime damage was taken by someone. |
| Environment (Slime - Death)    | [T] Slime killed you or a group member. |
| Falling                        | You fall through the air for 3 seconds - can happen multiple times. |
| Jump                           | You jump. |
| Minimap Ping                   | [T] Someone clicks on the minimap. |
| Swimming (Begin)               | You begin swimming. |
| Swimming (Continuing)          | Every 1 second while swimming, unless underwater. |
| Swimming (End)                 | You leave the water. |
| Underwater (Begin)             | The breath bar appears (won't happen if you can breathe underwater). |
| Underwater (Continuing)        | Every 1 second while the breath bar is visible. |
| Underwater (End)               | The breath bar disappears (even if using underwater breathing). |
<br/>

| Object Events | Description |
| --- | --- |
| Bank (Open)         | [T] You open your bank bags. |
| Bank (Close)        | [T] You close your bank bags. The target isn't known if you close it by walking away or opening a window with a different NPC. |
| Consume Alcohol     | You drink an alcoholic beverage. Its name isn't known. |
| Consume Drink       | You begin drinking (usually mana regen drinks). Its name isn't known. |
| Consume Food        | You begin eating (both buff food and health regen food). Its name isn't known. |
| Destroy Item        | [T] When you destroy an item. **`<target_name>`** is the item link. |
| Durability&nbsp;(Broken) | A worn item reaches 0 durability (won't happen while wearing broken items). |
| Durability (Low)    | A worn item reaches the low durability setting (won't happen while wearing an item with durability below that percent setting). |
| Guild Bank (Open)   | You open the guild bank window. |
| Guild Bank (Close)  | You close the guild bank window. |
| Loot (Autoloot)     | You begin looting something with autoloot turned on. |
| Loot (Open)         | You begin looting something with autoloot turned off. |
| Loot (Close)        | You close the loot window after about 2 or more seconds of it being open. |
| Loot (Close Fast)   | You close the loot window in about less than 2 seconds. If not wanted, a 100% chance "Spell/Event" reaction could redirect these to LootClose instead. |
| Mailbox (Close)     | You close the mailbox window. |
| Mailbox (Open)      | You open the mailbox window. |
| Open&nbsp;World&nbsp;Object   | [T] You begin opening an object (chest/door/etc) - **`<target_name>`** is its name. |
| Repair Items        | [T] You repair all your items. |
<br/>

| Society Events | Description |
| --- | --- |
| Auction House (Close)        | [T] You close the auction house window. |
| Auction House (Open)         | [T] You open the auction house window. |
| Flight Master (Close)        | [T] You cancel/close the flight master window. |
| Flight&nbsp;Master&nbsp;(Flight&nbsp;Begin) | [T] You pick a destination - **`<target_name>`** will be that destination. If you pick a destination you're already at, it will still trigger. |
| Flight Master (Flight End)   | [T] You land off a flight - **`<target_name>`** will be that location. |
| Flight Master (Open)         | [T] You talk to a flight master and open the flight window. |
| Follow (Start)               | [T] You begin following a player. |
| Follow (Stop)                | [T] You stop following a player. |
| Group (Join)                 | [T] You or someone joins the party/raid. **`<group_name>`** will be them. |
| Group (Leave)                | [T] You or someone leaves the party/raid. **`<target_name>`** will be them. |
| Login                        | You login into the game. |
| Logout (Countdown)           | The logout/quit popup to wait appears. |
| Logout (Instantly)           | You logout/quit instantly from a resting place (safe town/inn). |
| Merchant (Close)             | [T] You close a merchant window. |
| Merchant (Open)              | [T] You open a merchant window. |
| Ready Check (Begin)          | [T] affects you=you send a Ready Check. affects group=they send it. |
| Ready Check (Is Ready)       | You pick Yes during a Ready Check. |
| Ready Check (Not Ready)      | You pick No during a Ready Check. |
| Summon Accept (After)        | [T] You accept a summon - reaction is done after arriving. It only works if you aren't already in the same subzone as the summoner. |
| Summon Accept (Before)       | [T] You accept a summon - reaction is done before teleporting away. |
| Summon Cancel                | [T] You decline a summon. |
| Trade (Accept)               | [T] You complete a trade with someone. |
| Trade (Cancel)               | [T] The trade window closes without a trade being made. |
| Trade (Open)                 | [T] The trade window is opened with someone. |
<br/>

## Spell Effect

These events can trigger when you or the target gain or lose an aura that causes the chosen effect.

When you're the target, the (Begin) versions of each will only happen if you don't already have that effect on you. For example, if you get stunned by 2 different spells at the same time it will only trigger on the first spell. The (End) versions will act the same way, except only happen when all spells causing that effect is gone.

When other people are the target, the (Begin) and (End) versions happen every aura even if they have others on them causing the same effect.

# **6. Tags / Variables / Randomization**
There are a few ways to randomize and personalize each reaction message. Tags will pick a random phrase from a list and are meant to be generic and possibly used by any message. Randomization is similar but unique to each message. Variables will let you include someone's name or class, your current zone, and many other things.

* **`<new>`** is processed first to split the message into multiple ones, then tags, then randomization, then variables. You probably won't need to remember this unless you're doing something very fancy.
* When using a /script reaction, only variables can be used.
* You can put **`'s`** after a variable or tag name to add either 's or ' to the end depending on if the last letter is an S. For example: **`<target_name's>`**. Grammarians are split on if this simple rule should be followed!

## Tags
### Creating/editing

To create a tag, choose "Tags > All tags" then enter a tag name at the top and click [Create]. It can have spaces. Like spells, you can put it in a submenu to keep them organized.

To edit a tag, you can either find it in "Tags > All tags" or select it specifically from the Tags menu to get a bigger editing box and be able to rename/move it. Each phrase should be separated by **`|`** like:<br/>
`first|second phrase|the third phrase|fourth|here is the final phrase`

To delete a tag, click the [x] beside its name in "Tags > All tags" or use the delete button at the
top if it was specifically selected.

### Using
To use a tag in a reaction message, surround its name with **`{}`**. For example, to use a "class" tag:<br/>
`I heard the {class} has a powerful maneuver.`

To use multiple tags and get only one phrase out of all of them, separate their names with **`|`** like:<br/>
`I heard {horde capital|alliance capital} is a nice place to live.`

## Variables
Variables are surrounded by **`<>`** and will insert things like a character's name or class. The [?] button at the top will list all variables, and clicking one will insert it into whatever you're editing. Some have **`*`** in their name, which should be replaced with what you want from it.

Example: `I, <player_name> the <player_class>, hit <target_name> with <spell_link>!`<br/>
Possible result: `I, Pyralis the druid, hit digrat zombie with [Moonfire]!`

| Player&nbsp;Variables | Description |
| --- | --- |
| \<player_name>       | your name |
| \<player_name_title> | your name including title (if one is set) |
| \<player_race>       | your race |
| \<player_class>      | your class |
| \<player_guild>      | your guild name |
| \<player_title>      | your current title |
| \<player_hearth>     | your hearthstone location |
| \<player_gold>       | your gold amount |
| \<player_money_text> | your money written like: 32 gold, 84 silver, 50 copper |
| \<pet_name>          | your combat pet's name |


### Action targets

For the following variables, the **`*`** should be replaced with **`target`**, **`group`**, or **`extra_target`**. For example: **`<target_name>`**, **`<group_name>`**, or **`<extra_target_name>`**.

Here's how to know who **`<target_name>`**, **`<group_name>`**, and **`<extra_target_name>`** is:<br/>
* Actions you do or that target you: Any other person involved is always **`<target_name>`**.<br/>
* Actions mentioning a group member: they are **`<group_name>`**, anyone else involved is **`<target_name>`**.<br/>
* Actions mentioning a non-grouped person: they are **`<target_name>`**, anyone else is **`<extra_target_name>`**.

The name will always be known, but the other information will only be available if they're in your group, you or your pet are looking at them as a target, focus, or mouseover unit, or the group member involved in an action is targeting them.

| Action&nbsp;Target&nbsp;Variables | Description |
| --- | --- |
| \<*_name>         | the name of **`*`** |
| \<*_race>         | the player race or mob creature type of **`*`** |
| \<*_class>        | the player class or mob classification (rare/elite/etc) of **`*`** |
| \<*_guild>        | the guild **`*`** belongs to |
| \<*_he_she>       | he, she, or it depending on **`*`**'s sex |
| \<*_him_her>      | him, her, or it depending on **`*`**'s sex |
| \<*_his_her>      | his, her, or their depending on **`*`**'s sex |
| \<*_gender:M:F:O> | replace M, F, and O with the text you want to show if **`*`** is that sex |
<br/>

| Action&nbsp;Info&nbsp;Variables | Description |
| --- | --- |
| \<spell_link>         | a spell link of what triggered the reaction (if any) |
| \<spell_name>         | the spell name of what triggered the reaction (if any) |
| \<spell_rank>         | the spell rank of what triggered the reaction (if any), like "rank 3" |
| \<spell_rank:*>       | like spell **`<spell_rank>`**, but replace **`*`** with an ID or name to get the rank - names only work with your spellbook spells and give the highest rank |
| \<extra_spell_link>   | a second spell link involved in the reaction (if any) |
| \<extra_spell_name>   | a second spell name involved in the reaction (if any) |
| \<extra_spell_rank>   | a second spell rank involved in the reaction (if any) |
| \<spell_name_after:*> | Some spells are grouped with prefixes like "Portal: " or "Aspect of ". If you want to remove those for generic messages, replace **`*`** with the part to skip.<br/>Examples: **`<spell_name_after:Portal: >`** or **`<spell_name_after:Summon >`** |
<br/>


### Macro Style
Replace the **`*`** with a [Unit ID name](http://www.wowwiki.com/UnitId) that are used in normal macros. Keep in mind that "target" on these means your current target which may not be the action's target. One common example is using **`<name:mouseover>`** when resurrecting if using something like Clique/Grid.

| Macro&nbsp;Style&nbsp;Variables | Description |
| --- | --- |
| \<name:*>         | the name of **`*`** |
| \<race:*>         | the race of **`*`** |
| \<class:*>        | the class of **`*`** |
| \<guild:*>        | the guild name of **`*`** |
| \<he_she:*>       | he, she, or it depending on the sex of **`*`** |
| \<him_her:*>      | him, her, or it depending on the sex of **`*`** |
| \<his_her:*>      | his, her, or its depending on the sex of **`*`** |
| \<gender:*:M:F:O> | replace M, F, and O with the text you want if they're male, female, or other |
<br/>

| Equipment&nbsp;Variables | Description |
| --- | --- |
| \<eq_head_*>     | replace **`*`** with "name" or "link" - **`<eq_head_name>`** / **`<eq_head_link>`** |
| \<eq_neck_*>     | replace **`*`** with "name" or "link" - **`<eq_neck_name>`** / **`<eq_neck_link>`** |
| \<eq_shoulder_*> | replace **`*`** with "name" or "link" - **`<eq_shoulder_name>`** / **`<eq_shoulder_link>`** |
| \<eq_back_*>     | replace **`*`** with "name" or "link" - **`<eq_back_name>`** / **`<eq_back_link>`** |
| \<eq_chest_*>    | replace **`*`** with "name" or "link" - **`<eq_chest_name>`** / **`<eq_chest_link>`** |
| \<eq_shirt_*>    | replace **`*`** with "name" or "link" - **`<eq_shirt_name>`** / **`<eq_shirt_link>`** |
| \<eq_tabard_*>   | replace **`*`** with "name" or "link" - **`<eq_tabard_name>`** / **`<eq_tabard_link>`** |
| \<eq_wrist_*>    | replace **`*`** with "name" or "link" - **`<eq_wrist_name>`** / **`<eq_wrist_link>`** |
| \<eq_hands_*>    | replace **`*`** with "name" or "link" - **`<eq_hands_name>`** / **`<eq_hands_link>`** |
| \<eq_waist_*>    | replace **`*`** with "name" or "link" - **`<eq_waist_name>`** / **`<eq_waist_link>`** |
| \<eq_legs_*>     | replace **`*`** with "name" or "link" - **`<eq_legs_name>`** / **`<eq_legs_link>`** |
| \<eq_feet_*>     | replace **`*`** with "name" or "link" - **`<eq_feet_name>`** / **`<eq_feet_link>`** |
| \<eq_finger1_*>  | replace **`*`** with "name" or "link" - **`<eq_finger1_name>`** / **`<eq_finger1_link>`** |
| \<eq_finger2_*>  | replace **`*`** with "name" or "link" - **`<eq_finger2_name>`** / **`<eq_finger2_link>`** |
| \<eq_trinket1_*> | replace **`*`** with "name" or "link" - **`<eq_trinket1_name>`** / **`<eq_trinket1_link>`** |
| \<eq_trinket2_*> | replace **`*`** with "name" or "link" - **`<eq_trinket2_name>`** / **`<eq_trinket2_link>`** |
| \<eq_mainhand_*> | replace **`*`** with "name" or "link" - **`<eq_mainhand_name>`** / **`<eq_mainhand_link>`** |
| \<eq_offhand_*>  | replace **`*`** with "name" or "link" - **`<eq_offhand_name>`** / **`<eq_offhand_link>`** |
| \<eq_ranged_*>   | replace **`*`** with "name" or "link" - **`<eq_ranged_name>`** / **`<eq_ranged_link>`** |
| \<eq_ammo_*>     | replace **`*`** with "name" or "link" - **`<eq_ammo_name>`** / **`<eq_ammo_link>`** |
<br/>

| Random&nbsp;Variables | Description |
| --- | --- |
| \<number:&#65279;* *>              | a random number - replace the **`* *`** with a minimum and maximum number. |
| \<random_target_icon>      | a random target icon like **`{skull}`** and **`{moon}`** |
| \<random_party_member>     | a random party/subgroup member |
| \<random_group_member>     | a random group member, including other subgroups if in a raid |
| \<random_guild_member>     | a random online guild member |
| \<random_tutorial_message> | a random in-game tutorial message - the ones that pop up when creating a new character before they're immediately disabled by everyone |
<br/>

| Miscellaneous&nbsp;Variables | Description |
| --- | --- |
| \<make_spell_link:*> | replace **`*`** with a spell ID to create a link of that spell |
| \<zone>              | zone you're in, like Mulgore or Orgrimmar |
| \<subzone>           | subzone you're in, like Valley of Spirits |
| \<zone_full>         | zone and subzone you're in, like Valley of Spirits in Orgrimmar |
| \<coords>            | rounded coordinates you're at (can't use in instances) like 32, 37 |
| \<coords_exact>      | more exact coordinates you're at (can't use in instances) like 31.7, 37.4 |
| \<summon_last_zone>  | the area name that the most recent summon came from |
| \<summon_time_left>  | how many more seconds a summon is available, or 0 if there isn't one |
| \<direction>         | direction of last minimap ping: nearby, to the north, to the southwest, etc. |
| \<game_time_simple><br/>\<real_time_simple> | simple description based on game or your time:<br/>00:00 to 04:59: "early morning" (night isn't used because it ruins things like "Good ___")<br/>05:00 to 11:59: "morning"<br/>12:00 to 16:59: "afternoon"<br/>17:00 to 23:59: "evening" |
| \<game_time_general><br/>\<real_time_general> | general description based on game or your time:<br/>05:00 to 11:59: "morning"<br/>12:00 to 16:59: "afternoon"<br/>17:00 to 20:59: "evening"<br/>21:00 to 04:59: "night" |
| \<game_time_description><br/><real_time_description> | bigger descriptions based on game or your time:<br/>00:15 to 04:59: "late at night"</br>05:00 to 06:59: "early in the morning"</br>07:00 to 11:44: "in the morning"</br>11:45 to 12:14: "around noon"</br>12:10 to 15:59: "in the afternoon"</br>16:00 to 16:59: "in the late afternoon"</br>17:00 to 19:59: "in the evening"</br>20:00 to 20:59: "late in the evening"</br>21:00 to 23:44: "at night"</br>23:45 to 00:14: "around midnight" |
<br/>

| Symbol&nbsp;"Variables" | Description |
| --- | --- |
| \<tm>    | trademark symbol |
| \<r>     | registered trademark symbol |
| \<c>     | copyright symbol |
| \<cross> | cross symbol |
| \<lts>   | less-than sign: **`<`** |
| \<gts>   | greater-than sign: **`>`** |
| \<opar>  | openening parenthesis: **`(`** |
| \<cpar>  | closing parenthesis:   **`)`** |
| \<obra>  | opening brace/bracket: **`{`** |
| \<cbra>  | closing brace/bracket: **`}`** |
<br/>

| Chat&nbsp;Variables | Description |
| --- | --- |
| \<message>        | the full message that triggered the reaction |
| \<channel>        | the channel name that the message is in |
| \<channel_number> | the channel number (if any) that the message is in |
| \<capture:*>      | replace **`*`** with the text capture number, explained in the Chat section. |
<br/>

## Randomization

Randomization is similar to tags but put in a single reaction message. You surround the randomized part in **`()`** and separate each choice with **`|`**.

Example: `He died after getting hit by (two|three|four|five|six) (arrows|bullets).`<br/>
Possible result: `He died after getting hit by four arrows.`

You can leave choices empty, like `"No.(| I won't!)"` which would show either `"No."` or `"No. I won't!"`

You can put tags, variables, and even other randomization things inside each choice. Here's an example assuming `{big size}` and `{small size}` are tags:<br/>
Example: `The ({big size} (dinosaur|troll)|{small size} (rat|duck)) ran to <target_name>`<br/>
Possible result: `The tiny rat ran to Pyralis.`

Using **`<new>`** is an exception and can't be used inside these. This is because they're processed first, so it would just split up the message in an awkward place if you put it as a random choice.

# **7. Chat triggers**
To create a reaction to chat messages, click "Chat > Add Trigger" and give it a name.

## Trigger Settings

| Option | Description |
| --- | --- |
| Group/Chance      | The same as in spells and events. |
| Global Cooldown   | A cooldown time before this trigger can be reacted to again. |
| Person Cooldown   | A cooldown time before a specific person can be reacted to again. |
| Allow matches from| The sender must be in at least one of these groups to trigger a reaction. |
| On&nbsp;match,&nbsp;stop&nbsp;checking&nbsp;other&nbsp;triggers| If checked, no other triggers are tested if this one matches. |
| Watch on these channels               | Check each type of chat message that can cause the reaction. |

Special "watch on these channels" cases:
* Error is for UI errors like "You cannot attack that target." and "Out of range."
* Action is for emote messages that come from commands like `/bow` so that you know it was an actual command and not a trick like `"/emote spits on you."` that everyone sees.
* Raid includes Raid Leader and Raid Warning.
* Battleground includes Battleground Leader.

## Message Matching
Options on the left can simplify the incoming message so that it's easier to match. Capitalization and punctuation can be removed, and links can be changed to plain text like `[22 Pound Catfish]` instead of the full link like `|cffffffff|Hitem:6311:0:0:0:0:0:0:0:0|h[22 Pound Catfish]|h|r`.

The **`<target_name>`** variable will normally be the person who sends the message, but will be blank for the System, Tradeskills, Loot, and Error channels. If you need someone's name from those (like getting a name from a roll), the Reaction section below will explain how to use "captures" to save parts of the matching message.

Triggers are checked in alphabetical order using their names. If the order matters, you could add numbers to the beginning, like "1: The First Trigger" and "2: Second Trigger."

### Match options
There are 2 ways to check if a message matches. You can use either or both:

1. **Match prhrases:** a phrase list to look for, with each phrase separated by **`|`**.<br/>
   Example: hello|bonjour|greetings

   Each phrase uses [lua pattern matching](http://www.gammon.com.au/scripts/doc.php?lua=string.find). Because of this, you'll need to put a **`%`** before the following characters to match them normally:<br/>
   `( ) . % + - * ? [ ^ $`

   For example, `"[22 Pound Catfish]"` should be `"%[22 Pound Catfish]"` because **`[`** is normally a special character in pattern matching.

2. **Custom Lua:** If phrase matching isn't powerful enough and you know lua, you can use it to check the message. Return true if the message matches. The following variables are available in lua:

   | Lua&nbsp;Chat&nbsp;Variable | Description |
   | --- | --- |
   | rs.message        | The full, unchanged message. |
   | rs.modifiedMessage| The modified message after using the message matching options on it. |
   | rs.target         | like **`<target_name>`** - the person who sent the message. Some messages (like System, Tradeskills, and Loot) have no sender. |
   | rs.channel        | The chat type name (like "yell") or a numbered channel's name (like "world"). |
   | rs.channelNumber  | If the channel is a numbered kind, then this will be its number. |
   | rs.capture[#]     | **`<capture:#>`** explained below. When using custom lua matching, you'll have to set these yourself if you want to use them in the reaction. |

## Reaction
### Reply options
There are 2 ways you can react to a message. You can use either or both:

1. **[channel] [message]** - just like an event/spell reaction. If you want multiple possible reactions, you can create a fake spell (like "Beggar Reply") then use that in the "Spell/Event" channel. It will use the "Your spell hit someone else" action.

2. **Custom Lua for reacting:** like using `/script <something>`, but a bit more room to write the script. The lua variables listed above in the Message Matching section can be used here.

### Use message text
To use part of the message in a reaction, you can use "captures" (explained [here](http://www.gammon.com.au/scripts/doc.php?lua=string.find)) in a match phrase. The **`<capture:#>`** variables will have the captured text in them. **`<capture:1>`** will always be the full message that matched. You can capture up to 14 things in a message, going up to **`<capture:15>`**. If you're using custom lua matching, you'll have to set these yourself (to anything you want) if you want to use them in the reaction.

| Full Example | Settings or Output |
| --- | --- |
| Watch&nbsp;on&nbsp;these&nbsp;channels | `System` |
| Match phrases         | `^(%S+) rolls (%d+) %(1%-100%)` |
| The text that matched | `Mcduck rolls 51 (1-100)` |
| \<capture:1> would be | `Mcduck rolls 51 (1-100)` |
| \<capture:2> would be | `Mcduck` |
| \<capture:3> would be | `51` |
| Chat reaction example | `/y <capture:2> rolled <capture:3> in front of my eyes!` |


A custom lua reaction example:
```
if tonumber(rs.capture[3]) > 50 then
   SendChatMessage("You rolled over 50!", "whisper", nil, rs.capture[2])
end
```

# **8. Special examples**
Here are some work-arounds for problems or techniques that may not be obvious.

## How to react to entering a specific area:

1. Create an "Environment > Changed Zone" event. Set the chance to 100, override GCD to 0, and check "Don't activate global cooldown on use."

2. As a reaction, pick the "Spell/Event" option and use: `<zone>`<br/>
   This will cause it to try to use a "spell" named the zone you just entered.

3. Create spells using the names of the zones (like Nagrand) with the action "Your spell hit someone else" and set them up however you want.

If you wanted to be more specific and use subzones too, you could use the "Changed Subzone" event instead, and for the Spell/Event reaction use: `<zone>-<subzone>`<br/>
Then make spells like: `Black Temple-Halls of Anguish`
