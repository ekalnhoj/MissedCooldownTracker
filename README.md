# CooldownTracker
WoW Cooldown Tracker addon


https://imgur.com/a/AbkRdTu
In the image, CD = cooldown, LU = last used (seconds ago), and MC = missed casts. MC is orange if you've had it available for less than its cooldown, and red if you've missed a cast. Put more plainly: if you use a 30 second cooldown, MC will be 0 while the spell is on cooldown, MC will be 1 when 31-60 seconds have passed since you last used the spell, and 2 when 61+ seconds have passed since you last used the spell (since you could've used the spell at t = 0 seconds, t = 30 seconds, and t = 60 seconds, and you've just used it once, so you missed out). 


### What is it?
Cooldown Tracker is an addon that tracks spells with a cooldown over a threshold. The goal is to make it clear when you've missed uses of your cooldowns, e.g. in a raid fight or M+ dungeon. 



### Why make it?
I personally am awful about saving my cooldowns "for that big pack" or "for the boss" and then using two and three-minute cooldowns cooldowns four times in a dungeon, which is obviously not ideal. With this addon, I can screen record a dungeon and easily answer the question of "hm, could I have fit in another cast of this before that boss?". Obviously you can also look at it live.



### (Likely) FAQ:
Any setup needed?
Just make sure it's enabled in your addon options, make sure "Learning Mode" is enabled, then go use all your spells on a dummy or something. You can turn off "Learning Mode" once you've used all the spells and it has them learned. You only need to do this once ever for each spell you want to track. 



Honestly though I keep my addon with Learning Mode enabled and it seems fine, I haven't noticed it impacting my FPS or anything. But the option is there!


#### How does it learn the spells?
By default, the addon is in "Learning Mode", meaning every "tick" it will check to see if any spells are on cooldown. For spells without charges, the WoW API only gives cooldown numbers for the spells when they are actually on cooldown\*. For spells with charges, the WoW API can retrieve the cooldown without having to use them. 



\* this seems weird to me so if someone knows the API function that will retrieve a cooldown for spells without this, please let me know



#### How do I set the spell tracking threshold / other settings?
The WoW options menu for addons should have an entry for this addon. Typing "/cdt" should also open the menu. 



#### Can I resize the CDT display?
Yeah, it's under Display Options. The little "drag tab" is at the bottom right corner.



#### Do I need a separate profile for each character / class?
No. The only thing stored in the profile is the settings (e.g. how often does it update, what's the minimum cooldown tracked, etc.). The spell IDs of your race, class, and spec abilities are stored in a shared database. 



#### Why is everything marked as an Offensive Spell?
In the options menu there's a "Spell List" entry. Expand that and you can see the "Spell List" and "Blacklist". That'll let you change the designation of each spell you know (Offensive, Defensive, Utility) and let you Blacklist (i.e. no longer track) a spell. If you want to un-blacklist a spell, go to the blacklist entry and hit the appropriate button. 



You'll likely want to blacklist "Revive Battle Pets", for example. 



#### What if I've found a bug?
Please leave a comment, ideally including the behavior and how to reproduce it; I'll try to check them periodically. Thanks!