-- Next steps: 
--   Options UI blacklist by Spell ID.
--   Options UI whitelist spells.
--   Options in options pane:
--     tick frequency
--     tracking threshold
--   Resizing tracker window

local icon_file_id_to_path = {}
local periodic_save = true
local track_threshold = 30
local learning_mode = true
local str_max_disp_len = 17

-- Some initialization.
local initialized = 0

local debug_print = false
local debug_print_tab = {}

local n_rows = 0

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

local rows = {}
local update_icons = true

-- A "total missed casts" text box might be useful, but not necessary atm.

local classification_options_to_str = {}
classification_options_to_str["offensive"] ="Offensive"
classification_options_to_str["defensive"] ="Defensive"
classification_options_to_str["crowd_control"] ="Crowd Control"




function save_spelllist()
    -- Save the bs table to the SavedVariables file
    local addonName = "CooldownTracker"

    class_name = UnitClass("player")

    spec_idx = GetSpecialization()
    _,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)

    local savedVariables = _G[addonName.."DB"] or {[UnitClass("player")]={[spec_name]={}}}
    savedVariables[UnitClass("player")][spec_name].saved_spells = monitoredSpells
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

    -- I tried dofile and requrie and neither worked. So I modified the 
    --   ArtTextureID thing to be a global which feels bad but at least
    --   it works. 
    icon_file_id_to_path = _G["ArtTexturePaths"]
    if debug_print == true then print("CooldownTracker ready to go.") end
end

local function startup()
    spec_idx = GetSpecialization()
    if spec_idx ~= nil then
        _,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)
        if spec_name ~= nil then
            addon_loaded()
        else
            C_Timer.After(1,startup)
        end
    else
        C_Timer.After(1,startup)
    end
end


-- ========================================================================
-- ========================================================================
function load_table(table_name)
    if table_name == nil then table_name = "monitoredSpells" end

    if table_name == "monitoredSpells" then
        spec_idx = GetSpecialization()
        _,spec_name,_,spec_icon,_,_ = GetSpecializationInfo(spec_idx)

        if spec_name == nil then
            C_Timer.After(1,load_table)
            return
        end

        if debug_print == true then print("Spec name: ",spec_name) end
        -- Initialize if needed.
        if not monitoredSpells then
            monitoredSpells = {}
        end

        -- Initialize the table and subtable if they don't exist.
        if CooldownTrackerDB == nil then
            if debug_print == true then print("CooldownTrackerDB nil") end
            CooldownTrackerDB = {}
        end
        if CooldownTrackerDB[UnitClass("player")] == nil then
            if debug_print == true then print("CooldownTrackerDB[UnitClass(\"Player\")] nil") end
            CooldownTrackerDB[UnitClass("player")] = {}
        end

        if CooldownTrackerDB[UnitClass("player")][spec_name] == nil then
            if debug_print == true then 
                print("CooldownTrackerDB[UnitClass(\"Player\")][spec_name] nil")
                print("spec_name = ",spec_name)
            end
            CooldownTrackerDB[UnitClass("player")][spec_name] = {}
        end

        if CooldownTrackerDB[UnitClass("player")][spec_name].saved_spells == nil then
            if debug_print == true then print("CooldownTrackerDB[UnitClass(\"Player\")][spec_name].saved spells nil") end
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
    if debug_print == true then print("Loaded table ",table_name) end
end

function printTable(t, indent)
    indent = indent or 0
    if t ~= nil then
        for i,entry in ipairs(t) do
            if type(entry) == "table" then
                print(string.rep("  ", indent) .. i .. ":")
                printTable(entry, indent + 1)
            else
                print(string.rep("  ", indent) .. i .. ": " .. tostring(entry))
            end
        end
    else
        print("nil")
    end
end

function printTable_keys(t, indent)
    indent = indent or 0
    if t ~= nil then
        for k,entry in pairs(t) do
            if type(entry) == "table" then
                print(string.rep("  ", indent) .. k .. ":")
                printTable_keys(entry, indent + 1)
            else
                print(string.rep("  ", indent) .. k .. ": " .. tostring(entry))
            end
        end
    else
        print("nil")
    end
end

