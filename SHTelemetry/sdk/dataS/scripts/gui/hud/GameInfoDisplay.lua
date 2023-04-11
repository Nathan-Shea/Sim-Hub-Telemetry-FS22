---HUD general game information display.
--
--Displays current game information. This includes weather, current account balance and time settings.









local GameInfoDisplay_mt = Class(GameInfoDisplay, HUDDisplayElement)


---Create a new instance of GameInfoDisplay.
-- @param string hudAtlasPath Path to the HUD texture atlas
function GameInfoDisplay.new(hudAtlasPath, moneyUnit, l10n)
    local backgroundOverlay = GameInfoDisplay.createBackground()
    local self = GameInfoDisplay:superClass().new(backgroundOverlay, nil, GameInfoDisplay_mt)

    self.moneyUnit = moneyUnit
    self.l10n = l10n
    self.missionStats = nil -- MissionStats reference, set on loading
    self.environment = nil -- Environment reference, set on loading

    self.showMoney = true
    self.showWeather = true
    self.showTemperature = true
    self.showTime = true
    self.showDate = true
    self.showTutorialProgress = false

    self.infoBoxes = {} -- array of created info boxes

    self.moneyBox = nil
    self.moneyIconOverlay = nil -- Overlay reference of money icon to swap money unit texture UVs when necessary

    self.timeBox = nil
    self.clockElement = nil
    self.timeScaleArrow = nil
    self.timeScaleArrowFast = nil
    self.clockHandLarge = nil
    self.clockHandSmall = nil

    self.dateBox = nil
    self.seasonElement = nil
    self.monthMaxSize = 0

    self.temperatureBox = nil
    self.temperatureIconStable = nil
    self.temperatureIconRising = nil
    self.temperatureIconDropping = nil

    self.weatherBox = nil
    self.weatherTypeIcons = {} -- weather type -> HUDElement

    self.tutorialBox = nil
    self.tutorialProgressBar = nil

    self.boxHeight = 0
    self.boxMarginWidth, self.boxMarginHeight = 0, 0

    self.moneyBoxWidth = 0
    self.moneyTextSize = 0
    self.moneyTextPositionX, self.moneyTextPositionY = 0, 0
    self.monthText = ""

    self.timeTextPositionX, self.timeTextPositionY = 0,0
    self.timeTextSize = 0
    self.timeScaleTextPositionX, self.timeScaleTextPositionY = 0, 0
    self.timeScaleTextSize = 0
    self.timeText = ""
    self.clockHandLargePivotX, self.clockHandLargePivotY = 0, 0
    self.clockHandSmallPivotX, self.clockHandSmallPivotY = 0, 0

    self.dateTextPositionX, self.dateTextPositionY = 0,0

    self.temperatureHighTextPositionX, self.temperatureHighTextPositionY = 0, 0
    self.temperatureLowTextPositionX, self.temperatureLowTextPositionY = 0, 0
    self.temperatureTextSize = 0
    self.temperatureDayText = ""
    self.temperatureNightText = ""

    self.tutorialBarWidth, self.tutorialBarHeight = 0, 0
    self.tutorialTextPositionX, self.tutorialTextPositionX = 0, 0
    self.tutorialTextSize = 0
    self.tutorialText = utf8ToUpper(l10n:getText(GameInfoDisplay.L10N_SYMBOL.TUTORIAL))

    self.weatherAnimation = TweenSequence.NO_SEQUENCE
    self.currentWeather = ""
    self.nextWeather = ""
    self.temperatureAnimation = TweenSequence.NO_SEQUENCE
    self.lastTutorialProgress = 1

    self:createComponents(hudAtlasPath)

    return self
end


---Set the money unit for displaying the account balance.
-- @param int moneyUnit Money unit ID, any of [GS_MONEY_EURO | GS_MONEY_POUND | GS_MONEY_DOLLAR]. Invalid values are substituted by GS_MONEY_DOLLAR.
function GameInfoDisplay:setMoneyUnit(moneyUnit)
    if moneyUnit ~= GS_MONEY_EURO and moneyUnit ~= GS_MONEY_POUND and moneyUnit ~= GS_MONEY_DOLLAR then
        moneyUnit = GS_MONEY_DOLLAR
    end

    self.moneyUnit = moneyUnit
    self.moneyCurrencyText = g_i18n:getCurrencySymbol(true)
end


---Set the MissionStats reference for displaying information.
-- @param table missionStats MissionStats reference, do not change
function GameInfoDisplay:setMissionStats(missionStats)
    self.missionStats = missionStats
end


---Set the mission information reference for base information display.
-- @param table missionInfo MissionInfo reference, do not change
function GameInfoDisplay:setMissionInfo(missionInfo)
    self.missionInfo = missionInfo
end


---Set the environment reference to use for weather information display.
-- @param table environment Environment reference, do not change
function GameInfoDisplay:setEnvironment(environment)
    self.environment = environment
end


