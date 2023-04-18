-- Next steps: 
--   Options UI displays blacklisted spells.
--   Options UI blacklist by Spell ID.
--   Options UI whitelist spells.
--   Main frame reset button.
--   Way to make Missed Uses text red only for a particular row.

-- Create a new frame named 'CooldownTrackerFrame' with a size of 300x400
local cooldownFrame = CreateFrame("Frame", "CooldownTrackerFrame", UIParent, "BackdropTemplate")
cooldownFrame:SetSize(300, 400)
-- Position the frame 10 pixels from the left of the screen
cooldownFrame:SetPoint("LEFT", 10, 0)
-- Set the backdrop of the frame
cooldownFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
-- Set the background color of the frame to black
cooldownFrame:SetBackdropColor(0, 0, 0, 1)
-- Show the frame initially
cooldownFrame:Show()

-- Add a reset button to the bottom.
if true then
    -- Create a new frame for the button
    local resetButtonFrame = CreateFrame("Frame", "resetButtonFrame", cooldownFrame)
    resetButtonFrame:SetSize(150, 30)
    resetButtonFrame:SetPoint("BOTTOMLEFT", cooldownFrame, "BOTTOMLEFT", 5, 10)

    -- Create the button and add it to the frame
    local resetButton = CreateFrame("Button", "resetButton", resetButtonFrame, "UIPanelButtonTemplate")
    resetButton:SetPoint("CENTER", resetButtonFrame, "CENTER", 0, 0)
    resetButton:SetSize(140, 22)
    resetButton:SetText("Reset Spell Numbers")

    -- Set the click handler for the button
    resetButton:SetScript("OnClick", function()
        reset_spell_numbers()
    end)
end

-- Add a "pause" button to the bottom as well.
local is_running = true
if true then
    -- Create a new frame for the button
    local pauseButtonFrame = CreateFrame("Frame", "pauseButtonFrame", cooldownFrame)
    pauseButtonFrame:SetSize(150, 30)
    pauseButtonFrame:SetPoint("BOTTOMRIGHT", cooldownFrame, "BOTTOMRIGHT", -5, 10)

    -- Create the button and add it to the frame
    local pauseButton = CreateFrame("Button", "pauseButton", pauseButtonFrame, "UIPanelButtonTemplate")
    pauseButton:SetPoint("CENTER", pauseButtonFrame, "CENTER", 0, 0)
    pauseButton:SetSize(140, 22)
    pauseButton:SetText("Pause Addon")

    -- Set the click handler for the button
    pauseButton:SetScript("OnClick", function()
        toggle_ticking()
    end)
end

-- Create a new font string named 'spNameText' inside 'cooldownFrame'
local spNameText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- spell name 
local spcdText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- spell cooldown (max cd)
local spluText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- spell last used (seconds ago)
local mcText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- missed uses (turns red when it hits 2)
-- Set the position of 'spNameText' relative to the top left corner of 'cooldownFrame'
spNameText:SetPoint("TOPLEFT", 20, -20)
spcdText:SetPoint("TOPLEFT", 140, -20) -- Depends on the width you set below I think
spluText:SetPoint("TOPLEFT", 180, -20) -- Depends on the width you set below I think
mcText:SetPoint("TOPLEFT", 220, -20) -- Depends on the width you set below I think
-- Set the horizontal alignment of the text to the left
spNameText:SetJustifyH("LEFT")
spcdText:SetJustifyH("RIGHT")
spluText:SetJustifyH("RIGHT")
mcText:SetJustifyH("RIGHT")
-- Set the vertical alignment of the text to the top
spNameText:SetJustifyV("TOP")
spcdText:SetJustifyV("TOP")
spluText:SetJustifyV("TOP")
mcText:SetJustifyV("TOP")
-- Set the width and height of 'spNameText'
spNameText:SetWidth(120)
spNameText:SetHeight(360)

spcdText:SetWidth(40)
spcdText:SetHeight(360)

spluText:SetWidth(40)
spluText:SetHeight(360)

mcText:SetWidth(40)
mcText:SetHeight(360)

-- A "total missed casts" text box might be useful, but not necessary atm.


