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
function PuGCalculateBuffPoints(raidComp, combat, bossID, bossName)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    print("Calculating buff points for players...")
    for _, actor in miscContainer:ListActors() do
        local actorBufffs = {
            isWellFed = false,
            isFlask = false,
            isPotion = false,
        }
        local actorPoints = 0
        if actor.buff_uptime_spells then
            local buffContainer = actor.buff_uptime_spells
            if buffContainer and buffContainer._ActorTable then
                for spellID, spellInfo in pairs(buffContainer._ActorTable) do
                    if type(spellInfo) == "table" then
                        local spellName = C_Spell.GetSpellInfo(spellID).name or "Unknown Spell"
                        if string.find(spellName, "Well Fed") then
                            actorBufffs.isWellFed = true
                        elseif  string.find(spellName, "Flask of") then
                            actorBufffs.isFlask = true
                        elseif  string.find(spellName, "Potion") then
                            actorBufffs.isPotion = true
                        end
                    end
                end
            end
            for _, hasBuff in pairs(actorBufffs) do
                if hasBuff then
                    actorPoints = actorPoints + 1
                end
            end
            if actorBufffs.isWellFed and actorBufffs.isFlask and actorBufffs.isPotion then
                actorPoints = actorPoints + 1
            end
            if actorPoints > 0 then
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == actor:GetOnlyName() then
                        PuGAddPointEntry(player, bossID, bossName, "Food/Flask/Potion", actorPoints)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " has earned " .. actorPoints .. " for having food/flask buffs and/or using potions.") end
                        break
                    end
                end
            end
        end
    end
end