---Set visibility of the money display.
function GameInfoDisplay:setMoneyVisible(isVisible)
    self.showMoney = isVisible
    self.moneyBox:setVisible(isVisible)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end


---Set visibility of time display.
function GameInfoDisplay:setTimeVisible(isVisible)
    self.showTime = isVisible
    self.timeBox:setVisible(isVisible)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end


---Set visibility of temperature display.
function GameInfoDisplay:setTemperatureVisible(isVisible)
    self.showTemperature = isVisible
    self.temperatureBox:setVisible(isVisible)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end


---Set visibility of weather display.
function GameInfoDisplay:setWeatherVisible(isVisible)
    self.showWeather = isVisible
    self.weatherBox:setVisible(isVisible)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end


---Set visibility of tutorial progress display.
function GameInfoDisplay:setTutorialVisible(isVisible)
    self.showTutorialProgress = isVisible
    self.tutorialBox:setVisible(isVisible)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end









---Set the current tutorial progress values.
-- @param float progress Progress expressed as a number between 0 and 1
function GameInfoDisplay:setTutorialProgress(progress)
    if self.showTutorialProgress and progress ~= self.lastTutorialProgress then
        progress = MathUtil.clamp(progress, 0, 1)
        self.lastTutorialProgress = progress
        self.tutorialProgressBar:setDimension(self.tutorialBarWidth * progress)
    end
end






---Update the game info display state.
function GameInfoDisplay:update(dt)
    if self.showTime then
        self:updateTime()
    end

    if self.showTemperature then
        self:updateTemperature()
    end

    if self.showWeather then
        self:updateWeather(dt)
    end

    self:updateBackground()
end








---Update time display.
function GameInfoDisplay:updateTime()
    local currentTime = self.environment.dayTime / (1000 * 60 * 60)
    local timeHours = math.floor(currentTime)
    local timeMinutes = math.floor((currentTime - timeHours) * 60)

    self.timeText = string.format("%02d:%02d", timeHours, timeMinutes)

    if self.missionInfo.timeScale < 1 then
        self.timeScaleText = string.format("%0.1f", self.missionInfo.timeScale)
    else
        self.timeScaleText = string.format("%d", self.missionInfo.timeScale)
    end

    self.monthText = g_i18n:formatDayInPeriod(nil, nil, true)
    self.seasonOverlay:setUVs(self.seasonOverlayUVs[self.environment.currentSeason])

    local hourRotation = -((currentTime % 12) / 12) * math.pi * 2
    local minutesRotation = -(currentTime - timeHours) * math.pi * 2

    self.clockHandSmall:setRotation(hourRotation)
    self.clockHandLarge:setRotation(minutesRotation)

    local isTimeScaleFast = self.missionInfo.timeScale > 1
    self.timeScaleArrow:setVisible(not isTimeScaleFast)
    self.timeScaleArrowFast:setVisible(isTimeScaleFast)
end


---Update temperature display.
function GameInfoDisplay:updateTemperature()
    local minTemp, maxTemp = self.environment.weather:getCurrentMinMaxTemperatures()
    self.temperatureDayText = string.format("%d?", maxTemp)
    self.temperatureNightText = string.format("%d?", minTemp)

    local trend = self.environment.weather:getCurrentTemperatureTrend()
    self.temperatureIconStable:setVisible(trend == 0)
    self.temperatureIconRising:setVisible(trend > 0)
    self.temperatureIconDropping:setVisible(trend < 0)
end


---
function GameInfoDisplay:getWeatherStates()
    local sixHours = 6 * 60 * 60 * 1000
    local env = self.environment

    local dayPlus6h, timePlus6h = env:getDayAndDayTime(env.dayTime + sixHours, env.currentMonotonicDay)

    local weatherState = env.weather:getCurrentWeatherType()
    local nextWeatherState = env.weather:getNextWeatherType(dayPlus6h, timePlus6h)

    return weatherState, nextWeatherState
end


---Update weather display
function GameInfoDisplay:updateWeather(dt)
    if not self.environment.weather:getIsReady() then
        return
    end

    local weatherState, nextWeatherState = self:getWeatherStates()

    weatherState = weatherState or WeatherType.SUN
    nextWeatherState = nextWeatherState or WeatherType.SUN

    local hasChange = self.currentWeather ~= weatherState or self.nextWeather ~= nextWeatherState
    if hasChange then
        self.currentWeather = weatherState
        self.nextWeather = nextWeatherState

        self:animateWeatherChange()
    end

    if not self.weatherAnimation:getFinished() then
        self.weatherAnimation:update(dt)
    end
end


---Get the game info display's width based on its visible info boxes.
-- @return float Game info display width of visible elements in screen space
function GameInfoDisplay:getVisibleWidth()
    local width = -self.boxMarginWidth -- money box has no right margin
    for _, box in pairs(self.infoBoxes) do
        if box:getVisible() then
            width = width + box:getWidth() + self.boxMarginWidth * 2
        end
    end

    if self.currentWeather == self.nextWeather then
        local boxWidth, _ = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.WEATHER_BOX)
        width = width - boxWidth / 2
    end

    return width
