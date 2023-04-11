---Vehicle HUD speed meter display element.
--
--Displays gauges for current speed, fuel level and vehicle wear / damage. Also shows operating time, textual speed
--display and cruise control state.









local SpeedMeterDisplay_mt = Class(SpeedMeterDisplay, HUDDisplayElement)


---Create a new SpeedMeterDisplay instance.
-- @param string hudAtlasPath Path to the HUD texture atlas
function SpeedMeterDisplay.new(hudAtlasPath)
    local backgroundOverlay = SpeedMeterDisplay.createBackground(hudAtlasPath)
    local self = SpeedMeterDisplay:superClass().new(backgroundOverlay, nil, SpeedMeterDisplay_mt)

    self.uiScale = 1.0 -- UI scale, only change after initialization and only using setScale()

    self.vehicle = nil -- currently controlled vehicle reference
    self.isVehicleDrawSafe = false -- safety flag for drawing, must always run one update after setting a vehicle before drawing

    self.speedIndicatorElement = nil -- speed meter needle indicator element
    self.speedGaugeSegmentElements = nil -- large gauge elements covering the area between two gauge notches
    self.speedGaugeSegmentPartElements = nil -- small gauge elements for detailed display
    self.speedIndicatorRadiusX = 0
    self.speedIndicatorRadiusY = 0
    self.speedTextOffsetY = 0
    self.speedUnitTextOffsetY = 0
    self.speedTextSize = 0
    self.speedUnitTextSize = 0
    self.speedKmh = 0 -- current vehicle velocity in km/h

    self.speedGaugeMode = g_gameSettings:getValue(GameSettings.SETTING.HUD_SPEED_GAUGE)
    self.speedGaugeUseMiles = g_gameSettings:getValue(GameSettings.SETTING.USE_MILES)
    self.rpmUnitTextOffsetY = 0
    self.rpmUnitTextSize = 0
    self.rpmUnitText = g_i18n:getText("unit_rpmShort")

    self.lastGaugeValue = 0

    self.speedGaugeElements = {}

    self.damageGaugeBackgroundElement = nil
    self.damageGaugeSegmentPartElements = nil
    self.damageGaugeIconElement = nil
    self.damageGaugeRadiusX = 0
    self.damageGaugeRadiusY = 0
    self.damageGaugeActive = false

    self.fuelGaugeBackgroundElement = nil
    self.fuelIndicatorElement = nil
    self.fuelGaugeSegmentPartElements = nil
    self.fuelGaugeIconElement = nil
    self.fuelIndicatorRadiusX = 0
    self.fuelIndicatorRadiusY = 0
    self.fuelGaugeRadiusX = 0
    self.fuelGaugeRadiusY = 0
    self.fuelGaugeActive = false
    self.fuelGaugeUVsDiesel = GuiUtils.getUVs(SpeedMeterDisplay.UV.FUEL_LEVEL_ICON)
    self.fuelGaugeUVsElectric = GuiUtils.getUVs(SpeedMeterDisplay.UV.FUEL_LEVEL_ICON_ELECTRIC)
    self.fuelGaugeUVsMethane = GuiUtils.getUVs(SpeedMeterDisplay.UV.FUEL_LEVEL_ICON_METHANE)

    self.cruiseControlElement = nil
    self.cruiseControlSpeed = 0
    self.cruiseControlColor = nil
    self.cruiseControlTextOffsetX = 0
    self.cruiseControlTextOffsetY = 0

    self.operatingTimeElement = nil
    self.operatingTimeText = ""
    self.operatingTimeTextSize = 1
    self.operatingTimeTextOffsetX = 0
    self.operatingTimeTextOffsetY = 0
    self.operatingTimeTextDrawPositionX = 0
    self.operatingTimeTextDrawPositionY = 0

    self.gearTextPositionY = 0
    self.gearGroupTextPositionY = 0
    self.gearTextSize = 0
    self.gearTexts = {"A", "B", "C"}
    self.gearGroupText = ""
    self.gearSelectedIndex = 1
    self.gearHasGroup = false
    self.gearIsChanging = false
    self.gearWarningTime = 0

    self.fadeFuelGaugeAnimation = TweenSequence.NO_SEQUENCE
    self.fadeDamageGaugeAnimation = TweenSequence.NO_SEQUENCE

    self.hudAtlasPath = hudAtlasPath
    self:createComponents(hudAtlasPath)

    return self
end




---Get this element's base position as a reference for other component's positioning.
function SpeedMeterDisplay:getBasePosition()
    local offX, offY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.GAUGE_BACKGROUND))
    local selfX, selfY = self:getPosition()
    return selfX + offX, selfY + offY
end


