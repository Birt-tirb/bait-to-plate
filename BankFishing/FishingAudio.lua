local _, addon = ...

local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
local setCVar = C_CVar and C_CVar.SetCVar or SetCVar
local enabled, fishing, active = false, false, false
local volume = 1
local saved = {}
local settings = {
    { name = "Sound_EnableAllSound", value = 1 },
    { name = "Sound_EnableSFX", value = 1 },
    { name = "Sound_MasterVolume", volume = true },
    { name = "Sound_SFXVolume", volume = true },
    { name = "Sound_EnableMusic", value = 0 },
    { name = "Sound_EnableAmbience", value = 0 },
}

local function ReadCVar(name)
    if not getCVar then
        return
    end
    local ok, value = pcall(getCVar, name)
    if ok and (type(value) == "string" or type(value) == "number") then
        return tostring(value)
    end
end

local function SameValue(left, right)
    local leftNumber, rightNumber = tonumber(left), tonumber(right)
    if leftNumber and rightNumber then
        return math.abs(leftNumber - rightNumber) < 0.00001
    end
    return left == right
end

local function RestoreAudio()
    active = false
    for name, entry in pairs(saved) do
        local current = ReadCVar(name)
        if entry.overridden or not entry.changed then
            saved[name] = nil
        elseif current then
            if not SameValue(current, entry.applied) then
                -- Leave sound settings changed by the player or another addon alone.
                saved[name] = nil
            elseif setCVar then
                pcall(setCVar, name, entry.original)
                if SameValue(ReadCVar(name), entry.original) then
                    saved[name] = nil
                end
            end
        end
    end
end

local function ApplyAudio()
    for _, setting in ipairs(settings) do
        local name = setting.name
        local current = ReadCVar(name)
        if current and tonumber(current) and setCVar then
            local entry = saved[name]
            if not entry then
                entry = { original = current, applied = current, changed = false }
                saved[name] = entry
            elseif not SameValue(current, entry.applied) then
                entry.overridden = true
            end

            if not entry.overridden then
                local desired = tostring(setting.volume and volume or setting.value)
                if not SameValue(current, desired) then
                    -- Keep the first snapshot when the slider changes during a cast.
                    entry.applied = desired
                    entry.changed = true
                    pcall(setCVar, name, desired)
                    local applied = ReadCVar(name)
                    if applied then
                        entry.applied = applied
                        entry.changed = not SameValue(applied, entry.original)
                    end
                end
            end
        end
    end
end

function addon.UpdateFishingAudio(isFishing)
    fishing = isFishing == true
    if not enabled or not fishing or InCombatLockdown() then
        RestoreAudio()
    elseif not active then
        -- Retry a failed restore without replacing its original snapshot.
        RestoreAudio()
        active = true
        ApplyAudio()
    end
end

function addon.SetFishingAudioEnabled(value)
    enabled = value == true
    addon.UpdateFishingAudio(fishing)
end

function addon.GetFishingAudioVolume()
    return volume
end

function addon.SetFishingAudioVolume(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        number = 1
    end
    local selected = math.max(0, math.min(1, number))
    if selected ~= volume then
        volume = selected
        if active then
            ApplyAudio()
        end
    end
    return volume
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    addon.UpdateFishingAudio(false)
end)
