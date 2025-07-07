PuGLuoBossNames = {
	[3009] = "Vexie",
	[3010] = "Cauldron",
	[3011] = "Rik Reverb",
	[3012] = "Stix Bunjunker",
	[3013] = "Sprocket",
	[3014] = "Bandit",
	[3015] = "Mugzee",
	[3016] = "Gallywix",
}
PuGLouBossIds = {3009, 3010, 3011, 3012, 3013, 3014, 3015, 3016}
local maxAllowedDuration = 29
local fuelDebuffTracking = {}
local fuelDebuffResults = {}
local oilDebuffTracking = {}
local StixBombshellHits = {}
local StixBombDestroys = {}
local gallyBombThrows = {}
local gallyCoilDestroys = {}
local sprocketScrewed = {}
local highrollerPlayers = {}
local banditCrushedPlayers = {}

local function StripRealm(name)
    return strsplit("-", name)  -- returns just the player name
end

function PugAddVexiePoints(combat, raidComp)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    local supportRigName = "Support Rig"
    for _, actor in miscContainer:ListActors() do
        if actor.cc_done_targets and actor.cc_done_targets[supportRigName] then
            local name = actor:name()
            local count = actor.cc_done_targets[supportRigName]

            for _, player in ipairs(raidComp or {}) do
                if StripRealm(player.name) == name then
                    PuGAddPointEntry(player, 3009, "Vexie", "Support Rig CC", 3)
                    break
                end
            end
        end
    end

    -- Check interrupts
    local repairSpellId = 460173
    local repairSpellName = "Repair"
    local function PointFormula(amount)
        return math.max(1, math.floor(amount / 2))
    end
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for interrupts.") end
    if miscContainer then 
        for _, actor in miscContainer:ListActors() do
            if actor.interrupt and actor.interrupt > 0 then
                if actor.interrompeu_oque then
                    for spellID, amount in pairs(actor.interrompeu_oque) do
                        if spellID == repairSpellId then
                            local playerName = actor:name()
                            PuGCalculateInterruptPoints(raidComp, playerName, repairSpellName, amount, 3009, "Vexie", PointFormula)
                        end
                    end
                end
            end
        end
    end

    -- Damage to "Pit Mechanic"
    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end

    local bikerName = "Geargrinder Biker"
    local totalBikerDamage = 0

    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Geargrinder damage.") end
    for _, actor in damageContainer:ListActors() do
        local amount = actor.targets[bikerName]
        if (amount and amount >= 1) then
            totalBikerDamage = totalBikerDamage + amount
        end
    end

    for _, actor in damageContainer:ListActors() do
        local playerName = actor:name()
        local amount = actor.targets[bikerName]
        if (amount and amount >= math.floor(totalBikerDamage/#raidComp)) then
            local strippedName = StripRealm(playerName)
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == strippedName then
                    PuGAddPointEntry(player, 3009, 'Vexie', 'Did more than average damage to Geargrinder Biker - ' .. string.format("%.2fM", amount/1000000), 1)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' did more than average damage to Geargrinder Biker - ' .. string.format("%.2fM", amount/1000000), ' 1 points') end
                    break
                end
            end
        end
    end

    for playerName, debuffData in pairs(fuelDebuffResults) do
        local strippedName = StripRealm(playerName)
        for _, player in ipairs(raidComp) do
            if StripRealm(player.name) == strippedName then
                -- If the debuff was removed within the allowed duration, award points
                if debuffData.duration <= maxAllowedDuration then
                    PuGAddPointEntry(player, 3009, "Vexie", "Delived fuel in time " .. debuffData.duration .. " seconds", 1)
                elseif debuffData.duration >= maxAllowedDuration then
                    PuGAddPointEntry(player, 3009, "Vexie", "Failed to deliver fuel in time" .. debuffData.duration .. " seconds", -3)
                end
                break
            end
        end
    end

    for playerName, debuffData in pairs(oilDebuffTracking) do
        local strippedName = StripRealm(playerName)
        for _, player in ipairs(raidComp) do
            if StripRealm(player.name) == strippedName then
                local points = debuffData.count
                PuGAddPointEntry(player, 3009, "Vexie", "Caught fuel to deliver", points)
                break
            end
        end
    end
end

function PuGAddCauldronPoints(combat, raidComp)
    local sourceNpc
    local source
    local spell
    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end
	
    local dodgeSpells = {465466, 463803, 474322, 472242}
	local SpellNames = {
		[465466] = "FieryWave",
		[463803] = "Zapbolt",
		[474322] = "Thunderdrum",
        [472242] = "Blastburn Roarcannon"
	}
    local amountTable = {1000000, 5000000, 10000000}


    if damageContainer then
        for i, actor in damageContainer:ListActors() do
            actor.custom = 0
        end
    
        -- Loop spells to check
        for _, spellID in ipairs(dodgeSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end       
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3010, 'Cauldron', false, "Got hit by ")
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. " spell was not found from source:GetSpel(spellID)") end
            end
        end
    end
	
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    if not miscContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No misc container found.") end
    end
    local staticDischargeId = 473983
    if miscContainer then
        for _, actor in miscContainer:ListActors() do
            local playerName = actor:GetOnlyName()
            if actor.debuff_uptime_spells then
                local debuffContainer = actor.debuff_uptime_spells
                local staticDischarge = debuffContainer:GetSpell(staticDischargeId)
                if staticDischarge then
                    local uptime = staticDischarge.uptime or 0
                    local points = -math.max(1, math.floor(uptime / 6))
                    for _, player in ipairs(raidComp) do
                        if StripRealm(player.name) == playerName then
                            PuGAddPointEntry(player, 3010, "Cauldron", "Got stunned by Static Discharge for " .. staticDischarge.uptime .. " seconds.", points)
                            if PuGAddonDebug then print(PuGAddonDebugPrefix .. playerName .. " got stunned by Static Discharge for " .. staticDischarge.uptime .. " seconds." .. points) end
                        end
                    end
                end
            end
        end
    end
