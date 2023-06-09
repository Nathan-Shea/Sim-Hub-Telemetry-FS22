---Display a platform icon, depending on current and set platform.











local PlatformIconElement_mt = Class(PlatformIconElement, BitmapElement)


---
function PlatformIconElement.new(target, custom_mt)
    local self = PlatformIconElement:superClass().new(target, custom_mt or PlatformIconElement_mt)

    return self
end


---
function PlatformIconElement:delete()
    PlatformIconElement:superClass().delete(self)
end


---
function PlatformIconElement:copyAttributes(src)
    PlatformIconElement:superClass().copyAttributes(self, src)

    self.platformId = src.platformId
end


---Set the terrain layer to render
function PlatformIconElement:setPlatformId(platformId)
    local useOtherIcon = false

    -- On some platforms we can only show the icon for the same platform
    if GS_PLATFORM_ID == PlatformId.PS4 or GS_PLATFORM_ID == PlatformId.PS5 then
        if platformId ~= PlatformId.PS4 and platformId ~= PlatformId.PS5 then
            useOtherIcon = true
        end
    elseif GS_PLATFORM_ID == PlatformId.XBOX_ONE or GS_PLATFORM_ID == PlatformId.XBOX_SERIES then
        if platformId ~= PlatformId.XBOX_ONE and platformId ~= PlatformId.XBOX_SERIES then
            useOtherIcon = true
        end
    end

    if useOtherIcon then
        platformId = 0
    end

    self:setImageUVs(nil, unpack(GuiUtils.getUVs(PlatformIconElement.UVS[platformId])))
end
