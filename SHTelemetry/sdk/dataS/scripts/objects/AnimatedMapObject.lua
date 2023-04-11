---Class for animated map objects






local AnimatedMapObject_mt = Class(AnimatedMapObject, AnimatedObject)













---Creating animated object
-- @param integer id node id
function AnimatedMapObject:onCreate(id)
    local object = AnimatedMapObject.new(g_server ~= nil, g_client ~= nil)
    if object:load(id) then
        g_currentMission.onCreateObjectSystem:add(object, true)
        object:register(true)
    else
        object:delete()
    end
end


---Creating new instance of animated object class
-- @param boolean isServer is server
-- @param boolean isClient is client
-- @param table customMt custom metatable
-- @return table self new instance of object
function AnimatedMapObject.new(isServer, isClient, customMt)
    return AnimatedObject.new(isServer, isClient, customMt or AnimatedMapObject_mt)
end








---Load animated object attributes from object
-- @param integer nodeId id of object to load from
-- @return boolean success success
function AnimatedMapObject:load(nodeId)
    local xmlFilename = getUserAttribute(nodeId, "xmlFilename")
    if xmlFilename == nil then
        Logging.error("Missing 'xmlFilename' user attribute for AnimatedMapObject node '%s'!", getName(nodeId))
        return false
    end

    local baseDir = g_currentMission.loadingMapBaseDirectory
    if baseDir == "" then
        baseDir = Utils.getNoNil(self.baseDirectory, baseDir)
    end
    xmlFilename = Utils.getFilename(xmlFilename, baseDir)

    local index = getUserAttribute(nodeId, "index")
    if index == nil then
        Logging.error("Missing 'index' user attribute for AnimatedMapObject node '%s'!", getName(nodeId))
        return false
    end

    local xmlFile = XMLFile.load("AnimatedObject", xmlFilename, AnimatedMapObject.xmlSchema)
    if xmlFile == nil then
        return false
    end

    -- Find the index in the XML
    local key
    xmlFile:iterate("animatedObjects.animatedObject", function(_, objectKey)
        local configIndex = xmlFile:getString(objectKey.."#index")
        if configIndex == index then
            key = objectKey
            return true
        end
    end)

    if key == nil then
        Logging.error("index '%s' not found in AnimatedObject xml '%s'!", index, xmlFilename)
        return false
    end

    local result = AnimatedMapObject:superClass().load(self, nodeId, xmlFile, key, xmlFilename)

    xmlFile:delete()

    return result
end