end

function PuGAddRikPoints(combat, raidComp)
    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
        return
    end

    local barrelName = "Pyrotechnics"
    local totalBarrelDamage = 0

    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Barrel damage.") end
    for _, actor in damageContainer:ListActors() do
        local amount = actor.targets[barrelName]
        if (amount and amount >= 1) then
            totalBarrelDamage = totalBarrelDamage + amount
        end
    end

    for _, actor in damageContainer:ListActors() do
        local playerName = actor:name()
        local amount = actor.targets[barrelName]
        if (amount and amount >= math.floor(totalBarrelDamage/#raidComp)) then
            local strippedName = StripRealm(playerName)
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == strippedName then
                    PuGAddPointEntry(player, 3011, 'Rik', 'Did more than average damage to Pyrotechnics - ' .. string.format("%.2fM", amount/1000000), 1)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' did more than average damage to Pyrotechnics - ' .. string.format("%.2fM", amount/1000000), ' 1 points') end
                    break
                end
            end
        end
    end

    --Spell Damage Taken--
    local lingeringVoltage = {
        name = "Lingering Voltage",
        id = 1217126
    }
    local sourceNpc
    local source
    local spell
    local dodgeSpells = {466364, 467992}
	local SpellNames = {
		[466364] = "Amplification!",
        [467992] = "Blaring Drop",
	}
    local amountTable = {
        1000000, 5000000, 10000000
    }

    if damageContainer then
        for _, spellID in ipairs(dodgeSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3011, 'Rik', false, "Got hit by ")
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "spell was not found from source:GetSpel(spellID)") end
            end
        end

        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", lingeringVoltage.id, "-", lingeringVoltage.name) end
        sourceNpc = damageContainer:GetSpellSource(lingeringVoltage.id)
        if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
        if source then spell = source:GetSpell(lingeringVoltage.id) end
        if spell then 
            PuGCalculateSpellDamageTakenPoints(spell, raidComp, lingeringVoltage.name, amountTable, 3011, 'Rik', true, "Soaked antennas ")
        end
    end
