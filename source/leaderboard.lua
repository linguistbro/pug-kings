local leaderboardFrame = nil
local leaderboardFrame2 = nil
local detailsFrame = nil
local leaderboardLines = {}
local leaderboardDetailLines = {}
local currentFilter = "ALL"

local function CalculateBossPoints(player, bossID)
    local total = 0
    local bossName = "Unknown"
    if player.pointHistory[bossID] then
        bossName = player.pointHistory[bossID][1].bossName or "Unknown"
        for _, entry in pairs(player.pointHistory[bossID]) do
			total = total + (entry.points or 0)
        end
    end
    return total, bossName
end

local function CalculateTotalPoints(player)
    local total = 0
    if player.pointHistory then
		--if PuGAddonDebug then print(player.name .. ' has point history') end
        for bossID, entries in pairs(player.pointHistory) do
			--if PuGAddonDebug then print('Found entry for Boss ID: ' .. bossID) end 		
            for _, entry in ipairs(entries) do
				--if PuGAddonDebug then print('Points :' .. entry.points) end
                total = total + (entry.points or 0)
            end
        end
    end
    return total
end

local function GetSortedPlayersByPoints(raidCompName, currentFilter)
    local sorted = {}
    if raidCompName then
        for _, player in ipairs(raidCompName) do
            if currentFilter == "ALL" or currentFilter == "PROG" then
                player.totalPoints = CalculateTotalPoints(player)
                table.insert(sorted, player)
            elseif currentFilter == "HEALER" then 
                if player.role == "HEALER" then
                    player.totalPoints = CalculateTotalPoints(player)
                    table.insert(sorted, player)
                end
            elseif currentFilter == "DAMAGER" then
                if player.role ~= "HEALER" then
                    player.totalPoints = CalculateTotalPoints(player)
                    table.insert(sorted, player)
                end
            end
        end
    end

    table.sort(sorted, function(a, b)
        return (a.totalPoints or 0) > (b.totalPoints or 0)
    end)

    return sorted
end

local function CreateDetailsFrame(player)
    -- Create the main frame if it doesn't exist yet
	detailsFrame = CreateFrame("Frame", "LeaderboardDetails", UIParent, "BasicFrameTemplateWithInset")
	detailsFrame:SetSize(250, 200)
    if PuGKingsDB and PuGKingsDB.detailsFramePosition then
        local point, relativePoint, xOfs, yOfs = unpack(PuGKingsDB.detailsFramePosition)
        detailsFrame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    else
        detailsFrame:SetPoint("CENTER")
    end

	detailsFrame:SetMovable(true)
	detailsFrame:EnableMouse(true)
	detailsFrame:RegisterForDrag("LeftButton")
	detailsFrame:SetScript("OnDragStart", detailsFrame.StartMoving)
	detailsFrame:SetScript("OnDragStop", detailsFrame.StopMovingOrSizing)
	
	-- Set up title
	detailsFrame.title = detailsFrame:CreateFontString(nil, "OVERLAY")
	detailsFrame.title:SetFontObject("GameFontHighlight")
	detailsFrame.title:SetPoint("LEFT", detailsFrame.TitleBg, "LEFT", 5, 0)
	detailsFrame.title:SetText(player.name .. " Details")
	
	-- Create the scroll frame
	detailsFrame.scrollFrame = CreateFrame("ScrollFrame", nil, detailsFrame, "UIPanelScrollFrameTemplate")
	detailsFrame.scrollFrame:SetPoint("TOPLEFT", 10, -10) -- Adjusted to make room for tabs
	detailsFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
	
	detailsFrame.content = CreateFrame("Frame", nil, detailsFrame.scrollFrame)
	detailsFrame.scrollFrame:SetScrollChild(detailsFrame.content)
	detailsFrame.content:SetSize(1, 1)
    detailsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        PuGKingsDB.detailsFramePosition = {point, relativePoint, xOfs, yOfs}
    end)
end