local function function_of_the_day()
    print("Length of rows: ",#rows)
    printTable_keys(rows)
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
    elseif msg == "other" then
        function_of_the_day()
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
-- Iterates over all spells, adding only spells with a 
--   cd greater than <threshold> seconds to the table.
-- Probably best it run only on startup but that won't work if users don't have
--   all the spells learned yet. So for now it's running every half-ish second.
local function get_all_spells_with_cd_over_threshold()
    for i = 1,GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        
        for j = 1, numSpells do
            local spellName = GetSpellBookItemName(j + offset, BOOKTYPE_SPELL)
            local spellName, _, spellIcon, _, _, _, spellID = GetSpellInfo(spellName)

            local is_in_blacklist = 0
            for i,entry in ipairs(blacklist) do
                if spellID == entry.spellID then is_in_blacklist = 1 end
            end            

            local is_in_table = 0
            for i,entry in ipairs(monitoredSpells) do
                if spellID == entry.spellID then is_in_table = 1 end
            end

            local spellIcon_filePath = nil
            if spellIcon ~= nil then 
                spellIcon_filePath = icon_file_id_to_path[spellIcon]
            end

            if not spellID then 
                -- If spellID isn't valid then do nothing, else keep running.
            elseif is_in_blacklist == 1 then
                -- If it's in the blacklist, don't add it to the table.
            elseif is_in_table == 1 then
                -- It's in the table; don't re-add it.
            else
                local start, duration, enabled = GetSpellCooldown(spellID)
                if duration and duration >= track_threshold then
                    -- Assuming it's an offensive spell until told otherwise.
                    -- is_known is probably how I'll handle different talent sets? Upon talent set swap it goes through the list and hides any spells not known.
                    table.insert(monitoredSpells,{spellID=spellID, spellName=spellName, cooldown=duration, lastUsed=-1, spelIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true})
                    sort_table("cd")
                    update_icons = true
                else
                    -- Do nothing.
                end
            end
        end
    end
    if periodic_save == false then save_to_file() end
end

function validate_table_for_known_spells()
    if initialized == 0 then return end
    for i,entry in ipairs(monitoredSpells) do
        is_known_new = IsSpellKnown(entry.spellID)
        entry.is_known = is_known_new
    end
    update_icons = true
end

-- Remove spells in the blacklist from monitoredSpells
function blacklist_cleanse()
    if debug_print == true then 
        print("Before: ")
        printTable(monitoredSpells)
    end
    -- Yes it's n-squared, sorry. But blacklist is probably short so 
    --   realistically it shouldn't be too bad I think?
    for ib,entryb in ipairs(blacklist) do
        for i,entry in ipairs(monitoredSpells) do        
            if entry.spellID == entryb.spellID then
                print("Removing from monitored spells: ",entry.spellID,": ",entry.spellName)
                table.remove(monitoredSpells,i)
            end
        end
    end
    if debug_print == true then 
        print("After: ")
        printTable(monitoredSpells)
    end

    if periodic_save == false then save_to_file() end
    update_icons = true
end

function blacklist_add_by_id(spellID)
    -- Check if it's already being monitored.
    local already_monitored = false
    for i, entry in ipairs(monitoredSpells) do
        if entry.spellID == spellID then
            -- Add to blacklist and remove from monitoredSpells
            table.insert(blacklist,entry)
            table.remove(monitoredSpells,i)
            already_monitored = true
        end
    end

    -- If it wasn't already monitored, preemptively add it with some barebones info.
    if already_monitored == false then
        local spellName, _, spellIcon, _, _, _,_, _ = GetSpellInfo(spellID)
        local spellIcon_filePath = nil
        if spellIcon ~= nil then 
            spellIcon_filePath = icon_file_id_to_path[spellIcon]
        end
        table.insert(blacklist,{spellID=spellID, spellName=spellName, cooldown=-1, lastUsed=-1, spellIcon=spellIcon, spellIcon_filePath=spellIcon_filePath, classification="offensive", is_known=true})
    end

    if debug_print == true then print("Cleansing with new blacklist.") end
    blacklist_cleanse()
    update_icons = true
end

function blacklist_remove_by_id(spellID)
    -- Only re-add it if it's a known spell.
    for i,entry in ipairs(blacklist) do
        if entry.spellID == spellID then
            if IsSpellKnown(spellID) == true then
                table.insert(monitoredSpells,entry)
                sort_table("cd")
            end
            table.remove(blacklist,i)
        end
    end
    update_icons = true
end

local function make_table_row(parent,y_offset)
    y_offset = y_offset or 0
    local y_size = 12
    local y_pad = 2
    local x_size_unit = 40
    local x_pad = 2
    -- Total width is icon width (y_size) plus spell name width (3x normal size)
    --   plus the cooldown, last-used, and missed casts widths (1x normal size) 
    --   plus padding for each.
    local x_size_total = y_size + 3*x_size_unit + x_pad + 3*(x_size_unit+x_pad)

    n_rows = n_rows+1
    local the_row = CreateFrame("Frame","row_"..n_rows,parent)
    the_row:SetSize(x_size_total,y_size)
    the_row:Show()

    -- First make the spell icon
    local x_offset = 20
    local the_icon = the_row:CreateTexture(nil,"ARTWORK")
    the_icon:SetSize(y_size,y_size)
    the_icon:SetPoint("LEFT",x_offset,0)
    the_icon:Show()
    x_offset = x_offset + y_size+x_pad

    -- Next, the strings
    local spName_str = the_row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local spCD_str = the_row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local spLU_str = the_row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local spMC_str = the_row:CreateFontString(nil,"OVERLAY","GameFontNormal")

    spName_str:SetPoint("LEFT",the_row,"LEFT",x_offset,0)
    spCD_str:SetPoint("LEFT",spName_str,"RIGHT",x_pad,0)
    spLU_str:SetPoint("LEFT",spCD_str,"RIGHT",x_pad,0)
    spMC_str:SetPoint("LEFT",spLU_str,"RIGHT",x_pad,0)

    spName_str:SetJustifyH("LEFT")
    spCD_str:SetJustifyH("RIGHT")
    spLU_str:SetJustifyH("RIGHT")
    spMC_str:SetJustifyH("RIGHT")

    spName_str:SetWidth(x_size_unit*3)
    spCD_str:SetWidth(x_size_unit)
    spLU_str:SetWidth(x_size_unit)
    spMC_str:SetWidth(x_size_unit)

    local row_container = {row=the_row,icon=the_icon,spName=spName_str,spCD=spCD_str,spLU=spLU_str,spMC=spMC_str}
    -- print("Row container: ",row_container)
    -- printTable_keys(row_container)
    -- print("Row: ",the_row)
    return row_container
end


-- Function to update the display text of 'spNameText'
local function updateTableText()
    if not monitoredSpells then return end

    -- This might should be its own table but for now it's not.
    local defensive_spells = {}
    local crowd_control_spells = {}

    local y_size = 12
    local y_pad = 4
    local y_offset = y_size

    -- Iterate over the filtered spells and add them to the text
    local title_row = nil
    -- print("rows.title_offensive = ",rows["title_offensive"])
    if rows["title_offensive"] == nil then
        title_row = make_table_row(cooldownFrame)
        title_row.spName:SetText(string.format("|cFFFFFFFFOffensive Spells|r"))
        title_row.spCD:SetText(string.format("|cFFFFFFFFCD|r"))
        title_row.spLU:SetText(string.format("|cFFFFFFFFLU|r"))
        title_row.spMC:SetText(string.format("|cFFFFFFFFMC|r"))
        rows["title_offensive"] = title_row
    else
        title_row = rows["title_offensive"]
    end
    
    title_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)
    y_offset = y_offset + y_size+y_pad

    for i, spellData in ipairs(monitoredSpells) do
        -- Only need to check if it's known here because the defensive_spells and crowd_control_spells tables are set here.
        --   If that changes, then you'll have to add the logic below.

        if spellData.is_known == true then
            if spellData.classification == "defensive" then
                table.insert(defensive_spells,spellData)
            elseif spellData.classification == "crowd_control" then
                table.insert(crowd_control_spells,spellData)
            else
                -- Get the table row. First check if it exists.
                local curr_row = nil
                if rows[spellData.spellID] == nil then
                    curr_row = make_table_row(cooldownFrame)
                    rows[spellData.spellID] = curr_row
                else
                    curr_row = rows[spellData.spellID]
                end
                curr_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)

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

                local spNameLen = string.len(spellData.spellName)
                local spNameStr = ""
                local mcStr = ""
                if spNameLen > str_max_disp_len then
                    local spNameStr_trunc = string.sub(spellData.spellName,1,str_max_disp_len-3)
                    spNameStr = string.format("%s...",spNameStr_trunc)
                else
                    spNameStr = spellData.spellName
                end
                if make_red == true then 
                    mcStr = string.format("|cFFFF0000%d|r",mc)
                elseif make_orange == true then
                    mcStr = string.format("|cFFFFA500%d|r",mc)
                else
                    mcStr = string.format("%d",mc)
                end

                if spellData.spellIcon_filePath ~= nil then
                    curr_row.icon:SetTexture(spellData.spellIcon_filePath)
                end
                curr_row.spName:SetText(spNameStr)
                curr_row.spCD:SetText(string.format("%d",spellData.cooldown))
                curr_row.spLU:SetText(string.format("%d",sinceLastUsed))
                curr_row.spMC:SetText(mcStr)
                
                y_offset = y_offset+y_size+y_pad
            end
        end
    end

    -- ======
    if #defensive_spells > 0 then
        y_offset = y_offset + 3*y_size

        local title_row = nil
        if rows["title_defensive"] == nil then
            title_row = make_table_row(cooldownFrame)
            title_row.spName:SetText(string.format("|cFFFFFFFFDefensive Spells|r"))
            title_row.spCD:SetText(string.format("|cFFFFFFFFCD|r"))
            title_row.spLU:SetText(string.format("|cFFFFFFFFLU|r"))
            title_row.spMC:SetText(string.format("|cFFFFFFFFMC|r"))
            rows["title_defensive"] = title_row
        else
            title_row = rows["title_defensive"]
        end

        title_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)
        y_offset = y_offset + y_size+y_pad
        -- print("Rect 2: ",title_row.row:GetRect())

        for i, spellData in ipairs(defensive_spells) do
            -- Only need to check if it's known here because the defensive_spells and crowd_control_spells tables are set here.
            --   If that changes, then you'll have to add the logic below.
            if spellData.is_known == true then
                -- Get the table row. First check if it exists.
                local curr_row = nil
                if rows[spellData.spellID] == nil then
                    curr_row = make_table_row(cooldownFrame)
                    rows[spellData.spellID] = curr_row
                else
                    curr_row = rows[spellData.spellID]
                end

                curr_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)

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

                local spNameLen = string.len(spellData.spellName)
                local spNameStr = ""
                if spNameLen > str_max_disp_len then
                    local spNameStr_trunc = string.sub(spellData.spellName,1,str_max_disp_len-3)
                    spNameStr = string.format("%s...",spNameStr_trunc)
                else
                    spNameStr = spellData.spellName
                end
                if make_red == true then 
                    mcStr = string.format("|cFFFF0000%d|r",mc)
                elseif make_orange == true then
                    mcStr = string.format("|cFFFFA500%d|r",mc)
                else
                    mcStr = string.format("%d",mc)
                end

                if spellData.spellIcon_filePath ~= nil then
                    curr_row.icon:SetTexture(spellData.spellIcon_filePath)
                end
                curr_row.spName:SetText(spNameStr)
                curr_row.spCD:SetText(string.format("%d",spellData.cooldown))
                curr_row.spLU:SetText(string.format("%d",sinceLastUsed))
                curr_row.spMC:SetText(mcStr)

                y_offset = y_offset+y_size+y_pad
            end
        end
    end

    if #crowd_control_spells > 0 then
        y_offset = y_offset + 3*y_size

        local title_row = nil
        if rows["title_crowd_control"] == nil then
            title_row = make_table_row(cooldownFrame)
            title_row.spName:SetText(string.format("|cFFFFFFFFUtility Spells|r"))
            title_row.spCD:SetText(string.format("|cFFFFFFFFCD|r"))
            title_row.spLU:SetText(string.format("|cFFFFFFFFLU|r"))
            title_row.spMC:SetText(string.format("|cFFFFFFFFMC|r"))
            rows["title_crowd_control"] = title_row
        else
            title_row = rows["title_crowd_control"]
        end

        title_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)
        y_offset = y_offset + y_size+y_pad
        -- print("Rect 3: ",title_row.row:GetRect())

        for i, spellData in ipairs(crowd_control_spells) do
            -- Only need to check if it's known here because the defensive_spells and crowd_control_spells tables are set here.
            --   If that changes, then you'll have to add the logic below.
            if spellData.is_known == true then
                -- Get the table row. First check if it exists.
                local curr_row = nil
                if rows[spellData.spellID] == nil then
                    curr_row = make_table_row(cooldownFrame)
                    rows[spellData.spellID] = curr_row
                else
                    curr_row = rows[spellData.spellID]
                end

                curr_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)

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

                local spNameLen = string.len(spellData.spellName)
                local spNameStr = ""
                if spNameLen > str_max_disp_len then
                    local spNameStr_trunc = string.sub(spellData.spellName,1,str_max_disp_len-3)
                    spNameStr = string.format("%s...",spNameStr_trunc)
                else
                    spNameStr = spellData.spellName
                end
                if make_red == true then 
                    mcStr = string.format("|cFFFF0000%d|r",mc)
                elseif make_orange == true then
                    mcStr = string.format("|cFFFFA500%d|r",mc)
                else
                    mcStr = string.format("%d",mc)
                end

                if spellData.spellIcon_filePath ~= nil then
                    curr_row.icon:SetTexture(spellData.spellIcon_filePath)
                end
                curr_row.spName:SetText(spNameStr)
                curr_row.spCD:SetText(string.format("%d",spellData.cooldown))
                curr_row.spLU:SetText(string.format("%d",sinceLastUsed))
                curr_row.spMC:SetText(mcStr)

                y_offset = y_offset+y_size+y_pad

            end
        end
    end
