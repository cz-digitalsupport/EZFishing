local ADDON_NAME, ns = ...
local L = ns.L

-- Spell-IDs von "Angeln" (sprachunabhängig), in Prüfreihenfolge:
-- Retail nutzt 131474, Classic-Clients (z. B. WoW Forever) die Ränge
-- Großmeister/Fachmann/Experte/Geselle/Lehrling. Die erste bekannte ID gewinnt.
local FISHING_CAST_IDS = { 131474, 18248, 7732, 7731, 7620 }
local FISHING_SPELL_ID = FISHING_CAST_IDS[1] -- wird beim Login aufgelöst
-- Der Kanal-Zauber beim Angeln kann eine andere ID haben als der Wurf selbst
local FISHING_SPELL_IDS = {
    [131474] = true, [131476] = true, [131490] = true,
    [7620] = true, [7731] = true, [7732] = true, [18248] = true,
    [33095] = true, [51294] = true, [88868] = true, [110410] = true,
}
-- Maximaler Abstand zwischen zwei Rechtsklicks (Sekunden)
local DOUBLE_CLICK_TIME = 0.4
local BUTTON_NAME = "EZFishingCastButton"

ns.defaults = {
    enabled = true,
    debug = false,
    -- Sperre des Doppelklicks nach einem Wurf ohne Wasser (Sekunden)
    noWaterLock = 3,
    -- Schwimmer per Doppel-Rechtsklick einholen
    reelIn = true,
    showMinimapButton = true,
    minimapAngle = 220,
    -- Angelgeräusche während des Angelns erzwingen
    forceSound = false,
    -- WoW-Einstellungen für die Interaktion (werden gesetzt, solange reelIn aktiv ist)
    interactMode = 3,   -- SoftTargetInteract: 0 aus, 1 Gamepad, 2 Maus/Tastatur, 3 immer
    interactArc = 2,    -- SoftTargetInteractArc: 0 direkt voraus, 1 vorne, 2 rundum
    interactRange = 30, -- SoftTargetInteractRange in Metern
    -- Auslösung: 1 = Doppel-Rechtsklick, 2 = eigene Taste
    triggerMode = 1,
    -- Eigene Taste im WoW-Format, z. B. "1", "SHIFT-F" oder "BUTTON4"
    actionKey = nil,
    -- Aufgesessen: per Auslösung absitzen statt auszuwerfen
    dismount = false,
    -- Classic-Clients (z. B. WoW Forever): fehlende Angel aus den Taschen anlegen
    autoEquipPole = true,
    -- Nach so vielen Sekunden ohne Angeln die vorherigen Waffen wieder anlegen (0 = aus)
    weaponRestoreDelay = 30,
}

-- Erlaubter Bereich für den Waffen-Rücktausch (auch vom Optionsmenü genutzt)
ns.WEAPON_RESTORE_MIN, ns.WEAPON_RESTORE_MAX, ns.WEAPON_RESTORE_STEP = 0, 30, 5

ns.TRIGGER_DOUBLECLICK = 1
ns.TRIGGER_KEY = 2

-- Während des Angelns: Effekte laut, Musik/Umgebung/Dialoge stumm
local FISHING_SOUND_CVARS = {
    Sound_EnableAllSound = "1",
    Sound_EnableSFX = "1",
    Sound_EnableSoundWhenGameIsInBG = "1",
    Sound_MasterVolume = "1",
    Sound_SFXVolume = "1",
    Sound_MusicVolume = "0",
    Sound_AmbienceVolume = "0",
    Sound_DialogVolume = "0",
}
-- Nach so vielen Sekunden ohne neuen Wurf werden die Toneinstellungen zurückgesetzt
local SOUND_RESTORE_DELAY = 10

-- Soft-Target-Einstellungen, damit die Interaktionstaste den Schwimmer erfasst
local function GetSoftInteractCVars()
    return {
        SoftTargetInteract = tostring(EZFishingDB.interactMode),
        SoftTargetInteractArc = tostring(EZFishingDB.interactArc),
        SoftTargetInteractRange = tostring(EZFishingDB.interactRange),
    }
end

