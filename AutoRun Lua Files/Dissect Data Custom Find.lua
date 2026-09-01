

-- ============================================================================
-- Name: Dissect Data Custom Find
-- Version: 2.4
-- Description: Intercepts the native 'Find' window in Structure Dissect.
--              - Set 'Value (Custom)' as the default search option.
--              - Removed all successful/info print logs to keep console clean,
--                retaining only critical [Error] messages.
-- ============================================================================

if _G.StructFindModifierTimer ~= nil then
    _G.StructFindModifierTimer.destroy()
    _G.StructFindModifierTimer = nil
end

local modifierTimer = createTimer(nil)
_G.StructFindModifierTimer = modifierTimer
modifierTimer.Interval = 200

local lastCustomSearchIndex = -1

local function GetActiveDissectForm()
    if type(getDissectForm) == "function" then return getDissectForm() end
    if type(getStructuresDissectForm) == "function" then return getStructuresDissectForm() end

    for i = 0, getFormCount() - 1 do
        local form = getForm(i)
        if form and form.ClassName == 'TfrmStructures2' then
            return form
        end
    end
    return nil
end

local function GetBaseAddress(sd)
    local baseAddress = nil
    pcall(function()
        if sd.Column and sd.Column[0] then
            local addressText = sd.Column[0].AddressText
            if addressText then
                local cleanAddress = addressText:match("%[?([%x]+)%]?")
                if cleanAddress then
                    baseAddress = tonumber(cleanAddress, 16)
                end
            end
            if not baseAddress then
                baseAddress = sd.Column[0].Address
            end
        end
    end)
    return baseAddress
end

local function ReadElementValue(baseAddress, element)
    local offset = element.Offset or element.offset or 0
    local vType = element.Vartype or element.vartype or 2
    local addr = baseAddress + offset
    local val = nil

    if vType == 12 then val = readPointer(addr)
    elseif vType == 4 then val = readFloat(addr)
    elseif vType == 5 then val = readDouble(addr)
    elseif vType == 3 then val = readQword(addr)
    elseif vType == 6 or vType == 7 or vType == 8 then val = readString(addr, 256)
    elseif vType == 0 then
        local b = readBytes(addr, 1)
        if type(b) == "table" then val = b[1] else val = b end
    elseif vType == 1 then val = readSmallInteger(addr)
    else val = readInteger(addr) end

    return val
end