end


---Update sizes and positions of this elements and its children.
function GameInfoDisplay:updateSizeAndPositions()
    local width = self:getVisibleWidth()
    self:setDimension(width+g_safeFrameOffsetX, self:getHeight())

    local topRightX, topRightY = GameInfoDisplay.getBackgroundPosition(self:getScale())
    local bottomY = topRightY - self:getHeight()
    self:setPosition(topRightX - width, bottomY)

    -- update positions of info elements based on visibility
    local posX = topRightX
    local isRightMostBox = true
    for i, box in ipairs(self.infoBoxes) do -- iterate in order, info boxes stored from right to left
        if box:getVisible() then
            local leftMargin = self.boxMarginWidth
            local rightMargin = 0
            if i > 1 then
                rightMargin = self.boxMarginWidth
            end

            box:setPosition(posX - box:getWidth() - rightMargin, bottomY)
            posX = posX - box:getWidth() - leftMargin - rightMargin

            box.separator:setVisible(not isRightMostBox) -- all info boxes have their separators assigned as a field, see createComponents()
            isRightMostBox = false
        end
    end

    self:storeScaledValues()
end






---Draw the game info display.
function GameInfoDisplay:draw()
    GameInfoDisplay:superClass().draw(self)

    if self.showMoney then
        self:drawMoneyText()
    end

    if self.showTime then
        self:drawTimeText()
    end

    if self.showDate then
        self:drawDateText()
    end

    if self.showTemperature then
        self:drawTemperatureText()
    end

    if self.showTutorialProgress then
        self:drawTutorialText()
    end
end


---Draw the text part of the money display.
function GameInfoDisplay:drawMoneyText()
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(GameInfoDisplay.COLOR.TEXT))

    -- TODO(SR): Optimize?
    if g_currentMission.player ~= nil then
        local farm = g_farmManager:getFarmById(g_currentMission.player.farmId)

        local moneyText = g_i18n:formatMoney(farm.money, 0, false, true)
        renderText(self.moneyTextPositionX, self.moneyTextPositionY, self.moneyTextSize, moneyText)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(GameInfoDisplay.COLOR.ICON))
    renderText(self.moneyCurrencyPositionX, self.moneyCurrencyPositionY, self.moneyTextSize, self.moneyCurrencyText)
end


---Draw the text part of the time display.
function GameInfoDisplay:drawTimeText()
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(GameInfoDisplay.COLOR.TEXT))

    renderText(self.timeTextPositionX, self.timeTextPositionY, self.timeTextSize, self.timeText)
    renderText(self.timeScaleTextPositionX, self.timeScaleTextPositionY, self.timeScaleTextSize, self.timeScaleText)
end










---Draw the text part of the temperature display.
function GameInfoDisplay:drawTemperatureText()
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(GameInfoDisplay.COLOR.TEXT))

    renderText(self.temperatureHighTextPositionX, self.temperatureHighTextPositionY, self.temperatureTextSize, self.temperatureDayText)
    renderText(self.temperatureLowTextPositionX, self.temperatureLowTextPositionY, self.temperatureTextSize, self.temperatureNightText)
end


---Draw the text part of the tutorial progress display.
function GameInfoDisplay:drawTutorialText()
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(GameInfoDisplay.COLOR.TEXT))

    renderText(self.tutorialTextPositionX, self.tutorialTextPositionY, self.tutorialTextSize, self.tutorialText)
end


---Make an animation for a weather change.
function GameInfoDisplay:animateWeatherChange()
    local sequence = TweenSequence.new()

    for weatherType, icon in pairs(self.weatherTypeIcons) do
        local isCurrent = weatherType == self.currentWeather
        local isNext = weatherType == self.nextWeather
        local makeVisible = isCurrent or isNext

        if makeVisible and not icon:getVisible() then
            self:addActiveWeatherAnimation(sequence, isCurrent, icon)
        elseif not makeVisible and icon:getVisible() then
            self:addInactiveWeatherAnimation(sequence, icon)
        else
            self:addBecomeCurrentWeatherAnimation(sequence, icon)
        end
    end

    local isWeatherChanging = self.currentWeather ~= self.nextWeather
    self:addWeatherPositionAnimation(sequence, isWeatherChanging)

    sequence:start()
    self.weatherAnimation = sequence
end


---Animate a weather icon becoming active.
function GameInfoDisplay:addActiveWeatherAnimation(animationSequence, isCurrentWeatherIcon, icon)
    local fullColor = GameInfoDisplay.COLOR.ICON_WEATHER_NEXT
    if isCurrentWeatherIcon then
        fullColor = GameInfoDisplay.COLOR.ICON
    end

    local transparentColor = {fullColor[1], fullColor[2], fullColor[3], 0}
    local fadeInSequence = TweenSequence.new(icon)
    local fadeIn = MultiValueTween.new(icon.setColor, transparentColor, fullColor, HUDDisplayElement.MOVE_ANIMATION_DURATION)

    fadeInSequence:insertTween(fadeIn, 0)
    fadeInSequence:insertCallback(icon.setVisible, true, 0)

    fadeInSequence:start()
    animationSequence:insertTween(fadeInSequence, 0)