local lastClickTime = 0
local bindingActive = false
local lockedUntil = 0
local reelBindingActive = false
local reelBindingToken = 0
local pendingCVarUpdate = false
local pendingKeyUpdate = false
local soundRestoreToken = 0
local fishingChannelActive = false -- beim Kanalstart gesetzt, beim Stopp gelöscht
local UpdateKeyBinding -- weiter unten definiert
local GetPoleToEquip -- weiter unten definiert

function ns.Print(msg)
    print("|cff33ccffEZFishing|r: " .. msg)
end
local Print = ns.Print

local function Debug(msg)
    if EZFishingDB and EZFishingDB.debug then
        Print("|cff999999" .. msg .. "|r")
    end
end

---------------------------------------------------------------------------
-- Secure Button: wirft die Angel aus, wenn er "geklickt" wird
---------------------------------------------------------------------------
local castButton = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
castButton:SetAttribute("type", "spell")
castButton:SetAttribute("spell", FISHING_SPELL_ID)
-- Beide registrieren, damit es unabhängig von der CVar "ActionButtonUseKeyDown" auslöst
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:Hide()

local function KnowsSpell(spellID)
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    return false
end

-- Bekannte Angel-ID ermitteln und am Secure Button hinterlegen
local function ResolveFishingSpell()
    local found
    for _, spellID in ipairs(FISHING_CAST_IDS) do
        if KnowsSpell(spellID) then
            found = spellID
            break
        end
    end
    if not found or InCombatLockdown() then return end
    if found ~= FISHING_SPELL_ID or castButton:GetAttribute("spell") ~= found then
        FISHING_SPELL_ID = found
        castButton:SetAttribute("spell", found)
        Debug("Angel-Zauber: ID " .. found)
    end
end

local function ClearCastBinding()
    if not bindingActive or InCombatLockdown() then return end
    ClearOverrideBindings(castButton)
    bindingActive = false
end

castButton:SetScript("PostClick", function(self)
    local actionType = self:GetAttribute("type")
    if actionType == "spell" then
        Debug("Angel ausgeworfen")
    elseif actionType == "macro" then
        Debug("Abgesessen")
    end
    ClearCastBinding()
end)

---------------------------------------------------------------------------
-- Schwimmer einholen: Rechtsklick kurzzeitig auf "Mit Ziel interagieren" legen
---------------------------------------------------------------------------
local reelFrame = CreateFrame("Frame")

local function ClearReelBinding()
    if not reelBindingActive or InCombatLockdown() then return end
    ClearOverrideBindings(reelFrame)
    reelBindingActive = false
end

local function ArmReelBinding()
    if InCombatLockdown() then return end
    SetOverrideBinding(reelFrame, true, "BUTTON2", "INTERACTTARGET")
    reelBindingActive = true
    -- Kommt kein zweiter Klick, bekommt die Maustaste ihre normale Funktion zurück
    reelBindingToken = reelBindingToken + 1
    local token = reelBindingToken
    C_Timer.After(DOUBLE_CLICK_TIME, function()
        if token == reelBindingToken then ClearReelBinding() end
    end)
end

local function ApplySoftInteractCVars()
    EZFishingDB.savedCVars = EZFishingDB.savedCVars or {}
    for name, value in pairs(GetSoftInteractCVars()) do
        local current = GetCVar(name)
        if current == nil then
            -- CVar gibt es auf diesem Client nicht: überspringen statt Fehler
            Debug("CVar fehlt: " .. name)
        else
            -- Originalwert nur einmal merken, damit wir nicht unsere eigenen Werte sichern
            if EZFishingDB.savedCVars[name] == nil then
                EZFishingDB.savedCVars[name] = current
            end
            if current ~= value then
                SetCVar(name, value)
            end
        end
    end
end

local function RestoreSoftInteractCVars()
    if not EZFishingDB.savedCVars then return end
    for name, value in pairs(EZFishingDB.savedCVars) do
        SetCVar(name, value)
    end
    EZFishingDB.savedCVars = nil
end

local function UpdateSoftInteractCVars()
    -- CVars im Kampf nicht anfassen, sondern nach dem Kampf nachholen
    if InCombatLockdown() then
        pendingCVarUpdate = true
        return
    end
    pendingCVarUpdate = false
    if EZFishingDB.enabled and EZFishingDB.reelIn then
        ApplySoftInteractCVars()
    else
        RestoreSoftInteractCVars()
    end
end

