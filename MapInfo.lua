local ADDON_NAME, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Angel-Infos auf der Weltkarte: Mindestfertigkeit, Fertigkeit ohne
-- entkommende Fische und die Fische des Gebiets. Nur in der Zonenansicht,
-- Kontinent- und Weltübersicht bleiben unverändert. Die Daten (Zones.lua)
-- gelten für die Classic-Welt (WoW Forever / Classic Era).
---------------------------------------------------------------------------

local PANEL_WIDTH = 230
local ROW_HEIGHT = 16
local PADDING = 8
local BUTTON_SIZE = 16
local MAP_MARGIN = 10

-- Wählbare Ankerpunkte der Box auf der Karte
local ANCHORS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local panel
local fishRows = {}
local currentZone
local ShowAnchorMenu -- weiter unten definiert

-- Farben für den Vergleich mit der eigenen Fertigkeit
local COLOR_RED = "|cffff4040"
local COLOR_YELLOW = "|cffffd100"
local COLOR_GREEN = "|cff40ff40"
local COLOR_GRAY = "|cff999999"

---------------------------------------------------------------------------
-- Eigene Angelfertigkeit: Rang und Bonus (Angel, Köder, Ausrüstung)
---------------------------------------------------------------------------
local function GetFishingSpellName()
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(7620)
    elseif GetSpellInfo then
        return (GetSpellInfo(7620))
    end
end

local function GetFishingSkill()
    -- Classic-Clients: Fertigkeitenliste des Charakters
    if GetNumSkillLines and GetSkillLineInfo then
        local fishingName = GetFishingSpellName()
        for index = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, modifier = GetSkillLineInfo(index)
            if not isHeader and name and (name == fishingName or name == PROFESSIONS_FISHING) then
                return rank or 0, modifier or 0
            end
        end
    end
    -- Retail: Berufe-API
    if GetProfessions and GetProfessionInfo then
        local fishingIndex = select(4, GetProfessions())
        if fishingIndex then
            local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishingIndex)
            return rank or 0, modifier or 0
        end
    end
    return nil
end

local function ColorForSkill(skill, zone)
    if skill < zone.min then
        return COLOR_RED
    elseif skill < zone.noEscape then
        return COLOR_YELLOW
    end
    return COLOR_GREEN
end

---------------------------------------------------------------------------
-- Fischnamen/-symbole (Namen kommen lokalisiert aus dem Item-Cache)
---------------------------------------------------------------------------
local function GetItemNameAndIcon(itemID)
    local name, icon
    if C_Item and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        name = GetItemInfo(itemID)
    end
    if C_Item and C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(itemID)
    elseif GetItemIcon then
        icon = GetItemIcon(itemID)
    end
    return name, icon
end

local function FormatNote(note)
    if not note then return nil end
    return L["MAP_NOTE_" .. strupper(note)] or note
end

-- Fisch mit erhöhter Mindestfertigkeit noch nicht fangbar?
local function FishLine(fish, skill)
    local name = GetItemNameAndIcon(fish.id) or ("Item " .. fish.id)
    local text = name
    local note = FormatNote(fish.note)
    if note then
        text = text .. " " .. COLOR_GRAY .. "(" .. note .. ")|r"
    end
    if fish.minSkill then
        local color = (skill and skill >= fish.minSkill) and COLOR_GREEN or COLOR_RED
        text = text .. " " .. color .. L.MAP_FISH_FROM:format(fish.minSkill) .. "|r"
    end
    return text
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function GetMapCanvas()
    return WorldMapFrame.ScrollContainer or WorldMapFrame
end

