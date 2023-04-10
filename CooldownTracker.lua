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


-- local sl = {} -- Table to store filtered spells
-- local bl = {} -- Table to store spells to ignore (e.g. Revive Battle Pets)

local initialized = 0

-- Logic to load the saved table.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")



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

function save_to_file()
    save_spelllist()
    save_blacklist()
end


local function CreateOptionsPanel()
    -- create configuration panel
    local panel = CreateFrame("Frame", "CooldownTrackerOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Cooldown Tracker"

    -- create title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Cooldown Tracker Options")

    -- create description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", panel, -32, 0)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetText("Configure options for the Cooldown Tracker addon.")

    -- create scroll frame
    local scroll = CreateFrame("ScrollFrame", "CooldownTrackerOptionsPanelScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    scroll:SetPoint("BOTTOMRIGHT", panel, -32, 16)

    -- create scroll child frame
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(300, 400)
    scroll:SetScrollChild(child)

    -- create title for blacklist
    local blacklistTitle = child:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    blacklistTitle:SetPoint("TOPLEFT", 16, -16)
    blacklistTitle:SetText("Blacklisted Cooldowns")

    -- create description for blacklist
    local blacklistDesc = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    blacklistDesc:SetPoint("TOPLEFT", blacklistTitle, "BOTTOMLEFT", 0, -8)
    blacklistDesc:SetPoint("RIGHT", child, -32, 0)
    blacklistDesc:SetJustifyH("LEFT")
    blacklistDesc:SetJustifyV("TOP")
    blacklistDesc:SetText("Add or remove cooldowns from the blacklist (by name, not spell ID).")

    -- create editbox for blacklist
    local blacklistEditBox = CreateFrame("EditBox", "CooldownTrackerOptionsPanelBlacklistEditBox", child, "InputBoxTemplate")
    blacklistEditBox:SetSize(200, 20)
    blacklistEditBox:SetPoint("TOPLEFT", blacklistDesc, "BOTTOMLEFT", 0, -16)
    blacklistEditBox:SetAutoFocus(false)
    blacklistEditBox:SetMultiLine(false)
    blacklistEditBox:SetText(table.concat(CooldownTrackerDB.nixed_spells, "\n"))

    -- create okay button
    local okayButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    okayButton:SetPoint("BOTTOMRIGHT", -16, 16)
    okayButton:SetSize(80, 22)
    okayButton:SetText("Okay")
    okayButton:SetScript("OnClick", function()
        CooldownTrackerDB.nixed_spells = {}
        -- for line in blacklistEditBox:GetText():gmatch("[^\r\n]+") do
        --     tinsert(CooldownTrackerDB.nixed_spells, line)
        -- end
        add_to_blacklist(blacklistEditBox:GetText())
        print("Blacklist updated!")
    end)

    -- add configuration panel to WoW Interface Options
    InterfaceOptions_AddCategory(panel)
end

local function addon_loaded(context, event, addon_name)
    if addon_name == "CooldownTracker" then
        load_table("monitoredSpells")
        load_table("blacklist")

        CreateOptionsPanel()

        -- Unregister the ADDON_LOADED event
        frame:UnregisterEvent("ADDON_LOADED")
    end
end

frame:SetScript("OnEvent", addon_loaded)



-- ========================================================================





-- ========================================================================
function load_table(table_name)
    if table_name == "monitoredSpells" then
        -- Initialize if needed.
        if not monitoredSpells then
            monitoredSpells = {}
        end

        -- Initialize the table and subtable if they don't exist.
        if CooldownTrackerDB == nil then
            CooldownTrackerDB = {}
        end
        if CooldownTrackerDB[UnitClass("player")] == nil then
            CooldownTrackerDB[UnitClass("player")] = {}
        end

        if CooldownTrackerDB[UnitClass("player")].saved_spells == nil then
            CooldownTrackerDB[UnitClass("player")].saved_spells = {}
        end

        -- Load the monitoredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB[UnitClass("player")] then
            -- This seems to act like a pointer? I don't get it to be honest.
            monitoredSpells = CooldownTrackerDB[UnitClass("player")].saved_spells
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
    end
    if msg == "print_saved_table" then
        print("CooldownTrackerDB: ")
        printTable(CooldownTrackerDB)
    end
    if msg == "load" then
        load_table("monitoredSpells")
    end
    if msg == "load blacklist" then
        load_table("blacklist")
    end
end

-- Register the slash command
SLASH_CDT1 = "/cdt"
SlashCmdList["CDT"] = slashCommandHandler


-- =========================================================================

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

            if not spellID then 
                -- print("Not Spell ID: ",spellID)
                -- If spellID isn't valid then do nothing, else keep running.
            elseif is_in_blacklist == 1 then
                -- print("Blacklisted spell.")
                -- If it's in the blacklist, don't add it to the table.
            else
                local start, duration, enabled = GetSpellCooldown(spellID)
                if duration and duration >= track_threshold then
                    -- print("Yes: ",spellName)
                    monitoredSpells[spellID] = {spellID=spellID, spellName=spellName, cooldown=duration, lastused=-1}
                else
                    -- print("No:  ",spellName)
                end
            end
        end
    end

    save_to_file()
end

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
                blacklist[spellID] = spellName
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
    spNameText:SetText("Spell Name\n")
    spcdText:SetText("CD\n")
    spluText:SetText("LU\n")
    mcText:SetText("MC\n")

    -- Iterate over the filtered spells and add them to the text
    for _, spellData in pairs(monitoredSpells) do
        -- Add the formatted line to the previous lines.
        local sp_prev = spNameText:GetText()
        local cd_prev = spcdText:GetText()
        local lu_prev = spluText:GetText()
        local mc_prev = mcText:GetText()

        local sinceLastUsed = GetTime() - spellData.lastused
        local mc = sinceLastUsed / spellData.cooldown

        spNameText:SetText(sp_prev .. spellData.spellName .. "\n")
        spcdText:SetText(cd_prev .. string.format("%d",spellData.cooldown) .. "\n")
        spluText:SetText(lu_prev .. string.format("%d",sinceLastUsed) .. "\n")
        mcText:SetText(mc_prev .. string.format("%d",mc) .. "\n")
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
            monitoredSpells[spellData.spellID].lastused = start -- GetTime() - start
        end
    end
end



local function onTick()
    -- print("Tick: ",GetTime())
    get_all_spells_with_cd_over_threshold()
    updateCooldowns()
    updateTableText()
    C_Timer.After(0.5, onTick)
end

local function onTick_init()
    if initialized == 0 then
        C_Timer.After(1,onTick_init)
    else
        C_Timer.After(0.5,onTick)
    end
end

-- Call 'onTick' once to start the timer
onTick_init()


-- Event handler for PLAYER_LOGIN event
local function onPlayerLogin()
    get_all_spells_with_cd_over_threshold()
    --filterSpellsWithCooldownGreaterThan30()
    updateTableText()
end

-- Event handler for SPELL_UPDATE_COOLDOWN event
local function onSpellUpdateCooldown()
    --filterSpellsWithCooldownGreaterThan30()
    -- updateTableText()
end

-- Register the event handlers
cooldownFrame:RegisterEvent("PLAYER_LOGIN")
cooldownFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

-- Set the script for the OnEvent event of 'cooldownFrame'
cooldownFrame:SetScript("OnEvent", function(self, event, ...)
-- Call the appropriate event handler based on the event that occurred
if event == "PLAYER_LOGIN" then
    onPlayerLogin(...)
elseif event == "SPELL_UPDATE_COOLDOWN" then
    onSpellUpdateCooldown(...)
end
end)