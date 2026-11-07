-- Cheat Engine 7.7: Universal Dropdown Format Manager
-- Only selected record type is modified; no memory values are written.
-- Byte is the DEFAULT every time this dialog opens.
-- Extra mappings are transient; saved named presets persist separately.
-- Includes scope choice, numeric restore and scope count preview.
-- Modeless window: keep Cheat Engine usable while the formatter is open.
-- Child records are already included in AddressList.Count: no recursion.

local formats = {
  {name='No / Yes', zero='No', one='Yes'},
  {name='Disabled / Enabled', zero='Disabled', one='Enabled'},
  {name='Off / On', zero='Off', one='On'},
  {name='False / True', zero='False', one='True'},
  {name='Inactive / Active', zero='Inactive', one='Active'},
  {name='Custom Format'}
}
local types = {
  {name='Byte', id=vtByte}, {name='2 Bytes', id=vtWord},
  {name='4 Bytes', id=vtDword}, {name='Float', id=vtSingle},
  {name='Double', id=vtDouble}
}
local CUSTOM = #formats - 1 -- zero-based combo indexes
local SETTINGS = 'UniversalDropdownFormatManager'
local MAX_ROWS = 40
local MAX_PRESETS = 30

local function hexEncode(str)
  return (str:gsub('.', function(c) return string.format('%02X', string.byte(c)) end))
end
local function hexDecode(str)
  if not str or #str % 2 ~= 0 or str:find('[^%x]') then return '' end
  return (str:gsub('(%x%x)', function(pair) return string.char(tonumber(pair,16)) end))
end
local function encodeRows(rows)
  local parts = {}
  for i, row in ipairs(rows) do
    parts[i] = hexEncode(row.value) .. ':' .. hexEncode(row.label)
  end
  return table.concat(parts, ';')
