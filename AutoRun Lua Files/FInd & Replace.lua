local function plainReplace(str, findStr, replaceStr)
    if not str or str == "" or findStr == "" then return str, 0 end
    local result = ""
    local count = 0
    local startPos = 1
    
    while true do
        local s, e = str:find(findStr, startPos, true)
        if not s then
            result = result .. str:sub(startPos)
            break
        end
        result = result .. str:sub(startPos, s - 1) .. replaceStr
        startPos = e + 1
        count = count + 1
    end
    return result, count
end

local function replaceRecord(mr, findStr, replaceStr)
    local count = 0
    
    -- Description Replace
    if mr.Description then
        local newDesc, c = plainReplace(mr.Description, findStr, replaceStr)
        if c > 0 then
            mr.Description = newDesc
            count = count + c
        end
    end
    
    -- Address Replace
    if mr.Address then
        local newAddr, c = plainReplace(mr.Address, findStr, replaceStr)
        if c > 0 then
            -- 1. Save old pointer offsets
            local offsetCount = mr.OffsetCount or 0
            local offsets = {}
            if offsetCount > 0 then
                for j = 0, offsetCount - 1 do
                    offsets[j] = mr.Offset[j]
                end
            end
            
            -- 2. Update Address (CE clears offsets here automatically)
            mr.Address = newAddr
            count = count + c
            
            -- 3. Restore pointer offsets
            if offsetCount > 0 then
                mr.OffsetCount = offsetCount
                for j = 0, offsetCount - 1 do
                    mr.Offset[j] = offsets[j]
                end
            end
        end
    end

    -- Child records search
    for i = 0, mr.Count - 1 do
        count = count + replaceRecord(mr.Child[i], findStr, replaceStr)
    end
    
    return count
end

local function FindAndReplace(sender)
    local form = createForm(true)
    form.Caption = "Find & Replace"
    form.Width = 300
    form.Height = 140
    form.Position = "poScreenCenter"
    form.BorderStyle = "bsDialog"

    local lblFind = createLabel(form)
    lblFind.Caption = "Find what:"
    lblFind.Left = 10
    lblFind.Top = 15

    local edtFind = createEdit(form)
    edtFind.Left = 100
    edtFind.Top = 12
    edtFind.Width = 180

    local lblReplace = createLabel(form)
    lblReplace.Caption = "Replace with:"
    lblReplace.Left = 10
    lblReplace.Top = 45

    local edtReplace = createEdit(form)
    edtReplace.Left = 100
    edtReplace.Top = 42
    edtReplace.Width = 180

    local btnReplaceAll = createButton(form)
    btnReplaceAll.Caption = "Replace All"
    btnReplaceAll.Left = 100
    btnReplaceAll.Top = 80
    btnReplaceAll.Width = 90

    btnReplaceAll.OnClick = function()
        local findStr = edtFind.Text
        local replaceStr = edtReplace.Text

        if findStr == "" then
            showMessage("Please enter a string to find.")
            return
        end

        local al = getAddressList()
        local totalReplaced = 0

        for i = 0, al.Count - 1 do
            totalReplaced = totalReplaced + replaceRecord(al[i], findStr, replaceStr)
        end

        showMessage(string.format("Replaced %d occurrence(s).", totalReplaced))
    end

    form.show()
end

if ReplaceMenu == nil then
    ReplaceMenu = createMenuItem(MainForm.Menu)
    ReplaceMenu.Caption = "Find And Replace"
    ReplaceMenu.OnClick = FindAndReplace
    MainForm.Menu.Items.add(ReplaceMenu)
end