end


---Animate a weather icon becoming inactive.
function GameInfoDisplay:addInactiveWeatherAnimation(animationSequence, icon)
    local currentColor = {icon:getColor()}
    local transparentColor = {currentColor[1], currentColor[2], currentColor[3], 0}
    local fadeOutSequence = TweenSequence.new(icon)
    local fadeOut = MultiValueTween.new(icon.setColor, currentColor, transparentColor, HUDDisplayElement.MOVE_ANIMATION_DURATION)

    fadeOutSequence:insertTween(fadeOut, 0)
    fadeOutSequence:addCallback(icon.setVisible, false)

    fadeOutSequence:start()
    animationSequence:insertTween(fadeOutSequence, 0)
end


---Animate a weather icon becoming the current weather icon.
function GameInfoDisplay:addBecomeCurrentWeatherAnimation(animationSequence, icon)
    local currentColor = {icon:getColor()}
    local makeCurrent = MultiValueTween.new(icon.setColor, currentColor, GameInfoDisplay.COLOR.ICON, HUDDisplayElement.MOVE_ANIMATION_DURATION)
    makeCurrent:setTarget(icon)
    animationSequence:insertTween(makeCurrent, 0)
end


---Animate weather icon position changes.
function GameInfoDisplay:addWeatherPositionAnimation(animationSequence, isWeatherChanging)
    local icon = self.weatherTypeIcons[self.currentWeather]
    local boxPosX, boxPosY = self.weatherBox:getPosition()
    local centerX, centerY = boxPosX + self.weatherBox:getWidth() * 0.5, boxPosY + (self.weatherBox:getHeight() - icon:getHeight()) * 0.5

    if isWeatherChanging then
        local moveLeft = MultiValueTween.new(icon.setPosition, {icon:getPosition()}, {centerX - icon:getWidth(), centerY}, HUDDisplayElement.MOVE_ANIMATION_DURATION)
        moveLeft:setTarget(icon)
        animationSequence:insertTween(moveLeft, 0)

        local secondIcon = self.weatherTypeIcons[self.nextWeather]
        if secondIcon:getVisible() then
            local moveRight = MultiValueTween.new(secondIcon.setPosition, {secondIcon:getPosition()}, {centerX, centerY}, HUDDisplayElement.MOVE_ANIMATION_DURATION)
            moveRight:setTarget(secondIcon)
            animationSequence:insertTween(moveRight, 0)
        else
            secondIcon:setPosition(centerX, centerY)
        end
    else
        local iconPosX, iconPosY = icon:getPosition()
        if iconPosX ~= centerX or iconPosY ~= centerY and self.weatherAnimation:getFinished() then
            local move =  MultiValueTween.new(icon.setPosition, {icon:getPosition()}, {centerX, centerY}, HUDDisplayElement.MOVE_ANIMATION_DURATION)
            move:setTarget(icon)
            animationSequence:insertTween(move, 0)
        end
    end
end






---Get this element's base background position.
-- @param float uiScale Current UI scale factor
function GameInfoDisplay.getBackgroundPosition(uiScale)
    local offX, offY = getNormalizedScreenValues(unpack(GameInfoDisplay.POSITION.SELF))
    return 1 + offX * uiScale - g_safeFrameOffsetX, 1 - g_safeFrameOffsetY + offY * uiScale -- top right corner plus offset
end


---Set this element's UI scale factor.
-- @param float uiScale UI scale factor
function GameInfoDisplay:setScale(uiScale)
    GameInfoDisplay:superClass().setScale(self, uiScale, uiScale)
    self:storeScaledValues()
    self:updateSizeAndPositions()
end


