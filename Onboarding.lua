local ADDON_NAME, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Einrichtungsassistent: führt beim ersten Start durch die wichtigsten
-- Einstellungen. Alles Weitere bleibt im Optionsmenü änderbar.
---------------------------------------------------------------------------
local FRAME_WIDTH = 500
local PADDING = 24
local CONTENT_WIDTH = FRAME_WIDTH - 2 * PADDING
local MAX_OPTIONS = 4
local SHOW_DELAY = 3 -- Sekunden nach dem Login

local frame
local steps, visibleSteps
local stepIndex = 1
local choices = {}
local finished = false

local function YesNo(yesDesc, noDesc, recommendYes)
    return {
        { value = true, label = YES, desc = yesDesc, recommended = recommendYes },
        { value = false, label = NO, desc = noDesc, recommended = not recommendYes },
    }
end

local function BuildSteps()
    local list = {
        { title = L.ONB_WELCOME_TITLE, text = L.ONB_WELCOME_TEXT },
        {
            key = "triggerMode", title = L.ONB_TRIGGER_TITLE, text = L.ONB_TRIGGER_TEXT,
            options = {
                { value = ns.TRIGGER_DOUBLECLICK, label = L.TRIGGER_DOUBLECLICK,
                  desc = L.ONB_TRIGGER_DC_DESC, recommended = true },
                { value = ns.TRIGGER_KEY, label = L.TRIGGER_KEY, desc = L.ONB_TRIGGER_KEY_DESC },
            },
            keyCapture = true,
        },
        {
            key = "reelIn", title = L.ONB_REEL_TITLE, text = L.ONB_REEL_TEXT,
            options = YesNo(L.ONB_REEL_YES_DESC, L.ONB_REEL_NO_DESC, true),
        },
        {
            key = "dismount", title = L.ONB_DISMOUNT_TITLE, text = L.ONB_DISMOUNT_TEXT,
            options = YesNo(L.ONB_DISMOUNT_YES_DESC, L.ONB_DISMOUNT_NO_DESC, true),
        },
        {
            key = "forceSound", title = L.ONB_SOUND_TITLE, text = L.ONB_SOUND_TEXT,
            options = YesNo(L.ONB_SOUND_YES_DESC, L.ONB_SOUND_NO_DESC, true),
        },
    }
    -- Angel anlegen und Waffen zurücktauschen gibt es nur auf Classic-Clients
    if not ns.IS_RETAIL then
        table.insert(list, {
            key = "autoEquipPole", title = L.ONB_POLE_TITLE, text = L.ONB_POLE_TEXT,
            options = YesNo(L.ONB_POLE_YES_DESC, L.ONB_POLE_NO_DESC, true),
        })
        local restoreOptions = {}
        for _, seconds in ipairs({ 0, 10, 20, 30 }) do
            table.insert(restoreOptions, {
                value = seconds,
                label = seconds == 0 and L.ONB_RESTORE_OFF or L.ONB_RESTORE_SEC:format(seconds),
                desc = seconds == 0 and L.ONB_RESTORE_OFF_DESC or nil,
                recommended = seconds == ns.defaults.weaponRestoreDelay,
            })
        end
        table.insert(list, {
            key = "weaponRestoreDelay", title = L.ONB_RESTORE_TITLE, text = L.ONB_RESTORE_TEXT,
            options = restoreOptions,
            condition = function() return choices.autoEquipPole end,
        })
    end
    table.insert(list, {
        key = "showMinimapButton", title = L.ONB_MINIMAP_TITLE, text = L.ONB_MINIMAP_TEXT,
        options = YesNo(L.ONB_MINIMAP_YES_DESC, L.ONB_MINIMAP_NO_DESC, true),
    })
    table.insert(list, { title = L.ONB_DONE_TITLE, text = L.ONB_DONE_TEXT, last = true })
    return list
end