-- Some initialization.
spNameText:SetText("") -- Could probably just do it in the constructor, but why take chances?
local lastUseTime_default = 0
local tableTextStr = ""
local track_threshold = 30
local learning_mode = true


-- local sl = {} -- Table to store filtered spells
-- local bl = {} -- Table to store spells to ignore (e.g. Revive Battle Pets)

local initialized = 0


function save_spelllist()
    -- Save the bs table to the SavedVariables file
    local addonName = "CooldownTracker"
    local savedVariables = _G[addonName.."DB"] or {[UnitClass("player")]={}}
    savedVariables[UnitClass("player")].saved_spells = monitoredSpells
    _G[addonName.."DB"] = savedVariables
end

function save_blacklist()
    -- Save the bs table to the SavedVariables file
    local addonName = "CooldownTracker"
    local savedVariables = _G[addonName.."DB"] or {}
    savedVariables.nixed_spells = blacklist
    _G[addonName.."DB"] = savedVariables
end

function save_options()
    -- Save the bs table to the SavedVariables file
    local addonName = "CooldownTracker"
    local savedVariables = _G[addonName.."DB"] or {}
    savedVariables.cdt_options = cdt_opts
    _G[addonName.."DB"] = savedVariables
end

function save_to_file()
    save_spelllist()
    save_blacklist()
    save_options()
end


local function addon_loaded()
    load_table("monitoredSpells")
    load_table("blacklist")
    load_table("cdt_options")

    CreateOptionsPanel()
end

local function startup()
    spec_idx = GetSpecialization()
    _,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)
    if spec_idx == nil or spec_name == nil then
        C_Timer.After(1,startup)
    else
        addon_loaded()
    end
end




-- ========================================================================





-- ========================================================================
function load_table(table_name)
    if table_name == "monitoredSpells" then
        spec_idx = GetSpecialization()
        _,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)

        print("Spec name: ",spec_name)
        -- Initialize if needed.
        if not monitoredSpells then
            monitoredSpells = {}
        end

        -- Initialize the table and subtable if they don't exist.
        if CooldownTrackerDB == nil then
            print("CooldownTrackerDB nil")
            CooldownTrackerDB = {}
        end
        if CooldownTrackerDB[UnitClass("player")] == nil then
            print("CooldownTrackerDB[UnitClass(\"Player\")] nil")
            CooldownTrackerDB[UnitClass("player")] = {}
        end

        if CooldownTrackerDB[UnitClass("player")][spec_name] == nil then
            print("CooldownTrackerDB[UnitClass(\"Player\")][spec_name] nil")
            print("spec_name = ",spec_name)
            CooldownTrackerDB[UnitClass("player")][spec_name] = {}
        end

        if CooldownTrackerDB[UnitClass("player")][spec_name].saved_spells == nil then
            print("CooldownTrackerDB[UnitClass(\"Player\")][spec_name].saved spells nil")
            CooldownTrackerDB[UnitClass("player")][spec_name].saved_spells = {}
        end

        -- Load the monitoredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB[UnitClass("player")] then
            -- This seems to act like a pointer? I don't get it to be honest.
            monitoredSpells = CooldownTrackerDB[UnitClass("player")][spec_name].saved_spells
            if monitoredSpells == nil then 
                monitoredSpells = {}
            end
        end
        initialized = 1
    elseif table_name == "blacklist" then
        -- Initialize if needed.
        if not blacklist then
            blacklist = {}
        end

        -- Initialize table and subtable if they don't exist.
        if CooldownTrackerDB == nil then
            CooldownTrackerDB = {}
        end
        if CooldownTrackerDB.nixed_spells == nil then 
            CooldownTrackerDB.nixed_spells = {}
        end

        -- Load the monitoredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB.nixed_spells then
            blacklist = CooldownTrackerDB.nixed_spells
        end
    elseif table_name == "cdt_options" then
        -- Initialize if needed.
        if not cdt_opts then
            cdt_opts = {sort_method="cooldown"}
        end

        -- Initialize table and subtable if they don't exist.
        if CooldownTrackerDB == nil then
            CooldownTrackerDB = {}
        end
        if CooldownTrackerDB.cdt_options == nil then 
            CooldownTrackerDB.cdt_options = {}
        end

        -- Load the monitoredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB.cdt_options then
            cdt_opts = CooldownTrackerDB.cdt_options
        end
    end
    print("Loaded table ",table_name)
