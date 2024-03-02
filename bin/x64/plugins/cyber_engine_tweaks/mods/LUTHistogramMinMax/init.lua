local Cron = require('Modules/Cron')

local isOverlayOpen = false

local defaultSize = 48
local defaultMinRange = 0.01
local defaultMaxRange = 100.0
local minimumEffectiveMinRange = 0.0000000000000000000000000000000000001
local maximumEffectiveMinRange = 0.1
local minimumEffectiveMaxRange = 0.1
local maximumEffectiveMaxRange = 100000000000000000000000000000000000000.0

local started = true
local showErrorText = false
local presetInputFileName = ""
local selectedPresetName = ""
local presetList = {}

local configFileName = "config.json"
local settings = {
    size = 48,
    minRange = 0.01,
    maxRange = 100.0,
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

    if #presetList >= 1 then
        selectedPresetName = presetList[1]
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

function RemoveDuplicates(arr)
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

function isspace(str)
    return #string.match(str, "%s*") == #str
  end

function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
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

    settings.size, isSizeChanged = ImGui.SliderInt(" Size ", settings.size, 2, 128)

    if isSizeChanged then
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##1") then
        settings.size = 2
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##1") then
        settings.size = defaultSize
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##1") then
        settings.size = 128
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
        SaveSettings()
    end

    ImGui.Spacing()
    settings.minRange, isMinRangeChanged = ImGui.DragFloat(" Min Range ", settings.minRange,
        settings.minRange * 0.02, minimumEffectiveMinRange, maximumEffectiveMinRange, "%.37f",
        ImGuiSliderFlags.ClampOnInput)

    if isMinRangeChanged then
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##2") then
        settings.minRange = minimumEffectiveMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##2") then
        settings.minRange = defaultMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##2") then
        settings.minRange = maximumEffectiveMinRange
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
        SaveSettings()
    end

    ImGui.Spacing()
    settings.maxRange, isMaxRangeChanged = ImGui.DragFloat(" Max Range ", settings.maxRange,
        settings.maxRange * 0.02, minimumEffectiveMaxRange, maximumEffectiveMaxRange, "%.2f",
        ImGuiSliderFlags.ClampOnInput)

    if isMaxRangeChanged then
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
        SaveSettings()
    end

    ImGui.SameLine(sameLineWidth)
    if ImGui.SmallButton(" << ##3") then
        settings.maxRange = minimumEffectiveMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" Reset ##3") then
        settings.maxRange = defaultMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
        SaveSettings()
    end

    ImGui.SameLine()
    if ImGui.SmallButton(" >> ##3") then
        settings.maxRange = maximumEffectiveMaxRange
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
        SaveSettings()
    end

    ImGui.Spacing()
    ImGui.Spacing()

    if ImGui.Button(" Reset Defaults ") then
        settings.size = defaultSize
        settings.minRange = defaultMinRange
        settings.maxRange = defaultMaxRange
        GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
        GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
        GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
        SaveSettings()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    if started then
        ImGui.SetNextItemOpen(true)
    end

    if ImGui.CollapsingHeader("Presets") then
        ImGui.Spacing()

        if showErrorText then
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.23, 0.23, 1.0)
            ImGui.Text("Filename cannot be empty.")
            ImGui.PopStyleColor(1)
        end

        presetInputFileName, _ = ImGui.InputText("##SavePresetFilename", presetInputFileName, 44)

        if presetInputFileName ~= "" and not isspace(presetInputFileName) then
            showErrorText = false
        end

        ImGui.SameLine(384)
        if ImGui.Button(" Save Preset ") then
            preset.size = settings.size
            preset.minRange = settings.minRange
            preset.maxRange = settings.maxRange
            if presetInputFileName == "" or isspace(presetInputFileName) then
                showErrorText = true
            else
                presetInputFileName = trim(presetInputFileName)
                SavePreset(presetInputFileName)
                table.insert(presetList, presetInputFileName)
                presetList = RemoveDuplicates(presetList)
                selectedPresetName = presetInputFileName
                presetInputFileName = ""
                showErrorText = false
            end
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
            settings.size = preset.size
            settings.minRange = preset.minRange
            settings.maxRange = preset.maxRange
            GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
            GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
            GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
            SaveSettings()
            presetInputFileName = ""
            showErrorText = false
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
            presetInputFileName = ""
            showErrorText = false
        end
    end

    ImGui.PopItemWidth();
    ImGui.End()

    if started then started = false end
end)

registerForEvent('onInit', function()
    LoadSettings()
    GetAvailablePresets()
    GameOptions.SetInt('Rendering/LUT', 'Size', settings.size)
    GameOptions.SetFloat('Rendering/LUT', 'MinRange', settings.minRange)
    GameOptions.SetFloat('Rendering/LUT', 'MaxRange', settings.maxRange)
end)

registerForEvent('onUpdate', function(delta)
    -- This is required for Cron to function
    Cron.Update(delta)
end)
