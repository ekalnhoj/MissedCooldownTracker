-------------------------------------------------------------------------------
-- ========================================================================= --
-- Spell tracking logic below
-- ========================================================================= --
-------------------------------------------------------------------------------

-- Local copy of the addon.
local CooldownTracker = CooldownTracker


local spell_list_all, class_spell_list, race_spell_list, blacklist
local icon_file_id_to_path
local debug_print

function CooldownTracker:SpellManager_OnInitialize()
    -- Set up some defaults
	if self.db.profile.blacklist == nil then self.db.profile.blacklist = {} end
	if self.db.race.race_spell_list == nil then self.db.race.race_spell_list = {} end
	if self.db.class.class_spell_list == nil then self.db.class.class_spell_list = {} end
	
	-- Assign local vars.
	blacklist = self.db.profile.blacklist
	class_spell_list = self.db.class.class_spell_list
	race_spell_list = class_spell_list -- self.db.race.race_spell_list
end

function CooldownTracker:SpellManager_StartupDelayed()
    CooldownTracker:LoadTables()


    -- Register important events that couldn't be registered earlier.
	-- CooldownTracker:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED","CDT_TalentChangeUpdate",1)
	CooldownTracker:RegisterEvent("PLAYER_TALENT_UPDATE","CDT_TalentChangeUpdate",3)
	-- It's unclear when these fire.
	-- CooldownTracker:RegisterEvent("TRAIT_TREE_CHANGED","CDT_TalentChangeUpdate",2)
	-- CooldownTracker:RegisterEvent("PLAYER_TALENT_UPDATE","CDT_TalentChangeUpdate",3)
	-- CooldownTracker:RegisterEvent("SELECTED_LOADOUT_CHANGED","CDT_TalentChangeUpdate",4)
	-- CooldownTracker:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED","CDT_TalentChangeUpdate",5)


    -- Load the art files
	icon_file_id_to_path = _G["ArtTexturePaths"]
end

function CooldownTracker:SpellManager_OnTick()
    -- CooldownTracker:Print("SpellManager_OnTick")
    if self.db.profile.learning_mode == true then
		CooldownTracker:GetAllSpellsWithCDOverThreshold()
	else
		CooldownTracker:Print("Not learning")
	end
	CooldownTracker:UpdateCooldowns()
end

function CooldownTracker:GetSpellList()
	if spell_list_all == nil then return {} else return spell_list_all end
end

function CooldownTracker:GetBlacklist()
    if blacklist == nil then return {} else return blacklist end
end

function CooldownTracker:LoadTables()
	spell_list_all = {}
    blacklist = self.db.profile.blacklist

	-- Maybe-future feature: loading by spec name rather than just by class.
	for i,v in ipairs(self.db.class.class_spell_list) do
		table.insert(spell_list_all, v)
	end

    -- I've decided to delay this (I'd need to adjust the spell field to note 
    --   if I thought it was a racial or class spell, and that will be 
    --    less annoying to do once I have everything else working).
	-- -- Next, race-specific spells (e.g. Shadowmeld).
	-- for i,v in ipairs(self.db.race.race_spell_list) do
	-- 	table.insert(spell_list_all, v)
	-- end
end

function CooldownTracker:SaveTables()
	-- Apparently tables are passed by reference, so no need for this.
	-- if debug_print then CooldownTracker:Print("Saving tables.") end
end

-- Note: below here in this section not really adjusted.
function CooldownTracker:SortTable(method)
	local function compare_by_cd(a,b)
		return a.cooldown < b.cooldown
	end

    if debug_print == true then 
        print("Sorting by: |",method,"|")
        print("-----------")
        print("Before: ")
        CooldownTracker:printTable(spell_list_all)
    end

    if method == "name" then
        table.sort(spell_list_all,compare_by_name)
    elseif method == "cd" then
        table.sort(spell_list_all,compare_by_cd)
    elseif method == "spell id" then
        table.sort(spell_list_all,compare_by_spell_id)
    else
        print("Unknown sort method ",method)
    end
    
    if debug_print == true then 
        print("-----------")
        print("After: ")
        CooldownTracker:printTable(spell_list_all)
        print("-----------")
    end
end

