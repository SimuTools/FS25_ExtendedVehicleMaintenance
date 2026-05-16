local evmModDir = rawget(_G, "ExtendedVehicleMaintenance_DIR")
if evmModDir == nil or evmModDir == "" then
    evmModDir = g_currentModDirectory
end
if (evmModDir == nil or evmModDir == "") and g_modManager ~= nil and g_currentModName ~= nil and g_modManager.getModByName ~= nil then
    local mod = g_modManager:getModByName(g_currentModName)
    if mod ~= nil then
        evmModDir = mod.modDir
    end
end
if evmModDir ~= nil and evmModDir ~= "" and string.sub(evmModDir, -1) ~= "/" and string.sub(evmModDir, -1) ~= "\\" then
    evmModDir = evmModDir .. "/"
end
if ExtendedVehicleMaintenance ~= nil and rawget(ExtendedVehicleMaintenance, "_initialized") == true then
    return
end

if evmModDir ~= nil and evmModDir ~= "" then
    rawset(_G, "ExtendedVehicleMaintenance_DIR", evmModDir)
    source(evmModDir .. "scripts/events/EVMStartServiceEvent.lua")
    source(evmModDir .. "scripts/gui/EVMServiceDialog.lua")
else
    print("[ExtendedVehicleMaintenance] ERROR Could not resolve mod directory while loading main script")
end

ExtendedVehicleMaintenance = {}
ExtendedVehicleMaintenance.EVM_PATCH_TAG = "v13_service_unlock_drivable_restore"
ExtendedVehicleMaintenance.MOD_NAME = g_currentModName or "FS25_ExtendedVehicleMaintenance"
ExtendedVehicleMaintenance.EVM_PATCH_MARKER = "v21_haendler_repair_button_extra_hooks"
ExtendedVehicleMaintenance.MOD_DIR = evmModDir or g_currentModDirectory or ""
ExtendedVehicleMaintenance.SPEC_NAME = "extendedVehicleMaintenance"
ExtendedVehicleMaintenance.SPEC_TABLE_NAME = "spec_extendedVehicleMaintenance"
ExtendedVehicleMaintenance.ACTION_NAME = "EVM_OPEN_SERVICE"
ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP = 1
ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN = 2
ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR = 3
-- Legacy-Defaults (werden durch loadConfig() überschrieben)
ExtendedVehicleMaintenance.DEFAULT_HOURS = 25
ExtendedVehicleMaintenance.DEFAULT_DAYS = 9999
ExtendedVehicleMaintenance.MAX_HOURS = 25
ExtendedVehicleMaintenance.MAX_DAYS = 9999
-- v22: Wartungsintervall basiert auf den nativen LS-Betriebsstunden.
-- Standard: alle 25 Betriebsstunden, nicht mehr 90h/120h Pool.
ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS = 25
ExtendedVehicleMaintenance.SERVICE_INTERVAL_MS = ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS * 60 * 60 * 1000
ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL = 3500
ExtendedVehicleMaintenance.STALL_LOAD_THRESHOLD = 0.92
ExtendedVehicleMaintenance.GLOBAL_ACTION_UPDATE_INTERVAL = 200
ExtendedVehicleMaintenance.INTERACTION_RADIUS = 4.5
ExtendedVehicleMaintenance.WORKSHOP_COST_FACTOR = 2.2
ExtendedVehicleMaintenance.TECHNICIAN_COST_FACTOR = 3.8
ExtendedVehicleMaintenance.SELF_REPAIR_COST_FACTOR = 0.35
ExtendedVehicleMaintenance.DAMAGE_COST_FACTOR = 2.6
ExtendedVehicleMaintenance.TECHNICIAN_DURATION_FACTOR = 1.25
ExtendedVehicleMaintenance.SELF_REPAIR_DURATION_FACTOR = 5.0
ExtendedVehicleMaintenance.SELF_REPAIR_EXTRA_HOURS = 2.5
ExtendedVehicleMaintenance.workshopPatchesInstalled = false
ExtendedVehicleMaintenance.savegamePathsRegistered = false
ExtendedVehicleMaintenance.dialogRegistered = false
ExtendedVehicleMaintenance.debug = false
ExtendedVehicleMaintenance.COLLISION_DEBUG = false
-- v19: Kollisions-Detection deutlich strenger gegen False-Positives.
-- Ursachen die im Live-Spiel zu Schaden ohne echten Crash gefuehrt haben:
--  1. Teleport-Spikes (Position-Reset bei Einstieg/Resync) -> riesige posSpeed -> Drop-Detection
--  2. Y-Velocity beim Bodenkontakt nach Sprung -> phantom-Geschwindigkeitsabfall
--  3. lowSpeedBump triggerte beim normalen Wenden auf weichem Boden
--  4. Frame-Hänger (>250ms dt) -> dist/dt explodiert
ExtendedVehicleMaintenance.COLLISION_MIN_SPEED_KMH = 8.0
-- Schaden pro Frame max 12% (vorher 18%) - selbst bei echtem Crash kein Reifen-Killer-Schlag
ExtendedVehicleMaintenance.COLLISION_MIN_RELATIVE_DROP = 0.50
ExtendedVehicleMaintenance.COLLISION_DAMAGE_DEBUG = false
ExtendedVehicleMaintenance.COLLISION_MIN_IMPACT_SPEED_KMH = 8.0
ExtendedVehicleMaintenance.COLLISION_MAX_DAMAGE = 0.08
ExtendedVehicleMaintenance.COLLISION_COOLDOWN_MS = 1500
ExtendedVehicleMaintenance.COLLISION_POST_IMPACT_GRACE_MS = 1400
ExtendedVehicleMaintenance.COLLISION_BRAKE_INPUT_SUPPRESSION = true
ExtendedVehicleMaintenance.COLLISION_BRAKE_HISTORY_MS = 1300
-- v19: Neue Sicherheits-Schwellen
ExtendedVehicleMaintenance.COLLISION_TELEPORT_SPEED_KMH = 120 -- ueber dem Wert: Teleport, nicht Crash
ExtendedVehicleMaintenance.COLLISION_MAX_FRAME_DT_MS = 250    -- ueber dem Wert: Frame-Hang ignorieren
ExtendedVehicleMaintenance.COLLISION_INIT_GRACE_MS = 2500     -- nach Spawn/Einstieg keine Detection
ExtendedVehicleMaintenance.COLLISION_MIN_FRAME_DECEL = 75.0   -- vorher 45-55, jetzt strenger
ExtendedVehicleMaintenance.COLLISION_MIN_DROP_KMH = 4.5
ExtendedVehicleMaintenance.COLLISION_STOP_SPEED_KMH = 2.5
ExtendedVehicleMaintenance.COLLISION_POST_IMPACT_LOG_MS = 450
ExtendedVehicleMaintenance.globalWorkshopActionEventId = nil
ExtendedVehicleMaintenance.globalChargeActionEventId = nil
ExtendedVehicleMaintenance.activeSellingPoint = nil
ExtendedVehicleMaintenance.globalWorkshopActionTimer = 0

-- Batterie-Laden: Konfiguration
ExtendedVehicleMaintenance.BATTERY_CHARGE_COST = 5            -- €
ExtendedVehicleMaintenance.BATTERY_CHARGE_DURATION_MIN = 15   -- Echtzeit-Minuten Sperre
ExtendedVehicleMaintenance.BATTERY_CHARGE_THRESHOLD = 0.95    -- Erst unter 95% wird Laden angeboten
ExtendedVehicleMaintenance.clientLockWarningUntil = 0
ExtendedVehicleMaintenance.NEARBY_SERVICE_DISTANCE = 28
ExtendedVehicleMaintenance.ENTER_HINT_DURATION_MS = 6500
ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL = 60000
ExtendedVehicleMaintenance.BREAKDOWN_GLOBAL_UPDATE_INTERVAL = 1000
ExtendedVehicleMaintenance.BREAKDOWN_DEBUG = false
ExtendedVehicleMaintenance.BREAKDOWN_MIN_DAMAGE = 0.45
-- v15: Natuerliche Pannen waren nach dem MP-Fix viel zu aggressiv.
-- Chancen gelten pro Pruefintervall und werden serverseitig fuer alle Fahrzeuge geprueft.
ExtendedVehicleMaintenance.BREAKDOWN_BASE_CHANCE = 0.00025
ExtendedVehicleMaintenance.BREAKDOWN_OVERDUE_CHANCE = 0.006
ExtendedVehicleMaintenance.BREAKDOWN_MAX_CHANCE = 0.012
-- v16: globale & pro-Fahrzeug Cooldowns nach einer Panne deutlich erhoeht, damit nicht
-- direkt nach einer Panne irgendwo das naechste Fahrzeug auch eine Panne bekommt.
ExtendedVehicleMaintenance.BREAKDOWN_MIN_GLOBAL_COOLDOWN = 18 * 60 * 1000
ExtendedVehicleMaintenance.BREAKDOWN_MIN_VEHICLE_COOLDOWN = 75 * 60 * 1000
ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM = 2000
ExtendedVehicleMaintenance._hardLockVehicles = ExtendedVehicleMaintenance._hardLockVehicles or {}
ExtendedVehicleMaintenance._tireEffectStates = ExtendedVehicleMaintenance._tireEffectStates or setmetatable({}, { __mode = "k" })

-- v18: Pannen-Schweregrad-System.
-- MINOR  : leichte Panne, vor Ort selbst behebbar (Ersatzteil/Werkzeug aus Bordkasten)
-- MAJOR  : Standard, wie bisher: Werkstatt / Techniker / Selbst-Reparatur
-- CRITICAL: schwere Panne, nur Werkstatt oder Techniker (Selbst-Reparatur deaktiviert)
ExtendedVehicleMaintenance.SEVERITY_TIER_MINOR    = "minor"
ExtendedVehicleMaintenance.SEVERITY_TIER_MAJOR    = "major"
ExtendedVehicleMaintenance.SEVERITY_TIER_CRITICAL = "critical"
-- Schwellen, die aus dem 0..1 severity-Wert die Stufe bestimmen.
ExtendedVehicleMaintenance.SEVERITY_THRESHOLD_MINOR    = 0.40   -- < 0.40 -> minor
ExtendedVehicleMaintenance.SEVERITY_THRESHOLD_CRITICAL = 0.75   -- >= 0.75 -> critical
-- Quick-Fix Kosten/Dauer: pro Pannentyp ein Materialpreis und eine Reparaturdauer (Echtzeit-ms).
-- Engine ist bewusst NICHT enthalten -- Motorpanne braucht immer Werkstatt egal welcher Tier.
ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS = {
    flatTire      = { cost =  80, durationMs = 180 * 1000, label_de = "Reifen flicken",      label_en = "Patch tire" },
    hydraulicLeak = { cost =  60, durationMs = 150 * 1000, label_de = "Hydraulikleck dichten", label_en = "Seal hydraulics" },
    brakeFault    = { cost = 100, durationMs = 210 * 1000, label_de = "Bremse nachstellen",    label_en = "Adjust brakes" },
    rpmLimit      = { cost =  90, durationMs = 200 * 1000, label_de = "Notlauf zuruecksetzen", label_en = "Reset limp mode" },
}
-- "Weiterfahren mit Reduzierung": Effekt-Staerke wird halbiert fuer X ms, danach wieder voll.
-- Nur fuer MINOR Pannen verfuegbar. Kein Materialpreis, kein Cooldown.
ExtendedVehicleMaintenance.LIMP_HOME_DURATION_MS = 30 * 60 * 1000
ExtendedVehicleMaintenance.LIMP_HOME_SEVERITY_MULT = 0.5

-- Batterie-System helpers are forward-declared because onUpdate/onUpdateTick are defined
-- before the helper implementations further below. Without this Lua would resolve
-- evmGetElectricalLoad as a global/nil inside earlier functions.
local evmGetElectricalLoad
local evmGetAlternatorVoltage
-- v15_battery_debug_sync_restore
local evmProcessBattery
local evmGetEngineOn
ExtendedVehicleMaintenance._vehiclePhysicsHookStates = ExtendedVehicleMaintenance._vehiclePhysicsHookStates or setmetatable({}, { __mode = "k" })
ExtendedVehicleMaintenance._lastNearbyHelpTime = 0

-- Config-System: Fahrzeugkategorien (Standard-Fallback, wird durch loadConfig() befüllt)
ExtendedVehicleMaintenance.vehicleCategories = {
    { name="harvester", hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=1.4, costFactor=1.3 },
    { name="tractor",   hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=1.0, costFactor=1.0 },
    { name="trailer",   hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=0.12,costFactor=0.5 },
    { name="implement", hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=0.25,costFactor=0.6 },
    { name="tool",      hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=0.05,costFactor=0.3 },
    { name="default",   hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=1.0, costFactor=1.0 },
}

-- HUD-Konfiguration (Standard, wird durch loadConfig() überschrieben)
-- Position ist bewusst unten rechts, passend zum Standard-Fahrzeug-HUD.
-- posX/posY werden als rechter/oberer Anker verwendet, damit das HUD nicht in den Tacho läuft.
ExtendedVehicleMaintenance.hudConfig = {
    enabled         = true,
    posX            = 0.993,
    posY            = 0.512,
    scale           = 0.88,
    showOperatingH  = true,
    showNextService = true,
    showWarningLamps= true,
    onlyWhenEntered = true,
}

-- -----------------------------------------------------------------------
-- -----------------------------------------------------------------------
-- Config-Loader
-- Liest evm_config.xml per einfachem Text-Parser (kein Schema nötig).
-- Die Config wird beim ersten Start aus dem Mod-Ordner in den Savegame-
-- Ordner kopiert, damit der Spieler sie dort bequem bearbeiten kann.
-- -----------------------------------------------------------------------
function ExtendedVehicleMaintenance.getConfigPath()
    -- Savegame-Ordner: getUserProfileAppPath() + /modSettings/EVM/
    local base = getUserProfileAppPath and getUserProfileAppPath() or ""
    if base ~= "" and string.sub(base, -1) ~= "/" then base = base .. "/" end
    return base .. "modSettings/FS25_ExtendedVehicleMaintenance/evm_config.xml"
end

function ExtendedVehicleMaintenance.ensureConfigExists()
    local destPath = ExtendedVehicleMaintenance.getConfigPath()
    local srcPath  = ExtendedVehicleMaintenance.MOD_DIR .. "evm_config.xml"

    -- Prüfen ob Zieldatei existiert UND nicht leer ist
    local needsCopy = not fileExists(destPath)
    if not needsCopy and fileExists(destPath) then
        -- Leere Datei erkennen: loadXMLFile schlägt fehl
        local testId = loadXMLFile("evmConfigTest", destPath)
        if testId == nil or testId == 0 then
            needsCopy = true
            print("[EVM] Config-Datei ist leer oder ungültig, wird neu kopiert.")
        else
            delete(testId)
        end
    end

    if not needsCopy then return destPath end

    -- Zielordner anlegen
    local dir = destPath:match("^(.+)[/\\][^/\\]+$")
    if dir then createFolder(dir) end

    -- Template aus Mod-Ordner kopieren
    if fileExists(srcPath) then
        copyFile(srcPath, destPath, true)  -- true = overwrite
        print("[EVM] Config nach " .. destPath .. " kopiert. Dort bearbeiten!")
    else
        print("[EVM] Keine evm_config.xml im Mod-Ordner gefunden, verwende Standardwerte.")
        return nil
    end

    return destPath
end

function ExtendedVehicleMaintenance.loadConfig()
    local cfg = ExtendedVehicleMaintenance
    local path = ExtendedVehicleMaintenance.ensureConfigExists()

    if path == nil or not fileExists(path) then
        print("[EVM] Config nicht gefunden, Standardwerte aktiv.")
        return
    end

    -- FS25 blockiert io.open im Lesemodus.
    -- Wir nutzen das alte Integer-basierte XML-API (loadXMLFile/getXMLString/getXMLFloat etc.)
    -- das KEIN registriertes Schema benötigt.
    local xmlId = loadXMLFile("evmConfig", path)
    if xmlId == nil or xmlId == 0 then
        print("[EVM] Config konnte nicht geladen werden: " .. tostring(path))
        return
    end

    local function getF(key, default)
        local v = getXMLFloat(xmlId, key)
        return (v ~= nil) and v or default
    end
    local function getB(key, default)
        local v = getXMLBool(xmlId, key)
        return (v ~= nil) and v or default
    end
    local function getS(key, default)
        local v = getXMLString(xmlId, key)
        return (v ~= nil and v ~= "") and v or default
    end

    -- Difficulty preset
    local preset = getS("evmConfig.difficulty#preset", "normal")
    local bMult, cMult, iMult = 1.0, 1.0, 1.0
    if preset ~= "custom" then
        local i = 0
        while true do
            local key = string.format("evmConfig.difficultyPresets.preset(%d)", i)
            if not hasXMLProperty(xmlId, key) then break end
            if getS(key .. "#name", "") == preset then
                bMult = getF(key .. "#breakdownMult", 1.0)
                cMult = getF(key .. "#costMult",      1.0)
                iMult = getF(key .. "#intervalMult",  1.0)
                break
            end
            i = i + 1
        end
    end

    -- Breakdown
    local bd = "evmConfig.breakdown"
    cfg.BREAKDOWN_BASE_CHANCE    = getF(bd .. "#baseChance",    0.00025) * bMult
    cfg.BREAKDOWN_MIN_DAMAGE     = getF(bd .. "#minDamage",     0.45)
    cfg.BREAKDOWN_OVERDUE_CHANCE = getF(bd .. "#overdueChance", 0.006)  * bMult
    cfg.BREAKDOWN_MAX_CHANCE     = getF(bd .. "#maxChance",     0.012)
    cfg.BREAKDOWN_CHECK_INTERVAL = getF(bd .. "#checkInterval", 60000)
    cfg.RPM_LIMIT_FAILURE_RPM    = getF(bd .. "#rpmLimitValue", 2000)

    -- v15 Safety-Migration: Alte modSettings-Dateien hatten z.B. 0.008 alle 8 Sekunden.
    -- Das ist im globalen MP-Scanner extrem hoch, weil jedes geladene Fahrzeug separat gewuerfelt wird.
    -- Deshalb werden nur offensichtlich alte/zu aggressive Werte automatisch auf spielbare Werte begrenzt.
    if cfg.BREAKDOWN_CHECK_INTERVAL < 45000 then
        cfg.BREAKDOWN_CHECK_INTERVAL = 60000
    end
    if cfg.BREAKDOWN_BASE_CHANCE > 0.001 then
        cfg.BREAKDOWN_BASE_CHANCE = 0.00025 * bMult
    end
    if cfg.BREAKDOWN_OVERDUE_CHANCE > 0.015 then
        cfg.BREAKDOWN_OVERDUE_CHANCE = 0.006 * bMult
    end
    if cfg.BREAKDOWN_MAX_CHANCE > 0.03 then
        cfg.BREAKDOWN_MAX_CHANCE = 0.012
    end

    -- Costs
    local co = "evmConfig.costs"
    cfg.WORKSHOP_COST_FACTOR    = getF(co .. "#workshopFactor",   2.2)  * cMult
    cfg.TECHNICIAN_COST_FACTOR  = getF(co .. "#technicianFactor", 3.8)  * cMult
    cfg.SELF_REPAIR_COST_FACTOR = getF(co .. "#selfRepairFactor", 0.35) * cMult
    cfg.DAMAGE_COST_FACTOR      = getF(co .. "#damageFactor",     2.6)

    -- Duration
    local du = "evmConfig.duration"
    cfg.TECHNICIAN_DURATION_FACTOR  = getF(du .. "#technicianFactor", 1.25)
    cfg.SELF_REPAIR_DURATION_FACTOR = getF(du .. "#selfRepairFactor", 5.0)
    cfg.SELF_REPAIR_EXTRA_HOURS     = getF(du .. "#selfRepairExtraH", 2.5)

    -- Vehicle categories
    local cats = {}
    local i = 0
    while true do
        local key = string.format("evmConfig.vehicleCategories.category(%d)", i)
        if not hasXMLProperty(xmlId, key) then break end
        local cat = {
            name          = getS(key .. "#name",          "default"),
            hoursInterval = math.min(getF(key .. "#hoursInterval", 25) * iMult, 25),
            daysInterval  = 9999,
            maxHours      = 25,
            maxDays       = 9999,
            breakdownMult = getF(key .. "#breakdownMult", 1.0),
            costFactor    = getF(key .. "#costFactor",    1.0),
            label_de      = getS(key .. "#label_de",      "Fahrzeug"),
            label_en      = getS(key .. "#label_en",      "Vehicle"),
        }
        table.insert(cats, cat)
        i = i + 1
    end
    if #cats > 0 then
        cfg.vehicleCategories = cats
    end

    -- HUD
    local hb = "evmConfig.hud"
    cfg.hudConfig = {
        enabled         = getB(hb .. "#enabled",          true),
        posX            = getF(hb .. "#posX",             0.993),
        posY            = getF(hb .. "#posY",             0.512),
        scale           = getF(hb .. "#scale",            0.88),
        showOperatingH  = getB(hb .. "#showOperatingH",   true),
        showNextService = getB(hb .. "#showNextService",   true),
        showWarningLamps= getB(hb .. "#showWarningLamps",  true),
        onlyWhenEntered = getB(hb .. "#onlyWhenEntered",   true),
    }

    -- Migration fuer alte HUD-Defaults aus modSettings: alte Version sass zu weit oben/rechts und war zu gross.
    if (math.abs((cfg.hudConfig.posX or 0) - 0.955) < 0.001 and math.abs((cfg.hudConfig.posY or 0) - 0.350) < 0.001)
        or (math.abs((cfg.hudConfig.posX or 0) - 0.810) < 0.001 and math.abs((cfg.hudConfig.posY or 0) - 0.315) < 0.001)
        or (math.abs((cfg.hudConfig.posX or 0) - 0.835) < 0.010 and math.abs((cfg.hudConfig.posY or 0) - 0.305) < 0.030) then
        cfg.hudConfig.posX = 0.993
        cfg.hudConfig.posY = 0.512
        cfg.hudConfig.scale = 0.88
    end

    -- v24: alter 0.842/0.300-Default war nur ein Config-Anker, gezeichnet wurde spaeter
    -- hart bei 0.993/0.512. Beim neuen verschiebbaren HUD wuerde die alte Config
    -- sonst sichtbar springen, deshalb einmal sauber migrieren.
    if math.abs((cfg.hudConfig.posX or 0) - 0.842) < 0.010 and math.abs((cfg.hudConfig.posY or 0) - 0.300) < 0.030 then
        cfg.hudConfig.posX = 0.993
        cfg.hudConfig.posY = 0.512
    end

    cfg.hudConfig.scale = math.max(0.55, math.min(1.50, tonumber(cfg.hudConfig.scale or 0.88) or 0.88))
    cfg.hudConfig.posX  = math.max(0.05, math.min(0.995, tonumber(cfg.hudConfig.posX or 0.993) or 0.993))
    cfg.hudConfig.posY  = math.max(0.05, math.min(0.950, tonumber(cfg.hudConfig.posY or 0.512) or 0.512))

    delete(xmlId)
    print(string.format("[EVM] Config geladen: preset=%s breakdown=%.4f workshop=%.2f kategorien=%d | %s",
        preset, cfg.BREAKDOWN_BASE_CHANCE, cfg.WORKSHOP_COST_FACTOR, #cfg.vehicleCategories, path))
end

function ExtendedVehicleMaintenance.clampHudConfig()
    local hud = ExtendedVehicleMaintenance.hudConfig or {}
    hud.scale = math.max(0.55, math.min(1.50, tonumber(hud.scale or 0.88) or 0.88))
    hud.posX  = math.max(0.05, math.min(0.995, tonumber(hud.posX or 0.993) or 0.993))
    hud.posY  = math.max(0.05, math.min(0.950, tonumber(hud.posY or 0.512) or 0.512))
    ExtendedVehicleMaintenance.hudConfig = hud
    return hud
end

function ExtendedVehicleMaintenance.saveHudConfig()
    local path = ExtendedVehicleMaintenance.ensureConfigExists() or ExtendedVehicleMaintenance.getConfigPath()
    if path == nil or path == "" then
        print("[EVM] HUD Config konnte nicht gespeichert werden: kein Pfad")
        return false
    end

    local hud = ExtendedVehicleMaintenance.clampHudConfig()
    local xmlId = loadXMLFile("evmHudConfig", path)
    if xmlId == nil or xmlId == 0 then
        if createXMLFile ~= nil then
            xmlId = createXMLFile("evmHudConfig", path, "evmConfig")
        end
    end
    if xmlId == nil or xmlId == 0 then
        print("[EVM] HUD Config konnte nicht gespeichert werden: XML nicht offen")
        return false
    end

    local hb = "evmConfig.hud"
    setXMLBool(xmlId,  hb .. "#enabled",          hud.enabled ~= false)
    setXMLFloat(xmlId, hb .. "#posX",             hud.posX)
    setXMLFloat(xmlId, hb .. "#posY",             hud.posY)
    setXMLFloat(xmlId, hb .. "#scale",            hud.scale)
    setXMLBool(xmlId,  hb .. "#showOperatingH",   hud.showOperatingH ~= false)
    setXMLBool(xmlId,  hb .. "#showNextService",  hud.showNextService ~= false)
    setXMLBool(xmlId,  hb .. "#showWarningLamps", hud.showWarningLamps ~= false)
    setXMLBool(xmlId,  hb .. "#onlyWhenEntered",  hud.onlyWhenEntered ~= false)

    saveXMLFile(xmlId)
    delete(xmlId)
    print(string.format("[EVM] HUD gespeichert: scale=%.2f posX=%.3f posY=%.3f", hud.scale, hud.posX, hud.posY))
    return true
end

local function evmSetMouseCursorVisible(visible)
    visible = visible == true

    -- setShowMouseCursor allein reicht im Fahrzeug nicht immer aus: die Kamera
    -- bekommt dann weiter die Mausbewegung und der Cursor bleibt praktisch im
    -- Gameplay-Modus. Deshalb versuchen wir zusaetzlich den GUI-Input-Modus zu
    -- aktivieren. Alle Calls sind absichtlich via pcall gekapselt, weil sich die
    -- Giants-API zwischen Patches/Versionen leicht unterscheidet.
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(g_inputBinding.setShowMouseCursor, g_inputBinding, visible)
    elseif InputBinding ~= nil and InputBinding.setShowMouseCursor ~= nil and g_inputBinding ~= nil then
        pcall(InputBinding.setShowMouseCursor, g_inputBinding, visible)
    end

    if FocusManager ~= nil and FocusManager.setGuiInputMode ~= nil then
        pcall(FocusManager.setGuiInputMode, FocusManager, visible)
        pcall(FocusManager.setGuiInputMode, visible)
    end

    if g_gui ~= nil and g_gui.setGuiInputMode ~= nil then
        pcall(g_gui.setGuiInputMode, g_gui, visible)
        pcall(g_gui.setGuiInputMode, visible)
    end

    if g_inputBinding ~= nil and g_inputBinding.setContext ~= nil and InputContext ~= nil then
        if visible then
            ExtendedVehicleMaintenance._hudPrevInputContext = ExtendedVehicleMaintenance._hudPrevInputContext or InputContext.GAMEPLAY
            pcall(g_inputBinding.setContext, g_inputBinding, InputContext.MENU, true)
            pcall(g_inputBinding.setContext, g_inputBinding, InputContext.GUI, true)
        else
            pcall(g_inputBinding.setContext, g_inputBinding, ExtendedVehicleMaintenance._hudPrevInputContext or InputContext.GAMEPLAY, true)
            pcall(g_inputBinding.setContext, g_inputBinding, InputContext.GAMEPLAY, true)
            ExtendedVehicleMaintenance._hudPrevInputContext = nil
        end
    end
end

local function evmMaintainHudEditInput()
    if ExtendedVehicleMaintenance.hudEditMode == true then
        evmSetMouseCursorVisible(true)
    end
end

local function evmGetMouseNorm()
    if getMousePosition == nil then return nil, nil end
    local ok, x, y = pcall(getMousePosition)
    if not ok or x == nil or y == nil then return nil, nil end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    if x > 1 or y > 1 then
        local sw, sh
        if getScreenMode ~= nil then
            local ok2, w, h = pcall(getScreenMode)
            if ok2 then sw, sh = tonumber(w), tonumber(h) end
        end
        if sw ~= nil and sh ~= nil and sw > 0 and sh > 0 then
            x = x / sw
            y = y / sh
        end
    end
    return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

local function evmIsLeftMouseDown()
    if Input ~= nil and Input.isMouseButtonPressed ~= nil then
        local constants = { Input.MOUSE_BUTTON_LEFT, Input.MOUSE_BUTTON_1, 0, 1 }
        for _, c in ipairs(constants) do
            if c ~= nil then
                local ok, pressed = pcall(Input.isMouseButtonPressed, c)
                if ok and pressed then return true end
            end
        end
    end
    if getInputButton ~= nil then
        for _, c in ipairs({0,1}) do
            local ok, pressed = pcall(getInputButton, c)
            if ok and pressed then return true end
        end
    end
    return false
end

function ExtendedVehicleMaintenance.setHudEditMode(active)
    ExtendedVehicleMaintenance.hudEditMode = active == true
    ExtendedVehicleMaintenance._hudDragActive = false
    ExtendedVehicleMaintenance._hudMouseWasDown = false
    -- Standard jetzt: HUD folgt der Maus direkt. Das ist im LS25 deutlich
    -- stabiler als Drag&Drop, weil das Gameplay sonst manchmal die Maus weiter
    -- fuer die Kamera verwendet.
    ExtendedVehicleMaintenance._hudFollowMouse = ExtendedVehicleMaintenance.hudEditMode
    evmSetMouseCursorVisible(ExtendedVehicleMaintenance.hudEditMode)
    if ExtendedVehicleMaintenance.hudEditMode then
        print("[EVM] HUD Edit aktiv: HUD folgt der Maus. Mit evmHudEdit 0 speichern/beenden. Optional: evmHudNudge left/right/up/down.")
    else
        ExtendedVehicleMaintenance._hudFollowMouse = false
        ExtendedVehicleMaintenance.saveHudConfig()
        print("[EVM] HUD Edit beendet.")
    end
end

function ExtendedVehicleMaintenance.updateHudEditMode(baseX, baseY, totalW, totalH)
    if ExtendedVehicleMaintenance.hudEditMode ~= true then return end
    local hud = ExtendedVehicleMaintenance.clampHudConfig()
    local mx, my = evmGetMouseNorm()
    if mx == nil or my == nil then return end

    local down = evmIsLeftMouseDown()

    -- Direkter Follow-Modus: Kein Klick erforderlich. Der Cursor sitzt in der
    -- Mitte des HUDs; evmHudEdit 0 speichert die Position. Dadurch wird das
    -- Problem umgangen, dass der linke Mausklick im Fahrzeug oft weiter an die
    -- Kamera/Gameplay-Steuerung geht.
    if ExtendedVehicleMaintenance._hudFollowMouse == true then
        hud.posX = math.max(totalW + 0.005, math.min(0.995, mx + totalW * 0.5))
        hud.posY = math.max(totalH + 0.005, math.min(0.950, my + totalH * 0.5))
        ExtendedVehicleMaintenance._hudMouseWasDown = down
        return
    end

    local inside = mx >= baseX and mx <= (baseX + totalW) and my >= baseY and my <= (baseY + totalH)
    if down and not ExtendedVehicleMaintenance._hudMouseWasDown then
        if inside then
            ExtendedVehicleMaintenance._hudDragActive = true
            ExtendedVehicleMaintenance._hudDragOffsetX = (baseX + totalW) - mx
            ExtendedVehicleMaintenance._hudDragOffsetY = (baseY + totalH) - my
        end
    elseif not down then
        if ExtendedVehicleMaintenance._hudDragActive then
            ExtendedVehicleMaintenance.saveHudConfig()
        end
        ExtendedVehicleMaintenance._hudDragActive = false
    end

    if ExtendedVehicleMaintenance._hudDragActive then
        hud.posX = math.max(0.05, math.min(0.995, mx + (ExtendedVehicleMaintenance._hudDragOffsetX or 0)))
        hud.posY = math.max(0.05, math.min(0.950, my + (ExtendedVehicleMaintenance._hudDragOffsetY or 0)))
    end
    ExtendedVehicleMaintenance._hudMouseWasDown = down
end

-- -----------------------------------------------------------------------
-- Fahrzeugkategorie-Erkennung
-- -----------------------------------------------------------------------
function ExtendedVehicleMaintenance.getVehicleCategory(vehicle)
    if vehicle == nil then
        return ExtendedVehicleMaintenance.getCategoryByName("default")
    end
    local root = vehicle.rootVehicle or vehicle

    -- Reihenfolge: spezifischste zuerst
    if root.spec_motorized ~= nil and root.spec_combine ~= nil then
        return ExtendedVehicleMaintenance.getCategoryByName("harvester")
    end
    if root.spec_motorized ~= nil then
        return ExtendedVehicleMaintenance.getCategoryByName("tractor")
    end
    if root.spec_trailer ~= nil or root.spec_semitrailer ~= nil then
        return ExtendedVehicleMaintenance.getCategoryByName("trailer")
    end
    if root.spec_workArea ~= nil or (root.spec_attacherJoints ~= nil and root.spec_motorized == nil) then
        return ExtendedVehicleMaintenance.getCategoryByName("implement")
    end
    return ExtendedVehicleMaintenance.getCategoryByName("tool")
end

function ExtendedVehicleMaintenance.getCategoryByName(name)
    for _, cat in ipairs(ExtendedVehicleMaintenance.vehicleCategories) do
        if cat.name == name then return cat end
    end
    -- Fallback: letzte Kategorie (sollte "default" sein)
    return ExtendedVehicleMaintenance.vehicleCategories[#ExtendedVehicleMaintenance.vehicleCategories]
        or { name="default", hoursInterval=25, daysInterval=9999, maxHours=25, maxDays=9999, breakdownMult=1.0, costFactor=1.0 }
end

-- Forward declaration: used by evmGetActiveServiceSpec before the function body is defined later.
local evmGetServiceRemainingMs
local evmGetOperatingTimeMs
local evmGetVehicleName

local function evmDbg(fmt, ...)
    if not ExtendedVehicleMaintenance.debug then
        return
    end
    local ok, msg = pcall(string.format, "[EVM] " .. tostring(fmt), ...)
    if ok then
        print(msg)
    else
        print("[EVM] " .. tostring(fmt))
    end
end

local function evmClamp(value, minValue, maxValue)
    return math.min(math.max(value, minValue), maxValue)
end

local function evmGetDefaultServiceIntervalHours()
    return tonumber(ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS or ExtendedVehicleMaintenance.DEFAULT_HOURS or 25) or 25
end

local function evmGetDefaultServiceIntervalMs()
    return evmGetDefaultServiceIntervalHours() * 60 * 60 * 1000
end

-- v22: Migration fuer alte 90h/120h-Werte.
-- Fahrzeuge ohne echten EVM-Serviceeintrag orientieren sich am nativen LS-operatingTime.
-- Beispiel: 10.1 Bh -> naechster Service in ca. 14.9h, 30.0 Bh -> naechster Takt bei 50h.
local function evmGetOperatingCycleStartMs(currentOperatingTimeMs)
    local intervalMs = evmGetDefaultServiceIntervalMs()
    currentOperatingTimeMs = tonumber(currentOperatingTimeMs) or 0
    if intervalMs <= 0 then
        return 0
    end
    return math.floor(math.max(0, currentOperatingTimeMs) / intervalMs) * intervalMs
end

local function evmMigrateMaintenanceIntervalToOperatingHours(spec, vehicle, reason)
    if spec == nil then return end
    local intervalH = evmGetDefaultServiceIntervalHours()
    local intervalMs = evmGetDefaultServiceIntervalMs()
    local oldPool = tonumber(spec.hoursPool or 0) or 0

    -- Alte Versionen haben 90/120h gespeichert. Diese Werte verhindern, dass der
    -- LS-Betriebsstunden-Takt sichtbar laeuft. Alles deutlich ueber dem neuen
    -- Intervall wird einmalig auf den aktuellen 25h-Zyklus gelegt.
    if oldPool > (intervalH + 0.5) then
        local currentOp = evmGetOperatingTimeMs(vehicle)
        spec.hoursPool = intervalH
        spec.lastServiceOperatingTimeMs = evmGetOperatingCycleStartMs(currentOp)
        spec.daysPool = ExtendedVehicleMaintenance.MAX_DAYS or 9999
        spec.lastServiceGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
        evmDbg("migrated service interval to LS operating hours vehicle=%s reason=%s oldPool=%.2f newPool=%.2f currentBh=%.2f lastServiceBh=%.2f",
            tostring(evmGetVehicleName(vehicle)), tostring(reason or "?"), oldPool, spec.hoursPool,
            (tonumber(currentOp) or 0) / intervalMs * intervalH,
            (tonumber(spec.lastServiceOperatingTimeMs) or 0) / intervalMs * intervalH)
    end
end


local function evmText(key, fallback)
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText(key) then
        local text = g_i18n:getText(key)
        if text ~= nil and text ~= "" then
            return text
        end
    end
    return fallback or key
end

local function evmFormatHoursMinutes(totalGameMs)
    local totalMinutes = math.max(0, math.floor((totalGameMs / (60 * 1000)) + 0.5))
    local hours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60
    return hours, minutes
end

local function evmGetEffectiveTimeScale()
    local mission = g_currentMission
    local timeScale = 1
    if mission ~= nil and mission.missionInfo ~= nil and mission.missionInfo.timeScale ~= nil then
        timeScale = tonumber(mission.missionInfo.timeScale) or 1
    elseif mission ~= nil and mission.environment ~= nil and mission.environment.timeScale ~= nil then
        timeScale = tonumber(mission.environment.timeScale) or 1
    end
    return math.max(1, timeScale)
end

local function evmGameMsToRealMs(gameMs)
    return math.max(0, tonumber(gameMs or 0) or 0) / evmGetEffectiveTimeScale()
end

local function evmRealMsToGameMs(realMs)
    return math.max(0, tonumber(realMs or 0) or 0) * evmGetEffectiveTimeScale()
end

local function evmIsValidNode(node)
    return type(node) == "number" and node ~= 0 and entityExists(node)
end

local function evmGetWorldPosition(node)
    if not evmIsValidNode(node) then
        return nil, nil, nil
    end
    return getWorldTranslation(node)
end

local function evmDistanceSq(nodeA, nodeB)
    local ax, ay, az = evmGetWorldPosition(nodeA)
    local bx, by, bz = evmGetWorldPosition(nodeB)
    if ax == nil or bx == nil then
        return math.huge
    end
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return dx * dx + dy * dy + dz * dz
end

local function evmGetVehicleDamage(vehicle)
    if vehicle == nil then
        return 0
    end
    if vehicle.getDamageAmount ~= nil then
        return math.max(0, vehicle:getDamageAmount() or 0)
    end
    if vehicle.spec_wearable ~= nil and vehicle.spec_wearable.damage ~= nil then
        return math.max(0, vehicle.spec_wearable.damage)
    end
    return 0
end

local function evmGetVehiclePrice(vehicle)
    if vehicle == nil then
        return 10000
    end
    local basePrice = 10000
    if vehicle.getPrice ~= nil then
        basePrice = math.max(basePrice, vehicle:getPrice() or basePrice)
    elseif vehicle.price ~= nil then
        basePrice = math.max(basePrice, vehicle.price)
    end
    return basePrice
end

evmGetOperatingTimeMs = function(vehicle)
    if vehicle == nil then
        return 0
    end
    -- Motorisierte Fahrzeuge: native getOperatingTime
    if vehicle.getOperatingTime ~= nil then
        return vehicle:getOperatingTime() or 0
    end
    -- Geräte/Anhänger: operatingTime direkt oder über spec_wearable
    if vehicle.operatingTime ~= nil then
        return vehicle.operatingTime
    end
    -- spec_wearable hat bei manchen Implements operatingTime
    if vehicle.spec_wearable ~= nil and vehicle.spec_wearable.operatingTime ~= nil then
        return vehicle.spec_wearable.operatingTime
    end
    return 0
end


evmGetVehicleName = function(vehicle)
    if vehicle == nil then
        return "-"
    end
    if vehicle.getName ~= nil then
        local ok, result = pcall(vehicle.getName, vehicle)
        if ok and result ~= nil and tostring(result) ~= "" then
            return tostring(result)
        end
    end
    if vehicle.getFullName ~= nil then
        local ok, result = pcall(vehicle.getFullName, vehicle)
        if ok and result ~= nil and tostring(result) ~= "" then
            return tostring(result)
        end
    end
    if vehicle.configFileName ~= nil then
        local fileName = tostring(vehicle.configFileName)
        fileName = fileName:gsub("\\", "/")
        fileName = fileName:match("([^/]+)%.xml$") or fileName
        if fileName ~= nil and fileName ~= "" then
            return fileName
        end
    end
    return tostring(vehicle.typeName or vehicle.xmlFileName or vehicle.rootNode or "Vehicle")
end

local function evmGetVehicleLabel(vehicle)
    if type(vehicle) ~= "table" then
        return tostring(vehicle)
    end
    return evmGetVehicleName(vehicle)
end

local function evmGetVehicleSpec(vehicle)
    if vehicle == nil then
        return nil
    end
    return vehicle[ExtendedVehicleMaintenance.SPEC_TABLE_NAME]
end

local function evmCreateRuntimeSpec(vehicle)
    if vehicle == nil then
        return nil
    end

    local spec = vehicle[ExtendedVehicleMaintenance.SPEC_TABLE_NAME]
    if spec ~= nil then
        return spec
    end

    spec = {}
    vehicle[ExtendedVehicleMaintenance.SPEC_TABLE_NAME] = spec

    local nowGame = 0
    if ExtendedVehicleMaintenance ~= nil and ExtendedVehicleMaintenance.getCurrentGameTimeMs ~= nil then
        nowGame = ExtendedVehicleMaintenance.getCurrentGameTimeMs() or 0
    end

    local dirtyFlag = 0
    if vehicle.getNextDirtyFlag ~= nil then
        local ok, flag = pcall(vehicle.getNextDirtyFlag, vehicle)
        if ok and flag ~= nil then
            dirtyFlag = flag
        end
    end

    spec.dirtyFlag = dirtyFlag
    -- Kategorie-basierte Standardwerte
    local cat = ExtendedVehicleMaintenance.getVehicleCategory(vehicle)
    spec.hoursPool = ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS or ExtendedVehicleMaintenance.DEFAULT_HOURS or 25
    spec.daysPool  = ExtendedVehicleMaintenance.MAX_DAYS or ExtendedVehicleMaintenance.DEFAULT_DAYS or 9999
    spec.lastServiceOperatingTimeMs = 0
    spec.lastServiceGameTimeMs = nowGame
    spec.serviceRemainingGameMs = 0
    spec.serviceEndAbsHours = 0
    spec.serviceHoursToAdd = 0
    spec.serviceDaysToAdd = 0
    spec.serviceMode = 0
    spec.isServiceActive = false
    spec.lastTickGameTimeMs = nowGame
    spec.stallTimer = ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL or 3500
    spec.actionEvents = {}
    spec.physicsFrozen = false
    spec.debugTimer = 0
    spec.failureType = ""
    spec.failureSeverity = 0
    spec.failureWheelIndex = 0
    spec.failureDriftDirection = 0
    spec.engineFailureTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL or 60000
    spec.breakdownTimer = (ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL or 60000) + math.random(0, 30000)
    -- v16: Frische Fahrzeuge bekommen einen großzügigen Grace-Window. Die alten 10–25 Min
    -- waren bei 1×-Time-Scale viel zu kurz und führten zu Pannen kurz nach Spielstart bzw.
    -- direkt nach dem Kauf eines neuen Fahrzeugs.
    -- Wir staffeln nach Kategorie: motorisierte Fahrzeuge mehr Grace, Anhänger/Tools weniger,
    -- weil dort eh nur kleine Pannen (Reifen) möglich sind.
    local _cat = ExtendedVehicleMaintenance.getVehicleCategory(vehicle)
    local _initialGraceMs
    if _cat ~= nil and (_cat.name == "harvester" or _cat.name == "tractor") then
        _initialGraceMs = math.random(45 * 60 * 1000, 75 * 60 * 1000)
    elseif _cat ~= nil and (_cat.name == "implement" or _cat.name == "trailer" or _cat.name == "tool") then
        _initialGraceMs = math.random(25 * 60 * 1000, 45 * 60 * 1000)
    else
        _initialGraceMs = math.random(35 * 60 * 1000, 60 * 60 * 1000)
    end
    spec.nextNaturalBreakdownAllowedTime = (g_time or 0) + _initialGraceMs
    spec.enterHintUntil = 0
    spec.wasEntered = false
    spec.failureWarnUntil = 0
    -- MP-Fix: Preserve battery state if it was already set by an event before this runtime spec creation.
    if tonumber(spec.batteryCharge) == nil then spec.batteryCharge = 1.0 end
    if tonumber(spec.batteryVoltage) == nil then spec.batteryVoltage = 12.7 end
    spec.batteryVoltageTimer = 0
    spec._runtimeCreated = true

    return spec
end

local function evmGetPersistDir()
    -- Bevorzuge den Savegame-Ordner des aktuellen Spielstands.
    -- Vorteile: pro Savegame getrennt, im MP schreibt nur der Server dort,
    -- keine Konflikte zwischen verschiedenen Savegame-Slots.
    local saveDir = nil
    if g_currentMission ~= nil then
        local mi = g_currentMission.missionInfo
        if mi ~= nil then
            saveDir = mi.savegameDirectory or mi.savegamePath or mi.savegameDir
        end
        if saveDir == nil then
            saveDir = g_currentMission.savegameDirectory or g_currentMission.savegameDir
        end
    end

    if saveDir ~= nil and saveDir ~= "" then
        -- Savegame-Ordner direkt nutzen (kein Unterordner nötig)
        if string.sub(saveDir, -1) ~= "/" and string.sub(saveDir, -1) ~= "\\" then
            saveDir = saveDir .. "/"
        end
        -- Ordner anlegen falls nicht vorhanden (sollte eigentlich existieren)
        if createFolder ~= nil then
            pcall(createFolder, saveDir)
        end
        -- Pfad ohne abschließenden Slash zurückgeben (wie bisher)
        return string.sub(saveDir, 1, -2)
    end

    -- Fallback: modSettings (SP ohne geladenes Savegame, Dedi-Server-Edge-Cases)
    local basePath = nil
    if getUserProfileAppPath ~= nil then
        basePath = getUserProfileAppPath()
    end
    if basePath == nil or basePath == "" then
        basePath = ""
    end
    if basePath ~= "" and string.sub(basePath, -1) ~= "/" and string.sub(basePath, -1) ~= "\\" then
        basePath = basePath .. "/"
    end
    local dir = basePath .. "modSettings/FS25_ExtendedVehicleMaintenance"
    if createFolder ~= nil then
        pcall(createFolder, basePath .. "modSettings")
        pcall(createFolder, dir)
    end
    return dir
end

local function evmGetPersistFileName()
    return evmGetPersistDir() .. "/evm_resetPersist.xml"
end

local function evmGetOwnerFarmIdSafe(vehicle)
    if vehicle ~= nil and vehicle.getOwnerFarmId ~= nil then
        local ok, farmId = pcall(vehicle.getOwnerFarmId, vehicle)
        if ok then
            return tonumber(farmId) or 0
        end
    end
    return 0
end

local function evmVehicleMatchesPersist(vehicle, data)
    if vehicle == nil or data == nil then
        return false
    end

    local configFileName = tostring(vehicle.configFileName or "")
    local xmlFileName = tostring(vehicle.xmlFileName or "")
    local typeName = tostring(vehicle.typeName or "")
    local name = tostring(evmGetVehicleName(vehicle) or "")
    local ownerFarmId = evmGetOwnerFarmIdSafe(vehicle)

    -- rootNode ist bei resetVehicle() im MP NICHT stabil.
    -- Gleiche rootNode darf sofort matchen, unterschiedliche rootNode darf
    -- aber nicht hart ablehnen, weil das Werkstatt-Reset das Vehicle neu
    -- streamen/erzeugen kann. Sonst bleibt der Service am alten Objekt haengen.
    if data.rootNode ~= nil and vehicle.rootNode ~= nil and data.rootNode == vehicle.rootNode then
        return true
    end

    -- Leere Strings in data sind KEINE Wildcards – sie bedeuten "unbekannt".
    -- Nur matchen wenn data einen echten Wert hat UND er übereinstimmt.
    local configMatch = (data.configFileName ~= nil and data.configFileName ~= "")
        and data.configFileName == configFileName
    local xmlMatch = (data.xmlFileName ~= nil and data.xmlFileName ~= "")
        and data.xmlFileName == xmlFileName
    local typeMatch = (data.typeName ~= nil and data.typeName ~= "")
        and data.typeName == typeName
    local nameMatch = (data.name ~= nil and data.name ~= "")
        and data.name == name
    local ownerMatch = tonumber(data.ownerFarmId or 0) == 0
        or tonumber(data.ownerFarmId or 0) == ownerFarmId

    -- Mindestens configFileName ODER (xmlFileName UND typeName) muss matchen
    local hasStrongId = configMatch or (xmlMatch and typeMatch)
    if not hasStrongId then
        -- Fallback: typeName + name wenn nichts anderes vorhanden
        hasStrongId = typeMatch and nameMatch
    end

    return hasStrongId and ownerMatch
end


local function evmBuildPersistRuntimeData(vehicle, serviceMode, durationMs, hoursAdded, daysAdded)
    local rootVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if rootVehicle == nil then
        return nil
    end

    return {
        pending = true,
        rootNode = rootVehicle.rootNode,
        configFileName = tostring(rootVehicle.configFileName or ""),
        xmlFileName = tostring(rootVehicle.xmlFileName or ""),
        typeName = tostring(rootVehicle.typeName or ""),
        name = tostring(evmGetVehicleName(rootVehicle) or ""),
        ownerFarmId = evmGetOwnerFarmIdSafe(rootVehicle),
        operatingTimeMs = evmGetOperatingTimeMs(rootVehicle) or 0,
        serviceMode = tonumber(serviceMode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP,
        serviceRemainingGameMs = math.max(0, tonumber(durationMs) or 0),
        serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (math.max(0, tonumber(durationMs) or 0) / 3600000),
        serviceHoursToAdd = math.max(0, tonumber(hoursAdded) or 0),
        serviceDaysToAdd = math.max(0, tonumber(daysAdded) or 0),
        serviceStartRealMs = g_time or 0,
        serviceEndRealMs = (g_time or 0) + evmGameMsToRealMs(durationMs),
        writtenAt = tonumber(g_time) or 0
    }
end

function ExtendedVehicleMaintenance.evmWritePersist(vehicle, serviceMode, durationMs, hoursAdded, daysAdded)
    if vehicle == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local fileName = evmGetPersistFileName()
    local key = "extendedVehicleMaintenanceResetPersist.vehicle"

    -- Avoid XMLFile:setValue without schema here; FS25 logs "Unable to get schema"
    -- for every value. The old XML helpers are fine for this small modSettings bridge.
    if createXMLFile ~= nil and saveXMLFile ~= nil then
        local xmlId = createXMLFile("evmResetPersist", fileName, "extendedVehicleMaintenanceResetPersist")
        if xmlId ~= nil and xmlId ~= 0 then
            setXMLBool(xmlId, key .. "#pending", true)
            setXMLString(xmlId, key .. "#configFileName", tostring(rootVehicle.configFileName or ""))
            setXMLString(xmlId, key .. "#xmlFileName", tostring(rootVehicle.xmlFileName or ""))
            setXMLString(xmlId, key .. "#typeName", tostring(rootVehicle.typeName or ""))
            setXMLString(xmlId, key .. "#name", tostring(evmGetVehicleName(rootVehicle) or ""))
            setXMLInt(xmlId, key .. "#ownerFarmId", tonumber(evmGetOwnerFarmIdSafe(rootVehicle)) or 0)
            setXMLFloat(xmlId, key .. "#operatingTimeMs", tonumber(evmGetOperatingTimeMs(rootVehicle)) or 0)
            setXMLInt(xmlId, key .. "#serviceMode", tonumber(serviceMode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
            setXMLFloat(xmlId, key .. "#serviceRemainingGameMs", math.max(0, tonumber(durationMs) or 0))
            setXMLFloat(xmlId, key .. "#serviceEndAbsHours", ExtendedVehicleMaintenance.getCurrentAbsHours() + (math.max(0, tonumber(durationMs) or 0) / 3600000))
            setXMLFloat(xmlId, key .. "#serviceHoursToAdd", math.max(0, tonumber(hoursAdded) or 0))
            setXMLFloat(xmlId, key .. "#serviceDaysToAdd", math.max(0, tonumber(daysAdded) or 0))
            setXMLFloat(xmlId, key .. "#writtenAt", tonumber(g_time) or 0)

            local okSave = pcall(function()
                saveXMLFile(xmlId)
                delete(xmlId)
            end)

            evmDbg("evmWritePersist vehicle=%s ok=%s file=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(okSave), tostring(fileName))
            return okSave == true
        end
    end

    evmDbg("evmWritePersist failed create file=%s", tostring(fileName))
    return false
end

function ExtendedVehicleMaintenance.evmReadPersist(vehicle)
    if vehicle == nil then
        return nil
    end

    local fileName = evmGetPersistFileName()
    if fileExists ~= nil and not fileExists(fileName) then
        return nil
    end
    if loadXMLFile == nil then
        return nil
    end

    local xmlId = loadXMLFile("evmResetPersist", fileName)
    if xmlId == nil or xmlId == 0 then
        return nil
    end

    local key = "extendedVehicleMaintenanceResetPersist.vehicle"
    local pending = getXMLBool(xmlId, key .. "#pending")
    if pending ~= true then
        delete(xmlId)
        return nil
    end

    local data = {
        configFileName = getXMLString(xmlId, key .. "#configFileName") or "",
        xmlFileName = getXMLString(xmlId, key .. "#xmlFileName") or "",
        typeName = getXMLString(xmlId, key .. "#typeName") or "",
        name = getXMLString(xmlId, key .. "#name") or "",
        ownerFarmId = getXMLInt(xmlId, key .. "#ownerFarmId") or 0,
        operatingTimeMs = getXMLFloat(xmlId, key .. "#operatingTimeMs"),
        serviceMode = getXMLInt(xmlId, key .. "#serviceMode") or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP,
        serviceRemainingGameMs = getXMLFloat(xmlId, key .. "#serviceRemainingGameMs") or 0,
        serviceEndAbsHours = getXMLFloat(xmlId, key .. "#serviceEndAbsHours") or 0,
        serviceHoursToAdd = getXMLFloat(xmlId, key .. "#serviceHoursToAdd") or 0,
        serviceDaysToAdd = getXMLFloat(xmlId, key .. "#serviceDaysToAdd") or 0
    }

    delete(xmlId)

    if not evmVehicleMatchesPersist(vehicle.rootVehicle or vehicle, data) then
        return nil
    end

    return data
end

function ExtendedVehicleMaintenance.evmClearPersist(vehicle)
    local fileName = evmGetPersistFileName()
    if fileExists ~= nil and not fileExists(fileName) then
        return false
    end
    if loadXMLFile == nil then
        return false
    end

    local xmlId = loadXMLFile("evmResetPersist", fileName)
    if xmlId == nil or xmlId == 0 then
        return false
    end

    local key = "extendedVehicleMaintenanceResetPersist.vehicle"
    local shouldClear = vehicle == nil

    if not shouldClear then
        local data = {
            configFileName = getXMLString(xmlId, key .. "#configFileName") or "",
            xmlFileName = getXMLString(xmlId, key .. "#xmlFileName") or "",
            typeName = getXMLString(xmlId, key .. "#typeName") or "",
            name = getXMLString(xmlId, key .. "#name") or "",
            ownerFarmId = getXMLInt(xmlId, key .. "#ownerFarmId") or 0,
            operatingTimeMs = getXMLFloat(xmlId, key .. "#operatingTimeMs")
        }
        shouldClear = evmVehicleMatchesPersist(vehicle.rootVehicle or vehicle, data)
    end

    if shouldClear then
        setXMLBool(xmlId, key .. "#pending", false)
        pcall(function()
            saveXMLFile(xmlId)
            delete(xmlId)
        end)
        evmDbg("evmClearPersist vehicle=%s file=%s", tostring(vehicle ~= nil and evmGetVehicleName(vehicle.rootVehicle or vehicle) or "all"), tostring(fileName))
        return true
    end

    delete(xmlId)
    return false
end

-- BUGFIX (zwei identische Trecker): Strikte Objekt-Identitaets-Pruefung,
-- ob ein konkretes Vehicle aktuell tatsaechlich das laufende Service-Fahrzeug ist.
-- evmVehicleMatchesPersist matcht zwei identische Trecker (gleicher configFileName,
-- gleicher ownerFarmId) als "gleich" und sperrt dadurch faelschlicherweise auch
-- den zweiten, baugleichen Trecker. Deshalb hier zuerst harte Objekt-Identitaet
-- pruefen und nur als Fallback (wenn das Service-Vehicle noch nicht aufgeloest
-- wurde, z.B. unmittelbar nach Workshop-Reset) den schwachen Match per Persist-Daten
-- zulassen - aber dann nur, wenn das ORIGINAL-Vehicle nicht mehr existiert.
local function evmIsRuntimeServiceVehicle(vehicle, runtime)
    if vehicle == nil or runtime == nil or runtime.active ~= true then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    -- 1. Harte Objekt-Identitaet mit dem aktuell aufgeloesten Service-Vehicle
    if runtime.rootVehicle ~= nil then
        local rtRoot = runtime.rootVehicle.rootVehicle or runtime.rootVehicle
        if rtRoot == rootVehicle then
            return true
        end
    end

    -- 2. Im targets-Array enthalten (Mehrziel-Service)?
    if runtime.targets ~= nil then
        for i = 1, #runtime.targets do
            local t = runtime.targets[i]
            if t ~= nil then
                local tRoot = t.rootVehicle or t
                if tRoot == rootVehicle then
                    return true
                end
            end
        end
    end

    -- 3. Pre-Resolve-Phase: rootNode entspricht dem urspruenglichen Service-Vehicle
    --    (z.B. direkt nach tryStartService bevor enforceRuntimePersistLock lief)
    if runtime.pendingLockData ~= nil and rootVehicle.rootNode ~= nil then
        if runtime.pendingLockData.rootNode ~= nil and runtime.pendingLockData.rootNode == rootVehicle.rootNode then
            return true
        end
        if runtime.pendingOldRootNode ~= nil and runtime.pendingOldRootNode == rootVehicle.rootNode then
            return true
        end
    end

    -- 4. Letzter Fallback: schwacher Persist-Match per configFileName/ownerFarmId,
    --    aber NUR wenn das Original-Vehicle (data.rootNode) nicht mehr existiert.
    --    Damit bleibt der Lock auch nach Workshop-Reset auf dem neu erzeugten Objekt
    --    haengen, faengt aber nicht den zweiten baugleichen Trecker mit ein.
    if runtime.pendingLockData ~= nil and evmVehicleMatchesPersist(rootVehicle, runtime.pendingLockData) then
        local origRootNode = runtime.pendingLockData.rootNode or runtime.pendingOldRootNode
        if origRootNode == nil or not evmIsValidNode(origRootNode) then
            return true
        end
        -- origRootNode ist noch ein gueltiger Node -> Original lebt noch.
        -- In diesem Fall darf der schwache Match KEIN anderes Fahrzeug als
        -- "Service-Vehicle" markieren.
        return false
    end

    return false
end

local function evmGetActiveServiceSpec(vehicle)
    if vehicle == nil then
        return nil, nil
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    -- BUGFIX (zwei identische Trecker / "Motor startet nicht nach Service-Ende"):
    -- Selbstheilung fuer Specs, in denen frueheres Verhalten faelschlich
    -- isServiceActive=true gesetzt hat (zweiter baugleicher Trecker). Wenn die Spec
    -- meldet "Service aktiv", aber GLOBAL kein Service laeuft (oder dieses Fahrzeug
    -- gar nicht Teil des aktuellen Service ist) UND keine Restzeit mehr da ist,
    -- raeumen wir die spec hier auf, statt das Fahrzeug dauerhaft gesperrt zu lassen.
    local function isSpecOrphaned(s)
        if s == nil or s.isServiceActive ~= true then return false end
        local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
        local belongsToActiveRuntime = rt ~= nil and rt.active == true
            and evmIsRuntimeServiceVehicle(rootVehicle, rt)
        if belongsToActiveRuntime then return false end
        -- Kein laufender Service fuer dieses Fahrzeug: Spec sollte nicht aktiv sein.
        local remainingMs = tonumber(s.serviceRemainingGameMs or 0) or 0
        local endAbsHours = tonumber(s.serviceEndAbsHours or 0) or 0
        local absRemaining = endAbsHours > 0 and ((endAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000) or 0
        if remainingMs <= 0 and absRemaining <= 0 then
            return true
        end
        return false
    end

    local function clearOrphanedSpec(s)
        s.isServiceActive = false
        s.serviceMode = 0
        s.serviceRemainingGameMs = 0
        s.serviceEndAbsHours = 0
        s.serviceHoursToAdd = 0
        s.serviceDaysToAdd = 0
        s.physicsFrozen = false
        if rootVehicle.raiseDirtyFlags ~= nil and s.dirtyFlag ~= nil then
            pcall(rootVehicle.raiseDirtyFlags, rootVehicle, s.dirtyFlag)
        end
        evmDbg("evmGetActiveServiceSpec cleared orphaned isServiceActive flag vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))
    end

    local rootSpec = evmGetVehicleSpec(rootVehicle)
    if rootSpec ~= nil and rootSpec.isServiceActive then
        if isSpecOrphaned(rootSpec) then
            clearOrphanedSpec(rootSpec)
        else
            return rootSpec, rootVehicle
        end
    end

    local spec = evmGetVehicleSpec(vehicle)
    if spec ~= nil and spec.isServiceActive then
        if isSpecOrphaned(spec) then
            clearOrphanedSpec(spec)
        else
            return spec, vehicle
        end
    end

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    -- BUGFIX (zwei identische Trecker / "kein Motorstart nach Service-Ende"):
    -- Frueher wurde hier ueber evmVehicleMatchesPersist gematched - das ist nur ein
    -- schwacher configFileName/ownerFarmId-Vergleich und matcht ZWEI baugleiche Trecker
    -- des gleichen Spielers gleichermassen. Dadurch bekam der zweite Trecker:
    --   1. faelschlich isServiceActive=true gesetzt (-> war auch gesperrt)
    --   2. dieser Wert wurde in seine eigene Spec persistiert -> blieb auch nach
    --      Service-Ende gesetzt (-> Motor ging nicht mehr an, erst nach Reset).
    -- Loesung: strikt per Objekt-Identitaet pruefen.
    if runtime ~= nil and runtime.active == true and runtime.pendingLockData ~= nil and evmIsRuntimeServiceVehicle(rootVehicle, runtime) then
        local pendingRemainingMs = math.max(0, tonumber(runtime.pendingLockData.serviceRemainingGameMs or runtime.totalDurationMs or 0) or 0)
        if (runtime.pendingLockData.serviceEndAbsHours or 0) > 0 then
            pendingRemainingMs = math.max(0, (runtime.pendingLockData.serviceEndAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
        end

        local runtimeSpec = evmGetVehicleSpec(rootVehicle)
        if runtimeSpec ~= nil then
            runtimeSpec.isServiceActive = true
            runtimeSpec.serviceMode = runtime.pendingLockData.serviceMode or runtime.mode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
            runtimeSpec.serviceEndAbsHours = runtime.pendingLockData.serviceEndAbsHours or runtimeSpec.serviceEndAbsHours or 0
            local currentRemainingMs = tonumber(runtimeSpec.serviceRemainingGameMs or 0) or 0
            if currentRemainingMs <= 0 then
                runtimeSpec.serviceRemainingGameMs = pendingRemainingMs
            else
                runtimeSpec.serviceRemainingGameMs = math.min(currentRemainingMs, pendingRemainingMs)
            end
            runtimeSpec.serviceHoursToAdd = math.max(runtimeSpec.serviceHoursToAdd or 0, runtime.pendingLockData.serviceHoursToAdd or 0)
            runtimeSpec.serviceDaysToAdd = math.max(runtimeSpec.serviceDaysToAdd or 0, runtime.pendingLockData.serviceDaysToAdd or 0)
            runtimeSpec.physicsFrozen = true
            return runtimeSpec, rootVehicle
        end

        runtime.syntheticLockSpec = runtime.syntheticLockSpec or { isServiceActive = true }
        runtime.syntheticLockSpec.isServiceActive = true
        runtime.syntheticLockSpec.serviceMode = runtime.pendingLockData.serviceMode or runtime.mode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
        runtime.syntheticLockSpec.serviceEndAbsHours = runtime.pendingLockData.serviceEndAbsHours or 0
        runtime.syntheticLockSpec.serviceRemainingGameMs = pendingRemainingMs
        runtime.syntheticLockSpec.serviceHoursToAdd = runtime.pendingLockData.serviceHoursToAdd or 0
        runtime.syntheticLockSpec.serviceDaysToAdd = runtime.pendingLockData.serviceDaysToAdd or 0
        return runtime.syntheticLockSpec, rootVehicle
    end

    return nil, nil
end

function ExtendedVehicleMaintenance.getRuntime()
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime == nil then
        runtime = {
            enterLocks = {},
            _serviceWatchers = {}
        }
        ExtendedVehicleMaintenance.spec_serviceRuntime = runtime
    else
        runtime.enterLocks = runtime.enterLocks or {}
        runtime._serviceWatchers = runtime._serviceWatchers or {}
    end
    return runtime
end

function ExtendedVehicleMaintenance.restoreRuntimeHooks()
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime == nil then
        return
    end

    if runtime._origRequestToEnterVehicle ~= nil and g_localPlayer ~= nil then
        g_localPlayer.requestToEnterVehicle = runtime._origRequestToEnterVehicle
        runtime._origRequestToEnterVehicle = nil
    end

    if runtime._origLocalPlayerSetCurrentVehicle ~= nil and g_localPlayer ~= nil then
        g_localPlayer.setCurrentVehicle = runtime._origLocalPlayerSetCurrentVehicle
        runtime._origLocalPlayerSetCurrentVehicle = nil
    end

    if runtime._origMissionRequestToEnterVehicle ~= nil and g_currentMission ~= nil then
        g_currentMission.requestToEnterVehicle = runtime._origMissionRequestToEnterVehicle
        runtime._origMissionRequestToEnterVehicle = nil
    end

    if runtime._origMissionEnterVehicle ~= nil and g_currentMission ~= nil then
        g_currentMission.enterVehicle = runtime._origMissionEnterVehicle
        runtime._origMissionEnterVehicle = nil
    end

    if runtime._origMissionSetControlledVehicle ~= nil and g_currentMission ~= nil then
        g_currentMission.setControlledVehicle = runtime._origMissionSetControlledVehicle
        runtime._origMissionSetControlledVehicle = nil
    end

    if runtime._origMissionUpdate ~= nil and g_currentMission ~= nil then
        g_currentMission.update = runtime._origMissionUpdate
        runtime._origMissionUpdate = nil
    end

    runtime._enterLockUpdateInstalled = false
end

local function evmNormalizeVehicle(vehicle)
    if type(vehicle) ~= "table" then
        return nil
    end
    return vehicle.rootVehicle or vehicle
end

local evmIsLockedForInput

local function evmFindVehicleInArgs(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "table" then
            local root = value.rootVehicle or value
            if root ~= nil and root.rootNode ~= nil and (root.spec_enterable ~= nil or root.spec_motorized ~= nil or root.spec_drivable ~= nil) then
                return root
            end
        end
    end
    return nil
end

local function evmHasMaintenanceSpec(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    return rootVehicle ~= nil and evmGetVehicleSpec(rootVehicle) ~= nil
end

local function evmGetPlayerReferenceNode()
    local mission = g_currentMission
    if ExtendedVehicleMaintenance.getPlayerRootNode ~= nil then
        local node = ExtendedVehicleMaintenance.getPlayerRootNode()
        if evmIsValidNode(node) then
            return node
        end
    end
    if mission ~= nil and mission.player ~= nil and evmIsValidNode(mission.player.rootNode) then
        return mission.player.rootNode
    end
    if g_localPlayer ~= nil and evmIsValidNode(g_localPlayer.rootNode) then
        return g_localPlayer.rootNode
    end
    return nil
end

local function evmCollectMissionVehicles()
    local mission = g_currentMission
    local list = {}
    local seen = {}
    local function add(vehicle)
        local rootVehicle = evmNormalizeVehicle(vehicle)
        if rootVehicle ~= nil and rootVehicle.rootNode ~= nil and not seen[rootVehicle] then
            seen[rootVehicle] = true
            table.insert(list, rootVehicle)
        end
    end
    if mission ~= nil then
        if mission.vehicles ~= nil then
            for _, vehicle in ipairs(mission.vehicles) do add(vehicle) end
        end
        if mission.vehicleSystem ~= nil then
            if mission.vehicleSystem.vehicles ~= nil then
                for _, vehicle in pairs(mission.vehicleSystem.vehicles) do add(vehicle) end
            end
            if mission.vehicleSystem.vehicleIdToVehicle ~= nil then
                for _, vehicle in pairs(mission.vehicleSystem.vehicleIdToVehicle) do add(vehicle) end
            end
        end
    end
    return list
end

local function evmCanTabToVehicle(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    if rootVehicle == nil or rootVehicle.rootNode == nil then return false end
    -- Fahrzeuge die in Wartung sind NICHT als Tab-Ziel zulassen
    if evmIsLockedForInput(rootVehicle) then return false end
    if rootVehicle.spec_enterable == nil then return false end
    local checks = { "getCanBeSelected", "getCanBeTabbable", "getCanSwitchTo", "getCanBeSwitchedTo", "getIsSelectable" }
    for _, methodName in ipairs(checks) do
        local fn = rootVehicle[methodName]
        if type(fn) == "function" then
            local ok, result = pcall(fn, rootVehicle)
            if ok and result == false then return false end
        end
    end
    return true
end

local function evmFindNextUnlockedTabVehicle(lockedVehicle)
    local lockedRoot = evmNormalizeVehicle(lockedVehicle)
    local vehicles = evmCollectMissionVehicles()
    if #vehicles == 0 then return nil end
    local startIndex = nil
    for i, vehicle in ipairs(vehicles) do
        if vehicle == lockedRoot then startIndex = i; break end
    end
    -- Wenn gesperrtes Fahrzeug nicht in Liste: von Anfang an suchen
    if startIndex == nil then
        for _, candidate in ipairs(vehicles) do
            if evmCanTabToVehicle(candidate) then
                return candidate
            end
        end
        return nil
    end
    -- Von gesperrtem Fahrzeug aus vorwärts suchen (dieses selbst überspringen)
    for step = 1, #vehicles - 1 do
        local idx = (startIndex % #vehicles) + 1
        startIndex = idx
        local candidate = vehicles[idx]
        if candidate ~= lockedRoot and evmCanTabToVehicle(candidate) then
            return candidate
        end
    end
    return nil
end

local function evmFindConsoleFailureVehicle()
    local function usable(vehicle)
        local rootVehicle = evmNormalizeVehicle(vehicle)
        if rootVehicle ~= nil and rootVehicle.rootNode ~= nil then return rootVehicle end
        return nil
    end
    if g_currentMission ~= nil then
        local current = usable(g_currentMission.controlledVehicle or g_currentMission.currentVehicle)
        if current ~= nil then return current end
    end
    if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        local ok, vehicle = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
        if ok then
            local current = usable(vehicle)
            if current ~= nil then return current end
        end
    end
    local refNode = evmGetPlayerReferenceNode()
    local bestVehicle, bestDistanceSq = nil, math.huge
    local maxDistanceSq = 35 * 35
    if refNode ~= nil then
        for _, vehicle in ipairs(evmCollectMissionVehicles()) do
            local root = evmNormalizeVehicle(vehicle)
            if root ~= nil and evmIsValidNode(root.rootNode) then
                local distSq = evmDistanceSq(refNode, root.rootNode)
                if distSq <= maxDistanceSq and distSq < bestDistanceSq then
                    bestVehicle = root
                    bestDistanceSq = distSq
                end
            end
        end
    end
    return bestVehicle
end

local function evmRequireSpec(vehicle)
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then
        return nil, "EVM-Spezialisierung fehlt auf '" .. tostring(evmGetVehicleName(vehicle)) .. "' - Fahrzeugtyp wurde nicht korrekt gepatcht. Bitte Log beim Kartenstart pruefen."
    end
    return spec, nil
end

evmIsLockedForInput = function(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    if rootVehicle == nil then
        return false
    end

    local activeSpec, activeVehicle = evmGetActiveServiceSpec(rootVehicle)
    if activeSpec ~= nil then
        local remaining = evmGetServiceRemainingMs(activeSpec, activeVehicle or rootVehicle)
        if remaining <= 0 then
            ExtendedVehicleMaintenance.finishService(activeVehicle or rootVehicle)
            return false
        end
        return true
    end

    -- EVM v13 MP-Service-Lock-Fix:
    -- Lokaler EnterLock kommt im MP vor dem Server-State/Runtime-Spec.
    -- Darum erst den EnterLock pruefen und den HardLock nicht sofort loeschen.
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    local rootNode = rootVehicle.rootNode
    if runtime ~= nil and runtime.enterLocks ~= nil and rootNode ~= nil then
        local lock = runtime.enterLocks[rootNode]
        if lock ~= nil and lock.active == true then
            return true
        end
    end

    if rootVehicle._evmHardLockActive == true then
        local hardLock = ExtendedVehicleMaintenance._hardLockVehicles ~= nil and ExtendedVehicleMaintenance._hardLockVehicles[rootVehicle] or nil
        local age = (g_time or 0) - (hardLock ~= nil and (hardLock.installedAt or 0) or 0)
        if hardLock ~= nil and age < 10000 then
            return true
        end
        ExtendedVehicleMaintenance.removeHardVehicleLock(rootVehicle)
        ExtendedVehicleMaintenance.removeEnterLock(rootVehicle)
        return false
    end

    return false
end
local function evmFindNearbyActiveServiceVehicle(maxDistance)
    local mission = g_currentMission
    if mission == nil then
        return nil, nil
    end

    local referenceNode = evmGetPlayerReferenceNode()
    if not evmIsValidNode(referenceNode) then
        return nil, nil
    end

    local maxDist = tonumber(maxDistance or ExtendedVehicleMaintenance.NEARBY_SERVICE_DISTANCE or 28) or 28
    local maxDistanceSq = maxDist * maxDist
    local bestVehicle = nil
    local bestSpec = nil
    local bestDistanceSq = math.huge
    local seen = {}

    local function consider(vehicle)
        if vehicle == nil then return end
        local rootVehicle = vehicle.rootVehicle or vehicle
        if rootVehicle == nil or seen[rootVehicle] then return end
        seen[rootVehicle] = true

        local activeSpec, activeVehicle = evmGetActiveServiceSpec(rootVehicle)
        if activeSpec == nil or activeVehicle == nil then return end

        local vehicleNode = nil
        if ExtendedVehicleMaintenance.getVehicleNode ~= nil then
            vehicleNode = ExtendedVehicleMaintenance.getVehicleNode(activeVehicle)
        else
            vehicleNode = activeVehicle.rootNode
        end
        if not evmIsValidNode(vehicleNode) then return end

        local distSq = evmDistanceSq(referenceNode, vehicleNode)
        if distSq <= maxDistanceSq and distSq < bestDistanceSq then
            bestDistanceSq = distSq
            bestVehicle = activeVehicle
            bestSpec = activeSpec
        end
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do consider(vehicle) end
    end
    if mission.vehicleSystem ~= nil then
        if mission.vehicleSystem.vehicles ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicles) do consider(vehicle) end
        end
        if mission.vehicleSystem.vehicleIdToVehicle ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicleIdToVehicle) do consider(vehicle) end
        end
    end

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if bestVehicle == nil and runtime ~= nil and runtime.active == true and runtime.pendingLockData ~= nil and ExtendedVehicleMaintenance.findVehicleByPersistData ~= nil then
        consider(ExtendedVehicleMaintenance.findVehicleByPersistData(runtime.pendingLockData, runtime.pendingOldRootNode))
    end

    return bestVehicle, bestSpec
end

local function evmResolveInputLockVehicle(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    if rootVehicle ~= nil and evmIsLockedForInput(rootVehicle) then
        return rootVehicle
    end

    local nearbyVehicle = evmFindNearbyActiveServiceVehicle(ExtendedVehicleMaintenance.INTERACTION_RADIUS or 4.5)
    if nearbyVehicle ~= nil and evmIsLockedForInput(nearbyVehicle) then
        return nearbyVehicle
    end

    return rootVehicle
end


local function evmGetScaledMissionTimeMs()
    local mission = g_currentMission
    local now = 0
    if mission ~= nil and mission.time ~= nil then
        now = tonumber(mission.time or 0) or 0
    else
        now = tonumber(g_time or 0) or 0
    end

    return now, evmGetEffectiveTimeScale()
end

local function evmSyncRuntimeRemaining(rootVehicle, remaining, endAbsHours)
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime == nil then
        return
    end

    -- BUGFIX (zwei identische Trecker): rootVehicle muss strikt das aktuelle
    -- Service-Vehicle sein, sonst wird die Restzeit fuer das falsche Fahrzeug ueberschrieben.
    if runtime.pendingLockData ~= nil and (rootVehicle == nil or evmIsRuntimeServiceVehicle(rootVehicle, runtime)) then
        runtime.pendingLockData.serviceRemainingGameMs = remaining
        runtime.pendingLockData.serviceEndAbsHours = endAbsHours or 0
        if remaining ~= nil and remaining > 0 and (g_time or 0) > 0 then
            runtime.pendingLockData.serviceEndRealMs = (g_time or 0) + evmGameMsToRealMs(remaining)
        elseif remaining ~= nil and remaining <= 0 then
            runtime.pendingLockData.serviceEndRealMs = g_time or 0
        end
    end

    if runtime.syntheticLockSpec ~= nil then
        runtime.syntheticLockSpec.serviceRemainingGameMs = remaining
        runtime.syntheticLockSpec.serviceEndAbsHours = endAbsHours or 0
    end
end

evmGetServiceRemainingMs = function(activeSpec, vehicle)
    if activeSpec == nil then
        return 0
    end

    local rootVehicle = evmNormalizeVehicle(vehicle)
    local remaining = math.max(0, tonumber(activeSpec.serviceRemainingGameMs or 0) or 0)

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    -- BUGFIX (zwei identische Trecker): nicht ueber configFileName-Match sondern strikt
    -- per Objekt-Identitaet. Sonst koennte beim zweiten baugleichen Trecker die Restzeit
    -- des Service-Trecker mitberechnet werden.
    if runtime ~= nil and runtime.pendingLockData ~= nil and (rootVehicle == nil or evmIsRuntimeServiceVehicle(rootVehicle, runtime)) then
        if runtime.pendingLockData.serviceEndRealMs ~= nil and (g_time or 0) > 0 then
            local realRemaining = evmRealMsToGameMs(math.max(0, (runtime.pendingLockData.serviceEndRealMs - (g_time or 0))))
            remaining = remaining > 0 and math.min(remaining, realRemaining) or realRemaining
        elseif runtime.pendingLockData._lastRealTickMs ~= nil and (g_time or 0) > runtime.pendingLockData._lastRealTickMs then
            remaining = math.max(0, remaining - ((g_time or 0) - runtime.pendingLockData._lastRealTickMs))
        end
        runtime.pendingLockData._lastRealTickMs = g_time or runtime.pendingLockData._lastRealTickMs or 0
    end

    local endAbsHours = tonumber(activeSpec.serviceEndAbsHours or 0) or 0
    if endAbsHours > 0 then
        local absRemaining = math.max(0, (endAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
        remaining = remaining > 0 and math.min(remaining, absRemaining) or absRemaining
    end

    local gameNow = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    local missionNow, timeScale = evmGetScaledMissionTimeMs()
    local realNow = g_time or 0

    if activeSpec._evmCountdownGameTimeMs == nil then
        activeSpec._evmCountdownGameTimeMs = gameNow
        activeSpec._evmCountdownMissionTimeMs = missionNow
        activeSpec._evmCountdownRealTimeMs = realNow
    else
        local delta = math.max(0, gameNow - (activeSpec._evmCountdownGameTimeMs or gameNow))
        if delta <= 0 then
            delta = math.max(0, missionNow - (activeSpec._evmCountdownMissionTimeMs or missionNow)) * timeScale
        end
        if delta <= 0 and realNow > 0 then
            delta = evmRealMsToGameMs(math.max(0, realNow - (activeSpec._evmCountdownRealTimeMs or realNow)))
        end
        if delta > 0 and remaining > 0 then
            remaining = math.max(0, remaining - delta)
        end
        activeSpec._evmCountdownGameTimeMs = gameNow
        activeSpec._evmCountdownMissionTimeMs = missionNow
        activeSpec._evmCountdownRealTimeMs = realNow
    end

    activeSpec.serviceRemainingGameMs = remaining
    if remaining > 0 then
        activeSpec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (remaining / 3600000)
    else
        activeSpec.serviceEndAbsHours = 0
    end

    evmSyncRuntimeRemaining(rootVehicle, remaining, activeSpec.serviceEndAbsHours)
    return remaining
end

local function evmGetServiceLockMessage(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    if rootVehicle == nil then
        return evmText("warning_evmInService", "Vehicle is in maintenance")
    end

    local activeSpec, activeVehicle = evmGetActiveServiceSpec(rootVehicle)
    local remainingMs = evmGetServiceRemainingMs(activeSpec, activeVehicle or rootVehicle)

    if activeSpec ~= nil and remainingMs <= 0 then
        ExtendedVehicleMaintenance.finishService(activeVehicle or rootVehicle)
        return string.format(evmText("warning_evmServiceFinished", "%s wurde gewartet und repariert"), tostring(evmGetVehicleLabel(rootVehicle) or evmGetVehicleName(rootVehicle) or "Fahrzeug"))
    end

    if remainingMs <= 0 then
        local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
        -- BUGFIX (zwei identische Trecker): strikt per Objekt-Identitaet pruefen
        if runtime ~= nil and runtime.pendingLockData ~= nil and evmIsRuntimeServiceVehicle(rootVehicle, runtime) then
            remainingMs = tonumber(runtime.pendingLockData.serviceRemainingGameMs or runtime.totalDurationMs or 0) or 0
        end
    end

    local hours, minutes = evmFormatHoursMinutes(remainingMs)
    local vehicleName = evmGetVehicleLabel(rootVehicle) or evmGetVehicleName(rootVehicle) or "Fahrzeug"

    if hours > 0 then
        return string.format(
            evmText("warning_evmInServiceCountdownLong", "%s ist in Wartung und noch %d Std. %02d Min. gesperrt"),
            tostring(vehicleName), hours, minutes
        )
    end

    return string.format(
        evmText("warning_evmInServiceCountdownShort", "%s ist in Wartung und noch %d Min. gesperrt"),
        tostring(vehicleName), math.max(0, minutes)
    )
end

local function evmShowServiceLockWarning(vehicle, durationMs)
    local mission = g_currentMission
    if mission == nil or mission.showBlinkingWarning == nil then
        return
    end

    local rootVehicle = evmNormalizeVehicle(vehicle)
    local now = g_time or 0
    ExtendedVehicleMaintenance._lastServiceLockWarning = ExtendedVehicleMaintenance._lastServiceLockWarning or {}
    local key = rootVehicle or "global"
    local last = ExtendedVehicleMaintenance._lastServiceLockWarning[key] or -99999
    if now - last < 900 then
        return
    end
    ExtendedVehicleMaintenance._lastServiceLockWarning[key] = now

    mission:showBlinkingWarning(evmGetServiceLockMessage(rootVehicle or vehicle), durationMs or 2500)
end

local function evmClearControlledVehicleIfLocked(vehicle)
    local rootVehicle = evmNormalizeVehicle(vehicle)
    if rootVehicle == nil or not evmIsLockedForInput(rootVehicle) then
        return
    end

    local mission = g_currentMission
    if mission ~= nil then
        if mission.controlledVehicle == rootVehicle then
            mission.controlledVehicle = nil
        end
        if mission.currentVehicle == rootVehicle then
            mission.currentVehicle = nil
        end
    end

    if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        local ok, currentVehicle = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
        if ok and evmNormalizeVehicle(currentVehicle) == rootVehicle then
            local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
            local setCurrentVehicle = nil
            if runtime ~= nil and runtime._origLocalPlayerSetCurrentVehicle ~= nil then
                setCurrentVehicle = runtime._origLocalPlayerSetCurrentVehicle
            else
                setCurrentVehicle = g_localPlayer.setCurrentVehicle
            end

            if setCurrentVehicle ~= nil then
                if runtime ~= nil then runtime._isClearingControlledVehicle = true end
                pcall(setCurrentVehicle, g_localPlayer, nil)
                if runtime ~= nil then runtime._isClearingControlledVehicle = false end
            end
        end
    end

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.isEntered = false
                rootVehicle.spec_enterable.controller = nil -- EVM: needed to fully detach locked service vehicle; keep playerStyle/player/controllerName intact.
        rootVehicle.spec_enterable.controllerUserId = 0
        rootVehicle.spec_enterable.enteredFarmId = 0
        rootVehicle.spec_enterable.canBeEntered = false -- EVM: MP-Client lokal sperren; TAB-Umleitung laeuft ueber installGlobalInputLocks()
    end
end

function ExtendedVehicleMaintenance.installGlobalInputLocks()
    local runtime = ExtendedVehicleMaintenance.getRuntime()

    if g_localPlayer ~= nil and g_localPlayer.requestToEnterVehicle ~= nil and runtime._origRequestToEnterVehicle == nil then
        runtime._origRequestToEnterVehicle = g_localPlayer.requestToEnterVehicle
        g_localPlayer.requestToEnterVehicle = function(player, targetVehicle, ...)
            local vehicle = evmNormalizeVehicle(evmFindVehicleInArgs(targetVehicle, ...)) or evmNormalizeVehicle(targetVehicle)
            if evmIsLockedForInput(vehicle) then
                evmShowServiceLockWarning(vehicle, 2600)
                evmClearControlledVehicleIfLocked(vehicle)
                -- Kein automatisches Weiterleiten ins naechste Fahrzeug.
                -- Spieler soll stehen bleiben und die Warnung sehen.
                return false
            end
            return runtime._origRequestToEnterVehicle(player, targetVehicle, ...)
        end
    end

    if g_localPlayer ~= nil and g_localPlayer.setCurrentVehicle ~= nil and runtime._origLocalPlayerSetCurrentVehicle == nil then
        runtime._origLocalPlayerSetCurrentVehicle = g_localPlayer.setCurrentVehicle
        g_localPlayer.setCurrentVehicle = function(player, targetVehicle, ...)
            if targetVehicle == nil or runtime._isClearingControlledVehicle == true then
                return runtime._origLocalPlayerSetCurrentVehicle(player, targetVehicle, ...)
            end

            local vehicle = evmNormalizeVehicle(evmFindVehicleInArgs(targetVehicle, ...)) or evmNormalizeVehicle(targetVehicle)
            if evmIsLockedForInput(vehicle) then
                evmShowServiceLockWarning(vehicle, 2600)
                evmClearControlledVehicleIfLocked(vehicle)
                return false
            end
            return runtime._origLocalPlayerSetCurrentVehicle(player, targetVehicle, ...)
        end
    end

    local mission = g_currentMission
    if mission ~= nil then
        if mission.requestToEnterVehicle ~= nil and runtime._origMissionRequestToEnterVehicle == nil then
            runtime._origMissionRequestToEnterVehicle = mission.requestToEnterVehicle
            mission.requestToEnterVehicle = function(missionSelf, targetVehicle, ...)
                local vehicle = evmNormalizeVehicle(evmFindVehicleInArgs(targetVehicle, ...)) or evmNormalizeVehicle(targetVehicle)
                if evmIsLockedForInput(vehicle) then
                    evmShowServiceLockWarning(vehicle, 2600)
                    evmClearControlledVehicleIfLocked(vehicle)
                    return false
                end
                return runtime._origMissionRequestToEnterVehicle(missionSelf, targetVehicle, ...)
            end
        end

        if mission.enterVehicle ~= nil and runtime._origMissionEnterVehicle == nil then
            runtime._origMissionEnterVehicle = mission.enterVehicle
            mission.enterVehicle = function(missionSelf, targetVehicle, ...)
                local vehicle = evmNormalizeVehicle(evmFindVehicleInArgs(targetVehicle, ...)) or evmNormalizeVehicle(targetVehicle)
                if evmIsLockedForInput(vehicle) then
                    evmShowServiceLockWarning(vehicle, 2600)
                    evmClearControlledVehicleIfLocked(vehicle)
                    return false
                end
                return runtime._origMissionEnterVehicle(missionSelf, targetVehicle, ...)
            end
        end

        if mission.setControlledVehicle ~= nil and runtime._origMissionSetControlledVehicle == nil then
            runtime._origMissionSetControlledVehicle = mission.setControlledVehicle
            mission.setControlledVehicle = function(missionSelf, targetVehicle, ...)
                local vehicle = evmNormalizeVehicle(evmFindVehicleInArgs(targetVehicle, ...)) or evmNormalizeVehicle(targetVehicle)
                if evmIsLockedForInput(vehicle) then
                    evmShowServiceLockWarning(vehicle, 2600)
                    evmClearControlledVehicleIfLocked(vehicle)
                    return false
                end
                return runtime._origMissionSetControlledVehicle(missionSelf, targetVehicle, ...)
            end
        end
    end
end

function ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    local mission = g_currentMission
    if mission == nil or mission.environment == nil then
        return 0
    end
    local env = mission.environment
    local dayTime = env.dayTime or 0
    local currentDay = env.currentDay or 0
    return currentDay * 24 * 60 * 60 * 1000 + dayTime
end

function ExtendedVehicleMaintenance.getCurrentAbsHours()
    local mission = g_currentMission
    if mission == nil or mission.environment == nil then
        return 0
    end
    local env = mission.environment
    local dayTime = tonumber(env.dayTime or 0) or 0
    if (dayTime <= 0) and env.getEnvironmentTime ~= nil then
        local ok, t = pcall(env.getEnvironmentTime, env)
        if ok then
            dayTime = tonumber(t or 0) or dayTime
        end
    end
    local currentDay = tonumber(env.currentDay or 0) or 0
    return (dayTime / 3600000) + (currentDay * 24)
end

function ExtendedVehicleMaintenance.getLocalFarmId()
    local mission = g_currentMission
    if mission == nil or mission.getFarmId == nil then
        return nil
    end
    return mission:getFarmId()
end

function ExtendedVehicleMaintenance.getPlayerRootNode()
    local mission = g_currentMission
    if mission == nil then
        return nil
    end
    if mission.controlledVehicle ~= nil then
        return nil
    end
    if mission.player ~= nil and mission.player.rootNode ~= nil then
        return mission.player.rootNode
    end
    if g_localPlayer ~= nil and g_localPlayer.rootNode ~= nil then
        return g_localPlayer.rootNode
    end
    return nil
end

function ExtendedVehicleMaintenance.getVehicleNode(vehicle)
    if vehicle == nil then
        return nil
    end
    if vehicle.components ~= nil and vehicle.components[1] ~= nil and vehicle.components[1].node ~= nil then
        return vehicle.components[1].node
    end
    return vehicle.rootNode
end

function ExtendedVehicleMaintenance.resolveVehicleFromNode(node)
    if node == nil or node == 0 or g_currentMission == nil then
        return nil
    end

    local currentNode = node
    while currentNode ~= nil and currentNode ~= 0 do
        local object = g_currentMission.nodeToObject[currentNode]

        if object ~= nil then
            if object.isa ~= nil and object:isa(Vehicle) then
                return object.rootVehicle or object
            end
            if object.object ~= nil and object.object.isa ~= nil and object.object:isa(Vehicle) then
                return object.object.rootVehicle or object.object
            end
            if object.getRootVehicle ~= nil then
                local rootVehicle = object:getRootVehicle()
                if rootVehicle ~= nil then
                    return rootVehicle
                end
            end
        end

        local parent = getParent(currentNode)
        if parent == nil or parent == 0 or parent == currentNode then
            break
        end
        currentNode = parent
    end

    return nil
end

function ExtendedVehicleMaintenance.isVehicleLocked(vehicle)
    local activeSpec = evmGetActiveServiceSpec(vehicle)
    return activeSpec ~= nil
end

function ExtendedVehicleMaintenance.isVehicleInServiceOrPending(vehicle)
    if vehicle == nil then
        return false
    end

    if ExtendedVehicleMaintenance.isVehicleLocked(vehicle) then
        return true
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime ~= nil and runtime.active == true then
        if runtime.rootVehicle ~= nil then
            local rtRoot = runtime.rootVehicle.rootVehicle or runtime.rootVehicle
            if rtRoot == rootVehicle then
                return true
            end
        end

        -- BUGFIX (zwei identische Trecker): hier nicht mehr per evmVehicleMatchesPersist
        -- vergleichen, weil das beide baugleichen Trecker erfasst. Stattdessen ueber
        -- die strenge Objekt-/RootNode-Identitaetspruefung gehen.
        if runtime.pendingLockData ~= nil and evmIsRuntimeServiceVehicle(rootVehicle, runtime) then
            return true
        end
    end

    return false
end

function ExtendedVehicleMaintenance.prerequisitesPresent(_)
    return true
end

function ExtendedVehicleMaintenance.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", ExtendedVehicleMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", ExtendedVehicleMaintenance)
end

function ExtendedVehicleMaintenance.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", ExtendedVehicleMaintenance.getCanMotorRun)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getMotorNotAllowedWarning", ExtendedVehicleMaintenance.getMotorNotAllowedWarning)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeEntered", ExtendedVehicleMaintenance.getCanBeEntered)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected", ExtendedVehicleMaintenance.getCanBeSelected)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeUsed", ExtendedVehicleMaintenance.getCanBeUsed)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeRepaired", ExtendedVehicleMaintenance.getCanBeRepaired)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getRepairPrice", ExtendedVehicleMaintenance.getRepairPrice)
    -- v17: Wenn ein Anbaugeraet/Anhaenger ueber den Vanilla-"Reparieren"-Button am Haendler
    -- repariert wird, sollen aktive EVM-Pannen (flatTire, hydraulicLeak, brakeFault) ebenfalls
    -- aufgehoben werden. Sonst wuerde z.B. ein platter Reifen visuell heil aussehen, aber
    -- spec.failureType weiter "flatTire" bleiben und beim naechsten Tick wieder triggern.
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "repairVehicle", ExtendedVehicleMaintenance.repairVehicle)
    -- v21: Im Haendler-Menue ruft FS25 NICHT getRepairPrice() auf, sondern andere Funktionen.
    -- Welche genau weiss man nicht ohne Spielsourcen, deshalb hooken wir alle plausiblen Kandidaten
    -- mit einem Safe-Wrapper. Wenn die Funktion auf vehicleType.functions nicht existiert, ueberspringen.
    -- Beobachtung: Vanilla-Fendt zeigt "REPARIEREN (€2.247)" trotz getRepairPrice-Hook -> es gibt
    -- mind. eine zusaetzliche Funktion die der Haendler benutzt.
    local _evmExtraRepairFns = {
        "getRepairShopPrice",        -- Haendler-Dialog (Verdacht)
        "getRepairShopBasePrice",    -- alternative Schreibweise
        "getDailyUpkeep",             -- taegliche Reparaturkosten - vermutlich nicht der Button, aber sicher ist sicher
        "getSellPrice",               -- nicht repair, aber gleicher Mechanismus
    }
    for _, fnName in ipairs(_evmExtraRepairFns) do
        if vehicleType.functions ~= nil and vehicleType.functions[fnName] ~= nil
            and ExtendedVehicleMaintenance["evmHook_" .. fnName] ~= nil then
            local ok, err = pcall(SpecializationUtil.registerOverwrittenFunction, vehicleType, fnName, ExtendedVehicleMaintenance["evmHook_" .. fnName])
            if not ok then
                print(string.format("[EVM] WARN: Konnte %s nicht hooken: %s", fnName, tostring(err)))
            else
                if ExtendedVehicleMaintenance.debug == true and not ExtendedVehicleMaintenance._loggedRepairFns then
                    print(string.format("[EVM] Repair-Hook aktiv: %s", fnName))
                end
            end
        end
    end

    -- v21: Diagnose - einmalig loggen welche Repair-Funktionen FS25 ueberhaupt hat.
    -- Hilft beim Tracking welcher Hook das Haendler-Menue wirklich beeinflusst.
    if not ExtendedVehicleMaintenance._loggedRepairFns and vehicleType.functions ~= nil then
        ExtendedVehicleMaintenance._loggedRepairFns = true
        local found = {}
        for _, fnName in ipairs({"getRepairPrice","getRepairShopPrice","getRepairShopBasePrice","getCanBeRepaired","getDailyUpkeep","repairVehicle"}) do
            if vehicleType.functions[fnName] ~= nil then table.insert(found, fnName) end
        end
        print(string.format("[EVM] Repair-Funktionen auf vehicleType (%s): %s", tostring(vehicleType.name or "?"), table.concat(found, ", ")))
    end
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "showInfo", ExtendedVehicleMaintenance.showInfo)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsEnterable", ExtendedVehicleMaintenance.getIsEnterable)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsEnterableFromMenu", ExtendedVehicleMaintenance.getIsEnterableFromMenu)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", ExtendedVehicleMaintenance.interact)
    if vehicleType.functions ~= nil and vehicleType.functions.getCanToggleMotor ~= nil then
        SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanToggleMotor", ExtendedVehicleMaintenance.getCanToggleMotor)
    end
end

function ExtendedVehicleMaintenance.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#hoursPool", "Remaining maintenance hours pool")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#daysPool", "Remaining maintenance days pool")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#lastServiceOperatingTimeMs", "Operating time at last service")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#lastServiceGameTimeMs", "Game time at last service")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#serviceRemainingGameMs", "Remaining service duration")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#serviceEndAbsHours", "Absolute game hour when service ends")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#serviceHoursToAdd", "Hours added by service")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#serviceDaysToAdd", "Days added by service")
    schema:register(XMLValueType.BOOL, basePath .. ".extendedVehicleMaintenance#isServiceActive", "Whether service is active")
    schema:register(XMLValueType.INT, basePath .. ".extendedVehicleMaintenance#serviceMode", "Service mode")
    schema:register(XMLValueType.STRING, basePath .. ".extendedVehicleMaintenance#failureType", "Active realistic failure type")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#failureSeverity", "Failure severity")
    schema:register(XMLValueType.INT, basePath .. ".extendedVehicleMaintenance#failureWheelIndex", "Flat tire wheel cluster index")
    schema:register(XMLValueType.INT, basePath .. ".extendedVehicleMaintenance#failureDriftDirection", "Flat tire steering drift direction")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#batteryCharge", "Battery state of charge 0..1")
    schema:register(XMLValueType.FLOAT, basePath .. ".extendedVehicleMaintenance#batteryVoltage", "Simulated battery voltage")
end

function ExtendedVehicleMaintenance.registerSpecialization()
    if g_specializationManager == nil then
        print("[EVM] registerSpecialization skipped: g_specializationManager=nil")
        return nil
    end

    local shortName = ExtendedVehicleMaintenance.SPEC_NAME
    local envName = ExtendedVehicleMaintenance.MOD_NAME or g_currentModName or "FS25_ExtendedVehicleMaintenance"
    local fullName = envName .. "." .. shortName

    local spec = nil
    if g_specializationManager.getSpecializationByName ~= nil then
        spec = g_specializationManager:getSpecializationByName(fullName)
            or g_specializationManager:getSpecializationByName(shortName)
    end
    if spec ~= nil then
        return spec
    end

    local className = "ExtendedVehicleMaintenance"
    local fileName = Utils.getFilename("scripts/ExtendedVehicleMaintenance.lua", ExtendedVehicleMaintenance.MOD_DIR)
    local ok, err = pcall(function()
        g_specializationManager:addSpecialization(shortName, className, fileName, envName)
    end)

    if not ok then
        print("[EVM] registerSpecialization with env failed, retry without env: " .. tostring(err))
        pcall(function()
            g_specializationManager:addSpecialization(shortName, className, fileName, nil)
        end)
    end

    if g_specializationManager.getSpecializationByName ~= nil then
        spec = g_specializationManager:getSpecializationByName(fullName)
            or g_specializationManager:getSpecializationByName(shortName)
    end

    if spec == nil then
        print("[EVM] registerSpecialization FAILED: not found as '" .. fullName .. "' or '" .. shortName .. "'")
    end
    return spec
end

function ExtendedVehicleMaintenance.addSpecializationToVehicleTypes(vehicleTypesArg)
    if g_vehicleTypeManager == nil then
        print("[EVM] addSpecializationToVehicleTypes skipped: g_vehicleTypeManager=nil")
        return 0
    end

    local spec = ExtendedVehicleMaintenance.registerSpecialization()
    if spec == nil then
        print("[EVM] addSpecializationToVehicleTypes: registerSpecialization returned nil, aborting")
        return 0
    end

    local envName = ExtendedVehicleMaintenance.MOD_NAME or g_currentModName or "FS25_ExtendedVehicleMaintenance"
    local fullSpecName = envName .. "." .. ExtendedVehicleMaintenance.SPEC_NAME

    local checked = 0
    local added = 0
    local skipped = 0
    local failed = 0

    local vehicleTypes = vehicleTypesArg
    if vehicleTypes == nil and g_vehicleTypeManager.getVehicleTypes ~= nil then
        vehicleTypes = g_vehicleTypeManager:getVehicleTypes()
    end
    vehicleTypes = vehicleTypes or g_vehicleTypeManager.types or g_vehicleTypeManager.vehicleTypes or {}

    local function nameMatches(value, shortName)
        value = tostring(value or "")
        return value == shortName or string.sub(value, -#shortName - 1) == "." .. shortName
    end

    local function listHasSpecName(list, shortName)
        if list == nil then return false end
        for _, name in pairs(list) do
            if nameMatches(name, shortName) then return true end
        end
        return false
    end

    local function hasSpecObject(vehicleType)
        return vehicleType ~= nil
            and vehicleType.specializations ~= nil
            and SpecializationUtil ~= nil
            and SpecializationUtil.hasSpecialization ~= nil
            and SpecializationUtil.hasSpecialization(spec, vehicleType.specializations)
    end

    local function typeHasBase(vehicleType)
        if vehicleType == nil then return false end

        local specializations = vehicleType.specializations
        if specializations ~= nil and SpecializationUtil ~= nil and SpecializationUtil.hasSpecialization ~= nil then
            if Drivable ~= nil and SpecializationUtil.hasSpecialization(Drivable, specializations) then return true end
            if Attachable ~= nil and SpecializationUtil.hasSpecialization(Attachable, specializations) then return true end
            if Enterable ~= nil and SpecializationUtil.hasSpecialization(Enterable, specializations) then return true end
            if Motorized ~= nil and SpecializationUtil.hasSpecialization(Motorized, specializations) then return true end
        end

        local names = vehicleType.specializationNames or vehicleType.specializationsByName or vehicleType.specializationNameToIndex
        return listHasSpecName(names, "drivable")
            or listHasSpecName(names, "attachable")
            or listHasSpecName(names, "enterable")
            or listHasSpecName(names, "motorized")
    end

    for typeName, vehicleType in pairs(vehicleTypes) do
        if type(vehicleType) == "table" and typeHasBase(vehicleType) then
            checked = checked + 1

            local hasSpec = hasSpecObject(vehicleType)
                or listHasSpecName(vehicleType.specializationNames, ExtendedVehicleMaintenance.SPEC_NAME)

            if hasSpec then
                skipped = skipped + 1
            else
                local didAdd = false

                -- FS25: In diesem frühen TypeManager-Hook erzeugt addSpecialization() bei manchen
                -- Loads zwar keinen Fehler, aber am Fahrzeug entsteht später trotzdem keine spec_*-Tabelle.
                -- Deshalb patchen wir VOR finalizeTypes direkt die Type-Definition. Das ist kein
                -- Runtime-Fallback: es gibt weiterhin keine nachträglich erzeugten Fahrzeug-Specs.
                if vehicleType.specializationNames ~= nil and not listHasSpecName(vehicleType.specializationNames, ExtendedVehicleMaintenance.SPEC_NAME) then
                    table.insert(vehicleType.specializationNames, fullSpecName)
                    didAdd = true
                end

                if vehicleType.specializations ~= nil and not hasSpecObject(vehicleType) then
                    table.insert(vehicleType.specializations, spec)
                    didAdd = true
                end

                if didAdd then
                    added = added + 1
                else
                    failed = failed + 1
                    evmDbg("direct type patch failed for vehicle type %s", tostring(typeName))
                end
            end
        end
    end

    ExtendedVehicleMaintenance._vehicleTypesPatched = added > 0 or skipped > 0
    print(string.format("[EVM] addSpecializationToVehicleTypes: checked=%d added=%d skipped=%d failed=%d patched=%s mode=typePatchPlusRuntimeRepair", checked, added, skipped, failed, tostring(ExtendedVehicleMaintenance._vehicleTypesPatched)))
    return added
end
function ExtendedVehicleMaintenance.registerGlobalSavegameXMLPaths()
    if ExtendedVehicleMaintenance.savegamePathsRegistered then
        return
    end
    if Vehicle ~= nil and Vehicle.xmlSchemaSavegame ~= nil then
        ExtendedVehicleMaintenance.registerSavegameXMLPaths(Vehicle.xmlSchemaSavegame, "vehicles.vehicle(?)")
        ExtendedVehicleMaintenance.savegamePathsRegistered = true
    end
end

function ExtendedVehicleMaintenance.getRemainingMaintenance(vehicle)
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then
        return 0, 0
    end

    local currentOperatingTimeMs = evmGetOperatingTimeMs(vehicle)
    local currentGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()

    local lastServiceOperatingTimeMs = spec.lastServiceOperatingTimeMs or currentOperatingTimeMs
    local lastServiceGameTimeMs = spec.lastServiceGameTimeMs or currentGameTimeMs
    local hoursPool = spec.hoursPool or ExtendedVehicleMaintenance.DEFAULT_HOURS
    local daysPool = spec.daysPool or ExtendedVehicleMaintenance.DEFAULT_DAYS

    local elapsedOperatingHours = math.max(0, (currentOperatingTimeMs - lastServiceOperatingTimeMs) / (60 * 60 * 1000))
    local elapsedDays = math.max(0, (currentGameTimeMs - lastServiceGameTimeMs) / (24 * 60 * 60 * 1000))

    -- v16/v19: Realistische Verschleiß-Rate.
    -- Ein nagelneues Fahrzeug verbraucht das Wartungsintervall mit Faktor 1.0.
    -- Ein altes Fahrzeug (viele Gesamt-Betriebsstunden) bzw. ein beschädigtes Fahrzeug
    -- verbraucht das Intervall schneller -> der nächste Service kommt früher.
    -- v19: Multiplier abgemildert, weil bei hohem Time-Scale + Drescher + Schaden
    -- die Wartung sonst nach 30 Echt-Minuten faellig war.
    local totalOperatingHours = math.max(0, currentOperatingTimeMs / (60 * 60 * 1000))
    local damage = evmGetVehicleDamage(vehicle) or 0

    -- Alters-Faktor: ab 200 Bh leicht erhöht, bei 1000 Bh ca. +35%, bei >2000 Bh +55%.
    -- v19: Sanftere Kurve (vorher max +80%).
    local ageFactor = 1.0
    if totalOperatingHours > 100 then
        ageFactor = 1.0 + math.min(0.55, math.log(1.0 + (totalOperatingHours - 100) / 300) * 0.32)
    end

    -- Schadens-Faktor: erst ab 35% Schaden spürbar (vorher 20%), max +35% Verschleiß
    -- bei 100% Schaden (vorher +60%). Kleinere Schaeden treiben den Wartungs-Cycle nicht.
    local damageFactor = 1.0
    if damage > 0.35 then
        damageFactor = 1.0 + math.min(0.35, (damage - 0.35) * 0.55)
    end

    local wearMultiplier = ageFactor * damageFactor
    -- v19: Cap auf 1.7 (vorher 2.5). Selbst extrem altes + beschaedigtes Fahrzeug
    -- hat noch ~60% des nominalen Wartungsintervalls.
    if wearMultiplier > 1.70 then wearMultiplier = 1.70 end
    if wearMultiplier < 1.0 then wearMultiplier = 1.0 end

    local effectiveOperatingHours = elapsedOperatingHours * wearMultiplier
    local effectiveDays           = elapsedDays           * wearMultiplier

    local remainingHours = math.max(0, hoursPool - effectiveOperatingHours)
    local remainingDays = math.max(0, daysPool - effectiveDays)

    return remainingHours, remainingDays
end

function ExtendedVehicleMaintenance.isDue(vehicle)
    local remainingHours, remainingDays = ExtendedVehicleMaintenance.getRemainingMaintenance(vehicle)
    return remainingHours <= 0 or remainingDays <= 0, remainingHours, remainingDays
end

function ExtendedVehicleMaintenance.calculateServiceValues(vehicle)
    local damage = evmGetVehicleDamage(vehicle)
    local price = evmGetVehiclePrice(vehicle)
    local cat = ExtendedVehicleMaintenance.getVehicleCategory(vehicle)
    local isMotorized = vehicle ~= nil and vehicle.spec_motorized ~= nil
    local catCostFactor = tonumber(cat.costFactor or 1.0) or 1.0
    local maxH = tonumber(cat.maxHours or ExtendedVehicleMaintenance.MAX_HOURS) or 25
    local maxD = tonumber(cat.maxDays  or ExtendedVehicleMaintenance.MAX_DAYS)  or 9999

    -- v22: Service gibt wieder einen vollen 25-Betriebsstunden-Takt.
    -- Schaden beeinflusst Kosten/Dauer, aber nicht mehr den Grund-Takt im HUD.
    local hoursAdded = evmClamp(ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS or 25, 1, maxH)
    local daysAdded  = maxD
    local cost = math.floor(math.max(isMotorized and 350 or 180,
        price * ((isMotorized and 0.0026 or 0.0016) + damage * 0.0032) * catCostFactor))

    return {
        name = evmGetVehicleName(vehicle),
        damage = damage,
        hoursAdded = hoursAdded,
        daysAdded = daysAdded,
        cost = cost,
        isMotorized = isMotorized,
        category = cat,
    }
end

function ExtendedVehicleMaintenance.getDamageCostMultiplier(damage)
    local dmg = evmClamp(tonumber(damage) or 0, 0, 1)
    return 1 + dmg * (ExtendedVehicleMaintenance.DAMAGE_COST_FACTOR or 2.6)
end

function ExtendedVehicleMaintenance.getServiceModeCost(values, serviceMode)
    values = values or {}
    local baseCost = tonumber(values.cost) or 0
    local mode = tonumber(serviceMode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP

    local factor = ExtendedVehicleMaintenance.WORKSHOP_COST_FACTOR or 2.2
    if mode == ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN then
        factor = ExtendedVehicleMaintenance.TECHNICIAN_COST_FACTOR or 3.8
    elseif mode == ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR then
        factor = ExtendedVehicleMaintenance.SELF_REPAIR_COST_FACTOR or 0.35
    end

    local result = math.floor(baseCost * factor * ExtendedVehicleMaintenance.getDamageCostMultiplier(values.damage) + 0.5)
    if mode == ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR then
        return math.max(25, result)
    end

    return math.max(values.isMotorized and 750 or 350, result)
end

function ExtendedVehicleMaintenance.getServiceModeDuration(values, serviceMode)
    values = values or {}
    local baseHours = 1.0 + (tonumber(values.damage) or 0) * 2.5 + (values.isMotorized and 0.5 or 0.2)
    local mode = tonumber(serviceMode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP

    if mode == ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN then
        return baseHours * (ExtendedVehicleMaintenance.TECHNICIAN_DURATION_FACTOR or 1.15)
    elseif mode == ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR then
        return baseHours * (ExtendedVehicleMaintenance.SELF_REPAIR_DURATION_FACTOR or 4.0) + (ExtendedVehicleMaintenance.SELF_REPAIR_EXTRA_HOURS or 1.5)
    end

    return baseHours
end

function ExtendedVehicleMaintenance.createSelectionEntry(vehicle)
    if vehicle == nil then return nil end
    local rootVehicle = vehicle.rootVehicle or vehicle
    local values = ExtendedVehicleMaintenance.calculateServiceValues(rootVehicle)
    return {
        vehicle = rootVehicle,
        name = values.name,
        damage = values.damage,
        cost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP),
        technicianCost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN),
        selfRepairCost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR),
        durationHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP),
        durationTechnicianHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN),
        durationSelfRepairHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR),
        hoursAdded = values.hoursAdded,
        daysAdded = values.daysAdded,
    }
end

function ExtendedVehicleMaintenance.getWorkshopTargets(vehicle)
    local rootVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if rootVehicle == nil then
        return {}
    end

    local targets = {}
    local seen = {}

    local function addVehicleRecursive(target)
        if target == nil then
            return
        end

        target = target.rootVehicle or target
        if target.rootNode == nil or seen[target] then
            return
        end

        seen[target] = true
        table.insert(targets, target)

        if target.getAttachedImplements ~= nil then
            local ok, implements = pcall(target.getAttachedImplements, target)
            if ok and type(implements) == "table" then
                for _, implement in pairs(implements) do
                    local object = implement ~= nil and implement.object or nil
                    if object ~= nil then
                        addVehicleRecursive(object)
                    end
                end
            end
        end
    end

    addVehicleRecursive(rootVehicle)
    return targets
end

function ExtendedVehicleMaintenance.buildServicePlan(vehicle, mode)
    local targets = ExtendedVehicleMaintenance.getWorkshopTargets(vehicle)
    local entries = {}
    local totalCost = 0
    local maxDurationHours = 0
    local serviceMode = mode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP

    for _, target in ipairs(targets) do
        local values = ExtendedVehicleMaintenance.calculateServiceValues(target)
        local durationHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, serviceMode)
        local cost = ExtendedVehicleMaintenance.getServiceModeCost(values, serviceMode)

        totalCost = totalCost + cost
        maxDurationHours = math.max(maxDurationHours, durationHours)

        table.insert(entries, {
            vehicle = target,
            values = values,
            durationHours = durationHours,
            cost = cost
        })
    end

    if #entries == 0 then
        return nil
    end

    return {
        entries = entries,
        targetCount = #entries,
        totalCost = totalCost,
        durationHours = maxDurationHours,
        durationGameMs = math.floor(maxDurationHours * 60 * 60 * 1000),
        mode = serviceMode
    }

end

local function evmGetCurrentLocalVehicle()
    if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        local ok, currentVehicle = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
        if ok then
            return evmNormalizeVehicle(currentVehicle)
        end
    end

    if g_currentMission ~= nil then
        return evmNormalizeVehicle(g_currentMission.controlledVehicle or g_currentMission.currentVehicle)
    end

    return nil
end

local function evmIsPlayerInThisVehicle(rootVehicle)
    rootVehicle = evmNormalizeVehicle(rootVehicle)
    if rootVehicle == nil then
        return false
    end

    local currentVehicle = evmGetCurrentLocalVehicle()
    if currentVehicle == rootVehicle then
        return true
    end

    if g_currentMission ~= nil and evmNormalizeVehicle(g_currentMission.controlledVehicle) == rootVehicle then
        return true
    end

    if rootVehicle.getIsEntered ~= nil then
        local ok, entered = pcall(rootVehicle.getIsEntered, rootVehicle)
        if ok and entered == true then
            return true
        end
    end

    if rootVehicle.spec_enterable ~= nil then
        local se = rootVehicle.spec_enterable
        if se.isEntered == true or se.controller ~= nil or se.controllerUserId ~= nil and se.controllerUserId ~= 0 then
            return true
        end
    end

    return false
end

function ExtendedVehicleMaintenance.forceVehicleStandstill(vehicle)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    if rootVehicle.spec_motorized ~= nil then
        if rootVehicle.getIsMotorStarted ~= nil then
            local ok, started = pcall(rootVehicle.getIsMotorStarted, rootVehicle)
            if ok and started and rootVehicle.stopMotor ~= nil then
                pcall(rootVehicle.stopMotor, rootVehicle)
            end
        end

        if rootVehicle.spec_motorized.motor ~= nil then
            local motor = rootVehicle.spec_motorized.motor
            if motor.setSpeedLimit ~= nil then
                pcall(motor.setSpeedLimit, motor, 0)
            end
            if motor.setEqualizedMotorRpm ~= nil then
                pcall(motor.setEqualizedMotorRpm, motor, 0)
            end
        end
    end

    if rootVehicle.setIsTurnedOn ~= nil then
        pcall(rootVehicle.setIsTurnedOn, rootVehicle, false, true)
    end

    if rootVehicle.setCruiseControlState ~= nil and Drivable ~= nil and Drivable.CRUISECONTROL_STATE_OFF ~= nil then
        pcall(rootVehicle.setCruiseControlState, rootVehicle, Drivable.CRUISECONTROL_STATE_OFF)
    end

    if rootVehicle.setThrottle ~= nil then
        pcall(rootVehicle.setThrottle, rootVehicle, 0)
    end
    if rootVehicle.setAccelerationPedal ~= nil then
        pcall(rootVehicle.setAccelerationPedal, rootVehicle, 0)
    end
    if rootVehicle.setBrakePedal ~= nil then
        pcall(rootVehicle.setBrakePedal, rootVehicle, 1)
    end
    if rootVehicle.setAxisForward ~= nil then
        pcall(rootVehicle.setAxisForward, rootVehicle, 0)
    end
    if rootVehicle.setAxisSide ~= nil then
        pcall(rootVehicle.setAxisSide, rootVehicle, 0)
    end
    if rootVehicle.setMovingDirection ~= nil then
        pcall(rootVehicle.setMovingDirection, rootVehicle, 0)
    end

    if rootVehicle.spec_drivable ~= nil then
        local specDrivable = rootVehicle.spec_drivable
        -- EVM fix: remember drivable limits before service-lock overwrites them.
        -- Older builds left maxAcceleration/maxBackwardAcceleration=0 and handBrakeActive=true
        -- after service end, so the vehicle looked repaired but still could not move/start properly.
        if rootVehicle._evmSavedServiceDrivableState == nil then
            rootVehicle._evmSavedServiceDrivableState = {
                maxAcceleration = specDrivable.maxAcceleration,
                maxBackwardAcceleration = specDrivable.maxBackwardAcceleration,
                brakeInput = specDrivable.brakeInput,
                handBrakeActive = specDrivable.handBrakeActive
            }
        end
        specDrivable.axisForward = 0
        specDrivable.axisSide = 0
        specDrivable.accelerationAxis = 0
        specDrivable.maxAcceleration = 0
        specDrivable.maxBackwardAcceleration = 0
        specDrivable.brakeInput = 1
        specDrivable.handBrakeActive = true
        specDrivable.lastInputValues = specDrivable.lastInputValues or {}
        specDrivable.lastInputValues.axisForward = 0
        specDrivable.lastInputValues.axisSide = 0
        if specDrivable.cruiseControl ~= nil then
            specDrivable.cruiseControl.state = Drivable ~= nil and Drivable.CRUISECONTROL_STATE_OFF or 0
            specDrivable.cruiseControl.isActive = false
        end
    end

    if rootVehicle.components ~= nil then
        for _, component in ipairs(rootVehicle.components) do
            if component ~= nil and component.node ~= nil and entityExists(component.node) then
                setLinearVelocity(component.node, 0, 0, 0)
                setAngularVelocity(component.node, 0, 0, 0)
            end
        end
    end
end

function ExtendedVehicleMaintenance.forceLeaveVehicle(vehicle)
    if vehicle == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local mission = g_currentMission
    local left = false
    local playerWasInThisVehicle = evmIsPlayerInThisVehicle(rootVehicle)

    -- Only run the expensive / invasive leave logic when the player really sits in
    -- THIS vehicle. The previous version cleared g_localPlayer every update and
    -- therefore kicked the player out of unrelated vehicles too.
    if playerWasInThisVehicle then
        if rootVehicle.leaveVehicle ~= nil then
            pcall(rootVehicle.leaveVehicle, rootVehicle)
        end
        if rootVehicle.requestActionEventLeave ~= nil then
            pcall(rootVehicle.requestActionEventLeave, rootVehicle)
        end
        if rootVehicle.doLeaveVehicle ~= nil then
            pcall(rootVehicle.doLeaveVehicle, rootVehicle)
        end
        -- EVM v12: wie in BACKUP5 wieder sauber aus dem Fahrzeug ausklinken.
        -- Wichtig: playerStyle/player/controllerName bleiben aber unangetastet,
        -- weil genau deren Loeschen im MP unsichtbare Spieler/Fahrzeuge erzeugen konnte.
        if rootVehicle.onLeaveVehicle ~= nil then
            pcall(rootVehicle.onLeaveVehicle, rootVehicle)
        end
        if rootVehicle.setIsEntered ~= nil then
            pcall(rootVehicle.setIsEntered, rootVehicle, false)
            pcall(rootVehicle.setIsEntered, rootVehicle, false, nil, nil)
            pcall(rootVehicle.setIsEntered, rootVehicle, false, nil, 0)
        end
        left = true
    end

    if mission ~= nil then
        if evmNormalizeVehicle(mission.controlledVehicle) == rootVehicle then
            mission.controlledVehicle = nil
            left = true
        end
        if evmNormalizeVehicle(mission.currentVehicle) == rootVehicle then
            mission.currentVehicle = nil
            left = true
        end

        if playerWasInThisVehicle and mission.player ~= nil then
            if mission.player.setVehicle ~= nil then
                pcall(mission.player.setVehicle, mission.player, nil)
            end
            if mission.player.onLeaveVehicle ~= nil then
                pcall(mission.player.onLeaveVehicle, mission.player)
            end
        end
    end

    if g_localPlayer ~= nil and evmGetCurrentLocalVehicle() == rootVehicle then
        if g_localPlayer.setCurrentVehicle ~= nil then
            pcall(g_localPlayer.setCurrentVehicle, g_localPlayer, nil)
        end
        if g_localPlayer.onLeaveVehicle ~= nil then
            pcall(g_localPlayer.onLeaveVehicle, g_localPlayer)
        end
        left = true
    end

    if rootVehicle.spec_enterable ~= nil then
        local specEnterable = rootVehicle.spec_enterable
        specEnterable.isEntered = false
                specEnterable.controller = nil -- EVM: needed to fully detach locked service vehicle; keep playerStyle/player/controllerName intact.
        specEnterable.controllerUserId = 0
        specEnterable.enteredFarmId = 0
        -- MP-Safety: do NOT clear playerStyle/currentPlayerStyle/player/controllerName here.
        -- GIANTS uses those tables while processing enter/leave and AIJobVehicle packets;
        -- clearing them can make the player/vehicle render invisible or crash with
        -- AIJobVehicle.lua: attempt to index nil with 'name'.
        specEnterable.canBeEntered = false -- EVM: MP-Client lokal sperren; TAB-Umleitung laeuft ueber installGlobalInputLocks()
        left = true
    end

    return left
end

function ExtendedVehicleMaintenance.getVehicleName(vehicle)
    return evmGetVehicleName(vehicle)
end

function ExtendedVehicleMaintenance.installEnterLock(vehicle, mode)
    if vehicle == nil or vehicle.rootNode == nil then
        return
    end

    local runtime = ExtendedVehicleMaintenance.getRuntime()
    local rootVehicle = vehicle.rootVehicle or vehicle
    local rootNode = rootVehicle.rootNode
    local existing = runtime.enterLocks[rootNode]

    if existing ~= nil then
        existing.active = true
        existing.vehicle = rootVehicle
        existing.mode = mode
        return
    end

    runtime.enterLocks[rootNode] = {
        active = true,
        vehicle = rootVehicle,
        mode = mode,
        rootNode = rootNode
    }

    ExtendedVehicleMaintenance.installGlobalInputLocks()

    if runtime._enterLockUpdateInstalled ~= true then
        local mission = g_currentMission
        if mission ~= nil then
            runtime._enterLockUpdateInstalled = true
            runtime._origMissionUpdate = mission.update

            mission.update = Utils.overwrittenFunction(mission.update, function(missionSelf, superFunc, dt)
                if superFunc ~= nil then
                    superFunc(missionSelf, dt)
                end

                local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
                if rt == nil or rt.enterLocks == nil then
                    return
                end

                for _, entry in pairs(rt.enterLocks) do
                    if entry ~= nil and entry.active and entry.vehicle ~= nil then
                        local activeSpec, activeVehicle = evmGetActiveServiceSpec(entry.vehicle)
                        if activeSpec ~= nil and evmGetServiceRemainingMs(activeSpec, activeVehicle or entry.vehicle) <= 0 then
                            ExtendedVehicleMaintenance.finishService(activeVehicle or entry.vehicle)
                        elseif activeSpec ~= nil then
                            evmClearControlledVehicleIfLocked(entry.vehicle)
                            if entry.vehicle.spec_enterable ~= nil then
                                entry.vehicle.spec_enterable.isEntered = false
                                -- EVM v12: BACKUP5-Verhalten fuer echten Service-Enter-Lock.
                                -- controller muss geloest werden, sonst kann GIANTS den Sitz lokal noch als belegt/enterbar behandeln.
                                entry.vehicle.spec_enterable.controller = nil
                                entry.vehicle.spec_enterable.controllerUserId = 0
                                entry.vehicle.spec_enterable.canBeEntered = false -- EVM: MP-Client lokal sperren; TAB-Umleitung laeuft ueber installGlobalInputLocks()
                            end
                        else
                            entry.active = false
                            if entry.vehicle.spec_enterable ~= nil then
                                entry.vehicle.spec_enterable.canBeEntered = true
                            end
                        end
                    end
                end

                -- MP-Fix: kein permanentes Persist-Resolving im Mission-Update.
                -- Der Service-State kommt per Stream/Event/Watcher. Das verhindert den 100%-Join-Haenger.
            end)
        end
    end

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.isEntered = false
        rootVehicle.spec_enterable.controller = nil
        rootVehicle.spec_enterable.controllerUserId = 0
        rootVehicle.spec_enterable.canBeEntered = false -- EVM: MP-Client lokal sperren; TAB-Umleitung laeuft ueber installGlobalInputLocks()
    end
end

function ExtendedVehicleMaintenance.removeEnterLock(vehicle)
    if vehicle == nil then
        return
    end

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime == nil or runtime.enterLocks == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local rootNode = rootVehicle.rootNode
    if rootNode == nil then
        return
    end

    runtime.enterLocks[rootNode] = nil

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.canBeEntered = true
    end
end

function ExtendedVehicleMaintenance.installHardVehicleLock(vehicle)
    if vehicle == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local lock = ExtendedVehicleMaintenance._hardLockVehicles[rootVehicle]
    if lock ~= nil then
        -- Lock ist bereits installiert. Trotzdem pruefen, ob der Spieler durch
        -- einen Race ins Fahrzeug gekommen ist - dann rauswerfen.
        if evmIsPlayerInThisVehicle ~= nil and evmIsPlayerInThisVehicle(rootVehicle) then
            ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)
        end
        return true
    end

    -- WICHTIG: Wenn der Spieler genau in dem Moment im Fahrzeug sitzt, in dem
    -- der Lock installiert wird (MP-Race: Spieler ist eingestiegen bevor das
    -- Service-Event beim Client ankam), MUSS er VOR dem Methoden-Hook rausgeworfen
    -- werden. Sonst greifen die Hooks auf Aussteig-Routinen zu und der Spieler
    -- bleibt im Fahrzeug haengen (Alt+F4-Bug).
    if evmIsPlayerInThisVehicle ~= nil and evmIsPlayerInThisVehicle(rootVehicle) then
        ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)
    end

    lock = {
        vehicle = rootVehicle,
        installedAt = g_time or 0
    }

    ExtendedVehicleMaintenance._hardLockVehicles[rootVehicle] = lock
    rootVehicle._evmHardLockActive = true

    lock.origRootStartMotor = rootVehicle.startMotor
    if type(rootVehicle.startMotor) == "function" then
        rootVehicle.startMotor = function(selfVehicle, ...)
            evmShowServiceLockWarning(selfVehicle, 2600)
            return false
        end
    end
    lock.origRootGetIsMotorStarted = rootVehicle.getIsMotorStarted
    if type(rootVehicle.getIsMotorStarted) == "function" then
        rootVehicle.getIsMotorStarted = function()
            return false
        end
    end
    lock.origRootGetCanMotorRun = rootVehicle.getCanMotorRun
    if type(rootVehicle.getCanMotorRun) == "function" then
        rootVehicle.getCanMotorRun = function()
            return false
        end
    end
    lock.origRootGetCanToggleMotor = rootVehicle.getCanToggleMotor
    if type(rootVehicle.getCanToggleMotor) == "function" then
        rootVehicle.getCanToggleMotor = function()
            return false
        end
    end

    if rootVehicle.spec_motorized ~= nil and rootVehicle.spec_motorized.motor ~= nil then
        local motor = rootVehicle.spec_motorized.motor
        lock.origStartMotor = motor.vehicle.startMotor
        lock.origGetIsMotorStarted = motor.vehicle.getIsMotorStarted
        lock.origGetIsMotorStopped = motor.vehicle.getIsMotorStopped
        lock.origGetMotorRpm = motor.vehicle.getMotorRpm
        lock.origUpdateSound = motor.vehicle.updateSound
        lock.origUpdateSmoke = motor.vehicle.updateSmoke

        motor.vehicle.startMotor = function(selfVehicle, ...)
            evmShowServiceLockWarning(selfVehicle, 2600)
            return false
        end
        motor.vehicle.getIsMotorStarted = function()
            return false
        end
        motor.vehicle.getIsMotorStopped = function()
            return true
        end
        motor.vehicle.getMotorRpm = function()
            return 0
        end
        motor.vehicle.updateSound = function() end
        motor.vehicle.updateSmoke = function() end
    end

    if rootVehicle.setSteeringInput ~= nil then
        lock.origSetSteeringInput = rootVehicle.setSteeringInput
        rootVehicle.setSteeringInput = function(selfVehicle, value, ...)
            if selfVehicle.spec_drivable ~= nil then
                selfVehicle.spec_drivable.axisSide = 0
                selfVehicle.spec_drivable.lastInputValues = selfVehicle.spec_drivable.lastInputValues or {}
                selfVehicle.spec_drivable.lastInputValues.axisSide = 0
            end
            return nil
        end
    end

    if rootVehicle.setAccelerationInput ~= nil then
        lock.origSetAccelerationInput = rootVehicle.setAccelerationInput
        rootVehicle.setAccelerationInput = function(selfVehicle, value, ...)
            if selfVehicle.spec_drivable ~= nil then
                selfVehicle.spec_drivable.axisForward = 0
                selfVehicle.spec_drivable.accelerationAxis = 0
                selfVehicle.spec_drivable.lastInputValues = selfVehicle.spec_drivable.lastInputValues or {}
                selfVehicle.spec_drivable.lastInputValues.axisForward = 0
                selfVehicle.spec_drivable.brakeInput = 1
            end
            return nil
        end
    end

    if rootVehicle.setBrakeInput ~= nil then
        lock.origSetBrakeInput = rootVehicle.setBrakeInput
        rootVehicle.setBrakeInput = function(selfVehicle, value, ...)
            if selfVehicle.spec_drivable ~= nil then
                selfVehicle.spec_drivable.brakeInput = 1
            end
            return nil
        end
    end

    -- MP-Fix: Der Einstieg muss auf JEDEM Client lokal geblockt werden.
    -- Nur die globale requestToEnterVehicle-Umleitung reicht im MP nicht immer,
    -- weil GIANTS/Mods den Enter-Vorgang teilweise direkt am Fahrzeug ausloesen.
    -- Deshalb werden hier zusaetzlich die fahrzeuglokalen Enterable-Methoden
    -- blockiert. TAB wird weiterhin ueber installGlobalInputLocks() auf das
    -- naechste freie Fahrzeug umgeleitet.
    lock.extraMethodLocks = {}

    local function blockEnter(selfVehicle, ...)
        local v = evmNormalizeVehicle(selfVehicle) or rootVehicle
        if evmIsLockedForInput(v) then
            evmShowServiceLockWarning(v, 2600)
            evmClearControlledVehicleIfLocked(v)
            return false
        end
        return nil
    end

    local function lockMethod(methodName, replacement)
        local original = rootVehicle[methodName]
        if type(original) == "function" then
            lock.extraMethodLocks[methodName] = original
            rootVehicle[methodName] = replacement(original)
        end
    end

    lockMethod("getCanBeEntered", function(original)
        return function(selfVehicle, ...)
            if evmIsLockedForInput(selfVehicle) then return false end
            return original(selfVehicle, ...)
        end
    end)

    lockMethod("getIsEnterable", function(original)
        return function(selfVehicle, ...)
            if evmIsLockedForInput(selfVehicle) then return false end
            return original(selfVehicle, ...)
        end
    end)

    lockMethod("getIsEnterableFromMenu", function(original)
        return function(selfVehicle, ...)
            if evmIsLockedForInput(selfVehicle) then return false end
            return original(selfVehicle, ...)
        end
    end)


    lockMethod("getCanStartMotor", function(original)
        return function(selfVehicle, ...)
            if evmIsLockedForInput(selfVehicle) then return false end
            return original(selfVehicle, ...)
        end
    end)

    lockMethod("getCanMotorRun", function(original)
        return function(selfVehicle, ...)
            if evmIsLockedForInput(selfVehicle) then return false end
            return original(selfVehicle, ...)
        end
    end)

    -- MP-Fix: getCanBeSelected/getCanBeUsed werden nicht mehr hart ueberschrieben.
    -- Das verhinderte TAB/AIJobVehicle im Multiplayer; Einstieg bleibt ueber Enter-Hooks gesperrt.

    -- MP-Fix: getCanBeSelected/getCanBeUsed werden nicht mehr hart ueberschrieben.
    -- Das verhinderte TAB/AIJobVehicle im Multiplayer; Einstieg bleibt ueber Enter-Hooks gesperrt.

    lockMethod("setIsEntered", function(original)
        return function(selfVehicle, isEntered, ...)
            -- WICHTIG: Aussteigen (isEntered=false) NIEMALS blocken, sonst
            -- bleibt der Spieler im Fahrzeug haengen wenn er drin war als der
            -- Service gestartet wurde (MP-Race).
            if isEntered == true and evmIsLockedForInput(selfVehicle) then
                blockEnter(selfVehicle)
                return false
            end
            return original(selfVehicle, isEntered, ...)
        end
    end)

    -- WICHTIG: 'interact' und 'requestActionEventEnter' werden NICHT mehr
    -- pauschal geblockt. 'interact' ist die generische Q-Taste-Aktion und
    -- umfasst je nach Kontext Enter UND Leave - ein Block hier verhindert
    -- das Aussteigen, was im MP zu einem Hard-Stuck-Bug fuehrt
    -- (Spieler muss Alt+F4 druecken).
    -- Der Einstieg wird zuverlaessig ueber getCanBeEntered, getIsEnterable,
    -- setIsEntered, sowie die globalen Hooks (requestToEnterVehicle,
    -- setCurrentVehicle, mission.enterVehicle) verhindert.
    for _, methodName in ipairs({
        "enterVehicle",
        "doEnterVehicle",
        "onEnterVehicle"
    }) do
        lockMethod(methodName, function(original)
            return function(selfVehicle, ...)
                local blocked = blockEnter(selfVehicle, ...)
                if blocked == false then return false end
                return original(selfVehicle, ...)
            end
        end)
    end

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.isEntered = false
                rootVehicle.spec_enterable.controller = nil -- EVM: needed to fully detach locked service vehicle; keep playerStyle/player/controllerName intact.
        rootVehicle.spec_enterable.controllerUserId = 0
        rootVehicle.spec_enterable.enteredFarmId = 0
        rootVehicle.spec_enterable.canBeEntered = false
    end

    ExtendedVehicleMaintenance.installGlobalInputLocks()
    evmClearControlledVehicleIfLocked(rootVehicle)

    return true
end

function ExtendedVehicleMaintenance.removeHardVehicleLock(vehicle)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local lock = ExtendedVehicleMaintenance._hardLockVehicles[rootVehicle]
    if lock == nil then
        return
    end

    if rootVehicle.spec_motorized ~= nil and rootVehicle.spec_motorized.motor ~= nil then
        local motorVehicle = rootVehicle.spec_motorized.motor.vehicle
        if motorVehicle ~= nil then
            if lock.origStartMotor ~= nil then
                motorVehicle.startMotor = lock.origStartMotor
            end
            if lock.origGetIsMotorStarted ~= nil then
                motorVehicle.getIsMotorStarted = lock.origGetIsMotorStarted
            end
            if lock.origGetIsMotorStopped ~= nil then
                motorVehicle.getIsMotorStopped = lock.origGetIsMotorStopped
            end
            if lock.origGetMotorRpm ~= nil then
                motorVehicle.getMotorRpm = lock.origGetMotorRpm
            end
            if lock.origUpdateSound ~= nil then
                motorVehicle.updateSound = lock.origUpdateSound
            end
            if lock.origUpdateSmoke ~= nil then
                motorVehicle.updateSmoke = lock.origUpdateSmoke
            end
        end
    end

    if lock.origRootStartMotor ~= nil then rootVehicle.startMotor = lock.origRootStartMotor end
    if lock.origRootGetIsMotorStarted ~= nil then rootVehicle.getIsMotorStarted = lock.origRootGetIsMotorStarted end
    if lock.origRootGetCanMotorRun ~= nil then rootVehicle.getCanMotorRun = lock.origRootGetCanMotorRun end
    if lock.origRootGetCanToggleMotor ~= nil then rootVehicle.getCanToggleMotor = lock.origRootGetCanToggleMotor end

    if lock.origSetSteeringInput ~= nil then
        rootVehicle.setSteeringInput = lock.origSetSteeringInput
    end
    if lock.origSetAccelerationInput ~= nil then
        rootVehicle.setAccelerationInput = lock.origSetAccelerationInput
    end
    if lock.origSetBrakeInput ~= nil then
        rootVehicle.setBrakeInput = lock.origSetBrakeInput
    end
    if lock.origGetCanBeEntered ~= nil then
        rootVehicle.getCanBeEntered = lock.origGetCanBeEntered
    end
    if lock.origGetCanBeSelected ~= nil then
        rootVehicle.getCanBeSelected = lock.origGetCanBeSelected
    end
    if lock.origGetCanBeUsed ~= nil then
        rootVehicle.getCanBeUsed = lock.origGetCanBeUsed
    end
    if lock.origGetIsEnterable ~= nil then
        rootVehicle.getIsEnterable = lock.origGetIsEnterable
    end
    if lock.origGetIsEnterableFromMenu ~= nil then
        rootVehicle.getIsEnterableFromMenu = lock.origGetIsEnterableFromMenu
    end
    if lock.origInteract ~= nil then
        rootVehicle.interact = lock.origInteract
    end

    if lock.extraMethodLocks ~= nil then
        for methodName, originalFunction in pairs(lock.extraMethodLocks) do
            if originalFunction ~= nil then
                rootVehicle[methodName] = originalFunction
            end
        end
    end

    rootVehicle._evmHardLockActive = false
    ExtendedVehicleMaintenance._hardLockVehicles[rootVehicle] = nil

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.canBeEntered = true
    end
end

function ExtendedVehicleMaintenance.enforceLockedVehicle(vehicle)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)
    ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)
    ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)
    ExtendedVehicleMaintenance.installEnterLock(rootVehicle, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
    ExtendedVehicleMaintenance.installHardVehicleLock(rootVehicle)
    ExtendedVehicleMaintenance.installGlobalInputLocks()
    evmClearControlledVehicleIfLocked(rootVehicle)

    local spec = evmGetVehicleSpec(rootVehicle)
    if spec ~= nil then
        spec.physicsFrozen = true
    end

    if rootVehicle.spec_drivable ~= nil then
        local sd = rootVehicle.spec_drivable
        sd.axisForward = 0
        sd.axisSide = 0
        sd.accelerationAxis = 0
        sd.brakeInput = 1
        sd.handBrakeActive = true
        sd.maxAcceleration = 0
        sd.maxBackwardAcceleration = 0
        if sd.cruiseControl ~= nil then
            sd.cruiseControl.state = Drivable ~= nil and Drivable.CRUISECONTROL_STATE_OFF or 0
            sd.cruiseControl.isActive = false
        end
    end
end

function ExtendedVehicleMaintenance.getResetTranslation(vehicle)
    if vehicle == nil then
        return nil
    end

    if vehicle.getResetPosition ~= nil then
        local x, y, z = vehicle:getResetPosition()
        if x ~= nil and y ~= nil and z ~= nil then
            return x, y, z
        end
    end

    if vehicle.getResetWorldPosition ~= nil then
        local x, y, z = vehicle:getResetWorldPosition()
        if x ~= nil and y ~= nil and z ~= nil then
            return x, y, z
        end
    end

    if vehicle.getOwnerFarmId ~= nil and g_currentMission ~= nil and g_currentMission.shopConfig ~= nil and g_currentMission.shopConfig.getShopSpawnPlace ~= nil then
        local ownerFarmId = vehicle:getOwnerFarmId()
        local spawnPlace = g_currentMission.shopConfig:getShopSpawnPlace(ownerFarmId)
        if spawnPlace ~= nil then
            if spawnPlace.x ~= nil and spawnPlace.y ~= nil and spawnPlace.z ~= nil then
                return spawnPlace.x, spawnPlace.y, spawnPlace.z
            end
            if spawnPlace.posX ~= nil and spawnPlace.posY ~= nil and spawnPlace.posZ ~= nil then
                return spawnPlace.posX, spawnPlace.posY, spawnPlace.posZ
            end
        end
    end

    return nil
end

function ExtendedVehicleMaintenance.resetVehicleToWorkshop(vehicle)
    if vehicle == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)
    ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)

    evmDbg("resetVehicleToWorkshop START vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))

    if rootVehicle.resetVehicle ~= nil then
        local ok, result = pcall(rootVehicle.resetVehicle, rootVehicle)
        evmDbg("resetVehicleToWorkshop resetVehicle() ok=%s result=%s vehicle=%s", tostring(ok), tostring(result), tostring(evmGetVehicleName(rootVehicle)))
        if ok then
            return true
        end
    end

    if rootVehicle.reset ~= nil then
        local ok, result = pcall(rootVehicle.reset, rootVehicle)
        evmDbg("resetVehicleToWorkshop reset() ok=%s result=%s vehicle=%s", tostring(ok), tostring(result), tostring(evmGetVehicleName(rootVehicle)))
        if ok then
            return true
        end
    end

    -- Fallback: nur Node-Teleport (Objekt bleibt erhalten)
    local x, y, z = ExtendedVehicleMaintenance.getResetTranslation(rootVehicle)
    if x == nil then
        evmDbg("resetVehicleToWorkshop FAILED: no reset position vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))
        return false
    end

    local rx, ry, rz = 0, 0, 0
    if rootVehicle.getResetRotation ~= nil then
        local ok, rrx, rry, rrz = pcall(rootVehicle.getResetRotation, rootVehicle)
        if ok and rrx ~= nil then rx, ry, rz = rrx, rry, rrz end
    end

    local rootNode = rootVehicle.rootNode
    if rootNode ~= nil and rootNode ~= 0 then
        local okPos = pcall(setWorldTranslation, rootNode, x, y, z)
        pcall(setWorldRotation, rootNode, rx, ry, rz)
        evmDbg("resetVehicleToWorkshop fallback teleport ok=%s vehicle=%s", tostring(okPos), tostring(evmGetVehicleName(rootVehicle)))
        if okPos then return true end
    end

    evmDbg("resetVehicleToWorkshop FAILED vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))
    return false
end

function ExtendedVehicleMaintenance.findVehicleAfterWorkshopReset(referenceVehicle, oldRootNode)
    local rootVehicle = referenceVehicle ~= nil and (referenceVehicle.rootVehicle or referenceVehicle) or nil
    local mission = g_currentMission
    if rootVehicle == nil or mission == nil then
        return rootVehicle
    end

    local refConfig = tostring(rootVehicle.configFileName or "")
    local refXml = tostring(rootVehicle.xmlFileName or "")
    local refType = tostring(rootVehicle.typeName or "")
    local refName = tostring(evmGetVehicleName(rootVehicle) or "")
    local refOperatingTime = evmGetOperatingTimeMs(rootVehicle)

    local ownerFarmId = nil
    if rootVehicle.getOwnerFarmId ~= nil then
        local ok, farmId = pcall(rootVehicle.getOwnerFarmId, rootVehicle)
        if ok then
            ownerFarmId = farmId
        end
    end

    local resetX, resetY, resetZ = ExtendedVehicleMaintenance.getResetTranslation(rootVehicle)

    local bestVehicle = rootVehicle
    local bestScore = -math.huge
    local seen = {}

    local function consider(candidate)
        if candidate == nil then
            return
        end

        candidate = candidate.rootVehicle or candidate
        if candidate == nil or seen[candidate] then
            return
        end
        seen[candidate] = true

        if candidate.rootNode == nil or candidate.rootNode == 0 then
            return
        end

        local score = 0

        local candConfig = tostring(candidate.configFileName or "")
        local candXml = tostring(candidate.xmlFileName or "")
        local candType = tostring(candidate.typeName or "")
        local candName = tostring(evmGetVehicleName(candidate) or "")

        if oldRootNode ~= nil and candidate.rootNode ~= oldRootNode then
            score = score + 300
        elseif candidate == rootVehicle then
            score = score + 25
        end

        if refConfig ~= "" and candConfig == refConfig then
            score = score + 220
        end
        if refXml ~= "" and candXml == refXml then
            score = score + 120
        end
        if refType ~= "" and candType == refType then
            score = score + 80
        end
        if refName ~= "" and candName == refName then
            score = score + 40
        end

        if ownerFarmId ~= nil and candidate.getOwnerFarmId ~= nil then
            local okFarm, candFarmId = pcall(candidate.getOwnerFarmId, candidate)
            if okFarm and candFarmId ~= nil then
                if candFarmId == ownerFarmId then
                    score = score + 100
                else
                    score = score - 1000
                end
            end
        end

        local opDiff = math.abs((evmGetOperatingTimeMs(candidate) or 0) - refOperatingTime)
        score = score - math.min(180, opDiff / (60 * 1000))

        if resetX ~= nil then
            local node = ExtendedVehicleMaintenance.getVehicleNode(candidate)
            local x, y, z = evmGetWorldPosition(node)
            if x ~= nil then
                local dx = x - resetX
                local dy = y - resetY
                local dz = z - resetZ
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                score = score - math.min(400, dist * 4)
                if dist <= 30 then
                    score = score + 120
                end
                if dist <= 10 then
                    score = score + 120
                end
            end
        end

        if score > bestScore then
            bestScore = score
            bestVehicle = candidate
        end
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            consider(vehicle)
        end
    end

    if mission.vehicleSystem ~= nil then
        if mission.vehicleSystem.vehicles ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicles) do
                consider(vehicle)
            end
        end
        if mission.vehicleSystem.vehicleIdToVehicle ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicleIdToVehicle) do
                consider(vehicle)
            end
        end
    end

    evmDbg("findVehicleAfterWorkshopReset ref=%s oldRootNode=%s resolved=%s resolvedRootNode=%s score=%s",
        tostring(evmGetVehicleName(rootVehicle)),
        tostring(oldRootNode),
        tostring(evmGetVehicleName(bestVehicle)),
        tostring(bestVehicle ~= nil and bestVehicle.rootNode or nil),
        tostring(bestScore))

    return bestVehicle
end


function ExtendedVehicleMaintenance.findVehicleByPersistData(data, oldRootNode)
    local mission = g_currentMission
    if data == nil or mission == nil then
        return nil
    end

    local bestVehicle = nil
    local bestScore = -math.huge
    local seen = {}

    local function consider(candidate)
        if candidate == nil then return end
        candidate = candidate.rootVehicle or candidate
        if candidate == nil or seen[candidate] then return end
        seen[candidate] = true
        if candidate.rootNode == nil or candidate.rootNode == 0 then return end
        if not evmVehicleMatchesPersist(candidate, data) then return end

        local score = 0
        if oldRootNode ~= nil and candidate.rootNode ~= oldRootNode then score = score + 500 end
        if tostring(candidate.configFileName or "") == tostring(data.configFileName or "") then score = score + 250 end
        if tostring(candidate.xmlFileName or "") == tostring(data.xmlFileName or "") then score = score + 120 end
        if tostring(candidate.typeName or "") == tostring(data.typeName or "") then score = score + 80 end
        if evmGetOwnerFarmIdSafe(candidate) == tonumber(data.ownerFarmId or 0) then score = score + 100 end

        if score > bestScore then
            bestScore = score
            bestVehicle = candidate
        end
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do consider(vehicle) end
    end
    if mission.vehicleSystem ~= nil then
        if mission.vehicleSystem.vehicles ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicles) do consider(vehicle) end
        end
        if mission.vehicleSystem.vehicleIdToVehicle ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicleIdToVehicle) do consider(vehicle) end
        end
    end

    if bestVehicle ~= nil then
        local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
        local now = g_time or 0
        local changed = runtime == nil or runtime._lastPersistResolvedRootNode ~= bestVehicle.rootNode
        if runtime ~= nil and (changed or now >= (runtime._nextPersistResolveLogTime or 0)) then
            runtime._lastPersistResolvedRootNode = bestVehicle.rootNode
            runtime._nextPersistResolveLogTime = now + 2000
            evmDbg("findVehicleByPersistData resolved=%s rootNode=%s score=%s", tostring(evmGetVehicleName(bestVehicle)), tostring(bestVehicle.rootNode), tostring(bestScore))
        end
    end
    return bestVehicle
end

function ExtendedVehicleMaintenance.enforceRuntimePersistLock(tag)
    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime == nil or runtime.active ~= true or runtime.pendingLockData == nil then
        return nil
    end

    if runtime._persistLockResolved == true and runtime.rootVehicle ~= nil then
        local resolved = runtime.rootVehicle.rootVehicle or runtime.rootVehicle
        local spec = evmGetVehicleSpec(resolved)
        if spec ~= nil and spec.isServiceActive == true then
            return resolved
        end
        runtime._persistLockResolved = false
    end

    local now = g_time or 0
    local tagText = tostring(tag or "")
    local force = tagText == "onReadStream" or tagText == "receiveServiceState" or tagText == "watcher" or string.find(tagText, "ms") ~= nil

    if not force then
        runtime._persistResolveAttempts = runtime._persistResolveAttempts or 0
        if runtime._persistResolveAttempts >= 12 then
            if runtime._persistResolveAbortedLog ~= true then
                runtime._persistResolveAbortedLog = true
                print("[EVM] Persist-Lock resolving abgebrochen: Fahrzeug konnte nach 12 Versuchen nicht sicher gefunden werden")
            end
            return runtime.rootVehicle
        end
        if now < (runtime._nextPersistResolveTryTime or 0) then
            return runtime.rootVehicle
        end
        runtime._nextPersistResolveTryTime = now + 1000
        runtime._persistResolveAttempts = runtime._persistResolveAttempts + 1
    end

    local vehicle = ExtendedVehicleMaintenance.findVehicleByPersistData(runtime.pendingLockData, runtime.pendingOldRootNode)
    if vehicle == nil then
        return runtime.rootVehicle
    end

    vehicle = vehicle.rootVehicle or vehicle
    runtime.rootVehicle = vehicle
    runtime.targets = runtime.targets or {}
    if #runtime.targets == 0 then
        table.insert(runtime.targets, vehicle)
    else
        runtime.targets[1] = vehicle
    end

    local spec = evmGetVehicleSpec(vehicle)
    if spec ~= nil then
        spec.isServiceActive = true
        spec.serviceMode = runtime.pendingLockData.serviceMode or runtime.mode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
        local pendingEndAbsHours = tonumber(runtime.pendingLockData.serviceEndAbsHours or spec.serviceEndAbsHours or 0) or 0
        local pendingRemainingMs = math.max(0, tonumber(runtime.pendingLockData.serviceRemainingGameMs or runtime.totalDurationMs or 0) or 0)

        if runtime.pendingLockData.serviceEndRealMs ~= nil and now > 0 then
            local realRemaining = evmRealMsToGameMs(math.max(0, runtime.pendingLockData.serviceEndRealMs - now))
            pendingRemainingMs = pendingRemainingMs > 0 and math.min(pendingRemainingMs, realRemaining) or realRemaining
        end

        if pendingEndAbsHours > 0 then
            spec.serviceEndAbsHours = pendingEndAbsHours
            local absRemaining = math.max(0, (pendingEndAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
            pendingRemainingMs = pendingRemainingMs > 0 and math.min(pendingRemainingMs, absRemaining) or absRemaining
        elseif (spec.serviceEndAbsHours or 0) <= 0 and pendingRemainingMs > 0 then
            spec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (pendingRemainingMs / 3600000)
        end

        spec.serviceRemainingGameMs = pendingRemainingMs
        runtime.pendingLockData.serviceRemainingGameMs = pendingRemainingMs
        runtime.pendingLockData.serviceEndAbsHours = spec.serviceEndAbsHours or runtime.pendingLockData.serviceEndAbsHours or 0
        if pendingRemainingMs > 0 and now > 0 then
            runtime.pendingLockData.serviceEndRealMs = now + evmGameMsToRealMs(pendingRemainingMs)
        end
        spec.serviceHoursToAdd = math.max(spec.serviceHoursToAdd or 0, runtime.pendingLockData.serviceHoursToAdd or 0)
        spec.serviceDaysToAdd = math.max(spec.serviceDaysToAdd or 0, runtime.pendingLockData.serviceDaysToAdd or 0)
        spec.physicsFrozen = true
        if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
            pcall(vehicle.raiseDirtyFlags, vehicle, spec.dirtyFlag)
        end
    end

    ExtendedVehicleMaintenance.forceVehicleStandstill(vehicle)
    if evmIsPlayerInThisVehicle ~= nil and evmIsPlayerInThisVehicle(vehicle) then
        ExtendedVehicleMaintenance.forceLeaveVehicle(vehicle)
    end
    ExtendedVehicleMaintenance.installEnterLock(vehicle, runtime.mode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
    ExtendedVehicleMaintenance.installHardVehicleLock(vehicle)
    evmClearControlledVehicleIfLocked(vehicle)

    runtime._persistLockResolved = true
    runtime._persistResolveAttempts = 0

    local changed = runtime._lastPersistLockRootNode ~= vehicle.rootNode
    if changed or now >= (runtime._nextPersistLockLogTime or 0) then
        runtime._lastPersistLockRootNode = vehicle.rootNode
        runtime._nextPersistLockLogTime = now + 5000
        evmDbg("enforceRuntimePersistLock[%s] vehicle=%s rootNode=%s", tostring(tag), tostring(evmGetVehicleName(vehicle)), tostring(vehicle.rootNode))
    end
    return vehicle
end

function ExtendedVehicleMaintenance.isServiceable(vehicle)
    if vehicle == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    -- Nur Fahrzeuge die man einsteigen und fahren kann (Traktoren, Mähdrescher, etc.)
    -- Geräte/Anhänger sind vorerst nicht servicierbar
    local hasMotorized = rootVehicle.spec_motorized ~= nil
    local hasEnterable = rootVehicle.spec_enterable ~= nil
    local hasWearable = rootVehicle.spec_wearable ~= nil

    if not (hasMotorized and hasEnterable) then
        return false
    end

    local canBeSelected = true
    if rootVehicle.getCanBeSelected ~= nil then
        local ok, result = pcall(rootVehicle.getCanBeSelected, rootVehicle)
        if ok then canBeSelected = result ~= false end
    end

    return canBeSelected and hasWearable
end

function ExtendedVehicleMaintenance.getNearbyServiceVehicle(playerNode)
    local mission = g_currentMission
    if mission == nil then
        return nil
    end

    local referenceNode = nil
    if mission.player ~= nil and evmIsValidNode(mission.player.rootNode) then
        referenceNode = mission.player.rootNode
    elseif evmIsValidNode(playerNode) then
        referenceNode = playerNode
    end
    if referenceNode == nil then
        return nil
    end

    local ownerFarmId = ExtendedVehicleMaintenance.getLocalFarmId()
    -- Größerer Radius für Geräte/Anhänger die man von außen serviciert
    local maxDistance = (ExtendedVehicleMaintenance.INTERACTION_RADIUS or 4.5) * 2.2
    local maxDistanceSq = maxDistance * maxDistance

    local bestVehicle = nil
    local bestDistanceSq = math.huge
    local seen = {}

    local function tryVehicle(vehicle)
        if vehicle == nil then
            return
        end

        local rootVehicle = vehicle.rootVehicle or vehicle
        if rootVehicle == nil or seen[rootVehicle] then
            return
        end
        seen[rootVehicle] = true

        if not ExtendedVehicleMaintenance.isServiceable(rootVehicle) then
            return
        end

        -- Für die normale Service-Option nur freie Fahrzeuge wählen.
        -- Aktive Wartungsfahrzeuge bekommen ihren eigenen Restzeit-Hinweis im F1-Menü.
        if ExtendedVehicleMaintenance.isVehicleInServiceOrPending(rootVehicle) then
            return
        end

        if ownerFarmId ~= nil and rootVehicle.getOwnerFarmId ~= nil then
            local okFarm, farmId = pcall(rootVehicle.getOwnerFarmId, rootVehicle)
            if okFarm and farmId ~= nil and farmId ~= ownerFarmId then
                return
            end
        end

        local distSq = evmDistanceSq(ExtendedVehicleMaintenance.getVehicleNode(rootVehicle), referenceNode)
        if distSq <= maxDistanceSq and distSq < bestDistanceSq then
            bestDistanceSq = distSq
            bestVehicle = rootVehicle
        end
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            tryVehicle(vehicle)
        end
    end

    if mission.vehicleSystem ~= nil then
        if mission.vehicleSystem.vehicles ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicles) do
                tryVehicle(vehicle)
            end
        end
        if mission.vehicleSystem.vehicleIdToVehicle ~= nil then
            for _, vehicle in pairs(mission.vehicleSystem.vehicleIdToVehicle) do
                tryVehicle(vehicle)
            end
        end
    end

    return bestVehicle
end

function ExtendedVehicleMaintenance.getNearbySelectionEntries(vehicle)
    local entries = {}
    local targetVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if targetVehicle == nil then
        return entries
    end

    if ExtendedVehicleMaintenance.isVehicleInServiceOrPending(targetVehicle) then
        return entries
    end

    local seen = {}

    local function addEntry(v)
        local root = v.rootVehicle or v
        if root == nil or seen[root] then return end
        seen[root] = true
        if not ExtendedVehicleMaintenance.isServiceable(root) then return end

        local values = ExtendedVehicleMaintenance.calculateServiceValues(root)
        local remainingHours, remainingDays = ExtendedVehicleMaintenance.getRemainingMaintenance(root)
        local cat = ExtendedVehicleMaintenance.getVehicleCategory(root)
        local lang = (g_i18n ~= nil and g_i18n.languageShort or "en")
        local catLabel = (lang == "de" and cat.label_de) or cat.label_en or cat.name

        table.insert(entries, {
            vehicle = root,
            name = values.name,
            categoryLabel = catLabel,
            cost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP),
            technicianCost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN),
            selfRepairCost = ExtendedVehicleMaintenance.getServiceModeCost(values, ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR),
            damage = values.damage,
            hoursAdded = values.hoursAdded,
            daysAdded = values.daysAdded,
            remainingHours = remainingHours,
            remainingDays = remainingDays,
            durationHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP),
            durationTechnicianHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_TECHNICIAN),
            durationSelfRepairHours = ExtendedVehicleMaintenance.getServiceModeDuration(values, ExtendedVehicleMaintenance.SERVICE_MODE_SELF_REPAIR),
        })
    end

    -- Fahrzeug/Gerät selbst
    addEntry(targetVehicle)

    -- Alle angehängten Implements rekursiv einsammeln
    local function collectImplements(v)
        if v == nil or v.getAttachedImplements == nil then return end
        local ok, implements = pcall(v.getAttachedImplements, v)
        if not ok or type(implements) ~= "table" then return end
        for _, impl in pairs(implements) do
            local obj = impl ~= nil and impl.object or nil
            if obj ~= nil then
                addEntry(obj)
                collectImplements(obj)
            end
        end
    end
    collectImplements(targetVehicle)

    return entries
end

function ExtendedVehicleMaintenance.getNearbyActionText(vehicle)
    local entries = ExtendedVehicleMaintenance.getNearbySelectionEntries(vehicle)
    if #entries > 0 then
        local entry = entries[1]
        return string.format(evmText("action_evm_openMenu", "%s service options"), tostring(entry.name or "Vehicle"))
    end
    return evmText("action_evm_noTargets", "No vehicle nearby")
end

function ExtendedVehicleMaintenance.registerGlobalWorkshopAction()
    if ExtendedVehicleMaintenance.globalWorkshopActionEventId ~= nil or g_inputBinding == nil then
        return
    end

    local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.EVM_OPEN_SERVICE, ExtendedVehicleMaintenance, ExtendedVehicleMaintenance.actionEventStartServiceGlobal, false, true, false, true, nil)
    ExtendedVehicleMaintenance.globalWorkshopActionEventId = actionEventId

    if actionEventId ~= nil then
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventActive(actionEventId, false)
    end

    -- Zusätzliche Action: Batterie laden (kein Werkstatt-Bedarf, geht überall am Fahrzeug)
    if InputAction.EVM_CHARGE_BATTERY ~= nil then
        local _, chargeEventId = g_inputBinding:registerActionEvent(InputAction.EVM_CHARGE_BATTERY, ExtendedVehicleMaintenance, ExtendedVehicleMaintenance.actionEventChargeBatteryGlobal, false, true, false, true, nil)
        ExtendedVehicleMaintenance.globalChargeActionEventId = chargeEventId
        if chargeEventId ~= nil then
            g_inputBinding:setActionEventTextPriority(chargeEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventActive(chargeEventId, false)
        end
    end
end

function ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(ExtendedVehicleMaintenance)
    end
    ExtendedVehicleMaintenance.globalWorkshopActionEventId = nil
    ExtendedVehicleMaintenance.globalChargeActionEventId = nil
    ExtendedVehicleMaintenance.activeSellingPoint = nil
end

-- Sicherstellen dass mindestens die Charge-Action existiert, damit Batterie-Laden auch
-- ohne Werkstatt in der Nähe verfügbar ist.
function ExtendedVehicleMaintenance.ensureChargeActionRegistered()
    if g_inputBinding == nil or InputAction.EVM_CHARGE_BATTERY == nil then return end
    if ExtendedVehicleMaintenance.globalChargeActionEventId ~= nil then return end
    if ExtendedVehicleMaintenance.globalWorkshopActionEventId == nil then
        -- Keine andere Action registriert → komplett neu starten.
        ExtendedVehicleMaintenance.registerGlobalWorkshopAction()
        if ExtendedVehicleMaintenance.globalWorkshopActionEventId ~= nil then
            -- Workshop-Action soll inaktiv bleiben wenn keine Werkstatt nahe.
            g_inputBinding:setActionEventActive(ExtendedVehicleMaintenance.globalWorkshopActionEventId, false)
        end
    end
end

function ExtendedVehicleMaintenance.refreshGlobalWorkshopAction(forceSellingPoint)
    local actionEventId = ExtendedVehicleMaintenance.globalWorkshopActionEventId
    if actionEventId == nil or g_inputBinding == nil then
        ExtendedVehicleMaintenance.refreshGlobalChargeAction()
        return
    end

    local sellingPoint = forceSellingPoint or ExtendedVehicleMaintenance.activeSellingPoint
    ExtendedVehicleMaintenance.activeSellingPoint = sellingPoint

    if sellingPoint ~= nil then
        if ExtendedVehicleMaintenance.isVehicleInServiceOrPending(sellingPoint) then
            g_inputBinding:setActionEventActive(actionEventId, false)
        else
            local entries = ExtendedVehicleMaintenance.getNearbySelectionEntries(sellingPoint)
            if #entries > 0 then
                g_inputBinding:setActionEventText(actionEventId, ExtendedVehicleMaintenance.getNearbyActionText(sellingPoint))
                g_inputBinding:setActionEventActive(actionEventId, true)
            else
                g_inputBinding:setActionEventActive(actionEventId, false)
            end
        end
    else
        g_inputBinding:setActionEventActive(actionEventId, false)
    end

    ExtendedVehicleMaintenance.refreshGlobalChargeAction()
end

-- Batterie-Laden-Action: unabhängig vom Werkstatt-Standort.
-- Aktiv sobald man in einem Fahrzeug sitzt (oder daneben steht) und die Batterie unter Schwelle liegt.
function ExtendedVehicleMaintenance.refreshGlobalChargeAction()
    local chargeId = ExtendedVehicleMaintenance.globalChargeActionEventId
    if chargeId == nil or g_inputBinding == nil then return end

    local vehicle = ExtendedVehicleMaintenance.getChargeBatteryTargetVehicle()
    ExtendedVehicleMaintenance.activeChargeVehicle = vehicle

    if vehicle == nil then
        g_inputBinding:setActionEventActive(chargeId, false)
        return
    end

    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then
        g_inputBinding:setActionEventActive(chargeId, false)
        return
    end

    -- Bereits im Ladevorgang? Anzeigen aber Action sperren (Status-Anzeige).
    if spec._batteryChargingUntil ~= nil and (g_time or 0) < spec._batteryChargingUntil then
        local remMin = math.ceil((spec._batteryChargingUntil - (g_time or 0)) / 60000)
        g_inputBinding:setActionEventText(chargeId, string.format(evmText("action_evm_chargeBatteryStarted", "Battery charging on %s for %d minutes"), tostring(evmGetVehicleName(vehicle)), remMin))
        g_inputBinding:setActionEventActive(chargeId, false)
        return
    end

    local charge = tonumber(spec.batteryCharge) or 1.0
    if charge >= ExtendedVehicleMaintenance.BATTERY_CHARGE_THRESHOLD then
        g_inputBinding:setActionEventActive(chargeId, false)
        return
    end

    local cost = ExtendedVehicleMaintenance.BATTERY_CHARGE_COST
    local mins = ExtendedVehicleMaintenance.BATTERY_CHARGE_DURATION_MIN
    local moneyText = string.format("%d €", cost)
    if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
        local ok, m = pcall(function() return g_i18n:formatMoney(cost, 0, true, true) end)
        if ok and m ~= nil then moneyText = m end
    end
    local label = string.format(evmText("action_evm_chargeBattery", "Charge battery (%s, %s, %d min)"),
        tostring(evmGetVehicleName(vehicle)), tostring(moneyText), mins)
    g_inputBinding:setActionEventText(chargeId, label)
    g_inputBinding:setActionEventActive(chargeId, true)
end

-- Findet ein Ziel zum Batterie-Laden: Fahrzeug in dem der Spieler sitzt, oder ein nahes Fahrzeug.
function ExtendedVehicleMaintenance.getChargeBatteryTargetVehicle()
    local mission = g_currentMission
    if mission ~= nil and mission.controlledVehicle ~= nil then
        local controlled = mission.controlledVehicle.rootVehicle or mission.controlledVehicle
        if controlled ~= nil and ExtendedVehicleMaintenance.isServiceable(controlled) then
            return controlled
        end
    end
    local playerNode = ExtendedVehicleMaintenance.getPlayerRootNode()
    if not evmIsValidNode(playerNode) then return nil end
    return ExtendedVehicleMaintenance.getNearbyServiceVehicle(playerNode)
end

-- Handler: Action gedrückt → Batterie laden starten.
function ExtendedVehicleMaintenance.actionEventChargeBatteryGlobal(_, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 then return end

    local vehicle = ExtendedVehicleMaintenance.activeChargeVehicle
    if vehicle == nil then return end

    ExtendedVehicleMaintenance.startBatteryCharging(vehicle)
end

-- Startet Ladevorgang. Auf MP-Client wird ein Event an den Server geschickt.
function ExtendedVehicleMaintenance.startBatteryCharging(vehicle)
    if vehicle == nil then return end
    vehicle = vehicle.rootVehicle or vehicle

    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return end

    local charge = tonumber(spec.batteryCharge) or 1.0
    if charge >= ExtendedVehicleMaintenance.BATTERY_CHARGE_THRESHOLD then
        if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
            g_currentMission:showBlinkingWarning(string.format(evmText("action_evm_chargeBatteryNotNeeded", "Battery already full on %s"), tostring(evmGetVehicleName(vehicle))), 2000)
        end
        return
    end

    -- Bereits im Ladevorgang?
    if spec._batteryChargingUntil ~= nil and (g_time or 0) < spec._batteryChargingUntil then
        return
    end

    if g_server ~= nil then
        ExtendedVehicleMaintenance.applyBatteryCharging(vehicle)
    elseif EVMChargeBatteryEvent ~= nil and EVMChargeBatteryEvent.sendEvent ~= nil then
        EVMChargeBatteryEvent.sendEvent(vehicle)
    end
end

-- Wird auf dem Server ausgeführt: Geld abziehen, Lock setzen, Charge füllen,
-- nach 15 Echtzeit-Minuten freigeben.
function ExtendedVehicleMaintenance.applyBatteryCharging(vehicle)
    if vehicle == nil or g_server == nil then return end
    vehicle = vehicle.rootVehicle or vehicle

    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return end

    local cost = ExtendedVehicleMaintenance.BATTERY_CHARGE_COST
    local durationMs = ExtendedVehicleMaintenance.BATTERY_CHARGE_DURATION_MIN * 60 * 1000

    -- Geld abziehen
    local farmId = (vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId()) or 1
    if g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
        pcall(g_currentMission.addMoney, g_currentMission, -cost, farmId, MoneyType.SHOP_VEHICLE_REPAIR or MoneyType.OTHER, true, true)
    end

    -- Lock und Charging-State setzen
    local now = g_time or 0
    spec._batteryChargingUntil = now + durationMs
    spec._batteryChargingStartedAt = now

    -- Sofort die Batterie auf 100% setzen — physisch lädt sie zwar 15min,
    -- aber das simulieren wir nur über den Lock. Beim Beenden ist sie voll.
    spec.batteryCharge = 1.0
    spec.batteryVoltage = 12.7
    if spec.failureType == "battery" then
        spec.failureType = ""
        spec.failureSeverity = 0
        ExtendedVehicleMaintenance.restoreBatteryFailure(vehicle)
    end

    -- Fahrzeug sperren wie beim Service
    ExtendedVehicleMaintenance.installEnterLock(vehicle, ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP or 1)
    ExtendedVehicleMaintenance.installHardVehicleLock(vehicle)

    if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        pcall(vehicle.raiseDirtyFlags, vehicle, spec.dirtyFlag)
    end

    -- Server pushed neuen State an Clients
    if EVMBatteryStateEvent ~= nil and EVMBatteryStateEvent.sendEvent ~= nil then
        EVMBatteryStateEvent.sendEvent(vehicle, 1.0, 12.7, "", 0)
    end

    -- Watcher: nach Ablauf entsperren
    local runtime = ExtendedVehicleMaintenance.getRuntime ~= nil and ExtendedVehicleMaintenance.getRuntime() or nil
    if runtime ~= nil then
        runtime._serviceWatchers = runtime._serviceWatchers or {}
        table.insert(runtime._serviceWatchers, {
            triggerTime = now + durationMs,
            callback = function()
                ExtendedVehicleMaintenance.finishBatteryCharging(vehicle)
            end
        })
    end

    print(string.format("[EVM] Battery charging started on %s for %d min", tostring(evmGetVehicleName(vehicle)), ExtendedVehicleMaintenance.BATTERY_CHARGE_DURATION_MIN))
end

function ExtendedVehicleMaintenance.finishBatteryCharging(vehicle)
    if vehicle == nil then return end
    vehicle = vehicle.rootVehicle or vehicle

    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return end

    spec._batteryChargingUntil = nil
    spec._batteryChargingStartedAt = nil

    -- Locks entfernen
    ExtendedVehicleMaintenance.removeHardVehicleLock(vehicle)
    if vehicle.spec_enterable ~= nil then
        vehicle.spec_enterable.canBeEntered = true
    end

    print(string.format("[EVM] Battery charging finished on %s", tostring(evmGetVehicleName(vehicle))))
end

function ExtendedVehicleMaintenance.findNearbySellingPoint()
    -- Wenn man im Fahrzeug sitzt: das Fahrzeug selbst ist der Service-Ankerpunkt
    local mission = g_currentMission
    if mission ~= nil and mission.controlledVehicle ~= nil then
        local controlled = mission.controlledVehicle.rootVehicle or mission.controlledVehicle
        if ExtendedVehicleMaintenance.isServiceable(controlled) then
            return controlled
        end
    end
    local playerNode = ExtendedVehicleMaintenance.getPlayerRootNode()
    if not evmIsValidNode(playerNode) then
        return nil
    end
    return ExtendedVehicleMaintenance.getNearbyServiceVehicle(playerNode)
end

function ExtendedVehicleMaintenance.actionEventStartServiceAtWorkshop(vehicle, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 or vehicle == nil then
        return
    end

    if ExtendedVehicleMaintenance.isVehicleLocked(vehicle) then
        evmShowServiceLockWarning(vehicle, 2600)
        return
    end

    local entries = ExtendedVehicleMaintenance.getNearbySelectionEntries(vehicle)
    if #entries == 0 then
        if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
            g_currentMission:showBlinkingWarning(evmText("action_evm_noTargets", "No vehicle nearby"), 2000)
        end
        return
    end

    if EVMServiceDialog ~= nil and EVMServiceDialog.show ~= nil then
        EVMServiceDialog.show(vehicle)
    end
end

function ExtendedVehicleMaintenance.actionEventStartServiceGlobal(_, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 then
        return
    end

    local vehicle = ExtendedVehicleMaintenance.activeSellingPoint
    if vehicle == nil then
        return
    end

    ExtendedVehicleMaintenance.actionEventStartServiceAtWorkshop(vehicle, actionName, inputValue, callbackState, isAnalog)
end


function ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(vehicle)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle

    -- Always clear both lock layers. This is intentionally safe to call multiple times.
    if ExtendedVehicleMaintenance.removeEnterLock ~= nil then
        pcall(ExtendedVehicleMaintenance.removeEnterLock, rootVehicle)
    end
    if ExtendedVehicleMaintenance.removeHardVehicleLock ~= nil then
        pcall(ExtendedVehicleMaintenance.removeHardVehicleLock, rootVehicle)
    end

    local spec = evmGetVehicleSpec(rootVehicle)
    if spec ~= nil then
        spec.isServiceActive = false
        spec.serviceMode = 0
        spec.serviceRemainingGameMs = 0
        spec.serviceEndAbsHours = 0
        spec.serviceHoursToAdd = 0
        spec.serviceDaysToAdd = 0
        spec.physicsFrozen = false
    end

    if rootVehicle.spec_enterable ~= nil then
        rootVehicle.spec_enterable.canBeEntered = true
    end

    if rootVehicle.spec_drivable ~= nil then
        local sd = rootVehicle.spec_drivable
        local saved = rootVehicle._evmSavedServiceDrivableState

        sd.axisForward = 0
        sd.axisSide = 0
        sd.accelerationAxis = 0
        sd.brakeInput = saved ~= nil and saved.brakeInput or 0
        sd.handBrakeActive = saved ~= nil and saved.handBrakeActive or false

        -- If this vehicle was already locked by an older build, no saved values exist.
        -- In that case actively recover from the stuck state instead of leaving zeros behind.
        if saved ~= nil then
            sd.maxAcceleration = saved.maxAcceleration
            sd.maxBackwardAcceleration = saved.maxBackwardAcceleration
        else
            if tonumber(sd.maxAcceleration or 0) <= 0 then sd.maxAcceleration = 1 end
            if tonumber(sd.maxBackwardAcceleration or 0) <= 0 then sd.maxBackwardAcceleration = 1 end
        end

        if sd.lastInputValues ~= nil then
            sd.lastInputValues.axisForward = 0
            sd.lastInputValues.axisSide = 0
        end
        if sd.cruiseControl ~= nil then
            sd.cruiseControl.state = Drivable ~= nil and Drivable.CRUISECONTROL_STATE_OFF or 0
            sd.cruiseControl.isActive = false
        end

        rootVehicle._evmSavedServiceDrivableState = nil
    end

    rootVehicle._evmHardLockActive = false

    evmDbg("restoreVehicleAfterServiceUnlock vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))
end

function ExtendedVehicleMaintenance.applyServiceState(vehicle, isActive, mode, durationMs, hoursAdded, daysAdded)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(rootVehicle)
    if spec == nil then
        if isActive == true and evmCreateRuntimeSpec ~= nil then
            spec = evmCreateRuntimeSpec(rootVehicle)
            if spec ~= nil then
                print(string.format("[EVM] v13 receiveServiceState: runtime spec created for service lock vehicle=%s", tostring(evmGetVehicleName(rootVehicle))))
            end
        end
        if spec == nil then
            print(string.format("[EVM] v13 receiveServiceState ignored: missing spec vehicle=%s active=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(isActive)))
            return
        end
    end

    local wasServiceActive = spec.isServiceActive == true
    local previousEndAbsHours = tonumber(spec.serviceEndAbsHours or 0) or 0
    local previousRemainingMs = tonumber(spec.serviceRemainingGameMs or 0) or 0

    spec.isServiceActive = isActive == true
    spec.serviceMode = spec.isServiceActive and (tonumber(mode) or 1) or 0

    if spec.isServiceActive then
        local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
        local pendingEndAbsHours = 0
        -- BUGFIX (zwei identische Trecker): strikt per Objekt-Identitaet pruefen,
        -- damit bei zwei baugleichen Treckern nicht versehentlich Service-Endzeit
        -- vom anderen Trecker uebernommen wird.
        if runtime ~= nil and runtime.pendingLockData ~= nil and evmIsRuntimeServiceVehicle(rootVehicle, runtime) then
            pendingEndAbsHours = tonumber(runtime.pendingLockData.serviceEndAbsHours or 0) or 0
        end

        if pendingEndAbsHours > ExtendedVehicleMaintenance.getCurrentAbsHours() then
            spec.serviceEndAbsHours = pendingEndAbsHours
            spec.serviceRemainingGameMs = math.max(0, (spec.serviceEndAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
        elseif wasServiceActive and previousEndAbsHours > ExtendedVehicleMaintenance.getCurrentAbsHours() then
            spec.serviceEndAbsHours = previousEndAbsHours
            spec.serviceRemainingGameMs = math.max(0, (spec.serviceEndAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
        else
            spec.serviceRemainingGameMs = math.max(0, tonumber(durationMs) or previousRemainingMs or 0)
            spec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (spec.serviceRemainingGameMs / 3600000)
        end
    else
        spec.serviceRemainingGameMs = 0
        spec.serviceEndAbsHours = 0
        if ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock ~= nil then
            ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(rootVehicle)
        end
    end

    spec.serviceHoursToAdd = spec.isServiceActive and math.max(0, tonumber(hoursAdded) or 0) or 0
    spec.serviceDaysToAdd = spec.isServiceActive and math.max(0, tonumber(daysAdded) or 0) or 0
    spec.lastTickGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.batteryCharge = evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1)
    spec.batteryVoltage = evmClamp(tonumber(spec.batteryVoltage) or 12.7, 6.0, 15.5)
    spec.physicsFrozen = spec.isServiceActive

    if spec.isServiceActive then
        ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
        local runtime = ExtendedVehicleMaintenance.getRuntime()
        runtime.pendingLockData = runtime.pendingLockData or evmBuildPersistRuntimeData(rootVehicle, spec.serviceMode, spec.serviceRemainingGameMs, spec.serviceHoursToAdd, spec.serviceDaysToAdd)
        runtime.pendingOldRootNode = runtime.pendingOldRootNode or rootVehicle.rootNode
        runtime.active = true
        runtime.mode = spec.serviceMode
    end

    if rootVehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        rootVehicle:raiseDirtyFlags(spec.dirtyFlag)
    end

    evmDbg("applyServiceState vehicle=%s active=%s mode=%s remainingMs=%s hoursAdd=%s daysAdd=%s",
        tostring(evmGetVehicleName(rootVehicle)),
        tostring(spec.isServiceActive),
        tostring(spec.serviceMode),
        tostring(spec.serviceRemainingGameMs),
        tostring(spec.serviceHoursToAdd),
        tostring(spec.serviceDaysToAdd))
end

function ExtendedVehicleMaintenance.receiveServiceStateFromServer(vehicle, isActive, mode, remainingMs, endAbsHours, hoursAdded, daysAdded)
    if vehicle == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(rootVehicle)
    if spec == nil then
        if isActive == true then
            spec = evmCreateRuntimeSpec(rootVehicle)
            if spec ~= nil then
                print(string.format("[EVM] v13 receiveServiceState: runtime spec created for service lock vehicle=%s", tostring(evmGetVehicleName(rootVehicle))))
            end
        end
        if spec == nil then
            print(string.format("[EVM] v13 receiveServiceState ignored: missing spec vehicle=%s active=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(isActive)))
            return
        end
    end

    spec.isServiceActive = isActive == true
    spec.serviceMode = spec.isServiceActive and (tonumber(mode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP) or 0
    spec.serviceRemainingGameMs = spec.isServiceActive and math.max(0, tonumber(remainingMs) or 0) or 0
    spec.serviceEndAbsHours = spec.isServiceActive and (tonumber(endAbsHours) or 0) or 0
    spec.serviceHoursToAdd = spec.isServiceActive and math.max(0, tonumber(hoursAdded) or 0) or 0
    spec.serviceDaysToAdd = spec.isServiceActive and math.max(0, tonumber(daysAdded) or 0) or 0
    spec.physicsFrozen = spec.isServiceActive
    spec.lastTickGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()

    if spec.isServiceActive and spec.serviceEndAbsHours <= 0 and spec.serviceRemainingGameMs > 0 then
        spec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (spec.serviceRemainingGameMs / 3600000)
    end

    local runtime = ExtendedVehicleMaintenance.getRuntime()
    if spec.isServiceActive then
        runtime.active = true
        runtime.mode = spec.serviceMode
        runtime.rootVehicle = rootVehicle
        runtime.targets = { rootVehicle }
        runtime.totalDurationMs = spec.serviceRemainingGameMs
        runtime.pendingOldRootNode = rootVehicle.rootNode
        runtime.pendingLockData = evmBuildPersistRuntimeData(rootVehicle, spec.serviceMode, spec.serviceRemainingGameMs, spec.serviceHoursToAdd, spec.serviceDaysToAdd)
        if runtime.pendingLockData ~= nil then
            runtime.pendingLockData.serviceEndAbsHours = spec.serviceEndAbsHours or 0
        end

        runtime._persistLockResolved = true
        ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)
        if evmIsPlayerInThisVehicle ~= nil and evmIsPlayerInThisVehicle(rootVehicle) then
            ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)
        end
        ExtendedVehicleMaintenance.installEnterLock(rootVehicle, spec.serviceMode)
        ExtendedVehicleMaintenance.installHardVehicleLock(rootVehicle)
        ExtendedVehicleMaintenance.installGlobalInputLocks()
        evmClearControlledVehicleIfLocked(rootVehicle)
    else
        ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(rootVehicle)
        if runtime.rootVehicle == rootVehicle then
            runtime.active = false
            runtime.mode = 0
            runtime.rootVehicle = nil
            runtime.targets = {}
            runtime.totalDurationMs = 0
            runtime.pendingLockData = nil
            runtime.pendingOldRootNode = nil
            runtime.syntheticLockSpec = nil
        end
    end

    evmDbg("receiveServiceStateFromServer vehicle=%s active=%s mode=%s remainingMs=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(spec.isServiceActive), tostring(spec.serviceMode), tostring(spec.serviceRemainingGameMs))
end

function ExtendedVehicleMaintenance.broadcastServiceState(vehicle, isActive)
    if vehicle == nil or g_server == nil or EVMServiceStateEvent == nil or EVMServiceStateEvent.sendEvent == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(rootVehicle)
    if spec == nil then
        return
    end

    local remaining = 0
    if isActive == true then
        remaining = evmGetServiceRemainingMs(spec, rootVehicle)
    end

    EVMServiceStateEvent.sendEvent(
        rootVehicle,
        isActive == true,
        spec.serviceMode or 0,
        remaining,
        spec.serviceEndAbsHours or 0,
        spec.serviceHoursToAdd or 0,
        spec.serviceDaysToAdd or 0
    )
end

function ExtendedVehicleMaintenance:tryStartService(rootVehicle, targets, mode, totalCost, totalDurationMs)
    if rootVehicle == nil then
        print("[EVM] tryStartService abort: rootVehicle nil")
        return false
    end

    local function isVehicleObject(vehicle)
        return type(vehicle) == "table" and vehicle.rootNode ~= nil
    end

    rootVehicle = rootVehicle.rootVehicle or rootVehicle
    local serviceMode = mode or self.SERVICE_MODE_WORKSHOP

    local cleanTargets = {}
    if type(targets) == "table" then
        for i = 1, #targets do
            local vehicle = targets[i]
            if isVehicleObject(vehicle) then
                table.insert(cleanTargets, vehicle.rootVehicle or vehicle)
            else
                print(string.format("[EVM] tryStartService ignored invalid target at index %s type=%s value=%s", tostring(i), type(vehicle), tostring(vehicle)))
            end
        end
    end

    if #cleanTargets == 0 then
        table.insert(cleanTargets, rootVehicle)
        print(string.format("[EVM] tryStartService fallback: inserted rootVehicle as target (%s)", evmGetVehicleLabel(rootVehicle)))
    end

    local oldRootNode = rootVehicle.rootNode
    local activeVehicle = rootVehicle
    local runtime = ExtendedVehicleMaintenance.getRuntime()
    runtime.pendingLockData = nil
    runtime.pendingOldRootNode = oldRootNode
    runtime._persistLockResolved = false
    runtime._persistResolveAttempts = 0
    runtime._persistResolveAbortedLog = false
    runtime._nextPersistResolveTryTime = 0

    if serviceMode == self.SERVICE_MODE_WORKSHOP then
        print(string.format("[EVM] tryStartService workshop mode PRE-RESET vehicle=%s", evmGetVehicleLabel(rootVehicle)))

        ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)
        ExtendedVehicleMaintenance.forceLeaveVehicle(rootVehicle)
        ExtendedVehicleMaintenance.forceVehicleStandstill(rootVehicle)

        -- MP-Fix: Failure-Effekte (Flat Tire, Engine, etc.) VOR dem Reset
        -- clearen. Nach resetVehicle streamt FS25 das Fahrzeug neu an alle
        -- Clients. Wenn failureType noch gesetzt ist, wuerde der Client
        -- onReadStream applyFlatTire aufrufen und die Effekte explodieren
        -- (die weissen Quadrate / Particle-Bugs im Screenshot).
        ExtendedVehicleMaintenance.clearFailure(rootVehicle)

        local persistValues = ExtendedVehicleMaintenance.calculateServiceValues(rootVehicle)
        runtime.pendingLockData = evmBuildPersistRuntimeData(rootVehicle, serviceMode, totalDurationMs or 0, persistValues.hoursAdded or 0, persistValues.daysAdded or 0)
        runtime.pendingOldRootNode = oldRootNode
        ExtendedVehicleMaintenance.evmWritePersist(
            rootVehicle,
            serviceMode,
            totalDurationMs or 0,
            persistValues.hoursAdded or 0,
            persistValues.daysAdded or 0
        )

        local okReset, resultReset = pcall(ExtendedVehicleMaintenance.resetVehicleToWorkshop, rootVehicle)
        if not okReset then
            print(string.format("[EVM] tryStartService workshop mode reset FAILED vehicle=%s err=%s", evmGetVehicleLabel(rootVehicle), tostring(resultReset)))
            return false
        end

        print(string.format("[EVM] tryStartService workshop mode reset vehicle=%s ok=%s oldRootNode=%s", evmGetVehicleLabel(rootVehicle), tostring(resultReset), tostring(oldRootNode)))

        activeVehicle = ExtendedVehicleMaintenance.findVehicleByPersistData(runtime.pendingLockData, oldRootNode) or ExtendedVehicleMaintenance.findVehicleAfterWorkshopReset(rootVehicle, oldRootNode) or rootVehicle
    end

    activeVehicle = activeVehicle.rootVehicle or activeVehicle
    if activeVehicle == nil or not isVehicleObject(activeVehicle) then
        print("[EVM] tryStartService abort: activeVehicle invalid")
        return false
    end

    local remappedTargets = {}
    for i = 1, #cleanTargets do
        local target = cleanTargets[i]
        target = target.rootVehicle or target
        if target == rootVehicle then
            table.insert(remappedTargets, activeVehicle)
        else
            table.insert(remappedTargets, target)
        end
    end

    ExtendedVehicleMaintenance.removeEnterLock(rootVehicle)
    ExtendedVehicleMaintenance.removeHardVehicleLock(rootVehicle)

    if activeVehicle ~= rootVehicle then
        ExtendedVehicleMaintenance.removeEnterLock(activeVehicle)
        ExtendedVehicleMaintenance.removeHardVehicleLock(activeVehicle)
    end

    local farmId = evmGetOwnerFarmIdSafe(activeVehicle)
    local cost = tonumber(totalCost) or 0
    if cost > 0 and g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
        local moneyType = MoneyType ~= nil and (MoneyType.VEHICLE_REPAIR or MoneyType.REPAIR_VEHICLE or 10) or 10
        pcall(g_currentMission.addMoney, g_currentMission, -cost, farmId, moneyType, true, true)
        print(string.format("[EVM] deducted cost=%.0f farmId=%s", cost, tostring(farmId)))
    end

    runtime.active = true
    runtime.mode = serviceMode
    runtime.rootVehicle = activeVehicle
    runtime.targets = remappedTargets
    runtime.totalCost = totalCost or 0
    runtime.totalDurationMs = totalDurationMs or 0
    runtime.startTime = g_time or 0
    runtime.endTime = (g_time or 0) + (totalDurationMs or 0)
    runtime._serviceWatchers = runtime._serviceWatchers or {}

    local function applyStateToTargets()
        for i = 1, #runtime.targets do
            local target = runtime.targets[i]
            if target ~= nil then
                local values = ExtendedVehicleMaintenance.calculateServiceValues(target)
                ExtendedVehicleMaintenance.applyServiceState(
                    target,
                    true,
                    serviceMode,
                    totalDurationMs or 0,
                    values.hoursAdded or 0,
                    values.daysAdded or 0
                )
            end
        end
    end

    local function resolveAndSwitchActiveVehicle(tag)
        if serviceMode ~= self.SERVICE_MODE_WORKSHOP then
            return
        end

        local resolvedVehicle = ExtendedVehicleMaintenance.findVehicleByPersistData(runtime.pendingLockData, oldRootNode) or ExtendedVehicleMaintenance.findVehicleAfterWorkshopReset(activeVehicle, oldRootNode)
        if resolvedVehicle == nil then
            return
        end

        resolvedVehicle = resolvedVehicle.rootVehicle or resolvedVehicle

        if resolvedVehicle ~= activeVehicle then
            local oldVehicle = activeVehicle

            print(string.format(
                "[EVM] tryStartService switched active vehicle tag=%s old=%s oldRootNode=%s new=%s newRootNode=%s",
                tostring(tag),
                evmGetVehicleLabel(oldVehicle),
                tostring(oldVehicle ~= nil and oldVehicle.rootNode or nil),
                evmGetVehicleLabel(resolvedVehicle),
                tostring(resolvedVehicle.rootNode)
            ))

            ExtendedVehicleMaintenance.applyServiceState(oldVehicle, false, 0, 0, 0, 0)
            ExtendedVehicleMaintenance.removeEnterLock(oldVehicle)
            ExtendedVehicleMaintenance.removeHardVehicleLock(oldVehicle)

            activeVehicle = resolvedVehicle
            runtime.rootVehicle = activeVehicle

            for i = 1, #runtime.targets do
                local target = runtime.targets[i]
                if target == oldVehicle or target == rootVehicle then
                    runtime.targets[i] = activeVehicle
                end
            end
        end
    end

    local function enforceRuntimeState(tag)
        resolveAndSwitchActiveVehicle(tag)

        if activeVehicle == nil or not isVehicleObject(activeVehicle) then
            print(string.format("[EVM] enforceRuntimeState[%s] activeVehicle invalid", tostring(tag)))
            return
        end

        ExtendedVehicleMaintenance.forceLeaveVehicle(activeVehicle)
        ExtendedVehicleMaintenance.forceVehicleStandstill(activeVehicle)
        ExtendedVehicleMaintenance.installEnterLock(activeVehicle, serviceMode)
        ExtendedVehicleMaintenance.installHardVehicleLock(activeVehicle)
        applyStateToTargets()

        print(string.format(
            "[EVM] enforceRuntimeState[%s] active=%s rootNode=%s targets=%s mode=%s durationMs=%s",
            tostring(tag),
            evmGetVehicleLabel(activeVehicle),
            tostring(activeVehicle.rootNode),
            tostring(#runtime.targets),
            tostring(serviceMode),
            tostring(totalDurationMs)
        ))
    end

    -- Im Workshop-Mode: resetVehicle() erstellt das Fahrzeug-Objekt neu.
    -- onLoad() des neuen Objekts liest evm_resetPersist.xml und setzt
    -- isServiceActive=true. Das passiert ASYNCHRON nach tryStartService.
    -- Den initialen enforceRuntimeState/Broadcast erst aus dem Watcher
    -- aufrufen, damit das neue Objekt schon vollstaendig geladen ist.
    if serviceMode ~= self.SERVICE_MODE_WORKSHOP then
        enforceRuntimeState("initial")
        ExtendedVehicleMaintenance.broadcastServiceState(activeVehicle, true)
    end

    -- MP-Fix: broadcastServiceState mehrmals delayed wiederholen.
    -- Direkt nach tryStartService kann das Vehicle bei einigen Clients noch
    -- nicht im Network-Scope sein (insbesondere bei Workshop-Reset, aber auch
    -- bei langsamen Verbindungen). Das wiederholte Senden stellt sicher, dass
    -- jeder Client zuverlaessig den Service-State und damit Lock + Countdown
    -- bekommt. Das Watcher-System wird unten fuer Workshop-Mode bereits
    -- benutzt; hier ergaenzen wir Broadcast-Watcher fuer ALLE Modi.
    runtime._serviceWatchers = runtime._serviceWatchers or {}

    local function addBroadcastWatcher(delay)
        table.insert(runtime._serviceWatchers, {
            triggerTime = (g_time or 0) + delay,
            callback = function()
                local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
                if rt == nil or rt.rootVehicle == nil then return end
                local v = rt.rootVehicle
                local s = evmGetVehicleSpec(v)
                if s ~= nil and s.isServiceActive == true then
                    ExtendedVehicleMaintenance.broadcastServiceState(v, true)
                    if v.raiseDirtyFlags ~= nil and s.dirtyFlag ~= nil then
                        pcall(v.raiseDirtyFlags, v, s.dirtyFlag)
                    end
                end
            end
        })
    end

    addBroadcastWatcher(200)
    addBroadcastWatcher(750)
    addBroadcastWatcher(2000)

    if serviceMode == self.SERVICE_MODE_WORKSHOP then
        runtime._serviceWatchers = runtime._serviceWatchers or {}

        local function addWatcher(delay, tag)
            table.insert(runtime._serviceWatchers, {
                triggerTime = (g_time or 0) + delay,
                callback = function()
                    -- Nach resetVehicle neues Objekt suchen
                    local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
                    if rt ~= nil and rt.pendingLockData ~= nil then
                        local found = ExtendedVehicleMaintenance.findVehicleByPersistData(rt.pendingLockData, rt.pendingOldRootNode)
                        if found ~= nil then
                            rt.rootVehicle = found.rootVehicle or found
                        end
                    end
                    enforceRuntimeState(tag)
                    -- Broadcast mit dem (ggf. neuen) Objekt
                    local v = rt ~= nil and rt.rootVehicle or nil
                    if v ~= nil then
                        local s = evmGetVehicleSpec(v)
                        if s ~= nil and s.isServiceActive == true then
                            ExtendedVehicleMaintenance.broadcastServiceState(v, true)
                            if v.raiseDirtyFlags ~= nil and s.dirtyFlag ~= nil then
                                pcall(v.raiseDirtyFlags, v, s.dirtyFlag)
                            end
                        end
                    end
                end
            })
        end

        addWatcher(300,  "300ms")
        addWatcher(600,  "600ms")
        addWatcher(1200, "1200ms")
        addWatcher(2500, "2500ms")
        addWatcher(5000, "5000ms")
    end

    print(string.format(
        "[EVM] service active set target=%s root=%s mode=%s rootNode=%s",
        evmGetVehicleLabel(activeVehicle),
        evmGetVehicleLabel(activeVehicle),
        tostring(serviceMode),
        tostring(activeVehicle.rootNode)
    ))

    print(string.format(
        "[EVM] tryStartService success: mode=%s targets=%s cost=%s durationMs=%s",
        tostring(serviceMode),
        tostring(#runtime.targets),
        tostring(runtime.totalCost),
        tostring(runtime.totalDurationMs)
    ))

    if g_server ~= nil and ExtendedVehicleMaintenance.evmSaveAllVehicleStates ~= nil then
        pcall(ExtendedVehicleMaintenance.evmSaveAllVehicleStates)
    end

    return true
end

function ExtendedVehicleMaintenance.finishService(vehicle)
    local rootVehicle = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(rootVehicle)
    if spec == nil then
        return
    end

    evmDbg("finishService START vehicle=%s", tostring(evmGetVehicleName(rootVehicle)))

    local remainingHours, remainingDays = ExtendedVehicleMaintenance.getRemainingMaintenance(rootVehicle)

    spec.hoursPool = evmClamp(remainingHours + (spec.serviceHoursToAdd or 0), 0, ExtendedVehicleMaintenance.MAX_HOURS)
    spec.daysPool = evmClamp(remainingDays + (spec.serviceDaysToAdd or 0), 0, ExtendedVehicleMaintenance.MAX_DAYS)
    spec.lastServiceOperatingTimeMs = evmGetOperatingTimeMs(rootVehicle)
    spec.lastServiceGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.isServiceActive = false
    spec.serviceRemainingGameMs = 0
    spec.serviceEndAbsHours = 0
    spec.serviceHoursToAdd = 0
    spec.serviceDaysToAdd = 0
    spec.lastTickGameTimeMs = spec.lastServiceGameTimeMs
    spec.serviceMode = 0
    spec.physicsFrozen = false

    -- Geräte: Arbeitsbereich nach Wartung wieder aktivieren
    if rootVehicle.spec_motorized == nil and rootVehicle.spec_workArea ~= nil and rootVehicle.spec_workArea.workAreas ~= nil then
        for _, wa in ipairs(rootVehicle.spec_workArea.workAreas) do
            wa.isEnabled = true
        end
    end

    ExtendedVehicleMaintenance.evmClearPersist(rootVehicle)

    local repairTargets = ExtendedVehicleMaintenance.getWorkshopTargets(rootVehicle)
    local seenRepairTargets = {}
    local function addRepairTarget(v)
        if v ~= nil then
            v = v.rootVehicle or v
            if v ~= nil and seenRepairTargets[v] ~= true then
                seenRepairTargets[v] = true
                table.insert(repairTargets, v)
            end
        end
    end
    addRepairTarget(rootVehicle)
    local runtimeForRepair = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtimeForRepair ~= nil and runtimeForRepair.targets ~= nil then
        for _, v in ipairs(runtimeForRepair.targets) do addRepairTarget(v) end
    end
    for _, repairVehicle in ipairs(repairTargets) do
        repairVehicle = repairVehicle ~= nil and (repairVehicle.rootVehicle or repairVehicle) or nil
        if repairVehicle ~= nil then
            ExtendedVehicleMaintenance.clearFailure(repairVehicle)
            if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
                ExtendedVehicleMaintenance.broadcastFailureState(repairVehicle)
            end

            -- Wichtig: nicht nur die Methode versuchen, sondern den Wearable-Wert danach hart auf 0 setzen.
            -- Manche Fahrzeuge/Mods haben setDamageAmount(), aktualisieren aber nach Reset/Workshop nicht sauber.
            if repairVehicle.repairVehicle ~= nil then pcall(repairVehicle.repairVehicle, repairVehicle) end
            if repairVehicle.setDamageAmount ~= nil then
                pcall(repairVehicle.setDamageAmount, repairVehicle, 0, true)
                pcall(repairVehicle.setDamageAmount, repairVehicle, 0)
            end
            if repairVehicle.spec_wearable ~= nil then
                repairVehicle.spec_wearable.damage = 0
                repairVehicle.spec_wearable.wear = 0
                repairVehicle.spec_wearable.totalAmount = 0
                repairVehicle.spec_wearable.lastRepaired = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
            end
            if repairVehicle.setWearTotalAmount ~= nil then
                pcall(repairVehicle.setWearTotalAmount, repairVehicle, 0, true)
                pcall(repairVehicle.setWearTotalAmount, repairVehicle, 0)
            end
            local repairSpec = evmGetVehicleSpec(repairVehicle)
            if repairVehicle.raiseDirtyFlags ~= nil then
                if repairSpec ~= nil and repairSpec.dirtyFlag ~= nil then
                    pcall(repairVehicle.raiseDirtyFlags, repairVehicle, repairSpec.dirtyFlag)
                end
                if repairVehicle.spec_wearable ~= nil and repairVehicle.spec_wearable.dirtyFlag ~= nil then
                    pcall(repairVehicle.raiseDirtyFlags, repairVehicle, repairVehicle.spec_wearable.dirtyFlag)
                end
            end
        end
    end

    -- Unlock every service/repair target, not only the root vehicle. Also restores drivable
    -- values such as maxAcceleration/maxBackwardAcceleration that were forced to 0 during service.
    for _, unlockVehicle in ipairs(repairTargets) do
        if unlockVehicle ~= nil then
            ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(unlockVehicle.rootVehicle or unlockVehicle)
        end
    end
    ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(rootVehicle)
    ExtendedVehicleMaintenance.broadcastServiceState(rootVehicle, false)

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime ~= nil and (runtime.rootVehicle == rootVehicle or runtime.active == true) then
        runtime.active = false
        runtime.mode = 0
        runtime.rootVehicle = nil
        runtime.targets = {}
        runtime.totalCost = 0
        runtime.totalDurationMs = 0
        runtime.startTime = 0
        runtime.endTime = 0
        runtime.pendingLockData = nil
        runtime.pendingOldRootNode = nil
        runtime.syntheticLockSpec = nil
        runtime._serviceWatchers = {}
    end

    if rootVehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        rootVehicle:raiseDirtyFlags(spec.dirtyFlag)
    end

    if g_server ~= nil and ExtendedVehicleMaintenance.evmSaveAllVehicleStates ~= nil then
        pcall(ExtendedVehicleMaintenance.evmSaveAllVehicleStates)
    end

    if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
        g_currentMission:showBlinkingWarning(string.format(evmText("warning_evmServiceFinished", "%s wurde gewartet und repariert"), tostring(evmGetVehicleName(rootVehicle))), 3500)
    end

    evmDbg("finishService END vehicle=%s hoursPool=%.2f daysPool=%.2f",
        tostring(evmGetVehicleName(rootVehicle)),
        tonumber(spec.hoursPool or 0),
        tonumber(spec.daysPool or 0))
end

function ExtendedVehicleMaintenance:getCanBeEntered(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getCanBeAttached(superFunc, attacherVehicle, attacherVehicleJointDescIndex, implement)
    -- Gerät in Wartung: nicht ankuppelbar
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        if self.isClient and g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
            g_currentMission:showBlinkingWarning(
                evmText("warning_evmInService", "Vehicle is in maintenance") .. ": " .. tostring(evmGetVehicleName(self)), 3000)
        end
        return false
    end
    if superFunc ~= nil then
        return superFunc(self, attacherVehicle, attacherVehicleJointDescIndex, implement)
    end
    return true
end

function ExtendedVehicleMaintenance:getCanBeSelected(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getCanBeUsed(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getCanMotorRun(superFunc)
    -- Eine Motorpanne blockiert den Motor nicht dauerhaft. Der Motor kann starten,
    -- geht aber in zufälligen Abständen wieder aus, bis eine Wartung abgeschlossen wurde.
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getCanToggleMotor(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getMotorNotAllowedWarning(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return evmText("warning_evmInService", "Vehicle is in maintenance")
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return nil
end

function ExtendedVehicleMaintenance:getCanBeRepaired(superFunc)
    -- v17: Standard-Reparatur nur fuer motorisierte Fahrzeuge deaktivieren.
    -- Anbaugeraete / Anhaenger / Tools duerfen weiterhin am Haendler "REPARIEREN"
    -- benutzen, weil die EVM-Wartung dort eher nervig als sinnvoll ist
    -- (kleine Werte, kaum Pannen, keine Motor-Stalls moeglich).
    if self == nil or self.spec_motorized == nil then
        if superFunc ~= nil then
            return superFunc(self)
        end
        return true
    end
    return false
end

function ExtendedVehicleMaintenance:getRepairPrice(superFunc)
    -- v17: Preis nur fuer motorisierte Fahrzeuge auf 0 setzen (= Button verschwindet).
    -- Fuer alles andere den Vanilla-Preis durchreichen.
    if self == nil or self.spec_motorized == nil then
        if superFunc ~= nil then
            return superFunc(self)
        end
        return 0
    end
    return 0
end

-- v21: Zusaetzliche Repair-Preis-Hooks fuer Faelle in denen FS25 nicht getRepairPrice
-- aufruft (z.B. Haendler-Menue "REPARIEREN"-Button).
-- Logik identisch zu getRepairPrice: motorisierte Fahrzeuge -> 0, alles andere -> Vanilla.
function ExtendedVehicleMaintenance:evmHook_getRepairShopPrice(superFunc, ...)
    if self == nil or self.spec_motorized == nil then
        if superFunc ~= nil then
            return superFunc(self, ...)
        end
        return 0
    end
    return 0
end

function ExtendedVehicleMaintenance:evmHook_getRepairShopBasePrice(superFunc, ...)
    if self == nil or self.spec_motorized == nil then
        if superFunc ~= nil then
            return superFunc(self, ...)
        end
        return 0
    end
    return 0
end

-- Daily-Upkeep: NICHT den Reparieren-Button steuernd, aber falls FS25 das fuer
-- "Standard-Reparatur"-Berechnung mit benutzt, geben wir fuer Motorisierte 0 zurueck damit
-- Vanilla-Repair effektiv kostenlos waere -- und dann setzen wir getCanBeRepaired auf false
-- damit der Button trotzdem nicht klickbar ist.
-- Vorerst LASSE ICH DAILY UPKEEP UNVERAENDERT (= superFunc nutzen) damit ich nicht aus
-- Versehen in einen unbeabsichtigten Pfad eingreife.
function ExtendedVehicleMaintenance:evmHook_getDailyUpkeep(superFunc, ...)
    if superFunc ~= nil then
        return superFunc(self, ...)
    end
    return 0
end

function ExtendedVehicleMaintenance:evmHook_getSellPrice(superFunc, ...)
    -- Verkaufspreis nicht aendern -- nur durchreichen. Diese Funktion ist nur in der Hook-Liste
    -- weil sie erwaehnt war, aber EVM aendert keine Verkaufspreise.
    if superFunc ~= nil then
        return superFunc(self, ...)
    end
    return 0
end

function ExtendedVehicleMaintenance:repairVehicle(superFunc, ...)
    -- v17: Vanilla-Repair-Hook. Wird bei Anbaugeraeten/Anhaengern ueber den Haendler-Button
    -- aufgerufen. Wir lassen das Spiel zuerst seinen Standard-Reset machen und cleanen danach
    -- die aktive EVM-Panne (Reifen, Hydraulik, Bremse), sonst bleibt der Failure-State haengen.
    local result = nil
    if superFunc ~= nil then
        result = superFunc(self, ...)
    end

    -- Fuer motorisierte Fahrzeuge sollte der Vanilla-Repair gar nicht aufrufbar sein
    -- (getCanBeRepaired liefert false), aber falls doch: nichts machen, EVM-Service ist Pflicht.
    if self == nil or self.spec_motorized ~= nil then
        return result
    end

    local rootVehicle = self.rootVehicle or self
    local spec = evmGetVehicleSpec(rootVehicle)
    if spec == nil then return result end

    if spec.failureType ~= nil and spec.failureType ~= "" then
        -- Bei reinen Clients via Event clearen, sonst direkt.
        if g_server ~= nil then
            ExtendedVehicleMaintenance.clearFailure(rootVehicle)
            if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
                ExtendedVehicleMaintenance.broadcastFailureState(rootVehicle)
            end
        elseif EVMFailureEvent ~= nil and EVMFailureEvent.sendEvent ~= nil then
            EVMFailureEvent.sendEvent(rootVehicle, "", 0, true)
        end
        if ExtendedVehicleMaintenance.debug == true then
            print(string.format("[EVM] vanilla repair: cleared EVM failure on implement vehicle=%s",
                tostring(evmGetVehicleName(rootVehicle))))
        end
    end

    return result
end

function ExtendedVehicleMaintenance:showInfo(superFunc, box)
    local spec = evmGetVehicleSpec(self)
    if spec ~= nil and spec.failureType ~= nil and spec.failureType ~= "" then
        box:addLine(evmText("info_evm_failureLabel", "Failure"), ExtendedVehicleMaintenance.getFailureText(spec.failureType) or spec.failureType)
    end

    local activeSpec, activeVehicle = evmGetActiveServiceSpec(self)
    if activeSpec ~= nil then
        local hours, minutes = evmFormatHoursMinutes(evmGetServiceRemainingMs(activeSpec, activeVehicle or self))
        box:addLine(evmText("info_evm_serviceLabel", "Maintenance"), string.format(evmText("info_evm_serviceRunning", "%d h %d min remaining"), hours, minutes))
    else
        local remainingHours, remainingDays = ExtendedVehicleMaintenance.getRemainingMaintenance(self)
        box:addLine(evmText("info_evm_serviceLabel", "Maintenance"), string.format(evmText("info_evm_remaining", "%1.1f h / %1.1f d remaining"), remainingHours, remainingDays))
    end

    if superFunc ~= nil then
        return superFunc(self, box)
    end
end

function ExtendedVehicleMaintenance:getIsEnterable(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:getIsEnterableFromMenu(superFunc)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        return false
    end
    if superFunc ~= nil then
        return superFunc(self)
    end
    return true
end

function ExtendedVehicleMaintenance:interact(superFunc, player)
    if ExtendedVehicleMaintenance.isVehicleLocked(self) then
        if self.isClient then
            evmShowServiceLockWarning(self, 2600)
        end
        return
    end

    if superFunc ~= nil then
        return superFunc(self, player)
    end
end

function ExtendedVehicleMaintenance.updateActionEventText(vehicle, actionEventId)
    local activeSpec = evmGetActiveServiceSpec(vehicle)
    if activeSpec ~= nil then
        local hours, minutes = evmFormatHoursMinutes(evmGetServiceRemainingMs(activeSpec, vehicle))
        g_inputBinding:setActionEventText(actionEventId, string.format(evmText("action_evm_serviceRunning", "Maintenance running: %d h %d min"), hours, minutes))
    else
        g_inputBinding:setActionEventText(actionEventId, evmText("input_EVM_OPEN_SERVICE", "Service menu"))
    end
end

function ExtendedVehicleMaintenance:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    local spec = evmGetVehicleSpec(self)
    if spec == nil then
        return
    end

    self:clearActionEventsTable(spec.actionEvents)

    -- Motorisierte Fahrzeuge: Action-Event wenn eingestiegen
    if self.isClient and self.spec_motorized ~= nil and self.getIsEntered ~= nil and self:getIsEntered() then
        local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.EVM_OPEN_SERVICE, self, ExtendedVehicleMaintenance.actionEventStartService, false, true, false, true)
        if actionEventId ~= nil then
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            ExtendedVehicleMaintenance.updateActionEventText(self, actionEventId)
            g_inputBinding:setActionEventActive(actionEventId, not ExtendedVehicleMaintenance.isVehicleInServiceOrPending(self))
        end

        -- v18: Quick-Fix-Aktion (nur sichtbar wenn aktive MINOR-Panne mit Quick-Fix-Definition)
        if InputAction.EVM_QUICK_FIX ~= nil then
            local _, qfId = self:addActionEvent(spec.actionEvents, InputAction.EVM_QUICK_FIX, self, ExtendedVehicleMaintenance.actionEventQuickFix, false, true, false, true)
            if qfId ~= nil then
                g_inputBinding:setActionEventTextPriority(qfId, GS_PRIO_NORMAL)
                spec.evmQuickFixActionId = qfId
                ExtendedVehicleMaintenance.updateQuickFixActionText(self)
            end
        end

        -- v18: Limp-Home-Aktion
        if InputAction.EVM_LIMP_HOME ~= nil then
            local _, lhId = self:addActionEvent(spec.actionEvents, InputAction.EVM_LIMP_HOME, self, ExtendedVehicleMaintenance.actionEventLimpHome, false, true, false, true)
            if lhId ~= nil then
                g_inputBinding:setActionEventTextPriority(lhId, GS_PRIO_NORMAL)
                spec.evmLimpHomeActionId = lhId
                ExtendedVehicleMaintenance.updateLimpHomeActionText(self)
            end
        end
    end
end

-- v18: Action-Text/-Sichtbarkeit fuer Quick-Fix dynamisch je nach Fahrzeugzustand setzen.
function ExtendedVehicleMaintenance.updateQuickFixActionText(vehicle)
    if vehicle == nil then return end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or spec.evmQuickFixActionId == nil or g_inputBinding == nil then return end
    local id = spec.evmQuickFixActionId

    if not ExtendedVehicleMaintenance.canQuickFix(vehicle) then
        g_inputBinding:setActionEventActive(id, false)
        g_inputBinding:setActionEventTextVisibility(id, false)
        return
    end

    local ft = spec.failureType
    local def = ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS and ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS[ft]
    if def == nil then
        g_inputBinding:setActionEventActive(id, false)
        g_inputBinding:setActionEventTextVisibility(id, false)
        return
    end

    local label = (g_i18n ~= nil and g_i18n.getText ~= nil and g_i18n:getText(g_languageShort == "de" and def.label_de or def.label_en)) or def.label_de or def.label_en or "Quick fix"
    -- Falls obige getText nicht gefunden: direkt das Feld nehmen.
    if label == nil or label == "" or string.find(tostring(label), "missing", 1, true) ~= nil then
        label = (g_languageShort == "de" and def.label_de) or def.label_en or "Quick fix"
    end

    local durSec = math.floor((tonumber(def.durationMs) or 0) / 1000)
    local text = string.format(evmText("action_evm_quickFixOffer", "Quick fix: %s (€%d, %d sec)"), tostring(label), tonumber(def.cost) or 0, durSec)
    g_inputBinding:setActionEventText(id, text)
    g_inputBinding:setActionEventActive(id, true)
    g_inputBinding:setActionEventTextVisibility(id, true)
end

function ExtendedVehicleMaintenance.updateLimpHomeActionText(vehicle)
    if vehicle == nil then return end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or spec.evmLimpHomeActionId == nil or g_inputBinding == nil then return end
    local id = spec.evmLimpHomeActionId

    if not ExtendedVehicleMaintenance.canLimpHome(vehicle) then
        g_inputBinding:setActionEventActive(id, false)
        g_inputBinding:setActionEventTextVisibility(id, false)
        return
    end

    local minutes = math.floor((ExtendedVehicleMaintenance.LIMP_HOME_DURATION_MS or 1800000) / 60000)
    local text = string.format(evmText("action_evm_limpHomeOffer", "Continue (reduced effects, %d min)"), minutes)
    g_inputBinding:setActionEventText(id, text)
    g_inputBinding:setActionEventActive(id, true)
    g_inputBinding:setActionEventTextVisibility(id, true)
end

function ExtendedVehicleMaintenance.actionEventQuickFix(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 then return end
    if not ExtendedVehicleMaintenance.canQuickFix(self) then
        if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
            g_currentMission:showBlinkingWarning(evmText("warning_evmCriticalNoSelfRepair", "Cannot quick-fix this failure"), 2200)
        end
        return
    end
    if EVMQuickFixEvent ~= nil and EVMQuickFixEvent.sendEvent ~= nil then
        EVMQuickFixEvent.sendEvent(self, 1)
    end
end

function ExtendedVehicleMaintenance.actionEventLimpHome(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 then return end
    if not ExtendedVehicleMaintenance.canLimpHome(self) then return end
    if EVMQuickFixEvent ~= nil and EVMQuickFixEvent.sendEvent ~= nil then
        EVMQuickFixEvent.sendEvent(self, 2)
    end
end

function ExtendedVehicleMaintenance.actionEventStartService(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= 1 then
        return
    end
    if EVMServiceDialog ~= nil and EVMServiceDialog.show ~= nil then
        EVMServiceDialog.show(self)
    end
end

local function evmFormatServiceDueText(vehicle)
    local due, remainingHours, remainingDays = ExtendedVehicleMaintenance.isDue(vehicle)
    if due then
        return evmText("warning_evmDue", "Maintenance required!")
    end
    return string.format(evmText("warning_evmEnterStatus", "Next service in %1.1f h / %1.1f d"), remainingHours or 0, remainingDays or 0)
end

function ExtendedVehicleMaintenance.getFailureText(failureType)
    if failureType == "engine" then
        return evmText("warning_evmFailureEngine", "Motorpanne")
    elseif failureType == "flatTire" then
        return evmText("warning_evmFailureFlatTire", "Reifenpanne")
    elseif failureType == "rpmLimit" then
        return evmText("warning_evmFailureRpmLimit", "Notlauf (Drehzahlbegrenzer)")
    elseif failureType == "hydraulicLeak" then
        return evmText("warning_evmFailureHydraulic", "Hydraulikleck")
    elseif failureType == "brakeFault" then
        return evmText("warning_evmFailureBrake", "Bremsdefekt")
    elseif failureType == "battery" then
        return evmText("warning_evmFailureBattery", "Batterie leer")
    end
    return nil
end

local function evmGetVehicleFuelFillUnitIndex(vehicle)
    if vehicle == nil or vehicle.spec_fillUnit == nil or vehicle.getFillUnitFillType == nil then
        return nil
    end
    local ftm = g_fillTypeManager
    local diesel = ftm ~= nil and ftm.getFillTypeIndexByName ~= nil and ftm:getFillTypeIndexByName("DIESEL") or nil
    local electric = ftm ~= nil and ftm.getFillTypeIndexByName ~= nil and ftm:getFillTypeIndexByName("ELECTRICCHARGE") or nil
    local methane = ftm ~= nil and ftm.getFillTypeIndexByName ~= nil and ftm:getFillTypeIndexByName("METHANE") or nil
    local fillUnits = vehicle.spec_fillUnit.fillUnits or {}
    for i = 1, #fillUnits do
        local ok, fillType = pcall(vehicle.getFillUnitFillType, vehicle, i)
        if ok and (fillType == diesel or fillType == electric or fillType == methane) then
            return i
        end
    end
    return nil
end

local function evmTireNodeExists(node)
    if type(node) ~= "number" or node == 0 then
        return false
    end
    if entityExists ~= nil then
        local ok, exists = pcall(entityExists, node)
        return ok and exists == true
    end
    return true
end

local function evmResolveNodeId(value)
    if value == nil then
        return nil
    end
    local valueType = type(value)
    if valueType == "number" then
        return value
    elseif valueType == "table" then
        return evmResolveNodeId(value.node) or evmResolveNodeId(value.nodeId) or evmResolveNodeId(value.transformId) or evmResolveNodeId(value.shape) or evmResolveNodeId(value.i3dNode) or evmResolveNodeId(value.rootNode) or evmResolveNodeId(value.visualNode) or evmResolveNodeId(value.wheelShape)
    end
    return nil
end

local function evmSafeGetShaderParameter(node, name)
    if not evmTireNodeExists(node) or type(name) ~= "string" or name == "" or getShaderParameter == nil then return nil end
    local ok, x, y, z, w = pcall(getShaderParameter, node, name)
    if not ok then return nil end
    return x, y, z, w
end

local function evmSafeSetShaderParameter(node, name, x, y, z, w)
    if not evmTireNodeExists(node) or type(name) ~= "string" or name == "" or setShaderParameter == nil then return end
    pcall(setShaderParameter, node, name, x or 0, y or 0, z or 0, w or 0, false)
end

local function evmIsShapeNode(node)
    if not evmTireNodeExists(node) or getHasClassId == nil or ClassIds == nil or ClassIds.SHAPE == nil then return false end
    local ok, has = pcall(getHasClassId, node, ClassIds.SHAPE)
    return ok and has == true
end

local function evmCollectShaderShapes(rootNode, outShapes)
    if not evmTireNodeExists(rootNode) or outShapes == nil then return end
    if evmIsShapeNode(rootNode) then table.insert(outShapes, rootNode); return end
    if getNumOfChildren == nil or getChildAt == nil then return end
    local ok, numChildren = pcall(getNumOfChildren, rootNode)
    if not ok or numChildren == nil then return end
    for i = 0, numChildren - 1 do
        local okChild, child = pcall(getChildAt, rootNode, i)
        if okChild and child ~= nil then evmCollectShaderShapes(child, outShapes) end
    end
end

local function evmGetVisualPartNode(visualPart)
    if visualPart == nil then return nil end
    return evmResolveNodeId(visualPart.node) or evmResolveNodeId(visualPart.rootNode) or evmResolveNodeId(visualPart.visualNode) or evmResolveNodeId(visualPart.transform) or evmResolveNodeId(visualPart.i3dNode)
end

local function evmSafeGetTranslation(node)
    if not evmTireNodeExists(node) or getTranslation == nil then return nil, nil, nil end
    local ok, x, y, z = pcall(getTranslation, node)
    if not ok then return nil, nil, nil end
    return x, y, z
end

local function evmResolveWheelAxis(wheel)
    local node = evmResolveNodeId(wheel) or evmResolveNodeId(wheel.repr) or evmResolveNodeId(wheel.driveNode) or evmResolveNodeId(wheel.node) or evmResolveNodeId(wheel.wheelShape) or evmResolveNodeId(wheel.rootNode) or evmResolveNodeId(wheel.physics)
    if node ~= nil then
        local x, _, z = evmSafeGetTranslation(node)
        if x ~= nil and z ~= nil then return x, z end
    end
    if wheel.physics ~= nil then
        local px = tonumber(wheel.physics.positionX) or tonumber(wheel.physics.posX) or tonumber(wheel.physics.x)
        local pz = tonumber(wheel.physics.positionZ) or tonumber(wheel.physics.posZ) or tonumber(wheel.physics.z)
        if px ~= nil or pz ~= nil then return px or 0, pz or 0 end
    end
    return 0, 0
end

local function evmClusterScore(cluster)
    return (math.abs(cluster.posZ or 0) * 100) + math.abs(cluster.posX or 0)
end

local function evmCacheVisualRecord(cluster, visualPart)
    if visualPart == nil or cluster._visualSeen[visualPart] then return end
    cluster._visualSeen[visualPart] = true
    local node = evmGetVisualPartNode(visualPart)
    if node == nil then return end
    local shapes = {}
    evmCollectShaderShapes(node, shapes)
    local record = { node = node, shapes = shapes, morphPos = {}, prevMorphPos = {}, hasAny = false }
    for _, shape in ipairs(shapes) do
        local x, y, z, w = evmSafeGetShaderParameter(shape, "morphPos")
        if x ~= nil then record.morphPos[shape] = { x = x, y = y, z = z, w = w or 0 }; record.hasAny = true end
        local px, py, pz, pw = evmSafeGetShaderParameter(shape, "prevMorphPos")
        if px ~= nil then record.prevMorphPos[shape] = { x = px, y = py, z = pz, w = pw or 0 }; record.hasAny = true end
    end
    if record.hasAny then table.insert(cluster.visuals, record) end
end

local function evmScanWheelVisuals(cluster, wheel)
    if wheel == nil then return end
    if wheel.visualWheel ~= nil and wheel.visualWheel.visualParts ~= nil then
        for _, visualPart in ipairs(wheel.visualWheel.visualParts) do evmCacheVisualRecord(cluster, visualPart) end
    end
    if wheel.visualWheels ~= nil then
        for _, visualWheel in ipairs(wheel.visualWheels) do
            if visualWheel ~= nil and visualWheel.visualParts ~= nil then
                for _, visualPart in ipairs(visualWheel.visualParts) do evmCacheVisualRecord(cluster, visualPart) end
            end
        end
    end
    if wheel.visualParts ~= nil then
        for _, visualPart in ipairs(wheel.visualParts) do evmCacheVisualRecord(cluster, visualPart) end
    end
end

local function evmAddPhysicsRecord(cluster, wheel)
    if wheel == nil or wheel.physics == nil then return end
    local physics = wheel.physics
    if cluster._physicsSeen[physics] then return end
    cluster._physicsSeen[physics] = true
    local radius = physics.radiusOriginal or physics.radius
    if radius ~= nil then table.insert(cluster.physics, { physics = physics, radiusOriginal = radius }) end
end

local function evmAppendWheelCluster(cluster, wheel)
    if wheel == nil then return end
    evmAddPhysicsRecord(cluster, wheel)
    evmScanWheelVisuals(cluster, wheel)
    if wheel.additionalWheels ~= nil then
        for _, additionalWheel in ipairs(wheel.additionalWheels) do evmAppendWheelCluster(cluster, additionalWheel) end
    end
end

local function evmBuildTireState(vehicle)
    if vehicle == nil then return nil end
    local state = ExtendedVehicleMaintenance._tireEffectStates[vehicle]
    if state ~= nil then return state end
    local wheelsSpec = vehicle.spec_wheels
    if wheelsSpec == nil or wheelsSpec.wheels == nil then return nil end
    state = { vehicle = vehicle, clusters = {}, activeEffects = {} }
    for _, wheel in ipairs(wheelsSpec.wheels) do
        local posX, posZ = evmResolveWheelAxis(wheel)
        local side = 0
        if posX ~= nil and math.abs(posX) > 0.01 then side = posX < 0 and -1 or 1 end
        local cluster = { wheel = wheel, posX = posX or 0, posZ = posZ or 0, side = side, physics = {}, visuals = {}, _physicsSeen = {}, _visualSeen = {}, currentAmount = 0 }
        evmAppendWheelCluster(cluster, wheel)
        cluster._physicsSeen = nil
        cluster._visualSeen = nil
        if #cluster.physics > 0 or #cluster.visuals > 0 then table.insert(state.clusters, cluster) end
    end
    ExtendedVehicleMaintenance._tireEffectStates[vehicle] = state
    return state
end

local function evmApplyClusterAmount(cluster, amount)
    amount = evmClamp(amount, 0, 1)
    for _, entry in ipairs(cluster.physics) do
        local physics = entry.physics
        local radiusOriginal = entry.radiusOriginal or (physics ~= nil and (physics.radiusOriginal or physics.radius)) or nil
        if physics ~= nil and radiusOriginal ~= nil then
            local minRadius = radiusOriginal * 0.6
            local newRadius = radiusOriginal - ((radiusOriginal - minRadius) * amount)
            if physics.radius == nil or math.abs((physics.radius or newRadius) - newRadius) > 0.00005 then
                physics.radius = newRadius
                physics.isPositionDirty = true
            end
        end
    end
    for _, visualRecord in ipairs(cluster.visuals) do
        for shape, original in pairs(visualRecord.morphPos) do
            local baseW = tonumber(original.w) or 0.02
            local flatW = math.max(baseW * 2.75, 0.055)
            evmSafeSetShaderParameter(shape, "morphPos", original.x, original.y, original.z, baseW + ((flatW - baseW) * amount))
        end
        for shape, original in pairs(visualRecord.prevMorphPos) do
            local baseW = tonumber(original.w) or 0.02
            local flatW = math.max(baseW * 2.75, 0.055)
            evmSafeSetShaderParameter(shape, "prevMorphPos", original.x, original.y, original.z, baseW + ((flatW - baseW) * amount))
        end
    end
    cluster.currentAmount = amount
end

local function evmRecomputeTireEffects(state)
    if state == nil then return end
    local maxAmounts = {}
    for _, effectState in pairs(state.activeEffects) do
        local clusterIndex = effectState.clusterIndex
        local amount = evmClamp(effectState.amount, 0, 1)
        if clusterIndex ~= nil then maxAmounts[clusterIndex] = math.max(maxAmounts[clusterIndex] or 0, amount) end
    end
    for clusterIndex, cluster in ipairs(state.clusters) do evmApplyClusterAmount(cluster, maxAmounts[clusterIndex] or 0) end
end

function ExtendedVehicleMaintenance.getTireEffectCluster(vehicle, preferredSide)
    local state = evmBuildTireState(vehicle)
    if state == nil or state.clusters == nil or #state.clusters == 0 then return nil, nil end
    local bestScore = nil
    local candidates = {}
    for clusterIndex, cluster in ipairs(state.clusters) do
        if preferredSide == nil or preferredSide == 0 or cluster.side == preferredSide then
            local score = evmClusterScore(cluster)
            if bestScore == nil or score > bestScore + 0.001 then
                bestScore = score
                candidates = { clusterIndex }
            elseif bestScore ~= nil and math.abs(score - bestScore) <= 0.001 then
                table.insert(candidates, clusterIndex)
            end
        end
    end
    if #candidates == 0 then
        for clusterIndex = 1, #state.clusters do table.insert(candidates, clusterIndex) end
    end
    if #candidates == 0 then return nil, nil end
    local clusterIndex = candidates[math.random(#candidates)]
    return clusterIndex, state.clusters[clusterIndex]
end

function ExtendedVehicleMaintenance.setTireEffectAmount(vehicle, key, clusterIndex, amount)
    if vehicle == nil or key == nil or clusterIndex == nil then return false end
    local state = evmBuildTireState(vehicle)
    if state == nil or state.clusters == nil or state.clusters[clusterIndex] == nil then return false end
    state.activeEffects[key] = { clusterIndex = clusterIndex, amount = evmClamp(amount, 0, 1) }
    evmRecomputeTireEffects(state)
    return true
end

function ExtendedVehicleMaintenance.clearTireEffect(vehicle, key)
    if vehicle == nil or key == nil then return end
    local state = ExtendedVehicleMaintenance._tireEffectStates[vehicle]
    if state == nil then return end
    state.activeEffects[key] = nil
    if next(state.activeEffects) == nil then
        for _, cluster in ipairs(state.clusters or {}) do evmApplyClusterAmount(cluster, 0) end
        ExtendedVehicleMaintenance._tireEffectStates[vehicle] = nil
        return
    end
    evmRecomputeTireEffects(state)
end


local function evmGetVehiclePhysicsHookState(vehicle, create)
    if vehicle == nil then return nil end
    local state = ExtendedVehicleMaintenance._vehiclePhysicsHookStates[vehicle]
    if state == nil and create then
        state = { originalUpdateVehiclePhysics = nil, wrappedUpdateVehiclePhysics = nil, hooks = {}, order = {} }
        ExtendedVehicleMaintenance._vehiclePhysicsHookStates[vehicle] = state
    end
    return state
end

local function evmRemoveHookOrderEntry(order, key)
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) end
    end
end

function ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, key, hookFn)
    vehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if vehicle == nil or key == nil or type(hookFn) ~= "function" or type(vehicle.updateVehiclePhysics) ~= "function" then
        return false
    end

    local state = evmGetVehiclePhysicsHookState(vehicle, true)
    local current = vehicle.updateVehiclePhysics
    if state.originalUpdateVehiclePhysics == nil then
        state.originalUpdateVehiclePhysics = current
    elseif current ~= state.wrappedUpdateVehiclePhysics and current ~= state.originalUpdateVehiclePhysics then
        state.originalUpdateVehiclePhysics = current
    end

    if state.hooks[key] == nil then table.insert(state.order, key) end
    state.hooks[key] = hookFn

    if state.wrappedUpdateVehiclePhysics == nil then
        state.wrappedUpdateVehiclePhysics = function(selfVeh, axisForward, axisSide, doHandbrake, dt)
            local innerState = evmGetVehiclePhysicsHookState(selfVeh, false)
            local outForward, outSide, outHandbrake, outDt = axisForward, axisSide, doHandbrake, dt
            if innerState ~= nil then
                for _, hookKey in ipairs(innerState.order or {}) do
                    local fn = innerState.hooks[hookKey]
                    if type(fn) == "function" then
                        local ok, nf, ns, nh, nd = pcall(fn, selfVeh, outForward, outSide, outHandbrake, outDt)
                        if ok then
                            if nf ~= nil then outForward = nf end
                            if ns ~= nil then outSide = ns end
                            if nh ~= nil then outHandbrake = nh end
                            if nd ~= nil then outDt = nd end
                        else
                            print("[EVM] VehiclePhysicsHook error " .. tostring(hookKey) .. ": " .. tostring(nf))
                        end
                    end
                end
                    if type(innerState.originalUpdateVehiclePhysics) == "function" then
                    return innerState.originalUpdateVehiclePhysics(selfVeh, outForward, outSide, outHandbrake, outDt)
                end
            end
            if type(current) == "function" then
                return current(selfVeh, outForward, outSide, outHandbrake, outDt)
            end
        end
    end

    vehicle.updateVehiclePhysics = state.wrappedUpdateVehiclePhysics
    return true
end

function ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, key)
    vehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if vehicle == nil or key == nil then return end
    local state = ExtendedVehicleMaintenance._vehiclePhysicsHookStates[vehicle]
    if state == nil then return end
    state.hooks[key] = nil
    evmRemoveHookOrderEntry(state.order, key)
    if next(state.hooks) == nil then
        if type(state.originalUpdateVehiclePhysics) == "function" then vehicle.updateVehiclePhysics = state.originalUpdateVehiclePhysics end
        ExtendedVehicleMaintenance._vehiclePhysicsHookStates[vehicle] = nil
    else
        vehicle.updateVehiclePhysics = state.wrappedUpdateVehiclePhysics
    end
end

function ExtendedVehicleMaintenance.normalizeFailureType(value)
    local v = tostring(value or ""):lower():gsub("%s+", ""):gsub("_", ""):gsub("-", "")
    if v == "engine" or v == "motor" or v == "motorpanne" or v == "motorschaden" then
        return "engine"
    elseif v == "flattire" or v == "flat" or v == "tire" or v == "reifen" or v == "platt" or v == "platterreifen" or v == "reifenpanne" then
        return "flatTire"
    elseif v == "rpm" or v == "rpmlimit" or v == "notlauf" or v == "limp" then
        return "rpmLimit"
    elseif v == "hydraulic" or v == "hydraulik" or v == "hydraulikleck" or v == "hydraulicleak" then
        return "hydraulicLeak"
    elseif v == "brake" or v == "bremse" or v == "bremsdefekt" or v == "brakefault" then
        return "brakeFault"
    elseif v == "battery" or v == "batterie" or v == "leer" or v == "batteryleer" or v == "batteryflat" or v == "batteriepanne" then
        return "battery"
    end
    return nil
end

local function evmGetOriginalMotorRpm(vehicle)
    if vehicle == nil then return 0 end
    vehicle = vehicle.rootVehicle or vehicle
    if type(vehicle._evmRpmLimitOriginalGetMotorRpm) == "function" then
        local ok, rpm = pcall(vehicle._evmRpmLimitOriginalGetMotorRpm, vehicle)
        if ok then return tonumber(rpm or 0) or 0 end
    elseif type(vehicle.getMotorRpm) == "function" then
        local ok, rpm = pcall(vehicle.getMotorRpm, vehicle)
        if ok then return tonumber(rpm or 0) or 0 end
    end
    local motorVehicle = vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor ~= nil and vehicle.spec_motorized.motor.vehicle or nil
    if motorVehicle ~= nil then
        if type(motorVehicle._evmRpmLimitOriginalGetMotorRpm) == "function" then
            local ok, rpm = pcall(motorVehicle._evmRpmLimitOriginalGetMotorRpm, motorVehicle)
            if ok then return tonumber(rpm or 0) or 0 end
        elseif type(motorVehicle.getMotorRpm) == "function" then
            local ok, rpm = pcall(motorVehicle.getMotorRpm, motorVehicle)
            if ok then return tonumber(rpm or 0) or 0 end
        end
    end
    return 0
end

local function evmStopMotorForFailure(vehicle)
    if vehicle == nil then return false end
    vehicle = vehicle.rootVehicle or vehicle
    local stopped = false

    if vehicle.stopMotor ~= nil then
        local attempts = {
            function() return vehicle:stopMotor(false) end,
            function() return vehicle:stopMotor() end,
            function() return vehicle:stopMotor(true) end,
        }
        for _, fn in ipairs(attempts) do
            local ok = pcall(fn)
            if ok then stopped = true end
        end
    end

    -- Fallback fuer Mod-Fahrzeuge/MP: manche stopMotor()-Aufrufe werden vom Client-Input direkt wieder ueberfahren.
    if vehicle.spec_motorized ~= nil then
        vehicle.spec_motorized.isMotorStarted = false
        vehicle.spec_motorized.motorStartTime = 0
        vehicle.spec_motorized.motorStopTime = g_time or 0
        vehicle.spec_motorized.motorTurnedOn = false
        vehicle.spec_motorized.motorStartDuration = 0

        local motor = vehicle.spec_motorized.motor
        if motor ~= nil then
            if type(motor.setSpeedLimit) == "function" then pcall(motor.setSpeedLimit, motor, 0) end
            if type(motor.setExternalTorque) == "function" then pcall(motor.setExternalTorque, motor, 0) end
            if type(motor.setTargetRpm) == "function" then pcall(motor.setTargetRpm, motor, 0) end
            if type(motor.setThrottle) == "function" then pcall(motor.setThrottle, motor, 0) end
            if type(motor.stop) == "function" then pcall(motor.stop, motor) end
        end
    end
    if vehicle.setMotorStartState ~= nil then
        pcall(vehicle.setMotorStartState, vehicle, false)
        pcall(vehicle.setMotorStartState, vehicle, false, false)
        pcall(vehicle.setMotorStartState, vehicle, false, true)
    end
    if vehicle.setIsMotorStarted ~= nil then
        pcall(vehicle.setIsMotorStarted, vehicle, false, false)
        pcall(vehicle.setIsMotorStarted, vehicle, false, true)
        pcall(vehicle.setIsMotorStarted, vehicle, false)
    end
    if vehicle.raiseDirtyFlags ~= nil then
        local spec = evmGetVehicleSpec(vehicle)
        if spec ~= nil and spec.dirtyFlag ~= nil then pcall(vehicle.raiseDirtyFlags, vehicle, spec.dirtyFlag) end
    end

    return stopped
end

function ExtendedVehicleMaintenance.attachRpmLimiter(vehicle, spec)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or spec == nil or spec.failureType ~= "rpmLimit" or vehicle.spec_motorized == nil then return false end

    local rpmLimit = tonumber(spec.rpmLimitValue or ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM) or 2000
    rpmLimit = evmClamp(rpmLimit, 900, 3500)
    spec.rpmLimitValue = rpmLimit

    if type(vehicle.getMotorRpm) == "function" and vehicle._evmRpmLimitOriginalGetMotorRpm == nil then
        vehicle._evmRpmLimitOriginalGetMotorRpm = vehicle.getMotorRpm
        vehicle.getMotorRpm = function(selfVehicle, ...)
            local ok, rpm = pcall(selfVehicle._evmRpmLimitOriginalGetMotorRpm, selfVehicle, ...)
            if ok then return math.min(tonumber(rpm or 0) or 0, rpmLimit) end
            return rpmLimit
        end
    end

    local motor = vehicle.spec_motorized.motor
    local motorVehicle = motor ~= nil and motor.vehicle or nil
    if motorVehicle ~= nil and type(motorVehicle.getMotorRpm) == "function" and motorVehicle._evmRpmLimitOriginalGetMotorRpm == nil then
        motorVehicle._evmRpmLimitOriginalGetMotorRpm = motorVehicle.getMotorRpm
        motorVehicle.getMotorRpm = function(selfVehicle, ...)
            local ok, rpm = pcall(selfVehicle._evmRpmLimitOriginalGetMotorRpm, selfVehicle, ...)
            if ok then return math.min(tonumber(rpm or 0) or 0, rpmLimit) end
            return rpmLimit
        end
    end

    if motor ~= nil then
        if motor._evmRpmLimitOrigMaxRpm == nil then
            if type(motor.maxRpm) == "number" then motor._evmRpmLimitOrigMaxRpm = motor.maxRpm end
            if type(motor.maxForwardRpm) == "number" then motor._evmRpmLimitOrigMaxForwardRpm = motor.maxForwardRpm end
            if type(motor.maxBackwardRpm) == "number" then motor._evmRpmLimitOrigMaxBackwardRpm = motor.maxBackwardRpm end
            if type(motor.peakMotorPower) == "number" then motor._evmRpmLimitOrigPeakMotorPower = motor.peakMotorPower end
            if type(motor.maxMotorPower) == "number" then motor._evmRpmLimitOrigMaxMotorPower = motor.maxMotorPower end
            if type(motor.maxForwardSpeed) == "number" then motor._evmRpmLimitOrigMaxForwardSpeed = motor.maxForwardSpeed end
            if type(motor.maxBackwardSpeed) == "number" then motor._evmRpmLimitOrigMaxBackwardSpeed = motor.maxBackwardSpeed end
        end
        if type(motor.maxRpm) == "number" then motor.maxRpm = math.min(motor._evmRpmLimitOrigMaxRpm or motor.maxRpm, rpmLimit) end
        if type(motor.maxForwardRpm) == "number" then motor.maxForwardRpm = math.min(motor._evmRpmLimitOrigMaxForwardRpm or motor.maxForwardRpm, rpmLimit) end
        if type(motor.maxBackwardRpm) == "number" then motor.maxBackwardRpm = math.min(motor._evmRpmLimitOrigMaxBackwardRpm or motor.maxBackwardRpm, rpmLimit) end
        -- Notlauf: nicht nur Anzeige-RPM kappen, sondern echte Fahrleistung massiv reduzieren.
        if type(motor.peakMotorPower) == "number" then motor.peakMotorPower = (motor._evmRpmLimitOrigPeakMotorPower or motor.peakMotorPower) * 0.34 end
        if type(motor.maxMotorPower) == "number" then motor.maxMotorPower = (motor._evmRpmLimitOrigMaxMotorPower or motor.maxMotorPower) * 0.34 end
        if type(motor.maxForwardSpeed) == "number" then
            local originalMaxSpeed = motor._evmRpmLimitOrigMaxForwardSpeed or motor.maxForwardSpeed
            local limpMaxSpeed = originalMaxSpeed > 30 and 18 or (18 / 3.6)
            motor.maxForwardSpeed = math.min(originalMaxSpeed, limpMaxSpeed)
        end
        if type(motor.maxBackwardSpeed) == "number" then
            local originalMaxBackSpeed = motor._evmRpmLimitOrigMaxBackwardSpeed or motor.maxBackwardSpeed
            local limpMaxBackSpeed = originalMaxBackSpeed > 20 and 8 or (8 / 3.6)
            motor.maxBackwardSpeed = math.min(originalMaxBackSpeed, limpMaxBackSpeed)
        end
    end

    return ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, "evmFailureRpmLimit", function(selfVeh, axisForward, axisSide, doHandbrake, dt)
        local rpm = evmGetOriginalMotorRpm(selfVeh)
        local forward = axisForward
        local handbrake = doHandbrake

        -- Notlauf: bei Vollgas nur noch geringe Leistung; oberhalb ca. 18 km/h wird aktiv abgeregelt.
        if forward ~= nil and forward > 0 then
            forward = math.min(forward, 0.28)
        end

        local rawSpeed = math.abs(tonumber(selfVeh.lastSpeedReal or selfVeh.lastSpeed or 0) or 0)
        local speedKph = rawSpeed
        if rawSpeed < 1 then
            speedKph = rawSpeed * 3600
        elseif rawSpeed < 50 then
            speedKph = rawSpeed * 3.6
        end
        if speedKph > 18 then
            forward = 0
            handbrake = true
        end

        if selfVeh.spec_motorized ~= nil and selfVeh.spec_motorized.motor ~= nil and selfVeh.spec_motorized.motor.setEqualizedMotorRpm ~= nil and rpm > rpmLimit then
            pcall(selfVeh.spec_motorized.motor.setEqualizedMotorRpm, selfVeh.spec_motorized.motor, rpmLimit)
        end

        return forward, axisSide, handbrake, dt
    end)
end

function ExtendedVehicleMaintenance.restoreRpmLimiter(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil then return end

    ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, "evmFailureRpmLimit")

    if vehicle._evmRpmLimitOriginalGetMotorRpm ~= nil then
        vehicle.getMotorRpm = vehicle._evmRpmLimitOriginalGetMotorRpm
        vehicle._evmRpmLimitOriginalGetMotorRpm = nil
    end

    local motor = vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor or nil
    local motorVehicle = motor ~= nil and motor.vehicle or nil
    if motorVehicle ~= nil and motorVehicle._evmRpmLimitOriginalGetMotorRpm ~= nil then
        motorVehicle.getMotorRpm = motorVehicle._evmRpmLimitOriginalGetMotorRpm
        motorVehicle._evmRpmLimitOriginalGetMotorRpm = nil
    end

    if motor ~= nil then
        if motor._evmRpmLimitOrigMaxRpm ~= nil then motor.maxRpm = motor._evmRpmLimitOrigMaxRpm end
        if motor._evmRpmLimitOrigMaxForwardRpm ~= nil then motor.maxForwardRpm = motor._evmRpmLimitOrigMaxForwardRpm end
        if motor._evmRpmLimitOrigMaxBackwardRpm ~= nil then motor.maxBackwardRpm = motor._evmRpmLimitOrigMaxBackwardRpm end
        if motor._evmRpmLimitOrigPeakMotorPower ~= nil then motor.peakMotorPower = motor._evmRpmLimitOrigPeakMotorPower end
        if motor._evmRpmLimitOrigMaxMotorPower ~= nil then motor.maxMotorPower = motor._evmRpmLimitOrigMaxMotorPower end
        if motor._evmRpmLimitOrigMaxForwardSpeed ~= nil then motor.maxForwardSpeed = motor._evmRpmLimitOrigMaxForwardSpeed end
        if motor._evmRpmLimitOrigMaxBackwardSpeed ~= nil then motor.maxBackwardSpeed = motor._evmRpmLimitOrigMaxBackwardSpeed end
        motor._evmRpmLimitOrigMaxRpm = nil
        motor._evmRpmLimitOrigMaxForwardRpm = nil
        motor._evmRpmLimitOrigMaxBackwardRpm = nil
        motor._evmRpmLimitOrigPeakMotorPower = nil
        motor._evmRpmLimitOrigMaxMotorPower = nil
        motor._evmRpmLimitOrigMaxForwardSpeed = nil
        motor._evmRpmLimitOrigMaxBackwardSpeed = nil
    end
end

function ExtendedVehicleMaintenance.isEngineFailureBlocking(spec)
    if spec == nil or spec.failureType ~= "engine" then return false end
    return spec.engineFailurePhase == "block"
end

local evmSetEngineStallMotorCap

function ExtendedVehicleMaintenance.attachEngineFailure(vehicle, spec)
    -- Motorpanne blockiert den Start nicht dauerhaft. Nur direkt nach einem Aussetzer wird kurz verhindert,
    -- dass der MP-Client den Motor im selben Moment wieder anwirft.
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or spec == nil or spec.failureType ~= "engine" then return false end

    if type(vehicle.startMotor) == "function" and vehicle._evmOriginalStartMotor == nil then
        vehicle._evmOriginalStartMotor = vehicle.startMotor
        vehicle.startMotor = function(selfVehicle, ...)
            local s = evmGetVehicleSpec(selfVehicle.rootVehicle or selfVehicle)
            if s ~= nil and s.failureType == "engine" and s.engineFailurePhase == "stall" and (tonumber(s.engineFailurePhaseEnd or 0) or 0) > (g_time or 0) then
                return false
            end
            return selfVehicle._evmOriginalStartMotor(selfVehicle, ...)
        end
    end
    ExtendedVehicleMaintenance.attachEngineStallPhysics(vehicle, spec)
    return true
end

function ExtendedVehicleMaintenance.restoreEngineFailure(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle ~= nil and vehicle._evmOriginalStartMotor ~= nil then
        vehicle.startMotor = vehicle._evmOriginalStartMotor
        vehicle._evmOriginalStartMotor = nil
    end
    evmSetEngineStallMotorCap(vehicle, false)
    ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, "evmFailureEngineStall")
end

function evmSetEngineStallMotorCap(vehicle, active)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or vehicle.spec_motorized == nil then return end
    local motor = vehicle.spec_motorized.motor
    if motor == nil then return end

    if active == true then
        if motor._evmEngineStallOrigMaxForwardSpeed == nil and type(motor.maxForwardSpeed) == "number" then motor._evmEngineStallOrigMaxForwardSpeed = motor.maxForwardSpeed end
        if motor._evmEngineStallOrigMaxBackwardSpeed == nil and type(motor.maxBackwardSpeed) == "number" then motor._evmEngineStallOrigMaxBackwardSpeed = motor.maxBackwardSpeed end
        if motor._evmEngineStallOrigPeakMotorPower == nil and type(motor.peakMotorPower) == "number" then motor._evmEngineStallOrigPeakMotorPower = motor.peakMotorPower end
        if motor._evmEngineStallOrigMaxMotorPower == nil and type(motor.maxMotorPower) == "number" then motor._evmEngineStallOrigMaxMotorPower = motor.maxMotorPower end
        if motor._evmEngineStallOrigMaxRpm == nil and type(motor.maxRpm) == "number" then motor._evmEngineStallOrigMaxRpm = motor.maxRpm end
        if type(motor.maxForwardSpeed) == "number" then motor.maxForwardSpeed = 0.01 end
        if type(motor.maxBackwardSpeed) == "number" then motor.maxBackwardSpeed = 0.01 end
        if type(motor.peakMotorPower) == "number" then motor.peakMotorPower = 0.001 end
        if type(motor.maxMotorPower) == "number" then motor.maxMotorPower = 0.001 end
        if type(motor.maxRpm) == "number" then motor.maxRpm = 200 end
        if type(motor.setSpeedLimit) == "function" then pcall(motor.setSpeedLimit, motor, 0.01) end
        if type(motor.setTargetRpm) == "function" then pcall(motor.setTargetRpm, motor, 0) end
        if type(motor.setThrottle) == "function" then pcall(motor.setThrottle, motor, 0) end
    else
        if motor._evmEngineStallOrigMaxForwardSpeed ~= nil then motor.maxForwardSpeed = motor._evmEngineStallOrigMaxForwardSpeed end
        if motor._evmEngineStallOrigMaxBackwardSpeed ~= nil then motor.maxBackwardSpeed = motor._evmEngineStallOrigMaxBackwardSpeed end
        if motor._evmEngineStallOrigPeakMotorPower ~= nil then motor.peakMotorPower = motor._evmEngineStallOrigPeakMotorPower end
        if motor._evmEngineStallOrigMaxMotorPower ~= nil then motor.maxMotorPower = motor._evmEngineStallOrigMaxMotorPower end
        if motor._evmEngineStallOrigMaxRpm ~= nil then motor.maxRpm = motor._evmEngineStallOrigMaxRpm end
        motor._evmEngineStallOrigMaxForwardSpeed = nil
        motor._evmEngineStallOrigMaxBackwardSpeed = nil
        motor._evmEngineStallOrigPeakMotorPower = nil
        motor._evmEngineStallOrigMaxMotorPower = nil
        motor._evmEngineStallOrigMaxRpm = nil
    end
end

function ExtendedVehicleMaintenance.attachEngineStallPhysics(vehicle, spec)
    vehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if vehicle == nil or spec == nil or spec.failureType ~= "engine" then return false end

    return ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, "evmFailureEngineStall", function(selfVeh, axisForward, axisSide, doHandbrake, dt)
        local s = evmGetVehicleSpec(selfVeh.rootVehicle or selfVeh)
        if s ~= nil and s.failureType == "engine" and s.engineFailurePhase == "stall" and (tonumber(s.engineFailurePhaseEnd or 0) or 0) > (g_time or 0) then
            evmStopMotorForFailure(selfVeh)
            evmSetEngineStallMotorCap(selfVeh, true)
            return 0, axisSide, true, dt
        end
        evmSetEngineStallMotorCap(selfVeh, false)
        return axisForward, axisSide, doHandbrake, dt
    end)
end

function ExtendedVehicleMaintenance.attachFailurePhysics(vehicle, spec)
    vehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if vehicle == nil or spec == nil or spec.failureType ~= "flatTire" then return false end
    local severity = evmClamp(tonumber(spec.failureSeverity) or 0.75, 0.1, 1)
    local driftDirection = tonumber(spec.failureDriftDirection or 0)
    if driftDirection == 0 then
        driftDirection = (math.random() > 0.5) and 1 or -1
        spec.failureDriftDirection = driftDirection
    end
    local basePull = 0.18 + severity * 0.28
    local wobbleStrength = 0.04 + severity * 0.10
    local forwardClamp = evmClamp(0.72 - severity * 0.32, 0.32, 0.72)
    local hookKey = "evmFailureFlatTire"
    return ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, hookKey, function(selfVeh, axisForward, axisSide, doHandbrake, dt)
        local now = g_time or 0
        local wobble = math.sin(now / 220) * wobbleStrength
        local newSide = evmClamp((axisSide or 0) + driftDirection * basePull + wobble, -1, 1)
        local newForward = axisForward
        if newForward ~= nil and newForward > 0 then newForward = math.min(newForward, forwardClamp) end
        local pulseBrake = (now % 900) < 130
        if selfVeh.spec_drivable ~= nil then selfVeh.spec_drivable.steeringInput = newSide end
        return newForward, newSide, doHandbrake or pulseBrake, dt
    end)
end

function ExtendedVehicleMaintenance.restoreTires(vehicle)
    ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, "evmFailureFlatTire")
    ExtendedVehicleMaintenance.clearTireEffect(vehicle, "evmFlatTire")
    if vehicle ~= nil and vehicle.spec_wheels ~= nil and vehicle.spec_wheels.wheels ~= nil then
        if vehicle.setWheelTirePressure ~= nil then
            for i = 1, #vehicle.spec_wheels.wheels do pcall(vehicle.setWheelTirePressure, vehicle, i, 1) end
        end
        for _, wheel in pairs(vehicle.spec_wheels.wheels) do
            if wheel ~= nil then
                if wheel.setTirePressure ~= nil then pcall(wheel.setTirePressure, wheel, 1) end
                if wheel.tirePressure ~= nil then wheel.tirePressure = 1 end
                if wheel.wheelShape ~= nil and setWheelShapeTirePressure ~= nil then pcall(setWheelShapeTirePressure, wheel.wheelShape, 1) end
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- Batteriepanne: Motor startet nicht mehr. Laeuft aber weiter wenn er bereits an ist.
-- -----------------------------------------------------------------------
function ExtendedVehicleMaintenance.attachBatteryFailure(vehicle, spec)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or spec == nil or spec.failureType ~= "battery" then return false end
    -- KEIN Motor-Stop: Batterie leer = laeuft noch, aber kein Neustart
    if type(vehicle.startMotor) == "function" and vehicle._evmOriginalStartMotorBattery == nil then
        vehicle._evmOriginalStartMotorBattery = vehicle.startMotor
        vehicle.startMotor = function(selfVehicle, ...)
            local s = evmGetVehicleSpec(selfVehicle.rootVehicle or selfVehicle)
            if s ~= nil and s.failureType == "battery" then
                evmDbg("startMotor blocked: dead battery")
                return false
            end
            return selfVehicle._evmOriginalStartMotorBattery(selfVehicle, ...)
        end
    end
    evmDbg("attachBatteryFailure vehicle=%s", tostring(evmGetVehicleName(vehicle)))
    return true
end

function ExtendedVehicleMaintenance.restoreBatteryFailure(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil then return end
    if vehicle._evmOriginalStartMotorBattery ~= nil then
        vehicle.startMotor = vehicle._evmOriginalStartMotorBattery
        vehicle._evmOriginalStartMotorBattery = nil
    end
    local spec = evmGetVehicleSpec(vehicle)
    if spec ~= nil then
        -- MP-Fix: charge/voltage NICHT auf Defaults zurücksetzen!
        -- Die Werte sind Server-Owned und werden via EVMBatteryStateEvent gesynced.
        -- Das Setzen auf 1.0/12.6 hier hätte die soeben empfangenen Sync-Werte zerstört.
        if spec.failureType == "battery" then
            -- Nur falls noch eine echte Batterie-Panne läuft, sanft zurücksetzen.
            -- (Wird gleich überschrieben durch nächsten Sync, aber lieber ein sauberer Default.)
            spec.batteryCharge = math.max(tonumber(spec.batteryCharge) or 0, 0.5)
            spec.batteryVoltage = 12.6
        end
    end
    evmDbg("restoreBatteryFailure vehicle=%s", tostring(evmGetVehicleName(vehicle)))
end

function ExtendedVehicleMaintenance.clearFailure(vehicle)
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return end
    ExtendedVehicleMaintenance.restoreBatteryFailure(vehicle)
    ExtendedVehicleMaintenance.restoreTires(vehicle)
    ExtendedVehicleMaintenance.restoreEngineFailure(vehicle)
    ExtendedVehicleMaintenance.restoreRpmLimiter(vehicle)
    ExtendedVehicleMaintenance.restoreHydraulicLeak(vehicle)
    ExtendedVehicleMaintenance.restoreBrakeFault(vehicle)
    spec.failureType = ""
    spec.failureSeverity = 0
    spec.failureWheelIndex = 0
    spec.failureDriftDirection = 0
    spec.rpmLimitValue = nil
    spec.hydraulicLeakSeverity = nil
    spec.brakeFaultSeverity = nil
    spec.engineFailureTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.engineFailurePhase = nil
    spec.engineFailurePhaseEnd = nil
    spec.breakdownTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.failureWarnUntil = 0
    if vehicle ~= nil and vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then vehicle:raiseDirtyFlags(spec.dirtyFlag) end
end

function ExtendedVehicleMaintenance.applyFlatTire(vehicle, severity)
    if vehicle == nil then return end
    vehicle = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(vehicle)
    local amount = evmClamp(0.55 + (tonumber(severity) or 0.5) * 0.45, 0.55, 1)
    local clusterIndex = spec ~= nil and tonumber(spec.failureWheelIndex or 0) or 0
    if clusterIndex == nil or clusterIndex <= 0 then
        local preferredSide = (math.random() > 0.5) and 1 or -1
        local resolvedIndex = ExtendedVehicleMaintenance.getTireEffectCluster(vehicle, preferredSide)
        clusterIndex = tonumber(resolvedIndex or 0)
        if spec ~= nil then spec.failureWheelIndex = clusterIndex or 0 end
    end
    if clusterIndex ~= nil and clusterIndex > 0 then ExtendedVehicleMaintenance.setTireEffectAmount(vehicle, "evmFlatTire", clusterIndex, amount) end
    if spec ~= nil then ExtendedVehicleMaintenance.attachFailurePhysics(vehicle, spec) end
    local tirePressure = math.max(0.02, 0.18 - (tonumber(severity) or 0.5) * 0.12)
    if vehicle.setWheelTirePressure ~= nil and vehicle.spec_wheels ~= nil and vehicle.spec_wheels.wheels ~= nil then
        for i = 1, #vehicle.spec_wheels.wheels do
            if clusterIndex == nil or clusterIndex <= 0 or i == clusterIndex then pcall(vehicle.setWheelTirePressure, vehicle, i, tirePressure) end
        end
    end
end

-- v18: Helper - aus einer 0..1 severity die Tier-Klasse ableiten.
function ExtendedVehicleMaintenance.getSeverityTier(severity)
    local s = tonumber(severity) or 0
    if s < (ExtendedVehicleMaintenance.SEVERITY_THRESHOLD_MINOR or 0.40) then
        return ExtendedVehicleMaintenance.SEVERITY_TIER_MINOR
    elseif s >= (ExtendedVehicleMaintenance.SEVERITY_THRESHOLD_CRITICAL or 0.75) then
        return ExtendedVehicleMaintenance.SEVERITY_TIER_CRITICAL
    end
    return ExtendedVehicleMaintenance.SEVERITY_TIER_MAJOR
end

-- v18: Helper - aktive Pannen-Tier eines Fahrzeugs (oder nil wenn keine Panne).
function ExtendedVehicleMaintenance.getActiveFailureTier(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or spec.failureType == nil or spec.failureType == "" then return nil end
    return ExtendedVehicleMaintenance.getSeverityTier(spec.failureSeverity or 0)
end

-- v18: Helper - kann eine aktive Panne mit Quick-Fix vor Ort behoben werden?
-- Nur MINOR-Tier, nur Pannentypen die in QUICK_FIX_DEFINITIONS auftauchen, kein engine.
function ExtendedVehicleMaintenance.canQuickFix(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return false end
    local ft = spec.failureType
    if ft == nil or ft == "" or ft == "engine" or ft == "battery" then return false end
    local tier = ExtendedVehicleMaintenance.getActiveFailureTier(vehicle)
    if tier ~= ExtendedVehicleMaintenance.SEVERITY_TIER_MINOR then return false end
    if spec.isServiceActive == true then return false end
    if spec.quickFixUntil ~= nil and (g_time or 0) < spec.quickFixUntil then return false end
    local def = ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS and ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS[ft]
    return def ~= nil
end

-- v18: Helper - kann der Spieler "Weiterfahren mit Reduzierung" auf eine MINOR-Panne anwenden?
function ExtendedVehicleMaintenance.canLimpHome(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then return false end
    if spec.failureType == nil or spec.failureType == "" then return false end
    if spec.failureType == "engine" or spec.failureType == "battery" then return false end
    local tier = ExtendedVehicleMaintenance.getActiveFailureTier(vehicle)
    if tier ~= ExtendedVehicleMaintenance.SEVERITY_TIER_MINOR then return false end
    if spec.limpHomeUntil ~= nil and (g_time or 0) < spec.limpHomeUntil then return false end
    return true
end

-- v18: Quick-Fix vor Ort. Geld vom Konto, Cooldown-Sperre setzen, Panne komplett aufheben.
-- MUSS auf dem Server laufen. Auf reinen Clients verwendet der Action-Handler EVMQuickFixEvent.
function ExtendedVehicleMaintenance.applyQuickFix(vehicle)
    if g_server == nil then return false end
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or vehicle == nil then return false end
    if not ExtendedVehicleMaintenance.canQuickFix(vehicle) then return false end

    local ft = spec.failureType
    local def = ExtendedVehicleMaintenance.QUICK_FIX_DEFINITIONS[ft]
    if def == nil then return false end

    -- Geld vom Eigentuemer abziehen (nur Server kann das verlaesslich).
    local cost = tonumber(def.cost) or 0
    local farmId = nil
    if vehicle.getOwnerFarmId ~= nil then
        local ok, fid = pcall(vehicle.getOwnerFarmId, vehicle)
        if ok then farmId = fid end
    end
    if cost > 0 and farmId ~= nil and farmId ~= 0 and g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
        local moneyType = MoneyType ~= nil and (MoneyType.VEHICLE_RUNNING_COSTS or MoneyType.SHOP_VEHICLE_REPAIR or MoneyType.OTHER or 10) or 10
        pcall(g_currentMission.addMoney, g_currentMission, -cost, farmId, moneyType, true)
    end

    -- Panne aufheben.
    ExtendedVehicleMaintenance.clearFailure(vehicle)
    if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
        ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
    end

    -- Cooldown-Sperre setzen (gegen Spam).
    spec.quickFixUntil = (g_time or 0) + (tonumber(def.durationMs) or 180000)

    -- Kleiner Schadensanteil (Symbol fuer "geflickt, nicht repariert"). Verhindert dass
    -- der Spieler durch Quick-Fix den Wartungs-Verschleiss komplett umgeht.
    if vehicle.setDamageAmount ~= nil and vehicle.getDamageAmount ~= nil then
        local cur = 0
        local ok, dmg = pcall(vehicle.getDamageAmount, vehicle)
        if ok and dmg ~= nil then cur = tonumber(dmg) or 0 end
        local left = math.max(cur - 0.05, math.min(cur, 0.18)) -- Schaden minimal reduzieren auf >=18%
        pcall(vehicle.setDamageAmount, vehicle, evmClamp(left, 0, 1), true)
    end

    if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
        local label = (g_i18n ~= nil and g_i18n.getText ~= nil and g_i18n:getText("info_evm_quickFixDone")) or "Quick fix applied"
        g_currentMission:showBlinkingWarning(label, 2500)
    end

    if ExtendedVehicleMaintenance.debug == true or ExtendedVehicleMaintenance.BREAKDOWN_DEBUG == true then
        print(string.format("[EVM] quickFix applied vehicle=%s type=%s cost=%d cooldownMs=%d",
            tostring(evmGetVehicleName(vehicle)), tostring(ft), cost, tonumber(def.durationMs) or 0))
    end

    return true
end

-- v18: "Weiterfahren mit Reduzierung". Severity wird halbiert fuer LIMP_HOME_DURATION_MS.
-- Nach Ablauf greift die Panne wieder mit voller Staerke. Kein Materialpreis.
function ExtendedVehicleMaintenance.applyLimpHome(vehicle)
    if g_server == nil then return false end
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or vehicle == nil then return false end
    if not ExtendedVehicleMaintenance.canLimpHome(vehicle) then return false end

    spec.limpHomeUntil = (g_time or 0) + (ExtendedVehicleMaintenance.LIMP_HOME_DURATION_MS or 1800000)
    spec.limpHomeOriginalSeverity = spec.failureSeverity or 0.3
    spec.failureSeverity = (spec.limpHomeOriginalSeverity or 0.3) * (ExtendedVehicleMaintenance.LIMP_HOME_SEVERITY_MULT or 0.5)
    -- Subspec-Severities mitziehen, damit hydraulicLeak/brakeFault sofort schwaecher werden.
    if spec.hydraulicLeakSeverity ~= nil then
        spec.hydraulicLeakSeverity = spec.hydraulicLeakSeverity * (ExtendedVehicleMaintenance.LIMP_HOME_SEVERITY_MULT or 0.5)
    end
    if spec.brakeFaultSeverity ~= nil then
        spec.brakeFaultSeverity = spec.brakeFaultSeverity * (ExtendedVehicleMaintenance.LIMP_HOME_SEVERITY_MULT or 0.5)
    end
    if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
        ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
    end

    if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
        local label = (g_i18n ~= nil and g_i18n.getText ~= nil and g_i18n:getText("info_evm_limpHomeDone")) or "Limp home enabled - reduced effects"
        g_currentMission:showBlinkingWarning(label, 2500)
    end

    if ExtendedVehicleMaintenance.debug == true then
        print(string.format("[EVM] limpHome applied vehicle=%s untilMs=%d",
            tostring(evmGetVehicleName(vehicle)), spec.limpHomeUntil))
    end

    return true
end

-- v18: Tick-Logik fuer Limp-Home: nach Ablauf Severity zuruecksetzen.
function ExtendedVehicleMaintenance.updateLimpHomeExpiry(vehicle, spec)
    if vehicle == nil or spec == nil or g_server == nil then return end
    if spec.limpHomeUntil == nil or spec.limpHomeUntil == 0 then return end
    if (g_time or 0) < spec.limpHomeUntil then return end
    if spec.failureType == nil or spec.failureType == "" then
        spec.limpHomeUntil = 0
        spec.limpHomeOriginalSeverity = nil
        return
    end
    -- Limp-Home laeuft aus -> Severity wieder hochziehen.
    if spec.limpHomeOriginalSeverity ~= nil then
        spec.failureSeverity = spec.limpHomeOriginalSeverity
        if spec.hydraulicLeakSeverity ~= nil then
            spec.hydraulicLeakSeverity = spec.limpHomeOriginalSeverity
        end
        if spec.brakeFaultSeverity ~= nil then
            spec.brakeFaultSeverity = spec.limpHomeOriginalSeverity
        end
    end
    spec.limpHomeUntil = 0
    spec.limpHomeOriginalSeverity = nil
    if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
        ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
    end
    if ExtendedVehicleMaintenance.debug == true then
        print(string.format("[EVM] limpHome expired vehicle=%s severity restored", tostring(evmGetVehicleName(vehicle))))
    end
end


function ExtendedVehicleMaintenance.applyRandomFailure(vehicle, failureType, severity)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil or vehicle == nil then return false end
    severity = evmClamp(tonumber(severity) or 0.5, 0.1, 1)
    ExtendedVehicleMaintenance.clearFailure(vehicle)
    spec.failureType = failureType or "engine"
    spec.failureSeverity = severity
    spec.failureWarnUntil = 0
    spec.engineFailureTimer = 250
    spec.breakdownTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.nextNaturalBreakdownAllowedTime = (g_time or 0) + (ExtendedVehicleMaintenance.BREAKDOWN_MIN_VEHICLE_COOLDOWN or 2700000)
    if spec.failureType == "engine" then
        spec.engineFailurePhase = "randomStall"
        spec.engineFailurePhaseEnd = 0
        spec.engineFailureTimer = 350 + math.random(0, 1250)
        ExtendedVehicleMaintenance.attachEngineFailure(vehicle, spec)
    elseif spec.failureType == "flatTire" then
        ExtendedVehicleMaintenance.applyFlatTire(vehicle, severity)
    elseif spec.failureType == "rpmLimit" then
        spec.rpmLimitValue = ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM
        ExtendedVehicleMaintenance.attachRpmLimiter(vehicle, spec)
    elseif spec.failureType == "hydraulicLeak" then
        -- Hydraulikleck: Anbaugeräte können nicht mehr gehoben/gesenkt werden (Speed-Penalty)
        spec.hydraulicLeakSeverity = severity
        evmDbg("hydraulicLeak applied vehicle=%s severity=%.2f", tostring(evmGetVehicleName(vehicle)), severity)
    elseif spec.failureType == "brakeFault" then
        -- Bremsdefekt: Fahrzeug bremst schwächer / zieht zur Seite
        spec.brakeFaultSeverity = severity
        evmDbg("brakeFault applied vehicle=%s severity=%.2f", tostring(evmGetVehicleName(vehicle)), severity)
    end
    if vehicle.setDamageAmount ~= nil then
        local damage = math.max(evmGetVehicleDamage(vehicle), 0.55 + severity * 0.35)
        pcall(vehicle.setDamageAmount, vehicle, evmClamp(damage, 0, 1), true)
    end
    -- Keine globale Blink-Warnung mehr: der aktive Fehler wird im EVM-HUD als Kontrollleuchte angezeigt.
    if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then vehicle:raiseDirtyFlags(spec.dirtyFlag) end
    if g_server ~= nil and ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
        ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
    end
    evmDbg("random failure vehicle=%s type=%s severity=%.2f wheel=%s", tostring(evmGetVehicleName(vehicle)), tostring(spec.failureType), tonumber(severity), tostring(spec.failureWheelIndex or 0))
    return true
end

function ExtendedVehicleMaintenance.updateEngineFailure(vehicle, spec, dt)
    if vehicle == nil or spec == nil or spec.failureType ~= "engine" then return end
    if vehicle.spec_motorized == nil then return end

    ExtendedVehicleMaintenance.attachEngineFailure(vehicle, spec)

    local now = g_time or 0
    if spec.engineFailurePhase == "stall" then
        if (tonumber(spec.engineFailurePhaseEnd or 0) or 0) > now then
            evmStopMotorForFailure(vehicle)
            evmSetEngineStallMotorCap(vehicle, true)
            ExtendedVehicleMaintenance.attachEngineStallPhysics(vehicle, spec)
            return
        else
            spec.engineFailurePhase = "randomStall"
            spec.engineFailurePhaseEnd = 0
            evmSetEngineStallMotorCap(vehicle, false)
        end
    end

    local delta = tonumber(dt or 0) or 0
    local damage = evmGetVehicleDamage(vehicle)
    local severity = evmClamp(math.max(tonumber(spec.failureSeverity) or 0.85, damage), 0.25, 1)

    local load = 0
    if vehicle.getMotorLoadPercentage ~= nil then
        local ok, value = pcall(vehicle.getMotorLoadPercentage, vehicle)
        if ok then load = evmClamp(tonumber(value or 0) or 0, 0, 1) end
    end

    -- Manuell gesetzter Motorfehler: erster Aussetzer fast sofort, danach alle paar Sekunden.
    local minInterval = math.floor(evmClamp(2600 - severity * 900, 1200, 2600))
    local maxInterval = math.floor(evmClamp(6200 - severity * 1800, minInterval + 900, 6200))
    spec.engineFailureTimer = (tonumber(spec.engineFailureTimer) or 10) - delta
    if spec.engineFailureTimer > 0 then return end

    spec.engineFailureTimer = math.random(minInterval, maxInterval)

    local isStarted = true
    if vehicle.getIsMotorStarted ~= nil then
        local okStarted, started = pcall(vehicle.getIsMotorStarted, vehicle)
        if okStarted then isStarted = started == true end
    end

    local rawSpeed = math.abs(tonumber(vehicle.lastSpeedReal or vehicle.lastSpeed or 0) or 0)
    local moving = rawSpeed > 0.0005
    local entered = vehicle.getIsEntered ~= nil and vehicle:getIsEntered() == true

    -- Nicht nur auf getIsMotorStarted verlassen: Im MP kann dieser Status kurz falsch sein.
    if isStarted or moving or entered then
        local chance = evmClamp(0.88 + severity * 0.10 + load * 0.06, 0.88, 1.0)
        if math.random() < chance then
            spec.engineFailurePhase = "stall"
            spec.engineFailurePhaseEnd = now + math.floor(2800 + severity * 2200)
            evmStopMotorForFailure(vehicle)
            evmSetEngineStallMotorCap(vehicle, true)
            ExtendedVehicleMaintenance.attachEngineStallPhysics(vehicle, spec)
            print(string.format("[EVM] engine failure HARD STALL vehicle=%s side=%s durationMs=%d", tostring(evmGetVehicleName(vehicle)), tostring((vehicle.isServer and "server") or "client"), math.floor((spec.engineFailurePhaseEnd or now) - now)))
        end
    end
end

function ExtendedVehicleMaintenance.updateRpmLimiterFailure(vehicle, spec, dt)
    if vehicle == nil or spec == nil or spec.failureType ~= "rpmLimit" then return end
    ExtendedVehicleMaintenance.attachRpmLimiter(vehicle.rootVehicle or vehicle, spec)
    -- Keine Blink-Warnung mehr: Notlauf wird im EVM-HUD angezeigt.
end

function ExtendedVehicleMaintenance.attachBrakeFault(vehicle, spec)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or spec == nil or spec.failureType ~= "brakeFault" then return false end
    local severity = evmClamp(tonumber(spec.failureSeverity or spec.brakeFaultSeverity) or 0.65, 0.1, 1)
    spec.brakeFaultSeverity = severity
    local driftDirection = tonumber(spec.failureDriftDirection or 0)
    if driftDirection == 0 then
        driftDirection = (math.random() > 0.5) and 1 or -1
        spec.failureDriftDirection = driftDirection
    end
    return ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, "evmFailureBrakeFault", function(selfVeh, axisForward, axisSide, doHandbrake, dt)
        local newForward = axisForward
        local newSide = axisSide or 0
        local rawSpeed = math.abs(tonumber(selfVeh.lastSpeedReal or selfVeh.lastSpeed or 0) or 0)
        local speedKph = rawSpeed < 1 and rawSpeed * 3600 or (rawSpeed < 50 and rawSpeed * 3.6 or rawSpeed)
        if newForward ~= nil and newForward < -0.05 then
            -- Bremsdefekt: Brems-/Rueckwaertsinput wird deutlich schwaecher.
            newForward = newForward * evmClamp(0.48 - severity * 0.28, 0.12, 0.48)
        end
        if speedKph > 8 then
            newSide = evmClamp(newSide + driftDirection * (0.04 + severity * 0.10), -1, 1)
        end
        return newForward, newSide, doHandbrake, dt
    end)
end

function ExtendedVehicleMaintenance.restoreBrakeFault(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, "evmFailureBrakeFault")
end

function ExtendedVehicleMaintenance.attachHydraulicLeak(vehicle, spec)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    if vehicle == nil or spec == nil or spec.failureType ~= "hydraulicLeak" then return false end
    local severity = evmClamp(tonumber(spec.failureSeverity or spec.hydraulicLeakSeverity) or 0.65, 0.1, 1)
    spec.hydraulicLeakSeverity = severity
    return ExtendedVehicleMaintenance.attachVehiclePhysicsHook(vehicle, "evmFailureHydraulicLeak", function(selfVeh, axisForward, axisSide, doHandbrake, dt)
        local newForward = axisForward
        if newForward ~= nil and newForward > 0 then
            -- Hydraulikleck/Leistungsabfall: Maschine faehrt noch, aber deutlich zaeher.
            newForward = math.min(newForward, evmClamp(0.82 - severity * 0.32, 0.35, 0.82))
        end
        return newForward, axisSide, doHandbrake, dt
    end)
end

function ExtendedVehicleMaintenance.restoreHydraulicLeak(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    ExtendedVehicleMaintenance.detachVehiclePhysicsHook(vehicle, "evmFailureHydraulicLeak")
end

function ExtendedVehicleMaintenance.applyFailureEffects(vehicle, spec, dt, isServerSide)
    if vehicle == nil or spec == nil or spec.failureType == nil or spec.failureType == "" then return end
    local root = vehicle.rootVehicle or vehicle
    if spec.failureType == "flatTire" then
        ExtendedVehicleMaintenance.applyFlatTire(root, spec.failureSeverity or 0.5)
    elseif spec.failureType == "rpmLimit" then
        spec.rpmLimitValue = tonumber(spec.rpmLimitValue or ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM) or ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM
        ExtendedVehicleMaintenance.updateRpmLimiterFailure(root, spec, dt)
    elseif spec.failureType == "hydraulicLeak" then
        ExtendedVehicleMaintenance.attachHydraulicLeak(root, spec)
    elseif spec.failureType == "brakeFault" then
        ExtendedVehicleMaintenance.attachBrakeFault(root, spec)
    elseif spec.failureType == "engine" then
        -- Auch auf Clients ausfuehren, damit der Fahrer im MP die Aussetzer sofort merkt.
        -- Der Server fuehrt dieselbe Logik autoritativ aus.
        ExtendedVehicleMaintenance.updateEngineFailure(root, spec, dt)
    elseif spec.failureType == "battery" then
        ExtendedVehicleMaintenance.attachBatteryFailure(root, spec)
    end
end

function ExtendedVehicleMaintenance.receiveFailureStateFromServer(vehicle, failureType, severity, wheelIndex, driftDirection, rpmLimit)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil and evmCreateRuntimeSpec ~= nil then
        spec = evmCreateRuntimeSpec(vehicle)
    end
    if vehicle == nil or spec == nil then return end

    -- Erst lokale alte Hooks/Effekte entfernen, dann den bestaetigten Server-State setzen.
    ExtendedVehicleMaintenance.restoreTires(vehicle)
    ExtendedVehicleMaintenance.restoreEngineFailure(vehicle)
    ExtendedVehicleMaintenance.restoreRpmLimiter(vehicle)
    ExtendedVehicleMaintenance.restoreHydraulicLeak(vehicle)
    ExtendedVehicleMaintenance.restoreBrakeFault(vehicle)
    ExtendedVehicleMaintenance.restoreBatteryFailure(vehicle)

    failureType = failureType or ""
    if failureType == "" then
        spec.failureType = ""
        spec.failureSeverity = 0
        spec.failureWheelIndex = 0
        spec.failureDriftDirection = 0
        spec.rpmLimitValue = nil
        spec.hydraulicLeakSeverity = nil
        spec.brakeFaultSeverity = nil
        return
    end

    spec.failureType = failureType
    spec.failureSeverity = tonumber(severity) or 0.5
    spec.failureWheelIndex = tonumber(wheelIndex) or 0
    spec.failureDriftDirection = tonumber(driftDirection) or 0
    if failureType == "rpmLimit" then
        spec.rpmLimitValue = tonumber(rpmLimit) or ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM
    elseif failureType == "battery" then
        spec.batteryCharge = 0.0
        spec.batteryVoltage = 7.0 + math.random() * 2.0
    end
    spec.breakdownTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.engineFailureTimer = 10
    spec.engineFailurePhase = "randomStall"
    spec.engineFailurePhaseEnd = 0
    ExtendedVehicleMaintenance.applyFailureEffects(vehicle, spec, 0, false)
end

function ExtendedVehicleMaintenance.receiveBatteryStateFromServer(vehicle, charge, voltage, failureType, failureSeverity)
    -- MP-Fix v9:
    -- Event kann auf dem Client auf einem Child-/Komponentenfahrzeug ankommen,
    -- waehrend das HUD spaeter die Spec vom rootVehicle nutzt. Darum schreiben wir
    -- den Batterie-State bewusst auf beide Specs.
    local eventVehicle = vehicle
    local rootVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    if rootVehicle == nil then return end

    local c = evmClamp(tonumber(charge) or 1.0, 0, 1)
    local v = evmClamp(tonumber(voltage) or 12.7, 6.0, 15.5)
    local ft = failureType or ""
    local fs = tonumber(failureSeverity) or 0

    local function applyTo(target)
        if target == nil then return end
        local spec = evmGetVehicleSpec(target)
        if spec == nil and evmCreateRuntimeSpec ~= nil then
            spec = evmCreateRuntimeSpec(target)
        end
        if spec == nil then return end

        spec.batteryCharge = c
        spec.batteryVoltage = v
        spec._batteryClientSyncTime = g_time or 0
        spec._batteryClientSynced = true

        -- DIAGNOSTIC: log spec identity
        if (g_time or 0) % 4000 < 100 then
            print(string.format("[EVM] applyTo target=%s rootSame=%s specPtr=%s wroteCharge=%.4f",
                tostring(evmGetVehicleName(target)),
                tostring(target == (target.rootVehicle or target)),
                tostring(spec):sub(8, 18),
                tonumber(c)))
        end

        if ft == "battery" then
            spec.failureType = "battery"
            spec.failureSeverity = fs > 0 and fs or spec.failureSeverity or 1.0
            ExtendedVehicleMaintenance.attachBatteryFailure(target, spec)
        elseif spec.failureType == "battery" then
            spec.failureType = ""
            spec.failureSeverity = 0
            ExtendedVehicleMaintenance.restoreBatteryFailure(target)
        else
            ExtendedVehicleMaintenance.restoreBatteryFailure(target)
        end
    end

    applyTo(rootVehicle)
    if eventVehicle ~= rootVehicle then
        applyTo(eventVehicle)
    end

    local current = evmGetCurrentLocalVehicle ~= nil and evmGetCurrentLocalVehicle() or nil
    if current ~= nil and (current == rootVehicle or current.rootVehicle == rootVehicle) then
        applyTo(current)
    end

    if g_client ~= nil then
        -- v14: Client-Debug pro Fahrzeug statt global.
        local dbgSpec = evmGetVehicleSpec(rootVehicle)
        if dbgSpec ~= nil then
            dbgSpec._batteryClientDebugTimer = dbgSpec._batteryClientDebugTimer or 0
            if (g_time or 0) - dbgSpec._batteryClientDebugTimer > 1500 then
                dbgSpec._batteryClientDebugTimer = g_time or 0
                print(string.format("[EVM] BATTERY clientSync vehicle=%s eventVehicle=%s charge=%.4f volt=%.2f failure=%s",
                    tostring(evmGetVehicleName(rootVehicle)), tostring(evmGetVehicleName(eventVehicle)), tonumber(c or 0), tonumber(v or 0), tostring(ft)))
            end
        end
    end
end

function ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
    if vehicle ~= nil then vehicle = vehicle.rootVehicle or vehicle end
    local spec = evmGetVehicleSpec(vehicle)
    if vehicle == nil or spec == nil then return end
    if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        pcall(vehicle.raiseDirtyFlags, vehicle, spec.dirtyFlag)
    end
    if g_server ~= nil and EVMFailureStateEvent ~= nil then
        EVMFailureStateEvent.sendEvent(
            vehicle,
            spec.failureType or "",
            spec.failureSeverity or 0,
            spec.failureWheelIndex or 0,
            spec.failureDriftDirection or 0,
            spec.rpmLimitValue or ExtendedVehicleMaintenance.RPM_LIMIT_FAILURE_RPM or 0
        )
    end
end

function ExtendedVehicleMaintenance.updateActiveFailure(vehicle, spec, dt, isServerSide)
    if vehicle == nil or spec == nil or spec.failureType == nil or spec.failureType == "" then return end
    ExtendedVehicleMaintenance.applyFailureEffects(vehicle, spec, dt, isServerSide == true)
end

function ExtendedVehicleMaintenance.updateBreakdownRisk(vehicle, spec, dt, source)
    if vehicle == nil or spec == nil or spec.isServiceActive then return end
    if spec.failureType ~= nil and spec.failureType ~= "" then
        ExtendedVehicleMaintenance.updateActiveFailure(vehicle, spec, dt, true)
        return
    end

    -- Nur motorisierte Fahrzeuge bekommen Motor-Pannen; Geräte/Anhänger haben eigene Checks
    local cat = ExtendedVehicleMaintenance.getVehicleCategory(vehicle)
    local isMotorized = vehicle.spec_motorized ~= nil
    local isImplement = (cat.name == "implement" or cat.name == "tool" or cat.name == "trailer")

    -- Motorisierte: nur wenn Motor läuft
    if isMotorized and not isImplement then
        if vehicle.getIsMotorStarted ~= nil and not vehicle:getIsMotorStarted() then return end
    end

    spec.breakdownTimer = (spec.breakdownTimer or ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL) - (dt or 0)
    if spec.breakdownTimer > 0 then return end
    spec.breakdownTimer = (ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL or 60000) + math.random(0, 30000)

    local now = g_time or 0
    local globalNext = tonumber(ExtendedVehicleMaintenance._nextNaturalBreakdownAllowedTime or 0) or 0
    local vehicleNext = tonumber(spec.nextNaturalBreakdownAllowedTime or 0) or 0
    if now < globalNext or now < vehicleNext then
        if ExtendedVehicleMaintenance.BREAKDOWN_DEBUG == true or ExtendedVehicleMaintenance.debug == true then
            print(string.format("[EVM] breakdown skipped source=%s vehicle=%s cooldown globalLeft=%.1fmin vehicleLeft=%.1fmin",
                tostring(source or "tick"),
                tostring(evmGetVehicleName(vehicle)),
                math.max(0, globalNext - now) / 60000,
                math.max(0, vehicleNext - now) / 60000))
        end
        return
    end

    local damage = evmGetVehicleDamage(vehicle)
    local isDue, remainingHours, remainingDays = ExtendedVehicleMaintenance.isDue(vehicle)

    -- Basiswahrscheinlichkeit mit Kategorie-Multiplikator
    local catMult = tonumber(cat.breakdownMult or 1.0) or 1.0
    local chance = (ExtendedVehicleMaintenance.BREAKDOWN_BASE_CHANCE or 0.00025) * catMult

    -- v16: Wear-Faktor. Frische Fahrzeuge sollen praktisch keine zufälligen Pannen
    -- bekommen; je näher das Fahrzeug an "Wartung fällig" rückt, desto höher die Chance.
    -- wearFactor liegt zwischen 0.05 (gerade frisch gewartet) und ~1.0 (kurz vor fällig).
    -- Wir nehmen den niedrigeren der zwei Pools (Stunden vs. Tage) als Treiber, damit
    -- ein Anhänger der seit 200 Spieltagen nichts gemacht hat ähnlich behandelt wird wie
    -- ein Traktor mit vielen Betriebsstunden.
    local hoursPool = (cat.hoursInterval or 100)
    local daysPool  = (cat.daysInterval  or 60)
    local hoursUsedFrac = 1.0 - math.min(1.0, math.max(0.0, (remainingHours or 0) / math.max(1, hoursPool)))
    local daysUsedFrac  = 1.0 - math.min(1.0, math.max(0.0, (remainingDays  or 0) / math.max(1, daysPool)))
    local wearFactor = math.max(hoursUsedFrac, daysUsedFrac)
    -- Floor & Easing: unter 30% Verschleiß effektiv kein Pannen-Bonus, danach quadratisch
    -- ansteigend bis zur Fälligkeit. Das fühlt sich realistischer an als ein konstanter Wert.
    local wearScaled = 0
    if wearFactor > 0.30 then
        local norm = (wearFactor - 0.30) / 0.70  -- 0..1 zwischen 30% und 100% Verbrauch
        wearScaled = norm * norm
    end
    chance = chance * (0.20 + 0.80 * wearScaled) -- 20%..100% der base chance je nach Verschleiß

    if damage > (ExtendedVehicleMaintenance.BREAKDOWN_MIN_DAMAGE or 0.45) then
        chance = chance + (damage - ExtendedVehicleMaintenance.BREAKDOWN_MIN_DAMAGE) * 0.07 * catMult
    end
    if isDue then
        chance = chance + (ExtendedVehicleMaintenance.BREAKDOWN_OVERDUE_CHANCE or 0.006) * catMult
    else
        if remainingHours <= 3 then chance = chance + 0.015 * catMult end
        if remainingDays  <= 2 then chance = chance + 0.01  * catMult end
    end
    chance = evmClamp(chance, 0, ExtendedVehicleMaintenance.BREAKDOWN_MAX_CHANCE or 0.18)

    if ExtendedVehicleMaintenance.BREAKDOWN_DEBUG == true or ExtendedVehicleMaintenance.debug == true then
        print(string.format("[EVM] breakdown check source=%s vehicle=%s cat=%s motor=%s damage=%.3f wear=%.2f due=%s chance=%.5f",
            tostring(source or "tick"),
            tostring(evmGetVehicleName(vehicle)),
            tostring(cat.name),
            tostring(isMotorized and (vehicle.getIsMotorStarted == nil or vehicle:getIsMotorStarted()) or false),
            tonumber(damage or 0),
            tonumber(wearFactor or 0),
            tostring(isDue),
            tonumber(chance or 0)))
    end

    if math.random() > chance then return end

    -- Pannen-Typ je nach Fahrzeugkategorie
    local severity = evmClamp(damage + (isDue and 0.35 or 0.15), 0.2, 1)
    local roll = math.random()
    local failure

    if isImplement or cat.name == "trailer" then
        -- Anhänger/Geräte: kein Motorausfall, aber hydraulik/bremsen/licht
        if roll < 0.5 then
            failure = "flatTire"
        elseif roll < 0.8 then
            failure = "hydraulicLeak"
        else
            failure = "brakeFault"
        end
        -- Geräte haben keinen Motor → nur flatTire wenn kein Motor
        if not isMotorized then
            if roll < 0.6 then
                failure = "flatTire"
            elseif roll < 0.85 then
                failure = "hydraulicLeak"
            else
                failure = "brakeFault"
            end
        end
    elseif cat.name == "harvester" then
        -- Mähdrescher: mehr Pannen-Vielfalt
        if roll < 0.25 then
            failure = "engine"
        elseif roll < 0.45 then
            failure = "flatTire"
        elseif roll < 0.65 then
            failure = "rpmLimit"
        elseif roll < 0.82 then
            failure = "hydraulicLeak"
        else
            failure = "brakeFault"
        end
    else
        -- Traktor: klassische Pannen
        if roll < 0.33 then
            failure = "engine"
        elseif roll < 0.56 then
            failure = "flatTire"
        elseif roll < 0.75 then
            failure = "rpmLimit"
        elseif roll < 0.90 then
            failure = "hydraulicLeak"
        else
            failure = "brakeFault"
        end
    end

    ExtendedVehicleMaintenance.applyRandomFailure(vehicle, failure, severity)

    -- Nach einer natuerlichen Panne nicht direkt das naechste Fahrzeug erwischen.
    local now2 = g_time or 0
    ExtendedVehicleMaintenance._nextNaturalBreakdownAllowedTime = now2 + (ExtendedVehicleMaintenance.BREAKDOWN_MIN_GLOBAL_COOLDOWN or 720000)
    spec.nextNaturalBreakdownAllowedTime = now2 + (ExtendedVehicleMaintenance.BREAKDOWN_MIN_VEHICLE_COOLDOWN or 2700000)
end

local function evmIsAdminOrSP()
    if g_server == nil or g_client == nil then return true end
    local mission = g_currentMission
    if mission ~= nil and mission.isMasterUser == true then return true end
    if g_localPlayer ~= nil then
        if type(g_localPlayer.getIsAdmin) == "function" then
            local ok, isAdmin = pcall(g_localPlayer.getIsAdmin, g_localPlayer)
            if ok and isAdmin == true then return true end
        end
        if g_server ~= nil and g_client ~= nil then
            local serverCon = g_client:getServerConnection()
            if serverCon ~= nil and type(serverCon.getIsLocal) == "function" then
                local ok2, isLocal = pcall(serverCon.getIsLocal, serverCon)
                if ok2 and isLocal == true then return true end
            end
        end
    end
    return false
end

local function evmAdminGuard(commandName)
    if not evmIsAdminOrSP() then
        return "EVM: Befehl '" .. tostring(commandName) .. "' erfordert Admin-Rechte im Multiplayer."
    end
    return nil
end

local function evmConsoleParseArgs(...)
    local args = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" then
            table.insert(args, v)
        end
    end
    return args
end

function ExtendedVehicleMaintenance.consoleCommandFailure(...)
    local adminErr = evmAdminGuard("evmFailure")
    if adminErr ~= nil then return adminErr end
    local args = evmConsoleParseArgs(...)
    local failureType = nil
    for _, arg in ipairs(args) do
        local normalized = ExtendedVehicleMaintenance.normalizeFailureType(arg)
        if normalized ~= nil then
            failureType = normalized
            break
        end
    end
    failureType = failureType or "engine"

    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end

    vehicle = vehicle.rootVehicle or vehicle
    local spec, specErr = evmRequireSpec(vehicle)
    if spec == nil then
        return specErr
    end

    local ok = false
    if EVMFailureEvent ~= nil then
        ok = EVMFailureEvent.sendEvent(vehicle, failureType, 0.9, false) == true
    else
        ok = ExtendedVehicleMaintenance.applyRandomFailure(vehicle, failureType, 0.9) == true
        if ok and ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
            ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
        end
    end
    spec = evmGetVehicleSpec(vehicle)
    if ok then
        local extra = ""
        if failureType == "flatTire" then
            extra = " wheel=" .. tostring(spec ~= nil and spec.failureWheelIndex or 0)
        end
        if g_server == nil and g_client ~= nil then
            return "Failure request sent to server: " .. failureType .. " on " .. tostring(evmGetVehicleName(vehicle))
        end
        return "Applied failure: " .. failureType .. " on " .. tostring(evmGetVehicleName(vehicle)) .. extra
    end
    return "Could not apply failure on " .. tostring(evmGetVehicleName(vehicle)) .. " (no EVM spec?)"
end

function ExtendedVehicleMaintenance.consoleCommandClearFailure(...)
    local adminErr = evmAdminGuard("evmClearFailure")
    if adminErr ~= nil then return adminErr end
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end
    vehicle = vehicle.rootVehicle or vehicle
    local spec, specErr = evmRequireSpec(vehicle)
    if spec == nil then
        return specErr
    end
    local hadFailure = spec.failureType ~= nil and spec.failureType ~= ""
    local sent = false
    if EVMFailureEvent ~= nil then
        sent = EVMFailureEvent.sendEvent(vehicle, "", 0, true) == true
    else
        ExtendedVehicleMaintenance.clearFailure(vehicle)
        if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
            ExtendedVehicleMaintenance.broadcastFailureState(vehicle)
        elseif vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
            vehicle:raiseDirtyFlags(spec.dirtyFlag)
        end
        sent = true
    end
    if sent and g_server == nil and g_client ~= nil then
        return "Clear failure request sent to server on " .. tostring(evmGetVehicleName(vehicle))
    end
    if hadFailure then
        return "Failure cleared on " .. tostring(evmGetVehicleName(vehicle))
    end
    return "No active failure on " .. tostring(evmGetVehicleName(vehicle))
end

function ExtendedVehicleMaintenance.consoleCommandSetDue(...)
    local adminErr = evmAdminGuard("evmSetDue")
    if adminErr ~= nil then return adminErr end
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end
    vehicle = vehicle.rootVehicle or vehicle
    local spec, specErr = evmRequireSpec(vehicle)
    if spec == nil then
        return specErr
    end
    spec.hoursPool = 0
    spec.daysPool = 0
    if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        vehicle:raiseDirtyFlags(spec.dirtyFlag)
    end
    return "Maintenance set to DUE on " .. tostring(evmGetVehicleName(vehicle))
end

function ExtendedVehicleMaintenance.consoleCommandResetPool(...)
    local adminErr = evmAdminGuard("evmResetPool")
    if adminErr ~= nil then return adminErr end
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end
    vehicle = vehicle.rootVehicle or vehicle
    local spec, specErr = evmRequireSpec(vehicle)
    if spec == nil then
        return specErr
    end
    spec.hoursPool = ExtendedVehicleMaintenance.MAX_HOURS
    spec.daysPool = ExtendedVehicleMaintenance.MAX_DAYS
    spec.lastServiceOperatingTimeMs = evmGetOperatingTimeMs(vehicle)
    spec.lastServiceGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.failureDriftDirection = nil
    if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        vehicle:raiseDirtyFlags(spec.dirtyFlag)
    end
    return string.format("Maintenance pool reset: %.0f h / %.0f d on %s",
        ExtendedVehicleMaintenance.MAX_HOURS,
        ExtendedVehicleMaintenance.MAX_DAYS,
        tostring(evmGetVehicleName(vehicle)))
end

function ExtendedVehicleMaintenance.consoleCommandStatus(...)
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end
    vehicle = vehicle.rootVehicle or vehicle
    local spec, specErr = evmRequireSpec(vehicle)
    if spec == nil then
        return specErr
    end
    local remainingHours, remainingDays = ExtendedVehicleMaintenance.getRemainingMaintenance(vehicle)
    local isDue = ExtendedVehicleMaintenance.isDue(vehicle)
    local damage = evmGetVehicleDamage(vehicle)
    local failure = (spec.failureType ~= nil and spec.failureType ~= "") and spec.failureType or "none"
    local severity = spec.failureSeverity or 0
    local serviceActive = spec.isServiceActive and "YES" or "no"
    return string.format(
        "[EVM Status] %s | due=%s | hoursLeft=%.1f | daysLeft=%.1f | damage=%.0f%% | failure=%s(%.0f%%) | inService=%s",
        tostring(evmGetVehicleName(vehicle)),
        isDue and "YES" or "no",
        tonumber(remainingHours or 0),
        tonumber(remainingDays or 0),
        (tonumber(damage or 0)) * 100,
        failure,
        severity * 100,
        serviceActive
    )
end

-- v21: Diagnose welche Repair-Funktionen ein Fahrzeug hat und was sie zurueckgeben.
-- Nuetzlich um zu verstehen warum der Haendler-"REPARIEREN"-Button bei motorisierten Fahrzeugen
-- trotz EVM-Hook noch sichtbar ist.
function ExtendedVehicleMaintenance.consoleCommandRepairDiag(...)
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "Kein Fahrzeug gefunden. Einsteigen oder naeherkommen."
    end
    vehicle = vehicle.rootVehicle or vehicle
    local out = { string.format("[EVM RepairDiag] vehicle=%s motorized=%s", tostring(evmGetVehicleName(vehicle)), tostring(vehicle.spec_motorized ~= nil)) }
    for _, fnName in ipairs({"getRepairPrice","getRepairShopPrice","getRepairShopBasePrice","getCanBeRepaired","getDailyUpkeep","repairVehicle"}) do
        local fn = vehicle[fnName]
        if type(fn) == "function" then
            local ok, val = pcall(fn, vehicle)
            if ok then
                table.insert(out, string.format("  %s() -> %s", fnName, tostring(val)))
            else
                table.insert(out, string.format("  %s() -> ERROR %s", fnName, tostring(val)))
            end
        else
            table.insert(out, string.format("  %s -> not a function", fnName))
        end
    end
    return table.concat(out, "\n")
end

function ExtendedVehicleMaintenance.consoleCommandDebug(...)
    local args = evmConsoleParseArgs(...)
    local toggle = nil
    for _, arg in ipairs(args) do
        if arg == "1" or arg == "on" or arg == "true" then
            toggle = true
        elseif arg == "0" or arg == "off" or arg == "false" then
            toggle = false
        end
    end
    if toggle == nil then
        ExtendedVehicleMaintenance.debug = not ExtendedVehicleMaintenance.debug
    else
        ExtendedVehicleMaintenance.debug = toggle
    end
    return "EVM debug mode: " .. (ExtendedVehicleMaintenance.debug and "ON" or "OFF")
end

function ExtendedVehicleMaintenance.consoleCommandDiag(...)
    local lines = {}
    local mission = g_currentMission

    local controlled = mission ~= nil and (mission.controlledVehicle or mission.currentVehicle) or nil
    if controlled == nil and g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        local okCurrent, playerVehicle = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
        if okCurrent then
            controlled = playerVehicle
        end
    end
    local controlled_name = controlled ~= nil and tostring(evmGetVehicleName(controlled)) or "nil"
    local spec_present = controlled ~= nil and evmGetVehicleSpec(controlled.rootVehicle or controlled) ~= nil
    table.insert(lines, string.format("controlledVehicle: %s | spec_extendedVehicleMaintenance: %s", controlled_name, tostring(spec_present)))

    local vehicleTypePatched = tostring(ExtendedVehicleMaintenance._vehicleTypesPatched)
    table.insert(lines, string.format("_vehicleTypesPatched: %s", vehicleTypePatched))

    local specManager = g_specializationManager
    local specRegistered = false
    if specManager ~= nil and specManager.getSpecializationByName ~= nil then
        local envName = ExtendedVehicleMaintenance.MOD_NAME or g_currentModName or "FS25_ExtendedVehicleMaintenance"
        local s = specManager:getSpecializationByName(envName .. "." .. ExtendedVehicleMaintenance.SPEC_NAME)
            or specManager:getSpecializationByName(ExtendedVehicleMaintenance.SPEC_NAME)
        specRegistered = s ~= nil
    end
    table.insert(lines, string.format("specialization '%s' registered: %s", ExtendedVehicleMaintenance.SPEC_NAME, tostring(specRegistered)))

    local vehicleCount = 0
    local vehicleWithSpec = 0
    if mission ~= nil then
        local function countVehicle(v)
            if v == nil then return end
            local root = v.rootVehicle or v
            vehicleCount = vehicleCount + 1
            if evmGetVehicleSpec(root) ~= nil then vehicleWithSpec = vehicleWithSpec + 1 end
        end
        if mission.vehicles ~= nil then for _, v in ipairs(mission.vehicles) do countVehicle(v) end end
        if mission.vehicleSystem ~= nil and mission.vehicleSystem.vehicles ~= nil then
            for _, v in pairs(mission.vehicleSystem.vehicles) do countVehicle(v) end
        end
    end
    table.insert(lines, string.format("vehicles in mission: %d | with EVM spec: %d", vehicleCount, vehicleWithSpec))

    local result = table.concat(lines, " | ")
    print("[EVM Diag] " .. result)
    return result
end

function ExtendedVehicleMaintenance:consoleCommandCollisionTest(value)
    local vehicle = evmGetCurrentLocalVehicle()
    if vehicle == nil then
        vehicle = evmFindConsoleFailureVehicle()
    end

    vehicle = evmNormalizeVehicle(vehicle)
    if vehicle == nil then
        local msg = "[EVM] CollisionTest: kein aktuelles/nahes Fahrzeug gefunden"
        print(msg)
        return msg
    end

    local spec = evmGetVehicleSpec(vehicle)
    if spec == nil then
        spec = evmCreateRuntimeSpec(vehicle)
    end

    local addPercent = tonumber(value) or 5
    local addDamage = evmClamp(addPercent / 100, 0.001, 1)
    local oldDamage = evmGetVehicleDamage(vehicle)
    local newDamage = evmClamp(oldDamage + addDamage, 0, 1)
    local applied = false

    if vehicle.setDamageAmount ~= nil then
        local okSet, errSet = pcall(vehicle.setDamageAmount, vehicle, newDamage, true)
        applied = okSet == true
        if not okSet then
            print(string.format("[EVM] CollisionTest setDamageAmount failed vehicle=%s err=%s", tostring(evmGetVehicleName(vehicle)), tostring(errSet)))
        end
    end

    if not applied and vehicle.spec_wearable ~= nil then
        vehicle.spec_wearable.damage = newDamage
        applied = true
    end

    if applied then
        if vehicle.raiseDirtyFlags ~= nil and spec ~= nil and spec.dirtyFlag ~= nil then
            vehicle:raiseDirtyFlags(spec.dirtyFlag)
        end
        local msg = string.format("[EVM] CollisionTest applied vehicle=%s %.2f%% -> %.2f%%", tostring(evmGetVehicleName(vehicle)), oldDamage * 100, newDamage * 100)
        print(msg)
        return msg
    end

    local msg = string.format("[EVM] CollisionTest failed vehicle=%s reason=no damage setter/spec_wearable", tostring(evmGetVehicleName(vehicle)))
    print(msg)
    return msg
end


function ExtendedVehicleMaintenance.consoleCommandClearService(...)
    local adminErr = evmAdminGuard("evmClearService")
    if adminErr ~= nil then return adminErr end
    local vehicle = evmFindConsoleFailureVehicle()
    if vehicle == nil then
        return "EVM: Kein Fahrzeug gefunden"
    end

    local root = vehicle.rootVehicle or vehicle
    local spec = evmGetVehicleSpec(root)
    if spec ~= nil then
        spec.isServiceActive = false
        spec.serviceRemainingGameMs = 0
        spec.serviceEndAbsHours = 0
        spec.serviceHoursToAdd = 0
        spec.serviceDaysToAdd = 0
        spec.serviceMode = 0
        spec.physicsFrozen = false
    end

    ExtendedVehicleMaintenance.evmClearPersist(root)
    ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(root)

    local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
    if rt ~= nil and (rt.rootVehicle == root or evmVehicleMatchesPersist(root, rt.pendingLockData)) then
        rt.active = false
        rt.rootVehicle = nil
        rt.targets = {}
        rt.pendingLockData = nil
        rt.pendingOldRootNode = nil
        rt._persistLockResolved = false
    end

    if g_server ~= nil then
        ExtendedVehicleMaintenance.broadcastServiceState(root, false)
    end

    return "EVM: Service fuer " .. tostring(evmGetVehicleName(root)) .. " geloescht"
end

function ExtendedVehicleMaintenance.consoleCommandClearAllService(...)
    local adminErr = evmAdminGuard("evmClearAllService")
    if adminErr ~= nil then return adminErr end
    local count = 0
    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = vehicle.rootVehicle or vehicle
        local spec = evmGetVehicleSpec(root)
        if spec ~= nil and spec.isServiceActive == true then
            count = count + 1
            spec.isServiceActive = false
            spec.serviceRemainingGameMs = 0
            spec.serviceEndAbsHours = 0
            spec.serviceHoursToAdd = 0
            spec.serviceDaysToAdd = 0
            spec.serviceMode = 0
            spec.physicsFrozen = false
            ExtendedVehicleMaintenance.restoreVehicleAfterServiceUnlock(root)
            if g_server ~= nil then
                ExtendedVehicleMaintenance.broadcastServiceState(root, false)
            end
        end
    end

    ExtendedVehicleMaintenance.evmClearPersist(nil)

    local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
    if rt ~= nil then
        rt.active = false
        rt.rootVehicle = nil
        rt.targets = {}
        rt.pendingLockData = nil
        rt.pendingOldRootNode = nil
        rt._persistLockResolved = false
    end

    return "EVM: Service geloescht fuer " .. tostring(count) .. " Fahrzeuge"
end

-- v19: Flotten-Reset. Heilt False-Damage durch v15-v18 Kollisions-Bugs in einem Rutsch.
-- Setzt fuer ALLE Fahrzeuge: Schaden auf 0, Wartungspool voll, Pannen geloescht.
-- Admin-only. Nicht im Spielzustand "Service aktiv" -- erst evmClearAllService nutzen.
function ExtendedVehicleMaintenance.consoleCommandFleetReset(...)
    local adminErr = evmAdminGuard("evmFleetReset")
    if adminErr ~= nil then return adminErr end
    if g_server == nil then return "EVM: Nur auf Server/Host ausfuehrbar." end

    local total = 0
    local repaired = 0
    local poolsReset = 0
    local failuresCleared = 0

    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = vehicle.rootVehicle or vehicle
        local spec = evmGetVehicleSpec(root)
        if spec ~= nil then
            total = total + 1

            -- Aktive Pannen aufheben
            if spec.failureType ~= nil and spec.failureType ~= "" then
                ExtendedVehicleMaintenance.clearFailure(root)
                if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
                    ExtendedVehicleMaintenance.broadcastFailureState(root)
                end
                failuresCleared = failuresCleared + 1
            end

            -- Schaden auf 0 setzen (heilt v15-v18 Phantom-Damage)
            if root.setDamageAmount ~= nil then
                local cur = 0
                local ok, dmg = pcall(root.getDamageAmount, root)
                if ok and dmg ~= nil then cur = tonumber(dmg) or 0 end
                if cur > 0 then
                    pcall(root.setDamageAmount, root, 0, true)
                    repaired = repaired + 1
                end
            end

            -- Wartungspool voll
            spec.hoursPool = ExtendedVehicleMaintenance.MAX_HOURS
            spec.daysPool = ExtendedVehicleMaintenance.MAX_DAYS
            spec.lastServiceOperatingTimeMs = evmGetOperatingTimeMs(root)
            spec.lastServiceGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
            poolsReset = poolsReset + 1

            if root.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                root:raiseDirtyFlags(spec.dirtyFlag)
            end
        end
    end

    return string.format("EVM Fleet-Reset: %d Fahrzeuge geprueft, %d Schaden geheilt, %d Pools voll, %d Pannen geloescht.",
        total, repaired, poolsReset, failuresCleared)
end

function ExtendedVehicleMaintenance.consoleCommandHudScale(...)
    local args = evmConsoleParseArgs(...)
    local hud = ExtendedVehicleMaintenance.clampHudConfig()
    local value = tonumber(args[1])
    if value == nil then
        print(string.format("[EVM] HUD scale=%.2f | Usage: evmHudScale 0.55-1.50", tonumber(hud.scale or 0.88)))
        return
    end
    hud.scale = math.max(0.55, math.min(1.50, value))
    ExtendedVehicleMaintenance.saveHudConfig()
end

function ExtendedVehicleMaintenance.consoleCommandHudPos(...)
    local args = evmConsoleParseArgs(...)
    local hud = ExtendedVehicleMaintenance.clampHudConfig()
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    if x == nil or y == nil then
        print(string.format("[EVM] HUD posX=%.3f posY=%.3f | Usage: evmHudPos 0.993 0.512", tonumber(hud.posX or 0.993), tonumber(hud.posY or 0.512)))
        return
    end
    hud.posX = math.max(0.05, math.min(0.995, x))
    hud.posY = math.max(0.05, math.min(0.950, y))
    ExtendedVehicleMaintenance.saveHudConfig()
end

function ExtendedVehicleMaintenance.consoleCommandHudEdit(...)
    local args = evmConsoleParseArgs(...)
    local v = args[1]
    if v == nil or v == "" then
        ExtendedVehicleMaintenance.setHudEditMode(ExtendedVehicleMaintenance.hudEditMode ~= true)
    else
        v = tostring(v):lower()
        ExtendedVehicleMaintenance.setHudEditMode(v == "1" or v == "true" or v == "on" or v == "an" or v == "follow")
    end
end

function ExtendedVehicleMaintenance.consoleCommandHudNudge(...)
    local args = evmConsoleParseArgs(...)
    local hud = ExtendedVehicleMaintenance.clampHudConfig()
    local a = args[1] ~= nil and tostring(args[1]):lower() or ""
    local step = tonumber(args[2]) or 0.005

    local dx, dy = tonumber(args[1]), tonumber(args[2])
    if dx ~= nil and dy ~= nil then
        -- direkte Variante: evmHudNudge 0.01 -0.02
    elseif a == "left" or a == "links" or a == "l" then
        dx, dy = -step, 0
    elseif a == "right" or a == "rechts" or a == "r" then
        dx, dy = step, 0
    elseif a == "up" or a == "hoch" or a == "oben" or a == "u" then
        dx, dy = 0, step
    elseif a == "down" or a == "runter" or a == "unten" or a == "d" then
        dx, dy = 0, -step
    else
        print("[EVM] Usage: evmHudNudge left/right/up/down [0.005]  oder  evmHudNudge dx dy")
        return
    end

    hud.posX = math.max(0.05, math.min(0.995, (tonumber(hud.posX) or 0.993) + dx))
    hud.posY = math.max(0.05, math.min(0.950, (tonumber(hud.posY) or 0.512) + dy))
    ExtendedVehicleMaintenance.saveHudConfig()
    print(string.format("[EVM] HUD verschoben: posX=%.3f posY=%.3f", hud.posX, hud.posY))
end

function ExtendedVehicleMaintenance.consoleCommandHudReset(...)
    local hud = ExtendedVehicleMaintenance.hudConfig or {}
    hud.posX = 0.993
    hud.posY = 0.512
    hud.scale = 0.88
    ExtendedVehicleMaintenance.hudConfig = hud
    ExtendedVehicleMaintenance.saveHudConfig()
end

local function evmRegisterConsoleCommands()
    if addConsoleCommand == nil then return end
    removeConsoleCommand("evmFailure")
    removeConsoleCommand("evmClearFailure")
    removeConsoleCommand("evmSetDue")
    removeConsoleCommand("evmResetPool")
    removeConsoleCommand("evmStatus")
    removeConsoleCommand("evmDebug")
    removeConsoleCommand("evmDiag")
    removeConsoleCommand("evmClearService")
    removeConsoleCommand("evmClearAllService")
    removeConsoleCommand("evmCollisionTest")
    removeConsoleCommand("evmFleetReset")
    removeConsoleCommand("evmRepairDiag")
    removeConsoleCommand("evmHudScale")
    removeConsoleCommand("evmHudPos")
    removeConsoleCommand("evmHudEdit")
    removeConsoleCommand("evmHudNudge")
    removeConsoleCommand("evmHudReset")
    addConsoleCommand("evmFailure",      "EVM: Defekt erzwingen. Usage: evmFailure engine|flatTire|rpm|hydraulic|brake|battery", "consoleCommandFailure",      ExtendedVehicleMaintenance)
    addConsoleCommand("evmClearFailure", "EVM: Aktiven Defekt aufheben.",                                             "consoleCommandClearFailure", ExtendedVehicleMaintenance)
    addConsoleCommand("evmSetDue",       "EVM: Wartung sofort faellig setzen.",                                       "consoleCommandSetDue",       ExtendedVehicleMaintenance)
    addConsoleCommand("evmResetPool",    "EVM: Wartungspool auf Maximum zuruecksetzen.",                              "consoleCommandResetPool",    ExtendedVehicleMaintenance)
    addConsoleCommand("evmStatus",       "EVM: Wartungsstatus des aktuellen Fahrzeugs anzeigen.",                     "consoleCommandStatus",       ExtendedVehicleMaintenance)
    addConsoleCommand("evmDebug",        "EVM: Debug-Modus umschalten. Usage: evmDebug [0|1]",                       "consoleCommandDebug",        ExtendedVehicleMaintenance)
    addConsoleCommand("evmDiag",         "EVM: Diagnose - zeigt ob Spezialisierung geladen ist.",                    "consoleCommandDiag",         ExtendedVehicleMaintenance)
    addConsoleCommand("evmClearService", "EVM: Wartungslock des aktuellen/nahen Fahrzeugs loeschen.",                 "consoleCommandClearService", ExtendedVehicleMaintenance)
    addConsoleCommand("evmClearAllService", "EVM: Alle Wartungslocks loeschen.",                                     "consoleCommandClearAllService", ExtendedVehicleMaintenance)
    addConsoleCommand("evmCollisionTest", "EVM: Testet Kollisionsschaden am aktuellen Fahrzeug. Usage: evmCollisionTest [damagePercent]", "consoleCommandCollisionTest", ExtendedVehicleMaintenance)
    addConsoleCommand("evmFleetReset",   "EVM: Setzt ALLE Fahrzeuge zurueck (Schaden=0, Pool voll, Pannen weg). Heilt False-Damage durch alte Versionen.", "consoleCommandFleetReset", ExtendedVehicleMaintenance)
    addConsoleCommand("evmHudScale",    "EVM: HUD-Groesse setzen. Usage: evmHudScale 0.55-1.50", "consoleCommandHudScale", ExtendedVehicleMaintenance)
    addConsoleCommand("evmHudPos",      "EVM: HUD-Position setzen. Usage: evmHudPos posX posY", "consoleCommandHudPos", ExtendedVehicleMaintenance)
    addConsoleCommand("evmHudEdit",     "EVM: HUD mit Maus verschieben. Usage: evmHudEdit [0|1]", "consoleCommandHudEdit", ExtendedVehicleMaintenance)
    addConsoleCommand("evmHudNudge",    "EVM: HUD schrittweise verschieben. Usage: evmHudNudge left/right/up/down [step]", "consoleCommandHudNudge", ExtendedVehicleMaintenance)
    addConsoleCommand("evmHudReset",    "EVM: HUD-Position und Groesse zuruecksetzen.", "consoleCommandHudReset", ExtendedVehicleMaintenance)
    addConsoleCommand("evmRepairDiag",   "EVM: Diagnose welche Repair-Funktionen das aktuelle Fahrzeug hat und was sie liefern.", "consoleCommandRepairDiag", ExtendedVehicleMaintenance)
end

local function evmRemoveConsoleCommands()
    if removeConsoleCommand == nil then return end
    removeConsoleCommand("evmFailure")
    removeConsoleCommand("evmClearFailure")
    removeConsoleCommand("evmSetDue")
    removeConsoleCommand("evmResetPool")
    removeConsoleCommand("evmStatus")
    removeConsoleCommand("evmDebug")
    removeConsoleCommand("evmDiag")
    removeConsoleCommand("evmClearService")
    removeConsoleCommand("evmClearAllService")
    removeConsoleCommand("evmCollisionTest")
    removeConsoleCommand("evmFleetReset")
    removeConsoleCommand("evmRepairDiag")
    removeConsoleCommand("evmHudScale")
    removeConsoleCommand("evmHudPos")
    removeConsoleCommand("evmHudEdit")
    removeConsoleCommand("evmHudNudge")
    removeConsoleCommand("evmHudReset")
end

evmRegisterConsoleCommands()


function ExtendedVehicleMaintenance:onLoad(savegame)
    ExtendedVehicleMaintenance.registerGlobalSavegameXMLPaths()

    local spec = evmGetVehicleSpec(self)
    spec.dirtyFlag = self:getNextDirtyFlag()
    spec.hoursPool = ExtendedVehicleMaintenance.SERVICE_INTERVAL_HOURS or ExtendedVehicleMaintenance.DEFAULT_HOURS
    spec.daysPool = ExtendedVehicleMaintenance.MAX_DAYS or ExtendedVehicleMaintenance.DEFAULT_DAYS
    spec.lastServiceOperatingTimeMs = 0
    spec.lastServiceGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.serviceRemainingGameMs = 0
    spec.serviceEndAbsHours = 0
    spec.serviceHoursToAdd = 0
    spec.serviceDaysToAdd = 0
    spec.serviceMode = 0
    spec.isServiceActive = false
    spec.lastTickGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.stallTimer = ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL
    spec.actionEvents = {}
    spec.physicsFrozen = false
    spec.debugTimer = 0
    spec.failureType = ""
    spec.failureSeverity = 0
    spec.failureWheelIndex = 0
    spec.failureDriftDirection = 0
    spec.engineFailureTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.breakdownTimer = ExtendedVehicleMaintenance.BREAKDOWN_CHECK_INTERVAL
    spec.enterHintUntil = 0
    spec.wasEntered = false
    spec.failureWarnUntil = 0
    -- MP-Fix: NICHT zurücksetzen wenn die Spec bereits einen Wert vom Server-Sync hat.
    -- onLoad kann durch injectRuntimeSpecsForLoadedVehicles mehrfach aufgerufen werden,
    -- und in dem Fall darf der per EVMBatteryStateEvent empfangene State nicht überschrieben werden.
    if spec._batteryClientSynced ~= true then
        spec.batteryCharge = 1.0
        spec.batteryVoltage = 12.7
    end
    spec.batteryVoltageTimer = 0

    if savegame ~= nil and savegame.xmlFile ~= nil then
        local key = savegame.key .. ".extendedVehicleMaintenance"
        spec.hoursPool = savegame.xmlFile:getValue(key .. "#hoursPool", spec.hoursPool) or spec.hoursPool
        spec.daysPool = savegame.xmlFile:getValue(key .. "#daysPool", spec.daysPool) or spec.daysPool
        spec.lastServiceOperatingTimeMs = savegame.xmlFile:getValue(key .. "#lastServiceOperatingTimeMs", spec.lastServiceOperatingTimeMs) or spec.lastServiceOperatingTimeMs
        spec.lastServiceGameTimeMs = savegame.xmlFile:getValue(key .. "#lastServiceGameTimeMs", spec.lastServiceGameTimeMs) or spec.lastServiceGameTimeMs
        spec.serviceRemainingGameMs = savegame.xmlFile:getValue(key .. "#serviceRemainingGameMs", spec.serviceRemainingGameMs) or spec.serviceRemainingGameMs
        spec.serviceEndAbsHours = savegame.xmlFile:getValue(key .. "#serviceEndAbsHours", spec.serviceEndAbsHours) or spec.serviceEndAbsHours
        spec.serviceHoursToAdd = savegame.xmlFile:getValue(key .. "#serviceHoursToAdd", spec.serviceHoursToAdd) or spec.serviceHoursToAdd
        spec.serviceDaysToAdd = savegame.xmlFile:getValue(key .. "#serviceDaysToAdd", spec.serviceDaysToAdd) or spec.serviceDaysToAdd
        spec.serviceMode = savegame.xmlFile:getValue(key .. "#serviceMode", spec.serviceMode) or spec.serviceMode
        local isServiceActive = savegame.xmlFile:getValue(key .. "#isServiceActive", spec.isServiceActive)
        if isServiceActive ~= nil then
            spec.isServiceActive = isServiceActive
        end
        spec.failureType = savegame.xmlFile:getValue(key .. "#failureType", spec.failureType) or spec.failureType
        spec.failureSeverity = savegame.xmlFile:getValue(key .. "#failureSeverity", spec.failureSeverity) or spec.failureSeverity
        spec.failureWheelIndex = savegame.xmlFile:getValue(key .. "#failureWheelIndex", spec.failureWheelIndex) or spec.failureWheelIndex
        spec.failureDriftDirection = savegame.xmlFile:getValue(key .. "#failureDriftDirection", spec.failureDriftDirection) or spec.failureDriftDirection
        spec.batteryCharge = savegame.xmlFile:getValue(key .. "#batteryCharge", spec.batteryCharge) or spec.batteryCharge
        -- MP-Fix HUD: batteryVoltage aus dem Savegame kann veraltet sein (z.B. 11.6V obwohl Batterie voll).
        -- Wir laden den gespeicherten Wert nur als Fallback; der korrekte Wert wird nach dem ersten
        -- Batterie-Tick via getBatteryVoltage() berechnet und per EVMBatteryStateEvent an Clients gesendet.
        local savedVoltage = savegame.xmlFile:getValue(key .. "#batteryVoltage", nil)
        if savedVoltage ~= nil then
            -- Nur übernehmen wenn plausibel zur gespeicherten Ladung (Differenz > 0.5V = veraltet)
            local chargeDerivedV = 11.4 + evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1) * 1.3
            local sv = tonumber(savedVoltage) or chargeDerivedV
            if math.abs(sv - chargeDerivedV) > 0.5 then
                spec.batteryVoltage = chargeDerivedV  -- veralteter Wert, neu ableiten
            else
                spec.batteryVoltage = sv
            end
        else
            spec.batteryVoltage = 11.4 + evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1) * 1.3
        end

        evmMigrateMaintenanceIntervalToOperatingHours(spec, self, "savegame")
    else
        -- Kein alter EVM-Save vorhanden: direkt am nativen LS-Betriebsstunden-Takt ausrichten.
        spec.lastServiceOperatingTimeMs = evmGetOperatingCycleStartMs(evmGetOperatingTimeMs(self))
    end

    local resetPersist = ExtendedVehicleMaintenance.evmReadPersist(self)
    if resetPersist ~= nil then
        spec.serviceRemainingGameMs = resetPersist.serviceRemainingGameMs or spec.serviceRemainingGameMs
        spec.serviceEndAbsHours = resetPersist.serviceEndAbsHours or (ExtendedVehicleMaintenance.getCurrentAbsHours() + ((spec.serviceRemainingGameMs or 0) / 3600000))
        spec.serviceHoursToAdd = resetPersist.serviceHoursToAdd or spec.serviceHoursToAdd
        spec.serviceDaysToAdd = resetPersist.serviceDaysToAdd or spec.serviceDaysToAdd
        spec.serviceMode = resetPersist.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
        spec.isServiceActive = (spec.serviceRemainingGameMs or 0) > 0

        evmDbg("onLoad restored reset persist vehicle=%s serviceActive=%s remainingMs=%s",
            tostring(evmGetVehicleName(self)),
            tostring(spec.isServiceActive),
            tostring(spec.serviceRemainingGameMs))

        local runtime = ExtendedVehicleMaintenance.getRuntime()
        runtime.active = true
        runtime.mode = spec.serviceMode
        runtime.rootVehicle = self.rootVehicle or self
        runtime.pendingLockData = evmBuildPersistRuntimeData(self, spec.serviceMode, spec.serviceRemainingGameMs, spec.serviceHoursToAdd, spec.serviceDaysToAdd)
        if runtime.pendingLockData ~= nil then
            runtime.pendingLockData.serviceEndAbsHours = spec.serviceEndAbsHours or runtime.pendingLockData.serviceEndAbsHours or 0
        end
        runtime.pendingOldRootNode = runtime.pendingOldRootNode or self.rootNode

        -- MP-Fix: Persist erst loeschen NACHDEM wir den State gesichert haben.
        -- Die Watcher aus tryStartService suchen das neue Objekt per
        -- findVehicleByPersistData - wenn die Datei schon weg ist greifen sie
        -- nicht mehr. Wir loeschen erst spaeter (nach enforceLockedVehicle).
        -- evmClearPersist wird weiter unten aufgerufen.
    end

    spec.hoursPool = evmClamp(spec.hoursPool or ExtendedVehicleMaintenance.DEFAULT_HOURS, 0, ExtendedVehicleMaintenance.MAX_HOURS)
    spec.daysPool = evmClamp(spec.daysPool or ExtendedVehicleMaintenance.DEFAULT_DAYS, 0, ExtendedVehicleMaintenance.MAX_DAYS)
    spec.lastServiceOperatingTimeMs = spec.lastServiceOperatingTimeMs or evmGetOperatingTimeMs(self)
    spec.lastServiceGameTimeMs = spec.lastServiceGameTimeMs or ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    if spec.isServiceActive and (spec.serviceEndAbsHours or 0) > 0 then
        spec.serviceRemainingGameMs = math.max(0, (spec.serviceEndAbsHours - ExtendedVehicleMaintenance.getCurrentAbsHours()) * 3600000)
    else
        spec.serviceRemainingGameMs = math.max(0, spec.serviceRemainingGameMs or 0)
        if spec.isServiceActive and spec.serviceRemainingGameMs > 0 then
            spec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (spec.serviceRemainingGameMs / 3600000)
        end
    end
    spec.serviceHoursToAdd = math.max(0, spec.serviceHoursToAdd or 0)
    spec.serviceDaysToAdd = math.max(0, spec.serviceDaysToAdd or 0)
    spec.isServiceActive = spec.isServiceActive == true
    spec.lastTickGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    spec.batteryCharge = evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1)
    spec.batteryVoltage = evmClamp(tonumber(spec.batteryVoltage) or 12.7, 6.0, 15.5)

    evmDbg("onLoad vehicle=%s serviceActive=%s remainingMs=%s hoursPool=%.2f daysPool=%.2f",
        tostring(evmGetVehicleName(self)),
        tostring(spec.isServiceActive),
        tostring(spec.serviceRemainingGameMs),
        tonumber(spec.hoursPool or 0),
        tonumber(spec.daysPool or 0))

    if spec.isServiceActive then
        ExtendedVehicleMaintenance.enforceLockedVehicle(self)
        -- Runtime auch ohne resetPersist wiederherstellen (normaler Savegame-Reload)
        local runtime = ExtendedVehicleMaintenance.getRuntime()
        if not (runtime.active == true) then
            runtime.active = true
            runtime.mode = spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
            runtime.rootVehicle = self.rootVehicle or self
            if runtime.pendingLockData == nil then
                runtime.pendingLockData = evmBuildPersistRuntimeData(
                    self,
                    spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP,
                    spec.serviceRemainingGameMs or 0,
                    spec.serviceHoursToAdd or 0,
                    spec.serviceDaysToAdd or 0
                )
                if runtime.pendingLockData ~= nil then
                    runtime.pendingLockData.serviceEndAbsHours = spec.serviceEndAbsHours or 0
                end
                runtime.pendingOldRootNode = runtime.pendingOldRootNode or self.rootNode
            end
        end
        if self.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
            self:raiseDirtyFlags(spec.dirtyFlag)
        end

        -- MP-Fix: Nach Workshop-Reset laedt das neue Fahrzeug-Objekt hier
        -- neu und liest die Persist-Datei. Jetzt sofort an alle Clients
        -- broadcasten damit sie den Lock bekommen. Danach erst Persist-Datei
        -- loeschen - die Watcher aus tryStartService brauchen sie noch um
        -- das neue Objekt per findVehicleByPersistData zu finden.
        if g_server ~= nil then
            ExtendedVehicleMaintenance.broadcastServiceState(self, true)
            -- Verzoegert loeschen damit Watcher noch matchen koennen
            local selfRef = self
            local rt = ExtendedVehicleMaintenance.getRuntime()
            table.insert(rt._serviceWatchers, {
                triggerTime = (g_time or 0) + 6000,
                callback = function()
                    ExtendedVehicleMaintenance.evmClearPersist(selfRef)
                end
            })
        end
    else
        ExtendedVehicleMaintenance.removeHardVehicleLock(self)
        -- Kein Service aktiv: Persist-Datei sofort loeschen falls vorhanden
        ExtendedVehicleMaintenance.evmClearPersist(self)
    end
end

function ExtendedVehicleMaintenance:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = evmGetVehicleSpec(self)
    if spec == nil then
        return
    end

    xmlFile:setValue(key .. ".extendedVehicleMaintenance#hoursPool", spec.hoursPool)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#daysPool", spec.daysPool)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#lastServiceOperatingTimeMs", spec.lastServiceOperatingTimeMs)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#lastServiceGameTimeMs", spec.lastServiceGameTimeMs)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#serviceRemainingGameMs", evmGetServiceRemainingMs(spec, self))
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#serviceEndAbsHours", spec.serviceEndAbsHours or 0)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#serviceHoursToAdd", spec.serviceHoursToAdd)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#serviceDaysToAdd", spec.serviceDaysToAdd)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#serviceMode", spec.serviceMode)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#isServiceActive", spec.isServiceActive)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#failureType", spec.failureType or "")
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#failureSeverity", spec.failureSeverity or 0)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#failureWheelIndex", spec.failureWheelIndex or 0)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#failureDriftDirection", spec.failureDriftDirection or 0)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#batteryCharge", spec.batteryCharge or 1.0)
    xmlFile:setValue(key .. ".extendedVehicleMaintenance#batteryVoltage", spec.batteryVoltage or 12.7)
end

function ExtendedVehicleMaintenance:onDelete()
    ExtendedVehicleMaintenance.removeEnterLock(self)
    ExtendedVehicleMaintenance.removeHardVehicleLock(self)
end

function ExtendedVehicleMaintenance:onReadStream(streamId, connection)
    local spec = evmGetVehicleSpec(self)
    if spec == nil then
        -- MP-Fix: Wenn die Spec auf dem Joiner-Client noch nicht initialisiert
        -- wurde (Race-Condition zwischen Vehicle-Load und Stream-Read), erzeugen
        -- wir sie hier bei Bedarf. Sonst wuerde der gesamte Service-State
        -- verloren gehen und der Client wuerde das Fahrzeug nicht sperren.
        if evmCreateRuntimeSpec ~= nil then
            spec = evmCreateRuntimeSpec(self)
        end
        if spec == nil then
            self[ExtendedVehicleMaintenance.SPEC_TABLE_NAME] = self[ExtendedVehicleMaintenance.SPEC_TABLE_NAME] or {}
            spec = self[ExtendedVehicleMaintenance.SPEC_TABLE_NAME]
        end
    end
    spec.hoursPool = streamReadFloat32(streamId)
    spec.daysPool = streamReadFloat32(streamId)
    spec.lastServiceOperatingTimeMs = streamReadFloat32(streamId)
    spec.lastServiceGameTimeMs = streamReadFloat32(streamId)
    spec.serviceRemainingGameMs = streamReadFloat32(streamId)
    spec.serviceEndAbsHours = streamReadFloat32(streamId)
    spec.serviceHoursToAdd = streamReadFloat32(streamId)
    spec.serviceDaysToAdd = streamReadFloat32(streamId)
    spec.serviceMode = streamReadInt8(streamId)
    spec.isServiceActive = streamReadBool(streamId)
    spec.failureType = streamReadString(streamId) or ""
    spec.failureSeverity = streamReadFloat32(streamId) or 0
    spec.failureWheelIndex = streamReadInt8(streamId) or 0
    spec.failureDriftDirection = streamReadInt8(streamId) or 0
    spec.batteryCharge = streamReadFloat32(streamId) or 1.0
    spec.batteryVoltage = streamReadFloat32(streamId) or 12.7
    if spec.failureType ~= nil and spec.failureType ~= "" then
        ExtendedVehicleMaintenance.applyFailureEffects(self, spec, 0, false)
    else
        ExtendedVehicleMaintenance.restoreBatteryFailure(self)
    end

    if spec.isServiceActive then
        local runtime = ExtendedVehicleMaintenance.getRuntime()
        runtime.active = true
        runtime.mode = spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
        runtime.rootVehicle = self.rootVehicle or self
        runtime.targets = { runtime.rootVehicle }
        runtime.pendingLockData = nil
        runtime._persistLockResolved = true
        ExtendedVehicleMaintenance.forceVehicleStandstill(self)
        if evmIsPlayerInThisVehicle ~= nil and evmIsPlayerInThisVehicle(self) then
            ExtendedVehicleMaintenance.forceLeaveVehicle(self)
        end
        ExtendedVehicleMaintenance.installEnterLock(self, spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
        ExtendedVehicleMaintenance.installHardVehicleLock(self)
        -- Multiplayer-Client beim Join: Input-Locks installieren
        ExtendedVehicleMaintenance.installGlobalInputLocks()
        if self.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
            pcall(self.raiseDirtyFlags, self, spec.dirtyFlag)
        end
    else
        ExtendedVehicleMaintenance.removeHardVehicleLock(self)
    end
end

function ExtendedVehicleMaintenance:onWriteStream(streamId, connection)
    local spec = evmGetVehicleSpec(self)
    streamWriteFloat32(streamId, spec.hoursPool)
    streamWriteFloat32(streamId, spec.daysPool)
    streamWriteFloat32(streamId, spec.lastServiceOperatingTimeMs)
    streamWriteFloat32(streamId, spec.lastServiceGameTimeMs)
    streamWriteFloat32(streamId, evmGetServiceRemainingMs(spec, self))
    streamWriteFloat32(streamId, spec.serviceEndAbsHours or 0)
    streamWriteFloat32(streamId, spec.serviceHoursToAdd)
    streamWriteFloat32(streamId, spec.serviceDaysToAdd)
    streamWriteInt8(streamId, spec.serviceMode or 0)
    streamWriteBool(streamId, spec.isServiceActive == true)
    streamWriteString(streamId, spec.failureType or "")
    streamWriteFloat32(streamId, spec.failureSeverity or 0)
    streamWriteInt8(streamId, spec.failureWheelIndex or 0)
    streamWriteInt8(streamId, spec.failureDriftDirection or 0)
    streamWriteFloat32(streamId, spec.batteryCharge or 1.0)
    streamWriteFloat32(streamId, spec.batteryVoltage or 12.7)
end

function ExtendedVehicleMaintenance:onReadUpdateStream(streamId, timestamp, connection)
    local spec = evmGetVehicleSpec(self)
    if connection:getIsServer() and streamReadBool(streamId) then
        spec.hoursPool = streamReadFloat32(streamId)
        spec.daysPool = streamReadFloat32(streamId)
        spec.lastServiceOperatingTimeMs = streamReadFloat32(streamId)
        spec.lastServiceGameTimeMs = streamReadFloat32(streamId)
        spec.serviceRemainingGameMs = streamReadFloat32(streamId)
        spec.serviceEndAbsHours = streamReadFloat32(streamId)
        spec.serviceHoursToAdd = streamReadFloat32(streamId)
        spec.serviceDaysToAdd = streamReadFloat32(streamId)
        spec.serviceMode = streamReadInt8(streamId)
        spec.isServiceActive = streamReadBool(streamId)
        spec.failureType = streamReadString(streamId) or ""
        spec.failureSeverity = streamReadFloat32(streamId) or 0
        spec.failureWheelIndex = streamReadInt8(streamId) or 0
        spec.failureDriftDirection = streamReadInt8(streamId) or 0
        spec.batteryCharge = streamReadFloat32(streamId) or spec.batteryCharge or 1.0
        spec.batteryVoltage = streamReadFloat32(streamId) or spec.batteryVoltage or 12.7
        if spec.failureType ~= nil and spec.failureType ~= "" then
            ExtendedVehicleMaintenance.applyFailureEffects(self, spec, 0, false)
        else
            ExtendedVehicleMaintenance.restoreTires(self)
            ExtendedVehicleMaintenance.restoreEngineFailure(self)
            ExtendedVehicleMaintenance.restoreRpmLimiter(self)
            ExtendedVehicleMaintenance.restoreHydraulicLeak(self)
            ExtendedVehicleMaintenance.restoreBrakeFault(self)
            ExtendedVehicleMaintenance.restoreBatteryFailure(self)
        end

        if spec.isServiceActive then
            local runtime = ExtendedVehicleMaintenance.getRuntime()
            runtime.active = true
            runtime.mode = spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
            runtime.rootVehicle = self.rootVehicle or self
            runtime.targets = { runtime.rootVehicle }
            runtime._persistLockResolved = true
            if (self.rootVehicle or self)._evmHardLockActive ~= true then
                ExtendedVehicleMaintenance.installEnterLock(self, spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
                ExtendedVehicleMaintenance.installHardVehicleLock(self)
            end
            -- Multiplayer-Client: Runtime-Locks auch auf Client installieren
            ExtendedVehicleMaintenance.installGlobalInputLocks()
            if self.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                pcall(self.raiseDirtyFlags, self, spec.dirtyFlag)
            end
        else
            ExtendedVehicleMaintenance.removeHardVehicleLock(self)
        end
    end
end

function ExtendedVehicleMaintenance:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = evmGetVehicleSpec(self)
    if not connection:getIsServer() then
        local needsUpdate = bit32.band(dirtyMask, spec.dirtyFlag) ~= 0
        streamWriteBool(streamId, needsUpdate)
        if needsUpdate then
            streamWriteFloat32(streamId, spec.hoursPool)
            streamWriteFloat32(streamId, spec.daysPool)
            streamWriteFloat32(streamId, spec.lastServiceOperatingTimeMs)
            streamWriteFloat32(streamId, spec.lastServiceGameTimeMs)
            streamWriteFloat32(streamId, evmGetServiceRemainingMs(spec, self))
            streamWriteFloat32(streamId, spec.serviceEndAbsHours or 0)
            streamWriteFloat32(streamId, spec.serviceHoursToAdd)
            streamWriteFloat32(streamId, spec.serviceDaysToAdd)
            streamWriteInt8(streamId, spec.serviceMode or 0)
            streamWriteBool(streamId, spec.isServiceActive == true)
            streamWriteString(streamId, spec.failureType or "")
            streamWriteFloat32(streamId, spec.failureSeverity or 0)
            streamWriteInt8(streamId, spec.failureWheelIndex or 0)
            streamWriteInt8(streamId, spec.failureDriftDirection or 0)
            streamWriteFloat32(streamId, spec.batteryCharge or 1.0)
            streamWriteFloat32(streamId, spec.batteryVoltage or 12.7)
        end
    end
end


local function evmGetBrakeInputState(vehicle)
    if vehicle == nil or vehicle.spec_drivable == nil then
        return false, 0, 0, false
    end

    local sd = vehicle.spec_drivable
    local brake = math.abs(tonumber(sd.brakeInput) or 0)
    local axisForward = tonumber(sd.axisForward) or 0
    local handbrake = sd.doHandbrake == true or sd.handbrake == true or sd.isHandbrakeActive == true

    if sd.lastInputValues ~= nil then
        if sd.lastInputValues.brakeInput ~= nil then
            brake = math.max(brake, math.abs(tonumber(sd.lastInputValues.brakeInput) or 0))
        end
        if sd.lastInputValues.axisForward ~= nil then
            axisForward = tonumber(sd.lastInputValues.axisForward) or axisForward
        end
        if sd.lastInputValues.doHandbrake ~= nil then
            handbrake = handbrake or sd.lastInputValues.doHandbrake == true
        end
    end

    local braking = brake > 0.15 or axisForward < -0.25 or handbrake == true
    return braking, brake, axisForward, handbrake
end

-- ---------------------------------------------------------------------------
-- Kollisionsschaden - SP/MP-sicherer Runtime-Prozessor
-- Läuft nicht nur über die Fahrzeug-Spezialisierung, sondern zusätzlich über
-- den globalen ModEventListener:update(). Dadurch sieht man im SP sofort Logs,
-- selbst wenn onUpdateTick bei einem Fahrzeugtyp nicht korrekt feuert.
-- ---------------------------------------------------------------------------
function ExtendedVehicleMaintenance.processCollisionDamage(vehicle, dt, source)
    if vehicle == nil then return end

    local root = vehicle.rootVehicle or vehicle
    if root == nil or root.rootNode == nil or root.rootNode == 0 then return end
    if root.spec_motorized == nil then return end

    local spec = evmGetVehicleSpec(root)
    local mission = g_currentMission
    local localVehicle = evmGetCurrentLocalVehicle()
    local isControlled = evmNormalizeVehicle(localVehicle) == root
    if not isControlled and mission ~= nil then
        isControlled = evmNormalizeVehicle(mission.controlledVehicle or mission.currentVehicle) == root
    end

    -- v20: HARD GATE. Nur das lokal kontrollierte Fahrzeug wird ueberhaupt analysiert.
    -- Frueher wurde processCollisionDamage in onUpdateTick fuer JEDES Fahrzeug aufgerufen,
    -- inklusive der Fahrzeuge anderer Spieler auf unserem Client. Deren Velocity-Werte
    -- kommen aber per Net-Sync interpoliert rein, mit haeufigen Mini-Spikes -> False-Damage.
    -- Detection ist von Natur aus eine "Ich-erlebe-meinen-Crash"-Sache.
    if not isControlled then
        -- Ohne Logging zurueck. Wenn doDebug und ueberraschend hohe Speeds, kommt der
        -- globalUpdate-Pfad fuer's lokale Fahrzeug eh durch.
        return
    end

    local doDebug = ExtendedVehicleMaintenance.COLLISION_DEBUG == true or ExtendedVehicleMaintenance.debug == true

    if spec == nil then
        if doDebug and isControlled then
            ExtendedVehicleMaintenance._collisionNoSpecTimer = (ExtendedVehicleMaintenance._collisionNoSpecTimer or 0) - (dt or 0)
            if ExtendedVehicleMaintenance._collisionNoSpecTimer <= 0 then
                ExtendedVehicleMaintenance._collisionNoSpecTimer = 1000
                print(string.format("[EVM] CollisionDebug source=%s controlled=%s aber spec_extendedVehicleMaintenance fehlt -> RuntimeSpec wird nachgeladen/Typ-Patch pruefen", tostring(source), tostring(evmGetVehicleName(root))))
            end
        end
        return
    end

    if spec.isServiceActive then return end

    local now = mission ~= nil and (mission.time or g_time or 0) or (g_time or 0)
    if spec.evmCollisionLastProcessKey == now then return end
    spec.evmCollisionLastProcessKey = now

    -- v19: Init-Grace nach Spawn / erstem Tick. Vor Ablauf der 2.5s wird kein
    -- Crash erkannt - schuetzt vor Position-Spikes durch MP-Sync, Resume aus
    -- Pause, Fahrzeugwechsel, Trailer-Anhaengen etc.
    if spec.evmCollisionInitDeadline == nil then
        spec.evmCollisionInitDeadline = now + (ExtendedVehicleMaintenance.COLLISION_INIT_GRACE_MS or 2500)
    end
    if now < spec.evmCollisionInitDeadline then
        -- Position-Werte trotzdem mitschreiben damit nach Ende der Grace eine Baseline da ist
        local x, y, z = getWorldTranslation(root.rootNode)
        if x ~= nil then
            spec.evmCollisionLastX, spec.evmCollisionLastY, spec.evmCollisionLastZ = x, y, z
        end
        spec.evmImpactLastTime = now
        spec.evmImpactLastSpeed = 0
        spec.evmImpactPeakSpeed = 0
        spec.evmImpactPeakTime = now
        return
    end

    local dtMs = tonumber(dt or 0) or 0
    local dtSec = math.max(dtMs / 1000, 0.001)

    -- v19: Wenn der Frame-dt zu gross ist (Frame-Hang, Lade-Spike, Pause-Resume),
    -- ignorieren wir den kompletten Tick und resetten die Speed-Baseline.
    if dtMs > (ExtendedVehicleMaintenance.COLLISION_MAX_FRAME_DT_MS or 250) then
        local x, y, z = getWorldTranslation(root.rootNode)
        if x ~= nil then
            spec.evmCollisionLastX, spec.evmCollisionLastY, spec.evmCollisionLastZ = x, y, z
        end
        spec.evmImpactLastTime = now
        spec.evmImpactLastSpeed = 0
        spec.evmImpactPeakSpeed = 0
        spec.evmImpactPeakTime = now
        if doDebug and isControlled then
            print(string.format("[EVM] CollisionDebug source=%s vehicle=%s ignored frameHang dt=%.0fms", tostring(source), tostring(evmGetVehicleName(root)), dtMs))
        end
        return
    end

    local lastSpeedKmh = 0
    local lastSpeedOk = false
    if root.getLastSpeed ~= nil then
        local ok, s = pcall(root.getLastSpeed, root)
        if ok and s ~= nil then
            lastSpeedKmh = math.abs(tonumber(s) or 0)
            lastSpeedOk = true
        end
    end

    -- v19: physSpeed nur aus horizontalen Komponenten (X,Z). Y rauslassen, sonst
    -- werden Spruenge / Bodenkontakte nach Hoppern als "Crash" erkannt.
    local physSpeedKmh = -1
    local physOk = false
    if getPhysicsVelocity ~= nil then
        local okVel, vx, vy, vz = pcall(getPhysicsVelocity, root.rootNode)
        if okVel and vx ~= nil then
            vx, vz = tonumber(vx) or 0, tonumber(vz) or 0
            physSpeedKmh = math.sqrt(vx * vx + vz * vz) * 3.6
            physOk = true
        end
    end

    -- v20: Position-Speed nicht mehr fuer Detection genutzt - posSpeed ist im MP/Net-Sync
    -- die haeufigste Quelle fuer Phantom-Drops (Position-Reset = Pseudo-Sprung). Wir lesen
    -- die Position nur noch um Teleports zu erkennen und danach den Speed-Buffer zu resetten.
    local x, y, z = getWorldTranslation(root.rootNode)
    if x ~= nil then
        local lastX, lastZ = spec.evmCollisionLastX, spec.evmCollisionLastZ
        if lastX ~= nil and lastZ ~= nil then
            local dx = x - lastX
            local dz = z - lastZ
            local distHoriz = math.sqrt(dx * dx + dz * dz)
            local posSpeedHoriz = (distHoriz / dtSec) * 3.6
            -- Teleport-Detection (z.B. MP-Resync, Trailer-Anhaengen): Detection-Buffer resetten.
            if posSpeedHoriz > (ExtendedVehicleMaintenance.COLLISION_TELEPORT_SPEED_KMH or 120) then
                if doDebug and isControlled then
                    print(string.format("[EVM] CollisionDebug source=%s vehicle=%s ignored teleport posSpeedHoriz=%.0f km/h", tostring(source), tostring(evmGetVehicleName(root)), posSpeedHoriz))
                end
                spec.evmCollisionLastX, spec.evmCollisionLastY, spec.evmCollisionLastZ = x, y, z
                spec.evmImpactLastTime = now
                spec.evmImpactLastSpeed = lastSpeedKmh
                spec.evmImpactPeakSpeed = 0
                spec.evmImpactPeakTime = now
                spec.evmCollisionInitDeadline = now + 1500 -- kurze zusaetzliche Grace
                return
            end
        end
        spec.evmCollisionLastX, spec.evmCollisionLastY, spec.evmCollisionLastZ = x, y, z
    end

    -- v20: WICHTIG - sampleSpeed kommt PRIMAER vom Spiel (getLastSpeed). Das ist der
    -- einzige Wert, dem wir wirklich vertrauen. Bei einem echten Crash faellt dieser Wert
    -- sicher mit ab. Bei Phantom-Hoppern (Bordstein, Schiene, Bruecke) bleibt er stabil.
    -- physSpeed wird NUR zur Bestaetigung genommen, nicht als alleiniger Trigger.
    local sampleSpeedKmh = lastSpeedOk and lastSpeedKmh or (physOk and physSpeedKmh or 0)

    if sampleSpeedKmh > 180 then
        if doDebug and isControlled then
            print(string.format("[EVM] CollisionDebug source=%s vehicle=%s ignored unrealistic speed %.1f km/h", tostring(source), tostring(evmGetVehicleName(root)), sampleSpeedKmh))
        end
        spec.evmImpactPeakSpeed = 0
        spec.evmImpactPeakTime = now
        spec.evmImpactLastSpeed = sampleSpeedKmh
        spec.evmImpactLastTime = now
        return
    end

    local minSpeed = ExtendedVehicleMaintenance.COLLISION_MIN_SPEED_KMH or 5.0
    local maxDamage = ExtendedVehicleMaintenance.COLLISION_MAX_DAMAGE or 0.18
    local cooldown = ExtendedVehicleMaintenance.COLLISION_COOLDOWN_MS or 1200
    local postImpactGrace = ExtendedVehicleMaintenance.COLLISION_POST_IMPACT_GRACE_MS or 1400
    local brakeSuppression = ExtendedVehicleMaintenance.COLLISION_BRAKE_INPUT_SUPPRESSION ~= false
    local brakeHistoryMs = ExtendedVehicleMaintenance.COLLISION_BRAKE_HISTORY_MS or 1300
    local isBraking, brakeInput, axisForward, handbrake = evmGetBrakeInputState(root)

    if isBraking then spec.evmCollisionLastBrakeTime = now end
    local brakingRecently = spec.evmCollisionLastBrakeTime ~= nil and (now - spec.evmCollisionLastBrakeTime) <= brakeHistoryMs

    if spec.evmLastCollisionTime ~= nil and (now - spec.evmLastCollisionTime) < postImpactGrace then
        spec.evmImpactPeakSpeed = sampleSpeedKmh
        spec.evmImpactPeakTime = now
        spec.evmImpactLastSpeed = sampleSpeedKmh
        spec.evmImpactLastTime = now

        if doDebug and isControlled and sampleSpeedKmh > 0.5 then
            local logEvery = ExtendedVehicleMaintenance.COLLISION_POST_IMPACT_LOG_MS or 450
            if spec.evmCollisionLastPostImpactLog == nil or (now - spec.evmCollisionLastPostImpactLog) >= logEvery then
                spec.evmCollisionLastPostImpactLog = now
                print(string.format("[EVM] Collision ignored vehicle=%s reason=postImpactGrace current=%.1f brake=%.2f axis=%.2f", tostring(evmGetVehicleName(root)), sampleSpeedKmh, brakeInput, axisForward))
            end
        end
        return
    end

    local prevSpeed = spec.evmImpactLastSpeed or sampleSpeedKmh
    local prevTime = spec.evmImpactLastTime or now
    local frameDtSec = math.max((now - prevTime) / 1000, dtSec)
    if frameDtSec <= 0 then frameDtSec = dtSec end

    local frameDrop = math.max(0, prevSpeed - sampleSpeedKmh)
    local frameDecel = frameDrop / frameDtSec

    local peakWindowMs = 700
    if spec.evmImpactPeakSpeed == nil or sampleSpeedKmh >= (spec.evmImpactPeakSpeed or 0) or (now - (spec.evmImpactPeakTime or 0)) > peakWindowMs then
        spec.evmImpactPeakSpeed = sampleSpeedKmh
        spec.evmImpactPeakTime = now
    end

    local peakSpeedKmh = spec.evmImpactPeakSpeed or sampleSpeedKmh
    local speedDrop = math.max(0, peakSpeedKmh - sampleSpeedKmh)
    local relativeDrop = peakSpeedKmh > 0 and (speedDrop / peakSpeedKmh) or 0
    local isCoolingDown = now < ((spec.evmLastCollisionTime or -999999) + cooldown)

    local minImpactSpeed = math.max(minSpeed, ExtendedVehicleMaintenance.COLLISION_MIN_IMPACT_SPEED_KMH or minSpeed)
    local relativeDropLimit = ExtendedVehicleMaintenance.COLLISION_MIN_RELATIVE_DROP or 0.50
    local dynamicMinDrop = math.max(3.0, math.min(12.0, peakSpeedKmh * 0.32))

    -- v19: Frame-Decel deutlich strenger. Vorher 55 (nonBrake) / 115 (brake), jetzt 75 / 130.
    -- Das filtert die typischen "Wende auf Acker"-Drops raus die kein echter Crash sind.
    local nonBrakeDecelLimit = ExtendedVehicleMaintenance.COLLISION_MIN_FRAME_DECEL or 75.0
    local brakeDecelLimit = nonBrakeDecelLimit + 55.0
    local decelLimit = (isBraking or brakingRecently) and brakeDecelLimit or nonBrakeDecelLimit

    local suddenImpulse = peakSpeedKmh >= minImpactSpeed
        and speedDrop >= dynamicMinDrop
        and relativeDrop >= relativeDropLimit
        and frameDecel >= decelLimit

    -- v19: blockedForward braucht jetzt klar erhoehten frameDecel-Threshold.
    local blockedForward = peakSpeedKmh >= minImpactSpeed
        and axisForward > 0.30
        and speedDrop >= dynamicMinDrop
        and sampleSpeedKmh <= math.max(2.5, peakSpeedKmh * 0.40)
        and frameDecel >= 60.0

    -- v19: hardWall erhoeht peakSpeed-Mindest auf 25 km/h, decel auf 65.
    local hardWall = peakSpeedKmh >= 25.0
        and speedDrop >= math.max(10.0, peakSpeedKmh * 0.35)
        and relativeDrop >= 0.40
        and frameDecel >= 65.0

    -- v19: lowSpeedBump war der haeufigste False-Positive-Trigger (Wenden auf weichem Boden).
    -- Wir ziehen den peakSpeed-Mindestwert auf >=10 km/h, decel auf 75 hoch und verlangen,
    -- dass der Spieler aktiv Gas gibt (axisForward > 0.30) damit das eindeutig ein "in
    -- Bewegung gegen Hindernis"-Fall ist statt blosses Stehenbleiben.
    local lowSpeedBump = peakSpeedKmh >= 10.0
        and peakSpeedKmh < 18.0
        and axisForward > 0.30
        and speedDrop >= math.max(5.0, peakSpeedKmh * 0.60)
        and relativeDrop >= 0.65
        and frameDecel >= 75.0
        and not brakingRecently

    local validImpact = suddenImpulse or blockedForward or hardWall or lowSpeedBump

    if brakeSuppression and (isBraking or brakingRecently) and validImpact and not (blockedForward or hardWall) then
        validImpact = false
        if doDebug and isControlled and peakSpeedKmh >= minSpeed and speedDrop >= dynamicMinDrop then
            print(string.format(
                "[EVM] Collision ignored vehicle=%s reason=playerBraking impact=%.1f current=%.1f drop=%.1f relDrop=%.2f frameDrop=%.1f decel=%.1f brake=%.2f axis=%.2f handbrake=%s recent=%s",
                tostring(evmGetVehicleName(root)), peakSpeedKmh, sampleSpeedKmh, speedDrop, relativeDrop, frameDrop, frameDecel, brakeInput, axisForward, tostring(handbrake), tostring(brakingRecently)
            ))
        end
    end

    -- v20: PHYSICS-BESTAETIGUNG.
    -- Bei einem ECHTEN Crash wird die Bewegung physikalisch gebremst. physSpeed muss
    -- den lastSpeed-Drop also in derselben Groessenordnung bestaetigen. Wenn lastSpeed
    -- abrupt faellt aber physSpeed weiter hoch ist (oder umgekehrt), ist das ein Sync-
    -- Glitch oder Frame-Renderspike, kein Crash.
    if validImpact and physOk then
        local physVsLastDelta = math.abs(physSpeedKmh - sampleSpeedKmh)
        -- physSpeed darf max 12 km/h ueber lastSpeed liegen. Daruber: Phantom-Drop.
        if physSpeedKmh > sampleSpeedKmh + 12.0 then
            validImpact = false
            if doDebug and isControlled then
                print(string.format(
                    "[EVM] Collision ignored vehicle=%s reason=physMismatch lastSpeed=%.1f physSpeed=%.1f delta=%.1f (Spiel zeigt Drop, Physik nicht -> wahrscheinlich Render-/Sync-Glitch)",
                    tostring(evmGetVehicleName(root)), sampleSpeedKmh, physSpeedKmh, physVsLastDelta))
            end
        end
    end

    -- v20: MULTI-FRAME-KONSISTENZ.
    -- Ein echter Crash ist nicht in einem einzigen Frame "voll abgeschlossen". Auch beim
    -- Aufprall gegen eine Wand vergehen mind. 2-3 Frames bis das Fahrzeug steht. Ein
    -- Phantom-Drop dagegen ist genau EIN Frame: lastSpeed = 18, dann 4, dann wieder 17.
    -- Wir verlangen daher dass der gemessene Speed in mind. 2 aufeinanderfolgenden
    -- Detection-Ticks unter peakSpeed*0.65 lag.
    -- (Ausnahme: hardWall-Pattern bei sehr hoher Geschwindigkeit - da ist 1 Frame OK)
    if validImpact and not hardWall then
        spec.evmConsistentDropFrames = spec.evmConsistentDropFrames or 0
        local thisFrameDropped = sampleSpeedKmh < (peakSpeedKmh * 0.65) and peakSpeedKmh >= minImpactSpeed
        if thisFrameDropped then
            spec.evmConsistentDropFrames = spec.evmConsistentDropFrames + 1
        else
            spec.evmConsistentDropFrames = 0
        end

        if spec.evmConsistentDropFrames < 2 then
            validImpact = false
            if doDebug and isControlled then
                print(string.format(
                    "[EVM] Collision pending vehicle=%s reason=needConfirmFrame frames=%d sample=%.1f peak=%.1f (warte auf zweiten bestaetigten Drop-Frame)",
                    tostring(evmGetVehicleName(root)), spec.evmConsistentDropFrames, sampleSpeedKmh, peakSpeedKmh))
            end
        end
    else
        -- Reset wenn kein Drop mehr vorliegt
        if not validImpact then
            spec.evmConsistentDropFrames = 0
        end
    end

    -- v20: MP-Modus zusaetzlich strenger.
    -- Im MP gibt es Position-Net-Sync-Korrekturen die einzelne Frames verzerren.
    -- Wenn wir im MP-Modus laufen UND es kein hardWall-Crash ist (= eindeutige Hochgeschwindigkeit),
    -- verlangen wir 3 statt 2 bestaetigte Drop-Frames.
    if validImpact and not hardWall and g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil
        and g_currentMission.missionDynamicInfo.isMultiplayer == true then
        if (spec.evmConsistentDropFrames or 0) < 3 then
            validImpact = false
            if doDebug and isControlled then
                print(string.format(
                    "[EVM] Collision pending vehicle=%s reason=mpExtraConfirm frames=%d (MP braucht 3 bestaetigte Frames)",
                    tostring(evmGetVehicleName(root)), spec.evmConsistentDropFrames or 0))
            end
        end
    end

    if doDebug then
        spec.evmCollisionDebugTimer = (spec.evmCollisionDebugTimer or 0) - (dt or 0)
        if spec.evmCollisionDebugTimer <= 0 then
            spec.evmCollisionDebugTimer = 1000
            if isControlled or speedDrop >= dynamicMinDrop or sampleSpeedKmh > 1 then
                print(string.format(
                    "[EVM] CollisionDebug source=%s vehicle=%s controlled=%s server=%s last=%.1f phys=%s sample=%.1f peak=%.1f drop=%.1f frameDrop=%.1f decel=%.1f minDrop=%.1f cooldown=%s braking=%s recentBrake=%s brake=%.2f axis=%.2f impact=%s confirmFrames=%d damage=%.1f%%",
                    tostring(source), tostring(evmGetVehicleName(root)), tostring(isControlled), tostring(root.isServer), lastSpeedKmh, physOk and string.format("%.1f", physSpeedKmh) or "n/a", sampleSpeedKmh, peakSpeedKmh, speedDrop, frameDrop, frameDecel, dynamicMinDrop, tostring(isCoolingDown), tostring(isBraking), tostring(brakingRecently), brakeInput, axisForward, tostring(validImpact), tonumber(spec.evmConsistentDropFrames or 0), evmGetVehicleDamage(root) * 100
                ))
            end
        end
    end

    if peakSpeedKmh >= minSpeed and speedDrop >= dynamicMinDrop and not validImpact and not isCoolingDown and doDebug and isControlled and not (isBraking or brakingRecently) then
        print(string.format(
            "[EVM] Collision ignored vehicle=%s reason=noImpactSignature impact=%.1f current=%.1f drop=%.1f relDrop=%.2f frameDrop=%.1f decel=%.1f needDecel=%.1f axis=%.2f",
            tostring(evmGetVehicleName(root)), peakSpeedKmh, sampleSpeedKmh, speedDrop, relativeDrop, frameDrop, frameDecel, decelLimit, axisForward
        ))
    end

    if peakSpeedKmh >= minSpeed and speedDrop >= dynamicMinDrop and validImpact and not isCoolingDown then
        local impactSpeed = math.min(peakSpeedKmh, 80)
        local speedFactor = evmClamp((impactSpeed - minSpeed) / 45.0, 0.04, 1)
        local dropFactor = evmClamp(speedDrop / 30.0, 0.10, 1)
        local impulseFactor = evmClamp(frameDecel / 120.0, 0.25, 1.15)
        local collisionDamage = speedFactor * dropFactor * impulseFactor * maxDamage

        spec.evmLastCollisionTime = now
        spec.evmImpactPeakSpeed = sampleSpeedKmh
        spec.evmImpactPeakTime = now

        if doDebug then
            print(string.format(
                "[EVM] COLLISION detected source=%s vehicle=%s impact=%.1f current=%.1f drop=%.1f relDrop=%.2f frameDrop=%.1f decel=%.1f addDamage=%.2f%% flags impulse=%s blocked=%s hardWall=%s low=%s isServer=%s isClient=%s",
                tostring(source), tostring(evmGetVehicleName(root)), impactSpeed, sampleSpeedKmh, speedDrop, relativeDrop, frameDrop, frameDecel, collisionDamage * 100, tostring(suddenImpulse), tostring(blockedForward), tostring(hardWall), tostring(lowSpeedBump), tostring(root.isServer), tostring(root.isClient)
            ))
        end

        if collisionDamage > 0.0005 then
            -- v16: MP-Fix. Im Multiplayer ist root.isServer auf dem Client false,
            -- d.h. der frühere "and root.isServer"-Pfad hat im MP NIE Schaden gesetzt.
            -- Wir trennen nun sauber:
            --   * Server (SP/Host): Schaden direkt anwenden.
            --   * Reiner Client: Event an Server schicken; Server appliziert + broadcastet.
            if root.isServer then
                local currentDamage = evmGetVehicleDamage(root)
                local newDamage = evmClamp(currentDamage + collisionDamage, 0, 1)
                local applied = false

                if root.setDamageAmount ~= nil then
                    local okSet, errSet = pcall(root.setDamageAmount, root, newDamage, true)
                    applied = okSet == true
                    if not okSet and doDebug then
                        print(string.format("[EVM] COLLISION setDamageAmount failed vehicle=%s err=%s", tostring(evmGetVehicleName(root)), tostring(errSet)))
                    end
                end

                if not applied and root.spec_wearable ~= nil then
                    root.spec_wearable.damage = newDamage
                    applied = true
                end

                if applied then
                    if root.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                        root:raiseDirtyFlags(spec.dirtyFlag)
                    end
                    if doDebug then
                        evmDbg("COLLISION damage applied (server) vehicle=%s %.2f%% -> %.2f%%", tostring(evmGetVehicleName(root)), currentDamage * 100, newDamage * 100)
                    end
                elseif doDebug then
                    evmDbg("COLLISION damage NOT applied vehicle=%s reason=no damage setter/spec_wearable", tostring(evmGetVehicleName(root)))
                end
            else
                -- Reiner Client: Schaden an Server schicken.
                if EVMCollisionDamageEvent ~= nil and EVMCollisionDamageEvent.sendEvent ~= nil then
                    local sent = EVMCollisionDamageEvent.sendEvent(root, collisionDamage) == true
                    if doDebug then
                        evmDbg("COLLISION damage sent to server vehicle=%s add=%.2f%% sent=%s", tostring(evmGetVehicleName(root)), collisionDamage * 100, tostring(sent))
                    end
                elseif doDebug then
                    print(string.format("[EVM] COLLISION client cannot send damage event vehicle=%s (event class missing)", tostring(evmGetVehicleName(root))))
                end
            end
        elseif doDebug then
            print(string.format("[EVM] COLLISION damage skipped vehicle=%s reason=smallDamage damage=%.4f server=%s", tostring(evmGetVehicleName(root)), collisionDamage, tostring(root.isServer)))
        end
    end

    spec.evmImpactLastSpeed = sampleSpeedKmh
    spec.evmImpactLastTime = now
end
function ExtendedVehicleMaintenance:onUpdate(dt)
    if self.isClient and ExtendedVehicleMaintenance.hudEditMode == true then
        evmMaintainHudEditInput()
    end

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime

    if runtime ~= nil and runtime._serviceWatchers ~= nil and #runtime._serviceWatchers > 0 then
        local now = g_time or 0

        for i = #runtime._serviceWatchers, 1, -1 do
            local watcher = runtime._serviceWatchers[i]
            if watcher ~= nil and now >= (watcher.triggerTime or 0) then
                table.remove(runtime._serviceWatchers, i)

                if watcher.callback ~= nil then
                    local ok, err = pcall(watcher.callback)
                    if not ok then
                        print(string.format("[EVM] service watcher failed: %s", tostring(err)))
                    end
                end
            end
        end
    end

    local rt = ExtendedVehicleMaintenance.spec_serviceRuntime
    local runtimeServiceVehicle = nil
    if rt ~= nil and rt.active == true and rt.pendingLockData ~= nil and rt._persistLockResolved ~= true then
        runtimeServiceVehicle = ExtendedVehicleMaintenance.enforceRuntimePersistLock("onUpdate")
    elseif rt ~= nil and rt.active == true then
        runtimeServiceVehicle = rt.rootVehicle
    end

    if rt ~= nil and rt.active == true and runtimeServiceVehicle ~= nil and self.isServer then
        local runtimeServiceSpec = evmGetVehicleSpec(runtimeServiceVehicle)
        if runtimeServiceSpec ~= nil then
            local remaining = evmGetServiceRemainingMs(runtimeServiceSpec, runtimeServiceVehicle)
            if remaining <= 0 then
                ExtendedVehicleMaintenance.finishService(runtimeServiceVehicle)
            elseif runtimeServiceVehicle.raiseDirtyFlags ~= nil and runtimeServiceSpec.dirtyFlag ~= nil then
                pcall(runtimeServiceVehicle.raiseDirtyFlags, runtimeServiceVehicle, runtimeServiceSpec.dirtyFlag)
            end
        end
    end

    local activeSpec, activeVehicle = evmGetActiveServiceSpec(self)
    if activeSpec ~= nil and activeVehicle ~= nil then
        ExtendedVehicleMaintenance.installGlobalInputLocks()
        if (activeVehicle.rootVehicle or activeVehicle)._evmHardLockActive ~= true then
            ExtendedVehicleMaintenance.installEnterLock(activeVehicle, activeSpec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
            ExtendedVehicleMaintenance.installHardVehicleLock(activeVehicle)
        end
        evmClearControlledVehicleIfLocked(activeVehicle)
    end
end

function ExtendedVehicleMaintenance:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = evmGetVehicleSpec(self)

    if spec == nil then
        return
    end

    -- Kollisionsschaden wird zentral verarbeitet.
    ExtendedVehicleMaintenance.processCollisionDamage(self, dt, "onUpdateTick")

    local currentGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()
    local gameDt = math.max(0, currentGameTimeMs - (spec.lastTickGameTimeMs or currentGameTimeMs))
    spec.lastTickGameTimeMs = currentGameTimeMs

    local activeSpec, activeVehicle = evmGetActiveServiceSpec(self)
    if activeSpec ~= nil and activeVehicle ~= nil then
        ExtendedVehicleMaintenance.installGlobalInputLocks()
        if (activeVehicle.rootVehicle or activeVehicle)._evmHardLockActive ~= true then
            ExtendedVehicleMaintenance.installEnterLock(activeVehicle, activeSpec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
            ExtendedVehicleMaintenance.installHardVehicleLock(activeVehicle)
        end
        evmClearControlledVehicleIfLocked(activeVehicle)

        spec.debugTimer = (spec.debugTimer or 0) - dt
        if spec.debugTimer <= 0 then
            spec.debugTimer = 1000

            local rootVehicle = activeVehicle.rootVehicle or activeVehicle
            local controlled = g_currentMission ~= nil and g_currentMission.controlledVehicle == rootVehicle
            local localCurrent = g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil and g_localPlayer:getCurrentVehicle() == rootVehicle
            local isEntered = rootVehicle.getIsEntered ~= nil and rootVehicle:getIsEntered() or false
            local speed = rootVehicle.getLastSpeed ~= nil and rootVehicle:getLastSpeed() or -1
            local started = rootVehicle.getIsMotorStarted ~= nil and rootVehicle:getIsMotorStarted() or false

            evmDbg("LOCK TICK vehicle=%s controlled=%s localCurrent=%s entered=%s speed=%.4f motorStarted=%s remainingMs=%s hardLock=%s",
                tostring(evmGetVehicleName(rootVehicle)),
                tostring(controlled),
                tostring(localCurrent),
                tostring(isEntered),
                tonumber(speed or -1),
                tostring(started),
                tostring(activeSpec.serviceRemainingGameMs or 0),
                tostring(rootVehicle._evmHardLockActive))
        end

        if self.isClient and g_currentMission ~= nil and g_currentMission.time ~= nil and g_currentMission.time >= (ExtendedVehicleMaintenance.clientLockWarningUntil or 0) then
            ExtendedVehicleMaintenance.clientLockWarningUntil = g_currentMission.time + 1500
            local remSec = math.max(0, math.ceil(evmGetServiceRemainingMs(activeSpec, activeVehicle) / 1000))
            if g_currentMission.showBlinkingWarning ~= nil then
                g_currentMission:showBlinkingWarning(
                    string.format(
                        evmText("warning_evmInServiceCountdown", "Maintenance running: %s (%d sec)"),
                        tostring(evmGetVehicleName(activeVehicle)),
                        remSec
                    ),
                    2000
                )
            end
        end

        if self.isServer and (activeVehicle.rootVehicle or activeVehicle) == (self.rootVehicle or self) then
            if gameDt <= 0 then
                local timeScale = 1
                if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.timeScale ~= nil then
                    timeScale = tonumber(g_currentMission.missionInfo.timeScale) or 1
                elseif g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.timeScale ~= nil then
                    timeScale = tonumber(g_currentMission.environment.timeScale) or 1
                end
                gameDt = math.max(0, tonumber(dt or 0) or 0) * math.max(1, timeScale)
            end

            if (activeSpec.serviceEndAbsHours or 0) <= 0 then
                activeSpec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + ((activeSpec.serviceRemainingGameMs or 0) / 3600000)
            end
            activeSpec.serviceRemainingGameMs = evmGetServiceRemainingMs(activeSpec, activeVehicle)

            local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
            if runtime ~= nil and runtime.pendingLockData ~= nil then
                runtime.pendingLockData.serviceRemainingGameMs = activeSpec.serviceRemainingGameMs
                runtime.pendingLockData.serviceEndAbsHours = activeSpec.serviceEndAbsHours or 0
                if runtime.syntheticLockSpec ~= nil then
                    runtime.syntheticLockSpec.serviceRemainingGameMs = activeSpec.serviceRemainingGameMs
                    runtime.syntheticLockSpec.serviceEndAbsHours = activeSpec.serviceEndAbsHours or 0
                end
            end

            if activeSpec.serviceRemainingGameMs <= 0 then
                ExtendedVehicleMaintenance.finishService(activeVehicle)
            else
                if activeVehicle.raiseDirtyFlags ~= nil and activeSpec.dirtyFlag ~= nil then
                    activeVehicle:raiseDirtyFlags(activeSpec.dirtyFlag)
                end
            end
        end

        return
    end

    if self._evmHardLockActive then
        ExtendedVehicleMaintenance.removeHardVehicleLock(self)
    end

    if self.spec_motorized ~= nil and self.getIsEntered ~= nil then
        local enteredNow = self:getIsEntered() == true
        if enteredNow and not spec.wasEntered then
            spec.enterHintUntil = (g_currentMission ~= nil and g_currentMission.time or 0) + ExtendedVehicleMaintenance.ENTER_HINT_DURATION_MS
            -- Keine Einstieg-Blink-Warnung mehr: Service steht dauerhaft im EVM-HUD.
            -- v19: Beim Einsteigen Kollisions-Init-Grace neu starten. Verhindert dass der
            -- Position-Spike beim Switch des kontrollierten Fahrzeugs als Crash erkannt wird.
            local now = (g_time or 0)
            spec.evmCollisionInitDeadline = now + (ExtendedVehicleMaintenance.COLLISION_INIT_GRACE_MS or 2500)
            spec.evmCollisionLastX, spec.evmCollisionLastY, spec.evmCollisionLastZ = nil, nil, nil
            spec.evmImpactPeakSpeed = 0
            spec.evmImpactPeakTime = now
            spec.evmImpactLastSpeed = 0
            spec.evmImpactLastTime = now
        end
        spec.wasEntered = enteredNow

        -- v18: Quick-Fix / Limp-Home Action-Texte alle ~750ms aktualisieren wenn der Spieler im Fahrzeug sitzt.
        -- Damit der Button erscheint sobald eine MINOR-Panne auftritt, ohne dass der Spieler aussteigen muss.
        if enteredNow and self.isClient then
            spec.evmActionRefreshTimer = (spec.evmActionRefreshTimer or 0) - (dt or 0)
            if spec.evmActionRefreshTimer <= 0 then
                spec.evmActionRefreshTimer = 750
                if ExtendedVehicleMaintenance.updateQuickFixActionText ~= nil then
                    ExtendedVehicleMaintenance.updateQuickFixActionText(self)
                end
                if ExtendedVehicleMaintenance.updateLimpHomeActionText ~= nil then
                    ExtendedVehicleMaintenance.updateLimpHomeActionText(self)
                end
            end
        end
    end

    -- Client: visuelle Panning-Effekte (Warnungen, Reifeneffekte) – nur wenn Server die Panne bestätigt hat
    -- (spec.failureType wird via onReadStream/onReadUpdateStream vom Server gesetzt → kein Desync)
    if self.isClient and not self.isServer and spec.failureType ~= nil and spec.failureType ~= "" then
        ExtendedVehicleMaintenance.updateActiveFailure(self, spec, dt, false)
    end


    -- Batterie-Simulation läuft global in ExtendedVehicleMaintenance:update().
    -- Grund: geparkte Fahrzeuge bekommen nicht zuverlässig onUpdateTick, besonders wenn Motor aus.

    if self.isServer then
        -- Server: Panning-Logik UND visuelle Updates (Singleplayer / Server-Spieler)
        if spec.failureType ~= nil and spec.failureType ~= "" then
            ExtendedVehicleMaintenance.updateActiveFailure(self, spec, dt, true)
        end
        -- Zufalls-Pannen werden zentral im globalen Server-Update geprüft.
        -- Grund: Im MP/Dedi feuert onUpdateTick nicht für jedes geladene Fahrzeug zuverlässig.

        local isDue = ExtendedVehicleMaintenance.isDue(self)
        if isDue then
            if self.setDamageAmount ~= nil and self.spec_motorized ~= nil and self.getIsMotorStarted ~= nil and self:getIsMotorStarted() then
                local newDamage = evmClamp(evmGetVehicleDamage(self) + (dt or 0) * 0.0000004, 0, 1)
                pcall(self.setDamageAmount, self, newDamage, true)
            end

            if self.spec_motorized ~= nil then
                spec.stallTimer = (spec.stallTimer or ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL) - dt
                if spec.stallTimer <= 0 then
                    spec.stallTimer = ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL
                    if self.getIsMotorStarted ~= nil and self:getIsMotorStarted() and self.getMotorLoadPercentage ~= nil then
                        local load = self:getMotorLoadPercentage() or 0
                        if load >= ExtendedVehicleMaintenance.STALL_LOAD_THRESHOLD and self.stopMotor ~= nil then
                            self:stopMotor()
                        end
                    end
                end
            end
        else
            spec.stallTimer = ExtendedVehicleMaintenance.STALL_CHECK_INTERVAL
        end
    end
end

function ExtendedVehicleMaintenance.drawNearbyServiceCountdownHelp()
    local mission = g_currentMission
    if mission == nil or mission.addExtraPrintText == nil then
        return
    end
    local frameKey = g_updateLoopIndex or g_currentFrameTime or mission.time or g_time or 0
    if ExtendedVehicleMaintenance._lastNearbyHelpFrame == frameKey then
        return
    end
    ExtendedVehicleMaintenance._lastNearbyHelpFrame = frameKey

    local bestVehicle, bestSpec = evmFindNearbyActiveServiceVehicle(ExtendedVehicleMaintenance.NEARBY_SERVICE_DISTANCE or 28)
    if bestVehicle == nil or bestSpec == nil then
        return
    end

    local remainingMs = evmGetServiceRemainingMs(bestSpec, bestVehicle)
    if remainingMs <= 0 then
        return
    end

    local hours, minutes = evmFormatHoursMinutes(remainingMs)
    local vehicleName = evmGetVehicleLabel(bestVehicle) or evmGetVehicleName(bestVehicle) or "Fahrzeug"
    local txt
    if hours > 0 then
        txt = string.format(evmText("help_evmInServiceCountdownLong", "%s in Wartung: noch %d Std. %02d Min."), tostring(vehicleName), hours, minutes)
    else
        local seconds = math.max(0, math.ceil(remainingMs / 1000))
        if seconds < 60 then
            txt = string.format(evmText("help_evmInServiceCountdownSeconds", "%s in Wartung: noch %d Sek."), tostring(vehicleName), seconds)
        else
            txt = string.format(evmText("help_evmInServiceCountdownShort", "%s in Wartung: noch %d Min."), tostring(vehicleName), math.max(1, minutes))
        end
    end
    mission:addExtraPrintText(txt)
end

function ExtendedVehicleMaintenance:draw()
    ExtendedVehicleMaintenance.drawNearbyServiceCountdownHelp()

    -- Wie bei RealisticWorkSpeed: HUD global zeichnen, nicht nur ueber Vehicle:onDraw.
    local root = evmGetCurrentLocalVehicle()
    if root ~= nil and evmGetVehicleSpec(root) ~= nil and ExtendedVehicleMaintenance.hudConfig ~= nil and ExtendedVehicleMaintenance.hudConfig.enabled then
        ExtendedVehicleMaintenance.drawVehicleHUD(root, nil)
    end
end

-- -----------------------------------------------------------------------
-- HUD-System
-- -----------------------------------------------------------------------
local EVM_HUD = {}

-- Kontrollleuchten-Definitionen
-- type: failureType das diese Leuchte auslöst (oder "serviceDue", "serviceSoon", "serviceActive")
-- r,g,b: Farbe wenn aktiv
-- symbol: Unicode-Symbol
EVM_HUD.lamps = {
    { type="engine",        r=1,    g=0.15, b=0.1,  symbol="⚙",  labelKey="hud_lamp_engine",     labelFb="Motor" },
    { type="flatTire",      r=1,    g=0.5,  b=0,    symbol="●",  labelKey="hud_lamp_tire",       labelFb="Reifen" },
    { type="rpmLimit",      r=1,    g=0.7,  b=0,    symbol="▲",  labelKey="hud_lamp_rpm",        labelFb="Notlauf" },
    { type="hydraulicLeak", r=0.8,  g=0.1,  b=1,    symbol="◆",  labelKey="hud_lamp_hydraulic",  labelFb="Hydraulik" },
    { type="brakeFault",    r=1,    g=0,    b=0,    symbol="■",  labelKey="hud_lamp_brake",      labelFb="Bremse" },
    { type="serviceDue",    r=1,    g=0.15, b=0.1,  symbol="🔧", labelKey="hud_lamp_service",    labelFb="Wartung!" },
    { type="serviceSoon",   r=1,    g=0.8,  b=0,    symbol="🔧", labelKey="hud_lamp_soon",       labelFb="Wartung bald" },
    { type="serviceActive", r=0.2,  g=0.6,  b=1,    symbol="⏳", labelKey="hud_lamp_active",    labelFb="In Wartung" },
}

function ExtendedVehicleMaintenance.drawColoredDriverInfo(vehicle, spec, message, level)
    if message == nil or message == "" or renderText == nil then return false end
    local r, g, b = 1, 1, 1
    if level == "danger" then
        r, g, b = 1, 0.18, 0.12
    elseif level == "warn" then
        r, g, b = 1, 0.72, 0.12
    elseif level == "ok" then
        r, g, b = 0.25, 1, 0.25
    end
    if setTextColor ~= nil then setTextColor(r, g, b, 1) end
    if setTextBold ~= nil then setTextBold(true) end
    renderText(0.018, 0.815, 0.018, tostring(message))
    if setTextBold ~= nil then setTextBold(false) end
    if setTextColor ~= nil then setTextColor(1, 1, 1, 1) end
    return true
end

-- Gibt die simulierte Batteriespannung in Volt zurueck.
-- Berechnet Lichtmaschine, elektrische Last (Lichter/Blinker) und Rauschen realistisch.
evmGetElectricalLoad = function(vehicle, engineOn)
    if vehicle == nil then return 0 end
    vehicle = vehicle.rootVehicle or vehicle

    local load = 0.0
    local activeLights = false
    local mask = 0

    local function addMask(v)
        local n = tonumber(v) or 0
        if n > 0 then
            mask = math.max(mask, n)
            activeLights = true
        end
    end

    local lights = vehicle.spec_lights
    if lights ~= nil then
        -- Serverseitig real synchronisierte Felder (Basisspiel pflegt diese auf Dedi):
        -- lightsTypesMask (gewünschter Modus), turnLightState, beaconLightsActive.
        -- Die "active*" und "current*" Felder sind nur clientseitige Render-States.
        addMask(lights.lightsTypesMask)
        addMask(lights.activeLightTypesMask)
        addMask(lights.activeLightsTypesMask)
        addMask(lights.activeLightsMask)
        addMask(lights.currentLightTypesMask)
        addMask(lights.currentLightsTypesMask)
        addMask(lights.realLightsTypesMask)
        addMask(lights.lastLightTypesMask)
        addMask(lights.lastLightsTypesMask)

        local state = tonumber(lights.currentLightState or lights.lightState or lights.lastLightState or 0) or 0
        if state > 0 then
            activeLights = true
            if mask <= 0 then mask = state end
        end

        local isControlled = false
        if g_currentMission ~= nil then
            local cv = g_currentMission.controlledVehicle or g_currentMission.currentVehicle
            if cv ~= nil and (cv.rootVehicle or cv) == vehicle then
                isControlled = true
            end
        end
        if not activeLights and isControlled then
            addMask(lights.lightsTypesMask)
        end

        if not activeLights and getVisibility ~= nil then
            local function checkLightList(list)
                if type(list) ~= "table" then return false end
                for _, l in pairs(list) do
                    if type(l) == "table" then
                        local node = l.node or l.lightNode or l.realLightNode or l.linkNode or l.sharedLightNode
                        if node ~= nil then
                            local ok, vis = pcall(getVisibility, node)
                            if ok and vis == true then return true end
                        end
                    elseif type(l) == "number" then
                        local ok, vis = pcall(getVisibility, l)
                        if ok and vis == true then return true end
                    end
                end
                return false
            end
            if checkLightList(lights.realLights) or checkLightList(lights.defaultLights) or checkLightList(lights.staticLights) or checkLightList(lights.beamLights) then
                activeLights = true
            end
        end

        if activeLights then
            -- Realistische LED/Halogen-Mischung: Grundlast 4A für Standlicht/Armaturenbrett.
            load = load + 4.0
            local groups = 1
            if mask > 0 then
                groups = 0
                local m = mask
                while m > 0 do
                    if bit32 ~= nil and bit32.band ~= nil then
                        if bit32.band(m, 1) ~= 0 then groups = groups + 1 end
                        m = bit32.rshift(m, 1)
                    else
                        if (m % 2) >= 1 then groups = groups + 1 end
                        m = math.floor(m / 2)
                    end
                end
                groups = math.max(1, groups)
            end
            -- Pro aktiver Lichtgruppe ~0.8A (LED) bis max. 8A insgesamt.
            -- Vorher: 1.5A pro Gruppe, max 18A — viel zu hoch.
            load = load + math.min(groups * 0.8, 8.0)
        end

        local turnState = tonumber(lights.turnLightState or lights.activeTurnLightState or lights.turnLightActiveState or 0) or 0
        if turnState == 1 or turnState == 2 then
            load = load + 1.0     -- Blinker einseitig: ~1A
        elseif turnState == 3 or turnState == 4 then
            load = load + 2.0     -- Warnblinker: ~2A
        elseif lights.hazardLightsActive == true or lights.warningLightsActive == true then
            load = load + 2.0
        end
    end

    local beacons = vehicle.spec_beaconLights
    if beacons ~= nil and (beacons.beaconLightsActive == true or beacons.isActive == true) then
        load = load + 2.0     -- Rundumkennleuchte LED: ~2A (vorher 5A)
    end

    if engineOn == true then
        load = load + 1.5     -- Steuergeräte/ECU bei laufendem Motor (vorher 3A)
    end

    return load
end

evmGetEngineOn = function(vehicle)
    if vehicle == nil then return false end
    vehicle = vehicle.rootVehicle or vehicle

    if vehicle.getIsMotorStarted ~= nil then
        local ok, v = pcall(vehicle.getIsMotorStarted, vehicle)
        if ok and v == true then return true end
    end

    local motorized = vehicle.spec_motorized
    local motor = motorized ~= nil and motorized.motor or nil
    if motor ~= nil then
        if motor.getIsStarted ~= nil then
            local ok, v = pcall(motor.getIsStarted, motor)
            if ok and v == true then return true end
        end
        if motor.isStarted == true or motor.motorStarted == true or motor.isRunning == true then
            return true
        end
    end

    if vehicle.getMotorRpm ~= nil then
        local ok, rpm = pcall(vehicle.getMotorRpm, vehicle)
        if ok and (tonumber(rpm) or 0) > 350 then return true end
    end
    if motorized ~= nil and tonumber(motorized.motorRpm or motorized.rpm or 0) > 350 then
        return true
    end

    return false
end

evmGetAlternatorVoltage = function(vehicle)
    if vehicle == nil then return 0 end
    vehicle = vehicle.rootVehicle or vehicle
    if not evmGetEngineOn(vehicle) then return 0 end

    local rpm = 0
    if vehicle.getMotorRpm ~= nil then
        local ok, r = pcall(vehicle.getMotorRpm, vehicle)
        if ok then rpm = tonumber(r) or 0 end
    end
    local rpmFactor = evmClamp((rpm - 600) / 1400, 0, 1)
    return 13.6 + rpmFactor * 0.8  -- 13.6V Leerlauf bis 14.4V Vollgas
end

local function evmIsIgnoredBatteryVehicle(vehicle)
    if vehicle == nil then return true end
    local name = tostring(evmGetVehicleName(vehicle) or "")
    if name == "Train" or name:lower():find("train", 1, true) ~= nil then
        return true
    end
    -- Ohne Motorisierung keine echte Fahrzeugbatterie simulieren.
    if vehicle.spec_motorized == nil and vehicle.getIsMotorStarted == nil then
        return true
    end
    return false
end

evmProcessBattery = function(vehicle, spec, dt, source)
    if vehicle == nil or spec == nil then return end
    if evmIsIgnoredBatteryVehicle(vehicle) then return end

    local realMs = math.max(0, tonumber(dt or 0) or 0)
    if realMs <= 0 then return end

    spec.batteryCharge = evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1)
    spec.batteryVoltage = evmClamp(tonumber(spec.batteryVoltage) or 12.7, 6.0, 15.5)

    local engineOn = evmGetEngineOn(vehicle)

    local timeScale = 1
    if g_currentMission ~= nil then
        if g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.timeScale ~= nil then
            timeScale = tonumber(g_currentMission.missionInfo.timeScale) or 1
        elseif g_currentMission.environment ~= nil and g_currentMission.environment.timeScale ~= nil then
            timeScale = tonumber(g_currentMission.environment.timeScale) or 1
        end
    end
    timeScale = math.max(1, timeScale)

    local elapsedGameHours = (realMs / 3600000.0) * timeScale
    if elapsedGameHours <= 0 then return end

    local oldCharge = spec.batteryCharge
    local oldVoltage = spec.batteryVoltage
    local load = evmGetElectricalLoad(vehicle, engineOn)
    local current = load
    local CAPACITY_AH = 72.0

    if engineOn then
        -- Realistische Lichtmaschine: ~25A Netto-Ladestrom bei Leerlauf,
        -- bis ~45A bei höherer Drehzahl. Bei 72Ah-Batterie bedeutet das eine
        -- volle Aufladung von leer in ca. 2-3 Stunden Spielzeit (= realistisch).
        local rpm = 0
        if vehicle.getMotorRpm ~= nil then
            local ok, r = pcall(vehicle.getMotorRpm, vehicle)
            if ok then rpm = tonumber(r) or 0 end
        end
        -- Drehzahl-abhängige Lichtmaschinen-Leistung: 18A im Stand, 35A bei Volllast
        local rpmFactor = evmClamp((rpm - 600) / 1400, 0, 1)
        local alternatorCurrent = 18.0 + rpmFactor * 17.0   -- 18-35A
        local netCurrent = alternatorCurrent - current
        if netCurrent > 0 then
            -- Sanfte Tapering-Kurve: ab 80% wird das Laden langsamer (echte Akkus)
            local taper = 1.0
            if oldCharge > 0.80 then
                -- Von 80% bis 100% wird die Ladegeschwindigkeit sanft auf 5% reduziert
                taper = evmClamp((1.0 - oldCharge) / 0.20, 0.05, 1.0)
            end
            spec.batteryCharge = evmClamp(oldCharge + (netCurrent * elapsedGameHours / CAPACITY_AH) * taper, 0, 1.0)
        else
            spec.batteryCharge = evmClamp(oldCharge - ((-netCurrent) * elapsedGameHours / CAPACITY_AH), 0, 1.0)
        end

        -- Falls ein extern gestartetes/gerettetes Fahrzeug noch als Batterie-Panne markiert ist,
        -- gibt die laufende Lichtmaschine die Batterie nach etwas Ladung wieder frei.
        if spec.failureType == "battery" and (spec.batteryCharge or 0) > 0.12 then
            spec.failureType = ""
            spec.failureSeverity = 0
            spec.failureWarnUntil = 0
            ExtendedVehicleMaintenance.restoreBatteryFailure(vehicle)
            if vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                vehicle:raiseDirtyFlags(spec.dirtyFlag)
            end
            if g_server ~= nil and EVMFailureStateEvent ~= nil then
                EVMFailureStateEvent.sendEvent(vehicle, "", 0, 0, 0, 0)
            end
            print(string.format("[EVM] Battery recovered on %s charge=%.3f volt=%.2f", tostring(evmGetVehicleName(vehicle)), tonumber(spec.batteryCharge or 0), tonumber(spec.batteryVoltage or 0)))
        end
    else
        if current <= 0.001 then
            current = 0.02
        end
        spec.batteryCharge = evmClamp(oldCharge - (current * elapsedGameHours / CAPACITY_AH), 0, 1.0)
    end

    spec.batteryVoltage = ExtendedVehicleMaintenance.getBatteryVoltage(vehicle, spec)

    local chargeChanged = math.abs((spec.batteryCharge or oldCharge) - oldCharge) > 0.00001
    local voltageChanged = math.abs((spec.batteryVoltage or oldVoltage) - (oldVoltage or spec.batteryVoltage or 12.7)) > 0.03
    local hasRelevantBatteryLoad = (current or 0) > 0.05 or engineOn == true or (spec.failureType == "battery") or (spec.batteryCharge or 1) < 0.999
    local changed = chargeChanged or voltageChanged or (hasRelevantBatteryLoad and spec._batteryInitialSyncDone ~= true)
    if changed and vehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        vehicle:raiseDirtyFlags(spec.dirtyFlag)
    end

    -- MP/Dedi v15: Sync-Filter wieder entschärft.
    -- v14 war zu streng: dadurch konnten Logs/Sends komplett wegfallen.
    if g_server ~= nil and EVMBatteryStateEvent ~= nil and changed then
        spec._batterySyncTimer = (spec._batterySyncTimer or 0) - realMs
        local lastSyncV = tonumber(spec._batteryLastSyncVoltage) or -999
        local lastSyncC = tonumber(spec._batteryLastSyncCharge) or -999

        local needBatterySync = spec._batteryInitialSyncDone ~= true
            or spec._batterySyncTimer <= 0
            or math.abs((spec.batteryVoltage or 0) - lastSyncV) >= 0.03
            or math.abs((spec.batteryCharge or 0) - lastSyncC) >= 0.002

        if needBatterySync then
            spec._batteryInitialSyncDone = true
            spec._batterySyncTimer = 500
            spec._batteryLastSyncVoltage = spec.batteryVoltage or 12.7
            spec._batteryLastSyncCharge = spec.batteryCharge or 1.0
            EVMBatteryStateEvent.sendEvent(vehicle, spec.batteryCharge or 1.0, spec.batteryVoltage or 12.7, spec.failureType or "", spec.failureSeverity or 0)
        end
    end

    -- Battery tick logging intentionally disabled by default.
    -- The old v15 debug block printed one line per vehicle every few seconds on servers
    -- ("[EVM] BATTERY global ..."), which caused heavy log spam.
    -- It is now only visible when the normal EVM debug mode is explicitly enabled.
    if ExtendedVehicleMaintenance.debug == true then
        spec._batteryDebugTimer = (spec._batteryDebugTimer or 0) - realMs
        if spec._batteryDebugTimer <= 0 then
            spec._batteryDebugTimer = 5000
            print(string.format("[EVM] BATTERY %s vehicle=%s engine=%s load=%.3fA scale=%.0f elapsedH=%.4f charge %.4f -> %.4f volt=%.2f sync=%s",
                tostring(source or "tick"), tostring(evmGetVehicleName(vehicle)), tostring(engineOn), tonumber(current or 0), tonumber(timeScale or 1), tonumber(elapsedGameHours or 0), tonumber(oldCharge or 0), tonumber(spec.batteryCharge or 0), tonumber(spec.batteryVoltage or 0), tostring(g_server ~= nil and EVMBatteryStateEvent ~= nil)))
        end
    end

    if not engineOn and (spec.batteryCharge or 1) < 0.04 and (spec.failureType == nil or spec.failureType == "") then
        spec.batteryCharge = 0.0
        spec.batteryVoltage = 6.5 + math.random() * 2.0
        print(string.format("[EVM] Battery dead on %s (load=%.2fA)", tostring(evmGetVehicleName(vehicle)), tonumber(current or 0)))
        ExtendedVehicleMaintenance.applyRandomFailure(vehicle, "battery", 1.0)
    end
end

function ExtendedVehicleMaintenance.getBatteryVoltage(vehicle, spec)
    if spec == nil then return 12.6 end

    -- Batteriepanne: feste Niederspannung
    if spec.failureType == "battery" then
        return evmClamp(tonumber(spec.batteryVoltage) or 8.5, 6.5, 10.5)
    end

    local charge = evmClamp(tonumber(spec.batteryCharge) or 1.0, 0, 1)
    -- Ruhespannung: 11.4V (leer) bis 12.7V (voll geladen)
    local baseV  = 11.4 + charge * 1.3

    local engineOn = evmGetEngineOn ~= nil and evmGetEngineOn(vehicle) or false
    local altV   = evmGetAlternatorVoltage(vehicle)   -- 0 oder 13.6-14.4V
    local load   = evmGetElectricalLoad(vehicle, engineOn)       -- Ampere

    -- Spannungsabfall pro Ampere: ~0.022V (Innenwiderstand ~0.02 Ohm)
    local loadDrop = load * 0.022

    local voltage
    if altV > 0 then
        -- Motor laeuft: Lichtmaschine dominiert, Last senkt Spannung leicht
        voltage = altV - loadDrop * 0.5
    else
        -- Motor aus: Batteriespannung minus Lastabfall
        voltage = baseV - loadDrop
    end

    -- v14 MP-Fix: Kein Zufallsrauschen im gespeicherten Batterie-State.
    return evmClamp(voltage, 6.0, 15.5)
end

-- Rueckwaerts-Kompatibilitaet
function ExtendedVehicleMaintenance.getBatteryPercent(vehicle, spec)
    local v = ExtendedVehicleMaintenance.getBatteryVoltage(vehicle, spec)
    return evmClamp(((v - 11.4) / 1.3) * 100, 0, 100)
end

function ExtendedVehicleMaintenance.getHudIconOverlay(iconName)
    if iconName == nil or iconName == "" then return nil end
    ExtendedVehicleMaintenance._hudIconOverlays = ExtendedVehicleMaintenance._hudIconOverlays or {}
    if ExtendedVehicleMaintenance._hudIconOverlays[iconName] ~= nil then
        return ExtendedVehicleMaintenance._hudIconOverlays[iconName]
    end

    local filename = (ExtendedVehicleMaintenance.MOD_DIR or "") .. "icons/" .. tostring(iconName) .. ".dds"
    local overlay = false

    if Overlay ~= nil and Overlay.new ~= nil then
        local ok, obj = pcall(Overlay.new, filename, 0, 0, 0, 0)
        if ok and obj ~= nil then
            overlay = obj
        end
    elseif createImageOverlay ~= nil then
        local ok, obj = pcall(createImageOverlay, filename)
        if ok and obj ~= nil and obj ~= 0 then
            overlay = obj
        end
    end

    ExtendedVehicleMaintenance._hudIconOverlays[iconName] = overlay
    return overlay
end

function ExtendedVehicleMaintenance.renderHudIconOverlay(iconName, x, y, w, h, r, g, b)
    local overlay = ExtendedVehicleMaintenance.getHudIconOverlay(iconName)
    if overlay == nil or overlay == false then return false end

    if type(overlay) == "table" then
        if overlay.setPosition ~= nil then pcall(overlay.setPosition, overlay, x, y) end
        if overlay.setDimension ~= nil then pcall(overlay.setDimension, overlay, w, h) end
        if overlay.setColor ~= nil then pcall(overlay.setColor, overlay, r or 1, g or 1, b or 1, 1) end
        if overlay.render ~= nil then
            local ok = pcall(overlay.render, overlay)
            return ok == true
        end
    elseif type(overlay) == "number" then
        if setOverlayColor ~= nil then pcall(setOverlayColor, overlay, r or 1, g or 1, b or 1, 1) end
        if renderOverlay ~= nil then
            local ok = pcall(renderOverlay, overlay, x, y, w, h)
            return ok == true
        end
    end

    return false
end

function ExtendedVehicleMaintenance.drawVehicleHUDIcon(x, y, w, h, r, g, b, label, textSize, iconName)
    -- Erst echte DDS-Icons rendern. Falls Overlay in der Engine/Map nicht verfuegbar ist, Text-Fallback.
    if iconName ~= nil and ExtendedVehicleMaintenance.renderHudIconOverlay(iconName, x, y, w, h, r, g, b) then
        return
    end

    if renderText ~= nil and setTextColor ~= nil then
        setTextColor(r, g, b, 1)
        if setTextBold ~= nil then setTextBold(true) end
        renderText(x + (w * 0.06), y + (h * 0.26), textSize or h * 0.45, tostring(label or ""))
        if setTextBold ~= nil then setTextBold(false) end
    end
end

function ExtendedVehicleMaintenance.drawVehicleHUD(vehicle, spec)
    if renderText == nil or drawFilledRect == nil or setTextColor == nil then return end
    local hud = ExtendedVehicleMaintenance.hudConfig
    if hud == nil or hud.enabled == false then return end
    local originalVehicle = vehicle
    vehicle = evmNormalizeVehicle(vehicle)
    if vehicle == nil then return end

    -- MP-Fix v9: Immer die Spec vom rootVehicle bevorzugen.
    local rootSpec = evmGetVehicleSpec(vehicle)
    if rootSpec ~= nil then
        spec = rootSpec
    elseif spec == nil then
        spec = evmGetVehicleSpec(originalVehicle)
    end
    if spec == nil then return end

    local sc = math.max(0.55, math.min(1.50, tonumber(hud.scale or 0.88) or 0.88))

    local TW     = 0.028 * sc
    local TH     = 0.042 * sc
    local GAP    = 0.002 * sc
    local BAR_H  = 0.0020 * sc
    local ICON_SZ  = 0.0105 * sc
    local FONT_VAL = 0.0078 * sc
    local FONT_LBL = 0.0044 * sc
    local totalW = TW * 3 + GAP * 2

    -- Direkt ueber dem Tacho, rechts ausgerichtet.
    -- Der Tacho-Oberkante liegt je nach Aufloesung bei ~0.46-0.50.
    -- posX/posY koennen in evm_config.xml fein justiert werden.
    local posX = math.max(0.05, math.min(0.995, tonumber(hud.posX or 0.993) or 0.993))
    local posY = math.max(0.05, math.min(0.950, tonumber(hud.posY or 0.512) or 0.512))   -- rechter/oberer HUD-Anker

    local baseX = posX - totalW
    local baseY = posY - TH
    ExtendedVehicleMaintenance._hudLastRect = { x=baseX, y=baseY, w=totalW, h=TH }
    ExtendedVehicleMaintenance.updateHudEditMode(baseX, baseY, totalW, TH)
    -- Nach dem Ziehen sofort mit der neuen Position rendern.
    posX = math.max(0.05, math.min(0.995, tonumber(hud.posX or posX) or posX))
    posY = math.max(0.05, math.min(0.950, tonumber(hud.posY or posY) or posY))
    baseX = posX - totalW
    baseY = posY - TH

    -- Farbe: identisch zum LS25 HUD-Hintergrund (fast schwarz, leicht transparent)
    -- Gleicher Ton wie Tacho-BG, Getriebe-Panel etc.
    local BG_R,BG_G,BG_B,BG_A = 0.07, 0.07, 0.06, 0.82

    local OK_R,OK_G,OK_B = 0.42, 0.85, 0.14
    local WN_R,WN_G,WN_B = 1.00, 0.65, 0.05
    local ER_R,ER_G,ER_B = 1.00, 0.14, 0.10
    local BL_R,BL_G,BL_B = 0.20, 0.58, 1.00
    local MT_R,MT_G,MT_B = 0.40, 0.42, 0.38

    local function setBold(v) if setTextBold ~= nil then pcall(setTextBold, v==true) end end
    local function resetText()
        setTextColor(1,1,1,1); setBold(false)
        if setTextAlignment ~= nil and RenderText ~= nil then
            pcall(setTextAlignment, RenderText.ALIGN_LEFT)
        end
    end
    local function ctrTxt(cx, cy, sz, t, r, g, b)
        if setTextAlignment ~= nil and RenderText ~= nil then
            pcall(setTextAlignment, RenderText.ALIGN_CENTER)
        end
        setTextColor(r, g, b, 1)
        renderText(cx, cy, sz, tostring(t or ""))
        if setTextAlignment ~= nil and RenderText ~= nil then
            pcall(setTextAlignment, RenderText.ALIGN_LEFT)
        end
    end

    local function drawTile(idx, iconName, valueStr, labelStr, vr, vg, vb)
        local sx = baseX + idx * (TW + GAP)
        local sy = baseY
        local cx = sx + TW * 0.5

        pcall(drawFilledRect, sx, sy, TW, TH, BG_R, BG_G, BG_B, BG_A)
        pcall(drawFilledRect, sx, sy, TW, BAR_H, vr, vg, vb, 0.95)

        local iconX = sx + (TW - ICON_SZ) * 0.5
        local iconY = sy + TH * 0.50
        ExtendedVehicleMaintenance.renderHudIconOverlay(iconName, iconX, iconY, ICON_SZ, ICON_SZ, vr, vg, vb)

        setBold(true)
        ctrTxt(cx, sy + TH * 0.25, FONT_VAL, valueStr, vr, vg, vb)
        setBold(false)
        ctrTxt(cx, sy + BAR_H + 0.002*sc, FONT_LBL, labelStr, MT_R, MT_G, MT_B)
    end

    local isDue,remH,remD = ExtendedVehicleMaintenance.isDue(vehicle)
    remH = tonumber(remH or 0) or 0
    remD = tonumber(remD or 0) or 0
    local activeSpec,_ = evmGetActiveServiceSpec(vehicle)
    local failureType  = tostring(spec.failureType or "")

    -- HUD liest die Spannung IMMER frisch berechnet aus dem aktuellen charge-Wert.
    -- spec.batteryVoltage kann durch Race-Conditions im MP veraltet sein, charge ist via
    -- onReadUpdateStream + EVMBatteryStateEvent immer aktuell.
    local batV = evmClamp(ExtendedVehicleMaintenance.getBatteryVoltage(vehicle, spec), 6.0, 15.5)

    -- HUD-Debug nur noch bei aktivem evmDebug, damit der Serverlog sauber bleibt.
    if ExtendedVehicleMaintenance.debug == true then
        ExtendedVehicleMaintenance._hudDebugTimer = (ExtendedVehicleMaintenance._hudDebugTimer or 0)
        local nowMs = (g_time or 0)
        if nowMs - ExtendedVehicleMaintenance._hudDebugTimer > 2000 then
            ExtendedVehicleMaintenance._hudDebugTimer = nowMs
            evmDbg("HUD READ vehicle=%s rootSame=%s spec.batteryVoltage=%.3f spec.batteryCharge=%.4f computedV=%.3f synced=%s",
                tostring(evmGetVehicleName(vehicle)),
                tostring(vehicle == (vehicle.rootVehicle or vehicle)),
                tonumber(spec.batteryVoltage or -1),
                tonumber(spec.batteryCharge or -1),
                tonumber(batV),
                tostring(spec._batteryClientSynced))
        end
    end

    local br,bg2,bb2 = OK_R,OK_G,OK_B
    if     batV < 11.5 then br,bg2,bb2 = ER_R,ER_G,ER_B
    elseif batV < 12.0 then br,bg2,bb2 = WN_R,WN_G,WN_B end

    local sr,sg2,sb2 = OK_R,OK_G,OK_B
    local svcVal = string.format("%.0fh", remH)
    if activeSpec ~= nil then
        local rh,rm = evmFormatHoursMinutes(evmGetServiceRemainingMs(activeSpec, vehicle))
        svcVal = string.format("%d:%02dh", rh, rm)
        sr,sg2,sb2 = BL_R,BL_G,BL_B
    elseif isDue then
        svcVal = "faellig"
        sr,sg2,sb2 = ER_R,ER_G,ER_B
    elseif remH <= 5 or remD <= 3 then
        sr,sg2,sb2 = WN_R,WN_G,WN_B
    end

    local er2,eg2,eb2 = OK_R,OK_G,OK_B
    local engVal = "OK"
    if     failureType == "engine"        then er2,eg2,eb2,engVal = ER_R,ER_G,ER_B,"Panne"
    elseif failureType == "rpmLimit"      then er2,eg2,eb2,engVal = WN_R,WN_G,WN_B,"Notlauf"
    elseif failureType == "flatTire"      then er2,eg2,eb2,engVal = WN_R,WN_G,WN_B,"Reifen"
    elseif failureType == "hydraulicLeak" then er2,eg2,eb2,engVal = WN_R,WN_G,WN_B,"Hydr."
    elseif failureType == "brakeFault"    then er2,eg2,eb2,engVal = ER_R,ER_G,ER_B,"Bremse"
    elseif failureType == "battery"       then br,bg2,bb2 = ER_R,ER_G,ER_B
    end

    -- v18: Schwere-Stufe der Panne als Suffix anzeigen.
    -- ▼ = minor (klein, evt. selbst behebbar) | leer = major (Standard) | ▲ = critical (nur Werkstatt)
    -- Bei Limp-Home wird ein "~" angehaengt um zu signalisieren dass die Wirkung halbiert ist.
    if failureType ~= "" and failureType ~= "battery" then
        local tier = ExtendedVehicleMaintenance.getSeverityTier(spec.failureSeverity or 0)
        if tier == ExtendedVehicleMaintenance.SEVERITY_TIER_MINOR then
            engVal = engVal .. " ▼"
            -- Minor sind weniger dramatisch -> nicht ER, sondern WN-Farbe wenn vorher ER war
            if er2 == ER_R then er2,eg2,eb2 = WN_R,WN_G,WN_B end
        elseif tier == ExtendedVehicleMaintenance.SEVERITY_TIER_CRITICAL then
            engVal = engVal .. " ▲"
            er2,eg2,eb2 = ER_R,ER_G,ER_B
        end
        if spec.limpHomeUntil ~= nil and (g_time or 0) < (spec.limpHomeUntil or 0) then
            engVal = engVal .. "~"
        end
    end

    drawTile(0, "battery", string.format("%.1fV", batV), "Batterie", br,  bg2, bb2)
    drawTile(1, "service", svcVal,                          "Service",  sr,  sg2, sb2)
    drawTile(2, "engine",  engVal,                          "Motor",    er2, eg2, eb2)

    if ExtendedVehicleMaintenance.hudEditMode == true then
        pcall(drawFilledRect, baseX, baseY + TH - (0.0015 * sc), totalW, 0.0015 * sc, 0.25, 0.9, 0.1, 0.95)
        pcall(drawFilledRect, baseX, baseY, totalW, 0.0015 * sc, 0.25, 0.9, 0.1, 0.95)
        pcall(drawFilledRect, baseX, baseY, 0.0015 * sc, TH, 0.25, 0.9, 0.1, 0.95)
        pcall(drawFilledRect, baseX + totalW - (0.0015 * sc), baseY, 0.0015 * sc, TH, 0.25, 0.9, 0.1, 0.95)
        ctrTxt(baseX + totalW * 0.5, baseY - (0.010 * sc), 0.0065 * sc, "EVM HUD EDIT", 0.25, 0.9, 0.1)
    end

    resetText()
end


function ExtendedVehicleMaintenance:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = evmGetVehicleSpec(self)
    if spec == nil or not self.isClient then return end

    local mission = g_currentMission
    if mission == nil then return end
    local hud = ExtendedVehicleMaintenance.hudConfig
    local onlyEntered = hud.onlyWhenEntered

    -- Prüfen ob wir das kontrollierte / eingestiegene Fahrzeug sind
    local controlled = mission.controlledVehicle
    local isControlled = (controlled == self or controlled == (self.rootVehicle or self))
    local isEntered = (self.getIsEntered ~= nil and self:getIsEntered())

    -- Runtime-Spec-Fallback kann ueber rootVehicle laufen; getIsEntered() ist dort nicht immer verlaesslich.
    -- Darum zaehlt das aktuell kontrollierte Fahrzeug ebenfalls als "eingestiegen".
    if onlyEntered and not (isEntered or isControlled) then return end
    if not isControlled and not isEntered then return end

    -- HUD zeichnen (ersetzt die alten BlinkingWarnings für Daueranzeige)
    if hud.enabled then
        ExtendedVehicleMaintenance.drawVehicleHUD(self, nil)
    end
end

function ExtendedVehicleMaintenance.installWorkshopPatches()
    if ExtendedVehicleMaintenance.workshopPatchesInstalled then
        return
    end
    ExtendedVehicleMaintenance.workshopPatchesInstalled = true
end

function ExtendedVehicleMaintenance.injectRuntimeSpecsForLoadedVehicles()
    -- FS25 1.18 lädt VehicleTypes bereits vor extraSourceFiles. Dadurch ist der Type-Patch
    -- im Log zwar sichtbar, erzeugt bei vorhandenen Savegame-Fahrzeugen aber keine spec_*-Tabelle.
    -- Dieser Fallback repariert nur fehlende EVM-Spec-Tabellen auf geladenen Fahrzeugen.
    -- Er überschreibt keine echte Spezialisierung und läuft auch für später gekaufte Fahrzeuge nach.
    local missing = 0
    local created = 0

    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = evmNormalizeVehicle(vehicle)
        if root ~= nil and root.rootNode ~= nil and evmGetVehicleSpec(root) == nil then
            missing = missing + 1

            local spec = evmCreateRuntimeSpec(root)
            if spec ~= nil then
                created = created + 1

                local ok, err = pcall(function()
                    ExtendedVehicleMaintenance.onLoad(root, nil)
                end)
                if not ok then
                    print(string.format("[EVM] Runtime-Spec onLoad fehlgeschlagen fuer '%s': %s", tostring(evmGetVehicleName(root)), tostring(err)))
                end
            end
        elseif root ~= nil and root.rootNode ~= nil then
            -- Spec existiert bereits: falls isServiceActive=true, Lock neu einrichten
            -- (wichtig fuer MP-Clients die per onReadStream den State empfangen haben
            --  und danach durch den Scan-Timer nicht zurueckgesetzt werden sollen)
            local existingSpec = evmGetVehicleSpec(root)
            if existingSpec ~= nil and existingSpec.isServiceActive == true then
                if root._evmHardLockActive ~= true then
                    ExtendedVehicleMaintenance.installEnterLock(root, existingSpec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
                    ExtendedVehicleMaintenance.installHardVehicleLock(root)
                    ExtendedVehicleMaintenance.installGlobalInputLocks()
                end
            end
        end
    end

    if missing > 0 or created > 0 then
        print(string.format("[EVM] Runtime-Spec-Reparatur: missing=%d created=%d mode=runtimeRepairFallback", missing, created))
    end

    return created
end

function ExtendedVehicleMaintenance:update(dt)
    if not ExtendedVehicleMaintenance._runtimeSpecsInjected then
        ExtendedVehicleMaintenance._runtimeSpecsInjected = true
        ExtendedVehicleMaintenance._runtimeSpecScanTimer = 0
        ExtendedVehicleMaintenance.injectRuntimeSpecsForLoadedVehicles()
        -- MP-FIX: Direkt nach dem ersten Spec-Inject die eigene State-XML einlesen.
        -- Das ueberschreibt die DEFAULT-Werte mit den tatsaechlich gespeicherten Werten.
        -- Nur Server tut das, Clients bekommen ihren State per Stream.
        if g_server ~= nil then
            local ok, err = pcall(ExtendedVehicleMaintenance.evmLoadAllVehicleStates)
            if not ok then
                print(string.format("[EVM] evmLoadAllVehicleStates fehlgeschlagen: %s", tostring(err)))
            end
        end
    end

    ExtendedVehicleMaintenance._runtimeSpecScanTimer = (ExtendedVehicleMaintenance._runtimeSpecScanTimer or 0) - (dt or 0)
    if ExtendedVehicleMaintenance._runtimeSpecScanTimer <= 0 then
        ExtendedVehicleMaintenance._runtimeSpecScanTimer = 2000
        local createdNow = ExtendedVehicleMaintenance.injectRuntimeSpecsForLoadedVehicles()
        -- Falls neue Fahrzeuge dazugekommen sind (z.B. spaet geladen oder neu gekauft),
        -- versuche, deren State aus der XML zu restaurieren.
        if g_server ~= nil and createdNow ~= nil and createdNow > 0 then
            pcall(ExtendedVehicleMaintenance.evmLoadAllVehicleStates)
        end
    end

    ExtendedVehicleMaintenance._activeServiceGlobalTimer = (ExtendedVehicleMaintenance._activeServiceGlobalTimer or 0) - (dt or 0)
    if ExtendedVehicleMaintenance._activeServiceGlobalTimer <= 0 then
        ExtendedVehicleMaintenance._activeServiceGlobalTimer = 2000
        if ExtendedVehicleMaintenance.evmUpdateLoadedServices ~= nil then
            pcall(ExtendedVehicleMaintenance.evmUpdateLoadedServices, dt)
        end
    end

    local mission = g_currentMission

    if mission == nil or g_inputBinding == nil then
        return
    end

    -- SP/Runtime-Fallback: Kollisionsschaden auch dann prüfen, wenn die Fahrzeug-Spezialisierung
    -- bei einem Fahrzeugtyp kein onUpdateTick feuert. Im SP ist mission.controlledVehicle je nach
    -- Situation nil, obwohl der Spieler im Fahrzeug sitzt. Deshalb nutzen wir zuerst g_localPlayer.
    local collisionVehicle = evmGetCurrentLocalVehicle()
    if collisionVehicle ~= nil then
        ExtendedVehicleMaintenance.processCollisionDamage(collisionVehicle, dt, "globalUpdate")
        local failureSpec = evmGetVehicleSpec(collisionVehicle.rootVehicle or collisionVehicle)
        if failureSpec ~= nil and failureSpec.failureType ~= nil and failureSpec.failureType ~= "" then
            ExtendedVehicleMaintenance.updateActiveFailure(collisionVehicle.rootVehicle or collisionVehicle, failureSpec, dt, false)
        end
    elseif ExtendedVehicleMaintenance.COLLISION_DEBUG == true or ExtendedVehicleMaintenance.debug == true then
        ExtendedVehicleMaintenance._collisionNoVehicleTimer = (ExtendedVehicleMaintenance._collisionNoVehicleTimer or 0) - (dt or 0)
        if ExtendedVehicleMaintenance._collisionNoVehicleTimer <= 0 then
            ExtendedVehicleMaintenance._collisionNoVehicleTimer = 3000
            local cv = mission.controlledVehicle or mission.currentVehicle
            local playerVehicle = nil
            if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
                local okPv, pv = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
                if okPv then playerVehicle = pv end
            end
            print(string.format("[EVM] CollisionDebug globalUpdate: kein lokales Fahrzeug gefunden controlled=%s current=%s playerVehicle=%s", tostring(evmGetVehicleName(cv)), tostring(evmGetVehicleName(mission.currentVehicle)), tostring(evmGetVehicleName(playerVehicle))))
        end
    end

    -- Batterie global simulieren: auch geparkte / nicht ausgewählte Fahrzeuge müssen entladen/laden können.
    if g_server ~= nil and evmProcessBattery ~= nil then
        ExtendedVehicleMaintenance._batteryGlobalTimer = (ExtendedVehicleMaintenance._batteryGlobalTimer or 0) - (dt or 0)
        if ExtendedVehicleMaintenance._batteryGlobalTimer <= 0 then
            local stepDt = 1000 - ExtendedVehicleMaintenance._batteryGlobalTimer
            ExtendedVehicleMaintenance._batteryGlobalTimer = 1000
            local seen = {}
            for _, v in ipairs(evmCollectMissionVehicles()) do
                local root = evmNormalizeVehicle(v)
                if root ~= nil and root.rootNode ~= nil and seen[root] ~= true then
                    seen[root] = true
                    local bSpec = evmGetVehicleSpec(root)
                    if bSpec ~= nil then
                        evmProcessBattery(root, bSpec, stepDt, "global")
                    end
                end
            end
        end
    end

    -- MP/Dedi-Fix: Zufalls-Pannen global und serverseitig prüfen.
    -- onUpdateTick ist im Multiplayer nicht zuverlässig genug, weil es je nach Fahrzeug/Owner/Selektion
    -- nicht dauerhaft für alle Fahrzeuge läuft. Testbefehle funktionierten, aber natürliche Pannen kamen nie.
    if g_server ~= nil then
        ExtendedVehicleMaintenance._breakdownGlobalTimer = (ExtendedVehicleMaintenance._breakdownGlobalTimer or 0) - (dt or 0)
        if ExtendedVehicleMaintenance._breakdownGlobalTimer <= 0 then
            local interval = ExtendedVehicleMaintenance.BREAKDOWN_GLOBAL_UPDATE_INTERVAL or 1000
            local stepDt = interval - ExtendedVehicleMaintenance._breakdownGlobalTimer
            ExtendedVehicleMaintenance._breakdownGlobalTimer = interval
            local seen = {}
            for _, v in ipairs(evmCollectMissionVehicles()) do
                local root = evmNormalizeVehicle(v)
                if root ~= nil and root.rootNode ~= nil and seen[root] ~= true then
                    seen[root] = true
                    local rSpec = evmGetVehicleSpec(root)
                    if rSpec ~= nil then
                        ExtendedVehicleMaintenance.updateBreakdownRisk(root, rSpec, stepDt, "global")
                        -- v18: Limp-Home Ablauf pruefen damit Severity zurueckkommt
                        if ExtendedVehicleMaintenance.updateLimpHomeExpiry ~= nil then
                            ExtendedVehicleMaintenance.updateLimpHomeExpiry(root, rSpec)
                        end
                    end
                end
            end
        end
    end

    ExtendedVehicleMaintenance.globalWorkshopActionTimer = (ExtendedVehicleMaintenance.globalWorkshopActionTimer or 0) - dt
    if ExtendedVehicleMaintenance.globalWorkshopActionTimer > 0 then
        return
    end
    ExtendedVehicleMaintenance.globalWorkshopActionTimer = ExtendedVehicleMaintenance.GLOBAL_ACTION_UPDATE_INTERVAL

    -- Charge-Action soll immer verfügbar sein (auch ohne Werkstatt in der Nähe).
    ExtendedVehicleMaintenance.ensureChargeActionRegistered()
    ExtendedVehicleMaintenance.refreshGlobalChargeAction()

    if mission.controlledVehicle ~= nil then
        -- Auch wenn man in einem Fahrzeug sitzt: prüfen ob angehängte Geräte wartbar sind.
        -- In diesem Fall den globalen Event trotzdem anbieten (Traktor+Gerät gemeinsam servicieren).
        local controlled = mission.controlledVehicle.rootVehicle or mission.controlledVehicle
        local hasImplements = false
        if controlled.getAttachedImplements ~= nil then
            local ok, implements = pcall(controlled.getAttachedImplements, controlled)
            if ok and type(implements) == "table" and #implements > 0 then
                for _, impl in pairs(implements) do
                    if impl ~= nil and impl.object ~= nil and ExtendedVehicleMaintenance.isServiceable(impl.object) then
                        hasImplements = true
                        break
                    end
                end
            end
        end
        if not hasImplements then
            ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
            return
        end
        -- Hat Geräte → weiter mit normalem Flow (sellingPoint = controlledVehicle)
    end

    if g_gui ~= nil and g_gui.currentGui ~= nil then
        ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
        return
    end

    local playerNode = ExtendedVehicleMaintenance.getPlayerRootNode()
    if not evmIsValidNode(playerNode) then
        ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
        return
    end

    local sellingPoint = ExtendedVehicleMaintenance.findNearbySellingPoint()
    if sellingPoint == nil then
        ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
        return
    end

    if ExtendedVehicleMaintenance.isVehicleInServiceOrPending(sellingPoint) then
        ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
        return
    end

    ExtendedVehicleMaintenance.registerGlobalWorkshopAction()
    ExtendedVehicleMaintenance.refreshGlobalWorkshopAction(sellingPoint)
end

function ExtendedVehicleMaintenance:loadMap(name)
    if ExtendedVehicleMaintenance.debug == true or ExtendedVehicleMaintenance.COLLISION_DEBUG == true then
        print(string.format("[EVM] loadMap active - collisionDamage debug=%s minSpeed=%.1f km/h", tostring(ExtendedVehicleMaintenance.COLLISION_DEBUG), ExtendedVehicleMaintenance.COLLISION_MIN_SPEED_KMH or 5.0))
    end
    ExtendedVehicleMaintenance.loadConfig()
    ExtendedVehicleMaintenance.registerGlobalSavegameXMLPaths()
    if not ExtendedVehicleMaintenance._vehicleTypesPatched then
        ExtendedVehicleMaintenance.addSpecializationToVehicleTypes()
    end
    ExtendedVehicleMaintenance.installWorkshopPatches()
    evmRegisterConsoleCommands()
    ExtendedVehicleMaintenance._runtimeSpecsInjected = false

    if not ExtendedVehicleMaintenance.dialogRegistered and EVMServiceDialog ~= nil and EVMServiceDialog.register ~= nil then
        ExtendedVehicleMaintenance.dialogRegistered = EVMServiceDialog.register(ExtendedVehicleMaintenance.MOD_DIR)
        evmDbg("dialog registered=%s", tostring(ExtendedVehicleMaintenance.dialogRegistered))
    end
end

function ExtendedVehicleMaintenance:deleteMap()
    ExtendedVehicleMaintenance.dialogRegistered = false
    ExtendedVehicleMaintenance.removeGlobalWorkshopAction()
    evmRemoveConsoleCommands()

    for vehicle, _ in pairs(ExtendedVehicleMaintenance._hardLockVehicles) do
        ExtendedVehicleMaintenance.removeHardVehicleLock(vehicle)
    end

    local runtime = ExtendedVehicleMaintenance.spec_serviceRuntime
    if runtime ~= nil then
        runtime.enterLocks = {}
        runtime._serviceWatchers = {}
        runtime.active = false
        runtime.mode = 0
        runtime.rootVehicle = nil
        runtime.targets = {}
        runtime.totalCost = 0
        runtime.totalDurationMs = 0
        runtime.startTime = 0
        runtime.endTime = 0
    end

    ExtendedVehicleMaintenance.restoreRuntimeHooks()
end

-- ============================================================================
-- MP-FIX: Eigene State-Persistenz fuer alle EVM-Fahrzeuge
-- ============================================================================
-- Hintergrund: FS25 1.18 laedt VehicleTypes vor extraSourceFiles, sodass die
-- EVM-Spezialisierung bei Fahrzeugen, die zum Savegame-Load-Zeitpunkt schon
-- existieren, NICHT ueber die normale Spec-Pipeline aktiv wird. Folge:
--   1) saveToXMLFile wird vom Spiel fuer diese Fahrzeuge nicht aufgerufen
--   2) onLoad wird nur durch unseren Runtime-Repair mit savegame=nil getriggert
-- -> Service-Zeiten gehen beim MP-Neustart verloren (immer zurueck auf Default).
--
-- Loesung: Wir fuehren eine eigene XML-Datei (evm_vehicleStates.xml) im
-- Savegame-Ordner, in der wir den State aller Fahrzeuge unter einer stabilen
-- ID (configFileName + savegameId/uniqueId) selbst persistieren.
-- Diese XML wird beim Speichern UND zyklisch geschrieben und beim Laden
-- direkt nach injectRuntimeSpecsForLoadedVehicles eingelesen.
-- ============================================================================

local function evmGetVehicleStatesFileName()
    return evmGetPersistDir() .. "/evm_vehicleStates.xml"
end

-- Eindeutiger Key pro Fahrzeug: bevorzugt savegameId, sonst Kombi aus
-- configFileName + ownerFarmId + spawnIndex.
local function evmGetVehicleStateKey(vehicle)
    if vehicle == nil then return nil end
    local v = vehicle.rootVehicle or vehicle

    -- 1) FS25 Savegame-ID (stabilste Variante)
    local sid = nil
    if v.getCurrentSavegameId ~= nil then
        local ok, id = pcall(v.getCurrentSavegameId, v)
        if ok and id ~= nil then sid = tonumber(id) end
    end
    if sid == nil then
        sid = tonumber(v.currentSavegameId) or tonumber(v.savegameId)
    end
    if sid ~= nil and sid > 0 then
        return string.format("sid_%d", sid)
    end

    -- 2) Fallback: configFileName + ownerFarmId + xmlFileName-Hash
    local cfg = tostring(v.configFileName or "")
    local xml = tostring(v.xmlFileName or "")
    local farm = evmGetOwnerFarmIdSafe(v)
    if cfg == "" and xml == "" then return nil end
    -- Sehr einfacher String-Hash (sum modulo) - reicht zur Trennung
    local h = 0
    local combined = cfg .. "|" .. xml
    for i = 1, #combined do h = (h * 31 + string.byte(combined, i)) % 2147483647 end
    return string.format("cfg_%d_%d", farm, h)
end


-- MP/SP Neustart-Fix: aktive Wartungen nach Savegame-Reload wieder in die
-- Runtime/Locks aufnehmen und serverseitig fertigstellen, auch wenn das Fahrzeug
-- nur ueber die Runtime-Spec-Reparatur existiert und kein normales onUpdateTick feuert.
function ExtendedVehicleMaintenance.evmRestoreActiveServiceRuntime(rootVehicle, spec, source)
    if rootVehicle == nil or spec == nil or spec.isServiceActive ~= true then
        return false
    end

    rootVehicle = rootVehicle.rootVehicle or rootVehicle

    local remaining = 0
    if evmGetServiceRemainingMs ~= nil then
        remaining = evmGetServiceRemainingMs(spec, rootVehicle)
    else
        remaining = math.max(0, tonumber(spec.serviceRemainingGameMs or 0) or 0)
    end

    if remaining <= 0 then
        if ExtendedVehicleMaintenance.finishService ~= nil then
            print(string.format("[EVM] restored service already finished vehicle=%s source=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(source or "unknown")))
            ExtendedVehicleMaintenance.finishService(rootVehicle)
        end
        return true
    end

    spec.isServiceActive = true
    spec.serviceMode = tonumber(spec.serviceMode) or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP
    spec.serviceRemainingGameMs = remaining
    if (tonumber(spec.serviceEndAbsHours or 0) or 0) <= 0 then
        spec.serviceEndAbsHours = ExtendedVehicleMaintenance.getCurrentAbsHours() + (remaining / 3600000)
    end
    spec.physicsFrozen = true
    spec.lastTickGameTimeMs = ExtendedVehicleMaintenance.getCurrentGameTimeMs()

    ExtendedVehicleMaintenance.installEnterLock(rootVehicle, spec.serviceMode)
    ExtendedVehicleMaintenance.installHardVehicleLock(rootVehicle)
    ExtendedVehicleMaintenance.installGlobalInputLocks()

    local runtime = ExtendedVehicleMaintenance.getRuntime()
    -- Die Runtime ist historisch single-service. Beim Reload setzen wir sie auf
    -- das erste aktive Fahrzeug, damit alte Codepfade/Broadcasts weiter funktionieren.
    if runtime.active ~= true or runtime.rootVehicle == nil or runtime.rootVehicle == rootVehicle then
        runtime.active = true
        runtime.mode = spec.serviceMode
        runtime.rootVehicle = rootVehicle
        runtime.targets = { rootVehicle }
        runtime.totalDurationMs = remaining
        runtime.startTime = g_time or 0
        runtime.endTime = (g_time or 0) + remaining
        runtime.pendingOldRootNode = rootVehicle.rootNode
        runtime.pendingLockData = evmBuildPersistRuntimeData(rootVehicle, spec.serviceMode, remaining, spec.serviceHoursToAdd or 0, spec.serviceDaysToAdd or 0)
        if runtime.pendingLockData ~= nil then
            runtime.pendingLockData.serviceEndAbsHours = spec.serviceEndAbsHours or 0
            runtime.pendingLockData.serviceRemainingGameMs = remaining
        end
        runtime._persistLockResolved = true
    end

    if rootVehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        pcall(rootVehicle.raiseDirtyFlags, rootVehicle, spec.dirtyFlag)
    end
    if ExtendedVehicleMaintenance.broadcastServiceState ~= nil then
        ExtendedVehicleMaintenance.broadcastServiceState(rootVehicle, true)
    end

    print(string.format("[EVM] restored active service vehicle=%s remainingMs=%s source=%s", tostring(evmGetVehicleName(rootVehicle)), tostring(math.floor(remaining)), tostring(source or "unknown")))
    return true
end

function ExtendedVehicleMaintenance.evmUpdateLoadedServices(dt)
    if g_server == nil then
        return
    end

    local activeCount = 0
    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = evmNormalizeVehicle(vehicle) or vehicle
        if root ~= nil then
            local spec = evmGetVehicleSpec(root)
            if spec ~= nil and spec.isServiceActive == true then
                activeCount = activeCount + 1
                local remaining = evmGetServiceRemainingMs(spec, root)
                if remaining <= 0 then
                    ExtendedVehicleMaintenance.finishService(root)
                else
                    spec.physicsFrozen = true
                    ExtendedVehicleMaintenance.installEnterLock(root, spec.serviceMode or ExtendedVehicleMaintenance.SERVICE_MODE_WORKSHOP)
                    ExtendedVehicleMaintenance.installHardVehicleLock(root)
                    if root.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                        pcall(root.raiseDirtyFlags, root, spec.dirtyFlag)
                    end
                end
            end
        end
    end

    if activeCount > 0 then
        ExtendedVehicleMaintenance._lastActiveServiceBroadcastMs = ExtendedVehicleMaintenance._lastActiveServiceBroadcastMs or 0
        if (g_time or 0) - ExtendedVehicleMaintenance._lastActiveServiceBroadcastMs > 10000 then
            ExtendedVehicleMaintenance._lastActiveServiceBroadcastMs = g_time or 0
            for _, vehicle in ipairs(evmCollectMissionVehicles()) do
                local root = evmNormalizeVehicle(vehicle) or vehicle
                local spec = root ~= nil and evmGetVehicleSpec(root) or nil
                if spec ~= nil and spec.isServiceActive == true then
                    ExtendedVehicleMaintenance.broadcastServiceState(root, true)
                end
            end
        end

        -- Dedizierte Server werden oft hart neu gestartet. Darum bei laufender
        -- Wartung zyklisch die eigene EVM-State-Datei aktualisieren, nicht nur beim Save-Hook.
        ExtendedVehicleMaintenance._lastVehicleStateAutoSaveMs = ExtendedVehicleMaintenance._lastVehicleStateAutoSaveMs or 0
        if (g_time or 0) - ExtendedVehicleMaintenance._lastVehicleStateAutoSaveMs > 30000 then
            ExtendedVehicleMaintenance._lastVehicleStateAutoSaveMs = g_time or 0
            if ExtendedVehicleMaintenance.evmSaveAllVehicleStates ~= nil then
                pcall(ExtendedVehicleMaintenance.evmSaveAllVehicleStates)
            end
        end
    end
end

function ExtendedVehicleMaintenance.evmSaveAllVehicleStates()
    -- Nur Server/Host speichert. Clients duerfen das nicht, sonst wird der
    -- State eines Clients in den Server-Ordner geschrieben (gibt es im MP ohnehin nicht,
    -- aber im SP-Mode wo isServer immer true ist, ist es egal).
    if g_server == nil and g_currentMission ~= nil and g_currentMission.getIsServer ~= nil then
        local ok, isS = pcall(g_currentMission.getIsServer, g_currentMission)
        if ok and not isS then return false end
    end

    if createXMLFile == nil or saveXMLFile == nil then return false end
    local fileName = evmGetVehicleStatesFileName()
    local xmlId = createXMLFile("evmVehicleStates", fileName, "evmVehicleStates")
    if xmlId == nil or xmlId == 0 then
        print(string.format("[EVM] evmSaveAllVehicleStates: createXMLFile failed: %s", tostring(fileName)))
        return false
    end

    local idx = 0
    local saved = 0
    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = evmNormalizeVehicle(vehicle) or vehicle
        if root ~= nil then
            local spec = evmGetVehicleSpec(root)
            local key = evmGetVehicleStateKey(root)
            if spec ~= nil and key ~= nil then
                local base = string.format("evmVehicleStates.vehicle(%d)", idx)
                setXMLString(xmlId, base .. "#key", key)
                setXMLString(xmlId, base .. "#configFileName", tostring(root.configFileName or ""))
                setXMLString(xmlId, base .. "#xmlFileName", tostring(root.xmlFileName or ""))
                setXMLString(xmlId, base .. "#typeName", tostring(root.typeName or ""))
                setXMLInt(xmlId, base .. "#ownerFarmId", evmGetOwnerFarmIdSafe(root))
                setXMLFloat(xmlId, base .. "#hoursPool", tonumber(spec.hoursPool) or ExtendedVehicleMaintenance.DEFAULT_HOURS)
                setXMLFloat(xmlId, base .. "#daysPool", tonumber(spec.daysPool) or ExtendedVehicleMaintenance.DEFAULT_DAYS)
                setXMLFloat(xmlId, base .. "#lastServiceOperatingTimeMs", tonumber(spec.lastServiceOperatingTimeMs) or 0)
                setXMLFloat(xmlId, base .. "#lastServiceGameTimeMs", tonumber(spec.lastServiceGameTimeMs) or 0)
                local remainingForSave = tonumber(spec.serviceRemainingGameMs) or 0
                if spec.isServiceActive == true and evmGetServiceRemainingMs ~= nil then
                    remainingForSave = evmGetServiceRemainingMs(spec, root)
                end
                setXMLFloat(xmlId, base .. "#serviceRemainingGameMs", tonumber(remainingForSave) or 0)
                setXMLFloat(xmlId, base .. "#serviceEndAbsHours", tonumber(spec.serviceEndAbsHours) or 0)
                setXMLFloat(xmlId, base .. "#serviceHoursToAdd", tonumber(spec.serviceHoursToAdd) or 0)
                setXMLFloat(xmlId, base .. "#serviceDaysToAdd", tonumber(spec.serviceDaysToAdd) or 0)
                setXMLInt(xmlId, base .. "#serviceMode", tonumber(spec.serviceMode) or 0)
                setXMLBool(xmlId, base .. "#isServiceActive", spec.isServiceActive == true)
                setXMLString(xmlId, base .. "#failureType", tostring(spec.failureType or ""))
                setXMLFloat(xmlId, base .. "#failureSeverity", tonumber(spec.failureSeverity) or 0)
                setXMLInt(xmlId, base .. "#failureWheelIndex", tonumber(spec.failureWheelIndex) or 0)
                setXMLInt(xmlId, base .. "#failureDriftDirection", tonumber(spec.failureDriftDirection) or 0)
                setXMLFloat(xmlId, base .. "#batteryCharge", tonumber(spec.batteryCharge) or 1.0)
                setXMLFloat(xmlId, base .. "#batteryVoltage", tonumber(spec.batteryVoltage) or 12.7)
                setXMLFloat(xmlId, base .. "#operatingTimeMs", evmGetOperatingTimeMs(root) or 0)
                idx = idx + 1
                saved = saved + 1
            end
        end
    end

    local okSave = pcall(function()
        saveXMLFile(xmlId)
        delete(xmlId)
    end)

    print(string.format("[EVM] evmSaveAllVehicleStates: saved=%d ok=%s file=%s", saved, tostring(okSave), tostring(fileName)))
    return okSave == true
end

function ExtendedVehicleMaintenance.evmLoadAllVehicleStates()
    if loadXMLFile == nil then return 0 end
    local fileName = evmGetVehicleStatesFileName()
    if fileExists ~= nil and not fileExists(fileName) then
        evmDbg("evmLoadAllVehicleStates: kein File vorhanden (%s)", tostring(fileName))
        return 0
    end
    local xmlId = loadXMLFile("evmVehicleStates", fileName)
    if xmlId == nil or xmlId == 0 then return 0 end

    -- Erst alle Eintraege in eine Tabelle einlesen
    local entries = {}
    local idx = 0
    while true do
        local base = string.format("evmVehicleStates.vehicle(%d)", idx)
        local key = getXMLString(xmlId, base .. "#key")
        if key == nil then break end
        table.insert(entries, {
            key = key,
            configFileName = getXMLString(xmlId, base .. "#configFileName") or "",
            xmlFileName = getXMLString(xmlId, base .. "#xmlFileName") or "",
            typeName = getXMLString(xmlId, base .. "#typeName") or "",
            ownerFarmId = getXMLInt(xmlId, base .. "#ownerFarmId") or 0,
            hoursPool = getXMLFloat(xmlId, base .. "#hoursPool"),
            daysPool = getXMLFloat(xmlId, base .. "#daysPool"),
            lastServiceOperatingTimeMs = getXMLFloat(xmlId, base .. "#lastServiceOperatingTimeMs"),
            lastServiceGameTimeMs = getXMLFloat(xmlId, base .. "#lastServiceGameTimeMs"),
            serviceRemainingGameMs = getXMLFloat(xmlId, base .. "#serviceRemainingGameMs"),
            serviceEndAbsHours = getXMLFloat(xmlId, base .. "#serviceEndAbsHours"),
            serviceHoursToAdd = getXMLFloat(xmlId, base .. "#serviceHoursToAdd"),
            serviceDaysToAdd = getXMLFloat(xmlId, base .. "#serviceDaysToAdd"),
            serviceMode = getXMLInt(xmlId, base .. "#serviceMode"),
            isServiceActive = getXMLBool(xmlId, base .. "#isServiceActive"),
            failureType = getXMLString(xmlId, base .. "#failureType") or "",
            failureSeverity = getXMLFloat(xmlId, base .. "#failureSeverity"),
            failureWheelIndex = getXMLInt(xmlId, base .. "#failureWheelIndex"),
            failureDriftDirection = getXMLInt(xmlId, base .. "#failureDriftDirection"),
            batteryCharge = getXMLFloat(xmlId, base .. "#batteryCharge"),
            batteryVoltage = getXMLFloat(xmlId, base .. "#batteryVoltage"),
            operatingTimeMs = getXMLFloat(xmlId, base .. "#operatingTimeMs"),
        })
        idx = idx + 1
    end
    delete(xmlId)

    -- Index: key -> entry, configFileName -> entry (Fallback)
    local byKey = {}
    local byCfg = {}
    for _, e in ipairs(entries) do
        byKey[e.key] = e
        if e.configFileName ~= "" then
            byCfg[e.configFileName .. "|" .. tostring(e.ownerFarmId)] = e
        end
    end

    -- Auf alle Fahrzeuge anwenden
    local applied = 0
    for _, vehicle in ipairs(evmCollectMissionVehicles()) do
        local root = evmNormalizeVehicle(vehicle) or vehicle
        if root ~= nil then
            local spec = evmGetVehicleSpec(root)
            if spec == nil and evmCreateRuntimeSpec ~= nil then
                spec = evmCreateRuntimeSpec(root)
            end
            if spec ~= nil then
                local k = evmGetVehicleStateKey(root)
                local entry = (k ~= nil and byKey[k]) or nil
                if entry == nil then
                    -- Fallback: configFileName + farm
                    local cfg = tostring(root.configFileName or "")
                    local farm = evmGetOwnerFarmIdSafe(root)
                    entry = byCfg[cfg .. "|" .. tostring(farm)]
                end
                if entry ~= nil and not spec._evmStateRestored then
                    if entry.hoursPool ~= nil then spec.hoursPool = entry.hoursPool end
                    if entry.daysPool ~= nil then spec.daysPool = entry.daysPool end
                    if entry.lastServiceOperatingTimeMs ~= nil then spec.lastServiceOperatingTimeMs = entry.lastServiceOperatingTimeMs end
                    if entry.lastServiceGameTimeMs ~= nil then spec.lastServiceGameTimeMs = entry.lastServiceGameTimeMs end
                    if entry.serviceRemainingGameMs ~= nil then spec.serviceRemainingGameMs = entry.serviceRemainingGameMs end
                    if entry.serviceEndAbsHours ~= nil then spec.serviceEndAbsHours = entry.serviceEndAbsHours end
                    if entry.serviceHoursToAdd ~= nil then spec.serviceHoursToAdd = entry.serviceHoursToAdd end
                    if entry.serviceDaysToAdd ~= nil then spec.serviceDaysToAdd = entry.serviceDaysToAdd end
                    if entry.serviceMode ~= nil then spec.serviceMode = entry.serviceMode end
                    if entry.isServiceActive ~= nil then spec.isServiceActive = entry.isServiceActive end
                    if entry.failureType ~= nil then spec.failureType = entry.failureType end
                    if entry.failureSeverity ~= nil then spec.failureSeverity = entry.failureSeverity end
                    if entry.failureWheelIndex ~= nil then spec.failureWheelIndex = entry.failureWheelIndex end
                    if entry.failureDriftDirection ~= nil then spec.failureDriftDirection = entry.failureDriftDirection end
                    if entry.batteryCharge ~= nil then spec.batteryCharge = evmClamp(entry.batteryCharge, 0, 1) end
                    if entry.batteryVoltage ~= nil then spec.batteryVoltage = evmClamp(entry.batteryVoltage, 6.0, 15.5) end
                    evmMigrateMaintenanceIntervalToOperatingHours(spec, root, "evm_vehicleStates")
                    spec._evmStateRestored = true
                    applied = applied + 1
                    -- Dirty-Flag setzen damit der Client beim naechsten Stream den State bekommt
                    if root.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
                        pcall(root.raiseDirtyFlags, root, spec.dirtyFlag)
                    end
                    if spec.isServiceActive == true and ExtendedVehicleMaintenance.evmRestoreActiveServiceRuntime ~= nil then
                        ExtendedVehicleMaintenance.evmRestoreActiveServiceRuntime(root, spec, "evm_vehicleStates")
                    end
                end
            end
        end
    end

    print(string.format("[EVM] evmLoadAllVehicleStates: entries=%d applied=%d", #entries, applied))
    return applied
end

-- Save-Hook: FSBaseMission.saveSavegame -> nach Vanilla-Save auch eigene XML schreiben
if FSBaseMission ~= nil and FSBaseMission.saveSavegame ~= nil and not ExtendedVehicleMaintenance._saveHookInstalled then
    ExtendedVehicleMaintenance._saveHookInstalled = true
    local _evmOrigSaveSavegame = FSBaseMission.saveSavegame
    FSBaseMission.saveSavegame = function(self, ...)
        local result = _evmOrigSaveSavegame(self, ...)
        local ok, err = pcall(ExtendedVehicleMaintenance.evmSaveAllVehicleStates)
        if not ok then
            print(string.format("[EVM] evmSaveAllVehicleStates fehlgeschlagen: %s", tostring(err)))
        end
        return result
    end
    print("[EVM] Save-Hook auf FSBaseMission.saveSavegame installiert")
end

-- Auto-Save Hook: Manche Server schreiben ueber andere Pfade. Wir hooken
-- zusaetzlich auf MissionInfo.saveToXMLFile, damit auch Auto-Saves erfasst werden.
if g_savegameXML == nil then  -- nur einmal
    -- nichts zu tun, der FSBaseMission-Hook reicht in den meisten Faellen
end

local evmOldTypeManagerFinalizeTypes = TypeManager.finalizeTypes

function TypeManager:finalizeTypes(typeName, types, specializations, vehicleSpecializations, ...)
    if self == g_vehicleTypeManager then
        ExtendedVehicleMaintenance.addSpecializationToVehicleTypes(types)
    end

    local result = nil
    if evmOldTypeManagerFinalizeTypes ~= nil then
        result = evmOldTypeManagerFinalizeTypes(self, typeName, types, specializations, vehicleSpecializations, ...)
    end

    return result
end


function ExtendedVehicleMaintenance.drawFromMissionHook(mission)
    -- 3D/World marker deaktiviert: keine Mission-draw-Hooks mehr notwendig.
end

ExtendedVehicleMaintenance._initialized = true
addModEventListener(ExtendedVehicleMaintenance)
