-- Cheat Engine 7.7 | CT Color Formatter
-- Colors from the supplied color format.CT, in Cheat Engine BGR order.
-- Auto mode colors new records and recolors scripts when their names change.
-- Undo restores colors from the most recent manual Apply/White action.

local SCRIPT_YELLOW = 0x80FFFF
local MONO_COLOR = 0xFF8080
local INSTANCE_COLOR = 0x8000FF -- from color.CT
local ADDRESS_WHITE = 0xFFFFFF
local HEADER_COLORS = {0x80FF80, 0x80FF00, 0xFFFF80, 0xFF8000, 0xC080FF}

-- Persistent within the CE session, including autorun script reloads.
CTColorState = CTColorState or {auto=true, seen={}, undo=nil}
local state = CTColorState
state.auto = false -- enabled by default when the autorun script loads

local function isHeader(mr)
  return mr.IsGroupHeader or mr.IsAddressGroupHeader
end

local function expectedColor(mr, white)
  if white then return ADDRESS_WHITE end
  if isHeader(mr) then
    local level, parent, safety = 1, mr.Parent, 0
    while parent and safety < 1000 do
      if isHeader(parent) then level = level + 1 end
      parent = parent.Parent
      safety = safety + 1
    end
    return HEADER_COLORS[math.min(level, #HEADER_COLORS)]
  end
  -- Instance: exact name, 8 Bytes, displayed in hexadecimal.
  -- The Address may be a symbol such as health_ptr; it need not be a literal hex number.
  local name = tostring(mr.Description or ''):match('^%s*(.-)%s*$'):lower()
  if name == 'instance' and mr.Type == vtQword and mr.ShowAsHex then
    return INSTANCE_COLOR
  end
  if mr.Type == vtAutoAssembler then
    return name == 'initialize mono' and MONO_COLOR or SCRIPT_YELLOW
  end
  return ADDRESS_WHITE
end

local function recordKey(mr)
  -- CE record IDs remain stable while a record exists.
  return tostring(mr.ID)
end

local function allRecords(al)
  local result = {}
  for i=0, al.Count-1 do
    local mr = al[i]
    if mr then result[#result+1] = mr end
  end
  return result
end

local function normalize(color)
  local n = tonumber(color)
  return n and (n % 0x1000000) or nil
end

local function applyColors(white)
  local al = getAddressList()
  if not al then showMessage('Address list is unavailable.') return end
  local records = allRecords(al)
  local changed, failed, snapshot = 0, 0, {}
  for _, mr in ipairs(records) do
    local ok, err = pcall(function()
      local before = tonumber(mr.Color)
      local wanted = expectedColor(mr, white)
      if normalize(before) ~= wanted then
        mr.Color = wanted
        snapshot[#snapshot+1] = {record=mr, id=recordKey(mr), color=before}
        changed = changed + 1
      end
    end)
    if not ok then
      failed = failed + 1
      print('CT Color Formatter: ' .. tostring(mr.Description) .. ': ' .. tostring(err))
    end
  end
  if #snapshot > 0 then state.undo = snapshot end
  if failed > 0 then
    showMessage(string.format('Updated: %d | Failed: %d. See Lua Engine output.', changed, failed))
  elseif changed == 0 then
    showMessage('No changes needed.')
  else
    showMessage(string.format('Updated colors on %d record(s).', changed))
  end
end

local function undoLast()
  local snapshot = state.undo
  if not snapshot or #snapshot == 0 then
    showMessage('Nothing to undo.')
    return
  end
  local al = getAddressList()
  if not al then showMessage('Address list is unavailable.') return end
  local live = {}
  for i=0, al.Count-1 do
    local mr=al[i]
    if mr then live[recordKey(mr)] = mr end
  end
  local restored, failed = 0, 0
  for _, entry in ipairs(snapshot) do
    local mr = live[entry.id]
    if mr and mr == entry.record and entry.color ~= nil then
      local ok, err = pcall(function() mr.Color = entry.color end)
      if ok then restored=restored+1 else
        failed=failed+1
        print('Undo color error: ' .. tostring(err))
      end
    end
  end
  state.undo = nil
  showMessage(string.format('Restored colors on %d record(s).%s',
    restored, failed > 0 and (' Failed: ' .. failed) or ''))
end

local function recordSignature(mr)
  -- A changed description must trigger recoloring (not just newly created records).
  -- Parent/header changes are tracked too, so moving a header updates its level.
  local parent = mr.Parent
  return tostring(mr.Description or '') .. '\0' ..
         tostring(mr.Type) .. '\0' ..
         tostring(mr.ShowAsHex) .. '\0' ..
         tostring(isHeader(mr)) .. '\0' ..
         tostring(parent and parent.ID or '') .. '\0' ..
         tostring(expectedColor(mr, false))
end

local function rememberCurrentRecords()
  local al = getAddressList()
  state.seen = {}
  if not al then return end
  for i=0, al.Count-1 do
    local mr = al[i]
    if mr then
      local ok, signature = pcall(recordSignature, mr)
      if ok then state.seen[recordKey(mr)] = {record=mr, signature=signature} end
    end
  end
end

local function autoTick()
  if not state.auto then return end
  local al = getAddressList()
  if not al then return end
  local current = {}
  for i=0, al.Count-1 do
    local mr = al[i]
    if mr then
      local key = recordKey(mr)
      local ok, err = pcall(function()
        local signature = recordSignature(mr)
        local old = state.seen[key]
        current[key] = {record=mr, signature=signature}
        if not old or old.record ~= mr or old.signature ~= signature then
          local wanted = expectedColor(mr, false)
          if normalize(mr.Color) ~= wanted then mr.Color = wanted end
        end
      end)
      if not ok then print('Auto color error: ' .. tostring(err)) end
    end
  end
  state.seen = current
end

local function addItem(parent, globalName, caption, handler)
  if _G[globalName] == nil then
    _G[globalName] = createMenuItem(parent)
    parent.add(_G[globalName])
  end
  local item = _G[globalName]
  item.Caption = caption
  item.OnClick = handler
  return item
end

if CTColorFormatterMenu == nil then
  CTColorFormatterMenu = createMenuItem(MainForm.Menu)
  MainForm.Menu.Items.add(CTColorFormatterMenu)
end
CTColorFormatterMenu.Caption = 'Color Formatter'
CTColorFormatterMenu.OnClick = nil

addItem(CTColorFormatterMenu, 'CTColorApplyItem', 'Apply Colors', function() applyColors(false) end)
addItem(CTColorFormatterMenu, 'CTColorWhiteItem', 'Set Default', function() applyColors(true) end)
addItem(CTColorFormatterMenu, 'CTColorUndoItem', 'Undo Last Change', undoLast)

local autoItem = addItem(CTColorFormatterMenu, 'CTColorAutoItem', 'Auto Color Records', function()
  state.auto = not state.auto
  if state.auto then rememberCurrentRecords() end
  CTColorAutoItem.Checked = state.auto
end)
autoItem.Checked = state.auto
rememberCurrentRecords()

if CTColorAutoTimer == nil then
  CTColorAutoTimer = createTimer(MainForm, false)
  CTColorAutoTimer.Interval = 750
end
CTColorAutoTimer.OnTimer = function()
  local ok, err = pcall(autoTick)
  if not ok then print('CT Color auto timer error: ' .. tostring(err)) end
end
CTColorAutoTimer.Enabled = true

-- Hide obsolete selected-record items if an older version was loaded earlier.
if CTColorSelectedApply then CTColorSelectedApply.Visible = false end
if CTColorSelectedWhite then CTColorSelectedWhite.Visible = false end