local function ShowLeaderboardDetails(player)
	if detailsFrame ~= nil and detailsFrame:IsShown() then
		detailsFrame:Hide()
	end 

    CreateDetailsFrame(player)
    -- Hide and clear all old lines
    for _, line in ipairs(leaderboardDetailLines) do
        line:Hide()
    end
    wipe(leaderboardDetailLines)
	
	local bossIDs = {}
	for bossID in pairs(player.pointHistory) do
		table.insert(bossIDs, bossID)
	end
	
	local yOffset = -20
    if detailsFrame then
        for i, bossID in ipairs(bossIDs) do
            -- Create text next to class icon
            local line = detailsFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")			
            local totalbosspoints, bossName = CalculateBossPoints(player, bossID)
            line:SetText(i .. ". " .. (PuGLuoBossNames[bossID] or bossName)  .. ": " .. totalbosspoints .. " points")
            line:SetPoint("TOPLEFT", 10, yOffset - (i - 1) * 20)
            line:Show()
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Points Breakdown")
                for _, entry in ipairs(player.pointHistory[bossID]) do
                    GameTooltip:AddLine(entry.points .. " Points: " .. entry.reason, 1, 1, 1)
                end
                GameTooltip:Show()
            end)

            line:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            table.insert(leaderboardDetailLines, line)
        end
	end
end

