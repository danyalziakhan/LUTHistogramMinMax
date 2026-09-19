local Cron = require('Modules/Cron')
local Localization = require('Modules/Localization')

local UIText = Localization.GetUIText()

local configFileName = 'config.json'
local presetsFolder = 'presets'
local optionGroup = 'Rendering/LUT'
local saveDelay = 0.5
local itemWidth = 360

local limits = {
    size = { min = 2, max = 128, default = 48 },
    minRange = { min = 1e-37, max = 0.1, default = 0.001 },
    maxRange = { min = 0.1, max = 1e38, default = 100.0 },
}

local errorColor = { 1.0, 0.23, 0.23 }

local settings = nil
local isOverlayOpen = false
local isFirstDraw = true
local saveTimer = nil
local presetInputName = ''
local presetList = {}
local selectedPresetName = ''
local presetError = nil

local function Clamp(value, low, high)
    if type(value) ~= 'number' or value ~= value then
        return nil
    end

    return math.max(low, math.min(high, value))
end

local function SanitizeValues(loaded)
    local result = {
        size = limits.size.default,
        minRange = limits.minRange.default,
        maxRange = limits.maxRange.default,
    }

    if type(loaded) ~= 'table' then
        return result
    end

    for key, limit in pairs(limits) do
        local value = Clamp(loaded[key], limit.min, limit.max)

        if value then
            result[key] = value
        end
    end

    result.size = math.floor(result.size + 0.5)

    return result
end

local function ReadJson(path)
    local file = io.open(path, 'r')

    if not file then
        return nil
    end

    local content = file:read('*a')
    file:close()

    local ok, result = pcall(json.decode, content)

    if ok and type(result) == 'table' then
        return result
    end

    return nil
end

local function WriteJson(path, data)
    local file = io.open(path, 'w')

    if not file then
        return false
    end

    file:write(json.encode(data))
    file:close()

    return true
end

local function ApplySettings()
    GameOptions.SetInt(optionGroup, 'Size', settings.size)
    GameOptions.SetFloat(optionGroup, 'MinRange', settings.minRange)
    GameOptions.SetFloat(optionGroup, 'MaxRange', settings.maxRange)
end

local function SaveSettings()
    if saveTimer then
        Cron.Halt(saveTimer)
        saveTimer = nil
    end

    WriteJson(configFileName, settings)
end

local function RequestSave()
    if saveTimer then
        Cron.Halt(saveTimer)
    end

    saveTimer = Cron.After(saveDelay, SaveSettings)
end

local function SetValue(key, value)
    local limit = limits[key]
    value = Clamp(value, limit.min, limit.max)

    if not value then
        return
    end

    if key == 'size' then
        value = math.floor(value + 0.5)
    end

    settings[key] = value
    ApplySettings()
    RequestSave()
end

local function Trim(text)
    return (text:gsub('^%s*(.-)%s*$', '%1'))
end

local function PresetPath(name)
    return presetsFolder .. '\\' .. name .. '.json'
end

local function SortPresets()
    table.sort(presetList, function(a, b)
        return a:lower() < b:lower()
    end)
end

local function RefreshPresets()
    presetList = {}

    local ok, entries = pcall(dir, presetsFolder)

    if ok and type(entries) == 'table' then
        for _, entry in ipairs(entries) do
            local name = entry.name and entry.name:match('^(.+)%.[jJ][sS][oO][nN]$')

            if name then
                table.insert(presetList, name)
            end
        end
    end

    SortPresets()
    selectedPresetName = presetList[1] or ''
end

local function FindPreset(name)
    for index, existing in ipairs(presetList) do
        -- file names are case insensitive on Windows
        if existing:lower() == name:lower() then
            return index
        end
    end

    return nil
end

local function SavePreset()
    local name = Trim(presetInputName):gsub('%.[jJ][sS][oO][nN]$', '')

    if name == '' then
        presetError = UIText.fileNameError
        return
    end

    if name:find('[%c\\/:%*%?"<>|]') or name:match('^%.+$') then
        presetError = UIText.fileNameInvalidError
        return
    end

    local preset = { size = settings.size, minRange = settings.minRange, maxRange = settings.maxRange }

    if not WriteJson(PresetPath(name), preset) then
        presetError = UIText.presetSaveError
        return
    end

    local index = FindPreset(name)

    if index then
        presetList[index] = name
    else
        table.insert(presetList, name)
    end

    SortPresets()
    selectedPresetName = name
    presetInputName = ''
    presetError = nil
end

local function LoadPreset()
    local loaded = ReadJson(PresetPath(selectedPresetName))

    if not loaded then
        presetError = UIText.presetLoadError
        return
    end

    local values = SanitizeValues(loaded)
    settings.size = values.size
    settings.minRange = values.minRange
    settings.maxRange = values.maxRange
    ApplySettings()
    RequestSave()
    presetError = nil
end

