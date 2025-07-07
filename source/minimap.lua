AceGUI = LibStub("AceGUI-3.0")
PuGMinimapButton = CreateFrame("Button", "PuGKingsMinimapButton", UIParent, "GameMenuButtonTemplate")
PuGMinimapButton:SetSize(24, 24)
PuGMinimapButton:SetNormalTexture("Interface\\AddOns\\PuGKings\\icons\\pugkings")
PuGMinimapButton:SetPoint("CENTER", Minimap, -94, -114)

PuGMinimapButton:SetMovable(true)
PuGMinimapButton:EnableMouse(true)
PuGMinimapButton:RegisterForDrag("LeftButton")
local minimapShapes = {
	["ROUND"] = {true, true, true, true},
	["SQUARE"] = {false, false, false, false},
	["CORNER-TOPLEFT"] = {false, false, false, true},
	["CORNER-TOPRIGHT"] = {false, false, true, false},
	["CORNER-BOTTOMLEFT"] = {false, true, false, false},
	["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
	["SIDE-LEFT"] = {false, true, false, true},
	["SIDE-RIGHT"] = {true, false, true, false},
	["SIDE-TOP"] = {false, false, true, true},
	["SIDE-BOTTOM"] = {true, true, false, false},
	["TRICORNER-TOPLEFT"] = {false, true, true, true},
	["TRICORNER-TOPRIGHT"] = {true, false, true, true},
	["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
	["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function IconMoveButton(self)
	if self.dragMode == "free" then
		local centerX, centerY = Minimap:GetCenter()
		local x, y = GetCursorPosition()
		x, y = x / self:GetEffectiveScale() - centerX, y / self:GetEffectiveScale() - centerY
		self:ClearAllPoints()
		self:SetPoint("CENTER", x, y)
	else
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		
		local angle = math.atan2(py - my, px - mx)
		local x, y, q = math.cos(angle), math.sin(angle), 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end
---@diagnostic disable-next-line: undefined-global
		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local quadTable = minimapShapes[minimapShape]
		local w = (Minimap:GetWidth() / 2) + 5
		local h = (Minimap:GetHeight() / 2) + 5
		if quadTable[q] then
			x, y = x*w, y*h
		else
			local diagRadiusW = sqrt(2*(w)^2)-10
			local diagRadiusH = sqrt(2*(h)^2)-10
			x = max(-w, min(x*diagRadiusW, w))
			y = max(-h, min(y*diagRadiusH, h))
		end
		self:ClearAllPoints()
		self:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end
end

PuGMinimapButton:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", IconMoveButton)
	self.isMoving = true
	GameTooltip:Hide()
end)

PuGMinimapButton:SetScript("OnDragStop", function(self)
	self:UnlockHighlight()
	self:SetScript("OnUpdate", nil)
	self.isMoving = false
	local point, _, _, xOfs, yOfs = self:GetPoint()
	-- Save the button position to PuGKingsDB for future use
	if not PuGKingsDB.minimapPos then
		PuGKingsDB.minimapPos = {}
	end
	PuGKingsDB.minimapPos = {point, xOfs, yOfs}
end)

