Localization = {}

local UIText = {
  modName = "LUT Histogram Min/Max",
  sizeSlider = " Size ",
  resetButton = " Reset ",
  minRangeDragFloat = " Min Range ",
  maxRangeDragFloat = " Max Range ",
  resetDefaultsButton = " Reset Defaults ",
  presetsHeader = "Presets",
  fileNameError = "Filename cannot be empty.",
  savePresetButton = " Save Preset ",
  loadPresetButton = " Load Preset ",
  deletePresetButton = " Delete Preset ",
}

local modDefaultLang = "en-us"

local FallbackBoard = {}

function Deepcopy(contents)
  if contents == nil then return contents end

  local contentsType = type(contents)
  local copy

  if contentsType == 'table' then
    copy = {}

    for key, value in next, contents, nil do
      copy[Deepcopy(key)] = Deepcopy(value)
    end

    setmetatable(copy, Deepcopy(getmetatable(contents)))
  else
    copy = contents
  end

  return copy
end

function SafeMergeTables(mergeTo, mergeA)
  if mergeA == nil then return mergeTo end

  for key, value in pairs(mergeA) do
    if mergeTo[key] ~= nil then -- Only proceed if the key exists in mergeTo
      if type(value) == "table" and type(mergeTo[key]) == "table" then
        mergeTo[key] = SafeMergeTables(mergeTo[key], value)
      else
        mergeTo[key] = value
      end
    end
  end

  return mergeTo
end

function SetFallback(owner, contents, key)
  local copiedContents = Deepcopy(contents)

  if key then
    FallbackBoard[owner] = FallbackBoard[owner] or {}
    FallbackBoard[owner][key] = copiedContents
  else
    FallbackBoard[owner] = copiedContents
  end
end

function GetFallback(owner, key)
  if FallbackBoard[owner] == nil then return nil end
  if key and FallbackBoard[owner] and FallbackBoard[owner][key] == nil then return nil end

  if key then
    return FallbackBoard[owner][key]
  else
    return FallbackBoard[owner]
  end
end

function Localization.GetUIText()
  return UIText
end

function Localization.GetOnScreenLanguage()
  return Game.NameToString(Game.GetSettingsSystem():GetVar("/language", "OnScreen"):GetValue())
end

local function GetNewLocalization(sourceTable, key, currentLang)
  if GetFallback("Localization", key) == nil then
    SetFallback("Localization", sourceTable, key)
  else
    sourceTable = SafeMergeTables(sourceTable, GetFallback("Localization", key))
  end

  local translationFile = "Translations/" .. currentLang .. ".lua"
  local chunk = loadfile(translationFile)

  if chunk then
    local translation = chunk()
    return SafeMergeTables(sourceTable, translation[key])
  else
    return sourceTable
  end
end

local function GetDefaultLocalization(sourceTable, key)
  local fallback = GetFallback("Localization", key)
  return fallback and SafeMergeTables(sourceTable, fallback) or sourceTable
end

function Localization.GetTranslation(sourceTable, key)
  local currentLang = Localization.GetOnScreenLanguage()

  if currentLang == modDefaultLang then return GetDefaultLocalization(sourceTable, key) end

  if currentLang == modDefaultLang then
    return GetDefaultLocalization(sourceTable, key)
  else
    return GetNewLocalization(sourceTable, key, currentLang)
  end
end

return Localization