local function DeletePreset()
    local index = FindPreset(selectedPresetName)

    if not index then
        return
    end

    os.remove(PresetPath(presetList[index]))
    table.remove(presetList, index)
    selectedPresetName = presetList[math.min(index, #presetList)] or ''
    presetError = nil
end

local function Tooltip(text)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(text)
    end
end

local function DragFloat(label, value, low, high, format)
    local speed = value * 0.02
    local clampFlag = ImGuiSliderFlags and ImGuiSliderFlags.AlwaysClamp

    if clampFlag then
        return ImGui.DragFloat(label, value, speed, low, high, format, clampFlag)
    end

    return ImGui.DragFloat(label, value, speed, low, high, format)
end

local function DrawStepButtons(key, buttonsX)
    local limit = limits[key]
    local id = '##LUTHistogramMinMax' .. key

    ImGui.SameLine(buttonsX)

    if ImGui.SmallButton(' << ' .. id .. 'Min') then
        SetValue(key, limit.min)
    end

    Tooltip(UIText.minButtonTooltip)
    ImGui.SameLine()

    if ImGui.SmallButton(UIText.resetButton .. id .. 'Reset') then
        SetValue(key, limit.default)
    end

    ImGui.SameLine()

    if ImGui.SmallButton(' >> ' .. id .. 'Max') then
        SetValue(key, limit.max)
    end

    Tooltip(UIText.maxButtonTooltip)
end

local function DrawValues()
    local labelWidth = math.max(
        ImGui.CalcTextSize(UIText.sizeSlider),
        ImGui.CalcTextSize(UIText.minRangeDragFloat),
        (ImGui.CalcTextSize(UIText.maxRangeDragFloat)))
    local buttonsX = itemWidth + labelWidth + 24

    ImGui.PushItemWidth(itemWidth)

    local size, isSizeChanged = ImGui.SliderInt(UIText.sizeSlider .. '##LUTHistogramMinMaxSize', settings.size,
        limits.size.min, limits.size.max)

    if isSizeChanged then
        SetValue('size', size)
    end

    Tooltip(UIText.sizeTooltip)
    DrawStepButtons('size', buttonsX)
    ImGui.Spacing()

    local minRange, isMinRangeChanged = DragFloat(UIText.minRangeDragFloat .. '##LUTHistogramMinMaxMinRange',
        settings.minRange, limits.minRange.min, limits.minRange.max, '%g')

    if isMinRangeChanged then
        SetValue('minRange', minRange)
    end

    Tooltip(UIText.minRangeTooltip)
    DrawStepButtons('minRange', buttonsX)
    ImGui.Spacing()

    local maxRange, isMaxRangeChanged = DragFloat(UIText.maxRangeDragFloat .. '##LUTHistogramMinMaxMaxRange',
        settings.maxRange, limits.maxRange.min, limits.maxRange.max, '%.2f')

    if isMaxRangeChanged then
        SetValue('maxRange', maxRange)
    end

    Tooltip(UIText.maxRangeTooltip)
    DrawStepButtons('maxRange', buttonsX)

    ImGui.PopItemWidth()
end

local function DrawPresets()
    if presetError then
        ImGui.TextColored(errorColor[1], errorColor[2], errorColor[3], 1.0, presetError)
    end

    ImGui.PushItemWidth(itemWidth)

    local name, isNameChanged = ImGui.InputText('##LUTHistogramMinMaxPresetName', presetInputName, 44)

    if isNameChanged then
        presetInputName = name
        presetError = nil
    end

    ImGui.SameLine()

    if ImGui.Button(UIText.savePresetButton .. '##LUTHistogramMinMaxSavePreset') then
        SavePreset()
    end

    Tooltip(UIText.savePresetTooltip)
    ImGui.Spacing()

    if ImGui.BeginCombo('##LUTHistogramMinMaxPresetList', selectedPresetName, ImGuiComboFlags.HeightLarge) then
        for index, option in ipairs(presetList) do
            if ImGui.Selectable(option .. '##LUTHistogramMinMaxPreset' .. index, option == selectedPresetName) then
                selectedPresetName = option
                presetError = nil
            end
        end

        ImGui.EndCombo()
    end

    ImGui.PopItemWidth()

    local hasSelection = selectedPresetName ~= ''

    if not hasSelection then
        ImGui.BeginDisabled()
    end

    ImGui.SameLine()

    if ImGui.Button(UIText.loadPresetButton .. '##LUTHistogramMinMaxLoadPreset') then
        LoadPreset()
    end

    ImGui.SameLine()

    if ImGui.Button(UIText.deletePresetButton .. '##LUTHistogramMinMaxDeletePreset') then
        DeletePreset()
    end

    if not hasSelection then
        ImGui.EndDisabled()
    end
end

local function DrawWindow()
    ImGui.Begin(UIText.modName .. '###LUTHistogramMinMax', ImGuiWindowFlags.AlwaysAutoResize)

    DrawValues()
    ImGui.Spacing()
    ImGui.Spacing()

    if ImGui.Button(UIText.resetDefaultsButton .. '##LUTHistogramMinMaxResetAll') then
        settings.size = limits.size.default
        settings.minRange = limits.minRange.default
        settings.maxRange = limits.maxRange.default
        ApplySettings()
        RequestSave()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    if isFirstDraw then
        ImGui.SetNextItemOpen(true)
        isFirstDraw = false
    end

    if ImGui.CollapsingHeader(UIText.presetsHeader .. '##LUTHistogramMinMaxPresets') then
        ImGui.Spacing()
        DrawPresets()
    end

    ImGui.End()
end

registerForEvent('onInit', function()
    UIText = Localization.GetTranslation(UIText, 'UIText')
    settings = SanitizeValues(ReadJson(configFileName))
    ApplySettings()
    RefreshPresets()
end)

registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
end)

registerForEvent('onOverlayOpen', function()
    isOverlayOpen = true
    UIText = Localization.GetTranslation(UIText, 'UIText')
end)

registerForEvent('onOverlayClose', function()
    isOverlayOpen = false

    if saveTimer then
        SaveSettings()
    end
end)

registerForEvent('onShutdown', function()
    if saveTimer then
        SaveSettings()
    end
end)

registerForEvent('onDraw', function()
    if isOverlayOpen and settings then
        DrawWindow()
    end
end)