-- Notes to self:
--   Sorontar: Wild Charge is index 86
--   C_SpellBook.GetSpellBookItemCooldown(86,0) yields duration; is either 0 or 15, not a countdown. 
-- So logic needs to be:
--   . if spell is in tab 1, active, and a spell (not a flyout), then is racial
--   . if spell is later, then is druid spells. I could sort by spec, but I'd have to sort by class tree and spec tree which is doable but annoying and maybe not useful? If I do that, skillLineInfo has "name"
--   . GetSpellBookSkillLineInfo has an "isGuild" thing; maybe useful
-- 102401 = wild charge
-- 22842 = frenzied regen


function CooldownTracker:GetAllSpellsWithCDOverThreshold()
	local saving_spell_list = nil
	local is_racial = nil
    for i = 1,C_SpellBook.GetNumSpellBookSkillLines() do
		if i == 1 then 
			saving_spell_list = race_spell_list
			is_racial = true
		else
			saving_spell_list = class_spell_list
			is_racial = false
		end
		local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
		local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
		for j = offset+1, offset+numSlots do
			-- Get info about the current spell.
			local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(j, Enum.SpellBookSpellBank.Player)
			local spellBookItemCooldown = C_SpellBook.GetSpellBookItemCooldown(j, Enum.SpellBookSpellBank.Player)
			local spellBookItemChargeInfo = C_SpellBook.GetSpellBookItemCharges(j, Enum.SpellBookSpellBank.Player)

			if spellBookItemInfo and spellBookItemCooldown then
				-- Unpack info
				--   SpellBookItemInfo stuff
				local spellType, spellID, isPassive, spellIcon = spellBookItemInfo.itemType, spellBookItemInfo.actionID, spellBookItemInfo.isPassive, spellBookItemInfo.iconID
	
				local is_in_blacklist = 0
				for i,entry in ipairs(blacklist) do
					if spellID == entry.spellID then is_in_blacklist = 1 end
				end            

				local is_in_table = 0
				for i,entry in ipairs(spell_list_all) do
					if spellID == entry.spellID then is_in_table = 1 end
				end

				if not spellID then 
					-- If spellID isn't valid then do nothing, else keep running.
				elseif is_in_blacklist == 1 then
					-- If it's in the blacklist, don't add it to the table.
				elseif is_in_table == 1 then
					-- It's in the table; don't re-add it.
				else
					--   SpellBookItemCooldown stuff
					local duration = spellBookItemCooldown.duration

					--   SpellBookItemChargeInfo stuff
					local has_charges = false
					local max_charges = 1
					local currentCharges
					if spellBookItemChargeInfo == nil then
						has_charges = false
					else
						currentCharges, max_charges, duration = spellBookItemChargeInfo.currentCharges, spellBookItemChargeInfo.maxCharges, spellBookItemChargeInfo.cooldownDuration
					end

					-- Figure out if we care about it.
					if duration ~= nil then
						if isPassive == false and spellType == Enum.SpellBookItemType.Spell and duration and duration >= CooldownTracker.db.profile.track_threshold_min and duration <= CooldownTracker.db.profile.track_threshold_max then
							-- Keep going
							local spellName = C_Spell.GetSpellName(spellID)

							local spellIcon_filePath = nil
							if spellIcon ~= nil then 
								spellIcon_filePath = icon_file_id_to_path[spellIcon]
							end

							-- Assuming it's an offensive spell until told otherwise.
							-- is_known is probably how I'll handle different talent sets? Upon talent set swap it goes through the list and hides any spells not known.
							table.insert(spell_list_all,{spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true, has_charges=has_charges, max_charges=max_charges})
							-- And save it into the race/class spell list. 
							table.insert(saving_spell_list,{spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true, has_charges=has_charges, max_charges=max_charges})
							CooldownTracker:SortTable("cd")

							CooldownTracker:Print("Just added " .. spellName .. " to spell list.")
							CooldownTracker:RefreshOptions()
							CooldownTracker:UpdateIcons()
						else
							-- Do nothing.
						end
					end
				end
			end
		end
    end
end

function CooldownTracker:ValidateSpellTable()
    for i,entry in ipairs(spell_list_all) do
        local is_known_new = IsSpellKnown(entry.spellID)
        -- Hacking in a way to validate for cd changes in addition to whether it's known.
        if entry.cooldown < db.track_threshold_min then is_known_new = false end
        entry.is_known = is_known_new
    end

	CooldownTracker:RefreshOptions()
	CooldownTracker:UpdateIcons()
end

