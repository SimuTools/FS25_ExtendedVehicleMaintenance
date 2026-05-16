EVMStartServiceEvent = {}
local EVMStartServiceEvent_mt = Class(EVMStartServiceEvent, Event)
InitEventClass(EVMStartServiceEvent, "EVMStartServiceEvent")

function EVMStartServiceEvent.emptyNew()
    local self = Event.new(EVMStartServiceEvent_mt)
    return self
end

function EVMStartServiceEvent.new(vehicle, serviceMode)
    local self = EVMStartServiceEvent.emptyNew()
    self.vehicle = vehicle
    self.serviceMode = serviceMode or 1
    return self
end

function EVMStartServiceEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.serviceMode = streamReadUInt8(streamId)
    self:run(connection)
end

function EVMStartServiceEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUInt8(streamId, self.serviceMode or 1)
end

function EVMStartServiceEvent:run(connection)
    if self.vehicle == nil or not self.vehicle:getIsSynchronized() then
        return
    end

    local rootVehicle = self.vehicle.rootVehicle or self.vehicle
    local serviceMode = self.serviceMode or 1

    if ExtendedVehicleMaintenance == nil then
        return
    end

    local plan = ExtendedVehicleMaintenance.buildServicePlan(rootVehicle, serviceMode)
    if plan == nil or plan.entries == nil or #plan.entries == 0 then
        print(string.format("[EVM] EVMStartServiceEvent: no valid service plan for vehicle=%s mode=%s", tostring(rootVehicle), tostring(serviceMode)))
        return
    end

    local targets = {}
    for i = 1, #plan.entries do
        local entry = plan.entries[i]
        if entry ~= nil and entry.vehicle ~= nil then
            table.insert(targets, entry.vehicle)
        end
    end

    ExtendedVehicleMaintenance:tryStartService(
        rootVehicle,
        targets,
        serviceMode,
        plan.totalCost or 0,
        plan.durationGameMs or 0
    )
end

function EVMStartServiceEvent.sendEvent(vehicle, serviceMode)
    if vehicle == nil or ExtendedVehicleMaintenance == nil then
        return
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local mode = serviceMode or 1

    if g_server ~= nil then
        -- Auf dem Listen-Host (g_server + g_client): Lock sofort lokal
        -- setzen bevor tryStartService den Workshop-Reset macht.
        -- Verhindert das Race-Fenster zwischen Dialog-Bestaetigung und
        -- dem Moment wo enforceRuntimeState die Locks installiert.
        if g_client ~= nil then
            if ExtendedVehicleMaintenance.installEnterLock ~= nil then
                pcall(ExtendedVehicleMaintenance.installEnterLock, rootVehicle, mode)
            end
            if ExtendedVehicleMaintenance.installHardVehicleLock ~= nil then
                pcall(ExtendedVehicleMaintenance.installHardVehicleLock, rootVehicle)
            end
            if ExtendedVehicleMaintenance.installGlobalInputLocks ~= nil then
                pcall(ExtendedVehicleMaintenance.installGlobalInputLocks)
            end
        end

        local plan = ExtendedVehicleMaintenance.buildServicePlan(rootVehicle, mode)
        if plan == nil or plan.entries == nil or #plan.entries == 0 then
            print(string.format("[EVM] EVMStartServiceEvent.sendEvent: no valid service plan for vehicle=%s mode=%s", tostring(rootVehicle), tostring(mode)))
            return
        end

        local targets = {}
        for i = 1, #plan.entries do
            local entry = plan.entries[i]
            if entry ~= nil and entry.vehicle ~= nil then
                table.insert(targets, entry.vehicle)
            end
        end

        ExtendedVehicleMaintenance:tryStartService(
            rootVehicle,
            targets,
            mode,
            plan.totalCost or 0,
            plan.durationGameMs or 0
        )
    else
        -- MP-Fix: Lock SOFORT lokal auf dem Client installieren, noch bevor
        -- das Event den Server erreicht. Ohne das gibt es ein Race-Fenster
        -- (50-500ms) in dem der Spieler noch einsteigen kann.
        -- Der Server bestaetigt den Lock kurz danach via EVMServiceStateEvent.
        if ExtendedVehicleMaintenance.installEnterLock ~= nil then
            pcall(ExtendedVehicleMaintenance.installEnterLock, rootVehicle, mode)
        end
        if ExtendedVehicleMaintenance.installHardVehicleLock ~= nil then
            pcall(ExtendedVehicleMaintenance.installHardVehicleLock, rootVehicle)
        end
        if ExtendedVehicleMaintenance.installGlobalInputLocks ~= nil then
            pcall(ExtendedVehicleMaintenance.installGlobalInputLocks)
        end

        local connection = g_client ~= nil and g_client:getServerConnection() or nil
        if connection ~= nil then
            connection:sendEvent(EVMStartServiceEvent.new(rootVehicle, mode))
        end
    end
