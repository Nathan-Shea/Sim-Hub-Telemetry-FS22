---Provides an interface model between game settings and the UI for re-use between several components. The model keeps
--a common, transient state until saved. When saving, the settings are applied to the global game settings and written
--to the player's configuration file.









local SettingsModel_mt = Class(SettingsModel)



















































































































---Create a new instance.
-- @param table gameSettings GameSettings object which holds the currently active and applied game settings
-- @param int settingsFileHandle Engine file handle of the player's settings file
-- @param table l10n I18N reference for localized display string resolution
-- @param table soundMixer SoundMixer reference for direct application of volume settings
-- @return table SettingsModel instance
function SettingsModel.new(gameSettings, settingsFileHandle, l10n, soundMixer, isConsoleVersion)
    local self = setmetatable({}, SettingsModel_mt)

    self.gameSettings = gameSettings
    self.settingsFileHandle = settingsFileHandle
    self.l10n = l10n
    self.soundMixer = soundMixer
    self.isConsoleVersion = isConsoleVersion

    self.settings = {} -- previous and current settings, {[setting] -> {saved=value, changed=value}}
    self.sortedSettings = {} -- settings
    self.settingReaders = {} -- [settingKey] -> function
    self.settingWriters = {} -- [settingKey] -> function

    self.defaultReaderFunction = self:makeDefaultReaderFunction()
    self.defaultWriterFunction = self:makeDefaultWriterFunction()

    self.volumeTexts = {}
    self.voiceInputThresholdTexts = {}
    self.recordingVolumeTexts = {}
    self.voiceModeTexts = {}
    self.brightnessTexts = {}
    self.fovYTexts = {}
    self.indexToFovYMapping = {}
    self.fovYToIndexMapping = {}
    self.uiScaleValues = {}
    self.uiScaleTexts = {}
    self.cameraSensitivityValues = {}
    self.cameraSensitivityStrings = {}
    self.cameraSensitivityStep = 0.25
    self.vehicleArmSensitivityValues = {}
    self.vehicleArmSensitivityStrings = {}
    self.vehicleArmSensitivityStep = 0.25
    self.realBeaconLightBrightnessValues = {}
    self.realBeaconLightBrightnessStrings = {}
    self.realBeaconLightBrightnessStep = 0.1
    self.steeringBackSpeedValues = {}
    self.steeringBackSpeedStrings = {}
    self.steeringBackSpeedStep = 1
    self.steeringSensitivityValues = {}
    self.steeringSensitivityStrings = {}
    self.steeringSensitivityStep = 0.1
    self.moneyUnitTexts = {}
    self.distanceUnitTexts = {}
    self.temperatureUnitTexts = {}
    self.areaUnitTexts = {}
    self.radioModeTexts = {}
    self.resolutionScaleTexts = {}
    self.resolutionScale3dTexts = {}
    self.dlssTexts = {}
    self.fidelityFxSRTexts = {}
    self.fidelityFxSR20Texts = {}
    self.xeSSTexts = {}
    self.sharpnessTexts = {}
    self.postProcessAntiAliasingTexts = {}

    self.msaaTexts = {}
    self.shadowQualityTexts = {}
    self.shadowDistanceQualityTexts = {}
    self.fourStateTexts = {}
    self.lowHighTexts = {}
    self.textureFilteringTexts = {}
    self.shadowMapMaxLightsTexts = {}
    self.hdrPeakBrightnessValues = {}
    self.hdrPeakBrightnessTexts = {}
    self.hdrPeakBrightnessStep = 0.05
    self.percentValues = {}
    self.perentageTexts = {}
    self.percentStep = 0.05
    self.tireTracksValues = {}
    self.tireTracksTexts = {}
    self.tireTracksStep = 0.5
    self.maxMirrorsTexts = {}
    self.foliageShadowTexts = {}
    self.ssaoQualityTexts = {}
    self.ssaoQualityValues = {}
    self.ssaoSamplesToQualityIndex = {}
    self.cloudQualityTexts = {}

    self.resolutionTexts = {}
    self.fullscreenModeTexts = {}
    self.mpLanguageTexts = {}
    self.inputHelpModeTexts = {}
    self.directionChangeModeTexts = {}
    self.gearShiftModeTexts = {}
    self.hudSpeedGaugeTexts = {}
    self.frameLimitTexts = {}

    self.intialValues = {}

    self.deviceSettings = {}
    self.currentDevice = {}

    self.minBrightness = 0.5
    self.maxBrightness = 2.0
    self.brightnessStep = 0.1

    self.minSharpness = 0.0
    self.maxSharpness = 2.0
    self.sharpnessStep = 0.1

    self.minFovY = Platform.minFovY
    self.maxFovY = Platform.maxFovY

    self:initialize()

    return self
end


---Initialize model.
Read current configuration settings and populate valid display and configuration option values.
function SettingsModel:initialize()
    self:createControlDisplayValues()
    self:addManagedSettings()
end