---Create display components for the speed meter.
Components are created with an implicit scale of 1. Scaling should only ever happen after initialization.
-- @param string hudAtlasPath Path to the HUD texture atlas
function SpeedMeterDisplay:createComponents(hudAtlasPath)
    local baseX, baseY = self:getBasePosition()
    self:storeScaledValues(baseX, baseY)

    -- create components in order of drawing:
    -- self.speedGaugeSegmentElements, self.speedGaugeSegmentPartElements = self:createSpeedGaugeElements(hudAtlasPath, baseX, baseY)

    self.gaugeBackgroundElement = self:createGaugeBackground(hudAtlasPath, baseX, baseY)

    self.damageGaugeIconElement, self.fuelGaugeIconElement = self:createGaugeIconElements(hudAtlasPath, baseX, baseY)

    self.damageBarElement = self:createDamageBar(hudAtlasPath, baseX, baseY)
    self.fuelBarElement = self:createFuelBar(hudAtlasPath, baseX, baseY)
    self.fuelBarElementBlinkTimer = 0

    self.gearElement = self:createGearIndicator(hudAtlasPath, baseX, baseY)

    self.speedIndicatorElement = self:createSpeedGaugeIndicator(hudAtlasPath, baseX, baseY)

    self.operatingTimeElement = self:createOperatingTimeElement(hudAtlasPath, baseX, baseY)
    self.operatingTimeElement:setVisible(false)
    self.cruiseControlElement = self:createCruiseControlElement(hudAtlasPath, baseX, baseY)
end


---Set the current vehicle which provides the data for the speed meter.
-- @param table vehicle Vehicle reference
function SpeedMeterDisplay:setVehicle(vehicle)
    local hadVehicle = self.vehicle ~= nil
    self.vehicle = vehicle

    local hasVehicle = vehicle ~= nil
    self.cruiseControlElement:setVisible(hasVehicle)

    local isMotorized = hasVehicle and vehicle.spec_motorized ~= nil
    local needFuelGauge = true
    -- enable/disable the fuel gauge based on the fuel tank capacity, i.e. if it consumes any fuel
    if hasVehicle and isMotorized then
        local _, capacity = SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(vehicle)
        needFuelGauge = capacity ~= nil

        if needFuelGauge then
            local fuelType = SpeedMeterDisplay.getVehicleFuelType(vehicle)
            local fuelGaugeIconUVs = self.fuelGaugeUVsDiesel
            if fuelType == FillType.ELECTRICCHARGE then
                fuelGaugeIconUVs = self.fuelGaugeUVsElectric
            elseif fuelType == FillType.METHANE then
                fuelGaugeIconUVs = self.fuelGaugeUVsMethane
            end
            self.fuelGaugeIconElement:setUVs(fuelGaugeIconUVs)
        end

        self:onHudSpeedGaugeModeChanged()
    end

    self.fuelGaugeActive = needFuelGauge
    self:animateFuelGaugeToggle(needFuelGauge)

    local needDamageGauge = hasVehicle and vehicle.getDamageAmount ~= nil and vehicle:getDamageAmount() ~= nil
    self.damageGaugeActive = needDamageGauge
    self:animateDamageGaugeToggle(needDamageGauge)

    local hasOperatingTime = hasVehicle and vehicle.operatingTime ~= nil
    self.operatingTimeElement:setVisible(hasOperatingTime)

    self.isVehicleDrawSafe = false -- use a safety flag here because setVehicle() can be called inbetween update and draw

    if hasVehicle and not hadVehicle then
        g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.HUD_SPEED_GAUGE], self.onHudSpeedGaugeModeChanged, self)
        g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_MILES], self.onHudSpeedGaugeUseMilesChanged, self)
    else
        g_messageCenter:unsubscribeAll(self)
    end
end






---Update the state of the speed meter.
function SpeedMeterDisplay:update(dt)
    SpeedMeterDisplay:superClass().update(self, dt)
    if not self.animation:getFinished() then
        local baseX, baseY = self.gaugeBackgroundElement:getPosition()
        self:storeScaledValues(baseX, baseY)
    end

    if self.vehicle ~= nil and self.vehicle.spec_motorized ~= nil then
        self:updateSpeedGauge(dt)
        self:updateDamageGauge(dt)
        self:updateFuelGauge(dt)
        self:updateCruiseControl(dt)
        self:updateOperatingTime(dt)
        self:updateGearDisplay(dt)
    end

    self.isVehicleDrawSafe = true
end