end
-- Server -> Clients: expliziter Service-State Sync.
-- Wichtig fuer MP/DEDIs, weil der normale Vehicle-DirtyFlag-Stream bei
-- Runtime-Specs oder nach Workshop-Reset nicht immer rechtzeitig auf Clients ankommt.
EVMServiceStateEvent = {}
local EVMServiceStateEvent_mt = Class(EVMServiceStateEvent, Event)
InitEventClass(EVMServiceStateEvent, "EVMServiceStateEvent")

function EVMServiceStateEvent.emptyNew()
    local self = Event.new(EVMServiceStateEvent_mt)
    return self
end

function EVMServiceStateEvent.new(vehicle, isActive, serviceMode, remainingMs, endAbsHours, hoursAdded, daysAdded)
    local self = EVMServiceStateEvent.emptyNew()
    self.vehicle = vehicle
    self.isActive = isActive == true
    self.serviceMode = serviceMode or 0
    self.remainingMs = math.max(0, tonumber(remainingMs) or 0)
    self.endAbsHours = tonumber(endAbsHours) or 0
    self.hoursAdded = math.max(0, tonumber(hoursAdded) or 0)
    self.daysAdded = math.max(0, tonumber(daysAdded) or 0)
    return self
end

function EVMServiceStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isActive = streamReadBool(streamId)
    self.serviceMode = streamReadUInt8(streamId)
    self.remainingMs = streamReadFloat32(streamId)
    self.endAbsHours = streamReadFloat32(streamId)
    self.hoursAdded = streamReadFloat32(streamId)
    self.daysAdded = streamReadFloat32(streamId)
    self:run(connection)
end

function EVMServiceStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isActive == true)
    streamWriteUInt8(streamId, self.serviceMode or 0)
    streamWriteFloat32(streamId, self.remainingMs or 0)
    streamWriteFloat32(streamId, self.endAbsHours or 0)
    streamWriteFloat32(streamId, self.hoursAdded or 0)
    streamWriteFloat32(streamId, self.daysAdded or 0)
end

function EVMServiceStateEvent:run(connection)
    if self.vehicle == nil or ExtendedVehicleMaintenance == nil then
        return
    end

    -- MP-Fix: Auf dem reinen Server (Dedi) ohne g_client darf das Event nicht
    -- nochmal angewendet werden, weil applyServiceState dort schon gelaufen ist.
    -- Auf einem Listen-Host (g_server + g_client) und auf reinen Clients muss
    -- receiveServiceStateFromServer aber laufen, damit lokale Locks/Countdown
    -- richtig installiert werden.
    if g_server ~= nil and g_client == nil then
        return
    end

    if ExtendedVehicleMaintenance.receiveServiceStateFromServer ~= nil then
        ExtendedVehicleMaintenance.receiveServiceStateFromServer(
            self.vehicle,
            self.isActive == true,
            self.serviceMode or 0,
            self.remainingMs or 0,
            self.endAbsHours or 0,
            self.hoursAdded or 0,
            self.daysAdded or 0
        )
    end
