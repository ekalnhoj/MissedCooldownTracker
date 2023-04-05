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

-- Create a new font string named 'cooldownText' inside 'cooldownFrame'
local cooldownText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
-- Set the position of 'cooldownText' relative to the top left corner of 'cooldownFrame'
cooldownText:SetPoint("TOPLEFT", 20, -20)
-- Set the horizontal alignment of the text to the left
cooldownText:SetJustifyH("LEFT")
-- Set the vertical alignment of the text to the top
cooldownText:SetJustifyV("TOP")
-- Set the width and height of 'cooldownText'
cooldownText:SetWidth(260)
cooldownText:SetHeight(360)

-- Some initialization.
cooldownText:SetText("") -- Could probably just do it in the constructor, but why take chances?
local lastUseTime_default = 0

-- Define a function named 'updateCooldowns'
local function updateCooldowns()
    print("updateCooldowns()")
    -- Get the current time in seconds since the start of the game
    local currentTime = GetTime()
    -- Create a table named 'cooldownInfo' to store the cooldown information for each spell
    local cooldownInfo = {}
    
    -- Loop through each spell tab in the player's spellbook
    for i = 1, 3 do --GetNumSpellTabs() do
        -- Get information about the current spell tab
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        -- Loop through each spell in the current spell tab

        -- print("GetNumSpellTabs. numSpells: ",numSpells)
        for j = 1, numSpells do
            -- Get the name, ID, and icon of the current spell
            local spellName_outer = GetSpellBookItemName(j + offset, BOOKTYPE_SPELL)

            -- local spellID = select(2, GetSpellBookItemInfo(spellName, BOOKTYPE_SPELL))
            -- print(spellID)
            -- local spellName, _, spellIcon = GetSpellInfo(spellID)
            local spellName, _, spellIcon, _, _, _, spellID = GetSpellInfo(spellName_outer)

            if not spellName then
                -- This only happens when it's an expanded spell (e.g. the portals).
                print("Nil inner SpellName    : i:", i, " j: ", j,"  |  ",spellName_outer)
            else
                -- print("Non-Nil inner SpellName: i:", i, " j: ", j,"  |  ",spellName_outer)
                print(spellName, spellID, spellIcon)

                -- Get the cooldown information for the current spell
                local start, duration, enabled = GetSpellCooldown(j + offset, BOOKTYPE_SPELL)
                local spellCooldown = start + duration - GetTime() -- calculate time since last use
                -- That's kinda sus, swapping to this:
                -- Get the cooldown information for the current spell
                spellCooldown = GetSpellCooldown(j + offset, BOOKTYPE_SPELL)
                
                if not spellCooldown then
                    print("spellCooldown was nil for:  ",spellName)
                else
                    --print(spellName, spellCooldown)
                    
                    -- If the spell has a cooldown longer than 20 seconds, add it to 'cooldownInfo'
                    if spellCooldown and spellCooldown > 20 then
                        -- Calculate the time in seconds since the spell was last used
                        local lastUseTime = currentTime - spellCooldown
                        -- Add the spell and last use time to 'cooldownInfo'
                        cooldownInfo[spellName] = lastUseTime

                        print("Added spell to table:  ",spellName_outer)
                    end
                end
            end
        end
    end
    
    -- Clear the current contents of 'cooldownText'
    cooldownText:SetText("")
    
    -- Loop through each spell
    for spellName, lastUseTime in pairs(cooldownInfo) do
        -- Add a line of text to 'cooldownText' with the spell name and time since last use
        --cooldownText:AddLine(spellName .. ": " .. lastUseTime .. " seconds since last use")
        if not lastUseTime then
            lastUseTime = lastUseTime_default
        end
        local lastUseTime_formatted = string.format("%03d",lastUseTime)
        -- print("cooldownText:GetText: ",cooldownText:GetText())
        -- print("spellName           : ",spellName)
        -- print("lastUseTime_fmtted  : ",lastUseTime_formatted)
        local cdt = cooldownText:GetText()
        if not cdt then
            cooldownText:SetText(spellName .. ": " .. lastUseTime_formatted .. " sec since last use\n")
        else
            cooldownText:SetText(cdt .. spellName .. ": " .. lastUseTime_formatted .. " sec since last use\n")
        end
        -- -- cooldownText:SetText(cooldownText:GetText() .. spellName .. ": " .. lastUseTime_formatted .. " sec since last use\n")
        -- cooldownText:SetText(spellName .. ": " .. lastUseTime_formatted .. " sec since last use\n")
    end
end

-- Set the 'OnEvent' script for 'cooldownFrame' to listen for the 'PLAYER_ENTERING_WORLD' event
--cooldownFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
print("Player entered world (presumably).")

-- Set the 'OnEvent' script for 'cooldownFrame' to call 'updateCooldowns' whenever a spell is cast or a spell cooldown ends
cooldownFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        print("Updating Cooldowns.")
        updateCooldowns()
    end
end)

-- Add a slash command to toggle the visibility of 'cooldownFrame'
SLASH_COOLDOWNTRACKER1 = "/cooldowntracker"
SlashCmdList["COOLDOWNTRACKER"] = function()
    if cooldownFrame:IsVisible() then
        cooldownFrame:Hide()
    else
        cooldownFrame:Show()
    end
end

-- Add a string to the top right of the screen that says "CooldownTracker"
local titleText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPRIGHT", -10, -10)
titleText:SetText("CooldownTracker")
