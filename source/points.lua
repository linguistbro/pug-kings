-- Variables --
local raidDPSAndHealers = {}
local raidersProgComp = {}
local lastEncounterID
local lastEncounterName
local leaderboardFrame	
local PurgeDataFrame = nil
local purgeAll = true
local fightStartTime = nil 
local unitsWithBuffs = {}

local function StripRealm(name)
    return strsplit("-", name)  -- returns just the player name
end

function DebugPrintTable(tbl, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    if type(tbl) ~= "table" then
        print(prefix .. tostring(tbl))
        return
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. ":")
            DebugPrintTable(v, indent + 1)
        else
            print(prefix .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

local function SaveRaidDPSAndHealers()
    if not PuGKingsDB then
        PuGKingsDB = {}  -- Initialize the SavedVariables if it doesn't exist
    end
    PuGKingsDB.raidDPSAndHealers = raidDPSAndHealers  -- Save the data
	PuGKingsDB.raidersProgComp = raidersProgComp

    local dataToSend = {
        raidDPSAndHealers = PuGKingsDB.raidDPSAndHealers,
        raidersProgComp = PuGKingsDB.raidersProgComp,
    }
    
    PuGKingsAddon:Transmit(dataToSend)
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Saved DPS and Healers to SavedVariables.") end
end

local function LoadRaidDPSAndHealers()
    if PuGKingsDB then
        if PuGKingsDB.raidDPSAndHealers then raidDPSAndHealers = PuGKingsDB.raidDPSAndHealers end
		if PuGKingsDB.raidersProgComp then raidersProgComp = PuGKingsDB.raidersProgComp  end
        if PuGAddonDebug then print(PuGAddonDebugPrefix ..  "Loaded saved raid DPS and Healers.") end 
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No saved DPS and Healers found.") end
    end
end

LoadRaidDPSAndHealers()

local function FindCombatForEncounter(encounterID, encounterName)
    if not encounterID or not encounterName then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No encounter ID or encounter name found, returning nil.") end
        return nil
    end

    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Looking for combat data for: " .. (encounterName or "unknown") .. " (ID: " .. (encounterID or "unknown") .. ")") end
    local segments = _detalhes:GetCombatSegments()
    -- Try an exact match on both ID and name
    for _, segment in ipairs(segments) do
        if segment.is_boss then
            local idMatch = segment.is_boss.id == encounterID
            local nameMatch = segment.is_boss.encounter == encounterName
            
            if idMatch and nameMatch then
                if PuGAddonDebug then print(PuGAddonDebugPrefix ..  "Found exact match for " .. encounterName) end
                print(PuGAddonDebugPrefix ..  "Found exact match for " .. encounterName)
                return segment
            end
        end
    end
    
    -- Try matching just by ID
    for _, segment in ipairs(segments) do
        if segment.is_boss and segment.is_boss.id == encounterID then
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Found match by ID for " .. encounterName) end
            print(PuGAddonDebugPrefix .. "Found match by ID for " .. encounterName)
            return segment
        end
    end

    for _, segment in ipairs(segments) do
        if segment.is_boss then
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Using most recent boss combat: " .. (segment.is_boss.encounter or "Unknown")) end
            return segment
        end
    end

    if PuGAddonDebug then    
        if #segments > 0 then
            if PuGAddonDebug then print(PuGAddonDebugPrefix ..  "Using most recent combat segment (not identified as boss)") end
            return segments[1]
        end
    end

    if PuGAddonDebug then print(PuGAddonDebugErrorPrefix ..  "No suitable combat segments found") end
    return nil
end

function PuGAddPointEntry(player, bossID, bossName, reason, points)
    -- Ensure player.pointHistory is initialized
    if not player.pointHistory then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Player does not have a point history, creating it.") end
        player.pointHistory = {}
    end

    -- Ensure player.pointHistory[bossID] is initialized
    if not player.pointHistory[bossID] then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Player does not have a point history for this boss " .. bossName .. "(".. bossID .. ")" .. " creating it.") end
        player.pointHistory[bossID] = {}  -- Initialize as an empty table
    end

    -- Now we can safely insert
    table.insert(player.pointHistory[bossID], {
        reason = reason,
        points = points,
        bossName = bossName
    })
end

local function UpdateRosterFromRaidComp(targetRoster, raidComp)
    -- Build a lookup table for existing players by stripped name
    local lookup = {}
    for i = 1, #targetRoster do
        local player = targetRoster[i]
        lookup[StripRealm(player.name)] = player
    end

    -- Clear the target roster without wiping the table object (more efficient)
    table.wipe(targetRoster)

    -- Rebuild targetRoster
    for i = 1, #raidComp do
        local newPlayer = raidComp[i]
        local strippedName = StripRealm(newPlayer.name)

        if lookup[strippedName] then
            -- Old player: reuse their data (preserve history)
            table.insert(targetRoster, lookup[strippedName])
        else
            -- New player: insert fresh player
            table.insert(targetRoster, newPlayer)
        end
    end
end

local function GetRaidPlayers(success)
    local existingPlayers = {}
    local raidComp = {}
    LoadRaidDPSAndHealers()

    if success then
        for _, player in ipairs(raidDPSAndHealers) do
            existingPlayers[StripRealm(player.name)] = player
        end
    else
        for _, player in ipairs(raidersProgComp) do
            existingPlayers[StripRealm(player.name)] = player
        end
    end

    -- Loop through all raid members (up to 40 players)
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(i)
        if name and role then
            local shortName = StripRealm(name)
            local _, class = UnitClass(name)
            local specID = GetSpecializationInfoByID(GetInspectSpecialization(name))

            if existingPlayers[shortName] then
                -- Reuse existing player
                table.insert(raidComp, existingPlayers[shortName])
            else
                -- Create a fresh new player
                table.insert(raidComp, {
                    name = shortName,
                    class = class,
                    specID = specID or 0,
                    role = role,
                    pointHistory = {},
                    damage = 0,
                    healing = 0,
                })
            end
        end
    end

    -- Update the global table
    if success then
        UpdateRosterFromRaidComp(raidDPSAndHealers, raidComp)
        if PuGAddonDebug then
            print("==DEBUG==")
            print("DPS and Healers in Raid:")
            for _, player in ipairs(raidComp) do
                print(player.name .. " - " .. player.role)
            end
        end
    else
        UpdateRosterFromRaidComp(raidersProgComp, raidComp)
        if PuGAddonDebug then
            print("==DEBUG==")
            print("DPS and Healers in Raid:")
            for _, player in ipairs(raidComp) do
                print(player.name .. " - " .. player.role)
            end
        end
    end
    SaveRaidDPSAndHealers()
end

local function UpdatePlayerPerformance(success)
    if not lastEncounterID or not lastEncounterName then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No last encounter ID or last encounter name found.") end
        return
    end
    local combat = FindCombatForEncounter(lastEncounterID, lastEncounterName)
    if not combat then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No matching combat segment found for " .. (lastEncounterName or "unknown")) end
        return false
    end

    local damage_container = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    local healing_container = combat:GetContainer(DETAILS_ATTRIBUTE_HEAL)
    
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Combat data found. Damage container: " .. (damage_container and "Yes" or "No") .. ", Healing container: " .. (healing_container and "Yes" or "No")) end
    
	local compToCheck = {}
	
    -- Reset performance values
	if success then
		compToCheck = raidDPSAndHealers
	else
		compToCheck = raidersProgComp
	end
	
	for _, player in ipairs(compToCheck) do
		player.damage = 0
		player.healing = 0
	end

    -- Debug - Get segment information
    if PuGAddonDebug then
        print("== DEBUG: Combat segment information ==")
        print("Combat ID: " .. (combat.combat_id or "unknown"))
        print("Boss name: " .. (combat.enemy or "unknown"))

        if combat.CombatEndedAt and combat.CombatStartedAt then
            print("Combat duration: " .. (combat.CombatEndedAt - combat.CombatStartedAt) .. " seconds")
        end
    end

    -- Debug - List all actors in the damage container
    if damage_container then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "All actors in damage meter") end
        for index, actor in damage_container:ListActors() do
            if actor:IsPlayer() then
                -- Format damage in millions for readability
                local damage_millions = actor.total / 1000000
                if PuGAddonDebug then print(actor:GetOnlyName() .. " - Damage: " .. string.format("%.2fM", damage_millions)) end
                -- Get detailed actor info
                --print("  Class: " .. (actor.classe or "unknown"))
                --print("  Spec: " .. (actor.spec or "unknown"))
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage data available in this combat segment") end
    end
	
    -- Debug - List all actors in the healing container
    if healing_container then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "All actors in healing meter") end
        for index, actor in healing_container:ListActors() do
            if actor:IsPlayer() and actor.total > 10000000 then
                -- Format damage in millions for readability
                local healing_millions = actor.total / 1000000
                if PuGAddonDebug then print(actor:GetOnlyName() .. " - Healing: " .. string.format("%.2fM", healing_millions)) end
                
                -- Get detailed actor info
                --print("  Class: " .. (actor.classe or "unknown"))
                --print("  Spec: " .. (actor.spec or "unknown"))
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No healing data available in this combat segment") end
    end

    -- Match players with their performance data
    local matches = 0
    for _, player in ipairs(compToCheck) do
        local playerName = StripRealm(player.name)
        --print("Looking for player: " .. playerName)
        
        if (player.role == "DAMAGER" or player.role == "TANK") and damage_container then
            local found = false
            for index, actor in damage_container:ListActors() do
                local actorName = actor:GetOnlyName()
				local class = actor:class()
                if actor:IsPlayer() and (actorName == playerName or actorName == player.name) then
                    player.damage = actor.total or 0
                    matches = matches + 1
                    --print("✓ Matched DPS player: " .. playerName .. " with damage: " .. string.format("%.2fM", player.damage/1000000))
                    found = true
                    break
                end
            end
            if not found then
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "✗ Could not find DPS player: " .. playerName .. " in damage meter") end
            end
        elseif player.role == "HEALER" and healing_container then
            local found = false
            for index, actor in healing_container:ListActors() do
                local actorName = actor:GetOnlyName()
                if actor:IsPlayer() and (actorName == playerName or actorName == player.name) then
                    player.healing = actor.total or 0
                    matches = matches + 1
                    --print("✓ Matched Healer: " .. playerName .. " with healing: " .. string.format("%.2fM", player.healing/1000000))
                    found = true
                    break
                end
            end
            if not found then
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "✗ Could not find Healer: " .. playerName .. " in healing meter") end
            end
        end
    end
    
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Matched " .. matches .. " players with performance data") end
    
    -- If we don't have healing data, we need to handle healers differently
    local healersPresent = false
    for _, player in ipairs(compToCheck) do
        if player.role == "HEALER" then
            healersPresent = true
            break
        end
    end
    
    if healersPresent and not healing_container then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Warning: Healers are present but no healing data available.") end
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Assigning default points to healers.") end
    end

    return matches > 0 or (damage_container ~= nil)
