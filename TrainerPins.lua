local ADDON_NAME, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Angellehrer, Expertenbuch und Fachmann-Quest als Pins auf der Zonenkarte.
-- Es werden nur die NPCs der eigenen Fraktion und neutrale NPCs gezeigt.
-- Daten: Trainers.lua (Classic-Welt, WoW Forever / Classic Era).
---------------------------------------------------------------------------

local PIN_SIZE = 22
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local KIND_ICONS = {
    trainer = "Interface\\Icons\\Trade_Fishing",
    book = "Interface\\Icons\\INV_Misc_Book_09",
    quest = "Interface\\GossipFrame\\AvailableQuestIcon",
}
-- Ringfarbe je Art: Lehrer blau, Buch violett, Quest gold
local KIND_RING = {
    trainer = { 0.35, 0.78, 0.98, 1 },
    book = { 0.75, 0.55, 1, 1 },
    quest = { 1, 0.82, 0.2, 1 },
}

local COLOR_GRAY = "|cff999999"
local COLOR_GREEN = "|cff40ff40"
local COLOR_WHITE = "|cffffffff"

local pins = {}
local hooked = false

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local function GetCanvas()
    if WorldMapFrame.GetCanvas then
        return WorldMapFrame:GetCanvas()
    end
    return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

local function GetCanvasScale()
    if WorldMapFrame.GetCanvasScale then
        return WorldMapFrame:GetCanvasScale() or 1
    end
    return 1
end

local function PlayerFaction()
    return UnitFactionGroup("player")
end

local function IsVisibleForPlayer(npc)
    return not npc.faction or npc.faction == PlayerFaction()
end

-- Lokalisierter NPC-Name aus dem Client-Cache, sonst der englische Name
local npcNames = {}
local function GetNpcName(npc)
    if not npc.id then return npc.name end
    local cached = npcNames[npc.id]
    if cached then return cached end
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink,
            ("unit:Creature-0-0-0-0-%d-0000000000"):format(npc.id))
        local line = ok and data and data.lines and data.lines[1]
        if line and line.leftText and line.leftText ~= "" then
            npcNames[npc.id] = line.leftText
            return line.leftText
        end
    end
    return npc.name
end

local function RankLabel(rank)
    return L["RANK_" .. rank.key] .. (" (%d–%d)"):format(rank.from, rank.to)
end

-- Stand des Spielers: bereits gelernter Rang = maximale Fertigkeit >= rank.to
local function RankColor(rank, maxRank)
    if maxRank and maxRank >= rank.to then
        return COLOR_GRAY
    end
    return COLOR_WHITE
end

local function RequirementText(rank)
    local text = L.TRAINER_REQ_LEVEL:format(rank.level)
    if rank.skill and rank.skill > 0 then
        text = text .. ", " .. L.TRAINER_REQ_SKILL:format(rank.skill)
    end
    return text
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function ShowPinTooltip(pin)
    local npc = pin.npc
    local _, _, maxRank = ns.GetFishingSkill()
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(GetNpcName(npc), 1, 1, 1)
    GameTooltip:AddLine(L["TRAINER_KIND_" .. strupper(npc.kind)], 0.35, 0.78, 0.98)

    for _, rank in ipairs(ns.FISHING_RANKS) do
        if rank.source == npc.kind then
            local learned = maxRank and maxRank >= rank.to
            GameTooltip:AddDoubleLine(RankColor(rank, maxRank) .. RankLabel(rank) .. "|r",
                learned and (COLOR_GREEN .. L.TRAINER_LEARNED .. "|r") or RequirementText(rank),
                1, 1, 1, 0.8, 0.8, 0.8)
        end
    end

    if npc.kind == "book" and npc.item then
        local name = ns.GetItemNameAndIcon(npc.item) or ("Item " .. npc.item)
        GameTooltip:AddLine(L.TRAINER_BOOK:format(name), 1, 0.82, 0, true)
        if npc.price and GetCoinTextureString then
            GameTooltip:AddLine(L.TRAINER_PRICE .. " " .. GetCoinTextureString(npc.price), 0.8, 0.8, 0.8)
        end
    elseif npc.kind == "quest" then
        GameTooltip:AddLine(L.TRAINER_QUEST, 1, 0.82, 0, true)
        if npc.fish then
            for _, itemID in ipairs(npc.fish) do
                local name, icon = ns.GetItemNameAndIcon(itemID)
                GameTooltip:AddLine(("|T%s:14:14:0:0|t %s"):format(icon or 134400, name or ("Item " .. itemID)),
                    0.9, 0.9, 0.9)
            end
        end
    end
    if npc.note then
        GameTooltip:AddLine(L["TRAINER_NOTE_" .. npc.note], 0.6, 0.6, 0.6, true)
    end
    GameTooltip:AddLine(COLOR_GRAY .. ("%.1f, %.1f"):format(npc.x, npc.y) .. "|r")
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------
local function AddCircleMask(owner, texture)
    if texture.AddMaskTexture and owner.CreateMaskTexture then
        local mask = owner:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
    end
