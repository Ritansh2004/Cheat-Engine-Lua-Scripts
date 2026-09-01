-- Adds a context menu option to the Found List to revert selected items
-- to their "First" scan value. (Version 2 - Fixed nil SelCount error)

local function revertSelectedToFirst()
    local mainForm = getMainForm()
    local lv = mainForm.Foundlist3
    if not lv then return end

    -- Dynamically find the index of the "First" column
    local firstSubIdx = -1
    for i = 0, lv.Columns.Count - 1 do
        if lv.Columns[i].Caption:lower() == "first" then
            -- SubItems are 0-indexed and exclude the main Caption (Address)
            firstSubIdx = i - 1
            break
        end
    end

    if firstSubIdx < 0 then
        messageDialog("Could not find the 'First' column. Make sure it is visible.", mtError, mbOK)
        return
    end

    local ms = getCurrentMemscan()
    if not ms then return end

    local al = getAddressList()

    -- Loop through all items to process the selected ones
    for i = 0, lv.Items.Count - 1 do
        local item = lv.Items[i]

        -- Process only if the item exists and is currently selected by the user
        if item and item.Selected then
            local addressStr = item.Caption
            local firstValStr = item.SubItems[firstSubIdx]

            -- Ensure we have a valid value and it's not unreadable (??)
            if addressStr and firstValStr and firstValStr ~= "" and firstValStr ~= "??" then

                -- Create a temporary memory record to safely write the value
                local rec = al.createMemoryRecord()

                -- Parse the address for "Value Type All" suffixes (e.g., F3DF02DC:s)
                local addrPart, suffix = addressStr:match("([^:]+):(.+)")

                if suffix then
                    rec.Address = addrPart
                    local s = suffix:lower()

                    -- Map CE suffixes to actual variable types
                    if s == "1" or s == "b" then rec.Type = vtByte
                    elseif s == "2" or s == "w" then rec.Type = vtWord
                    elseif s == "4" or s == "d" then rec.Type = vtDword
                    elseif s == "8" or s == "q" then rec.Type = vtQword
                    elseif s == "s" or s == "f" then rec.Type = vtSingle
                    elseif s == "d" then rec.Type = vtDouble
                    else rec.Type = ms.VarType end
                else
                    rec.Address = addressStr
                    rec.Type = ms.VarType
                end

                -- Use pcall to prevent crashes if the value string format is unexpected
                pcall(function() rec.Value = firstValStr end)

                -- Clean up the temporary record
                rec.destroy()
            end
        end
    end

    -- Visually update the Found List to reflect the new current values
    lv.Refresh()
end

local function setupContextMenu()
    local popup = getMainForm().foundlistpopup

    -- Prevent duplicate menu items on repeated script executions
    for i=0, popup.Items.Count-1 do
        if popup.Items[i].Caption == "Set to 'First' Value" then
            return
        end
    end

    local miRevert = createMenuItem(popup)
    miRevert.Caption = "Set to 'First' Value"
    miRevert.OnClick = revertSelectedToFirst

    -- Insert it at the top of the context menu
    popup.Items.Insert(0, miRevert)

    local separator = createMenuItem(popup)
    separator.Caption = "-"
    popup.Items.Insert(1, separator)
end

-- Initialize via Timer to ensure Cheat Engine UI forms are completely constructed
local t = createTimer(nil, false)
t.Interval = 500
t.OnTimer = function(timer)
    timer.Enabled = false
    timer.destroy()
    setupContextMenu()
end
t.Enabled = true

--print("Set to 'First' Value extension loaded.")

