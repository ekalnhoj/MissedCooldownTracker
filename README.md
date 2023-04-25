# CooldownTracker
WoW Cooldown Tracker addon

Why make this addon? 
I personally am bad about saving my cooldowns "for that big pack" or "for the boss" and then using my big cooldowns four times in a dungeon, which is obviously not ideal. This addon will let me screen record and when I wonder "hm I wonder if I could have fit in another cast of <cooldown> before boss" I can have that question pretty quickly answered. 

I guess things will get wonky if your class has its major cd reduced by other spells (I think warriors have this? and some tanks too) but classes with immutable major cooldown lengths should find this pretty useful.

Any features I should know about it?
The WoW Options menu, in the addons tab, should have an entry for this addon. In there, you can blacklist spells (e.g. Revive Battle Pets) and change the categorization of spells (offensive, defensive, and utility). I'll add more options at a later date.

What if I want fewer spaces between the sections on the display?
Lines 809 and 883 of CooldownTracker.lua: change the number (default 3) to some other number between 0 and whatever. I'll streamline this at a later date but it's not exactly high priority.
