# Reactions

###### Scary warning: Most of these addons were made long ago during Feenix days, then a lot was changed/added to prepare for Corecraft. Since it died, they still haven't been extensively tested on modern servers.

### [Downloads](https://github.com/Shanghi/Reactions/releases)

***

## Purpose:
This will let you say or do things based on actions happening to you or around you. A boring example would be to react to when you begin casting a resurrection spell by telling your group who you're resurrecting. A more important example would be to say something about a party member who just drowned.

You can react to many types of actions:
* You can react to any spell based on what happened to it (you hit someone with it, a group member resists it, you take periodic damage from it, you begin casting it, someone outside the group gains its aura, etc).
* You can react to many events, like if combat starts/ends, your health/mana becomes low, a flight path starts, someone is damaged or killed by drowning or lava, someone in your group gets the killing blow on a boss, you're summoned (before and after), you start/stop following someone, you destroy an item, you use a mailbox, you resurrect, you go underwater, you join a group, you become stunned/feared/snared/etc, and many more.
* You can react to chat, system, and error messages.

Each action can have any amount of reactions and a random one will be chosen.
* Reacting can have a chance set so that it won't happen 100% of the time.
* After reacting, there's a global cooldown time before another reaction will be used. Each action can override this to have its own time (or no cooldown at all). You can limit them other ways too like to only let it happen every 20 fights.
* Each individual reaction can have many conditions set, like to only be picked if it's morning time in a battleground while you're in cat form wearing a specific item and the spell you used critically hit a gnome.
* Reactions can be chat messages, non-protected commands like /invite, scripts, or a mix of all. Messages can use variables like the target's name, custom tags you can make like {race} to pick a random race from a list, and randomized text like "There were (two|three|four) of them!" You can do multiple things at once (like say something then use /sleep) and optionally have pauses between each thing (which can have specific or random times).

## Using:
To start, use **`/rs`** to open the settings. There a so-called "quick" guide explaining a few things in the "Options & Info" section, and a more complete guide [here](https://github.com/Shanghi/Reactions/blob/master/guide.md).

| Commands (/rs or /reactions) | Description |
| --- | --- |
| /rs | _opens the settings window -<br/>all shortcut commands below can be set there_ |
| /rs \<"on"\|"off">               | _shortcut to enable/disable the addon_ |
| /rs test \<"on"\|"off">          | _shortcut to turn test mode on or off_ |
| /rs cooldown \<seconds>          | _shortcut to set the global cooldown time between actions_ |
| /rs chance \<multiplier>         | _shortcut to set a chance multiplier for reactions_ |
| /rs shout \<"on"\|"off">         | _shortcut to turn shout mode on or off_ |
| /rs&nbsp;group&nbsp;\<name>&nbsp;\<"on"\|"off"> | _shortcut to enable or disable a group of reactions_ |
| /rs use "\<spell>" [target]      | _use a "spell" reaction, optionally on a target name -<br/>surround the spell in quotation marks_ |

## Screenshots:
Complimenting a group member's bark skin.
![!](https://i.imgur.com/oCqeXWP.png)

_"OH MY GOD this guy has a macro when he LANDS off of a fuckin' flight like a griffin he yells hello everyone I am here and uhhhh 'cause I've seen him do this like 4 times (ghod) and then he greets everyone warmly"_
![!](https://i.imgur.com/qTJOJS4.png)

A simple chat trigger to yell "Hail Akama!" whenever someone else does, but only once every 8 seconds.
![!](https://i.imgur.com/8IeL2H0.png)
