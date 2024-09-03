-- Thanks to the creator of HandyNotes whose LUA I adapted to help me with this. Blame any bad coding on me, though.

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


-- === My crappy coding
local paused = false
local debug_print = true



local the_time = 0

local rows = {}
local n_rows = 0

local classification_options_to_str = {}
classification_options_to_str["offensive"] ="Offensive"
classification_options_to_str["defensive"] ="Defensive"
classification_options_to_str["utility"] ="Utility"

function CooldownTracker:hasNonIndexKeys(tbl)
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or k > #tbl then
            return true
        end
    end
    return false
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



-- === End my crappy coding

---------------------------------------------------------
-- Localize some globals
local floor, min, max = floor, math.min, math.max
local pairs, next, type = pairs, next, type
local CreateFrame = CreateFrame
local Minimap = Minimap



---------------------------------------------------------
-- xpcall safecall implementation
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function safecall(func, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnEnter OnLeave etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return xpcall(func, errorhandler, ...)
	end
end


---------------------------------------------------------
-- CooldownTracker options table
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
					CooldownTracker:UpdateDisplay()
				else
					CooldownTracker:UpdateDisplay()
				end
			end,
			disabled = function() return not db.enabled end,
			args = {
				desc = {
					name = L["These settings control the execution of CooldownTracker globally."],
					type = "description",
					order = 0,
				},
                learning_mode = {
                    type = "toggle",
                    arg = "learning_mode",
                    name = L["CooldownTracker learning mode."],
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
			-- get = function(info) return db[info.arg] end,
			-- set = function(info, v)
			-- 	local arg = info.arg
			-- 	db[arg] = v
			-- 	if arg == "track_threshold_min" or arg == "track_threshold_max" then
			-- 		CooldownTracker:UpdateDisplay()
			-- 	else
			-- 		CooldownTracker:UpdateDisplay()
			-- 	end
			-- end,
			disabled = function() return not db.enabled end,
			args = {
				spell_list={type="group",name="Spell List",args={},order=10},
				blacklist={type="group",name="Blacklist",args={},order=20},
			},
		},
	},
}


-- Table entry structure:
--   {spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true, has_charges=has_charges, max_charges=max_charges}
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
	CooldownTracker:Print("Refresh Options")
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


---------------------------------------------------------
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
        reset_spell_numbers()
    elseif input == "hard reset" then
        hard_reset_table()
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
	elseif input == "options_print" then
		CooldownTracker:Print("Print Options")
		CooldownTracker:printTable(options.args.spell_list)
    -- elseif input == "other" then
    --     function_of_the_day()
	elseif input == "print2" then
		for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
			local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
			for j = offset+1, offset+numSlots do
				local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(j, Enum.SpellBookSpellBank.Player)
				local spellType, id, passive = spellBookItemInfo.itemType, spellBookItemInfo.actionID, spellBookItemInfo.isPassive
				local spellName
				if spellType == Enum.SpellBookItemType.Spell then
					spellName = C_Spell.GetSpellName(id)
					spellType = "Spell"
				elseif spellType == Enum.SpellBookItemType.FutureSpell then
					spellName = C_Spell.GetSpellName(id)
					spellType = "Future Spell"
				elseif spellType == Enum.SpellBookItemType.Flyout then
					spellName = GetFlyoutInfo(id)
					spellType = "Flyout"
				end

				local passive_str = "(a)"
				if passive == true then passive_str = "(p)" end
				print(i, j, spellType, id, spellName, passive_str)
			end
		end
    else
        print("Unknown slash command: ",input)
    end
end


-- So it seems like I'll want to, in general, use self.db.class.saved_spells (the .class is the important part, rather than self.db.profile.saved_spells). You apparently can use all of "char", "realm", "class", "race", "faction", "factionrealm", "global" and "profile" at the same time. So I think something like the ".profile" one would be just for things like "minimap button size" and stuff like that. Honestly not really worth, but I'll leave it in for now and can cleanse it later.

