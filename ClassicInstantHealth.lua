local InstantHealth = LibStub("LibInstantHealth-1.0")

local UnitGUID = UnitGUID
local UnitIsConnected = UnitIsConnected
local GetTime = GetTime
local pairs = pairs
local wipe = wipe

local UnitHealth = InstantHealth.UnitHealth
local UnitHealthMax = InstantHealth.UnitHealthMax

local deferredCompactUnitFrames = {}
local deferredUnitFrameHealthBars = {}
local lastFrameTime = -1

local function CompactUnitFrame_OnHealthUpdate(frame, event, unit)
    if unit ~= frame.unit and unit ~= frame.displayedUnit then
        return
    end

    if GetTime() > lastFrameTime then
        deferredCompactUnitFrames[frame] = deferredCompactUnitFrames[frame] or event == "UNIT_MAXHEALTH"
    else
        if event == "UNIT_MAXHEALTH" then
            CompactUnitFrame_UpdateMaxHealth(frame)
        end

        CompactUnitFrame_UpdateHealth(frame)
        CompactUnitFrame_UpdateStatusText(frame)
    end
end

local function UnitFrameHealthBar_OnHealthUpdate(statusbar, event, unit)
    if unit ~= statusbar.unit then
        return
    end

    if GetTime() > lastFrameTime then
        deferredUnitFrameHealthBars[statusbar] = true
    else
        UnitFrameHealthBar_Update(statusbar, unit)
    end
end

local deferFrame = CreateFrame("Frame")
deferFrame:SetScript(
    "OnUpdate",
    function(self, elapsed)
        for frame, updateMaxHealth in pairs(deferredCompactUnitFrames) do
            if updateMaxHealth then
                CompactUnitFrame_UpdateMaxHealth(frame)
            end

            CompactUnitFrame_UpdateHealth(frame)
            CompactUnitFrame_UpdateStatusText(frame)
        end

        for statusbar in pairs(deferredUnitFrameHealthBars) do
            UnitFrameHealthBar_Update(statusbar, statusbar.unit)
        end

        wipe(deferredCompactUnitFrames)
        wipe(deferredUnitFrameHealthBars)

        lastFrameTime = GetTime()
    end
)

hooksecurefunc(
    "CompactUnitFrame_UpdateUnitEvents",
    function(frame)
        if frame:IsForbidden() then
            return
        end

        frame:UnregisterEvent("UNIT_MAXHEALTH")
        frame:UnregisterEvent("UNIT_HEALTH")
        frame:UnregisterEvent("UNIT_HEALTH_FREQUENT")

        if not frame.unit and not frame.displayedUnit then
            InstantHealth.UnregisterCallback(frame, "UNIT_MAXHEALTH")
            InstantHealth.UnregisterCallback(frame, "UNIT_HEALTH")
            InstantHealth.UnregisterCallback(frame, "UNIT_HEALTH_FREQUENT")
        else
            InstantHealth.RegisterCallback(frame, "UNIT_MAXHEALTH", CompactUnitFrame_OnHealthUpdate, frame)
            InstantHealth.RegisterCallback(frame, "UNIT_HEALTH", CompactUnitFrame_OnHealthUpdate, frame)
            InstantHealth.RegisterCallback(frame, "UNIT_HEALTH_FREQUENT", CompactUnitFrame_OnHealthUpdate, frame)
        end
    end
)

hooksecurefunc(
    "CompactUnitFrame_UnregisterEvents",
    function(frame)
        if frame:IsForbidden() then
            return
        end

        frame:UnregisterEvent("UNIT_MAXHEALTH")
        frame:UnregisterEvent("UNIT_HEALTH")
        frame:UnregisterEvent("UNIT_HEALTH_FREQUENT")

        InstantHealth.UnregisterCallback(frame, "UNIT_MAXHEALTH")
        InstantHealth.UnregisterCallback(frame, "UNIT_HEALTH")
        InstantHealth.UnregisterCallback(frame, "UNIT_HEALTH_FREQUENT")
    end
)

hooksecurefunc(
    "CompactUnitFrame_UpdateMaxHealth",
    function(frame)
        if frame:IsForbidden() then
            return
        end

        local maxHealth = UnitHealthMax(frame.displayedUnit)

        if frame.optionTable.smoothHealthUpdates then
            frame.healthBar:SetMinMaxSmoothedValue(0, maxHealth)
        else
            frame.healthBar:SetMinMaxValues(0, maxHealth)
        end
    end
)

hooksecurefunc(
    "CompactUnitFrame_UpdateHealth",
    function(frame)
        if frame:IsForbidden() then
            return
        end

        local health = UnitHealth(frame.displayedUnit)

        if frame.optionTable.smoothHealthUpdates then
            if frame.newUnit then
                frame.healthBar:ResetSmoothedValue(health)
                frame.newUnit = false
            else
                frame.healthBar:SetSmoothedValue(health)
            end
        else
            frame.healthBar:SetValue(health)
        end
    end
)

hooksecurefunc(
    "CompactUnitFrame_UpdateStatusText",
    function(frame)
        if frame:IsForbidden() then
            return
        end

        if not frame.statusText then
            return
        end

        if not frame.optionTable.displayStatusText then
            frame.statusText:Hide()
            return
        end

        local healthText = false

        if frame:IsShown() then
            local text = frame.statusText:GetText()

            if text and text:find("%d") then
                healthText = true
            end
        else
            healthText = true
        end

        if healthText then
            local displayedUnit = frame.displayedUnit

            if frame.optionTable.healthText == "health" then
                frame.statusText:SetText(UnitHealth(displayedUnit))
                frame.statusText:Show()
            elseif frame.optionTable.healthText == "losthealth" then
                local healthLost = UnitHealthMax(displayedUnit) - UnitHealth(displayedUnit)

                if healthLost > 0 then
                    frame.statusText:SetFormattedText(LOST_HEALTH, healthLost)
                    frame.statusText:Show()
                else
                    frame.statusText:Hide()
                end
            elseif frame.optionTable.healthText == "perc" and UnitHealthMax(displayedUnit) > 0 then
                local perc = math.ceil(100 * (UnitHealth(displayedUnit) / UnitHealthMax(displayedUnit)))
                frame.statusText:SetFormattedText("%d%%", perc)
                frame.statusText:Show()
            else
                frame.statusText:Hide()
            end
        end
    end
)

