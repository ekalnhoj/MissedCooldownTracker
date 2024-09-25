-------------------------------------------------------------------------------
-- ========================================================================= --
-- Spell tracking logic below
-- ========================================================================= --
-------------------------------------------------------------------------------

-- Local copy of the addon.
local CooldownTracker = MissedCooldownTracker


local race_spell_page = 1
local class_spell_page = 2
local function GetSpecIdx() return GetSpecialization()+2 end
local spell_list_all, race_spell_list, class_spell_list, spec_spell_list, blacklist
local icon_file_id_to_path
local debug_print
local recently_cast = {}

local tick_counter = 0

function CooldownTracker:SpellManager_OnInitialize()
	debug_print = CooldownTracker.debug_print

	-- Event-fired message functions registered in the main file.
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- Event-fired message functions.
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:SpellManager_StartupDelayed()
	-- Registered to CDT_API_LOADED message.
	if debug_print == true then CooldownTracker:Print("SM StartupDelayed") end

    CooldownTracker:LoadTables()
	CooldownTracker:SortTable("cd")

    -- Register important events that couldn't be registered earlier.
	-- CooldownTracker:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED","CDT_TalentChangeUpdate",1)
	CooldownTracker:RegisterEvent("PLAYER_TALENT_UPDATE","CDT_TalentChangeUpdate",3)
	-- It's unclear when these fire.
	-- CooldownTracker:RegisterEvent("TRAIT_TREE_CHANGED","CDT_TalentChangeUpdate",2)
	-- CooldownTracker:RegisterEvent("PLAYER_TALENT_UPDATE","CDT_TalentChangeUpdate",3)
	-- CooldownTracker:RegisterEvent("SELECTED_LOADOUT_CHANGED","CDT_TalentChangeUpdate",4)
	-- CooldownTracker:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED","CDT_TalentChangeUpdate",5)

	-- Uncomment if change mind on how to do the loop in updateCooldowns.
	-- CooldownTracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellCastSuccess")

    -- Load the art files
	icon_file_id_to_path = _G["ArtTexturePaths"]
end

function CooldownTracker:SpellManager_OnTick()
    -- Registered to CDT_TICK message.
    if self.db.profile.learning_mode == true then
		CooldownTracker:GetAllSpellsWithCDOverThreshold()
	else
		if debug_print == true then CooldownTracker:Print("Not learning") end
	end
	CooldownTracker:UpdateCooldowns()

	tick_counter = tick_counter+1
	if tick_counter > self.db.profile.track_threshold_min then
		self:SaveLastUsedTimes()
		tick_counter = 0
	end
end

function CooldownTracker:SpellManager_OnPause()
    -- Registered to CDT_PAUSE message.
end

function CooldownTracker:SpellManager_OnUnpause()
    -- Registered to CDT_UNPAUSE message.
end

function CooldownTracker:SpellManager_OnEnable()
	-- Registered to CDT_ENABLE message.
end

function CooldownTracker:SpellManager_OnDisable()
	-- Registered to CDT_DISABLE message.
end

-- === Not-common events
function CooldownTracker:CDT_TalentChangeUpdate(args)
	if debug_print == true then CooldownTracker:Print("Talent tree changed.") end
	-- This may not be needed.
	CooldownTracker:LoadTables()
	-- This is likely needed.
	CooldownTracker:ValidateSpellTable()
	CooldownTracker:SortTable("cd")
	CooldownTracker:RefreshOptions()
	
    CooldownTracker:RedrawDisplay(true)
end

function CooldownTracker:OnSpellCastSuccess(event, unitTarget, castGUID, spellID)
    if unitTarget == "player" then        
		-- Get entry by spellID
		-- Set current time
		recently_cast[spellID] = true
    end
end

-------------------------------------------------------------------------------
-- ========================================================================= --
-- 
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:GetSpellList()
	if spell_list_all == nil then return {} else return spell_list_all end
end

function CooldownTracker:GetBlacklist()
	if self.db.profile.blacklist == nil then 
		self.db.profile.blacklist = {}
	end
	return self.db.profile.blacklist
end

function CooldownTracker:GetRaceSpellList()
	if self.db.race.race_spell_list == nil then 
		self.db.race.race_spell_list = {}
	end
	return self.db.race.race_spell_list
end

function CooldownTracker:GetClassSpellList()
	-- Make sure the outer table exists; if not, then make it.
	if self.db.class.class_spell_list == nil then
		self.db.class.class_spell_list = {}
	end
	-- Now check if the inner table exists; if not, then make it.
	if self.db.class.class_spell_list[class_spell_page] == nil then
		self.db.class.class_spell_list[class_spell_page] = {}
	end
	-- And return it.
	return self.db.class.class_spell_list[class_spell_page]
