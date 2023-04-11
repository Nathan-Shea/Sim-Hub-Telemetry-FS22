---This class provides tools for loading shared i3d files. Access using g_i3DManager












local I3DManager_mt = Class(I3DManager)


---Creating manager
-- @return table instance instance of object
function I3DManager.new(customMt)
    local self = setmetatable({}, customMt or I3DManager_mt)

    addConsoleCommand("gsI3DLoadingDelaySet", "Sets loading delay for i3d files", "consoleCommandSetLoadingDelay", self)
    addConsoleCommand("gsI3DShowCache", "Show active i3d cache", "consoleCommandShowCache", self)
    addConsoleCommand("gsI3DPrintActiveLoadings", "Print active loadings", "consoleCommandPrintActiveLoadings", self)

    return self
end


---
function I3DManager:init()
    local loadingDelay = tonumber(StartParams.getValue("i3dLoadingDelay"))
    if loadingDelay ~= nil and loadingDelay > 0 then
        self:setLoadingDelay(loadingDelay / 1000)
    end

    if StartParams.getIsSet("scriptDebug") then
        self:setupDebugLoading()
    end
end


---
function I3DManager:update(dt)
    if I3DManager.showCache then
        local data = {}

        local numSharedI3ds = getNumOfSharedI3DFiles()
        for i=0, numSharedI3ds-1 do
            local filename, numRefs = getSharedI3DFilesData(i)

            table.insert(data, {filename=filename, numRefs=numRefs})
        end

        table.sort(data, function(a, b)
            return a.filename < b.filename
        end)


        local posX = 0.01
        local posY = 0.99
        for _, item in ipairs(data) do
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(posX,        posY, 0.01, "Refcount: " .. tostring(item.numRefs))
            renderText(posX + 0.04, posY, 0.01, "File: " .. tostring(item.filename))

            posY = posY - 0.011

            if posY < 0 then
                posX = posX + 0.3
                posY = 0.99
            end
        end
    end
end


---Loads an i3D file. A cache system is used for faster loading
-- @param string filename filename
-- @param boolean callOnCreate true if onCreate i3d callbacks should be called
-- @param boolean addToPhysics true if collisions should be added to physics
-- @return integer id i3d rootnode
-- @return integer sharedLoadRequestId sharedLoadRequestId
-- @return integer failedReason loading failed
function I3DManager:loadSharedI3DFile(filename, callOnCreate, addToPhysics)
    -- always print all loading texts
    local verbose = true
    callOnCreate = Utils.getNoNil(callOnCreate, false)
    addToPhysics = Utils.getNoNil(addToPhysics, false)

    local node, sharedLoadRequestId, failedReason = loadSharedI3DFile(filename, addToPhysics, callOnCreate, verbose)

    return node, sharedLoadRequestId, failedReason
end