---------------------------------------------------------------------------
-- Angelgeräusche erzwingen
---------------------------------------------------------------------------
local function ApplyFishingSound()
    -- Originalwerte merken (überlebt auch /reload oder Absturz)
    if not EZFishingDB.savedSoundCVars then
        EZFishingDB.savedSoundCVars = {}
        for name in pairs(FISHING_SOUND_CVARS) do
            EZFishingDB.savedSoundCVars[name] = GetCVar(name)
        end
    end
    for name, value in pairs(FISHING_SOUND_CVARS) do
        if GetCVar(name) ~= value then
            SetCVar(name, value)
        end
    end
end

local function RestoreFishingSound()
    soundRestoreToken = soundRestoreToken + 1
    if not EZFishingDB.savedSoundCVars then return end
    for name, value in pairs(EZFishingDB.savedSoundCVars) do
        SetCVar(name, value)
    end
    EZFishingDB.savedSoundCVars = nil
    Debug("Toneinstellungen wiederhergestellt")
end

-- Verzögert zurücksetzen, damit der Ton zwischen zwei Würfen nicht springt
local function ScheduleSoundRestore()
    soundRestoreToken = soundRestoreToken + 1
    local token = soundRestoreToken
    C_Timer.After(SOUND_RESTORE_DELAY, function()
        if token == soundRestoreToken then RestoreFishingSound() end
    end)
end

---------------------------------------------------------------------------
-- Zustand ändern (von Optionen, Minimap-Button und Slash-Befehlen genutzt)
---------------------------------------------------------------------------
function ns.OnStateChanged()
    if not EZFishingDB.enabled then
        ClearCastBinding()
        ClearReelBinding()
    end
    if not (EZFishingDB.enabled and EZFishingDB.forceSound) then
        RestoreFishingSound()
    end
    UpdateSoftInteractCVars()
    UpdateKeyBinding()
    if ns.UpdateMinimapButton then
        ns.UpdateMinimapButton()
    end
end

-- Über das Settings-Objekt setzen, damit das Optionsmenü synchron bleibt
function ns.SetOption(key, value)
    local setting = ns.settings and ns.settings[key]
    if setting then
        setting:SetValue(value)
    else
        EZFishingDB[key] = value
        ns.OnStateChanged()
    end
end

function ns.ToggleEnabled()
    ns.SetOption("enabled", not EZFishingDB.enabled)
    Print(EZFishingDB.enabled and L.MSG_ENABLED or L.MSG_DISABLED)
end

---------------------------------------------------------------------------
-- Prüfungen
---------------------------------------------------------------------------
local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end
    return GetSpellInfo and (GetSpellInfo(spellID))
end

-- Per ID-Liste und zusätzlich per (lokalisiertem) Zaubernamen erkennen
local function IsFishingSpell(spellID, spellName)
    if spellID and FISHING_SPELL_IDS[spellID] then return true end
    local fishingName = GetSpellName(FISHING_SPELL_ID)
    if not fishingName then return false end
    if spellName and spellName == fishingName then return true end
    if spellID then
        return GetSpellName(spellID) == fishingName
    end
    return false
end

local function IsFishingChanneling()
    local name, _, _, _, _, _, _, spellID = UnitChannelInfo("player")
    if not name then return false end
    return IsFishingSpell(spellID, name)
end

-- Fischschwärme zeigen ebenfalls einen Tooltip, sollen aber anklickbar bleiben
local function IsFishingPoolName(name)
    name = strlower(name)
    for _, pattern in ipairs(L.POOL_PATTERNS) do
        if name:find(pattern, 1, true) then return true end
    end
    return false
end

-- Die API kennt keine Abfrage für Objekte unter der Maus. Zeigt man auf ein
-- Weltobjekt, blendet das Spiel aber einen Tooltip ein – den werten wir aus.
local function GetWorldObjectUnderMouse()
    if not GameTooltip:IsShown() or GameTooltip:GetAlpha() < 1 then return nil end
    local owner = GameTooltip:GetOwner()
    if owner ~= UIParent and owner ~= WorldFrame then return nil end
    local line = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    if not line or line == "" then return nil end
    return line
end

