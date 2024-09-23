-------------------------------------------------------------------------------
-- ========================================================================= --
-- GUI stuff below
-- ========================================================================= --
-------------------------------------------------------------------------------

local CooldownTracker = MissedCooldownTracker
local cooldownFrame
-- file-wide locals because I change them when paused or resized
local pauseButton, pauseButtonFrame
local resetButton, resetButtonFrame
local reset_button_str = ""
local pause_button_str = ""

-- rows holds the display table contents.
local rows = {}
local n_rows = 0
local debug_print = true
local x_size_unit = 0 -- used in the row resizing calcs
local approx_letter_width_rows = 6
local approx_letter_width_button = 12

function CooldownTracker:UIManager_OnInitialize()
    debug_print = CooldownTracker.debug_print

    -- Event-fired message functions registered in the main file.

    CooldownTracker.need_to_redraw_display = false

    CooldownTracker:MakeCooldownFrame()
    CooldownTracker:CooldownFrameStart()
    CooldownTracker:ShowFrame(self.db.profile.enabled)
end

-------------------------------------------------------------------------------
-- ========================================================================= --
-- Event-fired message functions.
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:UIManager_StartupDelayed()
    --Registered to CDT_API_LOADED message.
    if debug_print == true then CooldownTracker:Print("UI StartupDelayed") end

    CooldownTracker:RedrawDisplay()
end

function CooldownTracker:UIManager_OnTick()
    -- Registered to CDT_TICK message.
    CooldownTracker:UpdateTableText()
end

function CooldownTracker:UIManager_OnPause()
    --Registered to CDT_PAUSE message.
    pauseButton:SetText("Unpause Addon")
end

function CooldownTracker:UIManager_OnUnpause()
    --Registered to CDT_UNPAUSE message.
    pauseButton:SetText("Pause Addon")
end

function CooldownTracker:UIManager_OnEnable()
    -- Registered to CDT_ENABLE message.
    CooldownTracker:ShowFrame(true)
end

function CooldownTracker:UIManager_OnDisable()
    -- Registered to CDT_DISABLE message.
    CooldownTracker:ShowFrame(false)
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- 
-- ========================================================================= --
-------------------------------------------------------------------------------

-- Current to do


-------------------------------------------------------------------------------
-- ========================================================================= --
-- Local GUI functions
-- ========================================================================= --
-------------------------------------------------------------------------------
local function make_table_row(parent,y_offset)
    local num_x_splits = 6
    y_offset = y_offset or 0
    local y_size = 12
    local y_pad = 2
    local x_pad = 2
    local x_size_unit_float = (CooldownTracker.db.profile.size_x - 40 - y_size - 4*y_pad)/num_x_splits
    x_size_unit = math.floor(x_size_unit_float) -- Typecast to int.
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

    -- Make sure this adds up to be equal to num_x_splits * x_size_unit
    spName_str:SetWidth(x_size_unit*3)
    spCD_str:SetWidth(x_size_unit)
    spLU_str:SetWidth(x_size_unit)
    spMC_str:SetWidth(x_size_unit)

    local row_container = {row=the_row,icon=the_icon,spName=spName_str,spCD=spCD_str,spLU=spLU_str,spMC=spMC_str}
    return row_container
end

-- === Here on they're kinda unused.
local function allow_frame_movement(bool_val,depth)
    depth = depth or 1
    if debug_print == true then print("Setting movable to ",bool_val) end

    cooldownFrame:SetMovable(bool_val)
    cooldownFrame:EnableMouse(bool_val)
    if bool_val == true then
        cooldownFrame:SetScript("OnMouseDown",function(self, button)
            if button == "LeftButton" then 
                self:StartMoving()
            else
                -- == Do nothing
            end
        end)
        cooldownFrame:SetScript("OnMouseUp",function(self,button)
            self:StopMovingOrSizing()
            -- Grab the coordinates for saving
            CooldownTracker:update_frame_info()
        end)
    end

    -- I know there must be a way to make "exclusive turn it on" work but I'm failing. 
    --   I'll just have to trust the user not to get into trouble.
    -- if bool_val == true and depth <= 1 then
    --     allow_frame_resizing(false,depth+1) -- Re-set moving options (seems to be needed?)
    --     CooldownTracker_Draw_Options()
    -- end