function CooldownTracker:OnInitialize()
    CooldownTracker:Print("CooldownTracker Initialized!")

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

	-- I'm actually registering a clock.
	CooldownTracker:RegisterMessage("CDT_TICK")
	CooldownTracker:RegisterMessage("CDT_PAUSE")
	CooldownTracker:RegisterMessage("CDT_UNPAUSE")
	CooldownTracker:RegisterMessage("CDT_API_LOADED","OnStartup_Delayed")

	-- Sub-app initialize calls.
	CooldownTracker:SpellManager_OnInitialize()

	-- Make the frame and stuff
	CooldownTracker:ShowFrame(self.db.profile.enabled)

	-- Set up tables and stuff once we're likely to have loaded in. From 
	--   testing, a small delay is prudent.
	local function delayed_startup()
		CooldownTracker:WaitForAPI()
	end
	C_Timer.After(3,delayed_startup)

end
-- The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded by the game client. It's a good time to do things like restore saved settings (see the info on AceConfig for more notes about that).


-- This is just a clock. Note that it's actually always running; I think that
--   that is alright.
function Tick()
	CooldownTracker:SendMessage("CDT_TICK")
	if not(paused) then -- eh, redundant, but okay.
		C_Timer.After(db.tick_frequency, Tick)
	end
end

function CooldownTracker:OnEnable()
    -- Called when the addon is enabled
    CooldownTracker:Print("CooldownTracker Enabled!")

    if not db.enabled then
        self:Disable()
        return
    end
	CooldownTracker:SendMessage("CDT_UNPAUSE")
	CooldownTracker:ShowFrame(true)

    -- HandyNotes had a bunch of stuff to draw / stop drawing on the world map, which I'm not planning to do, so this is pretty empty.
    -- I will eventually, however, be drawing/undrawing my frame.
end

function CooldownTracker:OnDisable()
    -- Called when the addon is disabled
    CooldownTracker:Print("CooldownTracker Disabled!")
	CooldownTracker:SendMessage("CDT_PAUSE")
	CooldownTracker:ShowFrame(false)

    -- HandyNotes had a bunch of stuff to draw / stop drawing on the world map, which I'm not planning to do, so this is pretty empty.
    -- I will eventually, however, be drawing/undrawing my frame.
end

function CooldownTracker:OnProfileChanged(event, database, newProfileKey)
	db = database.profile
end

function CooldownTracker:UpdateDisplay()
    CooldownTracker:Print("Updating Display (NYI)")
end

function CooldownTracker:CDT_TICK()
	-- CooldownTracker:Print("Tick..")
	the_time = the_time + 1

	CooldownTracker:SpellManager_OnTick()


	CooldownTracker:UpdateTableText()
end

function CooldownTracker:CDT_PAUSE()
	if not(paused) then
		paused = true
	end
end

function CooldownTracker:CDT_UNPAUSE()
	if paused then
		paused = false
		Tick()
	end
end

function CooldownTracker:OnStartup_Delayed()
	CooldownTracker:Print("OnStartup_Delayed")
	CooldownTracker:RefreshOptions()

	CooldownTracker:SpellManager_StartupDelayed()
    CooldownTracker:UIManager_StartupDelayed()

	-- Start the clock
	C_Timer.After(db.tick_frequency, Tick)
end


function CooldownTracker:CDT_TalentChangeUpdate(args)
	if debug_print == true then CooldownTracker:Print("Talent tree changed.") end
	-- This may not be needed.
	CooldownTracker:LoadTables()
	-- This is likely needed.
	CooldownTracker:ValidateSpellTable()
	CooldownTracker:RefreshOptions()
	
    CooldownTracker:UpdateIcons(true)
end

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
			CooldownTracker:Print("API Success: ".. spec_idx .. " " .. spec_name)
			CooldownTracker:SendMessage("CDT_API_LOADED")
		elseif attempts < max_attempts then
			CooldownTracker:Print("API: trying again in 1 sec")
			C_Timer.After(1,checkAPI)
		else
			error("API prob didn't load in time?")
			return false
		end
    end
	checkAPI()
	-- return spec_idx, spec_name
end







