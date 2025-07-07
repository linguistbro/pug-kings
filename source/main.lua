PuGKingsAddon = LibStub("AceAddon-3.0"):NewAddon("PuGKingsAddon", "AceComm-3.0")
LibSerialize = LibStub("LibSerialize")
LibDeflate = LibStub("LibDeflate")

PuGAddonDebug = false
PuGAddonDebugPrefix = "|cffff0000(DEBUG)|r |cffFFD700PuG Kings Addon|r: "
PuGAddonDebugErrorPrefix = "|cffff0000(ERROR)|r |cffFFD700PuG Kings Addon|r: "

function PuGKingsAddon:OnEnable()
    self:RegisterComm("PuGKingsComm")
	if PuGKingsDB and PuGKingsDB.minimapPos then -- Find saved minimap pos and apply it
		local point, posX, posY = unpack(PuGKingsDB.minimapPos)
		PuGMinimapButton:SetPoint(point, Minimap, posX, posY)
	end
    if PuGKingsDB and PuGKingsDB.PuGAddonDebug then -- Find saved minimap pos and apply it
        PuGAddonDebug = PuGKingsDB.PuGAddonDebug
	end
end

function PuGKingsAddon:Transmit(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    self:SendCommMessage("PuGKingsComm", encoded, "RAID", UnitName("player"))
end

function PuGKingsAddon:OnCommReceived(prefix, payload, distribution, sender)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
    if not decoded then return end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then return end
    PuGKingsDB.raidDPSAndHealers = data.raidDPSAndHealers
    PuGKingsDB.raidersProgComp = data.raidersProgComp
    if PuGAddonDebug then print(PuGKingsDB.raidDPSAndHealers) end
end

PuGListenToWowFrame = CreateFrame("Frame")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
PuGListenToWowFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")

function PuGWoWChatListener(isON)
    if isON then
		if PuGAddonDebug then print(PuGAddonDebugPrefix .. "CHAT_MSG is being listened") end
    else
        PuGListenToWowFrame:SetScript("OnEvent", nil)
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "CHAT_MSG is NOT being listened") end
    end
end

PuGLouCombatFrame = CreateFrame("Frame")
PuGLouCombatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
function PuGCombatLogListener(isON)
    if isON then
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "COMBAT_LOG_EVENT is being listened") end
    else
        PuGLouCombatFrame:SetScript("OnEvent", nil)
        if PuGAddonDebug then print(PuGAddonDebugPrefix .. "COMBAT_LOG_EVENT is NOT being listened") end
    end
end



