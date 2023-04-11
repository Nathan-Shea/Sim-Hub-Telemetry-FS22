---Custom vehicle HUD drawing extension.
--
--This serves as the base class for custom specific drawing cases of vehicles in the HUD, e.g. MixerWagon fill levels.
--
--To create new HUD extensions for vehicle specializations:
--1. sub-class this base class
--2. source() the sub-class module after its corresponding specialization's table has been declared
--3. call VehicleHUDExtension.registerHUDExtension([specialization], [HUDextension]) in sub-class module









local VehicleHUDExtension_mt = Class(VehicleHUDExtension)

---Base constructor for vehicle HUD extensions.
-- @param table class_mt Sub-class metatable
-- @param table vehicle Vehicle which has the specialization required by a sub-class
-- @param float uiScale Current UI scale
-- @param table uiTextColor HUD text drawing color as an RGBA array
-- @param float uiTextSize HUD text size
function VehicleHUDExtension.new(class_mt, vehicle, uiScale, uiTextColor, uiTextSize)
    local self = setmetatable({}, class_mt or VehicleHUDExtension_mt)

    -- vehicle specialization reference which provides the display data
    self.vehicle = vehicle

    self.uiTextColor = uiTextColor
    self.uiTextSize = uiTextSize
    self.uiScale = uiScale

    -- array of created display components which need to be deleted
    self.displayComponents = {}

    return self
end


---Delete this instance and clean up resources.
function VehicleHUDExtension:delete()
    for k, component in pairs(self.displayComponents) do
        component:delete()
        self.displayComponents[k] = nil
    end
end


---Add a display component for cleanup on delete().
Added components must support delete() themselves or they will be ignored.
function VehicleHUDExtension:addComponentForCleanup(component)
    if component.delete then
        table.insert(self.displayComponents, component)
    end
end


---Get this HUD extension's display height.
Override in subclasses.
function VehicleHUDExtension:getDisplayHeight()
    return 0
end


---Determine if this HUD extension is in a valid state for a call to draw() in the current frame.
Override in sub-classes with custom logic.
-- @return bool If true, the HUD extension should be drawn in the current frame.
function VehicleHUDExtension:canDraw()
    return true
end


---Draw HUD extension.
-- @param float leftPosX Left input help panel column start position
-- @param float rightPosX Right input help panel column start position
-- @param float posY Current input help panel drawing vertical offset
-- @return float Modified input help panel drawing vertical offset
function VehicleHUDExtension:draw(leftPosX, rightPosX, posY)
end


---Priority index to define rendering order
function VehicleHUDExtension:getPriority()
    return 0
end








---Register a HUD extension for a specialization.
-- @param table specializationType Vehicle specialization class type table
-- @param table hudExtensionType HUD extension class type table corresponding to the given vehicle specialization
function VehicleHUDExtension.registerHUDExtension(spec, hudExtensionType)
    registry[spec] = hudExtensionType
end


---HUD extension factory method, creates a HUD extension for a given vehicle specialization.
-- @param table spec Specialization reference
-- @param table vehicle Vehicle which has the given specialization
-- @param float uiScale Current UI scale
-- @param table uiTextColor HUD text drawing color as an RGBA array
-- @param float uiTextSize HUD text size
-- @return table HUD extension instance or nil of no extension has been registered for the given specialization
function VehicleHUDExtension.createHUDExtensionForSpecialization(spec, vehicle, uiScale, uiTextColor, uiTextSize)
    local extType = registry[spec]
    local extension = nil
    if extType then
        extension = extType.new(vehicle, uiScale, uiTextColor, uiTextSize)
    end

    return extension
end


---Check if there is a HUD extension for a given specialization.
function VehicleHUDExtension.hasHUDExtensionForSpecialization(spec)
    return not not registry[spec]
end


---Sort function to sort hud extensions based on prio
function VehicleHUDExtension.sortHUDExtensions(extensionA, extensionB)
    return extensionA:getPriority() > extensionB:getPriority()
end