end

function EVMServiceStateEvent.sendEvent(vehicle, isActive, serviceMode, remainingMs, endAbsHours, hoursAdded, daysAdded)
    if vehicle == nil or g_server == nil then
        return
    end

    -- WICHTIG MP-Fix: NICHT 'vehicle' als 4. Argument an broadcastEvent uebergeben.
    -- Das vierte Argument ist der "ghost object" Filter und sorgt dafuer, dass das
    -- Event nur an Clients gesendet wird, die das Objekt als Ghost geladen haben.
    -- Direkt nach einem Workshop-Reset oder wenn der Stream nach Spec-Aenderung
    -- noch nicht fertig ist, fehlt das Vehicle bei einigen Clients - dann wird
    -- das Event still verworfen und Clients bekommen keinen Lock/Countdown.
    -- broadcastEvent(event, sendLocal=false, ignoreConnection=nil) reicht voellig.
    local event = EVMServiceStateEvent.new(vehicle, isActive, serviceMode, remainingMs, endAbsHours, hoursAdded, daysAdded)
    local ok, err = pcall(function()
        g_server:broadcastEvent(event, false, nil)
    end)
    if not ok then
        print("[EVM] EVMServiceStateEvent broadcast failed: " .. tostring(err))
        pcall(function()
            g_server:broadcastEvent(event)
        end)
    end
end


-- Client -> Server: Failure anfordern/loeschen.
-- Der normale ConsoleCommand laeuft im MP auf dem Client lokal. Reifen/Motor/Notlauf
-- muessen aber serverseitig gesetzt werden, sonst sehen die Clients keinen echten Effekt.
EVMFailureEvent = {}
local EVMFailureEvent_mt = Class(EVMFailureEvent, Event)
InitEventClass(EVMFailureEvent, "EVMFailureEvent")

function EVMFailureEvent.emptyNew()
    local self = Event.new(EVMFailureEvent_mt)
    return self
end

function EVMFailureEvent.new(vehicle, failureType, severity, clearFailure)
    local self = EVMFailureEvent.emptyNew()
    self.vehicle = vehicle
    self.failureType = failureType or "engine"
    self.severity = tonumber(severity) or 0.9
    self.clearFailure = clearFailure == true
    return self
end

function EVMFailureEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.failureType = streamReadString(streamId) or "engine"
    self.severity = streamReadFloat32(streamId) or 0.9
    self.clearFailure = streamReadBool(streamId)
    self:run(connection)
end

function EVMFailureEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteString(streamId, self.failureType or "engine")
    streamWriteFloat32(streamId, tonumber(self.severity) or 0.9)
    streamWriteBool(streamId, self.clearFailure == true)
end

function EVMFailureEvent:run(connection)
    if ExtendedVehicleMaintenance == nil or self.vehicle == nil then
        return
    end
    if g_server == nil then
        return
    end

    local rootVehicle = self.vehicle.rootVehicle or self.vehicle
    if self.clearFailure == true then
        ExtendedVehicleMaintenance.clearFailure(rootVehicle)
        if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
            ExtendedVehicleMaintenance.broadcastFailureState(rootVehicle)
        end
        print(string.format("[EVM] MP failure cleared vehicle=%s", tostring(rootVehicle)))
        return
    end

    local failureType = self.failureType or "engine"
    if ExtendedVehicleMaintenance.normalizeFailureType ~= nil then
        failureType = ExtendedVehicleMaintenance.normalizeFailureType(failureType) or failureType
    end

    print(string.format("[EVM] MP failure request received vehicle=%s type=%s severity=%.2f clear=%s", tostring(rootVehicle), tostring(failureType), tonumber(self.severity or 0.9), tostring(self.clearFailure)))

    local ok = false
    if ExtendedVehicleMaintenance.applyRandomFailure ~= nil then
        ok = ExtendedVehicleMaintenance.applyRandomFailure(rootVehicle, failureType, self.severity or 0.9) == true
    end
    print(string.format("[EVM] MP failure apply result vehicle=%s type=%s ok=%s", tostring(rootVehicle), tostring(failureType), tostring(ok)))
    if ok and ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
        ExtendedVehicleMaintenance.broadcastFailureState(rootVehicle)
    end
