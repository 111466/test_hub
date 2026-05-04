-- ============================================================================
-- Tilemap Renderer - 基于 output.json 地图数据
-- 使用 NanoVG 渲染多层瓦片地图，支持精灵表裁剪和帧动画
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 常量
-- ============================================================================
local MAP_W = 8
local MAP_H = 8

-- ============================================================================
-- 状态
-- ============================================================================
---@type NVGContextWrapper
local vg = nil
local fontId = -1
---@type table<string, integer>
local imgHandles = {}   -- path → NanoVG image handle
---@type table<string, {w:number, h:number}>
local imgSizes = {}     -- path → {w, h}
local elapsedTime = 0

-- ============================================================================
-- 瓦片定义（从 manifest.json 推导）
-- ============================================================================

--- 构建 Tilemap_colorN 的 44 个瓦片坐标
--- 图集布局：8列/行，列x = {0,64,128,192, 320,384,448,512}
--- 行0-3 各8个，行4-5 各6个（列0,3,4,5,6,7）
local function buildTilemapTiles()
    local tiles = {}
    local colX = {0, 64, 128, 192, 320, 384, 448, 512}
    -- 行 0-3：每行 8 个
    for row = 0, 3 do
        for col = 1, 8 do
            tiles[#tiles + 1] = {x = colX[col], y = row * 64, w = 64, h = 64}
        end
    end
    -- 行 4-5：每行 6 个（列索引 1,4,5,6,7,8）
    local sparseCol = {1, 4, 5, 6, 7, 8}
    for row = 4, 5 do
        for _, ci in ipairs(sparseCol) do
            tiles[#tiles + 1] = {x = colX[ci], y = row * 64, w = 64, h = 64}
        end
    end
    return tiles
end

--- @class TileDef
--- @field path string
--- @field frames {x:number, y:number, w:number, h:number}[]
--- @field fps number
--- @field scale number
--- @field renderMode string

---@type table<integer, TileDef>
local tileDefs = {}

local function initTileDefs()
    -- ID 100: water_wave（动画，16帧 128x128，fps=10，scale=1.3）
    local waveFrames = {}
    for i = 0, 15 do
        waveFrames[#waveFrames + 1] = {x = i * 128, y = 0, w = 128, h = 128}
    end
    tileDefs[100] = {
        path = "Tiles/water_wave.png",
        frames = waveFrames,
        fps = 10, scale = 1.3, renderMode = "flat",
    }

    -- Tilemap_color 系列（每套 44 个瓦片）
    local tmTiles = buildTilemapTiles()
    local colorSets = {
        {base = 100, path = "Tiles/Tilemap_color1.png"},
        {base = 144, path = "Tiles/Tilemap_color2.png"},
        {base = 188, path = "Tiles/Tilemap_color3.png"},
        {base = 232, path = "Tiles/Tilemap_color4.png"},
        {base = 276, path = "Tiles/Tilemap_color5.png"},
    }
    for _, cs in ipairs(colorSets) do
        for i, t in ipairs(tmTiles) do
            tileDefs[cs.base + i] = {
                path = cs.path,
                frames = {{x = t.x, y = t.y, w = t.w, h = t.h}},
                fps = 0, scale = 1.0, renderMode = "flat",
            }
        end
    end

    -- ID 321: Tree1（动画，8帧 192x256，fps=10，vertical）
    local treeFrames = {}
    for i = 0, 7 do
        treeFrames[#treeFrames + 1] = {x = i * 192, y = 0, w = 192, h = 256}
    end
    tileDefs[321] = {
        path = "Tiles/Tree1.png",
        frames = treeFrames,
        fps = 10, scale = 1.0, renderMode = "vertical",
    }

    -- ID 322: Water Background（单帧 64x64，scale=1.1）
    tileDefs[322] = {
        path = "Tiles/Water Background color.png",
        frames = {{x = 0, y = 0, w = 64, h = 64}},
        fps = 0, scale = 1.1, renderMode = "flat",
    }

    print("[TileDefs] Initialized, total tile types: " .. #colorSets * 44 + 3)
end

-- ============================================================================
-- 地图数据（从 output.json 嵌入）
-- ============================================================================
local mapLayers = {
    -- 层1: 地面（8x8 水背景）
    {
        name = "地面", visible = true, opacity = 1,
        tiles = (function()
            local t = {}
            for y = 1, 8 do
                for x = 1, 8 do
                    t[#t + 1] = {x = x, y = y, id = 322}
                end
            end
            return t
        end)(),
    },
    -- 层2: 物体（水波环形）
    {
        name = "物体", visible = true, opacity = 1,
        tiles = {
            {x=3,y=3,id=100}, {x=4,y=3,id=100}, {x=5,y=3,id=100},
            {x=3,y=4,id=100},                    {x=5,y=4,id=100},
            {x=3,y=5,id=100}, {x=4,y=5,id=100}, {x=5,y=5,id=100},
        },
    },
    -- 层3: 草地岛屿 3x3
    {
        name = "草地", visible = true, opacity = 1,
        tiles = {
            {x=3,y=3,id=189}, {x=4,y=3,id=190}, {x=5,y=3,id=191},
            {x=3,y=4,id=197}, {x=4,y=4,id=198}, {x=5,y=4,id=199},
            {x=3,y=5,id=205}, {x=4,y=5,id=206}, {x=5,y=5,id=207},
        },
    },
    -- 层4: 树
    {
        name = "树木", visible = true, opacity = 1,
        tiles = {
            {x=4,y=4,id=321},
        },
    },
}

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

    -- 初始化瓦片定义
    initTileDefs()

    -- 加载地图中用到的所有图片
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

    -- 订阅事件
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

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    elapsedTime = elapsedTime + dt
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 绘制精灵表中的子区域
--- @param imgHandle integer NanoVG 图片句柄
--- @param imgW number 图片总宽度
--- @param imgH number 图片总高度
--- @param sx number 源区域 x
--- @param sy number 源区域 y
--- @param sw number 源区域宽度
--- @param sh number 源区域高度
--- @param dx number 目标 x
--- @param dy number 目标 y
--- @param dw number 目标宽度
--- @param dh number 目标高度
--- @param alpha number 透明度 0-1
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

--- 获取动画帧的当前帧索引
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

    -- 绘制深色背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(15, 20, 30, 255))
    nvgFill(vg)

    -- 计算瓦片尺寸，居中显示地图
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

        for _, tile in ipairs(layer.tiles) do
            local def = tileDefs[tile.id]
            if not def then goto continue_tile end

            local imgHandle = imgHandles[def.path]
            local imgSize = imgSizes[def.path]
            if not imgHandle or not imgSize then goto continue_tile end

            -- 获取当前帧
            local frameIdx = getFrameIndex(def)
            local frame = def.frames[frameIdx]

            -- 目标位置（tile.x/y 从 1 开始）
            local dx = offsetX + (tile.x - 1) * tileSize
            local dy = offsetY + (tile.y - 1) * tileSize

            if def.renderMode == "vertical" then
                -- 竖直渲染模式（如树）：保持宽高比，底部对齐到格子底边
                local aspect = frame.w / frame.h
                local drawH = tileSize * 2.5   -- 树比格子高
                local drawW = drawH * aspect
                local cx = dx + tileSize / 2   -- 水平居中
                local drawX = cx - drawW / 2
                local drawY = dy + tileSize - drawH  -- 底部对齐

                drawSubImage(imgHandle, imgSize.w, imgSize.h,
                    frame.x, frame.y, frame.w, frame.h,
                    drawX, drawY, drawW, drawH,
                    layer.opacity)
            else
                -- 平铺渲染模式
                local scale = def.scale
                local drawW = tileSize * scale
                local drawH = tileSize * scale
                -- 居中对齐（scale > 1 时会溢出格子边界）
                local drawX = dx + (tileSize - drawW) / 2
                local drawY = dy + (tileSize - drawH) / 2

                drawSubImage(imgHandle, imgSize.w, imgSize.h,
                    frame.x, frame.y, frame.w, frame.h,
                    drawX, drawY, drawW, drawH,
                    layer.opacity)
            end

            ::continue_tile::
        end

        ::continue_layer::
    end

    -- 绘制网格线（辅助线）
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

    -- 标题
    if fontId >= 0 then
        nvgFontFaceId(vg, fontId)
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 210, 230, 200))
        nvgText(vg, screenW / 2, 8, "Tilemap Viewer - 8×8 · 4 Layers", nil)
    end

    nvgEndFrame(vg)
end