end

local function AssignPoints(success)
    --print("== DEBUG: Performance before sorting ==")
    --for _, player in ipairs(raidDPSAndHealers) do
    --    if player.role == "DAMAGER" then
    --        print(player.name .. " - Damage: " .. string.format("%.2fM", player.damage/1000000))
    --    elseif player.role == "HEALER" then
    --        print(player.name .. " - Healing: " .. string.format("%.2fM", player.healing/1000000))
    --    end
    --end

    -- Sort DPS and healers separately
    local dps = {}
    local healers = {}
	local pointsRaidComp = {}
	if success then
		pointsRaidComp = raidDPSAndHealers
	else
		pointsRaidComp = raidersProgComp
	end
    for _, player in ipairs(pointsRaidComp) do
        if player.role == "HEALER" then
            table.insert(healers, player)
        else
            table.insert(dps, player)
        end
    end
    
    -- Sort DPS by damage
    table.sort(dps, function(a, b)
        return a.damage > b.damage
    end)
    
    -- Sort healers by healing
    table.sort(healers, function(a, b)
        return a.healing > b.healing
    end)
    
    if PuGAddonDebug then
        print("== DEBUG: After sorting ==")
        print("DPS Rankings:")
        for i, player in ipairs(dps) do
            print(i .. ". " .. player.name .. " - " .. string.format("%.2fM", player.damage/1000000))
        end
        
        print("Healer Rankings:")
        for i, player in ipairs(healers) do
            print(i .. ". " .. player.name .. " - " .. string.format("%.2fM", player.healing/1000000))
        end
    end
    -- Assign points - DPS
    for i, player in ipairs(dps) do
        -- Only assign points if they actually did damage
        if player.damage > 0 then
            local newPoints = (#dps - i + 1)
			if player.role == "TANK" then
				newPoints = newPoints + 2
			end
			PuGAddPointEntry(player, lastEncounterID, lastEncounterName, "Overall DPS", newPoints)
            --player.points = (player.points or 0) + newPoints
        else
            if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Skipping " .. player.name .. " - no damage recorded") end
        end
    end
    

	-- Normal assignment when we have healing data
	for i, player in ipairs(healers) do
		if player.healing > 0 then
			local newPoints = (#dps - i + 1)
			PuGAddPointEntry(player, lastEncounterID, lastEncounterName, "Overall Healing", newPoints)
			--player.points = (player.points or 0) + newPoints
		else
			if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Skipping " .. player.name .. " - no healing recorded") end
		end
	end
	
	local combat = FindCombatForEncounter(lastEncounterID, lastEncounterName)

	--LOA Points (3009-3016)
	if lastEncounterID == 3009 then
		PugAddVexiePoints(combat, pointsRaidComp)
	elseif lastEncounterID == 3010 then
		PuGAddCauldronPoints(combat, pointsRaidComp)
	elseif lastEncounterID == 3011 then
		PuGAddRikPoints(combat, pointsRaidComp)
	elseif lastEncounterID == 3012 then
		PuGAddStixPoints(combat, pointsRaidComp)
    elseif lastEncounterID == 3013 then
        PuGAddSprocketPoints(combat, pointsRaidComp)
    elseif lastEncounterID == 3014 then
        PuGAddBanditPoints(combat, pointsRaidComp)
    elseif lastEncounterID == 3015 then
        PuGAddMugzeePoints(combat, pointsRaidComp)
    elseif lastEncounterID == 3016 then
        PuGAddGallywixPoints(combat, pointsRaidComp)
    end
    PuGCheckPotionBuffs(pointsRaidComp, combat, lastEncounterID, lastEncounterName)
    PuGGiveBuffPoints(pointsRaidComp, lastEncounterID, lastEncounterName, unitsWithBuffs)
	SaveRaidDPSAndHealers()
	PuGShowLeaderboard()
end

local function PurgeSavedData()
	if PuGKingsDB then
        if purgeAll == true then
            PuGKingsDB.raidDPSAndHealers = nil
            PuGKingsDB.raidersProgComp = nil
            wipe(raidDPSAndHealers)
            wipe(raidersProgComp)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Purge complete: All data has been reset.") end
        else
            PuGKingsDB.raidersProgComp = nil
            wipe(raidersProgComp)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Purge complete: Prog data has been reset.") end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No saved data found to purge.") end
    end

    -- Refresh the leaderboard UI if it's visible
    if leaderboardFrame and leaderboardFrame:IsShown() then
        PuGShowLeaderboard("ALL")
    end
end

local function CreatePurgeFrame()
    if PurgeDataFrame ~= nil then
        PurgeDataFrame:Show()
        return
    end
    
    PurgeDataFrame = CreateFrame("Frame", "PuGKingsPurgePrompt", UIParent, "BasicFrameTemplateWithInset")
    PurgeDataFrame:SetSize(250, 120)
    PurgeDataFrame:SetPoint("CENTER")
    PurgeDataFrame:SetMovable(true)
    PurgeDataFrame:EnableMouse(true)
    PurgeDataFrame:RegisterForDrag("LeftButton")
    PurgeDataFrame:SetScript("OnDragStart", PurgeDataFrame.StartMoving)
    PurgeDataFrame:SetScript("OnDragStop", PurgeDataFrame.StopMovingOrSizing)

    -- Title
    PurgeDataFrame.title = PurgeDataFrame:CreateFontString(nil, "OVERLAY")
    PurgeDataFrame.title:SetFontObject("GameFontHighlight")
    PurgeDataFrame.title:SetPoint("CENTER", PurgeDataFrame.TitleBg, "CENTER")
    PurgeDataFrame.title:SetText("PuG Kings")

    -- Question
    PurgeDataFrame.question = PurgeDataFrame:CreateFontString(nil, "OVERLAY")
    PurgeDataFrame.question:SetFontObject("GameFontNormal")
    PurgeDataFrame.question:SetPoint("TOP", PurgeDataFrame, "TOP", 0, -30)
    PurgeDataFrame.question:SetText("Do you want to purge saved data?")

    -- YES button
    PurgeDataFrame.yesButton = CreateFrame("Button", nil, PurgeDataFrame, "UIPanelButtonTemplate")
    PurgeDataFrame.yesButton:SetSize(80, 22)
    PurgeDataFrame.yesButton:SetPoint("BOTTOMLEFT", PurgeDataFrame, "BOTTOMLEFT", 20, 15)
    PurgeDataFrame.yesButton:SetText("Yes")
    PurgeDataFrame.yesButton:SetScript("OnClick", function()
        PurgeSavedData()
        PurgeDataFrame:Hide()
    end)

    -- NO button
    PurgeDataFrame.noButton = CreateFrame("Button", nil, PurgeDataFrame, "UIPanelButtonTemplate")
    PurgeDataFrame.noButton:SetSize(80, 22)
    PurgeDataFrame.noButton:SetPoint("BOTTOMRIGHT", PurgeDataFrame, "BOTTOMRIGHT", -20, 15)
    PurgeDataFrame.noButton:SetText("No")
    PurgeDataFrame.noButton:SetScript("OnClick", function()
        PurgeDataFrame:Hide()
    end)
end

local function OnEncounterEnd(encounterID, encounterName, difficulty, size, success)
    if PuGAddonDebug then print(PuGAddonDebugPrefix ..  "Encounter ended: " .. encounterName .. " (ID: " .. encounterID .. ")") end
    lastEncounterID = encounterID
    lastEncounterName = encounterName

    -- Wait a bit longer for Details! to process the combat data
    C_Timer.After(3, function()
        GetRaidPlayers(success)
        local validData = UpdatePlayerPerformance(success)
        if validData then
            AssignPoints(success)
        else
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "First attempt: Unable to get valid performance data, retrying in 2 seconds...") end
            -- Try again after a bit more time
            C_Timer.After(2, function()
                validData = UpdatePlayerPerformance(success)
                if validData then
                    AssignPoints(success)
                else
                    if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "Could not find valid combat data for this encounter. Points not assigned.") end
                     -- Offer manual update option
                     if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "You can try manually updating with /pugupdate when combat data is available") end
                end
            end)
        end
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
	local addonName = ...
	if addonName == "Details" then
		if _detalhes and _detalhes.EncounterEndCallbacks then
			if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Details loaded and ready.") end
		else
			if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Details loaded, but _detalhes not ready.") end
		end
	end
