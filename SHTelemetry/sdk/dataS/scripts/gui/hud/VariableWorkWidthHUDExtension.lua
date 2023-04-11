---Custom HUD drawing extension for VariableWorkWidth
--
--Displays the active partial sections









local VariableWorkWidthHUDExtension_mt = Class(VariableWorkWidthHUDExtension, VehicleHUDExtension)





---Create a new instance of VariableWorkWidthHUDExtension.
-- @param table vehicle Vehicle which has the specialization required by a sub-class
-- @param float uiScale Current UI scale
-- @param table uiTextColor HUD text drawing color as an RGBA array
-- @param float uiTextSize HUD text size
function VariableWorkWidthHUDExtension.new(vehicle, uiScale, uiTextColor, uiTextSize)
    local self = VehicleHUDExtension.new(VariableWorkWidthHUDExtension_mt, vehicle, uiScale, uiTextColor, uiTextSize)

    self.variableWorkWidth = vehicle.spec_variableWorkWidth

    local _, sectionHeight = getNormalizedScreenValues(0, 15 * uiScale)
    self.sectionOverlays = {}
    local numSections = #self.variableWorkWidth.sections
    for i=1, numSections do
        local section = self.variableWorkWidth.sections[i]

        local sectionOverlay = {}

        local overlay = Overlay.new(g_baseHUDFilename, 0, 0, 0, sectionHeight)
        overlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_LEFT)
        overlay:setUVs(GuiUtils.getUVs(HUDElement.UV.FILL))
        overlay:setColor(unpack(uiTextColor))
        self:addComponentForCleanup(overlay)

        sectionOverlay.overlay = overlay
        sectionOverlay.section = section

        if (i < numSections and self.variableWorkWidth.sections[i+1].isCenter) or section.isCenter or (not self.variableWorkWidth.hasCenter and i == numSections / 2)then
            local separatorWidth, separatorHeight = getNormalizedScreenValues(1, 35 * uiScale)
            separatorWidth = math.max(separatorWidth, 1 / g_screenWidth)
            local separator = Overlay.new(g_baseHUDFilename, 0, 0, separatorWidth, separatorHeight)
            separator:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_LEFT)
            separator:setUVs(GuiUtils.getUVs(HUDElement.UV.FILL))
            separator:setColor(unpack(VariableWorkWidthHUDExtension.COLOR.SEPARATOR))
            self:addComponentForCleanup(separator)

            sectionOverlay.separator = separator
        end

        table.insert(self.sectionOverlays, sectionOverlay)
    end

    local _, helpHeight = getNormalizedScreenValues(0, 75 * uiScale)

    self.displayHeight = helpHeight

    return self
end


---Determine if the HUD extension should be drawn.
function VariableWorkWidthHUDExtension:canDraw()
    return self.vehicle:getIsActiveForInput(true) and self.variableWorkWidth.drawInputHelp
end


---Get this HUD extension's display height.
-- @return float Display height in screen space
function VariableWorkWidthHUDExtension:getDisplayHeight()
    return self:canDraw() and self.displayHeight or 0
end


---Returns how many help entry slots should be removed for display of the hud extension
-- @return integer numSLots numSLots
function VariableWorkWidthHUDExtension:getHelpEntryCountReduction()
    return self:canDraw() and 1 or 0
end


---Draw mixing ratio information for a mixing wagon when it is active.
-- @param float leftPosX Left input help panel column start position
-- @param float rightPosX Right input help panel column start position
-- @param float posY Current input help panel drawing vertical offset
-- @return float Modified input help panel drawing vertical offset
function VariableWorkWidthHUDExtension:draw(leftPosX, rightPosX, posY)
    setTextColor(unpack(self.uiTextColor))
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(leftPosX, posY + self.displayHeight - self.uiTextSize * 1.7, self.uiTextSize, g_i18n:getText("info_partialWorkingWidth"))
    setTextBold(false)

    setTextAlignment(RenderText.ALIGN_RIGHT)
    local usage = self.vehicle:getVariableWorkWidthUsage()
    if usage ~= nil then
        usage = MathUtil.round(usage)
        renderText(rightPosX, posY + self.displayHeight - self.uiTextSize * 1.7, self.uiTextSize, string.format(g_i18n:getText("info_workWidthAndUsage"), usage, self.vehicle:getWorkAreaWidth(self.variableWorkWidth.widthReferenceWorkArea)))
    else
        renderText(rightPosX, posY + self.displayHeight - self.uiTextSize * 1.7, self.uiTextSize, string.format(g_i18n:getText("info_workWidth"), self.vehicle:getWorkAreaWidth(self.variableWorkWidth.widthReferenceWorkArea)))
    end

    local numSections = #self.sectionOverlays
    local _, yOffset = getNormalizedScreenValues(0, 25 * self.uiScale)
    local fullWidth = (rightPosX - leftPosX)
    local sectionWidth = fullWidth / numSections
    local sideOffset = sectionWidth * 0.1
    for i=1, numSections do
        local overlay = self.sectionOverlays[i].overlay

        local color = VariableWorkWidthHUDExtension.COLOR.SECTION_ACTIVE
        if not self.sectionOverlays[i].section.isActive then
            color = VariableWorkWidthHUDExtension.COLOR.SECTION_INACTIVE
        end
        local posX = leftPosX + sectionWidth * (i - 1) * (1 + (sectionWidth * 0.2) / fullWidth)
        local width = sectionWidth * 0.8
        overlay:setPosition(posX, posY + yOffset)
        overlay:setDimension(width)
        overlay:setColor(unpack(color))
        overlay:render()

        local separator = self.sectionOverlays[i].separator
        if separator ~= nil then
            separator:setPosition(posX + width + sideOffset - separator.width * 0.5, posY + yOffset)
            separator:render()
        end
    end

    return posY
end