end
local function decodeRows(raw)
  local rows = {}
  if type(raw) ~= 'string' then return rows end
  for part in raw:gmatch('[^;]+') do
    local a,b = part:match('^([%x]*):([%x]*)$')
    if a and b and #rows < MAX_ROWS then
      rows[#rows+1] = {value=hexDecode(a), label=hexDecode(b)}
    end
  end
  return rows
end
local function readNamedPresets()
  local result={}
  local ok,err=pcall(function()
    local st=getSettings(SETTINGS)
    local count=math.min(tonumber(st.Value['PresetCount']) or 0,MAX_PRESETS)
    for i=1,count do
      local name=hexDecode(st.Value['PresetName'..i])
      local rows=decodeRows(st.Value['PresetRows'..i])
      if name~='' and #rows>0 then result[#result+1]={name=name,rows=rows} end
    end
  end)
  if not ok then print('Dropdown Formatter presets read: '..tostring(err)) end
  return result
end
local function saveNamedPresets(presets)
  local ok,err=pcall(function()
    local st=getSettings(SETTINGS)
    local old=tonumber(st.Value['PresetCount']) or 0
    st.Value['PresetCount']=tostring(#presets)
    for i,p in ipairs(presets) do
      st.Value['PresetName'..i]=hexEncode(p.name)
      st.Value['PresetRows'..i]=encodeRows(p.rows)
    end
    for i=#presets+1,math.min(old,MAX_PRESETS) do
      st.Value['PresetName'..i]=''; st.Value['PresetRows'..i]=''
    end
  end)
  if not ok then print('Dropdown Formatter presets save: '..tostring(err)) end
  return ok
end
local function suitable(mr,typeID)
  return mr and mr.Type==typeID and not mr.IsGroupHeader and not mr.IsAddressGroupHeader
end
local function targets(addressList,typeID,scopeIndex)
  local out,seen={},{}
  local source={}
  if scopeIndex==1 then
    local ok,result=pcall(function() return addressList.getSelectedRecords() end)
    if not ok or type(result)~='table' then return out end
    -- CE's selected records may be a sparse table.
    for _,mr in pairs(result) do source[#source+1]=mr end
  else
    for i=0,addressList.Count-1 do source[#source+1]=addressList[i] end
  end
  for _,mr in ipairs(source) do
    if suitable(mr,typeID) and not seen[mr] then
      seen[mr]=true; out[#out+1]=mr
    end
  end
  return out
end
local function readPrefs()
  local selected, custom = 0, {}
  local ok, err = pcall(function()
    local s = getSettings(SETTINGS)
    selected = tonumber(s.Value['FormatIndex']) or 0
    custom = decodeRows(s.Value['CustomRows'])
    -- Extra rows are deliberately session-only. Ignore old saved ExtraRows.
  end)
  if not ok then print('Dropdown Formatter: settings read: ' .. tostring(err)) end
  -- Never restore Custom Format as the selected display format.
  -- Also resets legacy preferences that previously saved the Custom index.
  if selected < 0 or selected >= CUSTOM or selected % 1 ~= 0 then selected=0 end
  if #custom == 0 then custom={{value='0',label=''}, {value='1',label=''}} end
  -- Only keep custom labels for the base 0 and 1 values across restarts.
  local labels = {}
  for _, r in ipairs(custom) do
    if r.value == '0' or r.value == '1' then labels[r.value] = r.label end
  end
  custom = {{value='0', label=labels['0'] or ''}, {value='1', label=labels['1'] or ''}}
  return selected, custom, {}
end
local function savePrefs(selected, custom)
  local ok, err = pcall(function()
    local s=getSettings(SETTINGS)
    -- Custom Format can be applied now, but must not be the next session's selection.
    -- Other predefined format choices remain persistent.
    s.Value['FormatIndex']=tostring(selected == CUSTOM and 0 or selected)
    local baseLabels = {}
    for _, r in ipairs(custom) do
      if r.value == '0' or r.value == '1' then baseLabels[r.value] = r.label end
    end
    s.Value['CustomRows']=encodeRows({
      {value='0', label=baseLabels['0'] or ''},
      {value='1', label=baseLabels['1'] or ''}
    })
    -- Clear any leftover data from previous versions.
    s.Value['ExtraRows']=''
  end)
  if not ok then print('Dropdown Formatter: settings save: ' .. tostring(err)) end
  return ok
end
local function label(parent, caption, x, y, width)
  local c=createLabel(parent)
  c.Caption=caption; c.Left=x; c.Top=y; c.Width=width or 430
  return c
end
local function btn(parent, caption, x,y,w)
  local c=createButton(parent)
  c.Caption=caption; c.Left=x; c.Top=y; c.Width=w
  return c
end
local function edit(parent, value,x,y,w)
  local c=createEdit(parent)
  c.Text=value or ''; c.Left=x; c.Top=y; c.Width=w
  return c
end
local function validNumber(text, typeIndex)
  text=text:match('^%s*(.-)%s*$')
  if text == '' then return nil, 'A value is empty.' end
  local n=tonumber(text)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return nil, 'Invalid numeric value: ' .. text
  end
  if typeIndex <= 2 then
    if not text:match('^%d+$') or n % 1 ~= 0 then
      return nil, 'Only non-negative whole numbers are allowed for this type: ' .. text
    end
    local max=({255,65535,4294967295})[typeIndex+1]
    if n > max then return nil, 'Value out of range (max ' .. tostring(max) .. '): ' .. text end
    return string.format('%.0f',n)
  end
  -- Decimal syntax only; avoid scientific notation and locale-dependent commas.
  if not (text:match('^%d+%.?%d*$') or text:match('^%d*%.%d+$') or
          text:match('^%-%d+%.?%d*$') or text:match('^%-%d*%.%d+$')) then
    return nil, 'Enter a decimal number (example: -1.5 or 2.25): ' .. text
  end
  if typeIndex == 3 and math.abs(n) > 3.4028235e38 then
    return nil, 'Float value is out of range: ' .. text
  end
  return text
end
local activeFormatterWindow = nil

local function chooseFormat(onApply)
  local savedIndex, savedCustom, savedExtras = readPrefs()
  local presets=readNamedPresets()
  local addressList=getAddressList()
  if activeFormatterWindow then
    local ok = pcall(function() activeFormatterWindow.show(); activeFormatterWindow.bringToFront() end)
    if ok then return end
    activeFormatterWindow=nil
  end
  local form=createForm(false)
  -- Autorun-created CE forms can otherwise remain above the main window.
  -- Set these before showing the form so it behaves like a normal window.
  form.PopupMode='pmNone'
  form.FormStyle='fsNormal'
  activeFormatterWindow=form
  form.Caption='Universal Dropdown Formatter'
  form.Width=540; form.Height=480; form.Position='poScreenCenter'

  label(form,'Apply to data type:',18,14)
  local typePicker=createComboBox(form)
  typePicker.Left=18; typePicker.Top=36; typePicker.Width=225; typePicker.Style='csDropDownList'
  for _, item in ipairs(types) do typePicker.Items.add(item.name) end
  typePicker.ItemIndex=0 -- ALWAYS reset to Byte on popup open

  label(form,'Display format:',264,14)
  local formatPicker=createComboBox(form)
  formatPicker.Left=264; formatPicker.Top=36; formatPicker.Width=245; formatPicker.Style='csDropDownList'
  for _, item in ipairs(formats) do formatPicker.Items.add(item.name) end

  label(form,'Action:',18,75,130)
  local actionPicker=createComboBox(form)
  actionPicker.Left=18; actionPicker.Top=95; actionPicker.Width=226; actionPicker.Style='csDropDownList'
  actionPicker.Items.add('Apply Formatting')
  actionPicker.Items.add('Restore Numeric Display')
  actionPicker.ItemIndex=0
  label(form,'Apply scope:',264,75,130)
  local scopePicker=createComboBox(form)
  scopePicker.Left=264; scopePicker.Top=95; scopePicker.Width=245; scopePicker.Style='csDropDownList'
  scopePicker.Items.add('All matching records')
  scopePicker.Items.add('Selected records only')
  scopePicker.ItemIndex=0
  label(form,'Values and display labels (use Add Value for more):',18,129)
  label(form,'Value',28,153,160)
  label(form,'Display label',200,153,240)

  -- Scroll only after 5 visible mappings; otherwise shrink to fit rows.
  local scroller=createComponentClass('TScrollBox',form)
  scroller.Parent=form
  scroller.Left=18; scroller.Top=174; scroller.Width=491; scroller.Height=70
  scroller.AutoScroll=true
  -- LCL defaults to updating after the mouse is released. Track live instead.
  pcall(function() scroller.VertScrollBar.Tracking=true end)
  pcall(function() scroller.VertScrollBar.Smooth=true end)
  pcall(function() scroller.VertScrollBar.Increment=30 end)

  local rows={}
  local updateLayout -- initialized after the footer buttons are created
  local function collectRows()
    local result={}
    for _,r in ipairs(rows) do
      result[#result+1]={value=r.value.Text,label=r.text.Text}
    end
    return result
  end
  local function reposition()
    for i,r in ipairs(rows) do
      local y=5+(i-1)*30
      r.value.Top=y; r.text.Top=y; r.remove.Top=y-1
      r.remove.Caption='Remove'
    end
    if updateLayout then updateLayout() end
  end
  local updatePreview
  local function deleteRow(index)
    if #rows <= 1 then return end
    local item=table.remove(rows,index)
    item.value.destroy(); item.text.destroy(); item.remove.destroy()
    reposition()
    if updatePreview then updatePreview() end
  end
  local function addRow(v,t)
    if #rows >= MAX_ROWS then
      showMessage('Maximum '..MAX_ROWS..' value mappings are supported.')
      return
    end
    local r={}
    r.value=edit(scroller,v,7,5,155)
    r.text=edit(scroller,t,178,5,207)
    r.remove=btn(scroller,'Remove',393,4,72)
    rows[#rows+1]=r
    r.remove.OnClick=function()
      for i,current in ipairs(rows) do
        if current==r then deleteRow(i); break end
      end
    end
    r.value.OnChange=function() if updatePreview then updatePreview() end end
    r.text.OnChange=function() if updatePreview then updatePreview() end end
    reposition()
  end
  local function clearRows()
    while #rows>0 do
      local r=table.remove(rows)
      r.value.destroy(); r.text.destroy(); r.remove.destroy()
    end
  end
  local customDraft=savedCustom
  local function presetAt(index)
    local p=index-#formats+1
    return presets[p]
  end
  local function refreshFormatItems(chosenName)
    formatPicker.Items.clear()
    for _,entry in ipairs(formats) do formatPicker.Items.add(entry.name) end
    for _,entry in ipairs(presets) do formatPicker.Items.add('Saved: '..entry.name) end
    if chosenName then
      for i,p in ipairs(presets) do
        if p.name==chosenName then formatPicker.ItemIndex=#formats+i-1; return end
      end
    end
    formatPicker.ItemIndex=0
  end
  local extraDraft=savedExtras
  local activeIndex=-1
  local function loadFormat(index)
    clearRows()
    local entries={}
    if index>=#formats then
      local p=presetAt(index)
      entries=p and p.rows or {}
    elseif index==CUSTOM then
      entries=customDraft
    else
      entries={{value='0',label=formats[index+1].zero},
               {value='1',label=formats[index+1].one}}
      for _,entry in ipairs(extraDraft) do entries[#entries+1]=entry end
    end
    for _,entry in ipairs(entries) do addRow(entry.value,entry.label) end
    if #rows==0 then addRow('0','') end
    -- Preset basic labels remain fixed; extra rows are editable.
    for i,r in ipairs(rows) do
      local basic=index<CUSTOM and i<=2
      r.value.Enabled=not basic
      r.text.Enabled=not basic
      r.remove.Enabled=not basic
    end
  end
  local function changeFormat()
    if activeIndex>=0 then
      local entries=collectRows()
      if activeIndex==CUSTOM then
        customDraft=entries
      elseif activeIndex>=#formats then
        -- Named preset edits are temporary until the user clicks Save Preset.
      else
        extraDraft={}
        for i=3,#entries do extraDraft[#extraDraft+1]=entries[i] end
      end
    end
    activeIndex=formatPicker.ItemIndex
    if activeIndex < 0 then return end
    loadFormat(activeIndex)
    if updatePreview then updatePreview() end
  end

  local addButton=btn(form,'+ Add Value',18,407,110)
  addButton.OnClick=function() addRow('',''); if updatePreview then updatePreview() end end
  local preview=label(form,'Preview: 0 -> No  |  1 -> Yes',18,485,490)
  local notice=label(form,'Labels change table display only; memory values are not modified.',18,511,500)
  local apply=btn(form,'Apply',294,539,100)
  local cancel=btn(form,'Cancel',407,539,100)
  cancel.OnClick=function() form.close() end

  local presetName=edit(form,'',18,434,226)
  local savePreset=btn(form,'Save Preset',264,434,116)
  local deletePreset=btn(form,'Delete Preset',391,434,118)
  pcall(function() presetName.TextHint='Preset name' end)
  local countLabel=label(form,'Matching records: 0',18,461,490)
  local function refreshCount()
    if not addressList then countLabel.Caption='Address list unavailable'; return end
    local idx=typePicker.ItemIndex
    if idx<0 then return end
    local matches=targets(addressList,types[idx+1].id,scopePicker.ItemIndex)
    countLabel.Caption='Matching '..types[idx+1].name..' records in scope: '..#matches
  end
  typePicker.OnChange=refreshCount
  scopePicker.OnChange=refreshCount
  actionPicker.OnChange=function()
    local restore=actionPicker.ItemIndex==1
    scroller.Enabled=not restore
    addButton.Enabled=not restore
    formatPicker.Enabled=not restore
    presetName.Enabled=not restore
    savePreset.Enabled=not restore
    deletePreset.Enabled=not restore
    refreshCount()
  end
  savePreset.OnClick=function()
    if actionPicker.ItemIndex==1 then return end
    local name=presetName.Text:match('^%s*(.-)%s*$')
    if #name==0 or #name>45 or name:find('[\r\n]') then
      showMessage('Enter a preset name (1-45 characters, no newlines).'); return
    end
    for _,p in ipairs(presets) do
      if p.name:lower()==name:lower() then
        showMessage('Preset already exists. Delete it first to replace it.'); return
      end
    end
    if #presets>=MAX_PRESETS then showMessage('Preset limit reached ('..MAX_PRESETS..').'); return end
    local entries=collectRows()
    if #entries==0 then showMessage('Add a mapping before saving.'); return end
    -- Validate preset for the currently chosen type before permanently saving.
    local seen={}; local validated={}
    for i,r in ipairs(entries) do
      local number,err=validNumber(r.value,typePicker.ItemIndex)
      if not number then showMessage('Row '..i..': '..err); return end
      if r.label=='' or r.label:find('[\r\n:]') then
        showMessage('Row '..i..': Invalid label.'); return
      end
      if seen[tonumber(number)] then showMessage('Duplicate value in row '..i); return end
      seen[tonumber(number)]=true
      validated[#validated+1]={value=number,label=r.label}
    end
    presets[#presets+1]={name=name,rows=validated}
    if not saveNamedPresets(presets) then
      table.remove(presets); showMessage('Preset could not be saved.'); return
    end
    activeIndex=-1
    refreshFormatItems(name)
    changeFormat()
    presetName.Text=''
    showMessage('Saved preset: '..name)
  end
  deletePreset.OnClick=function()
    local idx=formatPicker.ItemIndex
    if idx<#formats then showMessage('Choose a saved preset to delete.'); return end
    local p=presetAt(idx)
    if not p then return end
    local removed=table.remove(presets,idx-#formats+1)
    if not saveNamedPresets(presets) then
      table.insert(presets,idx-#formats+1,removed)
      showMessage('Could not delete preset.'); return
    end
    activeIndex=-1
    refreshFormatItems()
    changeFormat()
    showMessage('Deleted preset: '..removed.name)
  end

  -- A 2-row dialog starts compact. Rows 3-5 grow it in 30px steps.
  -- The list is capped at 5 visible rows; for 6+ the TScrollBox scrolls.
  -- Footer coordinates track the bottom of the list so nothing overlaps.
  updateLayout=function()
    local visible=math.min(math.max(#rows,2),5)
    local listHeight=visible*30+10
    local delta=listHeight-225 -- relative to the original dialog layout
    scroller.Height=listHeight
    addButton.Top=407+delta
    presetName.Top=434+delta
    savePreset.Top=434+delta
    deletePreset.Top=434+delta
    countLabel.Top=461+delta
    preview.Top=485+delta
    notice.Top=511+delta
    apply.Top=539+delta
    cancel.Top=539+delta
    -- ClientHeight avoids the excessive bottom gap caused by OS title-bar sizes.
    form.ClientHeight=apply.Top+apply.Height+15
    -- Keep the scroll position valid when removing rows or changing presets.
    if #rows<=5 then
      scroller.VertScrollBar.Position=0
    end
  end

  updatePreview=function()
    local fragments={}
    for i,r in ipairs(rows) do
      if i<=3 then
        local v=r.value.Text~='' and r.value.Text or '?'
        local t=r.text.Text~='' and r.text.Text or '(label needed)'
        fragments[#fragments+1]=v..' -> '..t
      end
    end
    local suffix=#rows>3 and ('  (+'..(#rows-3)..' more)') or ''
    preview.Caption='Preview: '..table.concat(fragments,'  |  ')..suffix
  end
  formatPicker.OnChange=changeFormat
  refreshFormatItems()
  formatPicker.ItemIndex=savedIndex
  changeFormat()
  refreshCount()
  updateLayout()
  form.OnActivate=function() refreshCount() end

  apply.OnClick=function()
    local typeIdx=typePicker.ItemIndex
    local formatIdx=formatPicker.ItemIndex
    if typeIdx<0 or typeIdx>=#types then showMessage('Select a data type.'); return end
    if actionPicker.ItemIndex==1 then
      local choice={typeIndex=typeIdx,scopeIndex=scopePicker.ItemIndex,mode='restore'}
      form.close()
      onApply(choice)
      return
    end
    if formatIdx<0 or formatIdx>=#formats+#presets then showMessage('Select a format.'); return end
    local entries=collectRows()
    if #entries==0 then showMessage('Add at least one mapping.'); return end
    local seen={}
    local validated={}
    for i,r in ipairs(entries) do
      local number,err=validNumber(r.value,typeIdx)
      if not number then showMessage('Row '..i..': '..err); return end
      if r.label=='' or r.label:find('[\r\n]') or r.label:find(':',1,true) then
        showMessage('Row '..i..': Label must not be empty or contain a colon/newline.')
        return
      end
      local key=tonumber(number)
      if seen[key] then
        showMessage('Duplicate numeric value in rows '..seen[key]..' and '..i..'.')
        return
      end
      seen[key]=i
      validated[i]={value=number,label=r.label}
    end
    if formatIdx==CUSTOM then
      customDraft=entries
    elseif formatIdx<#formats then
      extraDraft={}
      for i=3,#entries do extraDraft[#extraDraft+1]=entries[i] end
    end
    local choice={typeIndex=typeIdx, scopeIndex=scopePicker.ItemIndex, mode='apply', formatIndex=formatIdx, entries=validated,
            custom=customDraft, extras=extraDraft}
    form.close()
    onApply(choice)
  end
  form.OnClose=function()
    if activeFormatterWindow==form then activeFormatterWindow=nil end
    return caFree
  end
  form.show()
end

local function processChoice(choice)
  local addressList=getAddressList()
  if not addressList then showMessage('Address list is unavailable.'); return end
  local expectedType=types[choice.typeIndex+1]
  local records=targets(addressList,expectedType.id,choice.scopeIndex)
  local scope=choice.scopeIndex==1 and 'selected records' or 'cheat table'
  if #records==0 then
    beep()
    showMessage('No '..expectedType.name..' addresses found in the '..scope..'.')
    return
  end
  local dropdownText=''
  if choice.mode=='apply' then
    local dropdown={}
    for i,r in ipairs(choice.entries) do dropdown[i]=r.value..':'..r.label end
    dropdownText=table.concat(dropdown,'\n')
  end
  local applied,failed=0,0
  for _,mr in ipairs(records) do
    local ok,err=pcall(function()
      if choice.mode=='restore' then
        mr.DropDownList.Text=''
        mr.DropDownReadOnly=false
        mr.DropDownDescriptionOnly=false
        mr.DisplayAsDropDownListItem=false
      else
        mr.DropDownList.Text=dropdownText
        mr.DropDownReadOnly=true
        mr.DropDownDescriptionOnly=true
        mr.DisplayAsDropDownListItem=true
      end
    end)
    if ok then applied=applied+1 else
      failed=failed+1
      print('Dropdown Formatter error ('..tostring(mr.Description)..'): '..tostring(err))
    end
  end
  local verb=choice.mode=='restore' and 'restored numeric display for' or 'applied dropdown to'
  if choice.mode=='apply' then
    local saved=savePrefs(choice.formatIndex<#formats and choice.formatIndex or CUSTOM,choice.custom)
    if not saved then print('Dropdown Formatter: preferences could not be saved.') end
  end
  if failed==0 then
    showMessage(string.format('Successfully %s %d %s record(s).',verb,applied,expectedType.name))
  else
    showMessage(string.format('%d %s record(s) updated; %d failed. See Lua Engine.',applied,expectedType.name,failed))
  end
end

local function applyFormatter()
  chooseFormat(processChoice)
end

-- Reuse original menu object so rerunning this file does not add duplicates.
if ByteDropdownMenu==nil then
  ByteDropdownMenu=createMenuItem(MainForm.Menu)
  MainForm.Menu.Items.add(ByteDropdownMenu)
end
ByteDropdownMenu.Caption='Dropdown Formatter'
ByteDropdownMenu.OnClick=applyFormatter
