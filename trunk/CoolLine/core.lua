local CoolLine = CreateFrame("Frame", "CoolLine", UIParent)
local self = CoolLine
self:SetScript("OnEvent", function(this, event, ...)
	this[event](this, ...)
end)
local smed = LibStub("LibSharedMedia-3.0")

local _G = getfenv(0)
local pairs, ipairs = pairs, ipairs
local tinsert, tremove = tinsert, tremove
local GetTime = GetTime
local min, random = min, math.random
local UnitExists, HasPetUI = UnitExists, HasPetUI

local db, block
local backdrop = { edgeSize=16, }
local section, iconsize = 0, 0
local tick0, tick1, tick10, tick30, tick60, tick120, tick300
local BOOKTYPE_SPELL, BOOKTYPE_PET = BOOKTYPE_SPELL, BOOKTYPE_PET
local spells = { [BOOKTYPE_SPELL] = { }, [BOOKTYPE_PET] = { }, }
local frames, cooldowns = { }, { }

local SetValue, updatelook, createfs, ShowOptions
local function SetValueH(this, v, just)
	this:SetPoint(just or "CENTER", self, "LEFT", v, 0)
end
local function SetValueHR(this, v, just)
	this:SetPoint(just or "CENTER", self, "LEFT", db.w - v, 0)
end
local function SetValueV(this, v, just)
	this:SetPoint(just or "CENTER", self, "BOTTOM", 0, v)
end
local function SetValueVR(this, v, just)
	this:SetPoint(just or "CENTER", self, "BOTTOM", 0, db.h - v)
end