end)

local endRaidFrame = CreateFrame("Frame")
endRaidFrame:RegisterEvent("ENCOUNTER_END")
endRaidFrame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, groupSize, success)
    if not encounterID then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No encounter ID registered.") end
        return
    end
    local isInsideLuo = false
    for bossID in pairs(PuGLuoBossNames) do
        if encounterID == bossID then
            isInsideLuo = true
            break
        end
    end
    if not isInsideLuo then
        return
    end
    if success == 1 then
        OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, true)
        if raidersProgComp then wipe(raidersProgComp) end
        if PuGKingsDB.raidersProgComp then wipe(PuGKingsDB.raidersProgComp) end
    else
        if fightStartTime then
            local fightDuration = GetTime() - fightStartTime  -- Duration in seconds
            if fightDuration > 60 then
                OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, false)
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Encounter failed after " .. fightDuration/100 .. " seconds.") end
            else
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. 'Encounter failed before 1 minute (' .. fightDuration/100 .. '), not counting points.') end
            end
        end
    end
    PuGCombatLogListener(false)
    PuGWoWChatListener(false)
end)

local startRaidFrame = CreateFrame("Frame")
startRaidFrame:RegisterEvent("ENCOUNTER_START")
startRaidFrame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, groupSize)
    local validDifficulties = {14, 15, 16, 17}
    if tContains(validDifficulties, difficultyID) and tContains(PuGLouBossIds, encounterID) then
        fightStartTime = GetTime()
        PuGCombatLogListener(true)
        PuGWoWChatListener(true)
        PuGLouListeners(encounterID)
        unitsWithBuffs = {}  -- Reset buffs for the new encounter
        unitsWithBuffs = PuGCalculateBuffPoints()
    end