---Update gear drawing parameters.
function SpeedMeterDisplay:updateGearDisplay(dt)
    local gearName, gearGroupName, gearsAvailable, isAutomatic, prevGearName, nextGearName, prevPrevGearName, nextNextGearName, isGearChanging, showNeutralWarning = self.vehicle:getGearInfoToDisplay()

    -- With gears (with or without group) and not automatic, set up the texts
    if gearName ~= nil and not isAutomatic then
        self.gearHasGroup = gearGroupName ~= nil
        self.gearGroupText = gearGroupName or ""

        if nextGearName == nil and prevGearName == nil then
            self.gearTexts[1] = ""
            self.gearTexts[2] = gearName -- probably N
            self.gearTexts[3] = ""
            self.gearSelectedIndex = 2
        elseif nextGearName == nil then -- If there is no Next, this gear is the last gear
            self.gearTexts[1] = prevPrevGearName or ""
            self.gearTexts[2] = prevGearName
            self.gearTexts[3] = gearName
            self.gearSelectedIndex = 3
        elseif prevGearName == nil then -- if there is no Prev, this gear is the first gear
            self.gearTexts[1] = gearName
            self.gearTexts[2] = nextGearName
            self.gearTexts[3] = nextNextGearName or ""
            self.gearSelectedIndex = 1
        else -- Otherwise, we show it in the middle
            self.gearTexts[1] = prevGearName
            self.gearTexts[2] = gearName
            self.gearTexts[3] = nextGearName
            self.gearSelectedIndex = 2
        end
    elseif gearName ~= nil and isAutomatic then
        self.gearHasGroup = false
        self.gearGroupText = ""

        -- Order is D N R so that when switching from D to R we move over N
        self.gearTexts[1] = "R"
        self.gearTexts[2] = "N"
        self.gearTexts[3] = "D"

        if gearName == "N" then
            self.gearSelectedIndex = 2
        elseif gearName == "D" then
            self.gearSelectedIndex = 3
        elseif gearName == "R" then
            self.gearSelectedIndex = 1
        end
    end

    self.gearIsChanging = isGearChanging

    self:setGearGroupVisible(self.gearGroupText ~= "")
    self.gearSelectorIcon:setPosition(nil, self.gearSelectorPositions[self.gearSelectedIndex])

    if showNeutralWarning then
        self.gearWarningTime = self.gearWarningTime + dt
    else
        self.gearWarningTime = 0
    end
end


---Update operating time drawing parameters.
function SpeedMeterDisplay:updateOperatingTime(dt)
    if self.operatingTimeElement:getVisible() then
        local minutes = self.vehicle.operatingTime / (1000 * 60)
        local hours = math.floor(minutes / 60)
        minutes = math.floor((minutes - hours * 60) / 6)

        self.operatingTimeText = string.format(g_i18n:getText("shop_operatingTime"), hours, minutes)
        -- local textWidth = getTextWidth(self.operatingTimeTextSize, self.operatingTimeText)
        -- local operatingTimeWidth = self.operatingTimeElement:getWidth() + self.operatingTimeTextOffsetX + textWidth

        local posX, posY = self.operatingTimeElement:getPosition()
        -- local _, posY = self.operatingTimeElement:getPosition()

        -- posX = posX + (self:getWidth() - operatingTimeWidth) * 0.5

        self.operatingTimeTextDrawPositionX = posX + self.operatingTimeElement:getWidth() + self.operatingTimeTextOffsetX
        self.operatingTimeTextDrawPositionY = posY + self.operatingTimeTextOffsetY

        -- self.operatingTimeElement:setPosition(posX, nil)
        self.operatingTimeIsSafe = true
    end
end


---Update cruise control drawing parameters.
function SpeedMeterDisplay:updateCruiseControl(dt)
    local cruiseControlSpeed, isActive = self.vehicle:getCruiseControlDisplayInfo()
    self.cruiseControlSpeed = cruiseControlSpeed
    self.cruiseControlColor = isActive and SpeedMeterDisplay.COLOR.CRUISE_CONTROL_ON or SpeedMeterDisplay.COLOR.CRUISE_CONTROL_OFF

    self.cruiseControlElement:setColor(unpack(self.cruiseControlColor))
end


---Update a gauge indicator needle.
-- @param table Indicator HUDElement
-- @param float radiusX Radius X component of distance to the gauge center
-- @param float radiusY Radius Y component of distance to the gauge center
-- @param float rotation Rotation angle of the indicator in radians
function SpeedMeterDisplay:updateGaugeIndicator(indicatorElement, radiusX, radiusY, rotation)
    local pivotX, pivotY = indicatorElement:getRotationPivot()

    local cosRot = math.cos(rotation)
    local sinRot = math.sin(rotation)
    local posX = self.gaugeCenterX + cosRot * radiusX - pivotX
    local posY = self.gaugeCenterY + sinRot * radiusY - pivotY

    indicatorElement:setPosition(posX, posY)
    indicatorElement:setRotation(rotation - HALF_PI)
end