end

function printTable(t, indent)
    indent = indent or 0
    if t ~= nil then
        for k,v in pairs(t) do
            if type(v) == "table" then
                print(string.rep("  ", indent) .. k .. ":")
                printTable(v, indent + 1)
            else
                print(string.rep("  ", indent) .. k .. ": " .. tostring(v))
            end
        end
    else
        print("nil")
    end
end

-- Slash command function
local function slashCommandHandler(msg)
    if msg == "print" then
        print("monitoredSpells: ")
        printTable(monitoredSpells)
    elseif msg == "print_saved_table" then
        print("CooldownTrackerDB: ")
        printTable(CooldownTrackerDB)
    elseif msg == "load" then
        load_table("monitoredSpells")
    elseif msg == "load blacklist" then
        load_table("blacklist")
    elseif msg == "reset" then
        reset_spell_numbers()
    elseif msg == "hard reset" then
        hard_reset_table()
    elseif msg == "sort cd" then
        sort_table("cd")
    elseif msg == "sort name" then
        sort_table("name")
    elseif msg == "sort id" then
        sort_table("spell id")
    elseif msg == "learning_mode true" then
        learning_mode = true
    elseif msg == "learning_mode false" then
        learning_mode = false
    elseif msg == "validate" then
        validate_table_for_known_spells()
    else
        print("Unknown slash command: ",msg)
    end
end

-- Checks that GetSpecialization returns a non-nil value before loading tables.
startup()

-- Register the slash command
SLASH_CDT1 = "/cdt"
SlashCmdList["CDT"] = slashCommandHandler


-- =========================================================================
local printit = true
-- Runs on startup only. Iterates over all spells, adding only spells with a 
--   cd greater than <threshold> seconds to the table.
local function get_all_spells_with_cd_over_threshold()
    -- print("In a function of my own making.")
    for i = 1,GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        
        for j = 1, numSpells do
            local spellName = GetSpellBookItemName(j + offset, BOOKTYPE_SPELL)

            -- local spellID = select(2, GetSpellBookItemInfo(spellName, BOOKTYPE_SPELL))
            -- print(spellID)
            -- local spellName, _, spellIcon = GetSpellInfo(spellID)
            local spellName, _, spellIcon, _, _, _, spellID = GetSpellInfo(spellName)

            local is_in_blacklist = 0
            for k,v in pairs(blacklist) do
                if spellID == k then is_in_blacklist = 1 end
            end            

            local is_in_table = 0
            for k,v in pairs(monitoredSpells) do
                if spellID == v.spellID then is_in_table = 1 end
            end

            if not spellID then 
                -- print("Not Spell ID: ",spellID)
                -- If spellID isn't valid then do nothing, else keep running.
            elseif is_in_blacklist == 1 then
                -- print("Blacklisted spell.")
                -- If it's in the blacklist, don't add it to the table.
            elseif is_in_table == 1 then
                -- It's in the table; don't re-add it.
            else
                local start, duration, enabled = GetSpellCooldown(spellID)
                if duration and duration >= track_threshold then
                    -- print("Yes: ",spellName)
                    -- Assuming it's an offensive spell until told otherwise.
                    -- is_known is probably how I'll handle different talent sets? Upon talent set swap it goes through the list and hides any spells not known.
                    table.insert(monitoredSpells,{spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spellIcon=spellIcon, classification="offensive", is_known=true})
                else
                    -- print("No:  ",spellName)
                end
            end
        end
    end
    save_to_file()
end

function validate_table_for_known_spells()
    if initialized == 0 then return end
    for k,spellData in pairs(monitoredSpells) do
        is_known_new = IsSpellKnown(spellData.spellID)
        spellData.is_known = is_known_new
    end
end