-- Schritte mit Bedingung (z. B. Waffen-Rücktausch nur mit Angel-Automatik) filtern
local function UpdateVisibleSteps()
    local current = visibleSteps and visibleSteps[stepIndex]
    visibleSteps = {}
    for _, step in ipairs(steps) do
        if not step.condition or step.condition() then
            table.insert(visibleSteps, step)
        end
    end
    if current then
        for i, step in ipairs(visibleSteps) do
            if step == current then stepIndex = i end
        end
    end
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local Render -- weiter unten definiert

local function CreateOptionRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(CONTENT_WIDTH)

    row.radio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
    row.radio:SetPoint("TOPLEFT", 0, 0)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.label:SetPoint("LEFT", row.radio, "RIGHT", 6, 0)
    row.label:SetJustifyH("LEFT")

    row.desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.desc:SetPoint("TOPLEFT", row.radio, "BOTTOMLEFT", 22, -2)
    row.desc:SetWidth(CONTENT_WIDTH - 22)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetWordWrap(true)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.06)

    local function Select()
        local step = visibleSteps[stepIndex]
        choices[step.key] = row.value
        UpdateVisibleSteps()
        Render()
    end
    row:SetScript("OnClick", Select)
    row.radio:SetScript("OnClick", Select)
    return row
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "EZFishingOnboardingFrame", UIParent, "BackdropTemplate")
    f:SetWidth(FRAME_WIDTH)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()
    -- Mit Escape schließen
    tinsert(UISpecialFrames, f:GetName())

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(28, 28)
    f.icon:SetPoint("TOPLEFT", PADDING, -20)
    f.icon:SetTexture("Interface\\Icons\\Trade_Fishing")

    f.header = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.header:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.header:SetText(L.ONB_TITLE)

    f.stepLabel = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.stepLabel:SetPoint("TOPRIGHT", -PADDING - 24, -28)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -6, -6)

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -14)
    f.title:SetWidth(CONTENT_WIDTH)
    f.title:SetJustifyH("LEFT")

    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.text:SetWidth(CONTENT_WIDTH)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(true)
    f.text:SetSpacing(2)

    f.rows = {}
    for i = 1, MAX_OPTIONS do
        f.rows[i] = CreateOptionRow(f)
    end

    -- Eigene Taste direkt im Assistenten festlegen
    f.keyButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.keyButton:SetSize(180, 24)
    f.keyButton:SetScript("OnClick", function() ns.ShowKeyCapture() end)
    f.keyHint = f:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    f.keyHint:SetPoint("LEFT", f.keyButton, "RIGHT", 10, 0)
    f.keyHint:SetText(L.ONB_KEY_MISSING)

    f.back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.back:SetSize(110, 24)
    f.back:SetPoint("BOTTOMLEFT", PADDING - 4, 20)
    f.back:SetText(L.ONB_BACK)
    f.back:SetScript("OnClick", function()
        stepIndex = math.max(1, stepIndex - 1)
        Render()
    end)

    f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.next:SetSize(110, 24)
    f.next:SetPoint("BOTTOMRIGHT", -PADDING + 4, 20)
    f.next:SetScript("OnClick", function()
        if visibleSteps[stepIndex].last then
            ns.FinishOnboarding()
        else
            stepIndex = math.min(#visibleSteps, stepIndex + 1)
            Render()
        end
    end)

    f.skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.skip:SetSize(110, 24)
    f.skip:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f.skip:SetText(L.ONB_SKIP)
    f.skip:SetScript("OnClick", function() f:Hide() end)

    -- Schließen ohne Abschluss zählt als Überspringen: nicht bei jedem Login erneut fragen
    f:SetScript("OnHide", function()
        if not finished then
            EZFishingDB.onboarded = true
            ns.Print(L.ONB_SKIPPED)
        end
    end)

    return f
end

local function RefreshKeyControls(step)
    local showKey = step.keyCapture and choices.triggerMode == ns.TRIGGER_KEY
    frame.keyButton:SetShown(showKey)
    local missing = showKey and not EZFishingDB.actionKey
    frame.keyHint:SetShown(missing)
    if showKey then
        frame.keyButton:SetText(EZFishingDB.actionKey and GetBindingText(EZFishingDB.actionKey)
            or L.OPT_KEY_BUTTON)
    end
    -- Ohne Taste wäre die Auslösung per Taste wirkungslos
    frame.next:SetEnabled(not missing)
end

function Render()
    local step = visibleSteps[stepIndex]
    frame.stepLabel:SetText(L.ONB_STEP:format(stepIndex, #visibleSteps))
    frame.title:SetText(step.title)
    frame.text:SetText(step.text)

    local anchor, offset = frame.text, -16
    for i, row in ipairs(frame.rows) do
        local option = step.options and step.options[i]
        if option then
            row.value = option.value
            local label = option.label
            if option.recommended then
                label = label .. "  |cff33ff99" .. L.ONB_RECOMMENDED .. "|r"
            end
            row.label:SetText(label)
            row.desc:SetText(option.desc or "")
            row.desc:SetShown(option.desc ~= nil)
            row.radio:SetChecked(choices[step.key] == option.value)
            local height = 24 + (option.desc and (row.desc:GetStringHeight() + 4) or 0)
            row:SetHeight(height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
            row:Show()
            anchor, offset = row, -8
        else
            row:Hide()
        end
    end

    frame.keyButton:ClearAllPoints()
    frame.keyButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 22, -10)
    RefreshKeyControls(step)
    if frame.keyButton:IsShown() then
        anchor = frame.keyButton
    end

    frame.back:SetEnabled(stepIndex > 1)
    frame.skip:SetShown(not step.last)
    frame.next:SetText(step.last and L.ONB_FINISH or L.ONB_NEXT)

    -- Fensterhöhe an den Inhalt anpassen
    local top = frame:GetTop()
    local bottom = anchor:GetBottom()
    if top and bottom then
        frame:SetHeight(math.max(240, top - bottom + 70))
    else
        frame:SetHeight(380)
    end
end

-- Nach dem Festlegen der Taste im Tastenfenster den Assistenten aktualisieren
function ns.RefreshOnboarding()
    if frame and frame:IsShown() then
        RefreshKeyControls(visibleSteps[stepIndex])
    end
end

---------------------------------------------------------------------------
-- Ablauf
---------------------------------------------------------------------------
function ns.ShowOnboarding()
    frame = frame or CreateMainFrame()
    finished = false
    -- Mit den aktuellen Werten starten, damit ein erneuter Durchlauf nichts verstellt
    wipe(choices)
    for key in pairs(ns.defaults) do
        choices[key] = EZFishingDB[key]
    end
    steps = BuildSteps()
    visibleSteps = nil
    stepIndex = 1
    UpdateVisibleSteps()
    frame:Show()
    -- Zweimal rendern: Erst nach dem Anzeigen sind die Positionen für die Höhe bekannt
    Render()
    Render()
end

function ns.FinishOnboarding()
    for _, step in ipairs(steps) do
        if step.key and choices[step.key] ~= nil then
            ns.SetOption(step.key, choices[step.key])
        end
    end
    -- Eigene Taste gewählt, aber keine festgelegt: auf Doppelklick zurückfallen
    if EZFishingDB.triggerMode == ns.TRIGGER_KEY and not EZFishingDB.actionKey then
        ns.SetOption("triggerMode", ns.TRIGGER_DOUBLECLICK)
    end
    EZFishingDB.onboarded = true
    finished = true
    frame:Hide()
    ns.Print(L.ONB_DONE_MSG)
end

-- Beim ersten Start automatisch anzeigen (nicht im Kampf)
local waitFrame = CreateFrame("Frame")
local function TryAutoShow()
    if EZFishingDB.onboarded then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    waitFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ns.ShowOnboarding()
end
waitFrame:SetScript("OnEvent", TryAutoShow)

function ns.ScheduleOnboarding()
    if EZFishingDB.onboarded then return end
    C_Timer.After(SHOW_DELAY, TryAutoShow)
end