-- skipMouseChecks: bei Auslösung per Taste ist egal, was unter der Maus liegt
local function CanStartFishing(skipMouseChecks)
    if not EZFishingDB.enabled then return false end
    if GetTime() < lockedUntil then
        Debug("Gesperrt nach Wurf ohne Wasser")
        return false
    end
    -- Nur außerhalb des Kampfes (UnitAffectingCombat greift auch kurz vor dem Lockdown)
    if InCombatLockdown() or UnitAffectingCombat("player") then return false end
    if not KnowsSpell(FISHING_SPELL_ID) then
        Debug("Nicht ausgeworfen: Angeln nicht erlernt (ID " .. FISHING_SPELL_ID .. ")")
        return false
    end
    if not skipMouseChecks then
        -- Rechtsklick auf NPCs/Spieler (inkl. Questgeber) nicht abfangen
        if UnitExists("mouseover") then
            Debug("Nicht ausgeworfen: NPC/Spieler unter der Maus")
            return false
        end
        -- Rechtsklick auf Objekte (Kisten, Kräuter, Briefkasten, Questobjekte …) nicht abfangen
        local objectName = GetWorldObjectUnderMouse()
        if objectName and not IsFishingPoolName(objectName) then
            Debug("Nicht ausgeworfen: Objekt unter der Maus (" .. objectName .. ")")
            return false
        end
    end
    if IsFlying() then return false end
    -- Nur im Stillstand (Bewegung würde den Cast ohnehin abbrechen)
    if GetUnitSpeed("player") > 0 or IsFalling() then
        Debug("Nicht ausgeworfen: in Bewegung")
        return false
    end
    -- Nicht auswerfen, wenn der Cast die Gestalt aufheben würde. Mit der Option
    -- "Per Auslösung absitzen" wird aufgesessen stattdessen abgesessen.
    if UnitInVehicle("player") then
        Debug("Nicht ausgeworfen: in einem Fahrzeug")
        return false
    end
    if IsMounted() and not EZFishingDB.dismount then
        Debug("Nicht ausgeworfen: aufgesessen")
        return false
    end
    if select(2, UnitClass("player")) == "DRUID" and GetShapeshiftForm() ~= 0 then
        Debug("Nicht ausgeworfen: Druidengestalt")
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Angel automatisch anlegen (nur Clients, die zum Angeln eine Angel brauchen)
---------------------------------------------------------------------------
local MAINHAND_SLOT = INVSLOT_MAINHAND or 16
local ITEM_CLASS_WEAPON = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local WEAPON_FISHING_POLE = Enum and Enum.ItemWeaponSubclass
    and Enum.ItemWeaponSubclass.Fishingpole or 20

local function IsFishingPole(itemID)
    if not itemID then return false end
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not getInfo then return false end
    local _, _, _, _, _, classID, subclassID = getInfo(itemID)
    return classID == ITEM_CLASS_WEAPON and subclassID == WEAPON_FISHING_POLE
end

local function GetItemLevel(itemID)
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local level = getInfo and select(4, getInfo(itemID))
    return level or 0
end

-- Liefert die Item-ID der besten Angel in den Taschen, wenn keine angelegt ist
function GetPoleToEquip()
    -- Retail braucht keine Angel zum Angeln
    if FISHING_SPELL_ID == FISHING_CAST_IDS[1] then return nil end
    if IsFishingPole(GetInventoryItemID("player", MAINHAND_SLOT)) then return nil end
    local container = C_Container
    if not (container and container.GetContainerNumSlots and container.GetContainerItemID) then
        return nil
    end
    local bestID, bestLevel
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, container.GetContainerNumSlots(bag) do
            local itemID = container.GetContainerItemID(bag, slot)
            if IsFishingPole(itemID) then
                local level = GetItemLevel(itemID)
                if not bestID or level > bestLevel then
                    bestID, bestLevel = itemID, level
                end
            end
        end
    end
    return bestID
end

---------------------------------------------------------------------------
-- Vorherige Waffen merken und nach einer Angelpause wieder anlegen
---------------------------------------------------------------------------
local OFFHAND_SLOT = INVSLOT_OFFHAND or 17
local OFFHAND_DELAY = 0.5 -- Nebenhand erst anlegen, wenn die Haupthand fertig ist
local weaponRestoreToken = 0
local pendingWeaponRestore = false

local equipItem = (C_Item and C_Item.EquipItemByName) or EquipItemByName