end

local function allow_frame_resizing(bool_val,depth)
    depth = depth or 1
    if debug_print == true then print("Setting sizable to ",bool_val) end

    cooldownFrame:SetResizable(bool_val)
    cooldownFrame:EnableMouse(bool_val)
    if bool_val == true then
        cooldownFrame:SetScript("OnMouseDown",function(self, button)
            if button == "LeftButton" then 
                self:StartSizing() -- defaults to bottom right
            else
                -- == Do nothing
            end
        end)
        cooldownFrame:SetScript("OnMouseUp",function(self,button)
            self:StopMovingOrSizing()
            -- Grab the coordinates for saving
            CooldownTracker:update_frame_info()
        end)
    end

    -- I know there must be a way to make "exclusive turn it on" work but I'm failing. 
    --   I'll just have to trust the user not to get into trouble.
    -- if bool_val == true and depth <= 1 then
    --     allow_frame_movement(false,depth+1) -- Re-set moving options (seems to be needed?)
    --     CooldownTracker_Draw_Options()
    -- end
end

local function adjust_changeability(new_status)
    local new_status_lower = string.lower(new_status)
    CooldownTracker.db.profile.frame_adjustability = new_status_lower
    if new_status_lower == "movable" then
        if debug_print == true then print("Movable") end
        allow_frame_resizing(false)
        allow_frame_movement(true)
        
    elseif new_status_lower == "resizable" then 
        if debug_print == true then print("Resizable") end
        allow_frame_movement(false)
        allow_frame_resizing(true)
    else
        if debug_print == true then print("Neither movable or resizable") end
        allow_frame_movement(false)
        allow_frame_resizing(false)        
    end
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- GUI Small Utility Functions
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:toggle_ticking()
    local is_running = not(self.paused)
    if is_running == true then  
        CooldownTracker:SendMessage("CDT_PAUSE")
    else
        CooldownTracker:SendMessage("CDT_UNPAUSE") 
    end
end

function CooldownTracker.RedrawDisplay()
    CooldownTracker.need_to_redraw_display = true 
end

function CooldownTracker:update_frame_info()
    local coordinate_x,coordinate_y,size_x,size_y = cooldownFrame:GetRect()
    self.db.profile.coordinate_x = coordinate_x
    self.db.profile.coordinate_y = coordinate_y
    self.db.profile.size_x = size_x
    self.db.profile.size_y = size_y
end

function CooldownTracker:EnableFrameMove(do_enable)
    if do_enable == true then
        cooldownFrame:EnableMouse(true)
        cooldownFrame:SetMovable(true)
        cooldownFrame:RegisterForDrag("LeftButton")
        cooldownFrame:SetScript("OnDragStart", cooldownFrame.StartMoving)
        cooldownFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            CooldownTracker.db.profile.coordinate_x, CooldownTracker.db.profile.coordinate_y = self:GetLeft(), self:GetBottom()
        end)
    else
        cooldownFrame:EnableMouse(false)
        cooldownFrame:SetMovable(false)
        cooldownFrame:SetScript("OnDragStart", nil)
        cooldownFrame:SetScript("OnDragStop", nil)
    end
end