end

function EVMFailureEvent.sendEvent(vehicle, failureType, severity, clearFailure)
    if vehicle == nil or ExtendedVehicleMaintenance == nil then
        return false
    end

    local rootVehicle = vehicle.rootVehicle or vehicle
    local ft = failureType or "engine"
    local sev = tonumber(severity) or 0.9
    local clear = clearFailure == true

    if g_server ~= nil then
        if clear then
            ExtendedVehicleMaintenance.clearFailure(rootVehicle)
            if ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
                ExtendedVehicleMaintenance.broadcastFailureState(rootVehicle)
            end
            return true
        end

        local ok = ExtendedVehicleMaintenance.applyRandomFailure(rootVehicle, ft, sev) == true
        if ok and ExtendedVehicleMaintenance.broadcastFailureState ~= nil then
            ExtendedVehicleMaintenance.broadcastFailureState(rootVehicle)
        end
        return ok
    end

    local connection = g_client ~= nil and g_client:getServerConnection() or nil
    if connection ~= nil then
        -- Sofort lokales HUD/visuelle Effekte clearen; der Server bestaetigt danach per StateEvent.
        if clear and ExtendedVehicleMaintenance.receiveFailureStateFromServer ~= nil then
            ExtendedVehicleMaintenance.receiveFailureStateFromServer(rootVehicle, "", 0, 0, 0, 0)
        end
        connection:sendEvent(EVMFailureEvent.new(rootVehicle, ft, sev, clear))
        return true
    end

    return false
end

-- Server -> Clients: expliziter Failure-State Sync.
-- DirtyFlags reichen bei Runtime-Specs/kurz nach Join nicht immer, und fuer Reifen/Notlauf
-- sollen die lokalen Hooks sofort auf jedem Client installiert werden.
EVMFailureStateEvent = {}
local EVMFailureStateEvent_mt = Class(EVMFailureStateEvent, Event)
InitEventClass(EVMFailureStateEvent, "EVMFailureStateEvent")

function EVMFailureStateEvent.emptyNew()
    local self = Event.new(EVMFailureStateEvent_mt)
    return self
end

function EVMFailureStateEvent.new(vehicle, failureType, severity, wheelIndex, driftDirection, rpmLimit)
    local self = EVMFailureStateEvent.emptyNew()
    self.vehicle = vehicle
    self.failureType = failureType or ""
    self.severity = tonumber(severity) or 0
    self.wheelIndex = tonumber(wheelIndex) or 0
    self.driftDirection = tonumber(driftDirection) or 0
    self.rpmLimit = tonumber(rpmLimit) or 0
    return self
end

function EVMFailureStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.failureType = streamReadString(streamId) or ""
    self.severity = streamReadFloat32(streamId) or 0
    self.wheelIndex = streamReadInt8(streamId) or 0
    self.driftDirection = streamReadInt8(streamId) or 0
    self.rpmLimit = streamReadFloat32(streamId) or 0
    self:run(connection)
end

function EVMFailureStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteString(streamId, self.failureType or "")
    streamWriteFloat32(streamId, tonumber(self.severity) or 0)
    streamWriteInt8(streamId, tonumber(self.wheelIndex) or 0)
    streamWriteInt8(streamId, tonumber(self.driftDirection) or 0)
    streamWriteFloat32(streamId, tonumber(self.rpmLimit) or 0)
end

