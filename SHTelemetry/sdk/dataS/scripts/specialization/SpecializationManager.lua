---This class handles all specializations









local SpecializationManager_mt = Class(SpecializationManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function SpecializationManager.new(typeName, xmlFilename, customMt)
    local self = AbstractManager.new(customMt or SpecializationManager_mt)

    self.typeName = typeName
    self.xmlFilename = xmlFilename

    return self
end


---Initialize data structures
function SpecializationManager:initDataStructures()
    self.specializations = {}
    self.sortedSpecializations = {}
end


---Load data on map load
-- @return boolean true if loading was successful else false
function SpecializationManager:loadMapData()
    SpecializationManager:superClass().loadMapData(self)

    local xmlFile = loadXMLFile("SpecializationsXML", self.xmlFilename)
    local i=0
    while true do
        local baseName = string.format("specializations.specialization(%d)", i)

        local typeName = getXMLString(xmlFile, baseName.. "#name")
        if typeName == nil then
            break
        end
        local className = getXMLString(xmlFile, baseName.. "#className")
        local filename = getXMLString(xmlFile, baseName.. "#filename")

        g_asyncTaskManager:addSubtask(function()
            self:addSpecialization(typeName, className, filename, "")
        end)
        i = i+1
    end
    delete(xmlFile)

    g_asyncTaskManager:addSubtask(function()
        print(string.format("  Loaded '%s' specializations", self.typeName))
    end)

    return true
end


---Adds a new vehicleType
-- @param string name specialization name
-- @param string className classname
-- @param string filename filename
-- @param string customEnvironment a custom environment
-- @return boolean success true if added else false
function SpecializationManager:addSpecialization(name, className, filename, customEnvironment)

    if self.specializations[name] ~= nil then
        Logging.error("Specialization '%s' already exists. Ignoring it!", tostring(name))
        return false
    elseif className == nil then
        Logging.error("No className specified for specialization '%s'", tostring(name))
        return false
    elseif filename == nil then
        Logging.error("No filename specified for specialization '%s'", tostring(name))
        return false
    else

        local specialization = {}
        specialization.name = name
        specialization.className = className
        specialization.filename = filename

        source(filename, customEnvironment)

        local specializationObject = ClassUtil.getClassObject(className)
        if specializationObject ~= nil then
            specializationObject.className = className
        end

        self.specializations[name] = specialization
        table.insert(self.sortedSpecializations, specialization)
    end

    return true
end


---
function SpecializationManager:initSpecializations()
    for i=1, #self.sortedSpecializations do
        local specialization = self:getSpecializationObjectByName(self.sortedSpecializations[i].name)
        if specialization ~= nil and specialization.initSpecialization ~= nil then
            specialization.initSpecialization()
        end
    end
end


---
function SpecializationManager:postInitSpecializations()
    for i=1, #self.sortedSpecializations do
        local specialization = self:getSpecializationObjectByName(self.sortedSpecializations[i].name)
        if specialization ~= nil and specialization.postInitSpecialization ~= nil then
            specialization.postInitSpecialization()
        end
    end
end


---
function SpecializationManager:getSpecializationByName(name)
    if name ~= nil then
        return self.specializations[name]
    end

    return nil
end


---
function SpecializationManager:getSpecializationObjectByName(name)
    local entry = self.specializations[name]

    if entry == nil then
        return nil
    end

    return ClassUtil.getClassObject(entry.className)
end


---
function SpecializationManager:getSpecializations()
    return self.specializations
end
