--[===[
Author:	YoucefHam
Email:	youcefham20@gmail.com
Discord:	YoucefHam#5634

ADD to Edit Menu "Show/Hide records"
	"Show All Hidden Records", => Show all hidden children records.
	"Restore All Hidden Records", => Restore all hidden children records.
]===]

local ColapsedrecordsName = 'miColapsedrecords'
local ColapsedrecordsCaption = '&Show/Hide Records'
local miColapsedrecords

local function ShowColapsedrecords()
	local mr = getAddressList()
	if mr.Count > 0 then
		for _Record = 0 , mr.Count - 1 do -- Read all records in the Table
			if not(mr[_Record].Description:find('|moH')) or not(mr[_Record].Description:find('|moAH')) then
				if mr[_Record].Options:find('moHideChildren') then
					mr[_Record].Description = mr[_Record].Description.."|moH"
					mr[_Record].Options = mr[_Record].Options:gsub('moHideChildren','')
				end
				if mr[_Record].Options:find('moAlwaysHideChildren') then
					mr[_Record].Description = mr[_Record].Description.."|moAH"
					mr[_Record].Options = mr[_Record].Options:gsub('moAlwaysHideChildren','')
				end
				mr[_Record].Collapsed = false
			end
		end
		showMessage(translate("ALL RECORDS ARE VISIBLE!!!"))
	end
end

-- Get Table records
local function HideColapsedrecords()
	local mr = getAddressList()
	if mr.Count > 0 then
		for _Record = 0 , mr.Count - 1 do -- Read all records in the Table
			if mr[_Record].Description:find('|moH') then
				mr[_Record].Description = mr[_Record].Description:gsub("|moH",'')
				mr[_Record].Options = mr[_Record].Options..'moHideChildren'
			end
			if mr[_Record].Description:find('|moAH') then
				mr[_Record].Description = mr[_Record].Description:gsub("|moAH",'')
				mr[_Record].Options = mr[_Record].Options..'moAlwaysHideChildren'
			end
			mr[_Record].Collapsed = true
		end
		showMessage(translate("ALL HIDDEN RECORDS ARE RESTORED!!!"))
	end
end

-- Add menus
local function addMenuItem(MenuItem, caption, onClick)
	local newItem = createMenuItem(MenuItem)
	MenuItem.add(newItem)
	newItem.Caption = caption
	newItem.OnClick = onClick
	return newItem
end

-- create records Manager
local function addColapsedrecordsMenu()
	if not getMainForm().ComponentByName['Edit3'].Visible then getMainForm().ComponentByName['Edit3'].Visible = true end
	local parent = getMainForm().ComponentByName['Edit3'] or getMainForm().Menu.Items
	local separatorMenu = createMenuItem(parent)
	separatorMenu.Caption = '-'
	parent.add(separatorMenu)

	local miColapsedrecords = createMenuItem(parent)
	miColapsedrecords.Name = ColapsedrecordsName
	miColapsedrecords.Caption = ColapsedrecordsCaption
	parent.add(miColapsedrecords)

	addMenuItem(miColapsedrecords,translate('&Show All Hidden Records'), ShowColapsedrecords)
	addMenuItem(miColapsedrecords,'-')
	addMenuItem(miColapsedrecords,translate('&Restore All Hidden Records'), HideColapsedrecords)
end

addColapsedrecordsMenu()