-- Waffen pro Charakter speichern (EZFishingDB gilt accountweit)
local function GetCharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function GetSavedWeapons()
    return EZFishingDB.savedWeapons and EZFishingDB.savedWeapons[GetCharKey()]
end

local function ClearSavedWeapons()
    if EZFishingDB.savedWeapons then
        EZFishingDB.savedWeapons[GetCharKey()] = nil
        if next(EZFishingDB.savedWeapons) == nil then
            EZFishingDB.savedWeapons = nil
        end
    end
end

-- Vor dem Anlegen der Angel aufrufen
local function RememberWeapons()
    local main = GetInventoryItemLink("player", MAINHAND_SLOT)
    local off = GetInventoryItemLink("player", OFFHAND_SLOT)
    if not (main or off) then return end
    EZFishingDB.savedWeapons = EZFishingDB.savedWeapons or {}
    EZFishingDB.savedWeapons[GetCharKey()] = { main = main, off = off }
    Debug("Waffen gemerkt: " .. tostring(main) .. " / " .. tostring(off))
end

local function RestoreWeapons()
    local saved = GetSavedWeapons()
    if not saved or not equipItem then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        -- Im Kampf darf ein Addon keine Waffen wechseln: nach dem Kampf nachholen
        pendingWeaponRestore = true
        return
    end
    pendingWeaponRestore = false
    -- Hat der Spieler die Angel inzwischen selbst abgelegt, nichts anfassen
    if not IsFishingPole(GetInventoryItemID("player", MAINHAND_SLOT)) then
        Debug("Kein Rücktausch: Angel nicht mehr angelegt")
        ClearSavedWeapons()
        return
    end
    if UnitIsDeadOrGhost("player") or UnitChannelInfo("player") or UnitCastingInfo("player") then
        -- Gerade unpassend: nach einer weiteren Pause erneut versuchen
        -- (neues Angeln erhöht das Token und bricht den Versuch ab)
        local token = weaponRestoreToken
        C_Timer.After(5, function()
            if token == weaponRestoreToken then RestoreWeapons() end
        end)
        return
    end
    ClearSavedWeapons()
    if saved.main then
        equipItem(saved.main, MAINHAND_SLOT)
    end
    if saved.off then
        C_Timer.After(saved.main and OFFHAND_DELAY or 0, function()
            if not InCombatLockdown() then
                equipItem(saved.off, OFFHAND_SLOT)
            end
        end)
    end
    Print(L.WEAPONS_RESTORED)
end

local function CancelWeaponRestore()
    weaponRestoreToken = weaponRestoreToken + 1
end

-- Nach jeder Angelaktivität neu starten
local function ScheduleWeaponRestore()
    weaponRestoreToken = weaponRestoreToken + 1
    local delay = EZFishingDB.weaponRestoreDelay or 0
    if delay <= 0 or not GetSavedWeapons() then return end
    Debug(("Waffen-Rücktausch in %d Sek."):format(delay))
    local token = weaponRestoreToken
    C_Timer.After(delay, function()
        if token == weaponRestoreToken then RestoreWeapons() end
    end)
end

-- Vor jedem Auslösen erneut prüfen; bei Verbot wird der Klick wirkungslos.
-- Die Maus-Prüfungen hat der Doppelklick schon beim Drücken erledigt.
castButton:SetScript("PreClick", function(self, _, down)
    if InCombatLockdown() then return end
    -- Bei der eigenen Taste feuern Drücken und Loslassen: nur beim Drücken auswerfen
    if EZFishingDB.triggerMode == ns.TRIGGER_KEY and not down then
        self:SetAttribute("type", nil)
        return
    end
    if not CanStartFishing(true) then
        self:SetAttribute("type", nil)
        return
    end
    if IsMounted() and EZFishingDB.dismount then
        -- Absitzen über ein Makro, damit es auch geschützt zuverlässig funktioniert
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/dismount")
        return
    end
    local poleID = EZFishingDB.autoEquipPole and GetPoleToEquip()
    if poleID then
        -- Angel anlegen; die nächste Auslösung wirft dann aus
        -- Bereits gemerkte Waffen nicht mit einer anderen Zwischenlösung überschreiben
        if not GetSavedWeapons() then
            RememberWeapons()
        end
        ScheduleWeaponRestore()
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/equip item:" .. poleID)
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(poleID)
        Print(L.POLE_EQUIPPED:format(name or ("item:" .. poleID)))
        return
    end
    self:SetAttribute("type", "spell")
end)

