-- Thanks to the creator of HandyNotes whose LUA I adapted to help me with this. Blame any bad coding on me, though.

local debug_print = false

CooldownTracker = LibStub("AceAddon-3.0"):NewAddon("CooldownTracker","AceConsole-3.0","AceEvent-3.0")
local CooldownTracker = CooldownTracker
local L = LibStub("AceLocale-3.0"):GetLocale("CooldownTracker", false)


-- Our db upvalue and db defaults
local db
local options

local defaults = {
	profile = {
		enabled = true,
        learning_mode = true,
        display_enabled = true,
        track_threshold_min = 30,
        track_threshold_max = 300,
        tick_frequency = 0.5,
        -- Below are not in options menu 
        frame_adjustability = "None",
        coordinate_x = 6.66665506362915,
        coordinate_y = 802.5, 
        size_x = 297.5,
        size_y = 391.67,
        show_frame = true,
        periodic_save = true,
        str_max_disp_len = 17,
		section_line_breaks = 2,
	},
}

local classification_options_to_str = {
    offensive = "Offensive",
    defensive = "Defensive",
    utility = "Utility",
}

function CooldownTracker:hasNonIndexKeys(tbl)
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or k > #tbl then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- ========================================================================= --
-- Options section
-- ========================================================================= --
-------------------------------------------------------------------------------

-- A default options table.
options = {
	type = "group",
	name = L["CooldownTracker"],
	desc = L["CooldownTracker"],
	args = {
		enabled = {
			type = "toggle",
			name = L["Enable CooldownTracker"],
			desc = L["Enable or disable CooldownTracker"],
			order = 1,
			get = function(info) return db.enabled end,
			set = function(info, v)
				db.enabled = v
				if v then CooldownTracker:Enable() else CooldownTracker:Disable() end
			end,
			disabled = false,
		},
		overall_settings = {
			type = "group",
			name = L["Overall settings"],
			desc = L["Overall settings that affect every database"],
			order = 10,
			get = function(info) return db[info.arg] end,
			set = function(info, v)
				local arg = info.arg
				db[arg] = v
				if arg == "track_threshold_min" or arg == "track_threshold_max" then
					CooldownTracker:RedrawDisplay()
				else
					CooldownTracker:RedrawDisplay()
				end
			end,
			disabled = function() return not db.enabled end,
			args = {
				desc = {
					name = L["These settings control the execution of CooldownTracker globally."],
					type = "description",
					order = 0,
				},
                display_enabled = {
                    type = "toggle",
                    arg = "display_enabled",
                    name = "Display CDT",
                    desc = "Whether or not the display for CooldownTracker is shown",
                    order = 5,
                    get = function(info) return db.display_enabled end,
                    set = function(info, v)
                        db.display_enabled = v
                        if v then CooldownTracker:ShowFrame(true) else CooldownTracker:ShowFrame(false) end
                    end,
                },
                learning_mode = {
                    type = "toggle",
                    arg = "learning_mode",
                    name = L["Learning Mode"],
                    desc = L["Whether CooldownTracker checks for new spell IDs on cooldown."],
                    order = 5,
                },
                -- I don't remember what this is for so I'm gonna keep it hidden.
                -- periodic_save = {
                --     type = "toggle",
                --     arg = "periodic_save",
                --     name = L["Whether CooldownTracker is learning."],
                --     desc = L["Whether CooldownTracker checks for new spell IDs on cooldown."],
                --     order = 5,
                -- },
                track_threshold_min = {
                    type = "range",
                    name = L["Min CD length tracked"],
                    desc = L["The minimum cooldown length (in seconds) to track."],
                    min = 1, max = 900, softMin = 15, softMax = 300,  -- softMin and softMax are what the display shows, even if the text entry allows bigger
                    step = 1, bigStep = 15,
                    arg = "track_threshold_min",
                    order = 20,
                },
                track_threshold_max = {
                    type = "range",
                    name = L["Max CD length tracked"],
                    desc = L["The maximum cooldown length (in seconds) to track."],
                    min = 1, max = 900, softMin = 15, softMax = 300,  -- softMin and softMax are what the display shows, even if the text entry allows bigger
                    step = 1, bigStep = 15,
                    arg = "track_threshold_max",
                    order = 21,
                },
                tick_frequency = {
                    type = "range",
                    name = L["CDT Update period"],
                    desc = L["Interval at which CooldownTracker checks spell cooldowns."],
                    min = 0.1, max = 5, softMin = 0.5, softMax = 2, 
                    step = 0.25, bigStep = 0.25,
                    arg = "tick_frequency",
                    order = 10,
                },
                -- I don't remember what this is for either, so commented out.
                -- sort_method = {
                --     type = "select",
                --     name = L["CooldownTracker display sort method"],
                --     desc = L["Which method to use for choosing CooldownTracker display order."],
                --     style = "dropdown",
                --     values = {cooldown = "cooldown"},
                --     order = 40,
                -- },
			},
		},
		spell_list = {
			type = "group",
			name = L["Spell list"],
			desc = L["List of spells this character has access to."],
			order = 20,
			disabled = function() return not db.enabled end,
			args = {
				spell_list={type="group",name="Spell List",args={},order=10},
				blacklist={type="group",name="Blacklist",args={},order=20},
			},
		},
	},
}

