local ADDON_NAME, ns = ...
local L = ns.L

local LOCK_MIN, LOCK_MAX, LOCK_STEP = 0, 10, 1
local RANGE_MIN, RANGE_MAX, RANGE_STEP = 5, 40, 1

---------------------------------------------------------------------------
-- Fenster zum Festlegen der eigenen Taste
---------------------------------------------------------------------------
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}
-- Links-/Rechtsklick bleiben für die Buttons im Fenster frei
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local captureFrame
local keyInitializer

-- Button zeigt die festgelegte Taste, sonst "Taste festlegen"
local function GetKeyButtonText()
    if EZFishingDB.actionKey then
        return GetBindingText(EZFishingDB.actionKey)
    end
    return L.OPT_KEY_BUTTON
end

function ns.RefreshKeyButton()
    if not keyInitializer then return end
    local text = GetKeyButtonText()
    keyInitializer.data.buttonText = text
    -- Bereits angezeigten Button im offenen Einstellungsfenster direkt aktualisieren
    local list = SettingsPanel and SettingsPanel.GetSettingsList and SettingsPanel:GetSettingsList()
    if list and list.ScrollBox then
        list.ScrollBox:ForEachFrame(function(frame)
            if frame.GetElementData and frame:GetElementData() == keyInitializer and frame.Button then
                frame.Button:SetText(text)
            end
        end)
    end
end

local function BuildKeyString(key)
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

local function UpdateCaptureText()
    local current = EZFishingDB.actionKey and GetBindingText(EZFishingDB.actionKey) or L.KEY_NONE
    captureFrame.current:SetText(L.KEY_CURRENT:format(current))
end

local function AcceptKey(key)
    ns.SetActionKey(key)
    captureFrame:Hide()
end

local function CreateCaptureFrame()
    local f = CreateFrame("Frame", "EZFishingKeyCaptureFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 170)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText(L.OPT_KEY)

    local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 24, -48)
    text:SetPoint("TOPRIGHT", -24, -48)
    text:SetJustifyH("CENTER")
    text:SetText(L.KEY_POPUP_TEXT)

    f.current = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.current:SetPoint("TOP", text, "BOTTOM", 0, -12)

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(120, 22)
    clear:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    clear:SetText(L.KEY_CLEAR)
    clear:SetScript("OnClick", function() AcceptKey(nil) end)

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(120, 22)
    cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function() f:Hide() end)

    -- Tastendrücke abfangen, damit sie nicht im Spiel ausgelöst werden
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        elseif not MODIFIER_KEYS[key] then
            AcceptKey(BuildKeyString(key))
        end
    end)
    f:SetScript("OnMouseDown", function(self, button)
        local key = MOUSE_KEYS[button]
        if key then AcceptKey(BuildKeyString(key)) end
    end)
    f:SetScript("OnShow", UpdateCaptureText)

    return f
end

function ns.ShowKeyCapture()
    if InCombatLockdown() then
        ns.Print(L.COMBAT_BLOCKED)
        return
    end
    captureFrame = captureFrame or CreateCaptureFrame()
    captureFrame:Show()
end