end

function PuGAddStixPoints(combat, raidComp)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    if not miscContainer then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No misc container found.") end
    end

    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end

    -- Check interrupts
    local scrapRocketsSpellID = 1219384
    local scrapRocketsName = 'Scrap Rockets'
    local function PointFormula(amount)
        return math.max(1, math.floor(amount))
    end
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for interrupts.") end
    if miscContainer then
        for _, actor in miscContainer:ListActors() do
            if actor.interrupt and actor.interrupt > 0 then
                if actor.interrompeu_oque then
                    for spellID, amount in pairs(actor.interrompeu_oque) do
                        if spellID == scrapRocketsSpellID then
                            local playerName = actor:name()
                            PuGCalculateInterruptPoints(raidComp, playerName, scrapRocketsName, amount, 3012, "Stix", PointFormula)
                        end
                    end
                end
            end
        end
    end

    --Rolling ball mechanics
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Bombshell fails.") end
    if StixBombshellHits and #StixBombshellHits > 0 then
        for _, name in ipairs(StixBombshellHits) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Found: " .. name) end
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == StripRealm(name) then
                    PuGAddPointEntry(player, 3012, "Stix", "Hit a bombshell with the ball mechanic.", -3)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player .. " hit a bombshell with the ball mechanic -3 points") end
                end
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Stix Bomshell Hits table is empty.") end
    end

    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Bombshell fails.") end
    if StixBombDestroys and #StixBombDestroys > 0 then
        for _, name in ipairs(StixBombDestroys) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Found: " .. name) end
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == StripRealm(name) then
                    PuGAddPointEntry(player, 3012, "Stix", "Destroyed bomb with the ball mechanic.", 1)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player .. " destroyed bomb with the ball mechanic -3 points") end
                end
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Stix Bomshell Hits table is empty.") end
    end

    --Check bombshell damage
    local bombshellName = "Territorial Bombshell"
    local totalBombshellDamage = 0
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Territorial Bombshell damage.") end
    for _, actor in damageContainer:ListActors() do
        local amount = actor.targets[bombshellName]
        if (amount and amount >= 1) then
            totalBombshellDamage = totalBombshellDamage + amount
        end
    end

    for _, actor in damageContainer:ListActors() do
        local playerName = actor:name()
        local amount = actor.targets[bombshellName]
        if (amount and amount >= math.floor(totalBombshellDamage/#raidComp)) then
            local strippedName = StripRealm(playerName)
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == strippedName then
                    PuGAddPointEntry(player, 3012, 'Stix', 'Did more than average damage to Territorial Bombshell - ' .. string.format("%.2fM", amount/1000000), 2)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' did more than average damage to Territorial Bombshell - ' .. string.format("%.2fM", amount/1000000), ' 1 points') end
                    break
                end
            end
        end
    end
end

function PuGAddSprocketPoints(combat, raidComp)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    if not miscContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No misc container found.") end
    end

    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end

    local sourceNpc
    local source
    local spell
    local dodgeSpells = {1216415, 1216661, 1216679}
	local SpellNames = {
		[1216415] = "Blazing Beam",
		[1216661] = "Rocket Barrage",
		[1216679] = "Jumbo Void Beam"
	}
    local amountTable = {1000000, 5000000, 10000000}


    if damageContainer then
        for i, actor in damageContainer:ListActors() do
            actor.custom = 0
        end
    
        -- Loop spells to check
        for _, spellID in ipairs(dodgeSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3013, 'Sprocket', false, "Got hit by ")
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. " spell was not found from source:GetSpel(spellID)") end
            end
        end
    end
    
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Screwed! fails.") end
    if sprocketScrewed and #sprocketScrewed > 0 then
        for _, name in ipairs(sprocketScrewed) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Found: " .. name) end
            for _, player in ipairs(raidComp) do
                if StripRealm(player.name) == StripRealm(name) then
                    PuGAddPointEntry(player, 3013, "Sprocket", "Got Screwed!", -1)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " got Screwed! -1 points") end
                end
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Sprocket Screwed! table is empty.") end
    end
