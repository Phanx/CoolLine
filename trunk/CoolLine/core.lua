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
local random = math.random
local strmatch = strmatch
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
	if db.dbinit ~= 1 then
		db.dbinit = 1
		for k, v in pairs({
			w = 360, h = 18, x = 0, y = -240,
			statusbar = "Blizzard",
			bgcolor = { r = 0, g = 0, b = 0, a = 0.6, },
			border = "Blizzard Dialog",
			bordercolor = { r = 1, g = 1, b = 1, a = 1, },
			font = "Friz Quadrata TT",
			fontsize = 10,
			fontcolor = { r = 1, g = 1, b = 1, a = 0.8, },
			spellcolor = { r = 0.8, g = 0.4, b = 0, a = 1, },
			nospellcolor = { r = 0, g = 0, b = 0, a = 1, },
			inactivealpha = 0.5,
			activealpha = 1.0,
			block = {  -- [spell or item name] = true,
				[GetItemInfo(6948) or "Hearthstone"] = true,  -- Hearthstone
			},
		}) do
			db[k] = (db[k] ~= nil and db[k]) or v
		end
	end
	block = db.block
	
	SlashCmdList.COOLLINE = ShowOptions
	SLASH_COOLLINE1 = "/coolline"
	local panel = CreateFrame("Frame")
	panel.name = "CoolLine"
	panel:SetScript("OnShow", function(this)
		local t1 = this:CreateFontString(nil, "ARTWORK")
		t1:SetJustifyH("LEFT")
		t1:SetJustifyV("TOP")
		t1:SetFontObject(GameFontNormalLarge)
		t1:SetPoint("TOPLEFT", 16, -16)
		t1:SetText(this.name)
		
		local t2 = this:CreateFontString(nil, "ARTWORK")
		t2:SetJustifyH("LEFT")
		t2:SetJustifyV("TOP")
		t2:SetFontObject(GameFontHighlightSmall)
		t2:SetHeight(43)
		t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -8)
		t2:SetPoint("RIGHT", this, "RIGHT", -32, 0)
		t2:SetNonSpaceWrap(true)
		t2:SetFormattedText("Notes: %s\nAuthor: %s\nVersion: %s\n"..
							"Hint: |cffffff00/coolline|r to open menu; |cffffff00/coolline SpellOrItemNameOrLink|r to add/remove filter", 
							 GetAddOnMetadata("CoolLine", "Notes") or "N/A",
							 GetAddOnMetadata("CoolLine", "Author") or "N/A",
							 GetAddOnMetadata("CoolLine", "Version") or "N/A")
	
		local b = CreateFrame("Button", nil, this, "UIPanelButtonTemplate")
		b:SetWidth(120)
		b:SetHeight(20)
		b:SetText("Options Menu")
		b:SetScript("OnClick", ShowOptions)
		b:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", -2, -8)
		this:SetScript("OnShow", nil)
	end)
	InterfaceOptions_AddCategory(panel)
	
	createfs = function(f, text, offset, just)
		local fs = f or self.overlay:CreateFontString(nil, "OVERLAY")
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
				if just == "LEFT" then
					just, offset = "RIGHT", offset + 1
				else
					just, offset = "LEFT", offset - 1
				end
				fs:SetJustifyH(just)
			else
				if just == "LEFT" then
					offset = offset + 1
				else
					offset = offset - 1
				end
				fs:SetJustifyH(just)
			end
		else
			fs:SetJustifyH("CENTER")
		end
		SetValue(fs, offset, just)
		return fs
	end
	updatelook = function()
		self:SetWidth(db.w or 130)
		self:SetHeight(db.h or 18)
		self:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -240)
		
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
		
		self.overlay = self.overlay or CreateFrame("Frame", nil, self.border)
		self.overlay:SetFrameLevel(11)

		section = (db.vertical and db.h or db.w) / 6
		iconsize = db.vertical and db.w or db.h
		SetValue = (db.vertical and (db.reverse and SetValueVR or SetValueV)) or (db.reverse and SetValueHR or SetValueH)
		
		tick0 = createfs(tick0, "0", 0, "LEFT")
		tick1 = createfs(tick1, "1", section)
		tick10 = createfs(tick10, "10", section * 2)
		tick30 = createfs(tick30, "30", section * 3)
		tick60 = createfs(tick60, "60", section * 4)
		tick120 = createfs(tick120, "3m", section * 5)
		tick300 = createfs(tick300, "9m", section * 6, "RIGHT")
		
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
		if db.hidefail then
			self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
		else
			self:RegisterEvent("UNIT_SPELLCAST_FAILED")
		end
		CoolLine:SetAlpha((CoolLine.unlock or #cooldowns > 0) and db.activealpha or db.inactivealpha)
		for _, frame in ipairs(cooldowns) do
			frame:SetWidth(iconsize)
			frame:SetHeight(iconsize)
		end
	end
	if IsLoggedIn() then
		CoolLine:PLAYER_LOGIN()
	else
		self:RegisterEvent("PLAYER_LOGIN")
	end
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

local iconback = { bgFile="Interface\\AddOns\\CoolLine\\backdrop.tga" }
local elapsed, throt, ptime, isactive = 0, 1.5, 0, false
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
local function SetupIcon(frame, position, tthrot, active, fl)
	throt = (throt < tthrot and throt) or tthrot
	isactive = active or isactive
	if fl then
		frame:SetFrameLevel(random(1,4) * 2 + 2)
	end
	SetValue(frame, position)
end
local function OnUpdate(this, a1, ctime, dofl)
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
	
	ctime = ctime or GetTime()
	if ctime > ptime then
		dofl, ptime = true, ctime + 0.4
	end
	isactive, throt = false, 1.5
	for index, frame in pairs(cooldowns) do
		local remain = frame.endtime - ctime
		if remain < 10 then
			if remain > 1 then
				SetupIcon(frame, section * (remain + 8) * 0.11, 0.03, true, dofl)  -- 1 + (remain - 1) / 9
			elseif remain > 0.3 then
				SetupIcon(frame, section * remain, 0, true, dofl)
			elseif remain > 0 then
				local size = iconsize * (0.5 - remain) * 5  -- iconsize + iconsize * (0.3 - remain) / 0.2
				frame:SetWidth(size)
				frame:SetHeight(size)
				SetupIcon(frame, section * remain, 0, true, dofl)
			elseif remain > -1 then
				SetupIcon(frame, 0, 0, true, dofl)
				frame:SetAlpha(1 + remain)  -- fades
			else
				throt = (throt < 0.2 and throt) or 0.2
				isactive = true
				ClearCooldown(frame)
			end
		elseif remain < 30 then
			SetupIcon(frame, section * (remain + 30) * 0.05, 0.06, true, dofl)  -- 2 + (remain - 10) / 20
		elseif remain < 60 then
			SetupIcon(frame, section * (remain + 60) * 0.0333, 0.12, true, dofl)  -- 3 + (remain - 30) / 30
		elseif remain < 180 then
			SetupIcon(frame, section * (remain + 420) * 0.00833, 0.25, true, dofl)  -- 4 + (remain - 60) / 120
		elseif remain < 600 then
			SetupIcon(frame, section * (remain + 1920) * 0.00238, 1.2, true, dofl)  -- 5 + (remain - 180) / 420
			frame:SetAlpha(1)
		else
			SetupIcon(frame, 6 * section, 2, false, dofl)
		end
	end
	if not isactive and not CoolLine.unlock then
		self:SetAlpha(db.inactivealpha)
	end
end
local function NewCooldown(name, icon, endtime, isplayer)
	local f
	for index, frame in pairs(cooldowns) do
		if frame.name == name and frame.isplayer == isplayer then
			f = frame
			break
		elseif frame.endtime == endtime then
			return
		end
	end
	if not f then
		f = f or tremove(frames)
		if not f then
			f = CreateFrame("Frame", nil, CoolLine.border)
			f:SetBackdrop(iconback)
			f.icon = f:CreateTexture(nil, "ARTWORK")
			f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			f.icon:SetPoint("TOPLEFT", 1, -1)
			f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		end
		tinsert(cooldowns, f)
	end
	local ctime = GetTime()
	f:SetWidth(iconsize)
	f:SetHeight(iconsize)
	f:SetAlpha((endtime - ctime > 600) and 0.4 or 1)
	f.name, f.endtime, f.isplayer = name, endtime, isplayer
	f.icon:SetTexture(icon)
	local c = db[isplayer and "spellcolor" or "nospellcolor"]
	f:SetBackdropColor(c.r, c.g, c.b, c.a)
	f:Show()
	self:SetScript("OnUpdate", OnUpdate)
	self:SetAlpha(db.activealpha)
	OnUpdate(self, 2, ctime)
end

do  -- cache spells that have a cooldown
	local CLTip = CreateFrame("GameTooltip", "CLTip", CoolLine, "GameTooltipTemplate")
	CLTip:SetOwner(CoolLine, "ANCHOR_NONE")
	local GetSpellName = GetSpellName
	local cooldown1 = gsub(SPELL_RECAST_TIME_MIN, "%%%.%d[fg]", "(.+)")
	local cooldown2 = gsub(SPELL_RECAST_TIME_SEC, "%%%.%d[fg]", "(.+)")
	local function CheckRight(rtext)
		local text = rtext and rtext:GetText()
		if text and (strmatch(text, cooldown1) or strmatch(text, cooldown2)) then
			return true
		end
	end
	local function CacheBook(btype)
		local name, last
		local sb = spells[btype]
		for i = 1, 500, 1 do
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

do  -- scans spellbook to update cooldowns, throttled since the event fires a lot
	local selap = 0
	local spellthrot = CreateFrame("Frame", nil, CoolLine)
	local GetSpellCooldown, GetSpellTexture = GetSpellCooldown, GetSpellTexture
	local function CheckSpellBook(btype)
		for name, id in pairs(spells[btype]) do
			local start, duration, enable = GetSpellCooldown(id, btype)
			if enable == 1 and start > 0 then
				if duration > 2.5 and not block[name] then
					NewCooldown(name, GetSpellTexture(id, btype), start + duration, btype == BOOKTYPE_SPELL)
				end
			else
				ClearCooldown(nil, name)
			end
		end
	end
	spellthrot:SetScript("OnUpdate", function(this, a1)
		selap = selap + a1
		if selap < 0.5 then return end
		selap = 0
		this:Hide()
		CheckSpellBook(BOOKTYPE_SPELL)
		if not db.hidepet and HasPetUI() then
			CheckSpellBook(BOOKTYPE_PET)
		end
	end)
	spellthrot:Hide()
	-----------------------------------------
	function CoolLine:SPELL_UPDATE_COOLDOWN()
	-----------------------------------------
		spellthrot:Show()
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
						NewCooldown(name, GetInventoryItemTexture("player", i), start + duration)
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
							NewCooldown(name, GetContainerItemInfo(i, j), start + duration)
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
		if strmatch(frame.name, "vhcle") then
			ClearCooldown(nil, frame.name)
		end
	end
end

local failborder
----------------------------------------------------
function CoolLine:UNIT_SPELLCAST_FAILED(unit, spell)
----------------------------------------------------
	if unit ~= "player" or #cooldowns == 0 then return end
	for index, frame in pairs(cooldowns) do
		if frame.name == spell then
			if not failborder then
				failborder = CreateFrame("Frame", nil, CoolLine.border)
				failborder:SetBackdrop(iconback)
				failborder:SetBackdropColor(1, 0, 0, 0.9)
				failborder:Hide()
				failborder:SetScript("OnUpdate", function(this, a1)
					this.alp = this.alp - a1
					if this.alp < 0 then return this:Hide() end
					this:SetAlpha(this.alp > 1 and 1 or this.alp)
				end)
			end
			failborder.alp = 1.2
			failborder:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
			failborder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
			failborder:Show()
			break
		end
	end

end


local CoolLineDD
local info = { }
function ShowOptions(a1)
	if type(a1) == "string" and a1 ~= "" and a1 ~= "menu" and a1 ~= "options" and a1 ~= "help" then
		if strmatch(a1, "|H") then
			a1 = strmatch(a1, "|h%[(.+)%]|h")
		end
		if a1 then
			if block[a1] then
				block[a1] = nil
				print("|cff88ffffCool|r|cff88ff88Line|r: |cffffff00"..a1.."|r removed from filter.")
			else
				block[a1] = true
				print("|cff88ffffCool|r|cff88ff88Line|r: |cffffff00"..a1.."|r added to filter.")
			end
		end
		return
	end
	if not CoolLineDD then
		CoolLineDD = CreateFrame("Frame", "CoolLineDD", UIParent)
		CoolLineDD.displayMode = "MENU"

		local function Set(b, a1)
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
						db.w, db.h = floor(CoolLine:GetWidth() + 0.5), floor(CoolLine:GetHeight() + 0.5)
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
		local function SetSelect(b, a1)
			db[a1] = tonumber(b.value) or b.value
			local level, num = strmatch(b:GetName(), "DropDownList(%d+)Button(%d+)")
			level, num = tonumber(level) or 0, tonumber(num) or 0
			for i = 2, level, 1 do
				for j = 1, UIDROPDOWNMENU_MAXBUTTONS, 1 do
					local check = _G["DropDownList"..i.."Button"..j.."Check"]
					if check and i == level and j == num then
						check:Show()
					elseif b then
						check:Hide()
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
		local function HideCheck(b)
			if b and b.GetName and _G[b:GetName().."Check"] then
				_G[b:GetName().."Check"]:Hide()
			end
		end
		local function AddButton(lvl, text, keepshown)
			info.text = text
			info.keepShownOnClick = keepshown
			UIDropDownMenu_AddButton(info, lvl)
			wipe(info)
		end
		local function AddToggle(lvl, text, value)
			info.arg1 = value
			info.func = Set
			if value == "unlock" then
				info.checked = CoolLine.unlock
			else
				info.checked = db[value]
			end
			AddButton(lvl, text, 1)
		end
		local function AddList(lvl, text, value)
			info.value = value
			info.hasArrow = true
			info.func = HideCheck
			AddButton(lvl, text, 1)
		end
		local function AddSelect(lvl, text, arg1, value)
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
			AddButton(lvl, text, 1)
		end
		local function AddColor(lvl, text, value)
			local dbc = db[value]
			if not dbc then return end
			info.hasColorSwatch = true
			info.hasOpacity = 1
			info.r, info.g, info.b, info.opacity = dbc.r, dbc.g, dbc.b, 1 - dbc.a
			info.swatchFunc, info.opacityFunc, info.cancelFunc = SetColor, SetColor, SetColor
			info.value = value
			info.func = UIDropDownMenuButton_OpenColorPicker
			AddButton(lvl, text, nil)
		end
		CoolLineDD.initialize = function(self, lvl)
			if lvl == 1 then
				info.isTitle = true
				AddButton(lvl, "|cff88ffffCool|r|cff88ff88Line|r")
				AddList(lvl, "Texture", "statusbar")
				AddColor(lvl, "Texture Color", "bgcolor")
				AddList(lvl, "Border", "border")
				AddColor(lvl, "Border Color", "bordercolor")
				AddList(lvl, "Font", "font")
				AddColor(lvl, "Font Color", "fontcolor")
				AddList(lvl, "Font Size", "fontsize")
				AddColor(lvl, "My Spell Color", "spellcolor")
				AddColor(lvl, "Item/Pet Color", "nospellcolor")
				AddList(lvl, "Inactive Opacity", "inactivealpha")
				AddList(lvl, "Active Opacity", "activealpha")
				AddToggle(lvl, "Vertical", "vertical")
				AddToggle(lvl, "Reverse", "reverse")
				AddToggle(lvl, "Disable Cast Fail", "hidefail")
				AddToggle(lvl, "Disable Equipped", "hideinv")
				AddToggle(lvl, "Disable Bags", "hidebag")
				AddToggle(lvl, "Disable Pet", "hidepet")
				AddToggle(lvl, "Unlock", "unlock")
			elseif lvl and lvl > 1 then
				local sub = UIDROPDOWNMENU_MENU_VALUE
				if sub == "font" or sub == "statusbar" or sub == "border" then
					local t = smed:List(sub)
					local starti = 20 * (lvl - 2) + 1
					local endi = 20 * (lvl - 1)
					for i = starti, endi, 1 do
						if not t[i] then break end
						AddSelect(lvl, t[i], sub, t[i])
						if i == endi and t[i + 1] then
							AddList(lvl, "More", sub)
						end	
					end
				elseif sub == "fontsize" then
					for i = 5, 12, 1 do
						AddSelect(lvl, i, "fontsize", i)
					end
					for i = 14, 28, 2 do
						AddSelect(lvl, i, "fontsize", i)
					end
				elseif sub == "inactivealpha" or sub == "activealpha" then
					for i = 0, 1, 0.1 do
						AddSelect(lvl, format("%.1f", i), sub, i)
					end
				end
			end
		end
	end
	ToggleDropDownMenu(1, nil, CoolLineDD, "cursor")
end