end


-- Function to update spell cooldowns
function updateCooldowns()
    if not monitoredSpells then return end

    for _, spellData in ipairs(monitoredSpells) do        
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
    for i,entry in ipairs(monitoredSpells) do
        entry.lastUsed = t_reset
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
    if debug_print == true then 
        print("Sorting by: |",method,"|")
        print("-----------")
        print("Before: ")
        printTable(monitoredSpells)
    end

    if method == "name" then
        table.sort(monitoredSpells,compare_by_name)
    elseif method == "cd" then
        table.sort(monitoredSpells,compare_by_cd)
    elseif method == "spell id" then
        table.sort(monitoredSpells,compare_by_spell_id)
    else
        print("Unknown sort method ",method)
    end

    update_icons = true
    
    if debug_print == true then 
        print("-----------")
        print("After: ")
        printTable(monitoredSpells)
        print("-----------")
    end
end

local function onTick()
    if is_running ~= nil then
        if is_running == false then 
            return 
        else
            -- Else we are still running. 
        end
    end
    if learning_mode == true then
        get_all_spells_with_cd_over_threshold()
    end
    updateCooldowns()
    updateTableText()

    if periodic_save == true then save_to_file() end
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
    if debug_print == true then
        print("This function (onSpellUpdateCooldown) is called but is empty.")
    end
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
        if debug_print == true then print("Event: ",event) end
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
-- ============================================================================