end

function PuGAddBanditPoints(combat, raidComp)
    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    if not miscContainer then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No misc container found.") end
    end

    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end

    -- Check interrupts
    local overloadSpellID = 460582
    local overloadName = "Overload"
    local function PointFormula(amount)
        return math.max(1, math.floor(amount / 2))
    end
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for interrupts.") end
    if miscContainer then
        for _, actor in miscContainer:ListActors() do
            if actor.interrupt and actor.interrupt > 0 then
                if actor.interrompeu_oque then
                    for spellID, amount in pairs(actor.interrompeu_oque) do
                        if spellID == overloadSpellID then
                            local playerName = actor:name()
                            PuGCalculateInterruptPoints(raidComp, playerName, overloadName, amount, 3014, "Bandit", PointFormula)
                        end
                    end
                end
            end
        end
    end

    --Check buff
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for high roller buff.") end
    if highrollerPlayers and #highrollerPlayers > 0 then
        local nameCounts = {}
        for _, playerName in ipairs(highrollerPlayers) do
            if nameCounts[playerName] then
                nameCounts[playerName] = nameCounts[playerName] + 1
            else
                nameCounts[playerName] = 1
            end
        end
        for name, count in pairs(nameCounts) do
            local points = math.max(1, math.floor(count / 4))
            local playerName = StripRealm(name)
            for _, player in ipairs(raidComp) do 
                if playerName == StripRealm(player.name) then
                    PuGAddPointEntry(player, 3014, "Bandit", "Got/Refreshed High Roller! buff " .. count .. " time(s)", points)
                    break
                end
            end
        end
    end

    --Check stun
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for stunned players.") end
    if banditCrushedPlayers and #banditCrushedPlayers > 0 then
        local nameCounts = {}
        for _, playerName in ipairs(banditCrushedPlayers) do
            if nameCounts[playerName] then
                nameCounts[playerName] = nameCounts[playerName] + 1
            else
                nameCounts[playerName] = 1
            end
        end
        for name, count in pairs(nameCounts) do
            local points = count * -3
            local playerName = StripRealm(name)
            for _, player in ipairs(raidComp) do 
                if playerName == StripRealm(player.name) then
                    PuGAddPointEntry(player, 3014, "Bandit", "Got stunned by Crushed! " .. count .. " time(s)", points)
                    break
                end
            end
        end
    end
    
    --CHECK SPELLS TO DODGE
    local sourceNpc
    local source
    local spell

    local dodgeSpells = {1223999, 473178}
	local SpellNames = {
		[1223999] = "Traveling Flames",
        [473178] = "Voltaic Streak"
	}

    local amountTable = {1000000, 5000000, 10000000}

    if damageContainer then
        -- Loop spells to check
        for _, spellID in ipairs(dodgeSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3014, 'Bandit', false, "Got hit by ")
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. " spell was not found from source:GetSpel(spellID)") end
            end
        end

        --Check Reel Assistant Damage
        local reelAssistantName = "Reel Assistant"
        local totalReelAssitantAddDamage = 0
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Reel Assistant damage.") end
        for _, actor in damageContainer:ListActors() do
            local amount = actor.targets[reelAssistantName]
            if (amount and amount >= 1) then
                totalReelAssitantAddDamage = totalReelAssitantAddDamage + amount
            end
        end

        for _, actor in damageContainer:ListActors() do
            local playerName = actor:name()
            local amount = actor.targets[reelAssistantName]
            if (amount and amount >= math.floor(totalReelAssitantAddDamage/#raidComp)) then
                local strippedName = StripRealm(playerName)
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == strippedName then
                        PuGAddPointEntry(player, 3014, 'Bandit', 'Did more than average damage to Reel Assistant - ' .. string.format("%.2fM", amount/1000000), 1)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' did more than average damage to Reel Assistant - ' .. string.format("%.2fM", amount/1000000), ' 1 points') end
                        break
                    end
                end
            end
        end
    end
end

function PuGAddMugzeePoints(combat, raidComp)
    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end
    local shockerAddName = "Mk II Electro Shocker"
    local totalShockerAddDamage = 0
    local sourceNpc
    local source
    local spell
    local soakSpells = {469052}
	local SpellNames = {
		[469052] = "Searing Shrapnel"
	}
    local amountTable = {1000000, 5000000, 10000000}

    if damageContainer then
        --Check soaking
        for _, spellID in ipairs(soakSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3015, 'Mugzee', true, "Soaked ")           
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "spell was not found from source:GetSpel(spellID)") end
            end
        end
        
        --Check MK II Shocker Damage
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for Mk II Shocker damage.") end
        for _, actor in damageContainer:ListActors() do
            local amount = actor.targets[shockerAddName]
            if (amount and amount >= 1) then
                totalShockerAddDamage = totalShockerAddDamage + amount
            end
        end

        for _, actor in damageContainer:ListActors() do
            local playerName = actor:name()
            local amount = actor.targets[shockerAddName]
            if (amount and amount >= math.floor(totalShockerAddDamage/#raidComp)) then
                local strippedName = StripRealm(playerName)
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == strippedName then
                        PuGAddPointEntry(player, 3015, 'Mugzee', 'Did more than average damage to Mk II Shocker - ' .. string.format("%.2fM", amount/1000000), 1)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' did more than average damage to Mk II Shocker - ' .. string.format("%.2fM", amount/1000000), ' 1 points') end
                        break
                    end
                end
            end
        end
    end
end

function PuGAddGallywixPoints(combat, raidComp)
    local damageContainer = combat:GetContainer(DETAILS_ATTRIBUTE_DAMAGE)
    if not damageContainer then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "No damage container found.") end
    end

    local miscContainer = combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
    if not miscContainer then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "No misc container found.") end
    end

    local sourceNpc
    local source
    local spell
    local dodgeSpells = {467184, 465938, 1214611}
	local SpellNames = {
		[467184] = "Suppression",
        [465938] = "Big Bad Buncha Bombs",
        [1214611] = "Bigger Badder Bomb Blast"
	}
    local amountTable = {
        1000000, 5000000, 10000000
    }

    --Check spells to dodge
    if damageContainer then
        for _, spellID in ipairs(dodgeSpells) do
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking spellID:", spellID, "-", SpellNames[spellID] or "Unknown") end
            sourceNpc = damageContainer:GetSpellSource(spellID)
            if sourceNpc then source = damageContainer:GetActor(sourceNpc) end
            if source then spell = source:GetSpell(spellID) end
            if spell then 
                PuGCalculateSpellDamageTakenPoints(spell, raidComp, SpellNames[spellID], amountTable, 3016, 'Gallywix', false, "Got hit by ")           
            else
                if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "spell was not found from source:GetSpel(spellID)") end
            end
        end
    end

    --Check deaths
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. " Checking deaths.") end
    local deaths = combat:GetDeaths()
    if not deaths and  PuGAddonDebug then print(PuGAddonDebugPrefix .. " No deaths logged.") end

    if deaths then
        for _, death in ipairs(deaths) do
            if death[3] == 1219333 and death[7] >= 1500000 then --Gallybux Finale Blast
                local playerName = StripRealm(death[1])
                local amount = death[7]
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == playerName then
                        PuGAddPointEntry(player, 3016, 'Gallywix', 'Died to Gallybux Finale Blast - Overkill Amount: ' .. string.format("%.2fM", amount/1000000), -3)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' died to Gallybux Finale Blast - ' .. string.format("%.2fM", amount/1000000), ' -3 points') end
                        break
                    end
                end
            elseif death[3] == 1214226 and death[7] >= 400000 then --Cratering
                local playerName = StripRealm(death[1])
                local amount = death[7]
                for _, player in ipairs(raidComp) do
                    if StripRealm(player.name) == playerName then
                        PuGAddPointEntry(player, 3016, 'Gallywix', 'Died to Cratering - ' .. string.format("%.2fM", amount/1000000), -3)
                        if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. ' died to Cratering - ' .. string.format("%.2fM", amount/1000000), ' -3 points') end
                        break
                    end
                end
            end
        end
    end

    -- Check interrupts
    local juiceSpellID = 471352
    local juiceSpellName = 'Juice It!'
    local function PointFormula(amount)
        return math.max(1, math.floor(amount / 2))
    end
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for interrupts.") end
    if miscContainer then 
        for _, actor in miscContainer:ListActors() do
            if actor.interrupt and actor.interrupt > 0 then
                if actor.interrompeu_oque then
                    for spellID, amount in pairs(actor.interrompeu_oque) do
                        if spellID == juiceSpellID then
                            local playerName = actor:name()
                            PuGCalculateInterruptPoints(raidComp, playerName, juiceSpellName, amount, 3016, "Gallywix", PointFormula)
                        end
                    end
                end
            end
        end
    end

    --Bomb throw mechanics
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for bomb throws.") end
    if gallyBombThrows and #gallyBombThrows > 0 then
        local nameCounts = {}
        for _, playerName in ipairs(gallyBombThrows) do
            if nameCounts[playerName] then
                nameCounts[playerName] = nameCounts[playerName] + 1
            else
                nameCounts[playerName] = 1
            end
        end
        for name, count in pairs(nameCounts) do
            local points = count * 2
            local playerName = StripRealm(name)
            for _, player in ipairs(raidComp) do 
                if playerName == StripRealm(player.name) then
                    PuGAddPointEntry(player, 3016, "Gallywix", "Threw a bomb off the platform " .. count .. " time(s)", points)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " threw a bomb off the platform " .. count .. " time(s).") end
                    break
                end
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Gally Bomb Throw table is empty.") end
    end

    if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Checking for coil destroys with bomb.") end
    if gallyCoilDestroys and #gallyCoilDestroys > 0 then
        local nameCounts = {}
        for _, playerName in ipairs(gallyCoilDestroys) do
            if nameCounts[playerName] then
                nameCounts[playerName] = nameCounts[playerName] + 1
            else
                nameCounts[playerName] = 1
            end
        end
        for name, count in pairs(nameCounts) do
            local points = count * 2
            local playerName = StripRealm(name)
            for _, player in ipairs(raidComp) do 
                if playerName == StripRealm(player.name) then
                    PuGAddPointEntry(player, 3016, "Gallywix", "Destroyed a coil with a bomb " .. count .. " time(s)", points)
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. player.name .. " destroyed a coil with a bomb " .. count .. " time(s).") end
                    break
                end
            end
        end
    else
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Gally Coil Destroy table is empty.") end
    end