---------------------------------------------------------------------------
-- Optionsmenü im WoW-Einstellungsfenster (Optionen > AddOns > EZFishing)
---------------------------------------------------------------------------
function ns.InitOptions()
    local category, layout = Settings.RegisterVerticalLayoutCategory("EZFishing")
    ns.settingsCategory = category
    ns.settings = {}

    local function RegisterSetting(key, varType, name)
        local setting = Settings.RegisterAddOnSetting(category, "EZFishing_" .. key, key,
            EZFishingDB, varType, name, ns.defaults[key])
        setting:SetValueChangedCallback(function()
            ns.OnStateChanged()
        end)
        ns.settings[key] = setting
        return setting
    end

    local function AddHeader(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function AddCheckbox(key, name, tooltip)
        local setting = RegisterSetting(key, Settings.VarType.Boolean, name)
        return Settings.CreateCheckbox(category, setting, tooltip)
    end

    local function AddSlider(key, name, tooltip, minValue, maxValue, step, format)
        local setting = RegisterSetting(key, Settings.VarType.Number, name)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return format:format(math.floor(value + 0.5))
        end)
        return Settings.CreateSlider(category, setting, options, tooltip)
    end

    local function AddDropdown(key, name, tooltip, entries)
        local setting = RegisterSetting(key, Settings.VarType.Number, name)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, entry in ipairs(entries) do
                container:Add(entry[1], entry[2])
            end
            return container:GetData()
        end
        return Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    -- Allgemein
    AddHeader(L.HEADER_GENERAL)
    AddCheckbox("enabled", L.OPT_ENABLED, L.OPT_ENABLED_DESC)

    -- Auslösung: Doppel-Rechtsklick oder eigene Taste
    local triggerInit = AddDropdown("triggerMode", L.OPT_TRIGGER, L.OPT_TRIGGER_DESC, {
        { ns.TRIGGER_DOUBLECLICK, L.TRIGGER_DOUBLECLICK },
        { ns.TRIGGER_KEY, L.TRIGGER_KEY },
    })
    local keyInit = CreateSettingsButtonInitializer(L.OPT_KEY, GetKeyButtonText(),
        ns.ShowKeyCapture, L.OPT_KEY_DESC, true)
    keyInitializer = keyInit
    layout:AddInitializer(keyInit)
    if keyInit.SetParentInitializer then
        keyInit:SetParentInitializer(triggerInit, function()
            return EZFishingDB.triggerMode == ns.TRIGGER_KEY
        end)
    end

    AddCheckbox("dismount", L.OPT_DISMOUNT, L.OPT_DISMOUNT_DESC)
    AddCheckbox("forceSound", L.OPT_SOUND, L.OPT_SOUND_DESC)
    AddSlider("noWaterLock", L.OPT_LOCK, L.OPT_LOCK_DESC, LOCK_MIN, LOCK_MAX, LOCK_STEP, L.SECONDS)
    AddCheckbox("showMinimapButton", L.OPT_MINIMAP, L.OPT_MINIMAP_DESC)

    -- Einholen / WoW-Interaktionseinstellungen
    AddHeader(L.HEADER_INTERACT)
    local reelInit = AddCheckbox("reelIn", L.OPT_REEL, L.OPT_REEL_DESC)
    local function IsReelEnabled() return EZFishingDB.reelIn end

    local modeInit = AddDropdown("interactMode", L.OPT_INTERACT_MODE, L.OPT_INTERACT_MODE_DESC, {
        { 0, L.INTERACT_MODE_OFF },
        { 1, L.INTERACT_MODE_GAMEPAD },
        { 2, L.INTERACT_MODE_KBM },
        { 3, L.INTERACT_MODE_ALWAYS },
    })
    local arcInit = AddDropdown("interactArc", L.OPT_INTERACT_ARC, L.OPT_INTERACT_ARC_DESC, {
        { 0, L.INTERACT_ARC_FRONT },
        { 1, L.INTERACT_ARC_WIDE },
        { 2, L.INTERACT_ARC_ALL },
    })
    local rangeInit = AddSlider("interactRange", L.OPT_INTERACT_RANGE, L.OPT_INTERACT_RANGE_DESC,
        RANGE_MIN, RANGE_MAX, RANGE_STEP, L.YARDS)

    -- Unteroptionen nur bearbeitbar, wenn das Einholen aktiv ist
    for _, initializer in ipairs({ modeInit, arcInit, rangeInit }) do
        if initializer and initializer.SetParentInitializer then
            initializer:SetParentInitializer(reelInit, IsReelEnabled)
        end
    end

    Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Print(L.COMBAT_BLOCKED)
        return
    end
    Settings.OpenToCategory(ns.settingsCategory:GetID())
end
