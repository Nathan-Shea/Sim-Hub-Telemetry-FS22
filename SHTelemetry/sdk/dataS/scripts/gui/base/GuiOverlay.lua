---GUI overlay manager.
--Handles creation, loading and basic rendering of GUI overlays. This module has no interaction with Overlay.lua.















---Loads overlay data from XML or a profile into a table to turn it into an overlay.
function GuiOverlay.loadOverlay(self, overlay, overlayName, imageSize, profile, xmlFile, key)
    if overlay.uvs == nil then
        overlay.uvs = Overlay.DEFAULT_UVS
    end

    if overlay.color == nil then
        overlay.color = {1, 1, 1, 1}
    end

    local filename = nil
    local previewFilename = nil
    if xmlFile ~= nil then
        filename = getXMLString(xmlFile, key .. "#" .. overlayName .. "Filename")
        previewFilename = getXMLString(xmlFile, key .. "#" .. overlayName .. "PreviewFilename")

        GuiOverlay.loadXMLUVs(xmlFile, key, overlay, overlayName, imageSize)
        GuiOverlay.loadXMLColors(xmlFile, key, overlay, overlayName)

        overlay.sdfWidth = Utils.getNoNil(getXMLInt(xmlFile, key .. "#" .. overlayName .. "SdfWidth"), overlay.sdfWidth)
    elseif profile ~= nil then
        filename = profile:getValue(overlayName .. "Filename")
        previewFilename = profile:getValue(overlayName .. "PreviewFilename")

        GuiOverlay.loadProfileUVs(profile, overlay, overlayName, imageSize)
        GuiOverlay.loadProfileColors(profile, overlay, overlayName)

        overlay.sdfWidth = profile:getNumber(overlayName .. "SdfWidth", overlay.sdfWidth)
    end

    if filename == nil then
        return nil
    end

    if previewFilename == nil then
        previewFilename = "dataS/menu/blank.png"
    end

    if filename == "g_baseUIFilename" then
        filename = g_baseUIFilename
    elseif filename == "g_iconsUIFilename" then
        filename = g_iconsUIFilename
    end

    overlay.filename =  string.gsub(filename, "$l10nSuffix", g_gui.languageSuffix)
    overlay.previewFilename = previewFilename

    return overlay
end





































---Load overlay UV data from a profile.
function GuiOverlay.loadProfileUVs(profile, overlay, overlayName, imageSize)
    local uvs

    uvs = profile:getValue(overlayName .. "UVs")
    if uvs ~= nil then
        overlay.uvs = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "UVRotation"))
    end

    uvs = profile:getValue(overlayName .. "FocusedUVs")
    if uvs ~= nil then
        overlay.uvsFocused = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "FocusedUVRotation"))
    end

    uvs = profile:getValue(overlayName .. "PressedUVs")
    if uvs ~= nil then
        overlay.uvsPressed = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "UVRotation"))
    end

    uvs = profile:getValue(overlayName .. "SelectedUVs")
    if uvs ~= nil then
        overlay.uvsSelected = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "SelectedUVRotation"))
    end

    uvs = profile:getValue(overlayName .. "DisabledUVs")
    if uvs ~= nil then
        overlay.uvsDisabled = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "DisabledUVRotation"))
    end

    uvs = profile:getValue(overlayName .. "HighlightedUVs")
    if uvs ~= nil then
        overlay.uvsHighlighted = GuiUtils.getUVs(uvs, imageSize, nil, profile:getNumber(overlayName .. "HighlightedUVRotation"))
    end
end


---Load overlay color data from XML.
function GuiOverlay.loadXMLColors(xmlFile, key, overlay, overlayName)
    local color

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "Color"))
    if color ~= nil then
        overlay.color = color
    end

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "FocusedColor"))
    if color ~= nil then
        overlay.colorFocused = color
    end

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "PressedColor"))
    if color ~= nil then
        overlay.colorPressed = color
    end

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "SelectedColor"))
    if color ~= nil then
        overlay.colorSelected = color
    end

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "DisabledColor"))
    if color ~= nil then
        overlay.colorDisabled = color
    end

    color = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#" .. overlayName .. "HighlightedColor"))
    if color ~= nil then
        overlay.colorHighlighted = color
    end

    local rotation = getXMLFloat(xmlFile, key .. "#" .. overlayName .. "Rotation")
    if rotation ~= nil then
        overlay.rotation = math.rad(rotation)
    end

    local isWebOverlay = getXMLBool(xmlFile, key .. "#" .. overlayName .. "IsWebOverlay")
    if isWebOverlay ~= nil then
        overlay.isWebOverlay = isWebOverlay
    end
