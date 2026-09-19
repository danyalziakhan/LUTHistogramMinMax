local Localization = {}

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
  fileNameInvalidError = "Filename cannot contain \\ / : * ? \" < > |",
  presetSaveError = "Preset could not be saved.",
  presetLoadError = "Preset could not be read.",
  sizeTooltip = "LUT resolution. The game default is 48.",
  minRangeTooltip = "Lower end of the LUT range. Lowering it can bring back detail in crushed blacks.",
  maxRangeTooltip = "Upper end of the LUT range. Lowering it tones down overblown highlights such as neon signs.",
  minButtonTooltip = "Set to the lowest value",
  maxButtonTooltip = "Set to the highest value",
  savePresetTooltip = "Save the current values under this name. An existing preset with the same name is replaced.",
}

local modDefaultLang = "en-us"

local fallbacks = {}
local cachedLanguage = nil
local cachedTranslation = nil

local function Copy(source)
  local copy = {}

  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = Copy(value)
    else
      copy[key] = value
    end
  end

  return copy
end

-- only known keys of the same type
local function MergeKnownKeys(target, source)
  if type(source) ~= "table" then
    return target
  end

  for key, value in pairs(source) do
    if target[key] ~= nil then
      if type(value) == "table" and type(target[key]) == "table" then
        MergeKnownKeys(target[key], value)
      elseif type(value) == type(target[key]) then
        target[key] = value
      end
    end
  end

  return target
end

local function LoadTranslation(language)
  if language ~= cachedLanguage then
    cachedLanguage = language
    cachedTranslation = nil

    local chunk = loadfile("Translations/" .. language .. ".lua")

    if chunk then
      local ok, result = pcall(chunk)

      if ok and type(result) == "table" then
        cachedTranslation = result
      end
    end
  end

  return cachedTranslation
end

function Localization.GetUIText()
  return UIText
end

function Localization.GetOnScreenLanguage()
  return Game.NameToString(Game.GetSettingsSystem():GetVar("/language", "OnScreen"):GetValue())
end

function Localization.GetTranslation(sourceTable, key)
  if fallbacks[key] == nil then
    fallbacks[key] = Copy(sourceTable)
  else
    MergeKnownKeys(sourceTable, fallbacks[key])
  end

  local ok, language = pcall(Localization.GetOnScreenLanguage)

  if not ok or language == modDefaultLang then
    return sourceTable
  end

  local translation = LoadTranslation(language)

  if translation then
    MergeKnownKeys(sourceTable, translation[key])
  end

  return sourceTable
end

return Localization
