---HUD side notification element for mobile version
--
--Custom sub class of side notification with different uv's and text size









local SideNotificationMobile_mt = Class(SideNotificationMobile, SideNotification)


---Create a new SideNotificationMobile.
-- @param string hudAtlasPath Path to the HUD atlas texture
-- @return table SideNotificationMobile instance
function SideNotificationMobile.new(hudAtlasPath)
    return SideNotificationMobile:superClass().new(SideNotificationMobile_mt, hudAtlasPath)
end


---Store scaled positioning, size and offset values.
function SideNotificationMobile:storeScaledValues()
    SideNotificationMobile:superClass().storeScaledValues(self)

    self.textSize = self:scalePixelToScreenHeight(SideNotificationMobile.TEXT_SIZE.DEFAULT_NOTIFICATION)
end


---Create the background overlay.
function SideNotificationMobile:createBackground(hudAtlasPath)
    local overlay = SideNotificationMobile:superClass().createBackground(self, hudAtlasPath)

    overlay:setUVs(GuiUtils.getUVs(SideNotificationMobile.UV.DEFAULT_BACKGROUND))
    overlay:setColor(unpack(SideNotificationMobile.COLOR.DEFAULT_BACKGROUND))

    return overlay
end