local CDTOptions = CreateFrame("Frame", "CooldownTrackerOptionsFrame", InterfaceOptionsFramePanelContainer)
CDTOptions.name = "CooldownTracker"

local function CDT_Draw_Options()
    local y_size = 24
    local y_pad = 8  -- this is a guess

    -- Clear the frame
    for i, child in ipairs({CDTOptions:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
      
    local CDTList = CreateFrame("ScrollFrame", "CooldownTrackerListFrame", CDTOptions, "UIPanelScrollFrameTemplate")
    CDTList:SetSize(CDTOptions:GetWidth()*0.95, CDTOptions:GetHeight()*2/3)
    CDTList:SetPoint("TOPLEFT", 0, 0)

    local CooldownTrackerListContent = CreateFrame("Frame", "CooldownTrackerListContentFrame", CDTList)
    CooldownTrackerListContent:SetSize(CDTList:GetSize())
    CDTList:SetScrollChild(CooldownTrackerListContent)

    -- Make some titles for the table up top
    local monitoredSpellsIconTitle = CooldownTrackerListContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitoredSpellsIconTitle:SetPoint("TOPLEFT", 0, 0)
    monitoredSpellsIconTitle:SetText("") -- I just want it invisible I think
    monitoredSpellsIconTitle:SetTextColor(1, 1, 1)
    monitoredSpellsIconTitle:SetSize(y_size,y_size)

    local monitoredSpellsTitle = CooldownTrackerListContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitoredSpellsTitle:SetPoint("LEFT", monitoredSpellsIconTitle, "RIGHT", 0, 0)
    monitoredSpellsTitle:SetText("Monitored Spells")
    monitoredSpellsTitle:SetTextColor(1, 1, 1)
    monitoredSpellsTitle:SetSize(120,y_size)

    local dropdownTitle = CooldownTrackerListContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdownTitle:SetPoint("LEFT", monitoredSpellsTitle, "RIGHT", 16, 0)
    dropdownTitle:SetText("Classification")
    dropdownTitle:SetTextColor(1, 1, 1)
    dropdownTitle:SetSize(140,y_size)

    local offset = 0
    for i, entry in ipairs(monitoredSpells) do
        local button = CreateFrame("Frame", "MyCDTEntry"..i, CooldownTrackerListContent)
        button:SetPoint("TOPLEFT", monitoredSpellsTitle, "BOTTOMLEFT", 0, -offset)
        button:SetSize(120, y_size)

        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buttonText:SetPoint("LEFT", button, "LEFT", 5, 0)
        buttonText:SetText(entry.spellName)
        -- buttonText:SetTextColor(1, 1, 1) -- Set the font color to white
        buttonText:SetWidth(120)
        buttonText:SetJustifyH("LEFT")

        if entry.spellIcon_filePath ~= nil then
            -- Create a frame to contain the texture.
            local temp_spell_icon = CreateFrame("Frame", "MyCDTIcon"..i, CooldownTrackerListContent)
            temp_spell_icon:SetSize(y_size*0.75,y_size*0.75) -- Set the frame size.
            temp_spell_icon:SetPoint("RIGHT", button, "LEFT", 0, 0)

            -- Create a texture object and set its properties.
            local tsi_texture = temp_spell_icon:CreateTexture(nil, "ARTWORK")
            tsi_texture:SetTexture(entry.spellIcon_filePath) -- Set the texture file path.
            -- tsi_texture:SetTexture
            tsi_texture:SetSize(y_size*0.75,y_size*0.75) -- Set the texture size.
            tsi_texture:SetPoint("CENTER", temp_spell_icon) -- Position the texture in the center of the frame.

            -- Show the frame and texture on the screen.
            temp_spell_icon:Show()
        end

        local dropdown = CreateFrame("Frame", "MyCDTDropdown"..i, button, "UIDropDownMenuTemplate")
        dropdown:SetPoint("LEFT", buttonText, "RIGHT", 16, 0)
        dropdown:SetSize(140,y_size) 
        -- This SetSize doesn't really work as hoped - a longer text value 
        --   here makes the width wider? Unclear. But it works for my 
        --   needs (which is setting the width enough that I am able to
        --   anchor relative to the dropdown without things getting weird).

        local options = {
            {text = "Offensive", value = "offensive"},
            {text = "Defensive", value = "defensive"},
            {text = "Crowd Control", value = "crowd_control"},
        }

        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.text
                info.value = option.value
                info.checked = option.value == entry.classification
                
                info.func = function(self)
                    entry.classification = option.value
                    update_icons = true
                    UIDropDownMenu_SetSelectedValue(dropdown, entry.classification)
                    UIDropDownMenu_SetText(dropdown,classification_options_to_str[entry.classification])
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        UIDropDownMenu_SetSelectedValue(dropdown, entry.classification)
        UIDropDownMenu_SetText(dropdown,classification_options_to_str[entry.classification])

        local blacklistButton = CreateFrame("Button", "CooldownTrackerBlacklistButton"..i, button, "UIPanelButtonTemplate")
        blacklistButton:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
        blacklistButton:SetSize(80, y_size)
        blacklistButton:SetText("Blacklist")
        blacklistButton:SetScript("OnClick", function()
            blacklist_add_by_id(entry.spellID)
            if debug_print == true then 
                print("CooldownTracker: ",entry.spellName .. " has been blacklisted.")
            end
            CDT_Draw_Options()
        end)

        offset = offset + y_size
    end

    -- ========================================================================
    local BLList = CreateFrame("ScrollFrame", "BlacklistListFrame", CDTOptions, "UIPanelScrollFrameTemplate")
    BLList:SetSize(CDTList:GetWidth(), CDTList:GetHeight()*1/2)
    BLList:SetPoint("TOPLEFT", CDTList, "BOTTOMLEFT", 0, 0)

    local BlacklistContent = CreateFrame("Frame", "BlacklistContentFrame", BLList)
    BLList:SetScrollChild(BlacklistContent)
    BlacklistContent:SetSize(BLList:GetSize())

    local blacklistIconTitle = BlacklistContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blacklistIconTitle:SetPoint("TOPLEFT", 0, 0)
    blacklistIconTitle:SetText("") -- I just want it invisible I think
    blacklistIconTitle:SetTextColor(1, 1, 1)
    blacklistIconTitle:SetSize(y_size,y_size)

    local blacklistTitle = BlacklistContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blacklistTitle:SetPoint("LEFT", blacklistIconTitle, "RIGHT", 0, 0)
    blacklistTitle:SetText("Blacklist")
    blacklistTitle:SetTextColor(1, 1, 1)
    blacklistTitle:SetSize(140,y_size)

    offset = 0
    -- Populate blacklist table
    local function PopulateBlacklistTable()
        for i, entry in ipairs(blacklist) do
            local button = CreateFrame("Frame", "MyBLTEntry"..i, BlacklistContent)
            button:SetPoint("TOPLEFT", blacklistTitle, "BOTTOMLEFT", 0, -offset)
            button:SetSize(120, y_size)
    
            local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            buttonText:SetPoint("LEFT", button, "LEFT", 5, 0)
            buttonText:SetText(entry.spellName)
            -- buttonText:SetTextColor(1, 1, 1) -- Set the font color to white
            buttonText:SetWidth(120)
            buttonText:SetJustifyH("LEFT")

            if entry.spellIcon_filePath ~= nil then
                -- Create a frame to contain the texture.
                local temp_spell_icon = CreateFrame("Frame", "MyBLIcon"..i, BlacklistContent)
                temp_spell_icon:SetSize(y_size*0.75,y_size*0.75) -- Set the frame size.
                temp_spell_icon:SetPoint("RIGHT", button, "LEFT", 0, 0)
    
                -- Create a texture object and set its properties.
                local tsi_texture = temp_spell_icon:CreateTexture(nil, "ARTWORK")
                tsi_texture:SetTexture(entry.spellIcon_filePath) -- Set the texture file path.
                -- tsi_texture:SetTexture
                tsi_texture:SetSize(y_size*0.75,y_size*0.75) -- Set the texture size.
                tsi_texture:SetPoint("CENTER", temp_spell_icon) -- Position the texture in the center of the frame.
    
                -- Show the frame and texture on the screen.
                temp_spell_icon:Show()
            end
    
            local unblacklistButton = CreateFrame("Button", "UnBlacklistButton"..i, button, "UIPanelButtonTemplate")
            unblacklistButton:SetPoint("LEFT", buttonText, "RIGHT", 16, 0)
            unblacklistButton:SetSize(80, y_size)
            unblacklistButton:SetText("Un-Blacklist")
            unblacklistButton:SetScript("OnClick", function()
                blacklist_remove_by_id(entry.spellID)
                if debug_print == true then 
                    print("CooldownTracker: ",entry.spellName .. " has been un-blacklisted.")
                end
                CDT_Draw_Options()
            end)
    
            offset = offset + y_size
        end
    end    
    PopulateBlacklistTable()

    if false then 
        BLList:SetSize(400,offset/y_size*(y_size+y_pad))
    end

    -- print("=====")
    -- print("0: ",CDTOptions:GetSize())
    -- print("z: ",CDTOptions:GetRect())
    -- print("1: ",CDTList:GetSize())
    -- print("a: ",CDTList:GetRect())
    -- print("2: ",CooldownTrackerListContent:GetSize())
    -- print("b: ",CooldownTrackerListContent:GetRect())
    -- print("3: ",BLList:GetSize())
    -- print("c: ",BLList:GetRect())
    -- print("4: ",BlacklistContent:GetSize())
    -- print("d: ",BlacklistContent:GetRect())
end

CDTOptions:SetScript("OnShow",CDT_Draw_Options)
InterfaceOptions_AddCategory(CDTOptions)