---Store scaled positioning, size and offset values.
function GameInfoDisplay:storeScaledValues()
    self.boxHeight = self:scalePixelToScreenHeight(GameInfoDisplay.BOX_HEIGHT)
    self.boxMarginWidth, self.boxMarginHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.BOX_MARGIN)
    self.moneyBoxWidth = self:scalePixelToScreenWidth(GameInfoDisplay.SIZE.MONEY_BOX[1])
    self.moneyTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.MONEY)

    local moneyBoxPosX, moneyBoxPosY = self.moneyBox:getPosition()
    local textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.MONEY_TEXT)
    self.moneyTextPositionX = moneyBoxPosX + self.moneyBox:getWidth() + textOffX
    self.moneyTextPositionY = moneyBoxPosY + self.moneyBox:getHeight() * 0.5 - self.moneyTextSize * 0.5 + textOffY

    local x, y = self.moneyIconOverlay:getPosition()
    self.moneyCurrencyPositionX = self.moneyIconOverlay.width * 0.5 + x
    self.moneyCurrencyPositionY = self.moneyIconOverlay.height * 0.5 + y - self.moneyTextSize * 0.5 + textOffY

    local timeBoxPosX, timeBoxPosY = self.timeBox:getPosition()
    local _, timeBoxHeight = self.timeBox:getWidth(), self.timeBox:getHeight()
    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TIME_TEXT)
    self.timeTextPositionX = timeBoxPosX + textOffX
    self.timeTextPositionY = timeBoxPosY + timeBoxHeight * 0.5 + textOffY
    self.timeTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.TIME)

    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TIME_SCALE_TEXT)
    self.timeScaleTextPositionX = timeBoxPosX + textOffX
    self.timeScaleTextPositionY = timeBoxPosY + timeBoxHeight * 0.5 + textOffY
    self.timeScaleTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.TIME_SCALE)

    self.clockHandLargePivotX, self.clockHandLargePivotY = self:normalizeUVPivot(
        GameInfoDisplay.PIVOT.CLOCK_HAND_LARGE,
        GameInfoDisplay.SIZE.CLOCK_HAND_LARGE,
        GameInfoDisplay.UV.CLOCK_HAND_LARGE)
    self.clockHandSmallPivotX, self.clockHandSmallPivotY = self:normalizeUVPivot(
        GameInfoDisplay.PIVOT.CLOCK_HAND_SMALL,
        GameInfoDisplay.SIZE.CLOCK_HAND_SMALL,
        GameInfoDisplay.UV.CLOCK_HAND_SMALL)

    self.monthTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.MONTH)
    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.MONTH_TEXT)
    local dateBoxX, dateBoxY = self.dateBox:getPosition()
    self.monthTextPositionX = dateBoxX + self.seasonOverlay.width + textOffX
    self.monthTextPositionY = dateBoxY + textOffY + (self.dateBox:getHeight() - self.monthTextSize) * 0.5

    self.temperatureTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.TEMPERATURE)
    local tempBoxPosX, tempBoxPosY = self.temperatureBox:getPosition()
    local tempBoxWidth, tempBoxHeight = self.temperatureBox:getWidth(), self.temperatureBox:getHeight()
    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TEMPERATURE_HIGH)
    self.temperatureHighTextPositionX = tempBoxPosX + tempBoxWidth + textOffX
    self.temperatureHighTextPositionY = tempBoxPosY + tempBoxHeight * 0.5 + textOffY

    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TEMPERATURE_LOW)
    self.temperatureLowTextPositionX = tempBoxPosX + tempBoxWidth + textOffX
    self.temperatureLowTextPositionY = tempBoxPosY + tempBoxHeight * 0.5 + textOffY

    local tutorialBarX, tutorialBarY = self.tutorialProgressBar:getPosition()
    self.tutorialBarWidth, self.tutorialBarHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TUTORIAL_PROGRESS_BAR)
    textOffX, textOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TUTORIAL_TEXT)
    self.tutorialTextSize = self:scalePixelToScreenHeight(GameInfoDisplay.TEXT_SIZE.TUTORIAL)
    self.tutorialTextPositionX = tutorialBarX + textOffX
    self.tutorialTextPositionY = tutorialBarY + (self.tutorialBarHeight - self.tutorialTextSize) * 0.5 + textOffY
end






---Create the background overlay.
function GameInfoDisplay.createBackground()
    local posX, posY = GameInfoDisplay.getBackgroundPosition(1) -- top right corner
    local width, height = getNormalizedScreenValues(unpack(GameInfoDisplay.SIZE.SELF))
    width = width + g_safeFrameOffsetX
    local overlay = Overlay.new(nil, posX - width, posY - height, width, height)
    -- overlay:setUVs(g_colorBgUVs)
    -- overlay:setColor(0, 0, 0, 0.75)
    return overlay
end

















---Create required display components.
Also adds a separator HUDElement instance as a field (".separator") to all info boxes.
function GameInfoDisplay:createComponents(hudAtlasPath)
    local topRightX, topRightY = GameInfoDisplay.getBackgroundPosition(1)
    local bottomY = topRightY - self:getHeight()
    local marginWidth, _ = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.BOX_MARGIN)

    self.backgroundOverlay = self:createBackgroundOverlay()
    self.backgroundBaseX = topRightX

    -- create components from right to left
    local rightX = self:createMoneyBox(hudAtlasPath, topRightX, bottomY) - marginWidth
    self.moneyBox.separator = {setVisible=function() end} -- just use a dummy for the money box
    local sepX = rightX
    rightX = self:createTimeBox(hudAtlasPath, rightX - marginWidth, bottomY) - marginWidth

    local centerY = bottomY + self:getHeight() * 0.5
    local separator = self:createVerticalSeparator(hudAtlasPath, sepX, centerY)
    self.timeBox:addChild(separator)
    self.timeBox.separator = separator

    sepX = rightX
    rightX = self:createDateBox(hudAtlasPath, rightX - marginWidth, bottomY) - marginWidth

    separator = self:createVerticalSeparator(hudAtlasPath, sepX, centerY)
    self.dateBox:addChild(separator)
    self.dateBox.separator = separator

    sepX = rightX
    rightX = self:createTemperatureBox(hudAtlasPath, rightX - marginWidth, bottomY) - marginWidth

    separator = self:createVerticalSeparator(hudAtlasPath, sepX, centerY)
    self.temperatureBox:addChild(separator)
    self.temperatureBox.separator = separator

    sepX = rightX
    rightX = self:createWeatherBox(hudAtlasPath, rightX - marginWidth, bottomY) - marginWidth

    separator = self:createVerticalSeparator(hudAtlasPath, sepX, centerY)
    self.weatherBox:addChild(separator)
    self.weatherBox.separator = separator

    sepX = rightX
    self:createTutorialBox(hudAtlasPath, rightX - marginWidth, bottomY)

    separator = self:createVerticalSeparator(hudAtlasPath, sepX, centerY)
    self.tutorialBox:addChild(separator)
    self.tutorialBox.separator = separator

    -- update background size based on components:
    local width = self:getVisibleWidth()
    self:setDimension(width+g_safeFrameOffsetX, self:getHeight())