end

function CooldownTracker:GetSpecSpellList()
	-- Make sure the outer table exists; if not, then make it.
	if self.db.class.class_spell_list == nil then
		self.db.class.class_spell_list = {}
	end
	-- Now check if the inner table exists; if not, then make it.
	if self.db.class.class_spell_list[CooldownTracker:GetSpecSpellPage()] == nil then
		self.db.class.class_spell_list[CooldownTracker:GetSpecSpellPage()] = {}
	end
	return self.db.class.class_spell_list[CooldownTracker:GetSpecSpellPage()]
end

function CooldownTracker:GetSpecSpellPage()
	return GetSpecIdx()+class_spell_page
end

function CooldownTracker:GetTableBySpellPage(spellPageIdx)
	if spellPageIdx == -1 then
		if debug_print == true then CooldownTracker:Print("Issue finding spell to remove.") end 
	elseif spellPageIdx == 1 then return self:GetRaceSpellList()
	elseif spellPageIdx == 2 then return self:GetClassSpellList()
	else return self:GetSpecSpellList()
	end 
end

function CooldownTracker:LoadTables()
	-- Would be pretty but my life is easier if I just use the numbers.
	-- local classInfoStruct = C_PlayerInfo.GetClass({unit="player"})
	-- local className = classInfoStruct.classFilename
	-- local specInfoStruct = GetSpecializationInfo(GetSpecIdx())
	-- local specName = specInfoStruct.name

	-- Assign local vars.
    race_spell_list = self:GetRaceSpellList()
	class_spell_list = self:GetClassSpellList()
	spec_spell_list = self:GetSpecSpellList()
	blacklist = self:GetBlacklist()

	-- Reset the table
	spell_list_all = {}
	-- If it's been super long then we reset the numbers here.
	local curr_time = GetTime()
	local reset_thresh = 3600

	-- Load race-specific spells.
	for i,v in ipairs(race_spell_list) do
		if curr_time - v.lastUsed > reset_thresh then v.lastUsed = curr_time end
		table.insert(spell_list_all, v)
	end

	for i,v in ipairs(class_spell_list) do
		if curr_time - v.lastUsed > reset_thresh then v.lastUsed = curr_time end
		table.insert(spell_list_all, v)
	end	
	
	for i,v in ipairs(spec_spell_list) do
		if curr_time - v.lastUsed > reset_thresh then v.lastUsed = curr_time end
		table.insert(spell_list_all, v)
	end	
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

function CooldownTracker:CheckIfInTable(table,spellID)
	if table == nil then 
		if debug_print == true then CooldownTracker:Print("Issue checking if " .. spellID " is in table.") end
		return 0 
	end
	
	local is_in_table = 0
	for i,entry in ipairs(table) do
		if spellID == entry.spellID then
			is_in_table = 1
			break
		end
	end
	return is_in_table
end

function CooldownTracker:GetAllSpellsWithCDOverThreshold()
	local saving_spell_list = nil
	local is_racial = nil
    for i = 1,C_SpellBook.GetNumSpellBookSkillLines() do
		local spellBookTab = i
		-- When (if) I separate out racials again then I'll re-enable this.
		-- if i == 1 then 
		-- 	saving_spell_list = race_spell_list
		-- 	is_racial = true
		-- else
		-- 	saving_spell_list = class_spell_list
		-- 	is_racial = false
		-- end
		local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
		if skillLineInfo == nil then break end
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
	
				local is_in_blacklist = CooldownTracker:CheckIfInTable(blacklist,spellID)
				local is_in_table = CooldownTracker:CheckIfInTable(spell_list_all,spellID)

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
							table.insert(self:GetTableBySpellPage(spellBookTab),{spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spellBookTab=spellBookTab, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true, has_charges=has_charges, max_charges=max_charges})
							CooldownTracker:SortTable("cd")

							CooldownTracker:Print("Just added " .. spellName .. " to spell list.")
							CooldownTracker:LoadTables()
							CooldownTracker:SortTable("cd")
							CooldownTracker:RefreshOptions()
							CooldownTracker:RedrawDisplay()
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
        if entry.cooldown < CooldownTracker.db.profile.track_threshold_min then 
			is_known_new = false 
		end
        entry.is_known = is_known_new
    end

	CooldownTracker:ValidateBlacklist()
	CooldownTracker:RefreshOptions()
	CooldownTracker:RedrawDisplay()
end