end

local function VexieCombatLogListen()
    local carryingFuelId = 1216788
    local soakedInOilId = 473507
    fuelDebuffTracking = {}
    fuelDebuffResults = {}
    oilDebuffTracking = {}
    PuGLouCombatFrame:SetScript("OnEvent", function(self, event)
        local timestamp, subevent, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())
            if spellId and spellId == carryingFuelId then
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. "carryingFuelId triggered") end
                fuelDebuffTracking[destName] = { applyTime = timestamp, removed = false }
            elseif spellId == soakedInOilId then
                if oilDebuffTracking[destName] then
                    oilDebuffTracking[destName].count = oilDebuffTracking[destName].count + 1
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. oilDebuffTracking[destName]) end
                else
                    oilDebuffTracking[destName] = { count = 1, removed = false }
                    if PuGAddonDebug then print(PuGAddonDebugPrefix .. oilDebuffTracking[destName]) end
                end
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())
            if spellId and spellId == carryingFuelId then
                local fuelDebuffData = fuelDebuffTracking[destName]
                if fuelDebuffData and not fuelDebuffData.removed then
                    local duration = timestamp - fuelDebuffData.applyTime
                    fuelDebuffResults[destName] = { duration = duration, removed = true }
                    fuelDebuffData.removed = true
                end
            end
        end
    end)