local function UnitFrameHealthBar_UpdateHealthEvents(healthbar)
    healthbar:UnregisterEvent("UNIT_MAXHEALTH")
    healthbar:UnregisterEvent("UNIT_HEALTH")
    healthbar:UnregisterEvent("UNIT_HEALTH_FREQUENT")

    InstantHealth.UnregisterCallback(healthbar, "UNIT_MAXHEALTH")
    InstantHealth.UnregisterCallback(healthbar, "UNIT_HEALTH")
    InstantHealth.UnregisterCallback(healthbar, "UNIT_HEALTH_FREQUENT")

    healthbar:SetScript("OnUpdate", nil)
    healthbar:SetScript("OnEvent", UnitFrameHealthBar_OnEvent)

    healthbar.frequentUpdates = healthbar.AnimatedLossBar and healthbar.frequentUpdates

    healthbar:UnregisterEvent("VARIABLES_LOADED")

    if healthbar.unit then
        if healthbar.frequentUpdates then
            healthbar:RegisterEvent("VARIABLES_LOADED")
        end

        if GetCVarBool("predictedHealth") and healthbar.frequentUpdates then
            healthbar:SetScript("OnUpdate", UnitFrameHealthBar_OnUpdate)
        else
            InstantHealth.RegisterCallback(healthbar, "UNIT_MAXHEALTH", UnitFrameHealthBar_OnHealthUpdate, healthbar)
            InstantHealth.RegisterCallback(healthbar, "UNIT_HEALTH", UnitFrameHealthBar_OnHealthUpdate, healthbar)
            InstantHealth.RegisterCallback(healthbar, "UNIT_HEALTH_FREQUENT", UnitFrameHealthBar_OnHealthUpdate, healthbar)
        end
    end
end

hooksecurefunc(
    "UnitFrame_SetUnit",
    function(self, unit, healthbar, manabar)
        UnitFrameHealthBar_UpdateHealthEvents(healthbar)
    end
)

hooksecurefunc(
    "UnitFrameHealthBar_OnEvent",
    function(self, event)
        if event == "VARIABLES_LOADED" then
            UnitFrameHealthBar_UpdateHealthEvents(self)
        end
    end
)

hooksecurefunc(
    "UnitFrameHealthBar_Update",
    function(statusbar, unit)
        if not statusbar or statusbar.lockValues then
            return
        end

        if unit == statusbar.unit then
            local maxValue = UnitHealthMax(unit)

            statusbar.forceHideText = false

            if maxValue == 0 then
                maxValue = 1
                statusbar.forceHideText = true
            end

            statusbar:SetMinMaxValues(0, maxValue)

            if statusbar.AnimatedLossBar then
                statusbar.AnimatedLossBar:UpdateHealthMinMax()
            end

            statusbar.disconnected = not UnitIsConnected(unit)

            if statusbar.disconnected then
                if not statusbar.lockColor then
                    statusbar:SetStatusBarColor(0.5, 0.5, 0.5)
                end

                statusbar:SetValue(maxValue)
                statusbar._CIH_currValue = maxValue
            else
                local currValue = UnitHealth(unit)

                if not statusbar.lockColor then
                    statusbar:SetStatusBarColor(0.0, 1.0, 0.0)
                end

                statusbar:SetValue(currValue)
                statusbar._CIH_currValue = currValue
            end
        end

        TextStatusBar_UpdateTextString(statusbar)
    end
)

hooksecurefunc(
    "UnitFrameHealthBar_OnUpdate",
    function(self)
        if not self.disconnected and not self.lockValues then
            local currValue = UnitHealth(self.unit)
            local animatedLossBar = self.AnimatedLossBar

            if currValue ~= self._CIH_currValue then
                if not self.ignoreNoUnit or UnitGUID(self.unit) then
                    if animatedLossBar then
                        animatedLossBar:UpdateHealth(currValue, self._CIH_currValue)
                    end

                    self:SetValue(currValue)
                    self._CIH_currValue = currValue

                    TextStatusBar_UpdateTextString(self)
                end
            end

            if animatedLossBar then
                animatedLossBar:UpdateLossAnimation(currValue)
            end
        end
    end
)

if not PlayerFrame.PlayerFrameHealthBarAnimatedLoss then
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss = Mixin(CreateFrame("StatusBar", nil, PlayerFrame), AnimatedHealthLossMixin)
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss:SetFrameLevel(PlayerFrame.healthbar:GetFrameLevel() - 1)
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss:OnLoad()
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss:SetUnitHealthBar(PlayerFrame.unit, PlayerFrame.healthbar)
    PlayerFrame.PlayerFrameHealthBarAnimatedLoss:Hide()

    function PlayerFrame.PlayerFrameHealthBarAnimatedLoss:UpdateLossAnimation(currentHealth)
        if self.animationStartTime then
            local animationValue, animationCompletePercent = self:GetHealthLossAnimationData(currentHealth, self.animationStartValue)

            self.animationCompletePercent = animationCompletePercent

            if animationCompletePercent >= 1 then
                self:CancelAnimation()
            else
                self:SetValue(animationValue)
            end
        end
    end
end