end


---Load overlay color data from a profile.
function GuiOverlay.loadProfileColors(profile, overlay, overlayName)
    local color

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "Color"))
    if color ~= nil then
        overlay.color = color
    end

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "FocusedColor"))
    if color ~= nil then
        overlay.colorFocused = color
    end

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "PressedColor"))
    if color ~= nil then
        overlay.colorPressed = color
    end

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "SelectedColor"))
    if color ~= nil then
        overlay.colorSelected = color
    end

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "DisabledColor"))
    if color ~= nil then
        overlay.colorDisabled = color
    end

    color = GuiUtils.getColorGradientArray(profile:getValue(overlayName .. "HighlightedColor"))
    if color ~= nil then
        overlay.colorHighlighted = color
    end

    local rotation = profile:getValue(overlayName .. "Rotation")
    if rotation ~= nil then
        overlay.rotation = math.rad(tonumber(rotation))
    end

    local isWebOverlay = profile:getBool(overlayName .. "IsWebOverlay")
    if isWebOverlay ~= nil then
        overlay.isWebOverlay = isWebOverlay
    end
end


---(Re-)Create an overlay.
-- @param overlay Overlay table, see loadOverlay()
-- @param filename Path to image file (can also be a URL for web images)
-- @return Overlay table with added image data
function GuiOverlay.createOverlay(overlay, filename)
    if filename ~= nil then
        filename = string.gsub(filename, "$l10nSuffix", g_gui.languageSuffix)
    end

    if overlay.overlay ~= nil and (overlay.filename == filename or filename == nil) then
        return overlay -- already created / loaded
    end

    -- delete previously created overlay, if necessary
    GuiOverlay.deleteOverlay(overlay)

    if filename ~= nil then
        overlay.filename = filename
    end

    if overlay.filename ~= nil then
        local imageOverlay
        if overlay.isWebOverlay == nil or not overlay.isWebOverlay or (overlay.isWebOverlay and not overlay.filename:startsWith("http")) then
            imageOverlay = createImageOverlay(overlay.filename)
        else
            imageOverlay = createWebImageOverlay(overlay.filename, overlay.previewFilename)
        end

        if imageOverlay ~= 0 then
            overlay.overlay = imageOverlay

            if overlay.sdfWidth ~= nil then
                setOverlaySignedDistanceFieldWidth(imageOverlay, overlay.sdfWidth)
            end
        end
    end

    overlay.rotation = Utils.getNoNil(overlay.rotation, 0)
    overlay.alpha = Utils.getNoNil(overlay.alpha, 1)

    return overlay
end


