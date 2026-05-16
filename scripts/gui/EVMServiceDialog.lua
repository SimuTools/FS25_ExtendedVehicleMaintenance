EVMServiceDialog = {}
local EVMServiceDialog_mt = Class(EVMServiceDialog, YesNoDialog)

local function evmDbg(fmt, ...)
    if not (ExtendedVehicleMaintenance ~= nil and ExtendedVehicleMaintenance.debug) then return end
    local ok, msg = pcall(string.format, "[EVM] " .. tostring(fmt), ...)
    if ok then
        print(msg)
    else
        print("[EVM] " .. tostring(fmt))
    end
end

local function evmSafeText(value, fallback)
    if value == nil then
        return fallback or ""
    end

    local s = tostring(value)
    if s == "" then
        return fallback or ""
    end

    return s
end

local function evmGetVehicleName(vehicle)
    if vehicle == nil then
        return "nil"
    end

    if vehicle.getName ~= nil then
        local ok, result = pcall(vehicle.getName, vehicle)
        if ok and result ~= nil and tostring(result) ~= "" then
            return tostring(result)
        end
    end

    if vehicle.configFileName ~= nil and tostring(vehicle.configFileName) ~= "" then
        return tostring(vehicle.configFileName)
    end

    return tostring(vehicle)
end

function EVMServiceDialog.new(target, custom_mt)
    local self = YesNoDialog.new(target, custom_mt or EVMServiceDialog_mt)
    self.entries = {}
    self.selectedIndex = 1
    self.ownerFarmId = nil
    self.sellingPoint = nil
    self.serviceMode = 1
    self.targetVehicle = nil
    self.lastModeState = nil
    self.debugId = math.random(1000, 9999)
    evmDbg("Dialog.new created debugId=%s", tostring(self.debugId))
    return self
end

function EVMServiceDialog.register(modDir)
    if g_gui == nil then
        evmDbg("register aborted: g_gui=nil")
        return false
    end

    local path = Utils.getFilename("gui/EVMServiceDialog.xml", modDir or g_currentModDirectory or "")
    evmDbg("register path=%s", tostring(path))

    if not fileExists(path) then
        print("[ExtendedVehicleMaintenance] ERROR Dialog xml missing: " .. tostring(path))
        return false
    end

    EVMServiceDialog.INSTANCE = nil

    local dlg = EVMServiceDialog.new()
    local ok, err = pcall(function()
        g_gui:loadGui(path, "EVMServiceDialog", dlg)
    end)

    if not ok then
        print("[ExtendedVehicleMaintenance] ERROR Dialog registration failed: " .. tostring(err))
        return false
    end

    EVMServiceDialog.INSTANCE = dlg
    print("[EVM] EVMServiceDialog registered")
    evmDbg("dialog registered=true instance=%s", tostring(dlg))
    return true
end

