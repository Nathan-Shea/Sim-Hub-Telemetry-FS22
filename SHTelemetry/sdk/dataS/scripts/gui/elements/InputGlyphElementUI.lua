










local InputGlyphElementUI_mt = Class(InputGlyphElementUI, GuiElement)


---
function InputGlyphElementUI.new(target, custom_mt)
    local self = GuiElement.new(target, custom_mt or InputGlyphElementUI_mt)

    self.color = {1, 1, 1, 1}

    return self
end


---
function InputGlyphElementUI:delete()
    if self.glyphElement ~= nil then
        self.glyphElement:delete()
        self.glyphElement = nil
    end

    InputGlyphElementUI:superClass().delete(self)
end


---
function InputGlyphElementUI:loadFromXML(xmlFile, key)
    InputGlyphElementUI:superClass().loadFromXML(self, xmlFile, key)

    self.color = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#glyphColor"), self.color)

    self:rebuildGlyph()
end


---
function InputGlyphElementUI:loadProfile(profile, applyProfile)
    InputGlyphElementUI:superClass().loadProfile(self, profile, applyProfile)

    self.color = GuiUtils.getColorArray(profile:getValue("glyphColor"), self.color)

    self:rebuildGlyph()
end


---
function InputGlyphElementUI:copyAttributes(src)
    InputGlyphElementUI:superClass().copyAttributes(self, src)

    self.color = table.copy(src.color)

    if src.glyphElement ~= nil then
        local actionNames = src.glyphElement.actionNames
        local actionText = src.glyphElement.actionText
        local actionTextSize = src.glyphElement.actionTextSize

        self:rebuildGlyph()
        self:setActions(actionNames, actionText, actionTextSize)
    end
end























---Draw the glyph
function InputGlyphElementUI:draw(clipX1, clipY1, clipX2, clipY2)
    InputGlyphElementUI:superClass().draw(self, clipX1, clipY1, clipX2, clipY2)

    if self.glyphElement ~= nil then
        self.glyphElement:draw(clipX1, clipY1, clipX2, clipY2)
    end
end


---Set glyph actions
function InputGlyphElementUI:setActions(actions, ...)
    if self.glyphElement ~= nil then
        self.glyphElement:setActions(actions, ...)

        -- The size could have changed
        if not self.didSetAbsolutePosition then
            self:updateAbsolutePosition()
        end

        -- A bit of a nasty thing: base size is based on original width and height of the element,
        -- but we change the width based on the content. We still need the original width in case position changes.
        if self.absSize[1] > 0 then
            self.originalWidth = self.originalWidth or self.absSize[1]
        end

        self.absSize[1] = self.glyphElement:getGlyphWidth()
        self.size[1] = self.absSize[1] / g_aspectScaleX

        if self.parent ~= nil and self.parent.invalidateLayout ~= nil then
            self.parent:invalidateLayout()
        end
    end
end
