-- Full / Compact View toggle (autorun)

local compactMenuItem
local compactMenuAlreadyExists = false

local function setCompact(enabled)
    -- enabled = true  → Compact ON (hide panels)
    -- enabled = false → Compact OFF (show panels)
    getMainForm().Splitter1.Visible = not enabled
    getMainForm().Panel5.Visible   = not enabled
    compactMenuItem.Caption = enabled and 'Full View Mode' or 'Compact View Mode'
end

local function toggleCompact()
    local compactEnabled = not getMainForm().Splitter1.Visible
    setCompact(not compactEnabled)
end

local function addCompactMenu()
    if compactMenuAlreadyExists then return end

    local parent = getMainForm().Menu.Items
    compactMenuItem = createMenuItem(parent)
    parent.add(compactMenuItem)

    compactMenuItem.OnClick = toggleCompact
    compactMenuAlreadyExists = true
end

-- Init
addCompactMenu()

-- ✅ DEFAULT: Compact OFF (Full View ON)
setCompact(false)
