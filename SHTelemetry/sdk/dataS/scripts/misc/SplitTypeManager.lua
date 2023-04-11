---This class handles all tree split types











local SplitTypeManager_mt = Class(SplitTypeManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function SplitTypeManager.new(customMt)
    local self = AbstractManager.new(customMt or SplitTypeManager_mt)

    return self
end


---Initialize data structures
function SplitTypeManager:initDataStructures()
    self.typesByIndex = {}
    self.typesByName = {}
end


---Loads initial manager
-- @return boolean true if loading was successful else false
function SplitTypeManager:loadMapData()
    SplitTypeManager:superClass().loadMapData(self)

    self:addSplitType("SPRUCE",             "treeType_spruce",             1,      0.7,    3.0,  true, nil, 1000)  -- density 0.47
    self:addSplitType("PINE",               "treeType_pine",               2,      0.7,    3.0,  true, nil, 1000)  -- density 0.52
    self:addSplitType("LARCH",              "treeType_larch",              3,      0.7,    3.0,  true, nil, 1000)  -- density 0.59
    self:addSplitType("BIRCH",              "treeType_birch",              4,      0.85,   3.2,  false, nil, 1000) -- density 0.65
    self:addSplitType("BEECH",              "treeType_beech",              5,      0.9,    3.4,  false, nil, 1000) -- density 0.69
    self:addSplitType("MAPLE",              "treeType_maple",              6,      0.9,    3.4,  false, nil, 1000) -- density 0.65
    self:addSplitType("OAK",                "treeType_oak",                7,      0.9,    3.4,  false, nil, 1000) -- density 0.67
    self:addSplitType("ASH",                "treeType_ash",                8,      0.9,    3.4,  false, nil, 1000) -- density 0.69
    self:addSplitType("LOCUST",             "treeType_locust",             9,      1.0,    3.8,  false, nil, 1000) -- density 0.73
    self:addSplitType("MAHOGANY",           "treeType_mahogany",           10,     1.1,    3.0,  false, nil, 1000) -- density 0.80
    self:addSplitType("POPLAR",             "treeType_poplar",             11,     0.7,    7.5,  false, nil, 1000) -- density 0.48
    self:addSplitType("AMERICANELM",        "treeType_americanElm",        12,     0.7,    3.5,  false, nil, 1000) -- density 0.57 -- TODO: tweak price + woodchips
    self:addSplitType("CYPRESS",            "treeType_cypress",            13,     0.7,    3.5,  false, nil, 1000) -- density 0.51 -- TODO: tweak price + woodchips
    self:addSplitType("DOWNYSERVICEBERRY",  "treeType_downyServiceberry",  14,     0.7,    3.5,  false, nil, 1000) -- density 0.63 -- TODO: tweak price + woodchips
    self:addSplitType("PAGODADOGWOOD",      "treeType_pagodaDogwood",      15,     0.7,    3.5,  false, nil, 1000) -- density 0.76 -- TODO: tweak price + woodchips
    self:addSplitType("SHAGBARKHICKORY",    "treeType_shagbarkHickory",    16,     0.7,    3.5,  false, nil, 1000) -- density 0.75 -- TODO: tweak price + woodchips
    self:addSplitType("STONEPINE",          "treeType_stonePine",          17,     0.7,    3.5,  false, nil, 1000) -- density 0.51 -- TODO: tweak price + woodchips
    self:addSplitType("WILLOW",             "treeType_willow",             18,     0.7,    3.5,  false, nil, 1000) -- density 0.50 -- TODO: tweak price + woodchips
    self:addSplitType("OLIVETREE",          "treeType_oliveTree",          19,     0.6,    3.5,  false, nil, 1000) -- density 0.45 -- TODO: tweak price + woodchips

    return true
end


---Adds a new splitType
function SplitTypeManager:addSplitType(name, l10nKey, splitTypeIndex, pricePerLiter, woodChipsPerLiter, allowsWoodHarvester, customEnvironment, volumeToLiter)
    if self.typesByIndex[splitTypeIndex] ~= nil then
        Logging.error("SplitTypeManager:addSplitType(): SplitTypeIndex '%d' is already in use for '%s'", splitTypeIndex, name)
        return
    end

    name = name:upper()
    if self.typesByName[name] ~= nil then
        Logging.error("SplitTypeManager:addSplitType(): SplitType name '%s' is already in use", name)
        return
    end

    local desc = {}
    desc.name = name
    desc.title = g_i18n:getText(l10nKey, customEnvironment)
    desc.splitTypeIndex = splitTypeIndex
    desc.pricePerLiter = pricePerLiter
    desc.woodChipsPerLiter = woodChipsPerLiter
    desc.allowsWoodHarvester = allowsWoodHarvester
    desc.volumeToLiter = volumeToLiter or 1000

    self.typesByIndex[splitTypeIndex] = desc
    self.typesByName[name] = desc
end


---Returns split type table by given split type index provided by getSplitType()
function SplitTypeManager:getSplitTypeByIndex(index)
    -- check each split type index has a registered split type
--#debug     if index ~= 0 and self.typesByIndex[index] == nil then
--#debug         Logging.warning("split type index '%d' has no split type registered", index)
--#debug     end

    return self.typesByIndex[index]
end