---Add managed valid settings which receive their initial value from the loaded game settings or the engine.
function SettingsModel:addManagedSettings()
    self:addPerformanceClassSetting()
    self:addMSAASetting()
    self:addTextureFilteringSetting()
    self:addTextureResolutionSetting()
    self:addShadowQualitySetting()
    self:addShaderQualitySetting()
    self:addShadowMapFilteringSetting()
    self:addShadowMaxLightsSetting()
    self:addTerrainQualitySetting()
    self:addObjectDrawDistanceSetting()
    self:addFoliageDrawDistanceSetting()
    self:addFoliageShadowSetting()
    self:addLODDistanceSetting()
    self:addTerrainLODDistanceSetting()
    self:addVolumeMeshTessellationSetting()
    self:addMaxTireTracksSetting()
    self:addLightsProfileSetting()
    self:addRealBeaconLightsSetting()
    self:addMaxMirrorsSetting()
    self:addPostProcessAntiAliasingSetting()
    self:addDLSSSetting()
    self:addFidelityFxSRSetting()
    self:addFidelityFxSR20Setting()
    self:addValarSetting()
    self:addXeSSSetting()
    self:addSharpnessSetting()
    self:addShadingRateQualitySetting()
    self:addShadowDistanceQualitySetting()
    self:addSSAOQualitySetting()
    self:addCloudQualitySetting()

    self:addSetting(SettingsModel.SETTING.FULLSCREEN_MODE, getFullscreenMode, setFullscreenMode)
    self:addLanguageSetting()
    self:addMPLanguageSetting()
    self:addInputHelpModeSetting()
    self:addBrightnessSetting()
    self:addVSyncSetting()
    self:addFovYSetting()
    self:addUIScaleSetting()
    self:addMasterVolumeSetting()
    self:addMusicVolumeSetting()
    self:addEnvironmentVolumeSetting()
    self:addVehicleVolumeSetting()
    self:addRadioVolumeSetting()
    self:addVolumeGUISetting()
    self:addVoiceVolumeSetting()
    self:addVoiceInputVolumeSetting()
    self:addVoiceModeSetting()
    self:addVoiceInputSensitivitySetting()
    self:addSteeringBackSpeedSetting()
    self:addSteeringSensitivitySetting()
    self:addCameraSensitivitySetting()
    self:addVehicleArmSensitivitySetting()
    self:addRealBeaconLightBrightnessSetting()
    self:addActiveCameraSuspensionSetting()
    self:addCamerCheckCollisionSetting()
    self:addDirectionChangeModeSetting()
    self:addGearShiftModeSetting()
    self:addHudSpeedGaugeSetting()
    self:addWoodHarvesterAutoCutSetting()
    self:addForceFeedbackSetting()

    if Platform.hasAdjustableFrameLimit then
        self:addFrameLimitSetting()
    end

    if Platform.isMobile then
        self:addGyroscopeSteeringSetting()
        self:addHintsSetting()
        self:addCameraTiltingSetting()
    end

    if Platform.isConsole then
        self:addConsoleResolutionSetting()
        self:addConsoleRenderQualitySetting()
    else
        self:addSetting(SettingsModel.SETTING.RESOLUTION, getScreenMode, setScreenMode)
        self:addResolutionScaleSetting()
        self:addResolutionScale3dSetting()
    end

    if Platform.isStadia then
        self:addHDRPeakBrightnessSetting()
    end

    self:addDirectSetting(SettingsModel.SETTING.USE_COLORBLIND_MODE)
    self:addDirectSetting(SettingsModel.SETTING.GAMEPAD_ENABLED)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_FIELD_INFO)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_HELP_MENU)
    self:addDirectSetting(SettingsModel.SETTING.RADIO_IS_ACTIVE)
    self:addDirectSetting(SettingsModel.SETTING.RESET_CAMERA)
    self:addDirectSetting(SettingsModel.SETTING.RADIO_VEHICLE_ONLY)
    self:addDirectSetting(SettingsModel.SETTING.IS_TRAIN_TABBABLE)
    self:addDirectSetting(SettingsModel.SETTING.HEAD_TRACKING_ENABLED)
    self:addDirectSetting(SettingsModel.SETTING.USE_FAHRENHEIT)
    self:addDirectSetting(SettingsModel.SETTING.USE_WORLD_CAMERA)
    self:addDirectSetting(SettingsModel.SETTING.MONEY_UNIT)
    self:addDirectSetting(SettingsModel.SETTING.USE_ACRE)
    self:addDirectSetting(SettingsModel.SETTING.EASY_ARM_CONTROL)
    self:addDirectSetting(SettingsModel.SETTING.INVERT_Y_LOOK)
    self:addDirectSetting(SettingsModel.SETTING.USE_MILES)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_TRIGGER_MARKER)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_MULTIPLAYER_NAMES)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_HELP_TRIGGER)
    self:addDirectSetting(SettingsModel.SETTING.SHOW_HELP_ICONS)
    self:addDirectSetting(SettingsModel.SETTING.CAMERA_BOBBING, true)

    -- -- check for missing settings
    -- for _, key in pairs(SettingsModel.SETTING) do
    --     if self.settings[key] == nil then
    --         log(key)
    --     end
    -- end
end


---Add a setting to the model.
Reader and writer functions need to be provided which transform display values (usually indices) to actual setting
values and interact with the current game setting or engine states. Writer function can have side-effects, such as
directly applying values to the engine state or modifying dependent sub-settings.
-- @param string gameSettingsKey Key of the setting in GameSettings
-- @param function readerFunction Function which reads and processes the setting value identified by the key, signature: function(settingsKey)
-- @param function writerFunction Function which processes and writes the setting value identified by the key, signature: function(value, settingsKey)
-- @param boolean noRestartRequired true if no restart is required to apply the setting
function SettingsModel:addSetting(gameSettingsKey, readerFunction, writerFunction, noRestartRequired)
    local initialValue = readerFunction(gameSettingsKey)

    -- initial: the value of the settings when the screen was opened
    -- saved: the value that is currently set to the engine
    -- changed: the value that is currently set in the gui
    self.settings[gameSettingsKey] = {key = gameSettingsKey, initial = initialValue, saved = initialValue, changed = initialValue, noRestartRequired = noRestartRequired}
    self.settingReaders[gameSettingsKey] = readerFunction
    self.settingWriters[gameSettingsKey] = writerFunction

    table.insert(self.sortedSettings, self.settings[gameSettingsKey])
end


---Set a settings value.
-- @param string settingKey Setting key, use one of the values in SettingsModel.SETTING.
-- @param table value New setting value
function SettingsModel:setValue(settingKey, value)
    self.settings[settingKey].changed = value
end


---Get a settings value.
-- @param string settingKey Setting key, use one of the values in SettingsModel.SETTING.
-- @return table Currently active (changed) settings value
function SettingsModel:getValue(settingKey, trueValue)
    if trueValue then
        return self.settingReaders[settingKey](settingKey)
    end
    if self.settings[settingKey] == nil then -- resolution can be missing on consoles
        return 0
    end

    return self.settings[settingKey].changed
end


---Set the settings file handle when it changes (e.g. possible in the gamepad sign-in process).
function SettingsModel:setSettingsFileHandle(settingsFileHandle)
    self.settingsFileHandle = settingsFileHandle
end


---Refresh settings values from their reader functions.
Use this when other components might have changed the settings state and the model needs to reflect those changes
now.
function SettingsModel:refresh()
    for settingsKey, setting in pairs(self.settings) do
        setting.initial = self.settingReaders[settingsKey](settingsKey)
        setting.changed = setting.initial
        setting.saved = setting.initial
    end
end


---Refresh currently changed settings values from their reader functions. Calling reset will still reset to the old known values.
Use this when other components might have changed the settings state and the model needs to reflect those changes
now.
function SettingsModel:refreshChangedValue()
    for settingsKey, setting in pairs(self.settings) do
        setting.changed = self.settingReaders[settingsKey](settingsKey)
        setting.saved = setting.changed
    end
end



---Reset all settings to the initial values since the last apply
function SettingsModel:reset()
    for _, setting in pairs(self.sortedSettings) do
        setting.changed = setting.initial
        setting.saved = setting.initial
        local writeFunction = self.settingWriters[setting.key]
        writeFunction(setting.changed, setting.key)
    end

    self:resetDeviceChanges()
end


---Check if any setting has been changed in the model.
-- @return bool True if any setting has been changed, false otherwise
function SettingsModel:hasChanges()
    for _, setting in pairs(self.settings) do
        if setting.initial ~= setting.changed or setting.initial ~= setting.saved then
            return true
        end
    end

    return self:hasDeviceChanges()
end


---Check if any setting has been changed in the model.
-- @return bool True if any setting has been changed, false otherwise
function SettingsModel:needsRestartToApplyChanges()
    for _, setting in pairs(self.settings) do
        if (setting.initial ~= setting.changed or setting.initial ~= setting.saved) and not setting.noRestartRequired then
            return true
        end
    end

    return self:hasDeviceChanges()
end


---Apply the currently held, transient settings to the game settings.
-- @param bool doSave If true, the changes will also be persisted to storage.
function SettingsModel:applyChanges(settingClassesToSave)
    for _, setting in pairs(self.sortedSettings) do
        local settingsKey = setting.key
        local savedValue = self.settings[settingsKey].saved
        local changedValue = self.settings[settingsKey].changed

        if savedValue ~= changedValue then
            local writeFunction = self.settingWriters[settingsKey]
            writeFunction(changedValue, settingsKey) -- write to game settings / engine

            self.settings[settingsKey].saved = changedValue
        end
        self.settings[settingsKey].initial = changedValue -- update initial value
    end

    if settingClassesToSave ~= 0 then
        self:saveChanges(settingClassesToSave)
    end