end

local function StixChatListen()
    StixBombshellHits = {}
    StixBombDestroys = {}
    PuGListenToWowFrame:SetScript("OnEvent", function(self, event, msg, playerName,...)
        if msg:match("Territorial Bombshell") and playerName then
            table.insert(StixBombshellHits, playerName)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. playerName .. " has been added to Bombshell List.") end
        elseif msg:match("Discarded") and playerName then
            table.insert(StixBombDestroys, playerName)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. playerName .. " has been added to Bomb Destroy List.") end
        end
    end)
end

local function SprocketCombatLogListen()
    sprocketScrewed = {}
    PuGLouCombatFrame:SetScript("OnEvent", function(self, event)
        local _, subevent, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())
            if spellId and spellId == 1217261 then --Screwed
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. spellName .. "triggered for player: " .. destName) end
                table.insert(sprocketScrewed, destName)
            end
        end
    end)
end

local function BanditCombatLogListen()
    highrollerPlayers = {}
    banditCrushedPlayers = {}
    PuGLouCombatFrame:SetScript("OnEvent", function(self, event)
       local _, subevent, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())
            if spellId and spellId == 460444 then --High Roller
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. destName .. " got the High Roller buff.") end
                table.insert(highrollerPlayers, destName)
            elseif spellId and spellId == 460430 then -- Crushed
                table.insert(banditCrushedPlayers, destName)
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. spellName .. " triggered for player: " .. destName) end
            end
        elseif subevent == "SPELL_AURA_REFRESH" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())
            if (spellId and spellId == 460444) or (spellName and spellName == "High Roller!") then --High Roller
                if PuGAddonDebug then print(PuGAddonDebugPrefix .. destName .. " refreshed the High Roller buff.") end
                table.insert(highrollerPlayers, destName)
            end
        end
    end)