---Update the speed gauge state.
function SpeedMeterDisplay:updateSpeedGauge(dt)
    local lastSpeed = self.vehicle:getLastSpeed()
    local kmh = math.max(0, lastSpeed * self.vehicle.spec_motorized.speedDisplayScale)
    if kmh < 0.5 then
        kmh = 0
    end

    self.speedKmh = kmh -- used again for drawing the speed text

    local gaugeValue
    if self.speedGaugeMode == SpeedMeterDisplay.GAUGE_MODE_RPM then
        gaugeValue = MathUtil.clamp((self.vehicle:getMotorRpmReal() - self.speedGaugeMinValue) / (self.speedGaugeMaxValue - self.speedGaugeMinValue), 0, 1)
    else
        local scale = 1
        if self.speedGaugeUseMiles then
            scale = 0.621371
        end

        gaugeValue = MathUtil.clamp(((lastSpeed * scale) - self.speedGaugeMinValue) / (self.speedGaugeMaxValue - self.speedGaugeMinValue), 0, 1)
    end

    self.lastGaugeValue = self.lastGaugeValue * 0.95 + gaugeValue * 0.05

    local indicatorRotation = MathUtil.lerp(SpeedMeterDisplay.ANGLE.SPEED_GAUGE_MIN, SpeedMeterDisplay.ANGLE.SPEED_GAUGE_MAX, self.lastGaugeValue)
    self:updateGaugeIndicator(self.speedIndicatorElement, self.speedIndicatorRadiusX, self.speedIndicatorRadiusY, indicatorRotation)
end


---Update the damage gauge state.
function SpeedMeterDisplay:updateDamageGauge(dt)
    if not self.fadeDamageGaugeAnimation:getFinished() then
        self.fadeDamageGaugeAnimation:update(dt)
    end

    if self.damageGaugeActive then
        local gaugeValue = 1

        -- Show the most damage any item in the vehicle has
        local vehicles = self.vehicle.rootVehicle.childVehicles
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            if vehicle.getDamageShowOnHud ~= nil and vehicle:getDamageShowOnHud() then
                gaugeValue = math.min(gaugeValue, 1 - vehicle:getDamageAmount())
            end
        end
        self.damageBarElement:setValue(gaugeValue, "DAMAGE")

        local neededColor = SpeedMeterDisplay.COLOR.DAMAGE_GAUGE
        if gaugeValue < 0.2 then
            neededColor = SpeedMeterDisplay.COLOR.DAMAGE_GAUGE_LOW
        end
        self.damageBarElement:setBarColor(neededColor[1], neededColor[2], neededColor[3])
    end
end


---Get fuel level and capacity of a vehicle.
function SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(vehicle)
    local fuelType = FillType.DIESEL
    local fillUnitIndex = vehicle:getConsumerFillUnitIndex(fuelType)

    if fillUnitIndex == nil then
        fuelType = FillType.ELECTRICCHARGE
        fillUnitIndex = vehicle:getConsumerFillUnitIndex(fuelType)

        if fillUnitIndex == nil then
            fuelType = FillType.METHANE
            fillUnitIndex = vehicle:getConsumerFillUnitIndex(fuelType)
        end
    end

    local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
    local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)

    return level, capacity, fuelType
end


---Get fuel type of a vehicle.
function SpeedMeterDisplay.getVehicleFuelType(vehicle)
    if vehicle:getConsumerFillUnitIndex(FillType.DIESEL) ~= nil then
        return FillType.DIESEL
    elseif vehicle:getConsumerFillUnitIndex(FillType.ELECTRICCHARGE) ~= nil then
        return FillType.ELECTRICCHARGE
    elseif vehicle:getConsumerFillUnitIndex(FillType.METHANE) ~= nil then
        return FillType.METHANE
    end

    return FillType.DIESEL  -- default
end


---Update the fuel gauge state.
function SpeedMeterDisplay:updateFuelGauge(dt)
    if not self.fadeFuelGaugeAnimation:getFinished() then
        self.fadeFuelGaugeAnimation:update(dt)
    end

    if self.fuelGaugeActive then
        local level, capacity = SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(self.vehicle)

        if capacity > 0 then
            local levelPct = level / capacity
            local alpha = 1
            local color = SpeedMeterDisplay.COLOR.FUEL_GAUGE
            if levelPct < SpeedMeterDisplay.FUEL_LOW_PERCENTAGE then
                color =  SpeedMeterDisplay.COLOR.FUEL_GAUGE_LOW
                self.fuelBarElementBlinkTimer = self.fuelBarElementBlinkTimer + dt
                alpha = math.abs(math.cos(self.fuelBarElementBlinkTimer / 300))
            else
                self.fuelBarElementBlinkTimer = 0
            end

            self.fuelBarElement:setBarColor(color[1], color[2], color[3])
            self.fuelBarElement:setBarAlpha(alpha)
            self.fuelBarElement:setValue(levelPct, "FUEL")
        else
            self.fuelBarElement:setBarColor(SpeedMeterDisplay.COLOR.FUEL_GAUGE[1], SpeedMeterDisplay.COLOR.FUEL_GAUGE[2], SpeedMeterDisplay.COLOR.FUEL_GAUGE[3])
            self.fuelBarElement:setBarAlpha(1)
            self.fuelBarElement:setValue(1)
        end
    end
end


