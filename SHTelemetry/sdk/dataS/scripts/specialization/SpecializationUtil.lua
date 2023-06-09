---Specialization util class










---
function SpecializationUtil.raiseEvent(object, eventName, ...)
    if object.eventListeners[eventName] == nil then
        printError("Error: Event '"..tostring(eventName).."' is not registered for type '"..tostring(object.type.name).."'!")
        return
    end

    for _, spec in ipairs(object.eventListeners[eventName]) do
        --#profile local doProfiling, profileName = Vehicle.PROFILE_EVENTS[eventName], spec.className .. ":" .. eventName
        --#profile if doProfiling then g_remoteProfiler.ZoneBeginN(profileName) end
        spec[eventName](object, ...)
        --#profile if doProfiling then g_remoteProfiler.ZoneEnd() end
    end
end


---
function SpecializationUtil.registerEvent(objectType, eventName)
    if objectType.functions[eventName] ~= nil or objectType.events[eventName] ~= nil or (eventName == nil or eventName == "") then
        printCallstack()
    end

    assert(objectType.functions[eventName] == nil, "Error: Event '"..tostring(eventName).."' already registered as function in type '"..tostring(objectType.name).."'!")
    assert(objectType.events[eventName] == nil,    "Error: Event '"..tostring(eventName).."' already registered as event in type '"..tostring(objectType.name).."'!")
    assert(eventName ~= nil and eventName ~= "",    "Error: Event '"..tostring(eventName).."' is 'nil' or empty!")

    objectType.events[eventName] = eventName
    objectType.eventListeners[eventName] = {}
end


---
function SpecializationUtil.registerFunction(objectType, funcName, func)
    if objectType.functions[funcName] ~= nil or objectType.events[funcName] ~= nil or func == nil then
        printCallstack()
    end

    assert(objectType.functions[funcName] == nil,  "Error: Function '"..tostring(funcName).."' already registered as function in type '"..tostring(objectType.name).."'!")
    assert(objectType.events[funcName] == nil,     "Error: Function '"..tostring(funcName).."' already registered as event in type '"..tostring(objectType.name).."'!")
    assert(func ~= nil,                             "Error: Given reference for Function '"..tostring(funcName).."' is 'nil'!")

    objectType.functions[funcName] = func
end


---
function SpecializationUtil.registerOverwrittenFunction(objectType, funcName, func)

    assert(func ~= nil, "Error: Given reference for OverwrittenFunction '"..tostring(funcName).."' is 'nil'!")

    -- if function does not exist, we don't need to overwrite anything
    if objectType.functions[funcName] ~= nil then
        objectType.functions[funcName] = Utils.overwrittenFunction(objectType.functions[funcName], func)
    end
end


---
function SpecializationUtil.registerEventListener(objectType, eventName, spec)
    local className = ClassUtil.getClassName(spec)

    assert(objectType.eventListeners ~= nil, "Error: Invalid type for specialization '"..tostring(className).."'!")
    if objectType.eventListeners[eventName] == nil then
        return
    end

    assert(spec[eventName] ~= nil, "Error: Event listener function '"..tostring(eventName).."' not defined in specialization '"..tostring(className).."'!")

    local found = false
    for _, registeredSpec in pairs(objectType.eventListeners[eventName]) do
        if registeredSpec == spec then
            found = true
            break
        end
    end

    assert(not found, "Error: Eventlistener for '"..eventName.."' already registered in specialization '"..tostring(className).."'!")

    table.insert(objectType.eventListeners[eventName], spec)
end


---
function SpecializationUtil.removeEventListener(object, eventName, specClass)
    local listeners = object.eventListeners[eventName]
    if listeners ~= nil then
        for i=#listeners, 1, -1 do
            if ClassUtil.getClassName(listeners[i]) == ClassUtil.getClassName(specClass) then
                table.remove(listeners, i)
            end
        end
    end
end


---
function SpecializationUtil.hasSpecialization(spec, specializations)
    for _,v in pairs(specializations) do
        if v == spec then
            return true
        end
    end
    return false
end