end


---Save the game settings which may have been modified by this model.
This will not apply transient changes but only persist the currently applied game settings.
function SettingsModel:saveChanges(settingClassesToSave)
    if bitAND(settingClassesToSave, SettingsModel.SETTING_CLASS.SAVE_GAMEPLAY_SETTINGS) ~= 0 then
        self.gameSettings:saveToXMLFile(self.settingsFileHandle)
    end

    self:saveDeviceChanges()

    if bitAND(settingClassesToSave, SettingsModel.SETTING_CLASS.SAVE_ENGINE_QUALITY_SETTINGS) ~= 0 then
        saveHardwareScalability()
        if self.isConsoleVersion or GS_PLATFORM_GGP or GS_IS_MOBILE_VERSION then
            executeSettingsChange()
        end
    end
end












---
function SettingsModel:applyPerformanceClass(value)
    local settingsKey = SettingsModel.SETTING.PERFORMANCE_CLASS
    local writeFunction = self.settingWriters[settingsKey]
    writeFunction(value, settingsKey)
    self.settings[settingsKey].changed = value
    self.settings[settingsKey].saved = value

    self:refreshChangedValue()
end


---
function SettingsModel:applyCustomSettings()
    for settingsKey in pairs(self.settings) do
        if settingsKey ~= SettingsModel.SETTING.PERFORMANCE_CLASS then
            local changedValue = self.settings[settingsKey].changed
            if changedValue ~= self.settings[settingsKey].saved then
                local writeFunction = self.settingWriters[settingsKey]
                writeFunction(changedValue, settingsKey)
                self.settings[settingsKey].saved = changedValue
            end
        end
    end
end






