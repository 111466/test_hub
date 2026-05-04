-- ============================================================================
-- Tilemap Renderer - 基于 output.json 地图数据
-- ============================================================================

require "LuaScripts/Utilities/Sample"
local json = require("scripts/json") -- 使用我们刚刚创建的纯 Lua JSON 解析器

-- ============================================================================
-- 状态变量
-- ============================================================================
local MAP_W = 8
local MAP_H = 8
local TILE_W = 64
local TILE_H = 64

---@type NVGContextWrapper
local vg = nil
local fontId = -1
local imgHandles = {}   -- path → NanoVG image handle
local imgSizes = {}     -- path → {w, h}
local elapsedTime = 0

-- 存储从 output.json 解析出的数据
local tileDefs = {}
local mapLayers = {}

-- ============================================================================
-- 读取与解析 JSON
-- ============================================================================
local function loadMapData()
    -- 使用 io.open 读取 json 文件。假设当前目录是 test_hub
    local path = fileSystem:GetCurrentDir() .. "docs/output.json"
    local f = io.open(path, "r")
    if not f then
        print("ERROR: Failed to open " .. path)
        return
    end
    local content = f:read("*a")
    f:close()

    local mapData = json.decode(content)
    if not mapData then
        print("ERROR: Failed to decode json")
        return
    end

    MAP_W = mapData.width or 8
    MAP_H = mapData.height or 8

    -- 解析 imageRegistry
    for _, reg in ipairs(mapData.imageRegistry or {}) do
        local frames = {}
        if reg.frames then
            for _, frm in ipairs(reg.frames) do
                table.insert(frames, {x = frm.x, y = frm.y, w = frm.w, h = frm.h})
            end
        elseif reg.rect then
            table.insert(frames, {x = reg.rect.x, y = reg.rect.y, w = reg.rect.w, h = reg.rect.h})
        end

        tileDefs[reg.id] = {
            path = reg.imagePath,
            frames = frames,
            fps = reg.fps or 0,
            scale = reg.scale or 1.0,
            renderMode = reg.renderMode or "flat",
            name = reg.name
        }
    end

    -- 解析 layers
    for _, layerData in ipairs(mapData.layers or {}) do
        local layer = {
            name = layerData.name,
            visible = layerData.visible == nil and true or layerData.visible,
            opacity = layerData.opacity or 1.0,
            tiles = {}
        }
        for _, tData in ipairs(layerData.tiles or {}) do
            table.insert(layer.tiles, {
                x = tData.x,
                y = tData.y,
                id = tData.id
            })
        end
        table.insert(mapLayers, layer)
    end

    print("[MapData] Loaded successfully from output.json. Layers: " .. #mapLayers)
end

-- ============================================================================
-- 初始化
-- ============================================================================
function Start()
    SampleStart()
    graphics.windowTitle = "Tilemap Viewer"

    -- 创建 NanoVG 上下文
    vg = nvgCreate(1)
    if not vg then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontId = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 加载并解析地图数据
    loadMapData()

    -- 加载用到的图片
    local usedPaths = {}
    for _, layer in ipairs(mapLayers) do
        for _, tile in ipairs(layer.tiles) do
            local def = tileDefs[tile.id]
            if def then usedPaths[def.path] = true end
        end
    end
    for path in pairs(usedPaths) do
        local handle = nvgCreateImage(vg, path, 0)
        if handle >= 0 then
            imgHandles[path] = handle
            local w, h = nvgImageSize(vg, handle)
            imgSizes[path] = {w = w, h = h}
            print("[Image] Loaded: " .. path .. " (" .. w .. "x" .. h .. ")")
        else
            print("[Image] FAILED: " .. path)
        end
    end

    SampleInitMouseMode(MM_FREE)
    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")

    print("=== Tilemap Viewer Started ===")
end

function Stop()
    if vg then
        for _, handle in pairs(imgHandles) do
            nvgDeleteImage(vg, handle)
        end
        nvgDelete(vg)
        vg = nil
    end
end

-- ============================================================================
-- 更新
-- ============================================================================
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    elapsedTime = elapsedTime + dt
end

-- ============================================================================
-- 渲染
-- ============================================================================
local function drawSubImage(imgHandle, imgW, imgH, sx, sy, sw, sh, dx, dy, dw, dh, alpha)
    local scaleX = dw / sw
    local scaleY = dh / sh
    local paint = nvgImagePattern(vg,
        dx - sx * scaleX,
        dy - sy * scaleY,
        imgW * scaleX,
        imgH * scaleY,
        0, imgHandle, alpha)

    nvgSave(vg)
    nvgScissor(vg, dx, dy, dw, dh)
    nvgBeginPath(vg)
    nvgRect(vg, dx, dy, dw, dh)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
    nvgRestore(vg)
end

local function getFrameIndex(def)
    if def.fps <= 0 or #def.frames <= 1 then
        return 1
    end
    local totalFrames = #def.frames
    local frameIdx = math.floor(elapsedTime * def.fps) % totalFrames + 1
    return frameIdx
end

function HandleNanoVGRender(eventType, eventData)
    if not vg then return end

    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local screenW = physW / dpr
    local screenH = physH / dpr

    nvgBeginFrame(vg, screenW, screenH, dpr)

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(15, 20, 30, 255))
    nvgFill(vg)

    -- 居中计算
    local padding = 30
    local maxMapW = screenW - padding * 2
    local maxMapH = screenH - padding * 2
    local tileSize = math.min(maxMapW / MAP_W, maxMapH / MAP_H)
    local mapPixelW = tileSize * MAP_W
    local mapPixelH = tileSize * MAP_H
    local offsetX = (screenW - mapPixelW) / 2
    local offsetY = (screenH - mapPixelH) / 2

    -- 逐层渲染
    for _, layer in ipairs(mapLayers) do
        if not layer.visible then goto continue_layer end

        -- Z-Order 网格排序
        local grid = {}
        for y = 1, MAP_H do
            grid[y] = {}
        end
        for _, tile in ipairs(layer.tiles) do
            if tile.y >= 1 and tile.y <= MAP_H and tile.x >= 1 and tile.x <= MAP_W then
                grid[tile.y][tile.x] = tile
            end
        end

        for y = 1, MAP_H do
            for x = 1, MAP_W do
                local tile = grid[y][x]
                if not tile then goto continue_tile end

                local def = tileDefs[tile.id]
                if not def then goto continue_tile end

                local imgHandle = imgHandles[def.path]
                local imgSize = imgSizes[def.path]
                if not imgHandle or not imgSize then goto continue_tile end

                local frameIdx = getFrameIndex(def)
                local frame = def.frames[frameIdx]

                -- 基础目标位置
                local dx = offsetX + (tile.x - 1) * tileSize
                local dy = offsetY + (tile.y - 1) * tileSize

                local ratio = tileSize / 64
                local drawW = frame.w * ratio * def.scale
                local drawH = frame.h * ratio * def.scale

                if def.renderMode == "vertical" then
                    -- 竖直渲染（如树）：底部对齐，水平居中
                    local cx = dx + tileSize / 2
                    local drawX = cx - drawW / 2
                    local drawY = dy + tileSize - drawH

                    drawSubImage(imgHandle, imgSize.w, imgSize.h,
                        frame.x, frame.y, frame.w, frame.h,
                        drawX, drawY, drawW, drawH,
                        layer.opacity)
                else
                    -- 平铺渲染：居中对齐
                    local drawX = dx + (tileSize - drawW) / 2
                    local drawY = dy + (tileSize - drawH) / 2

                    drawSubImage(imgHandle, imgSize.w, imgSize.h,
                        frame.x, frame.y, frame.w, frame.h,
                        drawX, drawY, drawW, drawH,
                        layer.opacity)
                end

                ::continue_tile::
            end
        end

        ::continue_layer::
    end

    -- 网格线
    nvgBeginPath(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgStrokeWidth(vg, 1)
    for r = 0, MAP_H do
        local y = offsetY + r * tileSize
        nvgMoveTo(vg, offsetX, y)
        nvgLineTo(vg, offsetX + mapPixelW, y)
    end
    for c = 0, MAP_W do
        local x = offsetX + c * tileSize
        nvgMoveTo(vg, x, offsetY)
        nvgLineTo(vg, x, offsetY + mapPixelH)
    end
    nvgStroke(vg)

    if fontId >= 0 then
        nvgFontFaceId(vg, fontId)
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 210, 230, 200))
        nvgText(vg, screenW / 2, 8, "Tilemap Viewer - " .. MAP_W .. "x" .. MAP_H .. " · " .. #mapLayers .. " Layers", nil)
    end

    nvgEndFrame(vg)
end
