local function StripRealm(name)
    return strsplit("-", name)  -- returns just the player name
end

local function calculatePoints(amount, amountTable)
    for i = #amountTable, 1, -1 do
        if amount >= amountTable[i] then
            return i
        end
    end
    return 0
end

--- Calculates and applies points for players hit by a specific spell during a boss encounter
---@param spell any This is how you get the spell: sourceNpc = damageContainer:GetSpellSource(spellID) > source = damageContainer:GetActor(sourceNpc) > spell = source:GetSpell(spellID)
---@param raidComp table Raid roster to assign points to (normal comp or progress comp)
---@param spellName string Spell name as string
---@param amountTable table Points to be deducted or awarded based on damage amount
---@param bossID number ID of the boss for this encounter
---@param bossName string Name of the boss for this encounter
---@param awardPoints boolean Deduct or award points 
---@param reason string Reason shown to players
function PuGCalculateSpellDamageTakenPoints(spell, raidComp, spellName, amountTable, bossID, bossName, awardPoints, reason)
    local points = 0

    for playerName, amount in pairs(spell.targets) do
        points = calculatePoints(amount, amountTable)
        if points > 0 then
        if awardPoints == false then points = points * -1 end
            local strippedName = StripRealm(playerName)
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == strippedName then
                    PuGAddPointEntry(player, bossID, bossName, reason .. (spellName .. " - " .. string.format("%.2fM", amount/1000000)), points)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. reason .. (spellName .. " - ".. string.format("%.2fM", amount/1000000)), points) end
                    break
                end
            end
        end
    end
end

--- Calculates and awards points for players who interrupted a specific spell during a boss encounter
---@param raidComp table Raid roster to assign points to (normal comp or progress comp)
---@param playerName string Name of the player that interrupted the spell
---@param spellName string Spell name as string
---@param amount number Times player has interrupted the spell
---@param bossID number ID of the boss for this encounter
---@param bossName string Name of the boss for this encounter
---@param pointFormula function Function to calculate the points 
function PuGCalculateInterruptPoints(raidComp, playerName, spellName, amount, bossID, bossName, pointFormula)
    local points = pointFormula(amount)
    for _, player in ipairs(raidComp) do
        if StripRealm(player.name) == StripRealm(playerName) then
            PuGAddPointEntry(player, bossID, bossName, "Interrupted " .. spellName .. " " .. amount .. " times", points)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " interrupted " .. spellName .. " " .. amount .. " times - " .. points .. " points") end
            break
        end
    end
end

--- Checks for food buffs, flasks, and potions used 
---@param raidComp table Raid roster to assign points to (normal comp or progress comp)
---@param combat any Combat container from Details!
---@param bossID number ID of the boss for this encounter
---@param bossName string Name of the boss for this encounter
function PuGCheckPotionBuffs(raidComp, combat, bossID, bossName)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    for _, actor in miscContainer:ListActors() do
        local isActorPotionBuff = false
        if actor.buff_uptime_spells then
            local buffContainer = actor.buff_uptime_spells
            if buffContainer and buffContainer._ActorTable then
                for spellID, spellInfo in pairs(buffContainer._ActorTable) do
                    if type(spellInfo) == "table" then
                        local spellName = C_Spell.GetSpellInfo(spellID).name or "Unknown Spell"
                        if string.find(spellName, "Potion") then
                            isActorPotionBuff = true
                        end
                    end
                end
            end
            if isActorPotionBuff then
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == actor:GetOnlyName() then
                        PuGAddPointEntry(player, bossID, bossName, "Potion Used", 1)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " has earned " .. 1 .. " for using potions.") end
                        break
                    end
                end
            end
        end
    end
end

--- Loop through all players in the raid and check if they have the specified buff
--- Returns a table with player names as keys and their buff points as values
---@return table unitsWithBuffs A table containing player names and their buff points
function PuGCalculateBuffPoints()
    local unitsWithBuffs = {}
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        local unitPoints = 0
        local unitBuffs = {
            isWellFed = false,
            isFlask = false,
            isAugment = false,
        }
        for j = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, j, "HELPFUL")
            if not aura then
                break
            end
            local buffName = aura.name
            if string.find(buffName, "Well Fed") then
                unitBuffs.isWellFed = true
            elseif string.find(buffName, "Flask of") then
                unitBuffs.isFlask = true
            elseif string.find(buffName, "Crystallization") then
                unitBuffs.isAugment = true
            end
        end
        for _, hasBuff in pairs(unitBuffs) do
            if hasBuff then
                unitPoints = unitPoints + 1
            end
        end
        if unitBuffs.isWellFed and unitBuffs.isFlask and unitBuffs.isAugment then
            unitPoints = unitPoints + 1
        end
        if unitPoints > 0 then
            unitsWithBuffs[name] = unitPoints -- unitWithBuffs = {name = name, points = unitPoints}
        end
    end
    return unitsWithBuffs
end

--- Awards points to players who have food, flask, or augment buffs
---@param raidComp table Raid roster to assign points to (normal comp or progress comp)
---@param bossID number ID of the boss for this encounter
---@param bossName string Name of the boss for this encounter
---@param unitsWithBuffs table A table containing player names and their buff points
function PuGGiveBuffPoints(raidComp, bossID, bossName, unitsWithBuffs)
    for playerName, points in pairs(unitsWithBuffs) do
        for _, player in ipairs(raidComp) do
            if StripRealm(player.name) == StripRealm(playerName) then
                PuGAddPointEntry(player, bossID, bossName, "Food/Flask/Augment Rune", points)
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " has earned " .. points .. " for having food/flask/augment buffs.") end
                break
            end
        end
    end
end