function CooldownTracker:EnableFrameResize(do_enable)
    if do_enable == true then
        CooldownTracker.resizeHandle = CreateFrame("Button", nil, cooldownFrame)
        CooldownTracker.resizeHandle:SetSize(16, 16)
        CooldownTracker.resizeHandle:SetPoint("BOTTOMRIGHT", cooldownFrame, "BOTTOMRIGHT")
        
        CooldownTracker.resizeHandle:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Up")
        CooldownTracker.resizeHandle:SetHighlightTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Highlight")
        CooldownTracker.resizeHandle:SetPushedTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Down")
        
        CooldownTracker.resizeHandle:SetScript("OnMouseDown", function()
            cooldownFrame:StartSizing("BOTTOMRIGHT")
        end)
        
        CooldownTracker.resizeHandle:SetScript("OnMouseUp", function()
            cooldownFrame:StopMovingOrSizing()
            CooldownTracker.db.profile.size_x = cooldownFrame:GetWidth()
            CooldownTracker.db.profile.size_y = cooldownFrame:GetHeight()
            CooldownTracker:UpdateFrameSize()
        end)
        
        cooldownFrame:SetResizable(true)
    else
        if CooldownTracker.resizeHandle then CooldownTracker.resizeHandle:Hide() end
    end        
end


-------------------------------------------------------------------------------
-- ========================================================================= --
-- Addon-wide GUI Functions
-- ========================================================================= --
-------------------------------------------------------------------------------
function CooldownTracker:MakeCooldownFrame()
    -- GUI interlude
    -- Create a new frame named 'CooldownTrackerFrame' with a size of 300x400
    cooldownFrame = CreateFrame("Frame", "CooldownTrackerFrame", UIParent, "BackdropTemplate")
    -- cooldownFrame:SetSize(300, 400)
    -- Position the frame 10 pixels from the left of the screen
    -- cooldownFrame:SetPoint("LEFT", 0, 10)
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

    -- Make the buttons
    resetButtonFrame = CreateFrame("Frame", "resetButtonFrame", cooldownFrame)
    resetButton = CreateFrame("Button", "resetButton", resetButtonFrame, "UIPanelButtonTemplate")

    pauseButtonFrame = CreateFrame("Frame", "pauseButtonFrame", cooldownFrame)
    pauseButton = CreateFrame("Button", "pauseButton", pauseButtonFrame, "UIPanelButtonTemplate")

    CooldownTracker:UpdateButtons()
end

function CooldownTracker:UpdateButtons()
    -- Overkill? Yeah, I'm sure. But it works.
    local button_x_size = math.min(140,math.floor((CooldownTracker.db.profile.size_x - 10) / 2))
    local reset_button_strs = {{"Reset Spell Numbers",0},{"Reset Numbers",0},{"Reset",0}}
    local pause_button_strs = {{"Pause Addon",0},{"Pause",0}}
    for i,entry in ipairs(reset_button_strs) do
        reset_button_strs[i][2] = string.len(reset_button_strs[i][1]) * approx_letter_width_button
    end
    for i,entry in ipairs(pause_button_strs) do
        pause_button_strs[i][2] = string.len(pause_button_strs[i][1]) * approx_letter_width_button
    end

    for i,entry in ipairs(reset_button_strs) do
        if entry[2] < button_x_size then 
            reset_button_str = entry[1]
            break
        end
    end
    for i,entry in ipairs(pause_button_strs) do
        if entry[2] < button_x_size then 
            pause_button_str = entry[1]
            break
        end
    end    

    -- Update reset button to the bottom.
    if true then -- Just making a code block
        resetButtonFrame:SetSize(button_x_size+8, 30)
        resetButtonFrame:SetPoint("BOTTOMLEFT", cooldownFrame, "BOTTOMLEFT", 5, 10)

        resetButton:SetPoint("CENTER", resetButtonFrame, "CENTER", 0, 0)
        resetButton:SetSize(button_x_size, 22)
        resetButton:SetText(reset_button_str)

        -- Set the click handler for the button
        resetButton:SetScript("OnClick", function()
            CooldownTracker:ResetSpellNumbers()
        end)
    end

    -- Update pause button to the bottom as well.
    if true then -- Just making a code block
        pauseButtonFrame:SetSize(button_x_size+8, 30)
        pauseButtonFrame:SetPoint("BOTTOMRIGHT", cooldownFrame, "BOTTOMRIGHT", -5, 10)

        pauseButton:SetPoint("CENTER", pauseButtonFrame, "CENTER", 0, 0)
        pauseButton:SetSize(button_x_size, 22)
        pauseButton:SetText(pause_button_str)

        -- Set the click handler for the button
        pauseButton:SetScript("OnClick", function()
            CooldownTracker:toggle_ticking()
        end)
    end