---Loads an i3D file async. A cache system is used for faster loading
-- @param string filename filename
-- @param boolean callOnCreate true if onCreate i3d callbacks should be called
-- @param boolean addToPhysics true if collisions should be added to physics
-- @param function asyncCallbackFunction a callback function with parameters (node, failedReason, args)
-- @param table asyncCallbackObject callback function target object
-- @param table asyncCallbackArguments a list of arguments
-- @return integer sharedLoadRequestId sharedLoadRequestId
function I3DManager:loadSharedI3DFileAsync(filename, callOnCreate, addToPhysics, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    assert(filename ~= nil, "I3DManager:loadSharedI3DFileAsync - missing filename")
    assert(asyncCallbackFunction ~= nil, "I3DManager:loadSharedI3DFileAsync - missing callback function")
    assert(type(asyncCallbackFunction) == "function", "I3DManager:loadSharedI3DFileAsync - Callback value is not a function")

    callOnCreate = Utils.getNoNil(callOnCreate, false)
    addToPhysics = Utils.getNoNil(addToPhysics, false)

    local arguments = {}
    arguments.asyncCallbackFunction = asyncCallbackFunction
    arguments.asyncCallbackObject = asyncCallbackObject
    arguments.asyncCallbackArguments = asyncCallbackArguments

    local sharedLoadRequestId = streamSharedI3DFile(filename, "loadSharedI3DFileAsyncFinished", self, arguments, addToPhysics, callOnCreate, I3DManager.VERBOSE_LOADING)

    return sharedLoadRequestId
end


---Called once i3d async loading is finished
-- @param integer nodeId i3d node id
-- @param integer failedReason fail reason enum type
-- @param table arguments a list of arguments
function I3DManager:loadSharedI3DFileAsyncFinished(nodeId, failedReason, arguments)
    local asyncCallbackFunction = arguments.asyncCallbackFunction
    local asyncCallbackObject = arguments.asyncCallbackObject
    local asyncCallbackArguments = arguments.asyncCallbackArguments

    asyncCallbackFunction(asyncCallbackObject, nodeId, failedReason, asyncCallbackArguments)
end


---
function I3DManager:loadI3DFile(filename, callOnCreate, addToPhysics)
    callOnCreate = Utils.getNoNil(callOnCreate, false)
    addToPhysics = Utils.getNoNil(addToPhysics, false)

    local node = loadI3DFile(filename, addToPhysics, callOnCreate, I3DManager.VERBOSE_LOADING)

    return node
end


---
function I3DManager:loadI3DFileAsync(filename, callOnCreate, addToPhysics, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    assert(filename ~= nil, "I3DManager:loadI3DFileAsync - missing filename")
    assert(asyncCallbackFunction ~= nil, "I3DManager:loadI3DFileAsync - missing callback function")
    assert(type(asyncCallbackFunction) == "function", "I3DManager:loadI3DFileAsync - Callback value is not a function")

    callOnCreate = Utils.getNoNil(callOnCreate, false)
    addToPhysics = Utils.getNoNil(addToPhysics, false)

    local arguments = {}
    arguments.asyncCallbackFunction = asyncCallbackFunction
    arguments.asyncCallbackObject = asyncCallbackObject
    arguments.asyncCallbackArguments = asyncCallbackArguments

    local loadRequestId = streamI3DFile(filename, "loadSharedI3DFileFinished", self, arguments, addToPhysics, callOnCreate, I3DManager.VERBOSE_LOADING)

    return loadRequestId
end


---
function I3DManager:loadSharedI3DFileFinished(nodeId, failedReason, arguments)
    local asyncCallbackFunction = arguments.asyncCallbackFunction
    local asyncCallbackObject = arguments.asyncCallbackObject
    local asyncCallbackArguments = arguments.asyncCallbackArguments

    asyncCallbackFunction(asyncCallbackObject, nodeId, failedReason, asyncCallbackArguments)
end


---
function I3DManager:cancelStreamI3DFile(loadingRequestId)
    if loadingRequestId ~= nil then
        cancelStreamI3DFile(loadingRequestId)
    else
        Logging.error("I3DManager:cancelStreamedI3dFile - loadingRequestId is nil")
        printCallstack()
    end
end


---Releases one instance. If ref count <= 0 i3d will be removed from cache
-- @param int sharedLoadRequestId sharedLoadRequestId request id
function I3DManager:releaseSharedI3DFile(sharedLoadRequestId, warnIfInvalid)
    if sharedLoadRequestId ~= nil then
        warnIfInvalid = Utils.getNoNil(warnIfInvalid, false)

        if g_isDevelopmentVersion then
            -- always print warnings for invalid loading request ids in dev mode
            --warnIfInvalid = true
        end

        releaseSharedI3DFile(sharedLoadRequestId, warnIfInvalid)
    else
        Logging.error("I3DManager:releaseSharedI3DFile - sharedLoadRequestId is nil")
        printCallstack()
    end
end


---Adds an i3d file to cache
-- @param string filename filename
function I3DManager:pinSharedI3DFileInCache(filename)
    if filename ~= nil then
        if getSharedI3DFileRefCount(filename) < 0 then
--#debug             log("pinSharedI3DFileInCache", filename)
            pinSharedI3DFileInCache(filename, true)
        end
    else
        Logging.error("I3DManager:pinSharedI3DFileInCache - Filename is nil")
        printCallstack()
    end
end


---Removes an i3d file from cache
-- @param string filename filename
function I3DManager:unpinSharedI3DFileInCache(filename)
    if filename ~= nil then
--#debug         log("unpinSharedI3DFileInCache", filename)
        unpinSharedI3DFileInCache(filename)
    else
        Logging.error("I3DManager:unpinSharedI3DFileInCache - filename is nil")
        printCallstack()
    end
end


---
function I3DManager:clearEntireSharedI3DFileCache(verbose)
    if verbose == true then
        local numSharedI3ds = getNumOfSharedI3DFiles()
        Logging.devInfo("I3DManager: Deleting %s shared i3d files", numSharedI3ds)
        for i=0, numSharedI3ds-1 do
            local filename, numRefs = getSharedI3DFilesData(i)
            Logging.devWarning("    NumRef: %d - File: %s", numRefs, filename)
        end
    end

    Logging.devInfo("I3DManager: Deleted shared i3d files")

    clearEntireSharedI3DFileCache()
end


---
function I3DManager:setLoadingDelay(minDelaySeconds, maxDelaySeconds, minDelayCachedSeconds, maxDelayCachedSeconds)
    minDelaySeconds = minDelaySeconds or 0
    maxDelaySeconds = maxDelaySeconds or minDelaySeconds
    minDelayCachedSeconds = minDelayCachedSeconds or minDelaySeconds
    maxDelayCachedSeconds = maxDelayCachedSeconds or maxDelaySeconds

    setStreamI3DFileDelay(minDelaySeconds, maxDelaySeconds)
    setStreamSharedI3DFileDelay(minDelaySeconds, maxDelaySeconds, minDelayCachedSeconds, maxDelayCachedSeconds)

    Logging.info("Set new loading delay. MinDelay: %.2fs, MaxDelay: %.2fs, MinDelayCached: %.2fs, MaxDelayCached: %.2fs", minDelaySeconds, maxDelaySeconds, minDelayCachedSeconds, maxDelayCachedSeconds)
end


---
function I3DManager:consoleCommandSetLoadingDelay(minDelaySec, maxDelaySec, minDelayCachedSec, maxDelayCachedSec)
    minDelaySec = tonumber(minDelaySec) or 0
    maxDelaySec = tonumber(maxDelaySec) or minDelaySec
    minDelayCachedSec = tonumber(minDelayCachedSec) or minDelaySec
    maxDelayCachedSec = tonumber(maxDelayCachedSec) or maxDelaySec

    self:setLoadingDelay(minDelaySec, maxDelaySec, minDelayCachedSec, maxDelayCachedSec)
end


---
function I3DManager:consoleCommandShowCache(delay)
    I3DManager.showCache = not I3DManager.showCache
    return "showCache=" .. tostring(I3DManager.showCache)
end


---
function I3DManager:consoleCommandPrintActiveLoadings()

    print("Non-Shared loading tasks:")
    local loadingRequestIds = getAllStreamI3DFileRequestIds()
    for k, loadingRequestId in ipairs(loadingRequestIds) do
        local progress, timeSec, filename, callback, target, args = getStreamI3DFileProgressInfo(loadingRequestId)

        local text = string.format("%03d: Progress: %s | Time %.3fs | File: %s | Callback: %s | Target: %s | Args: %s", loadingRequestId, progress, timeSec, filename, callback, tostring(target), tostring(args))
        print(text)
    end

    print("\n\n")
    print("Shared loading tasks:")

    local sharedLoadingRequestIds = getAllSharedI3DFileRequestIds()
    for k, sharedLoadingRequestId in ipairs(sharedLoadingRequestIds) do
        local progress, timeSec, filename, callback, target, args = getSharedI3DFileProgressInfo(sharedLoadingRequestId)

        local text = string.format("%03d: Progress: %s | Time %.3fs | File: %s | Callback: %s | Target: %s | Args: %s", sharedLoadingRequestId, progress, timeSec, filename, callback, tostring(target), tostring(args))
        print(text)
    end
end