function CooldownTracker:ValidateBlacklist()
	-- Yes it's n-squared, sorry. But blacklist is probably short so 
    --   realistically it shouldn't be too bad I think?
    for ib,entryb in ipairs(blacklist) do
        for i,entry in ipairs(spell_list_all) do        
            if entry.spellID == entryb.spellID then
                CooldownTracker:Print("Removing from monitored spells: ",entry.spellID,": ",entry.spellName)
                CooldownTracker:RemoveSpellByID(entry.spellID)
				break
            end
        end
    end
end

function CooldownTracker:SaveLastUsedTimes()
	-- Think saving last used times to files every... minimum_duration seconds
	--   seems reasonable and kinda low overhead?
	-- Idea is that if you have to reload mid-fight or mid-dungeon you don't
	--   want to lose the last used time. Also honestly some of it is that I 
	--   hate logging in and seeing a ridiculously-large number.
	for i_s,entry_s in ipairs(spell_list_all) do
		local which_list = entry_s.spellBookTab
		if which_list == 1 then
			for i,v in ipairs(race_spell_list) do
				if v.spellID == entry_s.spellID then
					v.lastUsed = entry_s.lastUsed
				end
			end

		elseif which_list == 2 then
			for i,v in ipairs(class_spell_list) do
				if v.spellID == entry_s.spellID then
					v.lastUsed = entry_s.lastUsed
				end
			end

		else
			for i,v in ipairs(spec_spell_list) do
				if v.spellID == entry_s.spellID then
					v.lastUsed = entry_s.lastUsed
				end
			end
		end
	end
end

-- If I remember correctly, this one is updated on tick.
function CooldownTracker:UpdateCooldowns()
    local curr_time = GetTime()
	-- for k,v in pairs(recently_cast) do
	-- 	-- I like the idea of using this loop instead of the other one; however,]
	-- 	--   upon thinking about it, I realized that way - updating the start
	-- 	--   time only when cast - won't catch when cooldowns come up early 
	-- 	--   (e.g. if there's a proc or if cooldowns are reduced by procs). 
	-- end
	
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

function CooldownTracker:HardResetTables()
	wipe(spell_list_all)
	wipe(race_spell_list)
	wipe(class_spell_list)
end

function CooldownTracker:RemoveSpellByID(spellID)
	for spellBookTab = 1,C_SpellBook.GetNumSpellBookSkillLines() do
		local found_in_spell_list = self:GetTableBySpellPage(spellBookTab)
		for i, entry in ipairs(found_in_spell_list) do
			if entry.spellID == spellID then
				table.remove(found_in_spell_list,i)
				break
			end
		end
	end
end

function CooldownTracker:BlacklistToggleByID(spellID)
	if debug_print == true then CooldownTracker:Print("BlacklistToggleByID") end

	local found_it = 0
    for i, entry in ipairs(spell_list_all) do
        if entry.spellID == spellID then
            -- Add to blacklist and remove from monitoredSpells
            table.insert(blacklist,entry)
			CooldownTracker:RemoveSpellByID(spellID)
			
			found_it = 1
			break
        end
    end

	if found_it == 0 then
		for i, entry in ipairs(blacklist) do
			if entry.spellID == spellID then
				-- Add to blacklist and remove from monitoredSpells
				if IsSpellKnown(spellID) == true then
					local found_in_spell_list = self:GetTableBySpellPage(entry.spellBookTab)
					table.insert(found_in_spell_list,entry)
					CooldownTracker:LoadTables()
					CooldownTracker:SortTable("cd")
				end
				table.remove(blacklist,i)
				
				found_it = 1
				break
			end
		end
	end

	if found_it == 0 then
		if debug_print == true then CooldownTracker:Print("Pre-emptively blacklisting Spell ID " .. spellID) end
		-- If it wasn't already monitored, preemptively add it with some barebones info.
		local spellInfo = C_Spell.GetSpellInfo(spellID)
		local spellName, spellIcon = spellInfo.name, spellInfo.iconID
		local spellIcon_filePath = nil
		if spellIcon ~= nil then 
			spellIcon_filePath = icon_file_id_to_path[spellIcon]
		end
		table.insert(blacklist,{spellID=spellID, spellName=spellName, cooldown=-1, lastUsed=-1, spellBookTab=-1, spellIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true})

		if debug_print == true then print("Cleansing with new blacklist.") end
		CooldownTracker:ValidateBlacklist()
	end
	
	CooldownTracker:LoadTables()
	CooldownTracker:SortTable("cd")
	CooldownTracker:RefreshOptions()
	CooldownTracker:RedrawDisplay()

end