function EVMServiceDialog.show(vehicle)
    local dlg = EVMServiceDialog.INSTANCE
    if dlg == nil or g_gui == nil or ExtendedVehicleMaintenance == nil then
        evmDbg("show failed: missing dlg/g_gui/ExtendedVehicleMaintenance dlg=%s g_gui=%s evm=%s", tostring(dlg), tostring(g_gui), tostring(ExtendedVehicleMaintenance))
        return false
    end

    dlg.targetVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
    dlg.selectedIndex = 1
    dlg.serviceMode = 1
    dlg.lastModeState = nil
    dlg.entries = {}

    evmDbg("show called rawVehicle=%s targetVehicle=%s", tostring(vehicle), evmGetVehicleName(dlg.targetVehicle))

    if dlg.targetVehicle == nil then
        evmDbg("show failed: targetVehicle=nil")
        if g_currentMission ~= nil then
            g_currentMission:showBlinkingWarning(g_i18n:getText("ui_evm_noTargets") or "No vehicle nearby", 1000)
        end
        return false
    end

    local entry = nil
    local okEntry, resultEntry = pcall(function()
        if ExtendedVehicleMaintenance.createSelectionEntry ~= nil then
            return ExtendedVehicleMaintenance.createSelectionEntry(dlg.targetVehicle)
        end
        return nil
    end)

    evmDbg("show createSelectionEntry ok=%s resultType=%s", tostring(okEntry), type(resultEntry))

    if okEntry then
        entry = resultEntry
    else
        evmDbg("createSelectionEntry failed: %s", tostring(resultEntry))
    end

    if entry == nil then
        local damage = 0
        if dlg.targetVehicle.getDamageAmount ~= nil then
            local okDamage, damageValue = pcall(function()
                return dlg.targetVehicle:getDamageAmount()
            end)
            evmDbg("fallback getDamageAmount ok=%s value=%s", tostring(okDamage), tostring(damageValue))
            if okDamage and damageValue ~= nil then
                damage = tonumber(damageValue) or 0
            end
        elseif dlg.targetVehicle.spec_wearable ~= nil and dlg.targetVehicle.spec_wearable.damage ~= nil then
            damage = tonumber(dlg.targetVehicle.spec_wearable.damage) or 0
            evmDbg("fallback spec_wearable.damage=%s", tostring(damage))
        end

        local name = evmGetVehicleName(dlg.targetVehicle)
        local cost = math.max(350, math.floor(damage * 5000 + 0.5))
        local durationHours = 1.5

        entry = {
            vehicle = dlg.targetVehicle,
            name = name,
            damage = damage,
            cost = cost,
            technicianCost = math.floor(cost * 1.35 + 0.5),
            durationHours = durationHours
        }

        evmDbg("fallback entry created name=%s damage=%.4f cost=%s technicianCost=%s durationHours=%.2f", tostring(name), damage, tostring(cost), tostring(entry.technicianCost), durationHours)
    else
        evmDbg("entry from createSelectionEntry name=%s damage=%s cost=%s technicianCost=%s durationHours=%s", tostring(entry.name), tostring(entry.damage), tostring(entry.cost), tostring(entry.technicianCost), tostring(entry.durationHours))
    end

    if entry ~= nil then
        table.insert(dlg.entries, entry)
    end

    evmDbg("show entriesCount=%s", tostring(#dlg.entries))

    if #dlg.entries == 0 then
        if g_currentMission ~= nil then
            g_currentMission:showBlinkingWarning(g_i18n:getText("ui_evm_noTargets") or "No vehicle nearby", 1000)
        end
        return false
    end

    local okShow, errShow = pcall(function()
        g_gui:showDialog("EVMServiceDialog")
    end)

    if not okShow then
        evmDbg("showDialog failed: %s", tostring(errShow))
        return false
    end

    evmDbg("showDialog success target=%s", evmGetVehicleName(dlg.targetVehicle))
    return true
end

function EVMServiceDialog:onCreate()
    evmDbg("EVMServiceDialog:onCreate() self=%s", tostring(self))

    if self.yesButton ~= nil then
        self.yesButton.onClickCallback = self.onClickOk
        self.yesButton.target = self
        evmDbg("yesButton hooked")
    else
        evmDbg("yesButton missing")
    end

    if self.noButton ~= nil then
        self.noButton.onClickCallback = self.onClickBack
        self.noButton.target = self
        evmDbg("noButton hooked")
    else
        evmDbg("noButton missing")
    end
end

function EVMServiceDialog:onOpen()
    EVMServiceDialog:superClass().onOpen(self)
    evmDbg("EVMServiceDialog:onOpen() target=%s entries=%s", evmGetVehicleName(self.targetVehicle), tostring(#self.entries))

    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        g_inputBinding:setShowMouseCursor(true)
        evmDbg("mouse cursor enabled")
    end

    if self.dialogTitleElement ~= nil and self.dialogTitleElement.setText ~= nil then
        self.dialogTitleElement:setText(g_i18n:getText("ui_evm_title") or "Service")
        evmDbg("dialog title set")
    else
        evmDbg("dialogTitleElement missing")
    end

    self:setupModeBox()
    self.lastModeState = self:getModeState()
    self:updatePreview()
end

function EVMServiceDialog:onClose()
    evmDbg("EVMServiceDialog:onClose() target=%s", evmGetVehicleName(self.targetVehicle))

    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        g_inputBinding:setShowMouseCursor(false)
        evmDbg("mouse cursor disabled")
    end

    EVMServiceDialog:superClass().onClose(self)
end

function EVMServiceDialog:update(dt)
    EVMServiceDialog:superClass().update(self, dt)

    local state = self:getModeState()
    if state ~= self.lastModeState then
        evmDbg("mode state changed old=%s new=%s", tostring(self.lastModeState), tostring(state))
        self.lastModeState = state
        self.serviceMode = math.max(1, math.min(3, state))
        self:updatePreview()
    end
end

function EVMServiceDialog:setTextSafe(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(text or ""))
    else
        evmDbg("setTextSafe skipped missing element text=%s", tostring(text))
    end
end

function EVMServiceDialog:getModeState()
    if self.serviceModeElement ~= nil and self.serviceModeElement.getState ~= nil then
        local state = self.serviceModeElement:getState()
        if state ~= nil then
            local num = tonumber(state) or 1
            return num
        end
    end
    return 1
end

function EVMServiceDialog:setupModeBox()
    local texts = {
        g_i18n:getText("ui_evm_sendWorkshop") or "Send to workshop",
        g_i18n:getText("ui_evm_callTechnician") or "Call technician",
        g_i18n:getText("ui_evm_selfRepair") or "Repair yourself"
    }

    evmDbg("setupModeBox serviceMode=%s text1=%s text2=%s", tostring(self.serviceMode), tostring(texts[1]), tostring(texts[2]))

    if self.serviceModeElement ~= nil then
        if self.serviceModeElement.setTexts ~= nil then
            self.serviceModeElement:setTexts(texts)
            evmDbg("serviceModeElement texts applied")
        else
            evmDbg("serviceModeElement.setTexts missing")
        end

        if self.serviceModeElement.setState ~= nil then
            self.serviceModeElement:setState(self.serviceMode, true)
            evmDbg("serviceModeElement state set=%s", tostring(self.serviceMode))
        else
            evmDbg("serviceModeElement.setState missing")
        end
    else
        evmDbg("serviceModeElement missing")
    end

    self.lastModeState = self:getModeState()
end

function EVMServiceDialog:getSelectedEntry()
    local entry = self.entries[self.selectedIndex]
    evmDbg("getSelectedEntry index=%s entry=%s vehicle=%s", tostring(self.selectedIndex), tostring(entry), entry ~= nil and evmGetVehicleName(entry.vehicle) or "nil")
    return entry
end

function EVMServiceDialog:getModeText()
    if self.serviceMode == 2 then
        return g_i18n:getText("ui_evm_callTechnician") or "Call technician"
    elseif self.serviceMode == 3 then
        return g_i18n:getText("ui_evm_selfRepair") or "Repair yourself"
    end
    return g_i18n:getText("ui_evm_sendWorkshop") or "Send to workshop"
end

function EVMServiceDialog:getModeCost(baseCost)
    local entry = self:getSelectedEntry()
    if entry ~= nil then
        if self.serviceMode == 2 and entry.technicianCost ~= nil then
            return entry.technicianCost
        elseif self.serviceMode == 3 and entry.selfRepairCost ~= nil then
            return entry.selfRepairCost
        elseif entry.cost ~= nil then
            return entry.cost
        end
    end
    return baseCost or 0
end

function EVMServiceDialog:getModeDuration(baseHours)
    local entry = self:getSelectedEntry()
    if entry ~= nil then
        if self.serviceMode == 2 and entry.durationTechnicianHours ~= nil then
            return entry.durationTechnicianHours
        elseif self.serviceMode == 3 and entry.durationSelfRepairHours ~= nil then
            return entry.durationSelfRepairHours
        elseif entry.durationHours ~= nil then
            return entry.durationHours
        end
    end
    return baseHours or 0
end

function EVMServiceDialog:formatMoneySafe(value)
    if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
        local ok, result = pcall(function()
            return g_i18n:formatMoney(value or 0, 0, true, true)
        end)
        if ok and result ~= nil then
            return result
        end
        evmDbg("formatMoneySafe fallback after formatMoney failure ok=%s result=%s", tostring(ok), tostring(result))
    end

    return string.format("%d €", math.floor((value or 0) + 0.5))
end

function EVMServiceDialog:updatePreview()
    local entry = self:getSelectedEntry()
    if entry == nil then
        evmDbg("updatePreview no entry")
        self:setTextSafe(self.vehicleValueText, "-")
        self:setTextSafe(self.damageValueText, "-")
        self:setTextSafe(self.costValueText, "-")
        self:setTextSafe(self.durationValueText, "-")
        self:setTextSafe(self.optionValueText, "-")
        return
    end

    local cost
    local durationHours
    if self.serviceMode == 2 then
        cost = entry.technicianCost ~= nil and entry.technicianCost or self:getModeCost(entry.cost or 0)
        durationHours = entry.durationTechnicianHours ~= nil and entry.durationTechnicianHours or self:getModeDuration(entry.durationHours or 0)
    elseif self.serviceMode == 3 then
        cost = entry.selfRepairCost ~= nil and entry.selfRepairCost or self:getModeCost(entry.cost or 0)
        durationHours = entry.durationSelfRepairHours ~= nil and entry.durationSelfRepairHours or self:getModeDuration(entry.durationHours or 0)
    else
        cost = entry.cost or 0
        durationHours = entry.durationHours or 0
    end

    evmDbg(
        "updatePreview vehicle=%s mode=%s damage=%s baseCost=%s previewCost=%s baseDuration=%s previewDuration=%s",
        tostring(entry.name),
        tostring(self.serviceMode),
        tostring(entry.damage),
        tostring(entry.cost),
        tostring(cost),
        tostring(entry.durationHours),
        tostring(durationHours)
    )

    self:setTextSafe(self.vehicleValueText, entry.name or "-")
    self:setTextSafe(self.damageValueText, string.format("%d %%", math.floor((entry.damage or 0) * 100 + 0.5)))
    self:setTextSafe(self.costValueText, self:formatMoneySafe(cost))
    self:setTextSafe(self.durationValueText, string.format("%1.1f h", durationHours))
    self:setTextSafe(self.optionValueText, self:getModeText())
end

function EVMServiceDialog:onClickOk()
    local entry = self:getSelectedEntry()

    evmDbg("onClickOk START serviceMode=%s entry=%s vehicle=%s", tostring(self.serviceMode), tostring(entry), entry ~= nil and evmGetVehicleName(entry.vehicle) or "nil")

    -- v18: CRITICAL-Panne darf nicht selbst repariert werden.
    if self.serviceMode == 3 and entry ~= nil and entry.vehicle ~= nil
        and ExtendedVehicleMaintenance ~= nil
        and ExtendedVehicleMaintenance.getActiveFailureTier ~= nil then
        local rootVehicle = entry.vehicle.rootVehicle or entry.vehicle
        local tier = ExtendedVehicleMaintenance.getActiveFailureTier(rootVehicle)
        if tier == "critical" then
            if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
                local msg = g_i18n:getText("warning_evmCriticalNoSelfRepair") or "Critical failure - workshop or technician required."
                g_currentMission:showBlinkingWarning(msg, 2500)
            end
            evmDbg("onClickOk blocked: CRITICAL failure cannot self-repair")
            return
        end
    end

    self:close()

    if entry ~= nil and entry.vehicle ~= nil then
        local rootVehicle = entry.vehicle.rootVehicle or entry.vehicle
        evmDbg("onClickOk sending event to vehicle=%s rootVehicle=%s mode=%s", evmGetVehicleName(entry.vehicle), evmGetVehicleName(rootVehicle), tostring(self.serviceMode or 1))

        local ok, err = pcall(function()
            EVMStartServiceEvent.sendEvent(rootVehicle, self.serviceMode or 1)
        end)

        if not ok then
            evmDbg("onClickOk sendEvent failed: %s", tostring(err))
        else
            evmDbg("onClickOk sendEvent success mode=%s target=%s", tostring(self.serviceMode or 1), evmGetVehicleName(rootVehicle))
        end
    else
        evmDbg("onClickOk aborted: entry or vehicle nil")
    end
end

function EVMServiceDialog:onClickBack()
    evmDbg("onClickBack")
    self:close()
end