end


---Create the money display box.
function GameInfoDisplay:createMoneyBox(hudAtlasPath, rightX, bottomY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.MONEY_ICON)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.MONEY_BOX)
    local posX = rightX - boxWidth
    local posY = bottomY + (boxHeight - iconHeight) * 0.5

    local boxOverlay = Overlay.new(nil, posX, bottomY, boxWidth, boxHeight)
    local boxElement = HUDElement.new(boxOverlay)
    self.moneyBox = boxElement
    self:addChild(boxElement)
    table.insert(self.infoBoxes, self.moneyBox)

    local iconOverlay = Overlay.new(hudAtlasPath, posX, posY, iconWidth, iconHeight)
    iconOverlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.MONEY_ICON))
    iconOverlay:setColor(unpack(GameInfoDisplay.COLOR.ICON))

    self.moneyIconOverlay = iconOverlay
    boxElement:addChild(HUDElement.new(iconOverlay))

    self.moneyCurrencyText = g_i18n:getCurrencySymbol(true)

    return posX
end


---Create the time display box.
function GameInfoDisplay:createTimeBox(hudAtlasPath, rightX, bottomY)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TIME_BOX)
    local posX = rightX - boxWidth

    local boxOverlay = Overlay.new(nil, posX, bottomY, boxWidth, boxHeight)
    local boxElement = HUDElement.new(boxOverlay)
    self.timeBox = boxElement
    self:addChild(boxElement)
    table.insert(self.infoBoxes, self.timeBox)

    local clockWidth, clockHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TIME_ICON)
    local posY = bottomY + (boxHeight - clockHeight) * 0.5
    local clockOverlay = Overlay.new(hudAtlasPath, posX, posY, clockWidth, clockHeight)
    clockOverlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.TIME_ICON))
    clockOverlay:setColor(unpack(GameInfoDisplay.COLOR.ICON))
    local clockElement = HUDElement.new(clockOverlay)
    self.clockElement = clockElement
    boxElement:addChild(clockElement)

    posX, posY = posX + clockWidth * 0.5, posY + clockHeight * 0.5

    self.clockHandSmall = self:createClockHand(hudAtlasPath, posX, posY,
        GameInfoDisplay.SIZE.CLOCK_HAND_SMALL,
        GameInfoDisplay.UV.CLOCK_HAND_SMALL,
        GameInfoDisplay.COLOR.CLOCK_HAND_SMALL,
        GameInfoDisplay.PIVOT.CLOCK_HAND_SMALL)
    clockElement:addChild(self.clockHandSmall)

    self.clockHandLarge = self:createClockHand(hudAtlasPath, posX, posY,
        GameInfoDisplay.SIZE.CLOCK_HAND_LARGE,
        GameInfoDisplay.UV.CLOCK_HAND_LARGE,
        GameInfoDisplay.COLOR.CLOCK_HAND_LARGE,
        GameInfoDisplay.PIVOT.CLOCK_HAND_LARGE)
    clockElement:addChild(self.clockHandLarge)

    local arrowOffX, arrowOffY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TIME_SCALE_ARROW)
    posX, posY = rightX - boxWidth + clockWidth + arrowOffX, bottomY + boxHeight * 0.5 + arrowOffY

    self.timeScaleArrow = self:createTimeScaleArrow(hudAtlasPath, posX, posY,
        GameInfoDisplay.SIZE.TIME_SCALE_ARROW,
        GameInfoDisplay.UV.TIME_SCALE_ARROW)
    boxElement:addChild(self.timeScaleArrow)

    self.timeScaleArrowFast = self:createTimeScaleArrow(hudAtlasPath, posX, posY,
        GameInfoDisplay.SIZE.TIME_SCALE_ARROW_FAST,
        GameInfoDisplay.UV.TIME_SCALE_ARROW_FAST)
    boxElement:addChild(self.timeScaleArrowFast)

    return rightX - boxWidth