function PuGShowLeaderboard(filter)
    -- Update filter if provided
    if filter then
        currentFilter = filter
    else
		filter = "ALL"
	end
    
    if leaderboardFrame ~= nil and leaderboardFrame:IsShown() and not filter then
        leaderboardFrame:Hide()
        return
    end
    
    if not leaderboardFrame then
        -- Create the main frame if it doesn't exist yet
        leaderboardFrame = CreateFrame("Frame", "PuGKingsLeaderboard", UIParent, "BasicFrameTemplateWithInset")
        leaderboardFrame:SetResizeBounds(250, 300, 500, 600)
        leaderboardFrame:SetSize(250, 300)
        leaderboardFrame:SetResizable(true)
        if PuGKingsDB and PuGKingsDB.leaderboardFramePosition then
            local point, relativePoint, xOfs, yOfs = unpack(PuGKingsDB.leaderboardFramePosition)
            leaderboardFrame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
        else
            leaderboardFrame:SetPoint("CENTER")
        end
        leaderboardFrame:SetMovable(true)
        leaderboardFrame:EnableMouse(true)
        leaderboardFrame:RegisterForDrag("LeftButton")
        leaderboardFrame:SetScript("OnDragStart", leaderboardFrame.StartMoving)
        leaderboardFrame:SetScript("OnDragStop", leaderboardFrame.StopMovingOrSizing)
        
        -- Set up title
        leaderboardFrame.title = leaderboardFrame:CreateFontString(nil, "OVERLAY")
        leaderboardFrame.title:SetFontObject("GameFontHighlight")
        leaderboardFrame.title:SetPoint("LEFT", leaderboardFrame.TitleBg, "LEFT", 5, 0)
        leaderboardFrame.title:SetText("PuG Kings Leaderboard")

        -- Create the filter tabs
        local tabHeight = 24
        local tabWidth = 35
        local tabSpacing = 5
		
        -- All tab
        leaderboardFrame.allTab = CreateFrame("Button", nil, leaderboardFrame)
        leaderboardFrame.allTab:SetSize(tabWidth, tabHeight)
        leaderboardFrame.allTab:SetPoint("TOPLEFT", leaderboardFrame, "TOPLEFT", 10, -30)
        leaderboardFrame.allTab:SetText("All")
        leaderboardFrame.allTab:SetNormalFontObject("GameFontNormalSmall")
        leaderboardFrame.allTab:SetHighlightFontObject("GameFontHighlightSmall")
        leaderboardFrame.allTab:SetScript("OnClick", function() PuGShowLeaderboard("ALL") end)
        
        -- DPS tab
        leaderboardFrame.dpsTab = CreateFrame("Button", nil, leaderboardFrame)
        leaderboardFrame.dpsTab:SetSize(tabWidth, tabHeight)
        leaderboardFrame.dpsTab:SetPoint("LEFT", leaderboardFrame.allTab, "RIGHT", tabSpacing, 0)
        leaderboardFrame.dpsTab:SetText("DPS")
        leaderboardFrame.dpsTab:SetNormalFontObject("GameFontNormalSmall")
        leaderboardFrame.dpsTab:SetHighlightFontObject("GameFontHighlightSmall")
        leaderboardFrame.dpsTab:SetScript("OnClick", function() PuGShowLeaderboard("DAMAGER") end)
        
        -- Healer tab
        leaderboardFrame.healerTab = CreateFrame("Button", nil, leaderboardFrame)
        leaderboardFrame.healerTab:SetSize(tabWidth, tabHeight)
        leaderboardFrame.healerTab:SetPoint("LEFT", leaderboardFrame.dpsTab, "RIGHT", tabSpacing, 0)
        leaderboardFrame.healerTab:SetText("Healers")
        leaderboardFrame.healerTab:SetNormalFontObject("GameFontNormalSmall")
        leaderboardFrame.healerTab:SetHighlightFontObject("GameFontHighlightSmall")
        leaderboardFrame.healerTab:SetScript("OnClick", function() PuGShowLeaderboard("HEALER") end)
		
		-- Progress
        leaderboardFrame.progTab = CreateFrame("Button", nil, leaderboardFrame)
        leaderboardFrame.progTab:SetSize(tabWidth, tabHeight)
        leaderboardFrame.progTab:SetPoint("LEFT", leaderboardFrame.healerTab, "RIGHT", tabSpacing, 0)
        leaderboardFrame.progTab:SetText("Prog.")
        leaderboardFrame.progTab:SetNormalFontObject("GameFontNormalSmall")
        leaderboardFrame.progTab:SetHighlightFontObject("GameFontHighlightSmall")
        leaderboardFrame.progTab:SetScript("OnClick", function() PuGShowLeaderboard("PROG") end)
        
        -- Refresh button
        leaderboardFrame.refreshButton = CreateFrame("Button", nil, leaderboardFrame, "UIPanelButtonTemplate")
        leaderboardFrame.refreshButton:SetSize(80, 22)
        leaderboardFrame.refreshButton:SetPoint("TOPRIGHT", leaderboardFrame, "TOPRIGHT", -10, -30)
        leaderboardFrame.refreshButton:SetText("Refresh")
        leaderboardFrame.refreshButton:SetScript("OnClick", function() PuGShowLeaderboard(currentFilter) end)
        
        -- Create the scroll frame
        leaderboardFrame.scrollFrame = CreateFrame("ScrollFrame", nil, leaderboardFrame, "UIPanelScrollFrameTemplate")
        leaderboardFrame.scrollFrame:SetPoint("TOPLEFT", 10, -60) -- Adjusted to make room for tabs
        leaderboardFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
        leaderboardFrame.scrollFrame:SetClipsChildren(true)

        leaderboardFrame.content = CreateFrame("Frame", nil, leaderboardFrame.scrollFrame)
        leaderboardFrame.scrollFrame:SetScrollChild(leaderboardFrame.content)
        leaderboardFrame.content:SetSize(1, 1)
        leaderboardFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            PuGKingsDB.leaderboardFramePosition = {point, relativePoint, xOfs, yOfs}
        end)

        local resizeButton = CreateFrame("Button", nil, leaderboardFrame)
        resizeButton:SetSize(16, 16)
        resizeButton:SetPoint("BOTTOMRIGHT", leaderboardFrame, "BOTTOMRIGHT", -5, 5)
        resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeButton:SetScript("OnMouseDown", function(self)
            leaderboardFrame:StartSizing("BOTTOMRIGHT")
        end)
        resizeButton:SetScript("OnMouseUp", function(self)
            leaderboardFrame:StopMovingOrSizing()
            local point, relativeTo, relativePoint, xOfs, yOfs = leaderboardFrame:GetPoint()
            PuGKingsDB.leaderboardFramePosition = {point, relativePoint, xOfs, yOfs}
        end)
        leaderboardFrame:SetScript("OnSizeChanged", function(self)
            PuGKingsDB.leaderboardFrameSize = {self:GetWidth(), self:GetHeight()}        
        end)


    end
    
    -- Update tab highlighting based on current filter
    if leaderboardFrame.allTab then
        local allSelected = currentFilter == "ALL"
        leaderboardFrame.allTab:SetNormalFontObject(allSelected and "GameFontHighlightSmall" or "GameFontNormalSmall")
        leaderboardFrame.dpsTab:SetNormalFontObject(currentFilter == "DAMAGER" and "GameFontHighlightSmall" or "GameFontNormalSmall")
        leaderboardFrame.healerTab:SetNormalFontObject(currentFilter == "HEALER" and "GameFontHighlightSmall" or "GameFontNormalSmall")
		leaderboardFrame.progTab:SetNormalFontObject(currentFilter == "PROG" and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end

    -- Hide and clear all old lines
    for _, line in ipairs(leaderboardLines) do
        line:Hide()
    end
    wipe(leaderboardLines)
    
    -- Sort by points
	local sourceTable
	if currentFilter == "PROG" then
		sourceTable = PuGKingsDB.raidersProgComp
    else
        sourceTable = PuGKingsDB.raidDPSAndHealers
    end

	local sortedScores = GetSortedPlayersByPoints(sourceTable, currentFilter)

    -- Create new lines
    local yOffset = -5
	for i, player in ipairs(sortedScores) do
		-- Create role icon texture (left-most)
		local roleIcon = leaderboardFrame.content:CreateTexture(nil, "OVERLAY")
		roleIcon:SetSize(16, 16)
		roleIcon:SetPoint("TOPLEFT", 10, yOffset - 2)

		if player.role == "DAMAGER" then
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(0.3, 0.6, 0.35, 0.65)
		elseif player.role == "HEALER" then
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(0.3, 0.6, 0.0, 0.3)
		else
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(0, 0.3, 0.35, 0.65)
		end

		-- Create class icon texture next to role icon
		local classIcon = leaderboardFrame.content:CreateTexture(nil, "OVERLAY")
		classIcon:SetSize(16, 16)
		classIcon:SetPoint("LEFT", roleIcon, "RIGHT", 4, 0)
		local classTexPath = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
		local classIconCoords = CLASS_ICON_TCOORDS[player.class]
		if classIconCoords then
			classIcon:SetTexture(classTexPath)
			classIcon:SetTexCoord(unpack(classIconCoords))
		end

		-- Create text next to class icon
		local line = leaderboardFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		line:SetPoint("LEFT", classIcon, "RIGHT", 4, 0)
		local classColor = RAID_CLASS_COLORS[player.class] or NORMAL_FONT_COLOR
		local coloredName = string.format("|cff%02x%02x%02x%s|r",
			classColor.r * 255, classColor.g * 255, classColor.b * 255, player.name)
			
		local totalpoints = CalculateTotalPoints(player)
		line:SetText(i .. ". " .. coloredName .. ": " .. totalpoints .. " points")
		line:Show()
		line:SetScript("OnMouseUp", function() ShowLeaderboardDetails(player) end)
		line:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Points Breakdown")
			local bossIDs = {}
			for bossID in pairs(player.pointHistory) do
				table.insert(bossIDs, bossID)
			end
			for i, bossID in ipairs(bossIDs) do
				local totalbosspoints, bossName = CalculateBossPoints(player, bossID)
                GameTooltip:AddLine((PuGLuoBossNames[bossID] or bossName).. ": " .. totalbosspoints .. " points", 1, 1, 1)
			end
			GameTooltip:AddLine("|cffaaaaaaClick for more details.|r", 1, 1, 1)
			GameTooltip:Show()
		end)

		line:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		
		-- Store all UI elements for cleanup later
		tinsert(leaderboardLines, line)
		tinsert(leaderboardLines, roleIcon)
		tinsert(leaderboardLines, classIcon)

		yOffset = yOffset - 20
	end

    leaderboardFrame.content:SetHeight(math.abs(yOffset))
    leaderboardFrame:Show()
    
    -- Update title to reflect the current filter
    local filterText = currentFilter
    if filterText == "ALL" then filterText = "All Roles"
    elseif filterText == "DAMAGER" then filterText = "DPS"
    elseif filterText == "HEALER" then filterText = "Healers"
	elseif filterText == "PROG" then filterText = "Progression"
    end
    leaderboardFrame.title:SetText("PuG Kings Leaderboard: " .. filterText)
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if prefix == "PuGKingsComm" then
        if PuGAddonDebug then print("Received sync data from |cffFFD700PuG Kings Addon|r") end
        PuGKingsAddon:OnCommReceived(prefix, message, channel, sender)
    end
end)

SLASH_PUGKINGSSYNC1 = "/pugsync"
SlashCmdList["PUGKINGSSYNC"] = function()
    PuGAddonDebug = true
    PuGAddonDebug = false
end