modifierTimer.OnTimer = function(t)
    local formCount = getFormCount()

    for i = 0, formCount - 1 do
        local f = getForm(i)

        if f and f.Caption == 'Find' then
            local alreadyModified = false
            local editSearchText, btnFindNative, rbForward, rbBackward, cancelBtn

            for j = 0, f.ComponentCount - 1 do
                local c = f.Component[j]
                if c.Name == 'AdvSearchComboBox' then alreadyModified = true end
                if c.ClassName == 'TEdit' then editSearchText = c end
                if c.ClassName == 'TButton' and c.Caption == 'Find' then btnFindNative = c end
                if c.ClassName == 'TButton' and c.Caption == 'Cancel' then cancelBtn = c end
                if c.ClassName == 'TRadioButton' and string.find(c.Caption, 'Forward') then rbForward = c end
                if c.ClassName == 'TRadioButton' and string.find(c.Caption, 'Backward') then rbBackward = c end
            end

            if not alreadyModified and btnFindNative and editSearchText then
                local sd = GetActiveDissectForm()
                if sd ~= nil and sd.Visible then

                    local maxY = 0
                    for j = 0, f.ComponentCount - 1 do
                        local c = f.Component[j]
                        if c.Caption ~= 'Cancel' and not string.find(c.Name or "", "AdvSearch") then
                            local bottomEdge = c.Top + c.Height
                            if bottomEdge > maxY then maxY = bottomEdge end
                        end
                    end

                    local startY = maxY + 15

                    local lblSearchType = createLabel(f)
                    lblSearchType.Name = 'AdvSearchLabel'
                    lblSearchType.Caption = 'Search By:'
                    lblSearchType.Left = 10
                    lblSearchType.Top = startY + 3

                    local comboSearchType = createComboBox(f)
                    comboSearchType.Name = 'AdvSearchComboBox'
                    comboSearchType.Left = 80
                    comboSearchType.Top = startY
                    comboSearchType.Width = 160
                    comboSearchType.Items.add('Name/Offset (Custom)')
                    comboSearchType.Items.add('Address (Custom)')
                    comboSearchType.Items.add('Value (Custom)')
                    comboSearchType.Items.add('All Text (Native)')
                    -- Set default to 'Value (Custom)' which is index 2
                    comboSearchType.ItemIndex = 2
                    comboSearchType.Style = csDropDownList

                    local cbKeepSelection = createCheckBox(f)
                    cbKeepSelection.Name = 'AdvSearchKeepSel'
                    cbKeepSelection.Caption = 'Keep previous selections'
                    cbKeepSelection.Left = 10
                    cbKeepSelection.Top = startY + 30
                    cbKeepSelection.Width = 200
                    cbKeepSelection.Checked = false

                    local neededHeight = cbKeepSelection.Top + cbKeepSelection.Height + 15
                    if cancelBtn then
                        cancelBtn.Top = neededHeight
                        neededHeight = cancelBtn.Top + cancelBtn.Height + 15
                    end
                    f.ClientHeight = neededHeight

                    local nativeFindOnClick = btnFindNative.OnClick

                    local btnFindNext = createButton(f)
                    btnFindNext.Name = 'AdvSearchNextBtn'
                    btnFindNext.Caption = 'Find Next'
                    btnFindNext.Width = 75
                    btnFindNext.Height = btnFindNative.Height
                    btnFindNext.Left = btnFindNative.Left - btnFindNext.Width - 10
                    btnFindNext.Top = btnFindNative.Top

                    local btnFindPrev = createButton(f)
                    btnFindPrev.Name = 'AdvSearchPrevBtn'
                    btnFindPrev.Caption = 'Find Prev'
                    btnFindPrev.Width = 75
                    btnFindPrev.Height = btnFindNative.Height
                    btnFindPrev.Left = btnFindNext.Left - btnFindPrev.Width - 10
                    btnFindPrev.Top = btnFindNative.Top

                    local function DoCustomSearch(directionForward)
                        sd = GetActiveDissectForm()
                        if not sd then return end

                        local baseAddress = GetBaseAddress(sd)
                        if not baseAddress or baseAddress == 0 then
                            print("[Error] Could not retrieve Base Address.")
                            return
                        end

                        local st = nil
                        pcall(function() st = sd.mainStruct end)
                        if not st then
                            print("[Error] Could not access 'mainStruct'.")
                            return
                        end

                        local elementCount = 0
                        pcall(function()
                            if type(st.ElementCount) == "number" then elementCount = st.ElementCount end
                        end)
                        if elementCount == 0 then
                            pcall(function()
                                if st.Element then
                                    local c = 0
                                    while st.Element[c] do c = c + 1 end
                                    elementCount = c
                                end
                            end)
                        end

                        if elementCount == 0 then return end

                        local rawSearchTerm = string.match(editSearchText.Text, "^%s*(.-)%s*$")
                        if rawSearchTerm == "" then return end
                        local searchTerm = string.lower(rawSearchTerm)
                        local searchType = comboSearchType.ItemIndex

                        local sNum = nil
                        local sHex = nil

                        if string.sub(searchTerm, 1, 2) == "0x" then
                            sHex = tonumber(string.sub(searchTerm, 3), 16)
                        elseif string.match(searchTerm, "^[0-9]+$") then
                            sNum = tonumber(searchTerm)
                        elseif string.match(searchTerm, "^[0-9a-fA-F]+$") then
                            sHex = tonumber(searchTerm, 16)
                        else
                            sNum = tonumber(searchTerm)
                        end

                        local startIndex = lastCustomSearchIndex
                        if directionForward then
                            startIndex = startIndex + 1
                            if startIndex >= elementCount then startIndex = 0 end
                        else
                            startIndex = startIndex - 1
                            if startIndex < 0 then startIndex = elementCount - 1 end
                        end

                        local found = false
                        local idx = startIndex

                        repeat
                            local el = nil
                            pcall(function() el = st.Element[idx] end)

                            if el then
                                local match = false
                                local eOffset = el.Offset or el.offset or 0
                                local eName = el.Name or el.name or ""

                                if searchType == 0 then
                                    local nameStr = string.lower(eName)
                                    local offsetStr = string.lower(string.format("%X", eOffset))
                                    if string.find(nameStr, searchTerm) or string.find(offsetStr, searchTerm) then match = true end

                                elseif searchType == 1 then
                                    local exactAddr = string.lower(string.format("%X", baseAddress + eOffset))
                                    if string.find(exactAddr, searchTerm) then match = true end

                                elseif searchType == 2 then
                                    local val = ReadElementValue(baseAddress, el)
                                    if val ~= nil then
                                        if type(val) == "number" then
                                            if (sNum ~= nil and val == sNum) or (sHex ~= nil and val == sHex) then
                                                match = true
                                            end
                                        elseif type(val) == "string" then
                                            if string.find(string.lower(val), searchTerm) then
                                                match = true
                                            end
                                        end
                                    end
                                end

                                if match then
                                    lastCustomSearchIndex = idx
                                    found = true

                                    pcall(function()
                                        local tv = sd.tvStructureView
                                        if tv and tv.Items then
                                            if not cbKeepSelection.Checked then
                                                pcall(function()
                                                    local ms = tv.MultiSelect
                                                    tv.MultiSelect = false
                                                    tv.Selected = nil
                                                    tv.MultiSelect = ms
                                                end)

                                                for k = 0, tv.Items.Count - 1 do
                                                    local n = tv.Items[k]
                                                    if n then
                                                        pcall(function() n.MultiSelected = false end)
                                                        pcall(function() n.Selected = false end)
                                                    end
                                                end
                                            end

                                            for k = 0, tv.Items.Count - 1 do
                                                local node = tv.Items[k]
                                                if node and node.Level == 1 and node.Index == idx then
                                                    pcall(function()
                                                        if cbKeepSelection.Checked then
                                                            node.MultiSelected = true
                                                        end
                                                        node.Selected = true
                                                        node.Focused = true
                                                        tv.Selected = node
                                                    end)
                                                    if node.MakeVisible then node.MakeVisible() end
                                                    break
                                                end
                                            end
                                        end
                                    end)

                                    pcall(function() sd.BringToFront() end)
                                    break
                                end
                            end

                            if directionForward then idx = (idx + 1) % elementCount
                            else idx = (idx - 1 + elementCount) % elementCount end

                        until idx == startIndex
                    end

                    btnFindNative.OnClick = function(sender)
                        if comboSearchType.ItemIndex == 3 then
                            if nativeFindOnClick then nativeFindOnClick(sender) end
                        else
                            local isForward = true
                            if rbBackward and rbBackward.Checked then isForward = false end
                            DoCustomSearch(isForward)
                        end
                    end

                    btnFindNext.OnClick = function(sender)
                        if comboSearchType.ItemIndex == 3 then
                            if rbForward then rbForward.Checked = true end
                            if nativeFindOnClick then nativeFindOnClick(btnFindNative) end
                        else
                            DoCustomSearch(true)
                        end
                    end

                    btnFindPrev.OnClick = function(sender)
                        if comboSearchType.ItemIndex == 3 then
                            if rbBackward then rbBackward.Checked = true end
                            if nativeFindOnClick then nativeFindOnClick(btnFindNative) end
                        else
                            DoCustomSearch(false)
                        end
                    end

                end
            end
        end
    end
end

--print("NativeFindWindowModifier v2.4 loaded.")