---Copy an overlay.
function GuiOverlay.copyOverlay(overlay, overlaySrc, overrideFilename)
    overlay.filename = overrideFilename or overlaySrc.filename
    overlay.uvs = {overlaySrc.uvs[1], overlaySrc.uvs[2], overlaySrc.uvs[3], overlaySrc.uvs[4], overlaySrc.uvs[5], overlaySrc.uvs[6], overlaySrc.uvs[7], overlaySrc.uvs[8]}
    overlay.color = table.copyIndex(overlaySrc.color)
    overlay.rotation = overlaySrc.rotation
    overlay.alpha = overlaySrc.alpha
    overlay.isWebOverlay = overlaySrc.isWebOverlay
    overlay.previewFilename = overlaySrc.previewFilename
    overlay.sdfWidth = overlaySrc.sdfWidth

    if overlaySrc.uvsFocused ~= nil then
        overlay.uvsFocused = {overlaySrc.uvsFocused[1], overlaySrc.uvsFocused[2], overlaySrc.uvsFocused[3], overlaySrc.uvsFocused[4], overlaySrc.uvsFocused[5], overlaySrc.uvsFocused[6], overlaySrc.uvsFocused[7], overlaySrc.uvsFocused[8]}
    end

    if overlaySrc.colorFocused ~= nil then
        overlay.colorFocused = table.copyIndex(overlaySrc.colorFocused)
    end

    if overlaySrc.uvsPressed ~= nil then
        overlay.uvsPressed = {overlaySrc.uvsPressed[1], overlaySrc.uvsPressed[2], overlaySrc.uvsPressed[3], overlaySrc.uvsPressed[4], overlaySrc.uvsPressed[5], overlaySrc.uvsPressed[6], overlaySrc.uvsPressed[7], overlaySrc.uvsPressed[8]}
    end

    if overlaySrc.colorPressed ~= nil then
        overlay.colorPressed = table.copyIndex(overlaySrc.colorPressed)
    end

    if overlaySrc.uvsSelected ~= nil then
        overlay.uvsSelected = {overlaySrc.uvsSelected[1], overlaySrc.uvsSelected[2], overlaySrc.uvsSelected[3], overlaySrc.uvsSelected[4], overlaySrc.uvsSelected[5], overlaySrc.uvsSelected[6], overlaySrc.uvsSelected[7], overlaySrc.uvsSelected[8]}
    end

    if overlaySrc.colorSelected ~= nil then
        overlay.colorSelected = table.copyIndex(overlaySrc.colorSelected)
    end

    if overlaySrc.uvsDisabled ~= nil then
        overlay.uvsDisabled = {overlaySrc.uvsDisabled[1], overlaySrc.uvsDisabled[2], overlaySrc.uvsDisabled[3], overlaySrc.uvsDisabled[4], overlaySrc.uvsDisabled[5], overlaySrc.uvsDisabled[6], overlaySrc.uvsDisabled[7], overlaySrc.uvsDisabled[8]}
    end

    if overlaySrc.colorDisabled ~= nil then
        overlay.colorDisabled = table.copyIndex(overlaySrc.colorDisabled)
    end

    if overlaySrc.uvsHighlighted ~= nil then
        overlay.uvsHighlighted = {overlaySrc.uvsHighlighted[1], overlaySrc.uvsHighlighted[2], overlaySrc.uvsHighlighted[3], overlaySrc.uvsHighlighted[4], overlaySrc.uvsHighlighted[5], overlaySrc.uvsHighlighted[6], overlaySrc.uvsHighlighted[7], overlaySrc.uvsHighlighted[8]}
    end

    if overlaySrc.colorHighlighted ~= nil then
        overlay.colorHighlighted = table.copyIndex(overlaySrc.colorHighlighted)
    end

    return GuiOverlay.createOverlay(overlay)
end


---Delete an overlay.
Primarily releases the associated image file handle.
function GuiOverlay.deleteOverlay(overlay)
    if overlay ~= nil and overlay.overlay ~= nil then
        delete(overlay.overlay)
        overlay.overlay = nil
    end
end


---Get an overlay's color for a given overlay state.
-- @param overlay Overlay table
-- @param state GuiOverlay.STATE_[...] constant value
-- @return Color as {red, green, blue, alpha} with all values in the range of [0, 1]
function GuiOverlay.getOverlayColor(overlay, state)
    local color = nil
    if state == GuiOverlay.STATE_NORMAL then
        color = overlay.color
    elseif state == GuiOverlay.STATE_DISABLED then
        color = overlay.colorDisabled
    elseif state == GuiOverlay.STATE_FOCUSED then
        color = overlay.colorFocused
    elseif state == GuiOverlay.STATE_SELECTED then
        color = overlay.colorSelected
    elseif state == GuiOverlay.STATE_HIGHLIGHTED then
        color = overlay.colorHighlighted
    elseif state == GuiOverlay.STATE_PRESSED then
        color = overlay.colorPressed
        if color == nil then
            color = overlay.colorFocused
        end
    end

    if color == nil then
        color = overlay.color
    end

    return color
end


---Get an overlay's UV coordinates for a given overlay state.
-- @param overlay Overlay table
-- @param state GuiOverlay.STATE_[...] constant value
-- @return UV coordinates as {u1, v1, u2, v2, u3, v3, u4x, v4} with all values in the range of [0, 1]
function GuiOverlay.getOverlayUVs(overlay, state)
    local uvs = nil
    if state == GuiOverlay.STATE_DISABLED then
        uvs = overlay.uvsDisabled
    elseif state == GuiOverlay.STATE_FOCUSED then
        uvs = overlay.uvsFocused
    elseif state == GuiOverlay.STATE_SELECTED then
        uvs = overlay.uvsSelected
    elseif state == GuiOverlay.STATE_HIGHLIGHTED then
        uvs = overlay.uvsHighlighted
    elseif state == GuiOverlay.STATE_PRESSED then
        uvs = overlay.uvsPressed
        if uvs == nil then
            uvs = overlay.uvsFocused
        end
    end
    if uvs == nil then
        uvs = overlay.uvs
    end

    return uvs
end