end

function CooldownTracker:UpdateFrameSize()

    if cooldownFrame then
        cooldownFrame:SetSize(CooldownTracker.db.profile.size_x, CooldownTracker.db.profile.size_y)
        -- Reposition elements or content inside the frame if necessary
        CooldownTracker:UpdateButtons()
        CooldownTracker:RedrawDisplay()
    end
end

function CooldownTracker:CooldownFrameStart()
    if debug_print == true then CooldownTracker:Print("UI: CooldownFrameStart") end
    -- Some GUI startup
    CooldownTracker:ShowFrame(true)
    CooldownTracker:UpdateFrameSize()
    cooldownFrame:SetPoint("BOTTOMLEFT", CooldownTracker.db.profile.coordinate_x, CooldownTracker.db.profile.coordinate_y)

    -- If they left it movable, make it movable. 
    CooldownTracker:EnableFrameMove(CooldownTracker.db.profile.enable_moving)
    CooldownTracker:EnableFrameResize(CooldownTracker.db.profile.enable_resizing)
end

function CooldownTracker:ShowFrame(bool_val)
    if bool_val == true then 
		if debug_print == true then CooldownTracker:Print("Showing Frame") end
        cooldownFrame:Show()
    elseif bool_val == false then 
		if debug_print == true then CooldownTracker:Print("Hiding Frame") end
        cooldownFrame:Hide()
    end
    CooldownTracker.db.profile.display_enabled = bool_val
end