end

local function GetPin(index)
    local pin = pins[index]
    if pin then return pin end
    local canvas = GetCanvas()
    pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(PIN_SIZE, PIN_SIZE)

    -- Glas-Ring: farbiger Rand, dunkle Fläche, rundes Symbol
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetTexture(WHITE)
    pin.ring:SetAllPoints()
    AddCircleMask(pin, pin.ring)
    pin.fill = pin:CreateTexture(nil, "BORDER")
    pin.fill:SetTexture(WHITE)
    pin.fill:SetVertexColor(0.07, 0.08, 0.11, 0.85)
    pin.fill:SetPoint("TOPLEFT", 2, -2)
    pin.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    AddCircleMask(pin, pin.fill)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("TOPLEFT", 3, -3)
    pin.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    AddCircleMask(pin, pin.icon)
    pin.glow = pin:CreateTexture(nil, "HIGHLIGHT")
    pin.glow:SetTexture(WHITE)
    pin.glow:SetVertexColor(1, 1, 1, 0.25)
    pin.glow:SetAllPoints()
    AddCircleMask(pin, pin.glow)

    pin:SetScript("OnEnter", ShowPinTooltip)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pins[index] = pin
    return pin
end

local function PlacePin(pin)
    local canvas = GetCanvas()
    local scale = 1 / GetCanvasScale()
    pin:SetScale(scale)
    pin:ClearAllPoints()
    -- offset: fester Bildschirmversatz für Pins, die fast übereinander liegen
    local offset = pin.npc.offset
    pin:SetPoint("CENTER", canvas, "TOPLEFT",
        canvas:GetWidth() * pin.npc.x / 100 / scale + (offset and offset[1] or 0),
        -canvas:GetHeight() * pin.npc.y / 100 / scale + (offset and offset[2] or 0))
end

-- Buch- und Fischnamen vorab in den Item-Cache laden (für den Tooltip)
local function RequestItems(npc)
    if not Item or not Item.CreateFromItemID then return end
    local ids = npc.fish and { unpack(npc.fish) } or {}
    if npc.item then ids[#ids + 1] = npc.item end
    for _, itemID in ipairs(ids) do
        if not ns.GetItemNameAndIcon(itemID) then
            Item:CreateFromItemID(itemID):ContinueOnItemLoad(function() end)
        end
    end
end

local function HideAll()
    for _, pin in ipairs(pins) do
        pin:Hide()
        pin.npc = nil
    end
end

local function RepositionPins()
    for _, pin in ipairs(pins) do
        if pin.npc and pin:IsShown() then
            PlacePin(pin)
        end
    end
end

function ns.UpdateTrainerPins(mapID)
    if not ns.FISHING_TRAINERS or not WorldMapFrame then return end
    HideAll()
    if not EZFishingDB.showTrainers or not mapID then return end
    local list = ns.FISHING_TRAINERS[mapID]
    if not list then return end

    -- Zoomen und Vollbild/Fenster: Größe und Position der Pins nachziehen
    if not hooked then
        for _, method in ipairs({ "OnCanvasScaleChanged", "OnCanvasSizeChanged" }) do
            if WorldMapFrame[method] then
                hooksecurefunc(WorldMapFrame, method, RepositionPins)
            end
        end
        hooked = true
    end

    local canvas = GetCanvas()
    local index = 0
    for _, npc in ipairs(list) do
        if IsVisibleForPlayer(npc) then
            index = index + 1
            local pin = GetPin(index)
            pin.npc = npc
            pin:SetFrameLevel(canvas:GetFrameLevel() + 900)
            pin.ring:SetVertexColor(unpack(KIND_RING[npc.kind]))
            pin.icon:SetTexture(KIND_ICONS[npc.kind])
            if npc.kind == "quest" then
                pin.icon:SetTexCoord(0, 1, 0, 1)
            else
                pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            pin:Show()
            PlacePin(pin)
            RequestItems(npc)
        end
    end
end

---------------------------------------------------------------------------
-- Nächster Rang für die Box auf der Karte
---------------------------------------------------------------------------
function ns.GetNextFishingRank()
    local _, _, maxRank = ns.GetFishingSkill()
    for _, rank in ipairs(ns.FISHING_RANKS) do
        if not maxRank or maxRank < rank.to then
            return rank
        end
    end
end

ns.FishingRankLabel = RankLabel
ns.FishingRankRequirement = RequirementText