---Override of HUDDisplayElement.
Also updates the scaled values which are relative to the current position.
function SpeedMeterDisplay:onAnimateVisibilityFinished(isVisible)
    SpeedMeterDisplay:superClass().onAnimateVisibilityFinished(self, isVisible)

    local baseX, baseY = self.gaugeBackgroundElement:getPosition()
    self:storeScaledValues(baseX, baseY)
end






---Draw the speed meter.
function SpeedMeterDisplay:draw()
    if self.overlay.visible then
        self.overlay:render()

        for _, child in ipairs(self.children) do
            if child ~= self.speedIndicatorElement then
                child:draw()
            end
        end
    end

    if self.isVehicleDrawSafe and self:getVisible() then
        self:drawSpeedText()
        self:drawGearText()
        self:drawOperatingTimeText()
        self:drawCruiseControlText()
    end

    -- render speed indicator needle on top of gauge numbers
    new2DLayer()
    self.speedIndicatorElement:draw()
end


---Draw vehicle gear
-- @param table vehicle Current vehicle
function SpeedMeterDisplay:drawGearText()
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)

    local posX, posY = self.gearElement:getPosition()
    posX = posX + self.gearElement:getWidth() * 0.5

    -- If there is a gear group, draw it
    renderText(posX, posY + self.gearGroupTextPositionY, self.gearTextSize, self.gearGroupText)

    -- Draw all the gear texts, always 3. Values can be empty strings though
    for i = 1, 3 do
        local alpha = 1
        if i == 2 then
            alpha = math.abs(math.cos(self.gearWarningTime / 200))
        end

        if self.gearSelectedIndex == i and self.gearIsChanging then
            local r, g, b, a = unpack(SpeedMeterDisplay.COLOR.GEAR_TEXT_CHANGE)
            setTextColor(r, g, b, a * alpha)
        else
            local r, g, b, a = unpack(SpeedMeterDisplay.COLOR.GEAR_TEXT)
            setTextColor(r, g, b, a * alpha)
        end

        renderText(posX, posY + self.gearTextPositionY[i], self.gearTextSize, self.gearTexts[i])
    end

    setTextBold(false)
end


---Draw vehicle operating time if set.
-- @param table vehicle Current vehicle
function SpeedMeterDisplay:drawOperatingTimeText()
    if self.operatingTimeElement:getVisible() then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(1, 1, 1, 1)

        renderText(self.operatingTimeTextDrawPositionX, self.operatingTimeTextDrawPositionY, self.operatingTimeTextSize, self.operatingTimeText)
    end
end


---Draw the text portion of the cruise control element.
function SpeedMeterDisplay:drawCruiseControlText()
    if self.cruiseControlElement:getVisible() then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.cruiseControlColor))
        setTextBold(true)

        local speedText = string.format(g_i18n:getText("ui_cruiseControlSpeed"), g_i18n:getSpeed(self.cruiseControlSpeed))
        local baseX, baseY = self.cruiseControlElement:getPosition()
        local posX = baseX + self.cruiseControlElement:getWidth() + self.cruiseControlTextOffsetX
        local posY = baseY + self.cruiseControlTextOffsetY

        renderText(posX, posY, self.cruiseControlTextSize, speedText)
    end
end


---Draw the current speed in text.
function SpeedMeterDisplay:drawSpeedText()
    -- speed switches at 0.5 -> 0.5 - 1.5 = 1km/h; 1.5 - 2.5 = 2 km/h
    -- gives a much more smoother display if the cruise control is set
    local speedKmh = g_i18n:getSpeed(self.speedKmh)
    local speed = math.floor(speedKmh)
    if math.abs(speedKmh - speed) > 0.5 then
        speed = speed + 1
    end

    local speedI18N = string.format("%1d", speed)
    local speedUnit = utf8ToUpper(g_i18n:getSpeedMeasuringUnit())

    local baseX, baseY = self.gaugeBackgroundElement:getPosition()
    local centerPosX = baseX + self.gaugeBackgroundElement:getWidth() * 0.5

    setTextColor(unpack(SpeedMeterDisplay.COLOR.SPEED_TEXT))
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_CENTER)

    renderText(centerPosX, baseY + self.speedTextOffsetY, self.speedTextSize, speedI18N)

    setTextColor(unpack(SpeedMeterDisplay.COLOR.SPEED_UNIT))

    renderText(centerPosX, baseY + self.speedUnitTextOffsetY, self.speedUnitTextSize, speedUnit)

    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextColor(0.7, 0.7, 0.7, 0.65)

    for _, gaugeElement in pairs(self.speedGaugeElements) do
        if gaugeElement.text ~= nil then
            renderText(baseX + gaugeElement.textPosX, baseY + gaugeElement.textPosY, self.speedUnitTextSize, gaugeElement.text)
        end
    end

    if self.speedGaugeMode == SpeedMeterDisplay.GAUGE_MODE_RPM then
        renderText(centerPosX - self.gaugeBackgroundElement:getWidth() * 0.25, baseY + self.rpmUnitTextOffsetY * 0.34, self.rpmUnitTextSize, self.rpmUnitText)
        renderText(centerPosX + self.gaugeBackgroundElement:getWidth() * 0.25, baseY + self.rpmUnitTextOffsetY * 0.34, self.rpmUnitTextSize, "x100")
    end

    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
