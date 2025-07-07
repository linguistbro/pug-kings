local ICON_PATH = "Interface\\AddOns\\PuGKings\\icons\\pugkings"
local CLUB_ID_TO_CHECK = "155513232"  
local clubInfo = C_Club.GetClubInfo(CLUB_ID_TO_CHECK)
local clubName = clubInfo and clubInfo.name or "Unknown"
local PuGKingsCommunity = {}
local playerGuildName = GetGuildInfo("player")  

function PuGUpdateCommunityCache()
    PuGKingsCommunity = {}
    local members = C_Club.GetClubMembers(CLUB_ID_TO_CHECK)
	if not PuGKingsDB then PuGKingsDB = {} end

    if members then
        for _, memberId in ipairs(members) do
            local memberInfo = C_Club.GetMemberInfo(CLUB_ID_TO_CHECK, memberId)
            if memberInfo and memberInfo.name then
                PuGKingsCommunity[memberInfo.name] = clubName
            end
        end
		PuGKingsDB.PuGKingsCommunity = PuGKingsCommunity
    end
	if PuGAddonDebug then print(PuGAddonDebugPrefix .. "Community cache has been refreshed.") end
end

local function AddIcons()
    local viewer = LFGListFrame.ApplicationViewer
    if not viewer or not viewer.ScrollBox then
        if PuGAddonDebug then print(PuGAddonDebugErrorPrefix .. "no viewer or scrollbox found") end
        return
    end

    local buttons = viewer.ScrollBox:GetFrames()

	for _, button in ipairs(buttons) do
		if button and button.applicantID then
			local applicantInfo = C_LFGList.GetApplicantInfo(button.applicantID)
			local inCommunity = false
			local isGuildMember = false

			if applicantInfo then
				for i = 1, applicantInfo.numMembers do
					local memberName = C_LFGList.GetApplicantMemberInfo(button.applicantID, i)
					if memberName then
						local guildName = GetGuildInfo(memberName)
						if guildName and guildName == playerGuildName then
							isGuildMember = true
							break
						end

						if PuGKingsCommunity[memberName] then
							inCommunity = true
						end
					end
				end
			end

			if not button.MyCustomIcon then
				button.MyCustomIcon = button:CreateTexture(nil, "OVERLAY")
				button.MyCustomIcon:SetSize(16, 16)
				local nameFrame = button.Member1 and button.Member1.Name
				if nameFrame then
					button.MyCustomIcon:SetPoint("LEFT", nameFrame, "RIGHT", 4, 0)
				else
					button.MyCustomIcon:SetPoint("LEFT", button, "LEFT", 4, 0)
				end
			end

			if inCommunity and not isGuildMember then
				button.MyCustomIcon:SetTexture(ICON_PATH)
				button.MyCustomIcon:Show()
			else
				button.MyCustomIcon:Hide()
			end
		elseif button and button.MyCustomIcon then
			button.MyCustomIcon:Hide()
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
f:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
f:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
f:SetScript("OnEvent", function(self, event, ...)
    if LFGListFrame and LFGListFrame:IsShown() then
        AddIcons()
    end
end)

local refreshCommunityListFrame = CreateFrame("Frame")
refreshCommunityListFrame:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
refreshCommunityListFrame:SetScript("OnEvent", function(self, event, ...)
	PuGUpdateCommunityCache()
end)