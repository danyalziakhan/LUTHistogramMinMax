local Cron = require('Modules/Cron')

local isOverlayOpen = false

local defaultSize = 48
local defaultMinRange = 0.01
local defaultMaxRange = 100.0
local minimumEffectiveMinRange = 0.0000000000000000000000000000000000001
local maximumEffectiveMinRange = 0.1
local minimumEffectiveMaxRange = 0.1
local maximumEffectiveMaxRange = 100000000000000000000000000000000000000.0

local presetInputFileName = ""
local selectedPresetName = ""
local presetList = {}

local configFileName = "config.json"
local settings = {
    Current = {
        size = 48,
        minRange = 0.01,
        maxRange = 100.0,
    }
}

local preset = {
    size = 48,
    minRange = 0.01,
    maxRange = 100.0,
}

function LoadSettings()
    local file = io.open(configFileName, "r")
    if file ~= nil then
        local configStr = file:read("*a")
        settings = json.decode(configStr)
        file:close()
    end
end

function SaveSettings()
    local file = io.open(configFileName, "w")
    if file ~= nil then
        local jconfig = json.encode(settings)
        file:write(jconfig)
        file:close()
    end
end

function LoadPreset(filename)
    if not StrEndsWith(filename, ".json") then
        filename = filename .. ".json"
    end

    local file = io.open("presets\\" .. filename, "r")
    if file ~= nil then
        local configStr = file:read("*a")
        preset = json.decode(configStr)
        file:close()
    end
end

function SavePreset(filename)
    if not StrEndsWith(filename, ".json") then
        filename = filename .. ".json"
    end

    local file = io.open("presets\\" .. filename, "w")
    if file ~= nil then
        local jconfig = json.encode(preset)
        file:write(jconfig)
        file:close()
    end
end

function DeletePreset(filename)
    if not StrEndsWith(filename, ".json") then
        filename = filename .. ".json"
    end

    os.remove("presets\\" .. filename)
end

function GetAvailablePresets()
    for _, file in ipairs(dir('presets')) do
        table.insert(presetList, StrReplace(file.name, ".json", ""))
    end
end

function StrEndsWith(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

function StrReplace(str, old, new)
    local search_start_idx = 1

    while true do
        local start_idx, end_idx = str:find(old, search_start_idx, true)
        if (not start_idx) then
            break
        end

        local postfix = str:sub(end_idx + 1)
        str = str:sub(1, (start_idx - 1)) .. new .. postfix

        search_start_idx = -1 * postfix:len()
    end

    return str
end

local function removeDuplicates(arr)
    local newArray = {}
    local checkerTbl = {}
    for _, element in ipairs(arr) do
        if not checkerTbl[element] then -- if there is not yet a value at the index of element, then it will be nil, which will operate like false in an if statement
            checkerTbl[element] = true
            table.insert(newArray, element)
        end
    end
    return newArray
end

registerForEvent("onOverlayOpen", function()
    isOverlayOpen = true
end)

registerForEvent("onOverlayClose", function()
    isOverlayOpen = false
end)

registerForEvent("onDraw", function()
    if not isOverlayOpen then
        return
    end

    local itemWidth = 360
    local sameLineWidth = 452

    ImGui.Begin("LUT Histogram Min/Max", ImGuiWindowFlags.AlwaysAutoResize)
    ImGui.PushItemWidth(itemWidth);

    settings.Current.size, isSizeChanged = ImGui.SliderInt(" Size ", settings.Current.size, 2, 128)

    if isSizeChanged then
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##1") then
        settings.Current.size = 2
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##1") then
        settings.Current.size = defaultSize
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##1") then
        settings.Current.size = 128
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        SaveSettings()
    end

    ImGui.Spacing()
    settings.Current.minRange, isMinRangeChanged = ImGui.DragFloat(" Min Range ", settings.Current.minRange,
        settings.Current.minRange * 0.01, minimumEffectiveMinRange, maximumEffectiveMinRange, "%.37f",
        ImGuiSliderFlags.ClampOnInput)

    if isMinRangeChanged then
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##2") then
        settings.Current.minRange = minimumEffectiveMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##2") then
        settings.Current.minRange = defaultMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##2") then
        settings.Current.minRange = maximumEffectiveMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        SaveSettings()
    end

    ImGui.Spacing()
    settings.Current.maxRange, isMaxRangeChanged = ImGui.DragFloat(" Max Range ", settings.Current.maxRange,
        settings.Current.maxRange * 0.01, minimumEffectiveMaxRange, maximumEffectiveMaxRange, "%.2f",
        ImGuiSliderFlags.ClampOnInput)

    if isMaxRangeChanged then
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##3") then
        settings.Current.maxRange = minimumEffectiveMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##3") then
        settings.Current.maxRange = defaultMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##3") then
        settings.Current.maxRange = maximumEffectiveMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.Spacing()
    if ImGui.Button(" Reset Defaults ") then
        settings.Current.size = defaultSize
        settings.Current.minRange = defaultMinRange
        settings.Current.maxRange = defaultMaxRange
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    ImGui.Spacing()

    presetInputFileName, _ = ImGui.InputText("##SavePresetFilename", presetInputFileName, 44)

    ImGui.SameLine(384)
    if ImGui.Button(" Save Preset ") then
        preset.size = settings.Current.size
        preset.minRange = settings.Current.minRange
        preset.maxRange = settings.Current.maxRange
        SavePreset(presetInputFileName)
        table.insert(presetList, presetInputFileName)
        presetList = removeDuplicates(presetList)
        presetInputFileName = ""
    end


    ImGui.Spacing()
    if ImGui.BeginCombo("##LoadPresetCombo", selectedPresetName, ImGuiComboFlags.HeightLarge) then
        for _, option in ipairs(presetList) do
            if ImGui.Selectable(option, (option == selectedPresetName)) then
                selectedPresetName = option
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end

    ImGui.SameLine(384)
    if ImGui.Button(" Load Preset ") then
        LoadPreset(selectedPresetName)
        settings.Current.size = preset.size
        settings.Current.minRange = preset.minRange
        settings.Current.maxRange = preset.maxRange
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
        SaveSettings()
    end

    ImGui.SameLine(481)
    if ImGui.Button(" Delete Preset ") then
        for i, v in pairs(presetList) do
            if v == selectedPresetName then
                table.remove(presetList, i)
                os.remove("presets\\" .. selectedPresetName .. ".json")
                selectedPresetName = ""
            end
        end
    end
    
    ImGui.PopItemWidth();
    ImGui.End()
end)

registerForEvent('onInit', function()
    LoadSettings()
    GetAvailablePresets()
    GameOptions.SetInt('Rendering/LUT', 'Size', settings.Current.size)
    GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.Current.minRange)
    GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.Current.maxRange)
end)

registerForEvent('onUpdate', function(delta)
    -- This is required for Cron to function
    Cron.Update(delta)
end)