---Populate value and string lists for control elements display.
function SettingsModel:createControlDisplayValues()
    self.volumeTexts = {self.l10n:getText("ui_off"), "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"}
    self.recordingVolumeTexts = {self.l10n:getText("ui_auto"), "50%", "60%", "70%", "80%", "90%", "100%", "110%", "120%", "130%", "140%", "150%"}

    self.voiceModeTexts = {
        self.l10n:getText("ui_off"),
        self.l10n:getText("ui_voiceActivity"),
    }
    if Platform.supportsPushToTalk then
        table.insert(self.voiceModeTexts, self.l10n:getText("ui_pushToTalk"))
    end

    self.voiceInputThresholdTexts = {self.l10n:getText("ui_auto"), "0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"}

    for i = self.minBrightness, self.maxBrightness + 0.0001, self.brightnessStep do -- add a little to max for floating point precision
        table.insert(self.brightnessTexts, string.format("%.1f", i))
    end

    local index = 1
    for i = self.minFovY, self.maxFovY do
        self.indexToFovYMapping[index] = i
        self.fovYToIndexMapping[i] = index
        table.insert(self.fovYTexts, string.format(self.l10n:getText("setting_fovyDegree"), i))

        index = index + 1
    end

    for i = 1, 16 do
        table.insert(self.uiScaleTexts, string.format("%d%%", 50 + (i - 1) * 5))
    end

    for i = 0.5, 2.1, 0.1 do
        table.insert(self.resolutionScaleTexts, string.format("%d%%", MathUtil.round(i * 100)))
    end

    for i = 0.5, 2.1, 0.1 do
        table.insert(self.resolutionScale3dTexts, string.format("%d%%", MathUtil.round(i * 100)))
    end

    for i = 0.5, 3, self.cameraSensitivityStep do
        table.insert(self.cameraSensitivityStrings, string.format("%d%%", i * 100))
        table.insert(self.cameraSensitivityValues, i)
    end

    for i = 0.5, 3, self.vehicleArmSensitivityStep do
        table.insert(self.vehicleArmSensitivityStrings, string.format("%d%%", i * 100))
        table.insert(self.vehicleArmSensitivityValues, i)
    end

    for i = 0, 1, self.realBeaconLightBrightnessStep do
        if i > 0 then
            table.insert(self.realBeaconLightBrightnessStrings, string.format("%d%%", i * 100 + 0.5))
        else
            table.insert(self.realBeaconLightBrightnessStrings, self.l10n:getText("setting_off"))
        end
        table.insert(self.realBeaconLightBrightnessValues, i)
    end

    for i = 0, 10, self.steeringBackSpeedStep do
        table.insert(self.steeringBackSpeedStrings, string.format("%d%%", i * 10))
        table.insert(self.steeringBackSpeedValues, i)
    end

    for i = 0.5, 2.1, self.steeringSensitivityStep do
        table.insert(self.steeringSensitivityStrings, string.format("%d%%", i * 100 + 0.5))
        table.insert(self.steeringSensitivityValues, i)
    end

    self.moneyUnitTexts = {self.l10n:getText("unit_euro"), self.l10n:getText("unit_dollar"), self.l10n:getText("unit_pound")}
    self.distanceUnitTexts = {self.l10n:getText("unit_km"), self.l10n:getText("unit_miles")}
    self.temperatureUnitTexts = {self.l10n:getText("unit_celsius"), self.l10n:getText("unit_fahrenheit")}
    self.areaUnitTexts = {self.l10n:getText("unit_ha"), self.l10n:getText("unit_acre")}
    self.radioModeTexts = {self.l10n:getText("setting_radioAlways"), self.l10n:getText("setting_radioVehicleOnly")}
    self.msaaTexts = {self.l10n:getText("ui_off"), "2x", "4x", "8x"}
    self.shadowQualityTexts = {self.l10n:getText("setting_off"), self.l10n:getText("setting_medium"), self.l10n:getText("setting_high"), self.l10n:getText("setting_veryHigh")}
    self.shadowDistanceQualityTexts = {self.l10n:getText("setting_low"), self.l10n:getText("setting_medium"), self.l10n:getText("setting_high")}
    self.fourStateTexts = {self.l10n:getText("setting_low"), self.l10n:getText("setting_medium"), self.l10n:getText("setting_high"), self.l10n:getText("setting_veryHigh")}
    self.lowHighTexts = {self.l10n:getText("setting_low"), self.l10n:getText("setting_high")}
    self.textureFilteringTexts = {"Bilinear", "Trilinear", "Aniso 1x", "Aniso 2x", "Aniso 4x", "Aniso 8x", "Aniso 16x"}
    self.foliageShadowTexts = {self.l10n:getText("ui_off"), self.l10n:getText("ui_on")}
    self.ssaoQualityTexts = {self.l10n:getText("setting_low"), self.l10n:getText("setting_medium"), self.l10n:getText("setting_high"), self.l10n:getText("setting_veryHigh")}
    self.cloudQualityTexts = {self.l10n:getText("setting_low"), self.l10n:getText("setting_medium"), self.l10n:getText("setting_high"), self.l10n:getText("setting_veryHigh")}

    self.dlssTexts = { }
    self.dlssMapping = { }
    self.dlssMappingReverse = { }
    for quality = 0, DLSSQuality.NUM - 1 do
        if quality == DLSSQuality.OFF or getSupportsDLSSQuality(quality) then
            table.insert(self.dlssTexts, quality == DLSSQuality.OFF and self.l10n:getText("ui_off") or getDLSSQualityName(quality))
            self.dlssMapping[quality] = #self.dlssTexts
            self.dlssMappingReverse[#self.dlssTexts] = quality
        end
    end

    for i=0, 3 do
        local samples = getDefaultSSAOQuality(i)
        table.insert(self.ssaoQualityValues, samples)
        self.ssaoSamplesToQualityIndex[samples] = #self.ssaoQualityValues
    end


    self.fidelityFxSRTexts = { }
    self.fidelityFxSRMapping = { }
    self.fidelityFxSRMappingReverse = { }
    for quality = 0, FidelityFxSRQuality.NUM - 1 do
        if quality == FidelityFxSRQuality.OFF or getSupportsFidelityFxSRQuality(quality) then
            table.insert(self.fidelityFxSRTexts, quality == FidelityFxSRQuality.OFF and self.l10n:getText("ui_off") or getFidelityFxSRQualityName(quality))
            self.fidelityFxSRMapping[quality] = #self.fidelityFxSRTexts
            self.fidelityFxSRMappingReverse[#self.fidelityFxSRTexts] = quality
        end
    end

    self.fidelityFxSR20Texts = { }
    self.fidelityFxSR20Mapping = { }
    self.fidelityFxSR20MappingReverse = { }
    for quality = 0, FidelityFxSR20Quality.NUM - 1 do
        if quality == FidelityFxSR20Quality.OFF or getSupportsFidelityFxSR20Quality(quality) then
            table.insert(self.fidelityFxSR20Texts, quality == FidelityFxSR20Quality.OFF and self.l10n:getText("ui_off") or getFidelityFxSR20QualityName(quality))
            self.fidelityFxSR20Mapping[quality] = #self.fidelityFxSR20Texts
            self.fidelityFxSR20MappingReverse[#self.fidelityFxSR20Texts] = quality
        end
    end
    
    self.valarTexts = { }
    self.valarMapping = { }
    self.valarMappingReverse = { }
    for quality = 0, ValarQuality.NUM - 1 do
        if quality == ValarQuality.OFF or getSupportsValarQuality(quality) then
            table.insert(self.valarTexts, quality == ValarQuality.OFF and g_i18n:getText("ui_off") or getValarQualityName(quality))
            self.valarMapping[quality] = #self.valarTexts
            self.valarMappingReverse[#self.valarTexts] = quality
        end
    end

    self.xeSSTexts = { }
    self.xeSSMapping = { }
    self.xeSSMappingReverse = { }
    for quality = 0, XeSSQuality.NUM - 1 do
        if quality == XeSSQuality.OFF or getSupportsXeSSQuality(quality) then
            table.insert(self.xeSSTexts, quality == XeSSQuality.OFF and self.l10n:getText("ui_off") or getXeSSQualityName(quality))
            self.xeSSMapping[quality] = #self.xeSSTexts
            self.xeSSMappingReverse[#self.xeSSTexts] = quality
        end
    end

    for i = self.minSharpness, self.maxSharpness + 0.0001, self.sharpnessStep do -- add a little to max for floating point precision
        table.insert(self.sharpnessTexts, string.format("%.1f", i))
    end

    self.postProcessAntiAliasingTexts = { }
    self.postProcessAntiAliasingMapping = { }
    self.postProcessAntiAliasingMappingReverse = { }
    self.postProcessAntiAliasingToolTip = self.l10n:getText("toolTip_ppaa")
    for ppaa = 0, PostProcessAntiAliasing.NUM - 1 do
        if ppaa == PostProcessAntiAliasing.OFF or getSupportsPostProcessAntiAliasing(ppaa) then
            table.insert(self.postProcessAntiAliasingTexts, ppaa == PostProcessAntiAliasing.OFF and g_i18n:getText("ui_off") or getPostProcessAntiAliasingName(ppaa))
            self.postProcessAntiAliasingMapping[ppaa] = #self.postProcessAntiAliasingTexts
            self.postProcessAntiAliasingMappingReverse[#self.postProcessAntiAliasingTexts] = ppaa

            if ppaa == PostProcessAntiAliasing.TAA then
                self.postProcessAntiAliasingToolTip = self.postProcessAntiAliasingToolTip .. "\n"..self.l10n:getText("toolTip_ppaa_taa")
            elseif ppaa == PostProcessAntiAliasing.DLAA then
                self.postProcessAntiAliasingToolTip = self.postProcessAntiAliasingToolTip .. "\n"..self.l10n:getText("toolTip_ppaa_dlaa")
            end
        end
    end

    self.hdrPeakBrightnessValues = {}
    self.hdrPeakBrightnessTexts = {}
    self.hdrPeakBrightnessStep = 10
    for i=0, 50 do
        local value = (100 + i * self.hdrPeakBrightnessStep)
        table.insert(self.hdrPeakBrightnessTexts, string.format("%d", value))
        table.insert(self.hdrPeakBrightnessValues, value)
    end

    self.shadowMapMaxLightsTexts = {}
    for i=1,10 do
        table.insert(self.shadowMapMaxLightsTexts, string.format("%d", i))
    end

    self.percentValues = {}
    self.perentageTexts = {}
    self.percentStep = 0.05
    for i=0, 30 do
        table.insert(self.perentageTexts, string.format("%.f%%", (0.5+i*self.percentStep)*100))
        table.insert(self.percentValues, (0.5+i*self.percentStep))
    end

    self.tireTracksValues = {}
    self.tireTracksTexts = {}
    self.tireTracksStep = 0.5
    for i=0, 4, self.tireTracksStep do
        table.insert(self.tireTracksTexts, string.format("%d%%", i*100))
        table.insert(self.tireTracksValues, i)
    end

    self.maxMirrorsTexts = {}
    for i=0,7 do
        table.insert(self.maxMirrorsTexts, string.format("%d", i))
    end

    self.resolutionTexts = {}
    local numR = getNumOfScreenModes()
    for i = 0, numR - 1 do
        local x, y = getScreenModeInfo(i)
        local aspect = x / y
        local aspectStr
        if aspect == 1.25 then
            aspectStr = "(5:4)"
        elseif aspect > 1.3 and aspect < 1.4 then
            aspectStr = "(4:3)"
        elseif aspect > 1.7 and aspect < 1.8 then
            aspectStr = "(16:9)"
       elseif aspect > 2.3 and aspect < 2.4 then
            aspectStr = "(21:9)"
        else
            aspectStr = string.format("(%1.0f:10)", aspect * 10)
        end

        table.insert(self.resolutionTexts, string.format("%dx%d %s", x, y, aspectStr))
    end

    self.fullscreenModeTexts = {}
    for i = 0, FullscreenMode.NUM - 1 do
        if i == FullscreenMode.WINDOWED then
            table.insert(self.fullscreenModeTexts, self.l10n:getText("ui_windowed"))
        elseif i == FullscreenMode.WINDOWED_FULLSCREEN then
            table.insert(self.fullscreenModeTexts, self.l10n:getText("ui_windowed_fullscreen"))
        else
            -- FullscreenMode.EXCLUSIVE_FULLSCREEN
            table.insert(self.fullscreenModeTexts, self.l10n:getText("ui_exclusive_fullscreen"))
        end
    end

    self.mpLanguageTexts = {}
    local numL = getNumOfLanguages()
    for i=0, numL-1 do
        table.insert(self.mpLanguageTexts, getLanguageName(i))
    end

    self.inputHelpModeTexts = {self.l10n:getText("ui_auto"), self.l10n:getText("ui_keyboard"), self.l10n:getText("ui_gamepad")}

    self.frameLimitMapping = {}
    self.frameLimitMappingReverse = {}
    self.frameLimitTexts = {}
    for _, value in ipairs(g_gameSettings.frameLimitValues) do
        table.insert(self.frameLimitTexts, tostring(value))
        self.frameLimitMapping[value] = #self.frameLimitTexts
        self.frameLimitMappingReverse[#self.frameLimitTexts] = value
    end

    self.directionChangeModeTexts = {
        [VehicleMotor.DIRECTION_CHANGE_MODE_AUTOMATIC] = self.l10n:getText("ui_directionChangeModeAutomatic"),
        [VehicleMotor.DIRECTION_CHANGE_MODE_MANUAL] = self.l10n:getText("ui_directionChangeModeManual")
    }

    self.gearShiftModeTexts = {
        [VehicleMotor.SHIFT_MODE_AUTOMATIC] = self.l10n:getText("ui_gearShiftModeAutomatic"),
        [VehicleMotor.SHIFT_MODE_MANUAL] = self.l10n:getText("ui_gearShiftModeManual"),
    }
    -- Consoles are gamepad only, and we cannot properly map the clutch there
    if not Platform.isConsole then
        self.gearShiftModeTexts[VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH] = self.l10n:getText("ui_gearShiftModeManualClutch")
    end

    self.hudSpeedGaugeTexts = {
        [SpeedMeterDisplay.GAUGE_MODE_RPM] = self.l10n:getText("ui_hudSpeedGaugeRPM"),
        [SpeedMeterDisplay.GAUGE_MODE_SPEED] = self.l10n:getText("ui_hudSpeedGaugeSpeed"),
    }

    --self.consoleResolutionTexts = { self.l10n:getText("ui_fullhd_desc"), self.l10n:getText("ui_quadhd_desc"), self.l10n:getText("ui_ultrahd_desc") }
    self.consoleResolutionTexts = { self.l10n:getText("ui_fullhd_desc"), self.l10n:getText("ui_quadhd_desc") }
    self.consoleRenderQualityTexts = { self.l10n:getText("button_normal"), self.l10n:getText("button_enhanced") }

    self.deadzoneValues = {}
    self.deadzoneTexts = {}
    self.deadzoneStep = 0.01
    for i = 0, 0.3+0.001, self.deadzoneStep do
        table.insert(self.deadzoneTexts, string.format("%d%%", math.floor(i * 100+0.001)))
        table.insert(self.deadzoneValues, i)
    end

    self.sensitivityValues = {}
    self.sensitivityTexts = {}
    self.sensitivityStep = 0.25
    for i = 0.5, 2, self.sensitivityStep do
        table.insert(self.sensitivityTexts, string.format("%d%%", i * 100))
        table.insert(self.sensitivityValues, i)
    end

    self.headTrackingSensitivityValues = {}
    self.headTrackingSensitivityTexts = {}
    self.headTrackingSensitivityStep = 0.05
    for i = 0, 1+0.001, self.headTrackingSensitivityStep do
        table.insert(self.headTrackingSensitivityTexts, string.format("%d%%", i * 100+0.001))
        table.insert(self.headTrackingSensitivityValues, i)
    end
end


---
function SettingsModel:getDeadzoneTexts()
    return self.deadzoneTexts
end


---
function SettingsModel:getSensitivityTexts()
    return self.sensitivityTexts
end


---
function SettingsModel:getHeadTrackingSensitivityTexts()
    return self.headTrackingSensitivityTexts
end


---
function SettingsModel:getDeviceHasAxisDeadzone(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings ~= nil and settings.deadzones[axisIndex] ~= nil
end


---
function SettingsModel:getDeviceHasAxisSensitivity(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings ~= nil and settings.sensitivities[axisIndex] ~= nil
end


---
function SettingsModel:getNumDevices()
    return #self.deviceSettings
end


---
function SettingsModel:nextDevice()
    self.currentDevice = self.currentDevice + 1
    if self.currentDevice > #self.deviceSettings then
        self.currentDevice = 1
    end
end


---
function SettingsModel:getCurrentDeviceName()
    local setting = self.deviceSettings[self.currentDevice]
    if setting ~= nil then
        return setting.device.deviceName
    end

    return ""
end


---
function SettingsModel:initDeviceSettings()
    self.deviceSettings = {}
    self.currentDevice = 0

    for _, device in pairs(g_inputBinding.devicesByInternalId) do
        local deadzones = {}
        local sensitivities = {}
        local mouseSensitivity = {}
        local headTrackingSensitivity = {}
        table.insert(self.deviceSettings, {device=device, deadzones=deadzones, sensitivities=sensitivities, mouseSensitivity=mouseSensitivity, headTrackingSensitivity=headTrackingSensitivity})

        for axisIndex = 0, Input.MAX_NUM_AXES - 1 do
            if getHasGamepadAxis(axisIndex, device.internalId) then
                local deadzone = device:getDeadzone(axisIndex)
                local deadzoneValue = Utils.getValueIndex(deadzone, self.deadzoneValues)
                deadzones[axisIndex] = {current = deadzoneValue, saved = deadzoneValue}

                local sensitivity = device:getSensitivity(axisIndex)
                local sensitivityValue = Utils.getValueIndex(sensitivity, self.sensitivityValues)
                sensitivities[axisIndex] = {current = sensitivityValue, saved = sensitivityValue}
            end
        end

        if device.category == InputDevice.CATEGORY.KEYBOARD_MOUSE then
            local scale, _ = g_inputBinding:getMouseMotionScale()
            local value = Utils.getValueIndex(scale, self.sensitivityValues)
            mouseSensitivity.current = value
            mouseSensitivity.saved = value
        end


        local value = Utils.getValueIndex(getCameraTrackingSensitivity(), self.headTrackingSensitivityValues)
        headTrackingSensitivity.current = value
        headTrackingSensitivity.saved = value

        self.currentDevice = 1
    end
end


---
function SettingsModel:hasDeviceChanges()
    for _, settings in ipairs(self.deviceSettings) do
        for axisIndex, _ in pairs(settings.deadzones) do
            local deadzone = settings.deadzones[axisIndex]
            if deadzone.current ~= deadzone.saved then
                return true
            end

            local sensitivity = settings.sensitivities[axisIndex]
            if sensitivity.current ~= sensitivity.saved then
                return true
            end
        end

        if settings.device.category == InputDevice.CATEGORY.KEYBOARD_MOUSE then
            local mouseSensitivity = settings.mouseSensitivity
            if mouseSensitivity.current ~= mouseSensitivity.saved then
                return true
            end
        end

        local headTrackingSensitivity = settings.headTrackingSensitivity
        if headTrackingSensitivity.current ~= headTrackingSensitivity.saved then
            return true
        end
    end

    return false
end


---
function SettingsModel:saveDeviceChanges()
    local changedSettings = false
    for _, settings in ipairs(self.deviceSettings) do
        local device = settings.device
        for axisIndex, _ in pairs(settings.deadzones) do
            local deadzones = settings.deadzones[axisIndex]
            local deadzone = self.deadzoneValues[deadzones.current]
            deadzones.saved = deadzones.current
            device:setDeadzone(axisIndex, deadzone)

            local sensitivities = settings.sensitivities[axisIndex]
            local sensitivity = self.sensitivityValues[sensitivities.current]
            sensitivities.saved = sensitivities.current

            device:setSensitivity(axisIndex, sensitivity)
            changedSettings = true
        end
        if settings.device.category == InputDevice.CATEGORY.KEYBOARD_MOUSE then
            local mouseSensitivity = settings.mouseSensitivity
            if mouseSensitivity.current ~= mouseSensitivity.saved then
                g_inputBinding:setMouseMotionScale(self.sensitivityValues[mouseSensitivity.current])
                mouseSensitivity.saved = mouseSensitivity.current
                changedSettings = true
            end

            local headTrackingSensitivity = settings.headTrackingSensitivity
            if headTrackingSensitivity.current ~= headTrackingSensitivity.saved then
                setCameraTrackingSensitivity(self.headTrackingSensitivityValues[headTrackingSensitivity.current])
                headTrackingSensitivity.saved = headTrackingSensitivity.current
                changedSettings = true
            end
        end
    end

    if changedSettings then
        g_inputBinding:applyGamepadDeadzones()
        g_inputBinding:saveToXMLFile()
    end
end


---
function SettingsModel:resetDeviceChanges()
    for _, settings in ipairs(self.deviceSettings) do
        for axisIndex, _ in pairs(settings.deadzones) do
            local deadzone = settings.deadzones[axisIndex]
            deadzone.current = deadzone.saved

            local sensitivity = settings.sensitivities[axisIndex]
            sensitivity.current = deadzone.saved
        end

        settings.mouseSensitivity.current = settings.mouseSensitivity.saved
        settings.headTrackingSensitivity.current = settings.headTrackingSensitivity.saved
    end
end


---
function SettingsModel:setDeviceDeadzoneValue(axisIndex, value)
    local settings = self.deviceSettings[self.currentDevice]
    if settings ~= nil then
        settings.deadzones[axisIndex].current = value
    end
end









---
function SettingsModel:setDeviceSensitivityValue(axisIndex, value)
    local settings = self.deviceSettings[self.currentDevice]
    if settings ~= nil then
        settings.sensitivities[axisIndex].current = value
    end
end


---
function SettingsModel:getCurrentDeviceSensitivityValue(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    if settings ~= nil then
        return self.sensitivityValues[settings.sensitivities[axisIndex].current]
    end
end



---
function SettingsModel:setMouseSensitivity(value)
    local settings = self.deviceSettings[self.currentDevice]
    if settings ~= nil then
        settings.mouseSensitivity.current = value
    end
end


---
function SettingsModel:setHeadTrackingSensitivity(value)
    local settings = self.deviceSettings[self.currentDevice]
    if settings ~= nil then
        settings.headTrackingSensitivity.current = value
    end
end


---
function SettingsModel:getDeviceAxisDeadzoneValue(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings.deadzones[axisIndex].current
end


---
function SettingsModel:getDeviceAxisSensitivityValue(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings.sensitivities[axisIndex].current
end


---
function SettingsModel:getMouseSensitivityValue(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings.mouseSensitivity.current
end


---
function SettingsModel:getHeadTrackingSensitivityValue(axisIndex)
    local settings = self.deviceSettings[self.currentDevice]
    return settings.headTrackingSensitivity.current
end


---
function SettingsModel:getIsDeviceMouse()
    local settings = self.deviceSettings[self.currentDevice]
    return settings ~= nil and settings.device.category == InputDevice.CATEGORY.KEYBOARD_MOUSE
end

























---
function SettingsModel:setConsoleResolution(value)
    local displayResolution = self:getValue(SettingsModel.SETTING.CONSOLE_RESOLUTION)
    if not getNeoMode() or displayResolution then
        self:setValue(SettingsModel.SETTING.CONSOLE_RENDER_QUALITY, 1)
    else
        self:setValue(SettingsModel.SETTING.CONSOLE_RENDER_QUALITY, self.settings[SettingsModel.SETTING.CONSOLE_RENDER_QUALITY].saved)
    end
    self:setValue(SettingsModel.SETTING.CONSOLE_RESOLUTION, value)
end


---
function SettingsModel:getConsoleIsRenderQualityDisabled()
    local displayResolution = self:getValue(SettingsModel.SETTING.CONSOLE_RESOLUTION)
    return not getNeoMode() or displayResolution ~= 1
end


---
function SettingsModel:getConsoleIsResolutionVisible()
    return getNeoMode() and get4kAvailable()
end


---
function SettingsModel:getConsoleIsRenderQualityVisible()
    return getNeoMode()
end


---
function SettingsModel:getConsoleResolutionTexts()
    return self.consoleResolutionTexts
end


---
function SettingsModel:getConsoleRenderQualityTexts()
    return self.consoleRenderQualityTexts
end


---
function SettingsModel:getResolutionTexts()
    return self.resolutionTexts
end


---
function SettingsModel:getFullscreenModeTexts()
    return self.fullscreenModeTexts
end


---
function SettingsModel:getMPLanguageTexts()
    return self.mpLanguageTexts
end


---
function SettingsModel:getFrameLimitTexts()
    return self.frameLimitTexts
end


---
function SettingsModel:getInputHelpModeTexts()
    return self.inputHelpModeTexts
end


---
function SettingsModel:getDirectionChangeModeTexts()
    return self.directionChangeModeTexts
end


---
function SettingsModel:getGearShiftModeTexts()
    return self.gearShiftModeTexts
end


---
function SettingsModel:getHudSpeedGaugeTexts()
    return self.hudSpeedGaugeTexts
end


---
function SettingsModel:getLanguageTexts()
    return g_availableLanguageNamesTable
end


---
function SettingsModel:getIsLanguageDisabled()
    return #g_availableLanguagesTable <= 1 or GS_IS_STEAM_VERSION or GS_PLATFORM_GGP
end


---
function SettingsModel:getPerformanceClassTexts()
    local class, isCustom = getPerformanceClass()

    local texts = {}
    table.insert(texts, self.l10n:getText("setting_low"))
    table.insert(texts, self.l10n:getText("setting_medium"))
    table.insert(texts, self.l10n:getText("setting_high"))
    table.insert(texts, self.l10n:getText("setting_veryHigh"))

    if not GS_IS_MOBILE_VERSION then
        local settings = GameSettings.PERFORMANCE_CLASS_PRESETS[Utils.getPerformanceClassId()]
        isCustom = isCustom or (settings[SettingsModel.SETTING.LIGHTS_PROFILE] ~= g_gameSettings:getValue(SettingsModel.SETTING.LIGHTS_PROFILE))
        isCustom = isCustom or (settings[SettingsModel.SETTING.MAX_MIRRORS] ~= g_gameSettings:getValue(SettingsModel.SETTING.MAX_MIRRORS))
        isCustom = isCustom or (settings[SettingsModel.SETTING.REAL_BEACON_LIGHTS] ~= g_gameSettings:getValue(SettingsModel.SETTING.REAL_BEACON_LIGHTS))

        if isCustom then
            local index = Utils.getPerformanceClassIndex(class)
            texts[index] = texts[index] .. " (Custom)"
        end
    end

    return texts, class, isCustom
end


---Get valid audio volume texts.
function SettingsModel:getHDRPeakBrightnessTexts()
    return self.hdrPeakBrightnessTexts
end


---
function SettingsModel:getMSAATexts()
    return self.msaaTexts
end


---
function SettingsModel:getPostProcessAATexts()
    return self.postProcessAntiAliasingTexts
end


---
function SettingsModel:getPostProcessAAToolTip()
    return self.postProcessAntiAliasingToolTip
end


---
function SettingsModel:getDLSSTexts()
    return self.dlssTexts
end


---
function SettingsModel:getFidelityFxSRTexts()
    return self.fidelityFxSRTexts
end


---
function SettingsModel:getFidelityFxSR20Texts()
    return self.fidelityFxSR20Texts
end


---
function SettingsModel:getValarTexts()
    return self.valarTexts
end


---
function SettingsModel:getXeSSTexts()
    return self.xeSSTexts
end







---
function SettingsModel:getShadingRateQualityTexts()
    return self.fourStateTexts
end


---
function SettingsModel:getShadowQualityTexts()
    return self.shadowQualityTexts
end


---
function SettingsModel:getSSAOQualityTexts()
    return self.ssaoQualityTexts
end


---
function SettingsModel:getCloudQualityTexts()
    return self.cloudQualityTexts
end


---
function SettingsModel:getShadowDistanceQualityTexts()
    return self.shadowDistanceQualityTexts
end


---
function SettingsModel:getShaderQualityTexts()
    return self.fourStateTexts
end


---
function SettingsModel:getTextureResolutionTexts()
    return self.lowHighTexts
end


---
function SettingsModel:getTextureFilteringTexts()
    return self.textureFilteringTexts
end


---
function SettingsModel:getShadowMapFilteringTexts()
    return self.lowHighTexts
end


---
function SettingsModel:getTerraingQualityTexts()
    return self.fourStateTexts
end


---
function SettingsModel:getLightsProfileTexts()
    return self.fourStateTexts
end


---
function SettingsModel:getShadowMapLightsTexts()
    return self.shadowMapMaxLightsTexts
end


---
function SettingsModel:getObjectDrawDistanceTexts()
    return self.perentageTexts
end


---
function SettingsModel:getFoliageDrawDistanceTexts()
    return self.perentageTexts
end


---
function SettingsModel:getFoliageShadowTexts()
    return self.foliageShadowTexts
end


---
function SettingsModel:getLODDistanceTexts()
    return self.perentageTexts
end


---
function SettingsModel:getTerrainLODDistanceTexts()
    return self.perentageTexts
end


---
function SettingsModel:getVolumeMeshTessalationTexts()
    return self.perentageTexts
end


---
function SettingsModel:getMaxTireTracksTexts()
    return self.tireTracksTexts
end


---
function SettingsModel:getMaxMirrorsTexts()
    return self.maxMirrorsTexts
end


---Get valid brightness option texts.
function SettingsModel:getBrightnessTexts()
    return self.brightnessTexts
end


---Get valid FOV Y option texts.
function SettingsModel:getFovYTexts()
    return self.fovYTexts
end


---Get valid UI scale texts.
function SettingsModel:getUiScaleTexts()
    return self.uiScaleTexts
end


---Get valid audio volume texts.
function SettingsModel:getAudioVolumeTexts()
    return self.volumeTexts
end


---Get valid audio volume texts.
function SettingsModel:getVoiceInputSensitivityTexts()
    return self.voiceInputThresholdTexts
end


---Get valid audio volume texts.
function SettingsModel:getForceFeedbackTexts()
    -- Same as volume texts: Off to 100%
    return self.volumeTexts
end


---Get valid recording volume texts.
function SettingsModel:getRecordingVolumeTexts()
    return self.recordingVolumeTexts
end


---
function SettingsModel:getVoiceModeTexts()
    return self.voiceModeTexts
end


---Get valid camera sensitivity texts.
function SettingsModel:getCameraSensitivityTexts()
    return self.cameraSensitivityStrings
end


---Get valid camera sensitivity texts.
function SettingsModel:getVehicleArmSensitivityTexts()
    return self.vehicleArmSensitivityStrings
end


---Get valid real beacon light brightness texts.
function SettingsModel:getRealBeaconLightBrightnessTexts()
    return self.realBeaconLightBrightnessStrings
end


---Get valid camera sensitivity texts.
function SettingsModel:getSteeringBackSpeedTexts()
    return self.steeringBackSpeedStrings
end







---Get valid money unit (=currency) texts.
function SettingsModel:getMoneyUnitTexts()
    return self.moneyUnitTexts
end


---Get valid distance unit texts.
function SettingsModel:getDistanceUnitTexts()
    return self.distanceUnitTexts
end


---Get valid temperature unit texts.
function SettingsModel:getTemperatureUnitTexts()
    return self.temperatureUnitTexts
end


---Get valid area unit texts.
function SettingsModel:getAreaUnitTexts()
    return self.areaUnitTexts
end


---Get valid radio mode texts.
function SettingsModel:getRadioModeTexts()
    return self.radioModeTexts
end


---
function SettingsModel:getResolutionScaleTexts()
    return self.resolutionScaleTexts
end


---
function SettingsModel:getResolutionScale3dTexts()
    return self.resolutionScale3dTexts
end



























---
function SettingsModel:addConsoleResolutionSetting()
    local function readValue()
        local displayResolution, _ = SettingsModel.getConsoleResolutionStateFromMode(getDiscretePerformanceSetting())
        return displayResolution
    end

    local function writeValue(value)
        self:setConsolePerformanceSetting()
        setScreenMode(value - 1)
    end

    self:addSetting(SettingsModel.SETTING.CONSOLE_RESOLUTION, readValue, writeValue)
end


---
function SettingsModel:addConsoleRenderQualitySetting()
    local function readValue()
        local _, renderQuality = SettingsModel.getConsoleResolutionStateFromMode(getDiscretePerformanceSetting())
        return renderQuality
    end

    local function writeValue(value)
        self:setConsolePerformanceSetting()
    end

    self:addSetting(SettingsModel.SETTING.CONSOLE_RENDER_QUALITY, readValue, writeValue)
end


---
function SettingsModel:setConsolePerformanceSetting()
    local renderQuality = self:getValue(SettingsModel.SETTING.CONSOLE_RENDER_QUALITY)
    local resolution = self:getValue(SettingsModel.SETTING.CONSOLE_RESOLUTION)
    local discreteSetting = SettingsModel.getModeFromResolutionState(resolution, renderQuality)
    setDiscretePerformanceSetting(discreteSetting)
end











































---
function SettingsModel:addMSAASetting()
    local function readValue()
        return SettingsModel.getMSAAIndex(getMSAA())
    end

    local function writeValue(value)
        setMSAA(SettingsModel.getMSAAFromIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.MSAA, readValue, writeValue)
end














































































































---
function SettingsModel:addShadingRateQualitySetting()
    local function readValue()
        return getShadingRateQuality() + 1
    end

    local function writeValue(value)
        setShadingRateQuality(math.max(value - 1, 0))
    end

    self:addSetting(SettingsModel.SETTING.SHADING_RATE_QUALITY, readValue, writeValue, true)
end


---
function SettingsModel:addShadowDistanceQualitySetting()
    local function readValue()
        return getShadowDistanceQuality() + 1
    end

    local function writeValue(value)
        setShadowDistanceQuality(math.max(value - 1, 0))
    end

    self:addSetting(SettingsModel.SETTING.SHADOW_DISTANCE_QUALITY, readValue, writeValue, true)
end


---
function SettingsModel:addSSAOQualitySetting()
    local function readValue()
        local numSamples = getSSAOQuality()
        local index = self.ssaoSamplesToQualityIndex[numSamples] or 1
        return index
    end

    local function writeValue(value)
        local numSamples = self.ssaoQualityValues[value]
        setSSAOQuality(numSamples)
    end

    self:addSetting(SettingsModel.SETTING.SSAO_QUALITY, readValue, writeValue, true)
end


---
function SettingsModel:addCloudQualitySetting()
    local function readValue()
        return math.max(getCloudQuality(), 1)
    end

    local function writeValue(value)
        setCloudQuality(value)
    end

    self:addSetting(SettingsModel.SETTING.CLOUD_QUALITY, readValue, writeValue, true)
end


---
function SettingsModel:addTextureFilteringSetting()
    local function readValue()
        return SettingsModel.getTextureFilteringIndex(getFilterTrilinear(), getFilterAnisotropy())
    end

    local function writeValue(value)
        local isTrilinear, anisoValue = SettingsModel.getTextureFilteringByIndex(value)
        setFilterTrilinear(isTrilinear)
        setFilterAnisotropy(anisoValue)
    end

    self:addSetting(SettingsModel.SETTING.TEXTURE_FILTERING, readValue, writeValue, false) -- restart so that all texture are created with the right filtering
end


---
function SettingsModel:addTextureResolutionSetting()
    local function readValue()
        return SettingsModel.getTextureResolutionIndex(getTextureResolution())
    end

    local function writeValue(value)
        setTextureResolution(SettingsModel.getTextureResolutionByIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.TEXTURE_RESOLUTION, readValue, writeValue, false) -- restart so that all texture are created with the right resolution
end


---
function SettingsModel:addShadowQualitySetting()
    local function readValue()
        return SettingsModel.getShadowQualityIndex(getShadowQuality(), getHasShadowFocusBox())
    end

    local function writeValue(value)
        setShadowQuality(SettingsModel.getShadowQualityByIndex(value))
        setHasShadowFocusBox(SettingsModel.getHasShadowFocusBoxByIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.SHADOW_QUALITY, readValue, writeValue, false)
end


---
function SettingsModel:addShaderQualitySetting()
    local function readValue()
        return SettingsModel.getShaderQualityIndex(getShaderQuality())
    end

    local function writeValue(value)
        setShaderQuality(SettingsModel.getShaderQualityByIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.SHADER_QUALITY, readValue, writeValue, false) -- restart needed to use correct shader cache
end


---
function SettingsModel:addShadowMapFilteringSetting()
    local function readValue()
        return SettingsModel.getShadowMapFilterIndex(getShadowMapFilterSize())
    end

    local function writeValue(value)
        setShadowMapFilterSize(SettingsModel.getShadowMapFilterByIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.SHADOW_MAP_FILTERING, readValue, writeValue, false) -- restart needed to use correct shader cache
end


---
function SettingsModel:addShadowMaxLightsSetting()
    local function readValue()
        return getMaxNumShadowLights()
    end

    local function writeValue(value)
        setMaxNumShadowLights(value)
    end

    self:addSetting(SettingsModel.SETTING.MAX_LIGHTS, readValue, writeValue, true)
end


---
function SettingsModel:addTerrainQualitySetting()
    local function readValue()
        return SettingsModel.getTerrainQualityIndex(getTerrainQuality())
    end

    local function writeValue(value)
        setTerrainQuality(SettingsModel.getTerrainQualityByIndex(value))
    end

    self:addSetting(SettingsModel.SETTING.TERRAIN_QUALITY, readValue, writeValue, false) -- restart needed to use correct shader cache
end


---
function SettingsModel:addObjectDrawDistanceSetting()
    local function readValue()
        return Utils.getValueIndex(getViewDistanceCoeff(), self.percentValues)
    end

    local function writeValue(value)
        setViewDistanceCoeff(self.percentValues[value])
    end

    self:addSetting(SettingsModel.SETTING.OBJECT_DRAW_DISTANCE, readValue, writeValue, true)
end


---
function SettingsModel:addFoliageDrawDistanceSetting()
    local function readValue()
        return Utils.getValueIndex(getFoliageViewDistanceCoeff(), self.percentValues)
    end

    local function writeValue(value)
        setFoliageViewDistanceCoeff(self.percentValues[value])
    end

    self:addSetting(SettingsModel.SETTING.FOLIAGE_DRAW_DISTANCE, readValue, writeValue, true)
end


---
function SettingsModel:addFoliageShadowSetting()
    local function readValue()
        return getAllowFoliageShadows()
    end

    local function writeValue(value)
        setAllowFoliageShadows(value)
    end

    self:addSetting(SettingsModel.SETTING.FOLIAGE_SHADOW, readValue, writeValue, false)
end


---
function SettingsModel:addLODDistanceSetting()
    local function readValue()
        return Utils.getValueIndex(getLODDistanceCoeff(), self.percentValues)
    end

    local function writeValue(value)
        setLODDistanceCoeff(self.percentValues[value])
    end

    self:addSetting(SettingsModel.SETTING.LOD_DISTANCE, readValue, writeValue, true)
end


---
function SettingsModel:addTerrainLODDistanceSetting()
    local function readValue()
        return Utils.getValueIndex(getTerrainLODDistanceCoeff(), self.percentValues)
    end

    local function writeValue(value)
        setTerrainLODDistanceCoeff(self.percentValues[value])
    end

    self:addSetting(SettingsModel.SETTING.TERRAIN_LOD_DISTANCE, readValue, writeValue, true)
end


---
function SettingsModel:addVolumeMeshTessellationSetting()
    local function readValue()
        return Utils.getValueIndex(SettingsModel.getVolumeMeshTessellationCoeff(), self.percentValues)
    end

    local function writeValue(value)
        SettingsModel.setVolumeMeshTessellationCoeff(self.percentValues[value])
    end

    self:addSetting(SettingsModel.SETTING.VOLUME_MESH_TESSELLATION, readValue, writeValue, true)
end


---
function SettingsModel:addMaxTireTracksSetting()
    local function readValue()
        return Utils.getValueIndex(getTyreTracksSegmentsCoeff(), self.tireTracksValues)
    end

    local function writeValue(value)
        setTyreTracksSegementsCoeff(self.tireTracksValues[value])
    end

    self:addSetting(SettingsModel.SETTING.MAX_TIRE_TRACKS, readValue, writeValue, true)
end