-- Remove spells in the blacklist from monitoredSpells
function blacklist_cleanse()
    print("Before: ")
    printTable(monitoredSpells)
    for k,v in pairs(monitoredSpells) do
        if blacklist[k] ~= nil then
            print("Removing from monitored spells: ",k,": ",monitoredSpells[k].spellName)
            monitoredSpells[k] = nil
        end
    end
    print("After: ")
    printTable(monitoredSpells)

    save_to_file()
end

function add_to_blacklist(name_to_blacklist)
    print("Adding ",name_to_blacklist," to blacklist.")
    for i = 1,GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        
        for j = 1, numSpells do
            local spellName = GetSpellBookItemName(j + offset, BOOKTYPE_SPELL)
            local spellName, _, spellIcon, _, _, _, spellID = GetSpellInfo(spellName)

            if spellName == name_to_blacklist then
                blacklist[spellID] = {spellID=spellID,spellName=spellName,spellIcon=spellIcon}
            end
        end
    end
    print("New blacklist: ")
    printTable(blacklist)
    print("Cleansing with new blacklist.")
    blacklist_cleanse()
end

-- Function to update the display text of 'spNameText'
local function updateTableText()
    -- print("Tock: updateTableText")
    if not monitoredSpells then return end

    -- Clear the current text
    spNameText:SetText(string.format("|cFFFFFFFFSpell Name|r\n"))
    spcdText:SetText(string.format("|cFFFFFFFFCD|r\n"))
    spluText:SetText(string.format("|cFFFFFFFFSLU|r\n"))
    mcText:SetText(string.format("|cFFFFFFFFMC|r\n"))

    -- This might should be its own table but for now it's not.
    local defensive_spells = {}
    local crowd_control_spells = {}

    -- Iterate over the filtered spells and add them to the text
    for k, spellData in pairs(monitoredSpells) do
        -- Only need to check if it's known here because the defensive_spells and crowd_control_spells tables are set here.
        --   If that changes, then you'll have to add the logic below.
        if spellData.is_known == true then
            if spellData.classification == "defensive" then
                table.insert(defensive_spells,spellData)
            elseif spellData.classification == "crowd_control" then
                table.insert(crowd_control_spells,spellData)
            else
                -- Add the formatted line to the previous lines.
                local sp_prev = spNameText:GetText()
                local cd_prev = spcdText:GetText()
                local lu_prev = spluText:GetText()
                local mc_prev = mcText:GetText()

                local sinceLastUsed = GetTime() - spellData.lastUsed
                local mc = sinceLastUsed / spellData.cooldown
                local make_red = false
                local make_orange = false
                if mc >= 2 then
                    make_red = true
                end
                if mc >= 1 then
                    make_orange = true
                end

                spNameText:SetText(sp_prev .. spellData.spellName .. "\n")
                spcdText:SetText(cd_prev .. string.format("%d",spellData.cooldown) .. "\n")
                spluText:SetText(lu_prev .. string.format("%d",sinceLastUsed) .. "\n")
                if make_red == true then 
                    mcText:SetText(mc_prev .. string.format("|cFFFF0000%d|r",mc) .. "\n")
                elseif make_orange == true then
                    mcText:SetText(mc_prev .. string.format("|cFFFFA500%d|r",mc) .. "\n")
                else
                    mcText:SetText(mc_prev .. string.format("%d",mc) .. "\n")
                end
            end
        end
    end

    if #defensive_spells > 0 then
        local sp_prev = spNameText:GetText()
        local cd_prev = spcdText:GetText()
        local lu_prev = spluText:GetText()
        local mc_prev = mcText:GetText()

        spNameText:SetText(sp_prev .. string.format("\n\n|cFFFFFFFFDefensive Spells|r\n"))
        spcdText:SetText(cd_prev .. string.format("\n\n|cFFFFFFFFCD|r\n"))
        spluText:SetText(lu_prev .. string.format("\n\n|cFFFFFFFFSLU|r\n"))
        mcText:SetText(mc_prev .. string.format("\n\n|cFFFFFFFFMC|r\n"))

        for k, spellData in pairs(defensive_spells) do
            if false then
                -- Nothing but it looks symmetrical this way 
            else
                -- Add the formatted line to the previous lines.
                local sp_prev = spNameText:GetText()
                local cd_prev = spcdText:GetText()
                local lu_prev = spluText:GetText()
                local mc_prev = mcText:GetText()

                local sinceLastUsed = GetTime() - spellData.lastUsed
                local mc = sinceLastUsed / spellData.cooldown
                local make_red = false
                local make_orange = false
                if mc >= 2 then
                    make_red = true
                end
                if mc >= 1 then
                    make_orange = true
                end

                spNameText:SetText(sp_prev .. spellData.spellName .. "\n")
                spcdText:SetText(cd_prev .. string.format("%d",spellData.cooldown) .. "\n")
                spluText:SetText(lu_prev .. string.format("%d",sinceLastUsed) .. "\n")
                if make_red == true then 
                    mcText:SetText(mc_prev .. string.format("|cFFFF0000%d|r",mc) .. "\n")
                elseif make_orange == true then
                    mcText:SetText(mc_prev .. string.format("|cFFFFA500%d|r",mc) .. "\n")
                else
                    mcText:SetText(mc_prev .. string.format("%d",mc) .. "\n")
                end
            end
        end
    end

    if #crowd_control_spells > 0 then
        local sp_prev = spNameText:GetText()
        local cd_prev = spcdText:GetText()
        local lu_prev = spluText:GetText()
        local mc_prev = mcText:GetText()

        spNameText:SetText(sp_prev .. string.format("\n\n|cFFFFFFFFUtility Spells|r\n"))
        spcdText:SetText(cd_prev .. string.format("\n\n|cFFFFFFFFCD|r\n"))
        spluText:SetText(lu_prev .. string.format("\n\n|cFFFFFFFFSLU|r\n"))
        mcText:SetText(mc_prev .. string.format("\n\n|cFFFFFFFFMC|r\n"))

        for k, spellData in pairs(crowd_control_spells) do
            if false then 
                -- Nothing but it looks symmetrical this way
            else
                -- Add the formatted line to the previous lines.
                local sp_prev = spNameText:GetText()
                local cd_prev = spcdText:GetText()
                local lu_prev = spluText:GetText()
                local mc_prev = mcText:GetText()

                local sinceLastUsed = GetTime() - spellData.lastUsed
                local mc = sinceLastUsed / spellData.cooldown
                local make_red = false
                local make_orange = false
                if mc >= 2 then
                    make_red = true
                end
                if mc >= 1 then
                    make_orange = true
                end

                spNameText:SetText(sp_prev .. spellData.spellName .. "\n")
                spcdText:SetText(cd_prev .. string.format("%d",spellData.cooldown) .. "\n")
                spluText:SetText(lu_prev .. string.format("%d",sinceLastUsed) .. "\n")
                if make_red == true then 
                    mcText:SetText(mc_prev .. string.format("|cFFFF0000%d|r",mc) .. "\n")
                elseif make_orange == true then
                    mcText:SetText(mc_prev .. string.format("|cFFFFA500%d|r",mc) .. "\n")
                else
                    mcText:SetText(mc_prev .. string.format("%d",mc) .. "\n")
                end
            end
        end
    end
