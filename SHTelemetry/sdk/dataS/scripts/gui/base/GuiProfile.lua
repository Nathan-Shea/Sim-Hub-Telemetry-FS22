---GUI element display profile.
--Holds GuiElement property data for re-use similar to a HTML/CSS definition.









local GuiProfile_mt = Class(GuiProfile)


---Create a new GuiProfile.
-- @param profiles Reference to loaded profiles table for inheritance checking.
-- @param traits Reference to loaded traits table for inheritance checking.
-- @return New GuiProfile instance
function GuiProfile.new(profiles, traits)
    local self = setmetatable({}, GuiProfile_mt)

    self.values = {}
    self.name = ""
    self.profiles = profiles
    self.traits = traits
    self.parent = nil

    return self
end


---Load profile data from XML.
-- @param xmlFile XML file handle
-- @param key Profile XML element node path
-- @param presets Table of presets for symbol resolution, {preset name=preset value}
-- @param isTrait Whether this profile is a trait
-- @return True if profile values could be loaded, false otherwise.
function GuiProfile:loadFromXML(xmlFile, key, presets, isTrait, isVariant)
    local name = getXMLString(xmlFile, key .. "#name")
    if name == nil then
        return false
    end

    self.name = name
    self.isTrait = isTrait or false
    self.parent = getXMLString(xmlFile, key .. "#extends")
    self.isVariant = isVariant

    if self.parent == self.name then
        error("Profile " .. name .. " extends itself")
    end

    -- If this is not a trait, resolve traits
    if not isTrait then
        local traits = getXMLString(xmlFile, key .. "#with")
        if traits ~= nil then
            local traitNames = traits:split(" ")

            -- Copy all values, overwriting previous ones.
            -- This is resolving of the traits.
            for i = #traitNames, 1, -1 do
                local traitName = traitNames[i]
                local trait = self.traits[traitName]

                if trait ~= nil then
                    for traitValueName, value in pairs(trait.values) do
                        self.values[traitValueName] = value
                    end
                else
                    print("Warning: Trait-profile '" .. traitName .. "' not found for trait '" .. self.name .. "'")
                end
            end
        end
    end

    local i = 0
    while true do
        local k = key .. ".Value(" .. i .. ")"
        local valueName = getXMLString(xmlFile, k .. "#name")
        local value = getXMLString(xmlFile, k .. "#value")
        if valueName == nil or value == nil then
            break
        end

        if value:startsWith("$preset_") then
            local preset = string.gsub(value, "$preset_", "")
            if presets[preset] ~= nil then
                value = presets[preset]
            else
                print("Warning: Preset '" .. preset .. "' is not defined in GuiProfile!")
            end
        end

        self.values[valueName] = value
        i = i + 1
    end

    return true
end


---Get a string value from this profile (and its ancestors) by name.
-- @param name Name of attribute value to retrieve
-- @param default Default value to use if the attribute is not defined.
function GuiProfile:getValue(name, default)
    local ret = default

    -- Try a special case
    if self.values[name .. g_baseUIPostfix] ~= nil and self.values[name .. g_baseUIPostfix] ~= "nil" then
        ret = self.values[name .. g_baseUIPostfix]

    -- Try definition in the profile
    elseif self.values[name] ~= nil and self.values[name] ~= "nil" then
        ret = self.values[name]

    -- Try the profile itself
    else
        if self.parent ~= nil then
            -- Try parent
            local parentProfile
            if self.isVariant then
                parentProfile = self.profiles[self.parent]
            else
                -- Follow the path of special variants so top-level variants update all children
                parentProfile = g_gui:getProfile(self.parent)
            end

            if parentProfile ~= nil and parentProfile ~= "nil" then
                ret = parentProfile:getValue(name, default)
            else
                print("Warning: Parent-profile '" .. self.parent .. "' not found for profile '" .. self.name .. "'")
            end
        end
    end

    return ret
end


---Get a boolean value from this profile (and its ancestors) by name.
-- @param name Name of attribute value to retrieve
-- @param default Default value to use if the attribute is not defined.
function GuiProfile:getBool(name, default)
    local value = self:getValue(name)
    local ret = default
    if value ~= nil and value ~= "nil" then
        ret = (value:lower() == "true")
    end

    return ret
end


---Get a number value from this profile (and its ancestors) by name.
-- @param name Name of attribute value to retrieve
-- @param default Default value to use if the attribute is not defined.
function GuiProfile:getNumber(name, default)
    local value = self:getValue(name)
    local ret = default
    if value ~= nil and value ~= "nil" then
        ret = tonumber(value)
    end

    return ret
end