function EVMFailureStateEvent:run(connection)
    if self.vehicle == nil or ExtendedVehicleMaintenance == nil then
        return
    end
    if g_server ~= nil and g_client == nil then
        return
    end
    if ExtendedVehicleMaintenance.receiveFailureStateFromServer ~= nil then
        ExtendedVehicleMaintenance.receiveFailureStateFromServer(
            self.vehicle,
            self.failureType or "",
            self.severity or 0,
            self.wheelIndex or 0,
            self.driftDirection or 0,
            self.rpmLimit or 0
        )
    end
end

function EVMFailureStateEvent.sendEvent(vehicle, failureType, severity, wheelIndex, driftDirection, rpmLimit)
    if vehicle == nil or g_server == nil then
        return
    end
    local event = EVMFailureStateEvent.new(vehicle, failureType, severity, wheelIndex, driftDirection, rpmLimit)
    local ok, err = pcall(function()
        g_server:broadcastEvent(event, false, nil)
    end)
    if not ok then
        print("[EVM] EVMFailureStateEvent broadcast failed: " .. tostring(err))
        pcall(function()
            g_server:broadcastEvent(event)
        end)
    end
end


-- Server -> Clients: expliziter Batterie-State Sync.
-- Der normale DirtyFlag-Stream ist fuer kleine, haeufige Batteriewert-Aenderungen
-- im MP/Dedi nicht immer sichtbar genug. Dieses Event aktualisiert HUD/Startblocker direkt.
EVMBatteryStateEvent = {}
local EVMBatteryStateEvent_mt = Class(EVMBatteryStateEvent, Event)
InitEventClass(EVMBatteryStateEvent, "EVMBatteryStateEvent")

function EVMBatteryStateEvent.emptyNew()
    local self = Event.new(EVMBatteryStateEvent_mt)
    return self
end

function EVMBatteryStateEvent.new(vehicle, charge, voltage, failureType, failureSeverity)
    local self = EVMBatteryStateEvent.emptyNew()
    self.vehicle = vehicle
    self.charge = tonumber(charge) or 1.0
    self.voltage = tonumber(voltage) or 12.7
    self.failureType = failureType or ""
    self.failureSeverity = tonumber(failureSeverity) or 0
    return self
end

function EVMBatteryStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.charge = streamReadFloat32(streamId) or 1.0
    self.voltage = streamReadFloat32(streamId) or 12.7
    self.failureType = streamReadString(streamId) or ""
    self.failureSeverity = streamReadFloat32(streamId) or 0
    self:run(connection)
end

function EVMBatteryStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, tonumber(self.charge) or 1.0)
    streamWriteFloat32(streamId, tonumber(self.voltage) or 12.7)
    streamWriteString(streamId, self.failureType or "")
    streamWriteFloat32(streamId, tonumber(self.failureSeverity) or 0)
end

function EVMBatteryStateEvent:run(connection)
    if self.vehicle == nil or ExtendedVehicleMaintenance == nil then
        return
    end
    if g_server ~= nil and g_client == nil then
        return
    end
    if ExtendedVehicleMaintenance.receiveBatteryStateFromServer ~= nil then
        ExtendedVehicleMaintenance.receiveBatteryStateFromServer(
            self.vehicle,
            self.charge or 1.0,
            self.voltage or 12.7,
            self.failureType or "",
            self.failureSeverity or 0
        )
    end
end

function EVMBatteryStateEvent.sendEvent(vehicle, charge, voltage, failureType, failureSeverity)
    if vehicle == nil or g_server == nil then
        return
    end
    local event = EVMBatteryStateEvent.new(vehicle, charge, voltage, failureType, failureSeverity)
    local ok, err = pcall(function()
        g_server:broadcastEvent(event, false, nil)
    end)
    if not ok then
        print("[EVM] EVMBatteryStateEvent broadcast failed: " .. tostring(err))
        pcall(function()
            g_server:broadcastEvent(event)
        end)
    end