end


---Fade the fuel gauge elements.
function SpeedMeterDisplay:fadeFuelGauge(alpha)
    self.fuelBarElement:setAlpha(alpha)
    self.fuelGaugeIconElement:setAlpha(alpha)

    local visible = alpha > 0
    if visible ~= self.fuelBarElement:getVisible() then
        self.fuelBarElement:setVisible(visible)
        self.fuelGaugeIconElement:setVisible(visible)
    end
end


---Animate (de-)activation of the fuel gauge.
function SpeedMeterDisplay:animateFuelGaugeToggle(makeActive)
    local startAlpha = self.fuelBarElement:getAlpha()
    local endAlpha = makeActive and 1 or 0

    if self.fadeFuelGaugeAnimation:getFinished() then
        local sequence = TweenSequence.new(self)
        local fade = Tween.new(self.fadeFuelGauge, startAlpha, endAlpha, HUDDisplayElement.MOVE_ANIMATION_DURATION)
        sequence:addTween(fade)

        sequence:start()
        self.fadeFuelGaugeAnimation = sequence
    else -- if still animating, stop that and just set the visibility values immediately
        self.fadeFuelGaugeAnimation:stop()
        self:fadeFuelGauge(endAlpha)
    end
end


---Fade the damage gauge elements.
function SpeedMeterDisplay:fadeDamageGauge(alpha)
    self.damageGaugeIconElement:setAlpha(alpha)
    self.damageBarElement:setAlpha(alpha)

    local visible = alpha > 0
    if visible ~= self.damageBarElement:getVisible() then
        self.damageBarElement:setVisible(visible)
    end
end


---Animate (de-)activation of the damage gauge.
function SpeedMeterDisplay:animateDamageGaugeToggle(makeActive)
    local startAlpha = self.damageBarElement:getAlpha()
    local endAlpha = makeActive and 1 or 0

    if self.fadeDamageGaugeAnimation:getFinished() then
        local sequence = TweenSequence.new(self)
        local fade = Tween.new(self.fadeDamageGauge, startAlpha, endAlpha, HUDDisplayElement.MOVE_ANIMATION_DURATION)
        sequence:addTween(fade)

        sequence:start()
        self.fadeDamageGaugeAnimation = sequence
    else -- if still animating, stop that and just set the visibility values immediately
        self.fadeDamageGaugeAnimation:stop()
        self:fadeDamageGauge(endAlpha)
    end
end






---Set the speed meter scale.
Overrides HUDElement.setScale().
-- @param float uiScale UI scale factor, applied to both width and height dimensions
function SpeedMeterDisplay:setScale(uiScale)
    SpeedMeterDisplay:superClass().setScale(self, uiScale, uiScale)

    self.uiScale = uiScale

    local currentVisibility = self:getVisible()
    self:setVisible(true, false)
    -- update anchored position based on scaled values:
    local posX, posY = SpeedMeterDisplay.getBackgroundPosition(uiScale)
    self:setPosition(posX, posY)

    self:storeOriginalPosition()
    self:setVisible(currentVisibility, false)

    local baseX, baseY = self.gaugeBackgroundElement:getPosition()
    self:storeScaledValues(baseX, baseY)
end


---Calculate and store the gauge center position, including the current UI scale.
-- @param float baseX Gauge background element X position in screen space
-- @param float baseY Gauge background element Y position in screen space
function SpeedMeterDisplay:storeGaugeCenterPosition(baseX, baseY)
    -- local sizeRatioX = SpeedMeterDisplay.SIZE.GAUGE_BACKGROUND[1] / SpeedMeterDisplay.UV.GAUGE_BACKGROUND[3]
    -- local sizeRatioY = SpeedMeterDisplay.SIZE.GAUGE_BACKGROUND[2] / SpeedMeterDisplay.UV.GAUGE_BACKGROUND[4]
    -- local centerOffsetX = SpeedMeterDisplay.POSITION.GAUGE_CENTER[1] * sizeRatioX
    -- local centerOffsetY = SpeedMeterDisplay.POSITION.GAUGE_CENTER[2] * sizeRatioY
    -- local normOffsetX, normOffsetY = getNormalizedScreenValues(centerOffsetX, centerOffsetY)

    -- self.gaugeCenterX, self.gaugeCenterY = baseX + normOffsetX * self.uiScale, baseY + normOffsetY * self.uiScale

    local gaugeWidth, gaugeHeight = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.GAUGE_BACKGROUND))
    self.gaugeCenterX, self.gaugeCenterY = baseX + gaugeWidth * 0.5 * self.uiScale, baseY + gaugeHeight * 0.5 * self.uiScale
