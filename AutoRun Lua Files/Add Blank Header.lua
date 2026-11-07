-- Cheat Engine 7.7 autorun: Add named group header, optionally group selected records.
-- Intentionally preserve an empty Address on new headers.

local function addHeader(sender)
  local al = getAddressList()
  if not al then return end

  local name = inputQuery('Add Header', 'Header name (leave empty for a blank header):', 'New Header')
  if name == nil then return end -- cancelled
  name = name:match('^%s*(.-)%s*$')

  local selected = {}
  local okSelection, selection = pcall(function() return al.getSelectedRecords() end)
  if okSelection and type(selection) == 'table' then
    for _, record in ipairs(selection) do
      if record and not record.IsGroupHeader then selected[#selected+1] = record end
    end
  end

  local groupSelected = false
  if #selected > 0 then
    groupSelected = messageDialog('Move ' .. #selected .. ' selected non-header record(s) into the new header?', mtConfirmation, mbYes, mbNo) == mrYes
  end

  local header
  local ok, err = pcall(function()
    header = al.createMemoryRecord()
    header.IsGroupHeader = true
    header.Description = name
    header.Address = ''
    if groupSelected then
      for _, record in ipairs(selected) do
        record.appendToEntry(header)
      end
    end
  end)
  if not ok then
    showMessage('Could not create or populate header: ' .. tostring(err))
  end
end

-- Reuse the menu item on script reload; always refresh callback.
if HeaderMenu == nil then
  HeaderMenu = createMenuItem(MainForm.Menu)
  HeaderMenu.Caption = 'Add Header'
  MainForm.Menu.Items.add(HeaderMenu)
end
HeaderMenu.OnClick = addHeader