end

-- ===========================================================================
-- EVMChargeBatteryEvent: Client -> Server
-- Wird vom Client gesendet wenn der Spieler "Batterie laden" auswählt.
-- Server validiert (Geld vorhanden, Batterie wirklich leer) und startet Vorgang.
-- ===========================================================================
EVMChargeBatteryEvent = {}
local EVMChargeBatteryEvent_mt = Class(EVMChargeBatteryEvent, Event)
InitEventClass(EVMChargeBatteryEvent, "EVMChargeBatteryEvent")

function EVMChargeBatteryEvent.emptyNew()
    local self = Event.new(EVMChargeBatteryEvent_mt)
    return self
end

function EVMChargeBatteryEvent.new(vehicle)
    local self = EVMChargeBatteryEvent.emptyNew()
    self.vehicle = vehicle
    return self
end

function EVMChargeBatteryEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end

function EVMChargeBatteryEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
end

function EVMChargeBatteryEvent:run(connection)
    if self.vehicle == nil or ExtendedVehicleMaintenance == nil then
        return
    end
    -- Nur Server verarbeitet das Event
    if g_server ~= nil and ExtendedVehicleMaintenance.applyBatteryCharging ~= nil then
        ExtendedVehicleMaintenance.applyBatteryCharging(self.vehicle)
    end
end

function EVMChargeBatteryEvent.sendEvent(vehicle)
    if vehicle == nil then return end
    if g_server ~= nil then
        -- Auf dem Server: direkt verarbeiten (kein Event nötig)
        if ExtendedVehicleMaintenance.applyBatteryCharging ~= nil then
            ExtendedVehicleMaintenance.applyBatteryCharging(vehicle)
        end
    elseif g_client ~= nil then
        -- Auf dem Client: Event an Server schicken
        local event = EVMChargeBatteryEvent.new(vehicle)
        local ok, err = pcall(function()
            g_client:getServerConnection():sendEvent(event)
        end)
        if not ok then
            print("[EVM] EVMChargeBatteryEvent send failed: " .. tostring(err))
        end
    end
end

-- v16: Multiplayer-Kollisionsschaden.
-- Im MP läuft die Kollisionserkennung clientseitig (nur dort kennt das Spiel die echte
-- Geschwindigkeit/Position des gesteuerten Fahrzeugs). setDamageAmount muss aber vom
-- Server kommen, sonst wird der Schaden über die Damage-Streams weggeschrieben oder
-- gar nicht gesetzt. Der Client schickt dieses Event an den Server, der Server appliziert
-- den Schaden und FS25 broadcastet ihn anschließend automatisch über den DamageState.
EVMCollisionDamageEvent = {}
local EVMCollisionDamageEvent_mt = Class(EVMCollisionDamageEvent, Event)
InitEventClass(EVMCollisionDamageEvent, "EVMCollisionDamageEvent")

function EVMCollisionDamageEvent.emptyNew()
    local self = Event.new(EVMCollisionDamageEvent_mt)
    return self
end

function EVMCollisionDamageEvent.new(vehicle, addDamage)
    local self = EVMCollisionDamageEvent.emptyNew()
    self.vehicle = vehicle
    -- addDamage als 0..1 Float; serverseitig nochmals geclamped.
    self.addDamage = math.max(0, math.min(1, tonumber(addDamage) or 0))
    return self
end

function EVMCollisionDamageEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.addDamage = streamReadFloat32(streamId) or 0
    self:run(connection)
end

function EVMCollisionDamageEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, tonumber(self.addDamage) or 0)
end