local function ShowFishTooltip(owner)
    local zone = currentZone
    if not zone or not zone.fish then return end
    local rank, modifier = GetFishingSkill()
    local skill = rank and (rank + modifier)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.MAP_FISH_TITLE)
    for _, fish in ipairs(zone.fish) do
        local _, icon = GetItemNameAndIcon(fish.id)
        local line = FishLine(fish, skill)
        if icon then
            line = ("|T%s:14:14:0:0|t %s"):format(icon, line)
        end
        GameTooltip:AddLine(line, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(panel.expanded and L.MAP_CLICK_COLLAPSE or L.MAP_CLICK_EXPAND, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function GetFishRow(index)
    local row = fishRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    fishRows[index] = row
    return row
end

local function GetAnchor()
    local anchor = EZFishingDB.mapInfoAnchor
    for _, valid in ipairs(ANCHORS) do
        if anchor == valid then return anchor end
    end
    return ns.defaults.mapInfoAnchor
end

-- Box am gewählten Ankerpunkt ausrichten; der Pfeil sitzt in dieser Ecke.
-- Beim Ein-/Ausklappen bleibt die Ecke stehen, die Box wächst von dort weg.
local function ApplyLayout()
    local anchor = GetAnchor()
    local isTop = anchor:find("TOP") ~= nil
    local isRight = anchor:find("RIGHT") ~= nil
    local canvas = GetMapCanvas()

    panel:ClearAllPoints()
    panel:SetPoint(anchor, canvas, anchor, isRight and -MAP_MARGIN or MAP_MARGIN,
        isTop and -MAP_MARGIN or MAP_MARGIN)

    -- Oben verankert oder eingeklappt: Pfeil in der Titelzeile, sonst in der unteren Ecke
    local arrowInRow = isTop or panel.collapsed
    local arrow = panel.arrow
    arrow:ClearAllPoints()
    if arrowInRow then
        arrow:SetPoint(isRight and "TOPRIGHT" or "TOPLEFT", panel,
            isRight and -PADDING + 2 or PADDING - 2, -PADDING + 1)
    else
        arrow:SetPoint(anchor, panel, anchor, isRight and -PADDING + 2 or PADDING - 2, PADDING - 2)
    end

    -- Pfeil zeigt in die Richtung, in die die Box sich bewegt
    local pointsUp = (isTop and not panel.collapsed) or (not isTop and panel.collapsed)
    local texture = pointsUp and "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up"
        or "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
    arrow:SetNormalTexture(texture)
    arrow:SetPushedTexture((texture:gsub("%-Up$", "-Down")))

    -- Titelzeile: [Pfeil] Symbol Titel ... Zahnrad [Pfeil]
    local leftOffset = PADDING + ((arrowInRow and not isRight) and (BUTTON_SIZE + 2) or 0)
    local rightOffset = PADDING + ((arrowInRow and isRight) and (BUTTON_SIZE + 2) or 0)
    panel.icon:ClearAllPoints()
    panel.icon:SetPoint("TOPLEFT", leftOffset, -PADDING)
    panel.gear:ClearAllPoints()
    panel.gear:SetPoint("TOPRIGHT", -rightOffset, -PADDING)
    panel.bottomSpace = arrowInRow and 0 or BUTTON_SIZE
end

local function Refresh()
    if not panel then return end
    local zone = currentZone
    local lines = panel.lines
    local rank, modifier = GetFishingSkill()
    local skill = rank and (rank + modifier)

    panel.title:SetText(L.MAP_TITLE)
    ApplyLayout()

    -- Eingeklappt: nur die Titelzeile
    if panel.collapsed then
        lines:Hide()
        panel.fishHeader:Hide()
        for _, row in ipairs(fishRows) do
            row:Hide()
        end
        panel:SetHeight(PADDING * 2 + BUTTON_SIZE)
        return
    end
    lines:Show()

    if not zone.min then
        lines:SetText(COLOR_GRAY .. L.MAP_NO_FISHING .. "|r")
        panel.fishHeader:Hide()
    else
        local text = L.MAP_MIN:format(zone.min) .. "\n" .. L.MAP_NO_ESCAPE:format(zone.noEscape)
        if skill then
            local bonus = modifier ~= 0 and (" (%d%+d)"):format(rank, modifier) or ""
            text = text .. "\n" .. L.MAP_YOUR_SKILL .. " " .. ColorForSkill(skill, zone)
                .. skill .. bonus .. "|r"
        else
            text = text .. "\n" .. L.MAP_YOUR_SKILL .. " " .. COLOR_RED .. L.MAP_NOT_LEARNED .. "|r"
        end
        lines:SetText(text)
        panel.fishHeader:SetShown(zone.fish ~= nil and #zone.fish > 0)
        panel.fishHeader.text:SetText((panel.expanded and "- " or "+ ")
            .. L.MAP_FISH:format(zone.fish and #zone.fish or 0))
    end

    -- Aufgeklappte Fischliste
    local shown = 0
    if zone.min and zone.fish and panel.expanded then
        for index, fish in ipairs(zone.fish) do
            local row = GetFishRow(index)
            local _, icon = GetItemNameAndIcon(fish.id)
            row.itemID = fish.id
            row.icon:SetTexture(icon or 134400)
            row.text:SetText(FishLine(fish, skill))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel.fishHeader, "BOTTOMLEFT", 0, -(index - 1) * ROW_HEIGHT - 2)
            row:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
            row:Show()
            shown = index
        end
    end
    for index = shown + 1, #fishRows do
        fishRows[index]:Hide()
    end

    -- Höhe an den Inhalt anpassen
    local height = PADDING + BUTTON_SIZE + 4 + lines:GetStringHeight() + PADDING + panel.bottomSpace
    if panel.fishHeader:IsShown() then
        height = height + 4 + ROW_HEIGHT + shown * ROW_HEIGHT + (shown > 0 and 4 or 0)
    end
    panel:SetHeight(height)
end

-- Fischnamen nachladen, sobald der Item-Cache sie kennt
local function RequestItemNames(zone)
    if not zone.fish or not Item or not Item.CreateFromItemID then return end
    for _, fish in ipairs(zone.fish) do
        if not GetItemNameAndIcon(fish.id) then
            local item = Item:CreateFromItemID(fish.id)
            item:ContinueOnItemLoad(function()
                if panel and panel:IsShown() and currentZone == zone then
                    Refresh()
                end
            end)
        end
    end
end

local function SetAnchor(anchor)
    EZFishingDB.mapInfoAnchor = anchor
    Refresh()
end

-- Zahnrad-Menü: Ankerpunkt auswählen (ältere Clients ohne MenuUtil: durchschalten)
ShowAnchorMenu = function(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(L.MAP_ANCHOR)
            for _, anchor in ipairs(ANCHORS) do
                root:CreateRadio(L["MAP_ANCHOR_" .. anchor],
                    function() return GetAnchor() == anchor end,
                    function() SetAnchor(anchor) end)
            end
        end)
        return
    end
    local current = GetAnchor()
    for index, anchor in ipairs(ANCHORS) do
        if anchor == current then
            local nextAnchor = ANCHORS[index % #ANCHORS + 1]
            SetAnchor(nextAnchor)
            ns.Print(L.MAP_ANCHOR .. ": " .. L["MAP_ANCHOR_" .. nextAnchor])
            return
        end
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "EZFishingMapPanel", GetMapCanvas(), BackdropTemplateMixin and "BackdropTemplate")
    panel:SetWidth(PANEL_WIDTH)
    -- Strata vom Kartenfenster erben (auch im Vollbild), aber über den Karten-Pins liegen
    panel:SetFrameLevel(GetMapCanvas():GetFrameLevel() + 1000)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.75)
    panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    panel:EnableMouse(true)
    panel.expanded = EZFishingDB.mapInfoExpanded
    panel.collapsed = EZFishingDB.mapInfoCollapsed
    panel.bottomSpace = 0

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    panel.icon:SetTexture("Interface\\Icons\\Trade_Fishing")

    -- Zahnrad: Ankerpunkt wählen
    local gear = CreateFrame("Button", nil, panel)
    gear:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    gear:SetScript("OnClick", ShowAnchorMenu)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.MAP_ANCHOR)
        GameTooltip:AddLine(L.MAP_ANCHOR_DESC, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", GameTooltip_Hide)
    panel.gear = gear

    -- Pfeil in der Ecke des Ankerpunkts: Box ein-/ausklappen
    local arrow = CreateFrame("Button", nil, panel)
    arrow:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow:SetScript("OnClick", function(self)
        panel.collapsed = not panel.collapsed
        EZFishingDB.mapInfoCollapsed = panel.collapsed
        GameTooltip_Hide()
        Refresh()
    end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(panel.collapsed and L.MAP_EXPAND or L.MAP_COLLAPSE)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    panel.arrow = arrow

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 4, 0)
    panel.title:SetPoint("RIGHT", gear, "LEFT", -4, 0)
    panel.title:SetJustifyH("LEFT")

    panel.lines = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.lines:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -(PADDING + BUTTON_SIZE + 4))
    panel.lines:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    panel.lines:SetJustifyH("LEFT")
    panel.lines:SetSpacing(2)

    -- Fischliste: Mouse-Over zeigt sie als Tooltip, Klick klappt sie im Panel auf
    local header = CreateFrame("Button", nil, panel)
    header:SetHeight(ROW_HEIGHT)
    header:SetPoint("TOPLEFT", panel.lines, "BOTTOMLEFT", 0, -4)
    header:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT")
    header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    header:SetScript("OnClick", function(self)
        panel.expanded = not panel.expanded
        EZFishingDB.mapInfoExpanded = panel.expanded
        Refresh()
        if panel.expanded then
            GameTooltip_Hide()
        else
            ShowFishTooltip(self)
        end
    end)
    header:SetScript("OnEnter", function(self)
        if panel.expanded then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.MAP_CLICK_COLLAPSE, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        else
            ShowFishTooltip(self)
        end
    end)
    header:SetScript("OnLeave", GameTooltip_Hide)
    panel.fishHeader = header
end

local function UpdateForMap()
    local mapID = WorldMapFrame:GetMapID()
    if EZFishingDB.debug then
        ns.Print("|cff999999Karte: " .. tostring(mapID) .. "|r")
    end
    local zone = EZFishingDB.showMapInfo and mapID and ns.FISHING_ZONES[mapID]
    currentZone = zone
    if not zone then
        if panel then panel:Hide() end
        return
    end
    if not panel then CreatePanel() end
    RequestItemNames(zone)
    Refresh()
    panel:Show()
end

function ns.UpdateMapInfo()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        UpdateForMap()
    elseif panel and not EZFishingDB.showMapInfo then
        panel:Hide()
    end
end

local function HookWorldMap()
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdateForMap)
    elseif WorldMapFrame.SetMapID then
        hooksecurefunc(WorldMapFrame, "SetMapID", UpdateForMap)
    end
    WorldMapFrame:HookScript("OnShow", UpdateForMap)
end

function ns.InitMapInfo()
    -- Die Karten-IDs und Werte gelten nur für die Classic-Welt
    if ns.IS_RETAIL or not ns.FISHING_ZONES then return end
    if WorldMapFrame then
        HookWorldMap()
    else
        -- Kartenaddon wird bei manchen Clients erst bei Bedarf geladen
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_WorldMap" and WorldMapFrame then
                self:UnregisterEvent("ADDON_LOADED")
                HookWorldMap()
            end
        end)
    end
    -- Fertigkeit gestiegen oder Angel/Köder gewechselt: Anzeige auffrischen
    local events = CreateFrame("Frame")
    events:RegisterEvent("SKILL_LINES_CHANGED")
    events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    events:SetScript("OnEvent", function()
        if panel and panel:IsShown() and currentZone then
            Refresh()
        end
    end)
end
