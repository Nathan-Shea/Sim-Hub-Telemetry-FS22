---Render display as an overlay














local RenderElement_mt = Class(RenderElement, GuiElement)


---
function RenderElement.new(target, custom_mt)
    local self = GuiElement.new(target, custom_mt or RenderElement_mt)

    self.cameraPath = nil
    self.isRenderDirty = false
    self.overlay = 0
    self.shapesMask = 255 -- show all objects with bits 1-8 enabled
    self.lightMask = 67108864 -- per default only render lights with bit 26 enabled

    return self
end


---
function RenderElement:delete()
    self:destroyScene()

    RenderElement:superClass().delete(self)
end


---
function RenderElement:loadFromXML(xmlFile, key)
    RenderElement:superClass().loadFromXML(self, xmlFile, key)

    self.filename = getXMLString(xmlFile, key .. "#filename")
    self.cameraPath = getXMLString(xmlFile, key .. "#cameraNode")
    self.superSamplingFactor = getXMLInt(xmlFile, key .. "#superSamplingFactor")
    self.shapesMask = getXMLInt(xmlFile, key .. "#shapesMask") or self.shapesMask
    self.lightMask = getXMLInt(xmlFile, key .. "#lightMask") or self.lightMask

    self:addCallback(xmlFile, key.."#onRenderLoad", "onRenderLoadCallback")
end


---
function RenderElement:loadProfile(profile, applyProfile)
    RenderElement:superClass().loadProfile(self, profile, applyProfile)

    self.filename = profile:getValue("filename")
    self.cameraPath = profile:getValue("cameraNode")
    self.superSamplingFactor = profile:getNumber("superSamplingFactor")

    if applyProfile then
        self:setScene(self.filename)
    end
end


---
function RenderElement:copyAttributes(src)
    RenderElement:superClass().copyAttributes(self, src)

    self.filename = src.filename
    self.cameraPath = src.cameraPath
    self.superSamplingFactor = src.superSamplingFactor

    self.onRenderLoadCallback = src.onRenderLoadCallback
end


---Create the scene and the overlay. Call destroyScene to clean up resources.
function RenderElement:createScene()
    self:setScene(self.filename)
end


---Destroy the scene and the overlay, cleaning up resources.
function RenderElement:destroyScene()
    if self.loadingRequestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(self.loadingRequestId)
        self.loadingRequestId = nil
    end

    if self.overlay ~= 0 then
        delete(self.overlay)
        self.overlay = 0
    end

    if self.scene then
        delete(self.scene)
        self.scene = nil
    end
end


---
function RenderElement:setScene(filename)
    if self.scene ~= nil then
        delete(self.scene)
        self.scene = nil
    end

    if self.loadingRequestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(self.loadingRequestId)
        self.loadingRequestId = nil
    end

    self.isLoading = true
    self.filename = filename

    self.loadingRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, RenderElement.setSceneFinished, self, nil)
end


---
function RenderElement:setSceneFinished(node, failedReason, args)
    self.isLoading = false

    if failedReason == LoadI3DFailedReason.FILE_NOT_FOUND or failedReason == LoadI3DFailedReason.UNKNOWN then
        Logging.error("Failed to load character creation scene from '%s'", self.filename)
    end

    if failedReason == LoadI3DFailedReason.NONE then
        self.scene = node
        link(getRootNode(), node)

        -- The overlay is bound to the scene, so we need to recreate the overlay
        self:createOverlay()

    elseif node ~= 0 then
        delete(node)
    end
end


---
function RenderElement:createOverlay()
    if self.overlay ~= 0 then
        delete(self.overlay)
        self.overlay = 0
    end

    -- Use downsampling to imitate anti-aliasing, as the postFx for it is not available
    -- on render overlays
    local resolutionX = math.ceil(g_screenWidth * self.absSize[1]) * self.superSamplingFactor
    local resolutionY = math.ceil(g_screenHeight * self.absSize[2]) * self.superSamplingFactor

    local aspectRatio = resolutionX / resolutionY

    local camera = I3DUtil.indexToObject(self.scene, self.cameraPath)
    if camera == nil then
        Logging.error("Could not find camera node '%s' in scene", self.cameraPath)
    else
        self.overlay = createRenderOverlay(camera, aspectRatio, resolutionX, resolutionY, true, self.shapesMask, self.lightMask)

        self.isRenderDirty = true
        self:raiseCallback("onRenderLoadCallback", self.scene, self.overlay)
    end
end


---
function RenderElement:update(dt)
    RenderElement:superClass().update(self, dt)

    if self.isRenderDirty and self.overlay ~= 0 then
        updateRenderOverlay(self.overlay)
        self.isRenderDirty = false
    end
end


---
function RenderElement:draw(clipX1, clipY1, clipX2, clipY2)
    if not self.isLoading and self.overlay ~= 0 then

        local posX, posY, sizeX, sizeY = self.absPosition[1], self.absPosition[2], self.size[1], self.size[2]
        local u1, v1, u2, v2, u3, v3, u4, v4 = 0, 0, 0, 1, 1, 0, 1, 1

        -- Needs clipping
        if clipX1 ~= nil then
            local oldX1, oldY1, oldX2, oldY2 = posX, posY, sizeX + posX, sizeY + posY

            local posX2 = posX + sizeX
            local posY2 = posY + sizeY

            posX = math.max(posX, clipX1)
            posY = math.max(posY, clipY1)

            sizeX = math.max(math.min(posX2, clipX2) - posX, 0)
            sizeY = math.max(math.min(posY2, clipY2) - posY, 0)

            local p1 = (posX - oldX1) / (oldX2 - oldX1) -- start x
            local p2 = (posY - oldY1) / (oldY2 - oldY1) -- start y
            local p3 = ((posX + sizeX) - oldX1) / (oldX2 - oldX1) -- end x
            local p4 = ((posY + sizeY) - oldY1) / (oldY2 - oldY1) -- end y

            -- start x, start y
            u1 = p1
            v1 = p2

            -- start x, end y
            u2 = p1
            v2 = p4

            -- end x, start y
            u3 = p3
            v3 = p2

            -- end x, end y
            u4 = p3
            v4 = p4
        end

        if u1 ~= u3 and v1 ~= v2 then
            setOverlayUVs(self.overlay, u1, v1, u2, v2, u3, v3, u4, v4)
            renderOverlay(self.overlay, posX, posY, sizeX, sizeY)
        end
    end

    RenderElement:superClass().draw(self, clipX1, clipY1, clipX2, clipY2)
end








---
function RenderElement:getSceneRoot()
    return self.scene
end


---
function RenderElement:setRenderDirty()
    self.isRenderDirty = true
end