end



-- Function to update spell cooldowns
function updateCooldowns()
    -- print("Tock: updateCooldowns")
    if not monitoredSpells then return end

    for _, spellData in pairs(monitoredSpells) do        
        local spellName, _, spellIcon, spellCooldown = GetSpellInfo(spellData.spellID)
        local start, duration, enabled = GetSpellCooldown(spellData.spellID)

        -- If the spell is on cooldown and its cooldown is longer than 30 seconds
        if start ~= nil and duration > 1.5 and duration >= track_threshold then
            -- Store the spell data in the monitoredSpells table
            -- monitoredSpells[spellData.spellID].lastUsed = start -- GetTime() - start
            spellData.lastUsed = start
        end
    end
end

function reset_spell_numbers()
    t_reset = GetTime()
    for k,v in pairs(monitoredSpells) do
        v.lastUsed = t_reset
    end
    updateTableText()
end

function hard_reset_table()
    monitoredSpells = {}
end

function compare_by_cd(a,b)
    return a.cooldown < b.cooldown
end

function compare_by_name(a,b)
    return a.spellName < b.spellName
end

function compare_by_spell_id(a,b)
    return a.spellID < b.spellID
end

function pairsByKeys (table_to_sort, function_to_sort)
    -- function to sort is optional
    local a = {} -- temporary table 
    for k,v in pairs(table_to_sort) do table.insert(a, v) end
    table.sort(a, function_to_sort)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
      i = i + 1
      if a[i] == nil then return nil
      else return a[i], table_to_sort[a[i]]
      end
    end
    return iter
