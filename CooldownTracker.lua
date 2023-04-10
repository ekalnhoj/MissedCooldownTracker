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


local filteredSpells = {} -- Table to store filtered spells
--local blacklist = {} -- Table to store spells to ignore (e.g. Revive Battle Pets)


-- Logic to load the saved table.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local function addon_loaded(context, event, addon_name)
    print("Loading Addon: ",addon_name)
    print("Arguments: \nevent: ",event,"\naddon_name: ",addon_name,"\ncontext: ",context)
    printTable(filteredSpells)
    if addon_name == "CooldownTracker" then
        print("Loading from file")
        -- Initialize the filteredSpells table if it doesn't exist
        if not filteredSpells then
            print("not filteredSpells")
            filteredSpells = {}
        end

        -- Load the filteredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB[UnitClass("player")] then
            print("CooldownTrackerDB and CooldownTrackerDB[<stuff>]")
            filteredSpells = CooldownTrackerDB[UnitClass("player")].filteredSpells
            filteredSpells_loaded = CooldownTrackerDB[UnitClass("player")].filteredSpells
            print("filteredSpells: ")
            printTable(filteredSpells)
        end

        -- Unregister the ADDON_LOADED event
        frame:UnregisterEvent("ADDON_LOADED")
    end
    print("End of addon_loaded()")
end

frame:SetScript("OnEvent", addon_loaded)



-- ========================================================================
function load_table(table_name)
    if table_name == "filteredSpells" then
        -- Initialize the filteredSpells table if it doesn't exist
        if not filteredSpells then
            filteredSpells = {}
        end

        -- Load the filteredSpells table from the saved variable table
        if CooldownTrackerDB and CooldownTrackerDB[UnitClass("player")] then
            print("CooldownTrackerDB and CooldownTrackerDB[<stuff>]")
            filteredSpells = CooldownTrackerDB[UnitClass("player")].filteredSpells
            print("Loaded table filteredSpells: ")
            printTable(filteredSpells)
        end
    end
end

function printTable(t, indent)
    indent = indent or 0
    for k,v in pairs(t) do
        if type(v) == "table" then
            print(string.rep("  ", indent) .. k .. ":")
            printTable(v, indent + 1)
        else
            print(string.rep("  ", indent) .. k .. ": " .. tostring(v))
        end
    end
end

-- Slash command function
local function slashCommandHandler(msg)
    if msg == "print" then
        print("filteredSpells: ")
        printTable(filteredSpells)
    end
    if msg == "print_saved_table" then
        print("CooldownTrackerDB: ")
        printTable(CooldownTrackerDB)
    end
    if msg == "load" then
        print("Before (filteredSpells): ")
        printTable(filteredSpells)
        load_table("filteredSpells")
        print("After:  ")
        print("After (filteredSpells): ")
        printTable(filteredSpells)
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

            if not spellID then 
                -- print("Not Spell ID: ",spellID)
                -- If spellID isn't valid then do nothing, else keep running.
            else
                local start, duration, enabled = GetSpellCooldown(spellID)
                if duration and duration >= track_threshold then
                    -- print("Yes: ",spellName)
                    filteredSpells[spellID] = {spellID=spellID, spellName=spellName, cooldown=duration, lastused=-1}
                else
                    -- print("No:  ",spellName)
                end
            end
        end
    end

end

-- Function to update the display text of 'spNameText'
local function updateTableText()
    -- print("Tock: updateTableText")
    if not filteredSpells then return end

    -- Clear the current text
    spNameText:SetText("Spell Name\n")
    spcdText:SetText("CD\n")
    spluText:SetText("LU\n")
    mcText:SetText("MC\n")

    -- Iterate over the filtered spells and add them to the text
    for _, spellData in pairs(filteredSpells) do
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
local function updateCooldowns()
    -- print("Tock: updateCooldowns")
    if not filteredSpells then return end

    for _, spellData in pairs(filteredSpells) do        
        local spellName, _, spellIcon, spellCooldown = GetSpellInfo(spellData.spellID)
        local start, duration, enabled = GetSpellCooldown(spellData.spellID)

        -- If the spell is on cooldown and its cooldown is longer than 30 seconds
        if start ~= nil and duration > 1.5 and duration >= track_threshold then
            -- Store the spell data in the filteredSpells table
            filteredSpells[spellData.spellID].lastused = start -- GetTime() - start
        end
    end
end

-- Define the function to call 'updateCooldownText' once per second
local function onTick()
    -- print("Tick: ",GetTime())
    get_all_spells_with_cd_over_threshold()
    updateCooldowns()
    updateTableText()
    C_Timer.After(0.5, onTick)
end

-- Call 'onTick' once to start the timer
onTick()


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