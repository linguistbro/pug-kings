
--[[
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        local modelFrame = CreateFrame("DressUpModel", "MyCharacterModelFrame", UIParent)
        modelFrame:SetSize(300, 400)
        modelFrame:SetPoint("CENTER")
        modelFrame:SetFrameStrata("DIALOG")
        modelFrame:SetUnit("player")
        modelFrame:SetPortraitZoom(0.7)
        modelFrame:SetRotation(0)
        modelFrame:SetCamDistanceScale(3)
        modelFrame:SetPosition(0, 0, 0.5)
        modelFrame:Show()

        -- Background
        local bg = CreateFrame("Frame", nil, modelFrame, "BackdropTemplate")
        bg:SetAllPoints()
        bg:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        bg:SetBackdropColor(0, 0, 0, 0.8)
        bg:SetFrameLevel(modelFrame:GetFrameLevel() - 1)

        -- Dance button
        local btn = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        btn:SetSize(80, 24)
        btn:SetText("Dance")
        btn:SetPoint("TOP", modelFrame, "BOTTOM", 0, -10)
        btn:SetScript("OnClick", function()
            modelFrame:PlayAnimKit(1538, true)
        end)
    end)
end)

-- 1538 dranei male dance
]]