end)

local instanceCheckFrame = CreateFrame("Frame")
instanceCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceCheckFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    local isInInstance, instanceType = IsInInstance()
    if isInInstance and (instanceType == "raid") then
        C_Timer.After(2, function()  -- Small delay to make it smoother
            CreatePurgeFrame()
        end)
    end
end)

--SLASH COMMANDS FOR DEBUGGING--
SLASH_PURGEPUGKINGS1 = "/purge"
SlashCmdList["PURGEPUGKINGS"] = function () 
    PuGAddonDebug = true
    CreatePurgeFrame()
    PuGAddonDebug = false
end

SLASH_PUGUPDATE1 = "/pugupdate"
SLASH_GETPLAYERS1 = "/pugplayers"
SLASH_UPDATEPERFORMANCE1 = "/pugperformance"
SLASH_PUGKINGSLEADERBOARD1 = "/pugboard"

SlashCmdList["PUGKINGSLEADERBOARD"] = function() 
    PuGAddonDebug = true
    PuGShowLeaderboard("ALL")   
    PuGAddonDebug = false
end

SlashCmdList["GETPLAYERS"] = function()
    PuGAddonDebug = true
	GetRaidPlayers(false)
    PuGAddonDebug = false
end

SlashCmdList["UPDATEPERFORMANCE"] = function() 
    PuGAddonDebug = true
    UpdatePlayerPerformance() 
    PuGAddonDebug = false