---------------------------------------------------------------------------
-- Eigene Taste: wirft aus bzw. holt während des Angelns den Schwimmer ein
---------------------------------------------------------------------------
local keyFrame = CreateFrame("Frame")

-- fishing: optional bekannter Angelzustand (z. B. aus Kanal-Events)
function UpdateKeyBinding(fishing)
    if InCombatLockdown() then
        pendingKeyUpdate = true
        return
    end
    pendingKeyUpdate = false
    ClearOverrideBindings(keyFrame)

    local key = EZFishingDB.actionKey
    if not (EZFishingDB.enabled and EZFishingDB.triggerMode == ns.TRIGGER_KEY and key) then
        return
    end
    if fishing == nil then
        fishing = IsFishingChanneling()
    end
    if fishing and EZFishingDB.reelIn then
        SetOverrideBinding(keyFrame, true, key, "INTERACTTARGET")
        Debug("Taste " .. key .. ": Einholen")
    else
        SetOverrideBindingClick(keyFrame, true, key, BUTTON_NAME)
        Debug("Taste " .. key .. ": Auswerfen")
    end
end

function ns.SetActionKey(key)
    EZFishingDB.actionKey = key
    UpdateKeyBinding()
    if ns.RefreshKeyButton then
        ns.RefreshKeyButton()
    end
    if key then
        Print(L.KEY_SET:format(GetBindingText(key)))
    else
        Print(L.KEY_CLEARED)
    end
end

