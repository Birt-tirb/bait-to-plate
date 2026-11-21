-- Adapted from GatherGlow's fishing-pool minimap renderer.
--[[
MIT License

Copyright (c) 2026 Birt-tirb

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local addonName, addon = ...
local compat = addon.Compat

local UPDATE_INTERVAL = 0.1
local PIN_SIZE = 14
local PIN_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\FishingPoolFish.tga"
local poolsByContinent
local overlay, ticker
local pins = {}

local function isReadable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function worldPosition(mapID, mapPosition)
    if not isReadable(mapPosition) or not mapPosition then
        return
    end

    local continent, position = C_Map.GetWorldPosFromMapPos(mapID, mapPosition)
    if not isReadable(continent) or not isReadable(position) or not continent or not position then
        return
    end

    local north, west = position:GetXY()
    if isReadable(north) and isReadable(west) and north and west then
        return continent, north, west
    end
end

local function indexPools()
    local indexed = {}
    for mapID, locations in pairs(addon.PoolLocations) do
        for _, packed in ipairs(locations) do
            local x = math.floor(packed / 10000) / 10000
            local y = (packed % 10000) / 10000
            local continent, north, west = worldPosition(mapID, CreateVector2D(x, y))
            if not continent then
                -- Retry later if a map cannot be converted yet.
                return
            end
            local pools = indexed[continent] or {}
            indexed[continent] = pools
            pools[#pools + 1] = { north = north, west = west }
        end
    end
    poolsByContinent = indexed
end

local function getPin(index)
    if pins[index] then
        return pins[index]
    end

    local pin = overlay:CreateTexture(nil, "OVERLAY")
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:SetTexture(PIN_TEXTURE)
    pins[index] = pin
    return pin
end

local function hidePins(visible)
    for index = visible + 1, #pins do
        pins[index]:Hide()
    end
end

local function updatePins()
    if not Minimap:IsVisible() or IsInInstance() then
        hidePins(0)
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not isReadable(mapID) or not mapID then
        hidePins(0)
        return
    end

    local continent, playerNorth, playerWest = worldPosition(mapID, C_Map.GetPlayerMapPosition(mapID, "player"))
    local radius = compat.GetMinimapViewRadius()
    local width, height = Minimap:GetSize()
    if not continent or not isReadable(radius) or not radius or radius <= 0
        or not isReadable(width) or not isReadable(height) or not width or not height
        or width <= PIN_SIZE + 2 or height <= PIN_SIZE + 2 then
        hidePins(0)
        return
    end

    if not poolsByContinent then
        indexPools()
    end

    local pools = poolsByContinent and poolsByContinent[continent]
    if not pools then
        hidePins(0)
        return
    end

    local facing = 0
    local getCVarBool = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    if getCVarBool("rotateMinimap") and not compat.IsMinimapRotationIgnored() then
        facing = GetPlayerFacing()
        if not isReadable(facing) or not facing then
            hidePins(0)
            return
        end
    end

    local cosine, sine = math.cos(facing), math.sin(facing)
    local scaleX, scaleY = width / (2 * radius), height / (2 * radius)
    local inset = 1 - (PIN_SIZE + 2) / math.min(width, height)
    local insetRadius = radius * inset
    local radiusSquared = insetRadius * insetRadius
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local visible = 0

    for _, pool in ipairs(pools) do
        -- World coordinates increase north and west. Screen offsets increase east and north.
        local east, north = playerWest - pool.west, pool.north - playerNorth
        local x = east * cosine + north * sine
        local y = north * cosine - east * sine
        if (square and math.abs(x) <= insetRadius and math.abs(y) <= insetRadius)
            or (not square and x * x + y * y <= radiusSquared) then
            visible = visible + 1
            local pin = getPin(visible)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", overlay, "CENTER", x * scaleX, y * scaleY)
            pin:Show()
        end
    end

    hidePins(visible)
end

function addon.SetPoolPinsEnabled(enabled)
    if enabled and not ticker then
        if not overlay then
            overlay = CreateFrame("Frame", nil, Minimap)
            overlay:SetAllPoints(Minimap)
            overlay:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        end
        overlay:Show()
        updatePins()
        ticker = C_Timer.NewTicker(UPDATE_INTERVAL, updatePins)
    elseif not enabled and ticker then
        ticker:Cancel()
        ticker = nil
        overlay:Hide()
        hidePins(0)
    end
end