end

SlashCmdList["PUGUPDATE"] = function()
    PuGAddonDebug = true
    local validData = UpdatePlayerPerformance()
    if validData then
        AssignPoints(false)
        SaveRaidDPSAndHealers()
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Manual update successful!") end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Could not find valid combat data. Make sure you've completed an encounter and Details! has recorded it.") end
    end
    PuGAddonDebug = false
end

local function TestFunction()
    PuGAddonDebug = true
	local player = {
		name = "Test",
		class = "WARRIOR",
		specID = 0,
		role = "TANK",
		pointHistory = {},
		damage = 200000,
		healing = 0,
	}
	table.insert(raidDPSAndHealers, player)
	PuGAddPointEntry(player, 3010, "TestBoss", "Test Reason 1", 2)
	PuGAddPointEntry(player, 3011, "TestBoss", "Test Reason 2", 5)
	SaveRaidDPSAndHealers()
    PuGAddonDebug = false
end

local function TestFunction2()
    local segments = _detalhes:GetCombatSegments()
    for _, segment in ipairs(segments) do
        print(segment.is_boss.encounter)
        print(segment.is_boss.id)
    end
end


SLASH_PUGTEST1 = "/pugtest"
SlashCmdList["PUGTEST"] = function() TestFunction() end

SLASH_SHOWPUGSCORE1 = "/pugscore"
SlashCmdList["SHOWPUGSCORE"] = function()
    PuGAddonDebug = true
	LoadRaidDPSAndHealers()
    if PuGKingsDB and raidDPSAndHealers then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Current PuG Kings Scores:") end
        for _, player in ipairs(PuGKingsDB.raidDPSAndHealers) do
            --print(player.name .. " - " .. player.role .. " - " .. (player.points or 0) .. " points")
			print('WIP')
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No score data available.") end
    end
    PuGAddonDebug = false
