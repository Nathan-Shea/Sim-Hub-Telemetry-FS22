---Class for NightIllumination objects which are used for building windows that are illuminated at night













---Creating NightIllumination object
-- @param integer id ID of the node
function NightIllumination:onCreate(id)
    Logging.warning("i3d onCreate user-attribute 'NightIllumination' is deprecated. Please use 'Visiblity Condition'-Tab in GIANTS Editor for node '%s' instead", getName(id))
end
