---Class for nightlight objects which are blending in on night







---Creating nightlight object
-- @param integer id ID of the node
function Nightlight2:onCreate(id)
    Logging.warning("i3d onCreate user-attribute 'Nightlight2' is deprecated. Please use 'Visiblity Condition'-Tab in GIANTS Editor for node '%s' instead", getName(id))
end
