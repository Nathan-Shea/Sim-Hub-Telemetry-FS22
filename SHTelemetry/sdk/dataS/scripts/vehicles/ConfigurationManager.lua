---This class handles all configuration types









local ConfigurationManager_mt = Class(ConfigurationManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function ConfigurationManager.new(customMt)
    local self = AbstractManager.new(customMt or ConfigurationManager_mt)

    self:initDataStructures()

    return self
end


---Initialize data structures
function ConfigurationManager:initDataStructures()
    self.configurations = {}
    self.intToConfigurationName = {}
    self.configurationNameToInt = {}
    self.sortedConfigurationNames = {}
end











































---Returns number of configuration types
-- @return integer numOfConfigurationTypes number of configuration types
function ConfigurationManager:getNumOfConfigurationTypes()
    return #self.intToConfigurationName
end


---Returns a table of the available configuration types
-- @return table List of configuration types (names)
function ConfigurationManager:getConfigurationTypes()
    return self.intToConfigurationName
end


---Returns a table of the available configuration types sorted by priority
-- @return table List of configuration types (names)
function ConfigurationManager:getSortedConfigurationTypes()
    return self.sortedConfigurationNames
end


---Returns configuration name by given index
-- @param integer index index of config
-- @return string name name of config
function ConfigurationManager:getConfigurationNameByIndex(index)
    return self.intToConfigurationName[index]
end


---Returns configuration index by given name
-- @param string name name of config
-- @return integer index index of config
function ConfigurationManager:getConfigurationIndexByName(name)
    return self.configurationNameToInt[name]
end


---Returns table with all available configurations
-- @return table configurations configurations
function ConfigurationManager:getConfigurations()
    return self.configurations
end


---Returns configuration desc by name
-- @param string name name of config
-- @return table configuration configuration
function ConfigurationManager:getConfigurationDescByName(name)
    return self.configurations[name]
end


---Returns configuration attribute by given name and attribute
-- @param string configurationName name of config
-- @param string attribute name of attribute
-- @return any_type value value of attribute
function ConfigurationManager:getConfigurationAttribute(configurationName, attribute)
    local config = self:getConfigurationDescByName(configurationName)
    return config[attribute]
end