function EVMCollisionDamageEvent:run(connection)
    -- Server-only Handler: nur der Server appliziert Schaden und delegiert das Sync.
    if g_server == nil then return end
    if self.vehicle == nil or not self.vehicle:getIsSynchronized() then return end
    if ExtendedVehicleMaintenance == nil then return end

    local rootVehicle = self.vehicle.rootVehicle or self.vehicle
    local addDamage = math.max(0, math.min(1, tonumber(self.addDamage) or 0))

    -- Sicherheits-Cap pro Event: kein Client darf >25% Schaden in einem Event setzen.
    -- Das schützt vor manipulierten Clients und schlechten Detection-Werten.
    if addDamage > 0.25 then addDamage = 0.25 end
    if addDamage <= 0.0005 then return end

    -- Sanity: kein Schaden während aktiver Wartung
    local spec = nil
    if ExtendedVehicleMaintenance.getVehicleSpec ~= nil then
        spec = ExtendedVehicleMaintenance.getVehicleSpec(rootVehicle)
    elseif rootVehicle.spec_extendedVehicleMaintenance ~= nil then
        spec = rootVehicle.spec_extendedVehicleMaintenance
    end
    if spec ~= nil and spec.isServiceActive == true then return end

    -- Rate-Limit: nicht öfter als alle 800ms pro Fahrzeug akzeptieren (Anti-Spam).
    local now = g_time or 0
    if spec ~= nil then
        if spec.evmCollisionLastServerApply ~= nil and (now - spec.evmCollisionLastServerApply) < 800 then
            return
        end
        spec.evmCollisionLastServerApply = now
    end

    local currentDamage = 0
    if rootVehicle.getDamageAmount ~= nil then
        local ok, dmg = pcall(rootVehicle.getDamageAmount, rootVehicle)
        if ok and dmg ~= nil then currentDamage = tonumber(dmg) or 0 end
    end
    local newDamage = math.max(0, math.min(1, currentDamage + addDamage))

    local applied = false
    if rootVehicle.setDamageAmount ~= nil then
        local okSet = pcall(rootVehicle.setDamageAmount, rootVehicle, newDamage, true)
        applied = okSet == true
    end
    if not applied and rootVehicle.spec_wearable ~= nil then
        rootVehicle.spec_wearable.damage = newDamage
        applied = true
    end

    if applied and spec ~= nil and rootVehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
        rootVehicle:raiseDirtyFlags(spec.dirtyFlag)
    end

    if ExtendedVehicleMaintenance.COLLISION_DEBUG == true or ExtendedVehicleMaintenance.debug == true then
        print(string.format(
            "[EVM] MP CollisionDamageEvent applied vehicle=%s add=%.3f%% %.2f%% -> %.2f%% applied=%s",
            tostring(rootVehicle), addDamage * 100, currentDamage * 100, newDamage * 100, tostring(applied)))
    end
end

function EVMCollisionDamageEvent.sendEvent(vehicle, addDamage)
    if vehicle == nil or ExtendedVehicleMaintenance == nil then return false end
    local rootVehicle = vehicle.rootVehicle or vehicle
    local d = math.max(0, math.min(1, tonumber(addDamage) or 0))
    if d <= 0.0005 then return false end

    -- Auf dem Listen-Host (g_server + g_client): direkt anwenden, kein Round-Trip.
    if g_server ~= nil then
        local spec = rootVehicle.spec_extendedVehicleMaintenance
        if spec ~= nil and spec.isServiceActive == true then return false end

        local currentDamage = 0
        if rootVehicle.getDamageAmount ~= nil then
            local ok, dmg = pcall(rootVehicle.getDamageAmount, rootVehicle)
            if ok and dmg ~= nil then currentDamage = tonumber(dmg) or 0 end
        end
        local newDamage = math.max(0, math.min(1, currentDamage + d))

        local applied = false
        if rootVehicle.setDamageAmount ~= nil then
            applied = pcall(rootVehicle.setDamageAmount, rootVehicle, newDamage, true) == true
        end
        if not applied and rootVehicle.spec_wearable ~= nil then
            rootVehicle.spec_wearable.damage = newDamage
            applied = true
        end
        if applied and spec ~= nil and rootVehicle.raiseDirtyFlags ~= nil and spec.dirtyFlag ~= nil then
            rootVehicle:raiseDirtyFlags(spec.dirtyFlag)
        end
        return applied
    end

    -- Reiner Client: Event an Server schicken. Server validiert + appliziert + broadcastet.
    if g_client == nil then return false end
    local connection = g_client:getServerConnection()
    if connection == nil then return false end
    local ok, err = pcall(function()
        connection:sendEvent(EVMCollisionDamageEvent.new(rootVehicle, d))
    end)
    if not ok then
        print("[EVM] EVMCollisionDamageEvent send failed: " .. tostring(err))
        return false
    end
    return true
