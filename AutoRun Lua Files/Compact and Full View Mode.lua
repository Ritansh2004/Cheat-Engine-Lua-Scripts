-- Cheat Engine 7.7 - Full / Compact View Mode (autorun)
-- Compatible with the unchanged manual Table Lua script.
-- Both menu buttons control the same Full / Compact view state.
-- Does not change the layout when this autorun file loads.

CEViewModeState = CEViewModeState or {}
local state = CEViewModeState

local function getMainWindow()
  local form = getMainForm()
  if not form or not form.Splitter1 or not form.Panel5 then
    return nil
  end
  return form
end

local function isCompact(form)
  return not (form.Splitter1.Visible and form.Panel5.Visible)
end

local function updateMenuCaption()
  local form = getMainWindow()
  if not form or not state.menu then return end

  -- This is the action the autorun menu should offer next.
  state.menu.Caption = isCompact(form) and 'Normal View Mode' or 'Full Screen Mode'
end

local function toggleView(sender)
  local form = getMainWindow()
  if not form then
    showMessage('View Mode: required panels are unavailable.')
    return
  end

  -- When the manual Table Lua script has been executed, use its existing
  -- cycleFullCompact function. This keeps its button and the autorun button
  -- working from the same caption/state without changing the manual script.
  if type(cycleFullCompact) == 'function' and compactmenuitem then
    local ok, err = pcall(cycleFullCompact, sender)
    if not ok then
      print('View Mode: manual toggle failed: ' .. tostring(err))
      return
    end
  else
    -- The autorun button also works before the manual script is executed.
    -- Preserve the original panel visibility so the normal layout is restored.
    if isCompact(form) then
      if state.previousPanelVisible ~= nil then
        form.Panel5.Visible = state.previousPanelVisible
      else
        form.Panel5.Visible = true
      end
      if state.previousSplitterVisible ~= nil then
        form.Splitter1.Visible = state.previousSplitterVisible
      else
        form.Splitter1.Visible = true
      end
      state.previousPanelVisible = nil
      state.previousSplitterVisible = nil
    else
      state.previousSplitterVisible = form.Splitter1.Visible
      state.previousPanelVisible = form.Panel5.Visible
      form.Splitter1.Visible = false
      form.Panel5.Visible = false
    end
  end

  updateMenuCaption()
end

local form = getMainForm()
if not form or not form.Menu then
  showMessage('View Mode: main menu is unavailable.')
  return
end

-- Reuse the same autorun menu item if this file is reloaded.
if not state.menu then
  state.menu = createMenuItem(form.Menu)
  form.Menu.Items.add(state.menu)
end

state.menu.OnClick = toggleView
updateMenuCaption()

-- The unchanged manual button updates its own caption when clicked.
-- This timer keeps the autorun button caption synchronized with it.
if not state.captionTimer then
  state.captionTimer = createTimer(form, false)
  state.captionTimer.Interval = 250
end
state.captionTimer.OnTimer = updateMenuCaption
state.captionTimer.Enabled = true

-- Intentionally no startup layout operations.