self:RegisterEvent("ADDON_LOADED")
function CoolLine:ADDON_LOADED(a1)
	if a1 ~= "CoolLine" then return end
	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
	
	CoolLineDB = CoolLineDB or { }
	db = CoolLineDB
	if db.dbinit ~= 0 then
		for k,v in pairs({
			w = 360, h = 18, x = 0, y = -240,
			statusbar = "Blizzard",
			bgcolor = { r = 0, g = 0, b = 0, a = 0.6, },
			border = "Blizzard Dialog",
			bordercolor = { r = 1, g = 1, b = 1, a = 1, },
			font = "Friz Quadrata TT",
			fontsize = 10,
			fontcolor = { r = 1, g = 1, b = 1, a = 0.8, },
			inactivealpha = 0.5,
			activealpha = 1.0,
			block = {  -- [spell or item name] = true,
				[GetItemInfo(6948)] = true,  -- Hearthstone
			},
		}) do
			db[k] = (db[k] ~= nil and db[k]) or v
		end
		db.dbinit = 0
	end
	block = db.block
	
	SlashCmdList.COOLLINE = ShowOptions
	SLASH_COOLLINE1 = "/coolline"
	local panel = CreateFrame("Frame")
	panel.name = "CoolLine"
	panel:SetScript("OnShow", function(this)
		if not this.t1 then
			local t1 = this:CreateFontString(nil, "ARTWORK")
			t1:SetJustifyH("LEFT")
			t1:SetJustifyV("TOP")
			t1:SetFontObject(GameFontNormalLarge)
			t1:SetPoint("TOPLEFT", 16, -16)
			t1:SetText(this.name)
			this.t1 = t1
			
			local t2 = this:CreateFontString(nil, "ARTWORK")
			t2:SetJustifyH("LEFT")
			t2:SetJustifyV("TOP")
			t2:SetFontObject(GameFontHighlightSmall)
			t2:SetHeight(43)
			t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -8)
			t2:SetPoint("RIGHT", this, "RIGHT", -32, 0)
			t2:SetNonSpaceWrap(true)
			t2:SetFormattedText("Notes: %s\nAuthor: %s\nVersion: %s\n"..
			                    "Hint: |cffffff00/coolline|r to open menu; |cffffff00/coolline SpellOrItemName|r to add/remove filter", 
			                     GetAddOnMetadata("CoolLine", "Notes") or "N/A",
								 GetAddOnMetadata("CoolLine", "Author") or "N/A",
								 GetAddOnMetadata("CoolLine", "Version") or "N/A")
		
			local b = CreateFrame("Button", nil, this, "UIPanelButtonTemplate")
			b:SetWidth(120)
			b:SetHeight(20)
			b:SetText("Options Menu")
			b:SetScript("OnClick", ShowOptions)
			b:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", -2, -8)
		end
	end)
	InterfaceOptions_AddCategory(panel)
	
	createfs = function(f, text, offset, just)
		local fs = f or self.border:CreateFontString(nil, "OVERLAY")
		fs:SetFont(smed:Fetch("font", db.font), db.fontsize)
		fs:SetTextColor(db.fontcolor.r, db.fontcolor.g, db.fontcolor.b, db.fontcolor.a)
		fs:SetText(text)
		fs:SetWidth(db.fontsize * 3)
		fs:SetHeight(db.fontsize + 2)
		if just then
			fs:ClearAllPoints()
			if db.vertical then
				fs:SetJustifyH("CENTER")
				just = db.reverse and ((just == "LEFT" and "TOP") or "BOTTOM") or ((just == "LEFT" and "BOTTOM") or "TOP")
			elseif db.reverse then
				just = (just == "LEFT" and "RIGHT") or "LEFT"
				fs:SetJustifyH(just)
			else
				fs:SetJustifyH(just)
			end
		else
			fs:SetJustifyH("CENTER")
		end
		SetValue(fs, offset, just)
		return fs
	end
	updatelook = function()
		self:SetWidth(db.w)
		self:SetHeight(db.h)
		self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
		
		self.bg = self.bg or self:CreateTexture(nil, "ARTWORK")
		self.bg:SetTexture(smed:Fetch("statusbar", db.statusbar))
		self.bg:SetVertexColor(db.bgcolor.r, db.bgcolor.g, db.bgcolor.b, db.bgcolor.a)
		self.bg:SetAllPoints(self)
		if db.vertical then
			self.bg:SetTexCoord(1,0, 0,0, 1,1, 0,1)
		else
			self.bg:SetTexCoord(0,1, 0,1)
		end
		
		self.border = self.border or CreateFrame("Frame", nil, self)
		self.border:SetPoint("TOPLEFT", -4, 4)
		self.border:SetPoint("BOTTOMRIGHT", 4, -4)
		backdrop.edgeFile = smed:Fetch("border", db.border)
		self.border:SetBackdrop(backdrop)
		self.border:SetBackdropBorderColor(db.bordercolor.r, db.bordercolor.g, db.bordercolor.b, db.bordercolor.a)
		
		section = (db.vertical and db.h or db.w) / 6
		iconsize = db.vertical and db.w or db.h
		SetValue = (db.vertical and (db.reverse and SetValueVR or SetValueV)) or (db.reverse and SetValueHR or SetValueH)
		
		tick0 = createfs(tick0, "0", 0, "LEFT")
		tick1 = createfs(tick1, "1", section)
		tick10 = createfs(tick10, "10", section * 2)
		tick30 = createfs(tick30, "30", section * 3)
		tick60 = createfs(tick60, "60", section * 4)
		tick120 = createfs(tick120, "3m", section * 5)
		tick300 = createfs(tick300, "10m", section * 6, "RIGHT")
		
		if db.hidepet then
			self:UnregisterEvent("UNIT_PET")
			self:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN")
		else
			self:RegisterEvent("UNIT_PET")
			self:UNIT_PET("player")
		end
		if db.hidebag and db.hideinv then
			self:UnregisterEvent("BAG_UPDATE_COOLDOWN")
		else
			self:RegisterEvent("BAG_UPDATE_COOLDOWN")
		end
		CoolLine:SetAlpha((CoolLine.unlock or #cooldowns > 0) and db.activealpha or db.inactivealpha)
		for _, frame in ipairs(cooldowns) do
			frame:SetWidth(iconsize)
			frame:SetHeight(iconsize)
		end
	end
	self:RegisterEvent("PLAYER_LOGIN")
end

--------------------------------
function CoolLine:PLAYER_LOGIN()
--------------------------------
	self.PLAYER_LOGIN = nil
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE")
	if UnitHasVehicleUI("player") then
		self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
		self:RegisterEvent("UNIT_EXITED_VEHICLE")
	end
	updatelook()
	self:SPELLS_CHANGED()
	self:SPELL_UPDATE_COOLDOWN()
	self:BAG_UPDATE_COOLDOWN()
	self:SetAlpha((#cooldowns == 0 and db.inactivealpha) or db.activealpha)
end


local elapsed, throt, isactive = 0, 1.5, false
local function ClearCooldown(f, name)
	name = name or (f and f.name)
	for index, frame in ipairs(cooldowns) do
		if frame.name == name then
			frame:Hide()
			frame.name = nil
			frame.endtime = nil
			tinsert(frames, tremove(cooldowns, index))
			break
		end
	end
end
local layer = { "ARTWORK", "OVERLAY" }
local function SetupIcon(frame, position, alpha, tthrot, active, ctime)
	throt = min(throt, tthrot or 1.5)
	isactive = active or isactive
	frame:SetAlpha(alpha)
	if (ctime or 0) > ((frame.ptime or 0) + 0.3) then
		frame.ptime = ctime
		frame:SetDrawLayer(layer[random(1,2)])
	end
	SetValue(frame, position)
end
local function OnUpdate(this, a1)
	elapsed = elapsed + a1
	if elapsed < throt then return end
	elapsed = 0
	
	if #cooldowns == 0 then
		if not CoolLine.unlock then
			self:SetScript("OnUpdate", nil)
			self:SetAlpha(db.inactivealpha)
		end
		return
	end
	
	local ctime = GetTime()
	isactive = false
	throt = 1.5
	for name, frame in pairs(cooldowns) do
		local remain = frame.endtime - ctime
		if remain < 30 then
			local alpha = 1 - 0.5 * remain / 30
			if remain > 10 then
				SetupIcon(frame, section * (2 + (remain - 10) / 20), alpha, 0.06, true, ctime)
			elseif remain > 1 then
				SetupIcon(frame, section * (1 + (remain - 1) / 9), alpha, 0.03, true, ctime)
			elseif remain > 0.3 then
				SetupIcon(frame, section * remain, alpha, 0, true, ctime)
			elseif remain > 0 then
				local size = iconsize + iconsize * (0.3 - remain) / 0.3
				frame:SetWidth(size)
				frame:SetHeight(size)
				SetupIcon(frame, section * remain, alpha, 0, true, ctime)
			elseif remain > -1.3 then
				SetupIcon(frame, 0, 1 + remain/1.3, 0, true, ctime)
			else
				throt, isactive = min(throt, 0.2), true
				ClearCooldown(frame)
			end
		elseif remain < 60 then
			SetupIcon(frame, section * (3 + (remain - 30) / 30), 0.5, 0.15, true, ctime)
		elseif remain < 180 then
			SetupIcon(frame, section * (4 + (remain - 60) / 120), 0.4, 0.3, true, ctime)
		elseif remain < 600 then
			SetupIcon(frame, section * (5 + (remain - 180) / 420), 0.4, 1.5, true, ctime)
		else
			SetupIcon(frame, 6 * section + db.h, 0, 1.5, false, ctime)
		end
	end
	if not isactive and not CoolLine.unlock then
		self:SetAlpha(db.inactivealpha)
	end
end
local function NewCooldown(name, icon, endtime)
	local f
	for index, frame in pairs(cooldowns) do
		if frame.name == name then
			f = frame
			break
		elseif frame.endtime + 0.1 > endtime and frame.endtime - 0.1 < endtime then
			return
		end
	end
	if not f then
		f = f or tremove(frames)
		if not f then
			f = self.border:CreateTexture(nil, "ARTWORK")
			f:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		tinsert(cooldowns, f)
	end
	f:SetWidth(iconsize)
	f:SetHeight(iconsize)
	f.name = name
	f.endtime = endtime
	f:SetTexture(icon)
	f:Show()
	self:SetScript("OnUpdate", OnUpdate)
	self:SetAlpha(db.activealpha)
	OnUpdate(self, 2)
end

do  -- cache spells that have a cooldown
	local CLTip = CreateFrame("GameTooltip", "CLTip", CoolLine, "GameTooltipTemplate")
	CLTip:SetOwner(CoolLine, "ANCHOR_NONE")
	local cooldown1 = gsub(SPELL_RECAST_TIME_MIN, "%%%.%d[fg]", "(.+)")
	local cooldown2 = gsub(SPELL_RECAST_TIME_SEC, "%%%.%d[fg]", "(.+)")
	local function CheckRight(rtext)
		local text = rtext and rtext:GetText()
		if text and (strfind(text, cooldown1) or strfind(text, cooldown2)) then
			return true
		end
	end
	local function CacheBook(btype)
		local name, last
		local sb = spells[btype]
		local i = 0
		while true do
			i = i + 1
			name = GetSpellName(i, btype)
			if not name then break end
			if name ~= last then
				last = name
				if sb[name] then
					sb[name] = i
				else
					CLTip:SetSpell(i, btype)
					if CheckRight(CLTipTextRight2) or CheckRight(CLTipTextRight3) or CheckRight(CLTipTextRight4) then
						sb[name] = i
					end
				end
			end
		end
	end
	----------------------------------
	function CoolLine:SPELLS_CHANGED()
	----------------------------------
		CacheBook(BOOKTYPE_SPELL)
		if not db.hidepet then
			CacheBook(BOOKTYPE_PET)
		end
	end
end

do  -- scans spellbook to update cooldowns
	local selap = 0
	local spellthrot = CreateFrame("Frame", nil, CoolLine)
	local GetSpellCooldown, GetSpellTexture = GetSpellCooldown, GetSpellTexture
	local function CheckSpellBook(btype)
		for name, id in pairs(spells[btype]) do
			local start, duration, enable = GetSpellCooldown(id, btype)
			if enable == 1 and start > 0 then
				if duration > 2.5 and not block[name] then
					NewCooldown(name, GetSpellTexture(id, btype), start + duration)
				end
			else
				ClearCooldown(nil, name)
			end
		end
	end
	local function SpellOnUpdate(this, a1)
		selap = selap + a1
		if selap < 0.5 then return end
		selap = 0
		this:SetScript("OnUpdate", nil)
		CheckSpellBook(BOOKTYPE_SPELL)
		if not db.hidepet and HasPetUI() then
			CheckSpellBook(BOOKTYPE_PET)
		end
	end
	-----------------------------------------
	function CoolLine:SPELL_UPDATE_COOLDOWN()
	-----------------------------------------
		spellthrot:SetScript("OnUpdate", SpellOnUpdate)
	end
end

do  -- scans equipments and bags for item cooldowns
	local GetItemInfo = GetItemInfo
	local GetInventoryItemCooldown, GetInventoryItemTexture = GetInventoryItemCooldown, GetInventoryItemTexture
	local GetContainerItemCooldown, GetContainerItemInfo = GetContainerItemCooldown, GetContainerItemInfo
	local GetContainerNumSlots = GetContainerNumSlots
	---------------------------------------
	function CoolLine:BAG_UPDATE_COOLDOWN()
	---------------------------------------
		for i = 1, (db.hideinv and 0) or 18, 1 do
			local start, duration, enable = GetInventoryItemCooldown("player", i)
			if enable == 1 then
				local name = GetItemInfo(GetInventoryItemLink("player", i))
				if start > 0 and not block[name] then
					if duration > 3 and duration < 3601 then
						local texture = GetInventoryItemTexture("player", i)
						NewCooldown(name, texture, start + duration)
					end
				else
					ClearCooldown(nil, name)
				end
			end
		end
		for i = 0, (db.hidebag and -1) or 4, 1 do
			for j = 1, GetContainerNumSlots(i), 1 do
				local start, duration, enable = GetContainerItemCooldown(i, j)
				if enable == 1 then
					local name = GetItemInfo(GetContainerItemLink(i, j))
					if start > 0 and not block[name] then
						if duration > 3 and duration < 3601 then
							local texture = GetContainerItemInfo(i, j)
							NewCooldown(name, texture, start + duration)
						end
					else
						ClearCooldown(nil, name)
					end
				end
			end
		end
	end
end

-------------------------------------------
function CoolLine:PET_BAR_UPDATE_COOLDOWN()
-------------------------------------------
	for i = 1, 10, 1 do
		local start, duration, enable = GetPetActionCooldown(i)
		if enable == 1 then
			local name, _, texture = GetPetActionInfo(i)
			if name then
				if start > 0 and not block[name] then
					if duration > 3 then
						NewCooldown(name, texture, start + duration)
					end
				else
					ClearCooldown(nil, name)
				end
			end
		end
	end
end
------------------------------
function CoolLine:UNIT_PET(a1)
------------------------------
	if a1 ~= "player" then return end
	if UnitExists("pet") and not HasPetUI() then
		self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
	else
		self:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN")
	end
end

local GetActionCooldown, HasAction = GetActionCooldown, HasAction
---------------------------------------------
function CoolLine:ACTIONBAR_UPDATE_COOLDOWN()  -- used only for vehicles
---------------------------------------------
	for i = 1, 6, 1 do
		local b = _G["VehicleMenuBarActionButton"..i]
		if b and HasAction(b.action) then
			local start, duration, enable = GetActionCooldown(b.action)
			if enable == 1 then
				if start > 0 and not block[GetActionInfo(b.action)] then
					if duration > 3 then
						NewCooldown("vhcle"..i, GetActionTexture(b.action), start + duration)
					end
				else
					ClearCooldown(nil, "vhcle"..i)
				end
			end
		end
	end
end
------------------------------------------
function CoolLine:UNIT_ENTERED_VEHICLE(a1)
------------------------------------------
	if a1 ~= "player" or not UnitHasVehicleUI("player") then return end
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	self:RegisterEvent("UNIT_EXITED_VEHICLE")
	self:ACTIONBAR_UPDATE_COOLDOWN()
end
-----------------------------------------
function CoolLine:UNIT_EXITED_VEHICLE(a1)
-----------------------------------------
	if a1 ~= "player" then return end
	self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	for index, frame in ipairs(cooldowns) do
		if strfind(frame.name, "vhcle") then
			ClearCooldown(nil, frame.name)
		end
	end
end



local CoolLineDD
local info = { }
function ShowOptions(a1)
	if type(a1) == "string" and a1 ~= "" then
		if block[a1] then
			block[a1] = nil
			print("CoolLine: |cffffff00"..a1.."|r removed from filter.")
		else
			block[a1] = true
			print("CoolLine: |cffffff00"..a1.."|r added to filter.")
		end
		return
	end
	if not CoolLineDD then
		CoolLineDD = CreateFrame("Frame", "CoolLineDD", UIParent)
		CoolLineDD.displayMode = "MENU"

		local function Set(info, a1)
			if a1 == "unlock" then
				if not CoolLine.resizer then
					CoolLine:SetMovable(true)
					CoolLine:SetResizable(true)
					CoolLine:RegisterForDrag("LeftButton")
					CoolLine:SetScript("OnMouseUp", function(this, a1) if a1 == "RightButton" then ShowOptions() end end)
					CoolLine:SetScript("OnDragStart", function(this) this:StartMoving() end)
					CoolLine:SetScript("OnDragStop", function(this) 
						this:StopMovingOrSizing()
						local x, y = this:GetCenter()
						local ux, uy = UIParent:GetCenter()
						db.x, db.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
						this:ClearAllPoints()
						updatelook()
					end)
				
					CoolLine:SetMinResize(6, 6)
					CoolLine.resizer = CreateFrame("Button", nil, CoolLine.border, "UIPanelButtonTemplate")
					local resize = CoolLine.resizer
					resize:SetWidth(8)
					resize:SetHeight(8)
					resize:SetPoint("BOTTOMRIGHT", CoolLine, "BOTTOMRIGHT", 0, 0)
					resize:SetScript("OnMouseDown", function(this) CoolLine:StartSizing("BOTTOMRIGHT") end)
					resize:SetScript("OnMouseUp", function(this) 
						CoolLine:StopMovingOrSizing()
						local w, h = CoolLine:GetWidth(), CoolLine:GetHeight()
						db.w, db.h = floor(w + 0.5), floor(h + 0.5)
						updatelook()
					end)
				end
				if not CoolLine.unlock then
					CoolLine.unlock = true
					CoolLine:EnableMouse(true)
					CoolLine.resizer:Show()
					CoolLine:SetAlpha(db.activealpha)
				else
					CoolLine.unlock = nil
					CoolLine:EnableMouse(false)
					CoolLine.resizer:Hide()
					OnUpdate(CoolLine, 2)
				end
			elseif a1 then
				if a1 == "vertical" then
					local pw, ph = db.w, db.h
					db.w, db.h = ph, pw
				end
				db[a1] = not db[a1]
				updatelook()
			end
		end
		local function SetSelect(info, a1)
			db[a1] = tonumber(info.value) or info.value
			local level, num = strmatch(info:GetName(), "DropDownList(%d+)Button(%d+)")
			level, num = tonumber(level) or 0, tonumber(num) or 0
			for i = 2, level, 1 do
				for j = 1, UIDROPDOWNMENU_MAXBUTTONS, 1 do
					local b = _G["DropDownList"..i.."Button"..j.."Check"]
					if b and i == level and j == num then
						b:Show()
					elseif b then
						b:Hide()
					end
				end
			end
			updatelook()
		end
		local function SetColor(a1)
			local dbc = db[UIDROPDOWNMENU_MENU_VALUE]
			if not dbc then return end
			local r, g, b, a
			if a1 then
				local pv = ColorPickerFrame.previousValues
				r, g, b, a = pv.r, pv.g, pv.b, 1 - pv.opacity
			else
				r, g, b = ColorPickerFrame:GetColorRGB()
				a = 1 - OpacitySliderFrame:GetValue()
			end
			dbc.r, dbc.g, dbc.b, dbc.a = r, g, b, a
			updatelook()
		end
		local function HideCheck(info)
			if info and info.GetName and _G[info:GetName().."Check"] then
				_G[info:GetName().."Check"]:Hide()
			end
		end
		local function AddButton(info, level, text, keepshown)
			info.text = text
			info.keepShownOnClick = keepshown
			UIDropDownMenu_AddButton(info, level)
			wipe(info)
		end
		local function AddToggleButton(info, level, text, value)
			info.arg1 = value
			info.func = Set
			if value == "unlock" then
				info.checked = CoolLine.unlock
			else
				info.checked = db[value]
			end
			AddButton(info, level, text, 1)
		end
		local function AddListButton(info, level, text, value)
			info.value = value
			info.hasArrow = true
			info.func = HideCheck
			AddButton(info, level, text, 1)
		end
		local function AddSelectButton(info, level, text, arg1, value)
			info.arg1 = arg1
			info.func = SetSelect
			info.value = value
			if tonumber(value) then
				if floor(100 * tonumber(value)) == floor(100 * tonumber(db[arg1] or -1)) then
					info.checked = true
				end
			else
				info.checked = db[arg1] == value
			end
			AddButton(info, level, text, 1)
		end
		local function AddColorButton(info, level, text, value)
			local dbc = db[value]
			if not dbc then return end
			info.hasColorSwatch = true
			info.hasOpacity = 1
			info.r, info.g, info.b, info.opacity = dbc.r, dbc.g, dbc.b, 1 - dbc.a
			info.swatchFunc, info.opacityFunc, info.cancelFunc = SetColor, SetColor, SetColor
			info.value = value
			info.func = UIDropDownMenuButton_OpenColorPicker
			AddButton(info, level, text, nil)
		end
		CoolLineDD.initialize = function(self, level)
			if level == 1 then
				info.isTitle = true
				AddButton(info, level, "|cff88ff88Cool|r|cff88ff88Line|r")
				
				AddListButton(info, level, "Texture", "statusbar")
				AddColorButton(info, level, "Texture Color", "bgcolor")
				
				AddListButton(info, level, "Border", "border")
				AddColorButton(info, level, "Border Color", "bordercolor")
				
				AddListButton(info, level, "Font", "font")
				AddColorButton(info, level, "Font Color", "fontcolor")
				AddListButton(info, level, "Font Size", "fontsize")
				
				AddListButton(info, level, "Inactive Opacity", "inactivealpha")
				AddListButton(info, level, "Active Opacity", "activealpha")
				
				AddToggleButton(info, level, "Disable Equipped", "hideinv")
				AddToggleButton(info, level, "Disable Bags", "hidebag")
				AddToggleButton(info, level, "Disable Pet", "hidepet")
				AddToggleButton(info, level, "Vertical", "vertical")
				AddToggleButton(info, level, "Reverse", "reverse")
				AddToggleButton(info, level, "Unlock", "unlock")
			elseif level and level > 1 then
				local sub = UIDROPDOWNMENU_MENU_VALUE
				if sub == "font" or sub == "statusbar" or sub == "border" then
					local t = smed:List(sub)
					local starti = 20 * (level - 2) + 1
					local endi = 20 * (level - 1)
					for i = starti, endi, 1 do
						if not t[i] then break end
						AddSelectButton(info, level, t[i], sub, t[i])
						if i == endi and t[i + 1] then
							AddListButton(info, level, "More", sub)
						end	
					end
				elseif sub == "fontsize" then
					for i = 6, 28, 2 do
						AddSelectButton(info, level, i, "fontsize", i)
					end
				elseif sub == "inactivealpha" or sub == "activealpha" then
					for i = 0, 1, 0.1 do
						AddSelectButton(info, level, format("%.1f", i), sub, i)
					end
				end
			end
		end
	end
	ToggleDropDownMenu(1, nil, CoolLineDD, "cursor")
end