end







































---Create the temperature display box.
function GameInfoDisplay:createTemperatureBox(hudAtlasPath, rightX, bottomY)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TEMPERATURE_BOX)
    local posX = rightX - boxWidth

    local boxOverlay = Overlay.new(nil, posX, bottomY, boxWidth, boxHeight)
    local boxElement = HUDElement.new(boxOverlay)
    self.temperatureBox = boxElement
    self:addChild(boxElement)
    table.insert(self.infoBoxes, self.temperatureBox)

    self.temperatureIconStable = self:createTemperatureIcon(hudAtlasPath, posX, bottomY, boxHeight,
        GameInfoDisplay.UV.TEMPERATURE_ICON_STABLE, GameInfoDisplay.COLOR.ICON)
    boxElement:addChild(self.temperatureIconStable)

    self.temperatureIconRising = self:createTemperatureIcon(hudAtlasPath, posX, bottomY, boxHeight,
        GameInfoDisplay.UV.TEMPERATURE_ICON_RISING, GameInfoDisplay.COLOR.ICON)
    boxElement:addChild(self.temperatureIconRising)

    self.temperatureIconDropping = self:createTemperatureIcon(hudAtlasPath, posX, bottomY, boxHeight,
        GameInfoDisplay.UV.TEMPERATURE_ICON_DROPPING, GameInfoDisplay.COLOR.ICON)
    boxElement:addChild(self.temperatureIconDropping)

    return rightX - boxWidth
end


---Create the weather display box.
function GameInfoDisplay:createWeatherBox(hudAtlasPath, rightX, bottomY)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.WEATHER_BOX)
    local posX = rightX - boxWidth
    local boxOverlay = Overlay.new(nil, posX, bottomY, boxWidth, boxHeight)
    local boxElement = HUDElement.new(boxOverlay)
    self.weatherBox = boxElement
    self:addChild(boxElement)
    table.insert(self.infoBoxes, self.weatherBox)

    self.weatherBoxRight = rightX

    -- Use function so new weather types can be added
    local weatherUvs = self:getWeatherUVs()

    for weatherId, uvs in pairs(weatherUvs) do
        local weatherIcon = self:createWeatherIcon(hudAtlasPath, weatherId, boxHeight, uvs, GameInfoDisplay.COLOR.ICON)
        boxElement:addChild(weatherIcon)
        self.weatherTypeIcons[weatherId] = weatherIcon
    end

    return rightX - boxWidth
end


---Get UVs of the icons associated with the weather types
function GameInfoDisplay:getWeatherUVs()
    return { -- weather type and UV definition for iteration
        [WeatherType.SUN] = GameInfoDisplay.UV.WEATHER_ICON_CLEAR,
        [WeatherType.RAIN] = GameInfoDisplay.UV.WEATHER_ICON_RAIN,
        [WeatherType.CLOUDY] = GameInfoDisplay.UV.WEATHER_ICON_CLOUDY,
        [WeatherType.SNOW] = GameInfoDisplay.UV.WEATHER_ICON_SNOW
    }
end


---Create a weather icon for current and upcoming weather conditions.
-- @param string hudAtlasPath Path to HUD texture atlas
-- @param int weatherId Weather condition ID, as defined in WeatherType... constants
-- @param float boxHeight Screen space height of the box which will hold this icon
-- @param table uvs UV coordinates of the weather icon in the HUD texture atlas
-- @param table color Color RGBA array
-- @return table Weather icon HUDElement instance
function GameInfoDisplay:createWeatherIcon(hudAtlasPath, weatherId, boxHeight, uvs, color)
    local width, height = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.WEATHER_ICON)
    local overlay = Overlay.new(hudAtlasPath, 0, 0, width, height) -- position is set on update
    overlay:setUVs(GuiUtils.getUVs(uvs))

    local element = HUDElement.new(overlay)
    element:setVisible(false)

    return element
end


---Create a temperature icon to display stable or changing temperatures.
-- @param string hudAtlasPath Path to HUD texture atlas
-- @param float leftX Screen space left X position of newly created icon
-- @param float bottomY Screen space bottom Y position of the parent box
-- @param float boxHeight Screen space height of the parent box
-- @param table uvs UV coordinates of the icon in the HUD texture atlas
-- @param table color Color RGBA array
-- @return table Temperature icon HUDElement instance
function GameInfoDisplay:createTemperatureIcon(hudAtlasPath, leftX, bottomY, boxHeight, uvs, color)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TEMPERATURE_ICON)
    local posY = bottomY + (boxHeight - iconHeight) * 0.5
    local overlay = Overlay.new(hudAtlasPath, leftX, posY, iconWidth, iconHeight)
    overlay:setUVs(GuiUtils.getUVs(uvs))
    overlay:setColor(unpack(color))

    return HUDElement.new(overlay)
end