-- If I remember correctly, this one is updated on tick.
function CooldownTracker:UpdateCooldowns()
    local curr_time = GetTime()
    for _, spellData in ipairs(spell_list_all) do
		local spellInfo = C_Spell.GetSpellInfo(spellData.spellID)
		local spellCooldown = C_Spell.GetSpellCooldown(spellData.spellID)
		local spellCharges = C_Spell.GetSpellCharges(spellData.spellID)

		if spellCharges == nil then
			local start, duration = spellCooldown.startTime, spellCooldown.duration
			if start ~= nil and duration > 1.5 and duration >= CooldownTracker.db.profile.track_threshold_min and duration <= CooldownTracker.db.profile.track_threshold_max then
                spellData.lastUsed = start
            else
                -- Want a special case that detects if a spell can get reduced cooldown.
                --   A good example is Demon Hunter Eye Beams, which (via a talent) can 
                --   have its cooldown reduced by spending fury.
                -- As an example, assume Eye Beam is cast at time t=0, and the DH is 
                --   able to reduce its cd to 20 seconds. The user should have 
                --   one "missed cast" starting at t=20 and two "missed casts" 
                --   starting at t=60 (I'm not going to try to use past data to 
                --   project future likely reduction in cooldown, that way lies madness).
                -- Unfortunately, the addon won't show one "missed cast" until t=40 
                --   and won't transition to two missed casts until t=80. 
                -- So the thing to do is to check: if duration == 0 (i.e. it's off cd)
                --   and if GetTime() - spellData.lastUsed < spellData.cooldown . This
                --   will happen in the example above. The bandaid is to adjust the 
                --   lastUsed time to be GetTime - spellData.cooldown, which on the 
                --   display will be inaccurate Last Used but accurate missed casts.
                -- I suppose a more elegant solution would have a "LastUsed" and "LastUsed_calc"
                --   and use this calc value for the missed casts calcs and keep the 
                --   LastUsed unchanged in the situation outlined above.
                --
                -- Update: Tested it and it actually works fine without this. Huh. Never mind.
                -- if curr_time - spellData.lastUsed < spellData.cooldown then
                --     spellData.lastUsed = curr_time - spellData.cooldown
                -- end
            end
		else
			local curr_charges,max_charges,last_cast,cooldown,_ = spellCharges.currentCharges, spellCharges.maxCharges, spellCharges.cooldownStartTime, spellCharges.cooldownDuration

            if curr_charges < max_charges and cooldown > 1.5 and cooldown >= CooldownTracker.db.profile.track_threshold_min and cooldown <= CooldownTracker.db.profile.track_threshold_max then
                spellData.lastUsed = last_cast
            end
		end
    end
end

function CooldownTracker:ResetSpellNumbers()
    local t_reset = GetTime()
    for i,entry in ipairs(spell_list_all) do
        entry.lastUsed = t_reset
    end
    CooldownTracker:UpdateTableText()
end

function CooldownTracker:BlacklistToggleByID(spellID)
	CooldownTracker:Print("BlacklistToggleByID")

    for i, entry in ipairs(spell_list_all) do
        if entry.spellID == spellID then
            -- Add to blacklist and remove from monitoredSpells
            table.insert(blacklist,entry)
            table.remove(spell_list_all,i)
			CooldownTracker:RefreshOptions()
			CooldownTracker:UpdateIcons()
			return
        end
    end

	for i, entry in ipairs(blacklist) do
		if entry.spellID == spellID then
			-- Add to blacklist and remove from monitoredSpells
			if IsSpellKnown(spellID) == true then
				table.insert(spell_list_all,entry)
				CooldownTracker:SortTable("cd")
			end
			table.remove(blacklist,i)
			CooldownTracker:RefreshOptions()
			CooldownTracker:UpdateIcons()
			return
		end
	end

	CooldownTracker:Print("Pre-emptively blacklisting Spell ID " .. spellID)
	-- If it wasn't already monitored, preemptively add it with some barebones info.
	local spellInfo = C_Spell.GetSpellInfo(spellID)
	local spellName, spellIcon = spellInfo.name, spellInfo.iconID
	local spellIcon_filePath = nil
	if spellIcon ~= nil then 
		spellIcon_filePath = icon_file_id_to_path[spellIcon]
	end
	table.insert(blacklist,{spellID=spellID, spellName=spellName, cooldown=-1, lastUsed=-1, spellIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true})

	if debug_print == true then print("Cleansing with new blacklist.") end
	blacklist_cleanse()
	CooldownTracker:RefreshOptions()
	CooldownTracker:UpdateIcons()
	return
end