end

-- v18: Quick-Fix / Limp-Home Anfrage vom Client an den Server.
-- action = 1 -> applyQuickFix, action = 2 -> applyLimpHome
EVMQuickFixEvent = {}
local EVMQuickFixEvent_mt = Class(EVMQuickFixEvent, Event)
InitEventClass(EVMQuickFixEvent, "EVMQuickFixEvent")

function EVMQuickFixEvent.emptyNew()
    local self = Event.new(EVMQuickFixEvent_mt)
    return self
end

function EVMQuickFixEvent.new(vehicle, action)
    local self = EVMQuickFixEvent.emptyNew()
    self.vehicle = vehicle
    self.action = tonumber(action) or 1
    return self
end

function EVMQuickFixEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.action = streamReadUInt8(streamId)
    self:run(connection)
end

function EVMQuickFixEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUInt8(streamId, tonumber(self.action) or 1)
end

function EVMQuickFixEvent:run(connection)
    if g_server == nil then return end
    if self.vehicle == nil or not self.vehicle:getIsSynchronized() then return end
    if ExtendedVehicleMaintenance == nil then return end

    local rootVehicle = self.vehicle.rootVehicle or self.vehicle

    -- Berechtigungs-Check: nur eigener Hof-Spieler darf Quick-Fix ausloesen.
    if connection ~= nil and connection.getUserId ~= nil and rootVehicle.getOwnerFarmId ~= nil then
        local ok1, ownerFarm = pcall(rootVehicle.getOwnerFarmId, rootVehicle)
        if ok1 and ownerFarm ~= nil and ownerFarm ~= 0 and g_currentMission ~= nil and g_currentMission.userManager ~= nil then
            local user = g_currentMission.userManager:getUserByConnection(connection)
            if user ~= nil and user.getFarmId ~= nil then
                local farmId = user:getFarmId()
                if farmId ~= ownerFarm and not (user.getIsMasterUser ~= nil and user:getIsMasterUser() == true) then
                    print(string.format("[EVM] EVMQuickFixEvent denied: user farm=%s vehicle owner=%s", tostring(farmId), tostring(ownerFarm)))
                    return
                end
            end
        end
    end

    if self.action == 2 then
        ExtendedVehicleMaintenance.applyLimpHome(rootVehicle)
    else
        ExtendedVehicleMaintenance.applyQuickFix(rootVehicle)
    end
end

function EVMQuickFixEvent.sendEvent(vehicle, action)
    if vehicle == nil or ExtendedVehicleMaintenance == nil then return false end
    local rootVehicle = vehicle.rootVehicle or vehicle
    local act = tonumber(action) or 1

    if g_server ~= nil then
        if act == 2 then
            return ExtendedVehicleMaintenance.applyLimpHome(rootVehicle) == true
        end
        return ExtendedVehicleMaintenance.applyQuickFix(rootVehicle) == true
    end

    if g_client == nil then return false end
    local conn = g_client:getServerConnection()
    if conn == nil then return false end
    local ok, err = pcall(function()
        conn:sendEvent(EVMQuickFixEvent.new(rootVehicle, act))
    end)
    if not ok then
        print("[EVM] EVMQuickFixEvent send failed: " .. tostring(err))
        return false
    end
    return true
end