end


---Calculate and store scaling values based on the current UI scale.
-- @param float baseX Gauge background element X position in screen space
-- @param float baseY Gauge background element Y position in screen space
function SpeedMeterDisplay:storeScaledValues(baseX, baseY)
    self:storeGaugeCenterPosition(baseX, baseY)

    self.cruiseControlTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.CRUISE_CONTROL)
    self.cruiseControlTextOffsetX, self.cruiseControlTextOffsetY = self:scalePixelToScreenVector(SpeedMeterDisplay.POSITION.CRUISE_CONTROL_TEXT)

    self.operatingTimeTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.OPERATING_TIME)
    self.operatingTimeTextOffsetX, self.operatingTimeTextOffsetY = self:scalePixelToScreenVector(SpeedMeterDisplay.POSITION.OPERATING_TIME_TEXT)

    self.speedTextOffsetY = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.SPEED_TEXT[2])
    self.speedUnitTextOffsetY = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.SPEED_UNIT[2])
    self.speedTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.SPEED)
    self.speedUnitTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.SPEED_UNIT)

    self.rpmUnitTextOffsetY = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.SPEED_UNIT_TEXT[2])
    self.rpmUnitTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.RPM_UNIT)

    self.speedIndicatorRadiusX, self.speedIndicatorRadiusY = self:scalePixelToScreenVector(SpeedMeterDisplay.SIZE.GAUGE_INDICATOR_LARGE_RADIUS)

    self.gearTextPositionY = {}
    self.gearTextPositionY[1] = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_TEXT_1[2])
    self.gearTextPositionY[2] = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_TEXT_2[2])
    self.gearTextPositionY[3] = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_TEXT_3[2])
    self.gearGroupTextPositionY = self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_GROUP_TEXT[2])


    local circleHeight = self:scalePixelToScreenHeight(SpeedMeterDisplay.SIZE.GEAR_ICON_BG[2])
    local selectorHeight = self:scalePixelToScreenHeight(SpeedMeterDisplay.SIZE.GEAR_SELECTOR[2])

    local _, selfY = self:getPosition()
    local posY = selfY + self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_INDICATOR[2])
    self.gearGroupBgY = posY + self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_GROUP[2])
    self.gearIconBgY = posY + self:scalePixelToScreenHeight(SpeedMeterDisplay.POSITION.GEAR_ICON_BG[2])

    local by = posY + (circleHeight - selectorHeight) / 2
    self.gearSelectorPositions = {by, by + selectorHeight, by + selectorHeight * 2}

    self.gearTextSize = self:scalePixelToScreenHeight(SpeedMeterDisplay.TEXT_SIZE.GEAR)
end


---Called when speed gauge mode setting changes
function SpeedMeterDisplay:onHudSpeedGaugeModeChanged()
    self.speedGaugeMode = g_gameSettings:getValue(GameSettings.SETTING.HUD_SPEED_GAUGE)

    if self.vehicle ~= nil then
        local motorizedSpec = self.vehicle.spec_motorized
        if motorizedSpec ~= nil then
            if motorizedSpec.forceSpeedHudDisplay then
                self.speedGaugeMode = SpeedMeterDisplay.GAUGE_MODE_SPEED
            elseif motorizedSpec.forceRpmHudDisplay then
                self.speedGaugeMode = SpeedMeterDisplay.GAUGE_MODE_RPM
            end

            local motor = motorizedSpec.motor
            if self.speedGaugeMode == SpeedMeterDisplay.GAUGE_MODE_RPM then
                self:setupSpeedGauge(self.gaugeBackgroundElement, motor:getMinRpm(), motor:getMaxRpm(), 200)
            else
                local scale = 1
                if self.speedGaugeUseMiles then
                    scale = 0.621371
                end
                self:setupSpeedGauge(self.gaugeBackgroundElement, 0, motor:getMaximumForwardSpeed() * 3.6, 5, true, scale)
            end
        end
    end
end


---Called when use miles setting is changed
function SpeedMeterDisplay:onHudSpeedGaugeUseMilesChanged()
    self.speedGaugeUseMiles = g_gameSettings:getValue(GameSettings.SETTING.USE_MILES)
    if self.speedGaugeMode == SpeedMeterDisplay.GAUGE_MODE_SPEED then
        self:onHudSpeedGaugeModeChanged()
    end
end


---Get the position of the background element, which provides the SpeedMeterDisplay's absolute position.
-- @param float backgroundWidth Scaled background width in pixels
function SpeedMeterDisplay.getBackgroundPosition(scale)
    -- set position so that gauge background is properly aligned
    local gaugeWidth = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.BACKGROUND))
    local selfOffX, selfOffY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.SELF))

    return 1 - g_safeFrameOffsetX - gaugeWidth * scale + selfOffX, g_safeFrameOffsetY - selfOffY