-- Function to update the display text of 'spNameText'
function CooldownTracker:UpdateTableText()
    local spell_list_all = CooldownTracker:GetSpellList()
    if not spell_list_all then return end

    -- Embedding this in here instead of on its own because I only want to 
    --   try to redraw the thing at this particular step of updating the table.
    if CooldownTracker.need_to_redraw_display == true then
        -- Redraw the tables. First delete the old things.
        -- Clear the frame
        for k,row_entry in pairs(rows) do
            for k2,row_component in pairs(row_entry) do
                row_component:Hide()
                row_component:SetParent(nil)
            end
        end
        rows = {}

        CooldownTracker.need_to_redraw_display = false
    end

    -- This might should be its own table but for now it's not.
    local defensive_spells = {}
    local utility_spells = {}

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

    for i, spellData in ipairs(spell_list_all) do
        -- Only need to check if it's known here because the defensive_spells and utility_spells tables are set here.
        --   If that changes, then you'll have to add the logic below.

        if spellData.is_known == true then
            if spellData.classification == "defensive" then
                table.insert(defensive_spells,spellData)
            elseif spellData.classification == "utility" then
                table.insert(utility_spells,spellData)
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
                -- if spellData.max_charges > 1 then
                --     max_charges = spellData.max_charges
                --     curr_charges,max_charges,_,cooldown,_ = GetSpellCharges(spellData.spellID)

                --     if curr_charges < max_charges then 
                --         mc = 0
                --     else
                --         -- We're at max charges. Things get complicated.                         
                --         mc = (sinceLastUsed - cooldown*(max_charges-1)) / spellData.cooldown
                --     end
                --     if sinceLastUsed < 0 then sinceLastUsed = 0 end
                -- else
                --     mc = sinceLastUsed / spellData.cooldown
                -- end
                local make_red = false
                local make_orange = false
                if mc >= 2 then
                    make_red = true
                end
                if mc >= 1 then
                    make_orange = true
                end

                -- CooldownTracker.db.profile.str_max_disp_len = 17
                local spNameLen = string.len(spellData.spellName)
                local spNameStr = ""
                local mcStr = ""
                -- if spNameLen > CooldownTracker.db.profile.str_max_disp_len then
                --     local spNameStr_trunc = string.sub(spellData.spellName,1,CooldownTracker.db.profile.str_max_disp_len-3)
                --     spNameStr = string.format("%s...",spNameStr_trunc)
                -- else
                --     spNameStr = spellData.spellName
                -- end
                spNameStr = spellData.spellName
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

                -- Check that it's not too wide.
                local spNameLen = curr_row.spName:GetStringWidth()
                if spNameLen > 3*x_size_unit then
                    local target_len = 3*x_size_unit / approx_letter_width_rows
                    local spNameStr_trunc = string.sub(spellData.spellName,1,target_len-3)
                    spNameStr_trunc = string.format("%s...",spNameStr_trunc)
                    curr_row.spName:SetText(spNameStr_trunc)
                end
                
                y_offset = y_offset+y_size+y_pad
            end
        end
    end

    -- ======
    if #defensive_spells > 0 then
        y_offset = y_offset + CooldownTracker.db.profile.section_line_breaks*y_size

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
            -- Only need to check if it's known here because the defensive_spells and utility_spells tables are set here.
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
				local mcStr = ""
                if spNameLen > CooldownTracker.db.profile.str_max_disp_len then
                    local spNameStr_trunc = string.sub(spellData.spellName,1,CooldownTracker.db.profile.str_max_disp_len-3)
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

                -- Check that it's not too wide.
                local spNameLen = curr_row.spName:GetStringWidth()
                if spNameLen > 3*x_size_unit then
                    local target_len = 3*x_size_unit / approx_letter_width_rows
                    local spNameStr_trunc = string.sub(spellData.spellName,1,target_len-3)
                    spNameStr_trunc = string.format("%s...",spNameStr_trunc)
                    curr_row.spName:SetText(spNameStr_trunc)
                end

                y_offset = y_offset+y_size+y_pad
            end
        end
    end

    if #utility_spells > 0 then
        y_offset = y_offset + CooldownTracker.db.profile.section_line_breaks*y_size

        local title_row = nil
        if rows["title_utility"] == nil then
            title_row = make_table_row(cooldownFrame)
            title_row.spName:SetText(string.format("|cFFFFFFFFUtility Spells|r"))
            title_row.spCD:SetText(string.format("|cFFFFFFFFCD|r"))
            title_row.spLU:SetText(string.format("|cFFFFFFFFLU|r"))
            title_row.spMC:SetText(string.format("|cFFFFFFFFMC|r"))
            rows["title_utility"] = title_row
        else
            title_row = rows["title_utility"]
        end

        title_row.row:SetPoint("TOPLEFT",cooldownFrame,"TOPLEFT",0,-y_offset)
        y_offset = y_offset + y_size+y_pad
        -- print("Rect 3: ",title_row.row:GetRect())

        for i, spellData in ipairs(utility_spells) do
            -- Only need to check if it's known here because the defensive_spells and utility_spells tables are set here.
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
				local mcStr = ""
                if spNameLen > CooldownTracker.db.profile.str_max_disp_len then
                    local spNameStr_trunc = string.sub(spellData.spellName,1,CooldownTracker.db.profile.str_max_disp_len-3)
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

                -- Check that it's not too wide.
                local spNameLen = curr_row.spName:GetStringWidth()
                if spNameLen > 3*x_size_unit then
                    local target_len = 3*x_size_unit / approx_letter_width_rows
                    local spNameStr_trunc = string.sub(spellData.spellName,1,target_len-3)
                    spNameStr_trunc = string.format("%s...",spNameStr_trunc)
                    curr_row.spName:SetText(spNameStr_trunc)
                end

                y_offset = y_offset+y_size+y_pad

            end
        end
    end
end