end

local optionsFrame = nil

local function CreateOptionsFrame()
    if optionsFrame ~= nil and optionsFrame:IsShown() then
        optionsFrame:Hide()
        return
    end
    if optionsFrame ~= nil and not optionsFrame:IsShown() then
        optionsFrame:Show()
        return
    end
    if not optionsFrame then
        -- Create the main frame if it doesn't exist yet
        optionsFrame = CreateFrame("Frame", "PuGKingsOptions", PuGMinimapButton, "BasicFrameTemplateWithInset")
        optionsFrame:SetSize(150, 200)
        optionsFrame:SetPoint('CENTER', PuGMinimapButton, -85, -85)
        optionsFrame:SetMovable(false)
        optionsFrame:EnableMouse(true)
        -- Set up title
        optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY")
        optionsFrame.title:SetFontObject("GameFontHighlight")
        optionsFrame.title:SetPoint("LEFT", optionsFrame.TitleBg, "LEFT", 5, 0)
        optionsFrame.title:SetText("Options")

        -- Create the "Purge All Data" button
        local purgeAllButton = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
        purgeAllButton:SetSize(120, 30)
        purgeAllButton:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -30)
        purgeAllButton:SetText("Purge All Data")
        purgeAllButton:SetNormalFontObject("GameFontNormal")

        purgeAllButton:SetScript("OnClick", function()
            -- Purge all data from PuGKingsDB
            purgeAll = true
            CreatePurgeFrame()
        end)

        -- Create the "Purge Prog. Data" button
        local purgeProgDataButton = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
        purgeProgDataButton:SetSize(120, 30)
        purgeProgDataButton:SetPoint("TOPLEFT", purgeAllButton, "BOTTOMLEFT", 0, -10)
        purgeProgDataButton:SetText("Purge Prog. Data")
        purgeProgDataButton:SetNormalFontObject("GameFontNormal")

        purgeProgDataButton:SetScript("OnClick", function()
            purgeAll = false
            CreatePurgeFrame()
        end)
        
        -- Create the "Update Comm. Cache" button
        local updateCommunityButton = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
        updateCommunityButton:SetSize(120, 30)
        updateCommunityButton:SetPoint("TOPLEFT", purgeProgDataButton, "BOTTOMLEFT", 0, -10)
        updateCommunityButton:SetText("Update Comm. Cache")
        updateCommunityButton:SetNormalFontObject("GameFontNormal")

        updateCommunityButton:SetScript("OnClick", function()
            PuGUpdateCommunityCache()
        end)

        -- Create the checkbox for "Enable Debug"
        local enableDebugCheckbox = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        enableDebugCheckbox:SetPoint("TOPLEFT", updateCommunityButton, "TOPLEFT", 0, -30)
        enableDebugCheckbox.text:SetText("Enable Debugging")
        
        -- Set the initial checkbox state based on the saved variable
        local isChecked = PuGAddonDebug
        if PuGKingsDB and PuGKingsDB.enableDebug then
            isChecked = PuGKingsDB.enableDebug
        end

        enableDebugCheckbox:SetChecked(isChecked)       
        -- Add a callback to save the state when toggled
        enableDebugCheckbox:SetScript("OnClick", function(self)
            if self:GetChecked() then
                PuGKingsDB.PuGAddonDebug = true
                PuGAddonDebug = true
            else
                PuGKingsDB.PuGAddonDebug = false
                PuGAddonDebug = false
            end
        end)
    end
end

PuGMinimapButton:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        CreateOptionsFrame()
    elseif button == "LeftButton" then
        PuGShowLeaderboard("ALL")
    end
end)