end






---Create the background overlay for all contents of the speed meter
-- @param string hudAtlasPath Path to the HUD texture atlas
-- @return table Overlay instance
function SpeedMeterDisplay.createBackground(hudAtlasPath)
    local width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.BACKGROUND))
    local posX, posY = SpeedMeterDisplay.getBackgroundPosition(1) -- scale of 1 for initialization

    -- local background = Overlay.new(hudAtlasPath, posX, posY, width, height)
    -- background:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.SHADOW_BACKGROUND))
    -- background:setColor(unpack(SpeedMeterDisplay.COLOR.SHADOW_BACKGROUND))

    local background = Overlay.new(nil, posX, posY, width, height)
    -- background:setUVs(GuiUtils.getUVs({0,0,1024,1024}))
    -- background:setColor(1,1,1,1)


    return background
end


---Create the gauge background. This contains shadowing, ticks, coloring.
function SpeedMeterDisplay:createGaugeBackground(hudAtlasPath, baseX, baseY)
    local width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.GAUGE_BACKGROUND))
    local gaugeBackgroundOverlay = Overlay.new("dataS/menu/hud/hud_speedometer.png", baseX, baseY, width, height)
    gaugeBackgroundOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.GAUGE_BACKGROUND))

    local element = HUDElement.new(gaugeBackgroundOverlay)
    self:addChild(element)

    return element
end









































































































































---Create gauge icons.
function SpeedMeterDisplay:createGaugeIconElements(hudAtlasPath, baseX, baseY)
    local posX, posY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.DAMAGE_LEVEL_ICON))
    local width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.DAMAGE_LEVEL_ICON))
    local iconOverlay = Overlay.new(hudAtlasPath, baseX + posX, baseY + posY, width, height)
    iconOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.DAMAGE_LEVEL_ICON))

    local damageGaugeIconElement = HUDElement.new(iconOverlay)
    self:addChild(damageGaugeIconElement)

    posX, posY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.FUEL_LEVEL_ICON))
    width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.FUEL_LEVEL_ICON))
    iconOverlay = Overlay.new(hudAtlasPath, baseX + posX, baseY + posY, width, height)
    iconOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.FUEL_LEVEL_ICON))

    local fuelGaugeIconElement = HUDElement.new(iconOverlay)
    self:addChild(fuelGaugeIconElement)

    return damageGaugeIconElement, fuelGaugeIconElement
end


---Create the cruise control HUD element.
function SpeedMeterDisplay:createCruiseControlElement(hudAtlasPath, baseX, baseY)
    local posX, posY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.CRUISE_CONTROL))
    local width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.CRUISE_CONTROL))
    local cruiseControlOverlay = Overlay.new(hudAtlasPath, baseX + posX, baseY + posY, width, height)
    cruiseControlOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.CRUISE_CONTROL))

    local element = HUDElement.new(cruiseControlOverlay)
    self:addChild(element)
    return element
end


---Create the operating time HUD element.
function SpeedMeterDisplay:createOperatingTimeElement(hudAtlasPath, baseX, baseY)
    local operatingTimeWidth, operatingTimeHeight = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.OPERATING_TIME))
    local operatingTimeOffsetX, operatingTimeOffsetY = getNormalizedScreenValues(unpack(SpeedMeterDisplay.POSITION.OPERATING_TIME))

    local operatingTimeOverlay = Overlay.new(hudAtlasPath, baseX + operatingTimeOffsetX, baseY + operatingTimeOffsetY, operatingTimeWidth, operatingTimeHeight)
    operatingTimeOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.OPERATING_TIME))

    local element = HUDElement.new(operatingTimeOverlay)
    self:addChild(element)
    return element
end


---Create the indicator needle for the speed gauge.
function SpeedMeterDisplay:createSpeedGaugeIndicator(hudAtlasPath, baseX, baseY)
    local width, height = getNormalizedScreenValues(unpack(SpeedMeterDisplay.SIZE.GAUGE_INDICATOR_LARGE))
    local indicatorOverlay = Overlay.new(hudAtlasPath, 0, 0, width, height)
    indicatorOverlay:setUVs(GuiUtils.getUVs(SpeedMeterDisplay.UV.GAUGE_INDICATOR_LARGE))
    indicatorOverlay:setColor(unpack(SpeedMeterDisplay.COLOR.SPEED_GAUGE_INDICATOR))

    local indicatorElement = HUDElement.new(indicatorOverlay)
    local pivotX, pivotY = self:normalizeUVPivot(SpeedMeterDisplay.PIVOT.GAUGE_INDICATOR_LARGE, SpeedMeterDisplay.SIZE.GAUGE_INDICATOR_LARGE, SpeedMeterDisplay.UV.GAUGE_INDICATOR_LARGE)
    indicatorElement:setRotationPivot(pivotX, pivotY)

    self:addChild(indicatorElement)
    return indicatorElement
end
