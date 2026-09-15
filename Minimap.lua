local ADDON_NAME, ns = ...
local L = ns.L

local ICON_TEXTURE = "Interface\\Icons\\Trade_Fishing"
local button

---------------------------------------------------------------------------
-- Position: Button kreist in festem Abstand um die Minimap
---------------------------------------------------------------------------
local function UpdatePosition()
    local angle = math.rad(EZFishingDB.minimapAngle or ns.defaults.minimapAngle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    EZFishingDB.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
    UpdatePosition()
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("EZFishing")
    if EZFishingDB.enabled then
        GameTooltip:AddDoubleLine(L.TOOLTIP_STATUS, L.ENABLED, 1, 1, 1, 0.2, 1, 0.2)
    else
        GameTooltip:AddDoubleLine(L.TOOLTIP_STATUS, L.DISABLED, 1, 1, 1, 1, 0.2, 0.2)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.TOOLTIP_LEFT, L.TOOLTIP_LEFT_ACTION, 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TOOLTIP_RIGHT, L.TOOLTIP_RIGHT_ACTION, 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TOOLTIP_DRAG, L.TOOLTIP_DRAG_ACTION, 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Darstellung: farbig wenn aktiv, grau wenn deaktiviert
---------------------------------------------------------------------------
function ns.UpdateMinimapButton()
    if not button then return end
    button:SetShown(EZFishingDB.showMinimapButton)
    local enabled = EZFishingDB.enabled
    button.icon:SetDesaturated(not enabled)
    if enabled then
        button.icon:SetVertexColor(1, 1, 1)
    else
        button.icon:SetVertexColor(0.6, 0.6, 0.6)
    end
    if GameTooltip:IsOwned(button) then
        ShowTooltip(button)
    end
end

---------------------------------------------------------------------------
-- Button erstellen
---------------------------------------------------------------------------
function ns.InitMinimapButton()
    button = CreateFrame("Button", "EZFishingMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER", 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            ns.ToggleEnabled()
        elseif mouseButton == "RightButton" then
            ns.OpenOptions()
        end
    end)

    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    UpdatePosition()
    ns.UpdateMinimapButton()
end
