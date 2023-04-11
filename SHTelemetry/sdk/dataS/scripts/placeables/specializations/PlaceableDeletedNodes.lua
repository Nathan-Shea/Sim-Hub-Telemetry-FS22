---Specialization for placeables













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableDeletedNodes.prerequisitesPresent(specializations)
    return true
end


---
function PlaceableDeletedNodes.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoadFinished", PlaceableDeletedNodes)
end


---
function PlaceableDeletedNodes.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DeletedNodes")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".deletedNodes.deletedNode(?)#node", "The node that should be deleted")
    schema:setXMLSpecializationType()
end


---Called on loading
-- @param table savegame savegame
function PlaceableDeletedNodes:onLoadFinished(savegame)

    if self.xmlFile ~= nil then
        local nodes = {}
        self.xmlFile:iterate("placeable.deletedNodes.deletedNode", function(_, key)
            local node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
            table.insert(nodes, node)
        end)

        -- loop over node again and delete them to avoid conflicts with index pathes
        for _, node in ipairs(nodes) do
            delete(node)
        end
    end
end