---------------------------------------------------------------------------
-- Doppel-Rechtsklick in der Spielwelt erkennen
---------------------------------------------------------------------------
WorldFrame:HookScript("OnMouseDown", function(_, button)
    if button ~= "RightButton" then return end
    if EZFishingDB.triggerMode ~= ns.TRIGGER_DOUBLECLICK then return end

    -- Angel ist draußen: erster Rechtsklick legt "Interagieren" auf die Maustaste,
    -- der zweite Rechtsklick holt dann den Schwimmer ein
    if IsFishingChanneling() then
        lastClickTime = 0
        if reelBindingActive then
            -- Sollte nicht passieren: das Binding hätte den Klick abfangen müssen
            Debug("Zweiter Klick kam nicht bei der Interaktionstaste an")
        elseif EZFishingDB.enabled and EZFishingDB.reelIn and not InCombatLockdown() then
            ArmReelBinding()
            Debug("Einholen bereit")
        end
        return
    end

    local now = GetTime()
    if now - lastClickTime <= DOUBLE_CLICK_TIME then
        lastClickTime = 0
        if CanStartFishing() then
            -- Das Loslassen der rechten Maustaste löst jetzt den Secure Button aus
            SetOverrideBindingClick(castButton, true, "BUTTON2", BUTTON_NAME)
            bindingActive = true
            Debug("Doppel-Rechtsklick erkannt")
            -- Sicherheitsnetz, falls der Klick nicht ankommt
            C_Timer.After(1, ClearCastBinding)
        end
    else
        lastClickTime = now
    end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EZFishingDB = EZFishingDB or {}
        for key, value in pairs(ns.defaults) do
            if EZFishingDB[key] == nil then
                EZFishingDB[key] = value
            end
        end
        -- Ältere Werte (früher bis 300 Sek.) in den Bereich 0–30 in 5er-Schritten bringen
        local step = ns.WEAPON_RESTORE_STEP
        local delay = tonumber(EZFishingDB.weaponRestoreDelay) or ns.defaults.weaponRestoreDelay
        delay = math.floor(delay / step + 0.5) * step
        EZFishingDB.weaponRestoreDelay = math.max(ns.WEAPON_RESTORE_MIN,
            math.min(ns.WEAPON_RESTORE_MAX, delay))
        ns.InitOptions()
        ns.InitMinimapButton()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "SPELLS_CHANGED" then
        -- Neuer Angel-Rang gelernt (Classic) oder Zauberbuch erst jetzt geladen
        ResolveFishingSpell()
    elseif event == "PLAYER_LOGIN" then
        ResolveFishingSpell()
        UpdateSoftInteractCVars()
        UpdateKeyBinding()
        -- Übrig gebliebene Toneinstellungen (z. B. nach /reload beim Angeln) zurücksetzen
        RestoreFishingSound()
        -- Nach /reload mit angelegter Angel: Rücktausch-Timer neu starten
        ScheduleWeaponRestore()
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local spellID = select(2, ...)
        local channelName = UnitChannelInfo("player")
        Debug(("Kanal gestartet: %s (ID %s)"):format(tostring(channelName), tostring(spellID)))
        if IsFishingSpell(spellID, channelName) then
            fishingChannelActive = true
            -- Während des Angelns keine Waffen zurücktauschen
            CancelWeaponRestore()
            -- Eigene Taste auf "Einholen" umschalten
            UpdateKeyBinding(true)
            if EZFishingDB.enabled and EZFishingDB.forceSound then
                soundRestoreToken = soundRestoreToken + 1
                ApplyFishingSound()
                Debug("Angelgeräusche erzwungen")
            end
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        -- Angeln beendet (eingeholt oder abgelaufen): Maustaste freigeben
        ClearReelBinding()
        -- Classic-Clients liefern beim Stopp nicht immer eine erkennbare Spell-ID,
        -- daher zählt auch der beim Start gemerkte Angelzustand
        local stopID = select(2, ...)
        local wasFishing = fishingChannelActive or IsFishingSpell(stopID)
        fishingChannelActive = false
        Debug(("Kanal beendet (ID %s, Angeln: %s)"):format(tostring(stopID), tostring(wasFishing)))
        if wasFishing then
            -- Eigene Taste wieder auf "Auswerfen"
            UpdateKeyBinding(false)
            -- Angelpause beginnt: Waffen nach der eingestellten Zeit zurück
            ScheduleWeaponRestore()
            if EZFishingDB.savedSoundCVars then
                ScheduleSoundRestore()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Feuert kurz vor dem Combat-Lockdown: Bindings noch entfernen,
        -- damit die eigene Taste im Kampf ihre normale Funktion hat
        lastClickTime = 0
        ClearCastBinding()
        ClearReelBinding()
        ClearOverrideBindings(keyFrame)
        pendingKeyUpdate = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Was im Kampf nicht möglich war, jetzt nachholen
        ResolveFishingSpell()
        ClearCastBinding()
        ClearReelBinding()
        if pendingCVarUpdate then
            UpdateSoftInteractCVars()
        end
        if pendingKeyUpdate then
            UpdateKeyBinding()
        end
        if pendingWeaponRestore then
            RestoreWeapons()
        end
    elseif event == "UI_ERROR_MESSAGE" then
        -- arg1 = Fehlertyp, erstes Vararg = lokalisierter Fehlertext
        local message = ...
        if type(message) ~= "string" then return end
        Debug(("Fehlermeldung [%s]: %s"):format(tostring(arg1), message))
        if SPELL_FAILED_NOT_FISHABLE and message == SPELL_FAILED_NOT_FISHABLE then
            lastClickTime = 0
            lockedUntil = GetTime() + EZFishingDB.noWaterLock
            Print(L.NO_WATER:format(EZFishingDB.noWaterLock))
        end
    end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_EZFISHING1 = "/ezf"
SLASH_EZFISHING2 = "/ezfishing"

SlashCmdList.EZFISHING = function(msg)
    msg = strlower(strtrim(msg or ""))
    local cmd, value = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.OpenOptions()
    elseif cmd == "toggle" then
        ns.ToggleEnabled()
    elseif cmd == "reel" then
        ns.SetOption("reelIn", not EZFishingDB.reelIn)
        Print(EZFishingDB.reelIn and L.REEL_ON or L.REEL_OFF)
    elseif cmd == "lock" then
        local seconds = tonumber(value)
        if seconds and seconds >= 0 then
            ns.SetOption("noWaterLock", math.floor(seconds))
            Print(L.LOCK_SET:format(EZFishingDB.noWaterLock))
        else
            Print(L.LOCK_USAGE)
        end
    elseif cmd == "debug" then
        ns.SetOption("debug", not EZFishingDB.debug)
        Print(EZFishingDB.debug and L.DEBUG_ON or L.DEBUG_OFF)
    else
        Print(L.HELP)
    end
end