-- Table entry structure:
--   {spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, spellBookTab=spellBookTab, classification="offensive", is_known=true, has_charges=has_charges, max_charges=max_charges}
-- Function to generate the options table
local function generateOptions(spellTable,is_the_blacklist)
	-- if true then return {} end
	is_the_blacklist = is_the_blacklist or false
    local new_sub_options = {}
    for i, entry in ipairs(spellTable) do
        local spellOptions = {
            type = "group",
			inline = true,
            name = entry.spellName,
            args = {
				spellName = {
					type = "description",
					name = entry.spellName,
					image = entry.spellIcon_filePath,
					imageWidth = 16,
					imageHeight = 16,
                    order = 0
				},
                classification = {
                    type = "select",
                    style="radio",
                    name = "Classification",
					width = "half",
                    values = classification_options_to_str,
                    get = function(info) return entry.classification end,
                    set = function(info, value) entry.classification = value end,
                    order = 10
                },
                spellID = {
                    type = "description",
                    name = "Spell ID: " .. entry.spellID,
                    order = 5
                },
				addToBlacklist = {
					type = "execute",
					width = "half",
					name = function() if not(is_the_blacklist) then return "Blacklist" else return "Un-Blacklist" end end,
					func = function() CooldownTracker:BlacklistToggleByID(entry.spellID) end,
                    order = 15
				}
            },
        }
        -- table.insert(new_sub_options, spellOptions)
		new_sub_options["spell_" .. entry.spellID] = spellOptions
    end
    return new_sub_options
end

function CooldownTracker:RefreshOptions()
    -- Remake the spelllist and blacklist parts of the options menu.
    --   Needed because I'm dynamically generating the options menu based on 
    --   the spell_list and blacklist table contents, so any changes to the 
    --   tables necessitate a change to the options menu.
	if debug_print == true then CooldownTracker:Print("Refresh Options") end
    wipe(options.args.spell_list.args.spell_list.args)
	wipe(options.args.spell_list.args.blacklist.args)

    local new_spell_list = generateOptions(CooldownTracker:GetSpellList())
	local new_black_list = generateOptions(CooldownTracker:GetBlacklist(),true)

	-- Assign new options to the correct locations
    for k, v in pairs(new_spell_list) do
        options.args.spell_list.args.spell_list.args[k] = v
    end

    for k, v in pairs(new_black_list) do
        options.args.spell_list.args.blacklist.args[k] = v
    end

	-- options.args.spell_list.args.spell_list.args = new_spell_list
	-- options.args.spell_list.args.blacklist.args = new_black_list
	
    LibStub("AceConfigRegistry-3.0"):NotifyChange("CooldownTracker")
end