---Create a rotatable clock hand icon element.
-- @param string hudAtlasPath Path to HUD texture atlas
-- @param float posX Screen space X position of the clock hand
-- @param float posY Screen space Y position of the clock hand
-- @param table size Pixel size vector {width, height}
-- @param table uvs UV coordinates of the icon in the HUD texture atlas
-- @param table color Color RGBA array
-- @param table pivot UV pixel space rotation pivot coordinates
-- @return table Clock hand HUDElement instance
function GameInfoDisplay:createClockHand(hudAtlasPath, posX, posY, size, uvs, color, pivot)
    local pivotX, pivotY = self:normalizeUVPivot(pivot, size, uvs)
    local width, height = self:scalePixelToScreenVector(size)
    local clockHandOverlay = Overlay.new(hudAtlasPath, posX - pivotX, posY - pivotY, width, height)
    clockHandOverlay:setUVs(GuiUtils.getUVs(uvs))
    clockHandOverlay:setColor(unpack(color))

    local clockHandElement = HUDElement.new(clockHandOverlay)
    clockHandElement:setRotationPivot(pivotX, pivotY)

    return clockHandElement
end


---Create a time scale arrow icon element.
-- @param string hudAtlasPath Path to HUD texture atlas
-- @param float posX Screen space X position of the arrow
-- @param float posY Screen space Y position of the arrow
-- @param table size Pixel size vector {width, height}
-- @param table uvs UV coordinates of the icon in the HUD texture atlas
-- @return table Time scale arrow icon HUDElement instance
function GameInfoDisplay:createTimeScaleArrow(hudAtlasPath, posX, posY, size, uvs)
    local arrowWidth, arrowHeight = self:scalePixelToScreenVector(size)
    local arrowOverlay = Overlay.new(hudAtlasPath, posX, posY, arrowWidth, arrowHeight)
    arrowOverlay:setUVs(GuiUtils.getUVs(uvs))
    arrowOverlay:setColor(unpack(GameInfoDisplay.COLOR.ICON))
    return HUDElement.new(arrowOverlay)
end


---Create and return a vertical separator element.
function GameInfoDisplay:createVerticalSeparator(hudAtlasPath, posX, centerPosY)
    local width, height = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.SEPARATOR)
    width = math.max(width, 1 / g_screenWidth)

    local overlay = Overlay.new(hudAtlasPath, posX - width * 0.5, centerPosY - height * 0.5, width, height)
    overlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.SEPARATOR))
    overlay:setColor(unpack(GameInfoDisplay.COLOR.SEPARATOR))

    return HUDElement.new(overlay)
end


---Create the tutorial progress box.
function GameInfoDisplay:createTutorialBox(hudAtlasPath, rightX, bottomY)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TUTORIAL_BOX)
    local posX = rightX - boxWidth
    local boxOverlay = Overlay.new(nil, posX, bottomY, boxWidth, boxHeight)
    local boxElement = HUDElement.new(boxOverlay)
    self.tutorialBox = boxElement
    self:addChild(boxElement)
    table.insert(self.infoBoxes, self.tutorialBox)

    -- create progress bar background frame
    local offX, offY = self:scalePixelToScreenVector(GameInfoDisplay.POSITION.TUTORIAL_PROGRESS_BAR)
    local barWidth, barHeight = self:scalePixelToScreenVector(GameInfoDisplay.SIZE.TUTORIAL_PROGRESS_BAR)
    local barPosX, barPosY = rightX - barWidth + offX, bottomY + (boxHeight - barHeight) * 0.5 + offY

    local pixelX, pixelY = 1 / g_screenWidth, 1 / g_screenHeight
    local topLine = Overlay.new(hudAtlasPath, barPosX - pixelX, barPosY + barHeight, barWidth + pixelX * 2, pixelY)
    local bottomLine = Overlay.new(hudAtlasPath, barPosX - pixelX, barPosY - pixelY, barWidth + pixelX * 2, pixelY)
    local leftLine = Overlay.new(hudAtlasPath, barPosX - pixelX, barPosY, pixelX, barHeight)
    local rightLine = Overlay.new(hudAtlasPath, barPosX + barWidth, barPosY, pixelX, barHeight)

    for _, lineOverlay in pairs{topLine, bottomLine, leftLine, rightLine} do
        lineOverlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.SEPARATOR))
        lineOverlay:setColor(unpack(GameInfoDisplay.COLOR.SEPARATOR))
        local lineElement = HUDElement.new(lineOverlay)
        self.tutorialBox:addChild(lineElement)
    end

    -- create progress bar scalable overlay
    local barOverlay = Overlay.new(hudAtlasPath, barPosX, barPosY, barWidth, barHeight)
    barOverlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.SEPARATOR))
    barOverlay:setColor(unpack(GameInfoDisplay.COLOR.TUTORIAL_PROGRESS_BAR))
    local barElement = HUDElement.new(barOverlay)
    self.tutorialBox:addChild(barElement)
    self.tutorialProgressBar = barElement

    return rightX - boxWidth
end