end

function sort_table(method)
    -- print("Sorting by: |",method,"|")
    -- print("-----------")
    -- print("Before: ")
    -- printTable(monitoredSpells)
    if method == "name" then
        table.sort(monitoredSpells,compare_by_name)
    elseif method == "cd" then
        table.sort(monitoredSpells,compare_by_cd)
        -- for name,line in pairsByKeys(monitoredSpells,compare_by_cd) do
        --     print("Name: ",name,"Line: ",line)
        --     --printTable(line)
        -- end
    elseif method == "spell id" then
        table.sort(monitoredSpells,compare_by_spell_id)
    else
        print("Unknown sort method ",method)
    end
    -- print("-----------")
    -- print("After: ")
    -- printTable(monitoredSpells)
    -- print("-----------")
end

local function onTick()
    if is_running ~= nil then
        if is_running == false then 
            return 
        else
            -- Else we are still running. 
        end
    end
    -- print("Tick: ",GetTime())
    if learning_mode == true then
        get_all_spells_with_cd_over_threshold()
    end
    updateCooldowns()
    updateTableText()
    C_Timer.After(0.5, onTick)
end

local function onTick_init()
    -- Check every second if we're initialized. Once we are, 
    --   wait 2 seconds (probably overkill) then start up.
    if initialized == 0 then
        C_Timer.After(1,onTick_init)
    else
        C_Timer.After(2,onTick)
    end
end

function toggle_ticking()
    is_running = not(is_running)

    if is_running == true then
        -- if we're unpausing it 
        pauseButton:SetText("Pause Addon")
        onTick()
    elseif is_running == false then
        pauseButton:SetText("Unpause Addon")
    end
end

-- Call 'onTick' once to start the timer
onTick_init()


-- Event handler for PLAYER_LOGIN event
local function onPlayerLogin()
    if initialized == 1 then
        get_all_spells_with_cd_over_threshold()
        --filterSpellsWithCooldownGreaterThan30()
        updateTableText()
    else
        C_Timer.After(0.5,onPlayerLogin)
    end
end

-- Event handler for SPELL_UPDATE_COOLDOWN event
local function onSpellUpdateCooldown()
    --filterSpellsWithCooldownGreaterThan30()
    -- updateTableText()
end

-- Register the event handlers
cooldownFrame:RegisterEvent("PLAYER_LOGIN")
cooldownFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
cooldownFrame:RegisterEvent("TRAIT_TREE_CHANGED")
--cooldownFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
--cooldownFrame:RegisterEvent("PLAYER_TALENT_UPDATE")


-- Set the script for the OnEvent event of 'cooldownFrame'
cooldownFrame:SetScript("OnEvent", function(self, event, ...)
    -- Call the appropriate event handler based on the event that occurred
    if event == "PLAYER_LOGIN" then
        onPlayerLogin(...)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        onSpellUpdateCooldown(...)
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        load_table("monitoredSpells")
        validate_table_for_known_spells()
    elseif event == "TRAIT_TREE_CHANGED" then 
        -- It takes 5 seconds to change talents, so wait to do the validation.
        C_Timer.After(6,validate_table_for_known_spells)
    else
        print("Event: ",event)
    end
end)



local function allow_frame_movement(bool_val)
    cooldownFrame:SetMovable(true)
    cooldownFrame:EnableMouse(true)
    cooldownFrame:SetScript("OnMouseDown",function(self, button)
        if button == "LeftButton" then 
            self:StartMoving()
        end
    end)
    cooldownFrame:SetScript("OnMouseUp",function(self,button)
        self:StopMovingOrSizing()
    end)
end
allow_frame_movement(true)

-- ============================================================================
-- ============================================================================
end
end)