function CooldownTracker:OnProfileChanged(event, database, newProfileKey)
	db = database.profile
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- This section for addon startup and shutdown, addon enable and disable, and 
--   for the clock and control of it (pause and unpause).
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:OnInitialize()
    if debug_print == true then CooldownTracker:Print("CooldownTracker Initialized!") end

    CooldownTracker.debug_print = debug_print
    CooldownTracker.paused = false
    -- CooldownTracker.is_running = function() return not(paused) end

    -- Code that you want to run when the addon is first loaded goes here.
    -- Set up our database
	self.db = LibStub("AceDB-3.0"):New("CooldownTrackerDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	-- self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")
	db = self.db.profile

	-- Register options table and slash command
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("CooldownTracker", options)
	self:RegisterChatCommand("cooldowntracker", function() LibStub("AceConfigDialog-3.0"):Open("CooldownTracker") end)
    self:RegisterChatCommand("cdt", function() LibStub("AceConfigDialog-3.0"):Open("CooldownTracker") end)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CooldownTracker", "CooldownTracker")
	-- Register my own slash commands
	self:RegisterChatCommand("cdt_other", "CDT_SlashProcessorFunc")

	-- Get the option table for profiles
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	options.args.profiles.disabled = options.args.overall_settings.disabled

	-- Register events (I feel like it makes sense to do this now)
	-- Update: am registering talent change events after the tables are loaded,
	--   because when logging in there's a talent change event so it'll do 
	--   things too fast if I don't wait.	

	-- Set up messages for some message-fired events.
	CooldownTracker:RegisterMessage("CDT_TICK")
	CooldownTracker:RegisterMessage("CDT_PAUSE")
	CooldownTracker:RegisterMessage("CDT_UNPAUSE")
    CooldownTracker:RegisterMessage("CDT_ENABLE")
    CooldownTracker:RegisterMessage("CDT_DISABLE")
	CooldownTracker:RegisterMessage("CDT_API_LOADED","OnStartup_Delayed")

	-- Sub-app initialize calls.
	CooldownTracker:SpellManager_OnInitialize()
    CooldownTracker:UIManager_OnInitialize()

	-- Set up tables and stuff once we're likely to have loaded in. From 
	--   testing, a small delay is prudent.
	local function delayed_startup()
		CooldownTracker:WaitForAPI()
	end
	C_Timer.After(1,delayed_startup)

end
-- The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded by the game client. It's a good time to do things like restore saved settings (see the info on AceConfig for more notes about that).

function CooldownTracker:WaitForAPI()
	-- Upon further review... this function may not be needed.
	local spec_idx, spec_name, spec_icon

	local attempts = 0
	local max_attempts = 30
	local function checkAPI()
		attempts = attempts + 1

		spec_idx = GetSpecialization()
		if spec_idx ~= nil then
			_,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)
		end

		if spec_idx ~= nil and spec_name ~= nil then
			if debug_print == true then CooldownTracker:Print("API Success: ".. spec_idx .. " " .. spec_name) end
			CooldownTracker:SendMessage("CDT_API_LOADED")
		elseif attempts < max_attempts then
			if debug_print == true then CooldownTracker:Print("API: trying again in 1 sec") end
			C_Timer.After(1,checkAPI)
		else
			error("API prob didn't load in time?")
			return false
		end
    end
	checkAPI()
	-- return spec_idx, spec_name
end

-- This is just a clock. Note that it's actually always running; I think that
--   that is alright.
function CooldownTracker:ClockTick()
	CooldownTracker:SendMessage("CDT_TICK")
	if not(self.paused) then -- eh, redundant, but okay.
		C_Timer.After(db.tick_frequency, function() CooldownTracker:ClockTick() end)
	end
end

function CooldownTracker:OnEnable()
    -- Called when the addon is enabled
    if debug_print == true then CooldownTracker:Print("CooldownTracker Enabled!") end

    CooldownTracker:SendMessage("CDT_ENABLE")
	CooldownTracker:SendMessage("CDT_UNPAUSE")
end

function CooldownTracker:OnDisable()
    -- Called when the addon is disabled
    if debug_print == true then CooldownTracker:Print("CooldownTracker Disabled!") end

    CooldownTracker:SendMessage("CDT_DISABLE")
	CooldownTracker:SendMessage("CDT_PAUSE")
end

-- I'm not sure if I need these defined(?). So doing it to be safe.
function CooldownTracker:Enable()
    CooldownTracker:OnEnable()
end

function CooldownTracker:Disable()
    CooldownTracker:OnDisable()
end

-------------------------------------------------------------------------------
-- ========================================================================= --
-- Event-fired message functions.
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:CDT_TICK()
	-- CooldownTracker:Print("Tick..")
	
    -- Semi-submodules
    CooldownTracker:UIManager_OnTick()
    CooldownTracker:SpellManager_OnTick()
end