---Renders an overlay with the given parameters.
-- @param overlay Overlay table
-- @param posX Screen x position
-- @param posY Screen y position
-- @param sizeX Screen x size
-- @param sizeY Screen y size
-- @param state GuiOverlay.STATE_[...] constant for the required display state
function GuiOverlay.renderOverlay(overlay, posX, posY, sizeX, sizeY, state, clipX1, clipY1, clipX2, clipY2)
    if overlay.overlay ~= nil then
        local colors = GuiOverlay.getOverlayColor(overlay, state)

        -- if there is any alpha, draw.
        if colors[4] ~= 0 or (colors[8] ~= nil and (colors[8] ~= 0 or colors[12] ~= 0 or colors[16] ~= 0)) then
            if not overlay.hasCustomRotation then
                local pivotX, pivotY = sizeX / 2, sizeY / 2
                if overlay.customPivot ~= nil then
                    pivotX, pivotY = overlay.customPivot[1], overlay.customPivot[2]
                end

                setOverlayRotation(overlay.overlay, overlay.rotation, pivotX, pivotY)
            end

            local u1, v1, u2, v2, u3, v3, u4, v4 = unpack(GuiOverlay.getOverlayUVs(overlay, state))

            -- Needs clipping
            if clipX1 ~= nil then
                local oldX1, oldY1, oldX2, oldY2 = posX, posY, sizeX + posX, sizeY + posY

                local posX2 = posX + sizeX
                local posY2 = posY + sizeY

                posX = math.max(posX, clipX1)
                posY = math.max(posY, clipY1)

                sizeX = math.max(math.min(posX2, clipX2) - posX, 0)
                sizeY = math.max(math.min(posY2, clipY2) - posY, 0)

                if sizeX == 0 or sizeY == 0 then
                    return
                end

                local ou1, ov1, ou2, ov2, ou3, ov3, ou4, ov4 = u1, v1, u2, v2, u3, v3, u4, v4

                local p1 = (posX - oldX1) / (oldX2 - oldX1) -- start x
                local p2 = (posY - oldY1) / (oldY2 - oldY1) -- start y
                local p3 = ((posX + sizeX) - oldX1) / (oldX2 - oldX1) -- end x
                local p4 = ((posY + sizeY) - oldY1) / (oldY2 - oldY1) -- end y

                -- start x, start y
                u1 = (ou3-ou1)*p1 + ou1
                v1 = (ov2-ov1)*p2 + ov1

                -- start x, end y
                u2 = (ou3-ou1)*p1 + ou1
                v2 = (ov4-ov3)*p4 + ov3

                -- end x, start y
                u3 = (ou3-ou1)*p3 + ou1
                v3 = (ov2-ov1)*p2 + ov1

                -- end x, end y
                u4 = (ou4-ou2)*p3 + ou2
                v4 = (ov4-ov3)*p4 + ov3
            end

            setOverlayUVs(overlay.overlay, u1, v1, u2, v2, u3, v3, u4, v4)

            if colors[5] ~= nil then
                setOverlayCornerColor(overlay.overlay, 0, colors[1], colors[2], colors[3], colors[4] * overlay.alpha)
                setOverlayCornerColor(overlay.overlay, 1, colors[5], colors[6], colors[7], colors[8] * overlay.alpha)
                setOverlayCornerColor(overlay.overlay, 2, colors[9], colors[10], colors[11], colors[12] * overlay.alpha)
                setOverlayCornerColor(overlay.overlay, 3, colors[13], colors[14], colors[15], colors[16] * overlay.alpha)
            else
                local r,g,b,a = unpack(colors)
                setOverlayColor(overlay.overlay, r, g, b, a * overlay.alpha)
            end

            renderOverlay(overlay.overlay, posX, posY, sizeX, sizeY)
        end
    end
end











---Set this overlay's rotation.
-- @param rotation Rotation in radians
-- @param centerX Rotation pivot X position offset from overlay position in screen space
-- @param centerY Rotation pivot Y position offset from overlay position in screen space
function GuiOverlay.setRotation(overlay, rotation, centerX, centerY)
    setOverlayRotation(overlay.overlay, rotation, centerX, centerY)
    overlay.hasCustomRotation = true
end


---Set this overlay's color.
-- @param r red component of the color
-- @param g green component of the color
-- @param b blue component of the color
-- @param a alpha component of the color
function GuiOverlay.setColor(overlay, r, g, b, a)
    overlay.color = {r, g, b, a}
end