end

local function GallyChatListen()
    gallyBombThrows = {}
    gallyCoilDestroys = {}
    PuGListenToWowFrame:SetScript("OnEvent", function(self, event, msg, playerName, languageName, channelName, playerName2, ...)
        if msg:match("detonates from") and playerName2 then
            table.insert(gallyCoilDestroys, playerName2)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. playerName2 .. " has been added to gallyCoilDestroys List.") end
        end
        if msg:match("ditches their") and playerName2 then
            table.insert(gallyBombThrows, playerName2)
            if PuGAddonDebug then print(PuGAddonDebugPrefix .. playerName2 .. " has been added to gallyBombThrows List.") end
        end
    end)
end

local function TestCombatLogListen()
        PuGLouCombatFrame:SetScript("OnEvent", function(self, event)
        local _, subevent, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_REFRESH" then
            local destName, _, _, spellId, spellName = select(9, CombatLogGetCurrentEventInfo())            
            if PuGAddonDebug then print(subevent, destName, spellId, spellName) end
        end
    end)
end

function PuGLouListeners(encounterID)
    if encounterID == 3009 then --Vexie
        VexieCombatLogListen()
    elseif encounterID == 3012 then --Stix
        StixChatListen()
    elseif encounterID == 3013 then --Sprocket 
        SprocketCombatLogListen()
    elseif encounterID == 3014 then --Bandit
        BanditCombatLogListen()
    elseif encounterID == 3016 then --Gallywix
        GallyChatListen()
    end
end

local function PuGCheckDeaths()
    PuGAddonDebug = true
    if PuGAddonDebug then print(PuGAddonDebugPrefix .. " Checking deaths.") end
    local segments = _detalhes:GetCombatSegments()
    local combat = segments[1]:GetCombat()
    local deaths = combat:GetDeaths()
    if not deaths and PuGAddonDebug then print(PuGAddonDebugPrefix .. " No deaths logged.") end
    
    if deaths then
        print(deaths)
        for i, death in ipairs(deaths) do
            print(death[i])
        end
    end
    PuGAddonDebug = false
end

SLASH_PUGDEATH1 = "/pugdeath"
SlashCmdList["PUGDEATH"] = function() PuGCheckDeaths() end