function CooldownTracker:CDT_PAUSE()
	if not(self.paused) then
		self.paused = true
	end

    -- Semi-submodules
    CooldownTracker:UIManager_OnPause()
    CooldownTracker:SpellManager_OnPause()
end

function CooldownTracker:CDT_UNPAUSE()
	if self.paused then
		self.paused = false
		CooldownTracker:ClockTick()
	end

    -- Semi-submodules
    CooldownTracker:UIManager_OnUnpause()
    CooldownTracker:SpellManager_OnUnpause()
end

function CooldownTracker:CDT_ENABLE()
	-- Do nothing

    -- Semi-submodules
    CooldownTracker:UIManager_OnEnable()
    CooldownTracker:SpellManager_OnEnable()
end

function CooldownTracker:CDT_DISABLE()
	-- Do nothing

    -- Semi-submodules
    CooldownTracker:UIManager_OnDisable()
    CooldownTracker:SpellManager_OnDisable()
end

function CooldownTracker:OnStartup_Delayed()
    -- Registered to CDT_API_LOADED message
	if debug_print == true then CooldownTracker:Print("OnStartup_Delayed") end

    CooldownTracker:UIManager_StartupDelayed()
    CooldownTracker:SpellManager_StartupDelayed()

    -- After the other functions because otherwise the spell_list and 
    --   blacklist tables are empty when the options are drawn.
    CooldownTracker:RefreshOptions()

	-- Start the clock
	CooldownTracker:ClockTick()
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- Stuff after here really is just for debugging and are definite candidates
--   for removal.
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:CDT_SlashProcessorFunc(input)
	if input == "print" then
        print("spell_list: ")
        CooldownTracker:printTable(CooldownTracker:GetSpellList())
    elseif input == "print_saved_table" then
        print("CooldownTrackerDB: ")
        CooldownTracker:printTable(CooldownTrackerDB)
    -- elseif input == "load" then
    --     load_table("spell_list_all")
    -- elseif input == "load blacklist" then
    --     load_table("blacklist")
    elseif input == "reset" then
        CooldownTracker:ResetSpellNumbers()
    elseif input == "hard reset" then
        CooldownTracker:HardResetTables()
    elseif input == "table reload" then
        CooldownTracker:LoadTables()
    elseif input == "redraw" then
        CooldownTracker:RedrawDisplay()
    -- elseif input == "sort cd" then
    --     sort_table("cd")
    -- elseif input == "sort name" then
    --     sort_table("name")
    -- elseif input == "sort id" then
    --     sort_table("spell id")
    elseif input == "learning_mode true" then
        db.learning_mode = true
    elseif input == "learning_mode false" then
        db.learning_mode = false
    elseif input == "validate" then
        CooldownTracker:ValidateSpellTable()
	elseif input == "pause" then
		CooldownTracker:SendMessage("CDT_PAUSE")
	elseif input == "unpause" then
		CooldownTracker:SendMessage("CDT_UNPAUSE")
	elseif input == "options_update" then
		CooldownTracker:RefreshOptions()
    -- elseif input == "other" then
    --     function_of_the_day()
    else
        print("Unknown slash command: ",input)
    end
end

function CooldownTracker:printTable(t, indent)
	local function printTable_index(t, indent)
		indent = indent or 0
		if t ~= nil then
			for i,entry in ipairs(t) do
				if type(entry) == "table" then
					print(string.rep("  ", indent) .. i .. ":")
					CooldownTracker:printTable(entry,indent+1)
				else
					print(string.rep("  ", indent) .. i .. ": " .. tostring(entry))
				end
			end
		else
			print("nil")
		end
	end
	
	local function printTable_keys(t, indent)
		indent = indent or 0
		if t ~= nil then
			for k,entry in pairs(t) do
				if type(entry) == "table" then
					print(string.rep("  ", indent) .. k .. ":")
					CooldownTracker:printTable(entry,indent+1)
				else
					print(string.rep("  ", indent) .. k .. ": " .. tostring(entry))
				end
			end
		else
			print("nil")
		end
	end

    indent = indent or 0
    if t ~= nil then
		if CooldownTracker:hasNonIndexKeys(t) then
			printTable_keys(t,indent) 
		else
			printTable_index(t,indent)
		end
    else
        print("nil")
    end
end