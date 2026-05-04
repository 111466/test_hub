-- ============================================================================
-- 地图构建完整示例 (Lua)
-- ============================================================================

local MapBuilder = {}

MapBuilder.perspective = "isometric"
MapBuilder.tileWidth = 64
MapBuilder.tileHeight = 32
MapBuilder.imageCache = {}

function MapBuilder.Load(jsonPath)
    local file = File(jsonPath, FILE_READ)
    if not file or not file:IsOpen() then
        print("[MapBuilder] 无法打开文件: " .. jsonPath)
        return nil
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, mapData = pcall(cjson.decode, jsonStr)
    if not ok then
        print("[MapBuilder] JSON 解析失败: " .. tostring(mapData))
        return nil
    end

    return MapBuilder.Parse(mapData)
end

function MapBuilder.Parse(mapData)
    local map = {
        version = mapData.version,
        width = mapData.width,
        height = mapData.height,
        layers = {}
    }

    for _, layerInfo in ipairs(mapData.layers) do
        local grid = {}
        for y = 1, map.height do
            grid[y] = {}
            for x = 1, map.width do
                grid[y][x] = nil
            end
        end

        for _, tile in ipairs(layerInfo.tiles) do
            grid[tile.y][tile.x] = tile

            if tile.path and not MapBuilder.imageCache[tile.path] then
                MapBuilder.imageCache[tile.path] = Cache:GetFile("assets/" .. tile.path)
            end
        end

        table.insert(map.layers, {
            name = layerInfo.name,
            visible = layerInfo.visible ~= false,
            grid = grid
        })
    end

    return map
end

function MapBuilder.SetPerspective(mode)
    MapBuilder.perspective = mode
    if mode == "isometric" then
        MapBuilder.tileWidth = 64
        MapBuilder.tileHeight = 32
    else
        MapBuilder.tileWidth = 64
        MapBuilder.tileHeight = 64
    end
end

function MapBuilder.SetTileSize(width, height)
    MapBuilder.tileWidth = width
    MapBuilder.tileHeight = height
end

function MapBuilder.MapToScreen(mapX, mapY, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    if MapBuilder.perspective == "isometric" then
        local sx = (mapX - mapY) * (MapBuilder.tileWidth / 2)
        local sy = (mapX + mapY) * (MapBuilder.tileHeight / 2)
        return sx + offsetX, sy + offsetY
    else
        local sx = mapX * MapBuilder.tileWidth
        local sy = mapY * MapBuilder.tileHeight
        return sx + offsetX, sy + offsetY
    end
end

function MapBuilder.ScreenToMap(screenX, screenY, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local sx = screenX - offsetX
    local sy = screenY - offsetY

    if MapBuilder.perspective == "isometric" then
        local mapX = (sx / (MapBuilder.tileWidth / 2) + sy / (MapBuilder.tileHeight / 2)) / 2
        local mapY = (sy / (MapBuilder.tileHeight / 2) - sx / (MapBuilder.tileWidth / 2)) / 2
        return math.floor(mapX + 0.5), math.floor(mapY + 0.5)
    else
        local mapX = math.floor(sx / MapBuilder.tileWidth) + 1
        local mapY = math.floor(sy / MapBuilder.tileHeight) + 1
        return mapX, mapY
    end
end

function MapBuilder.IsWalkable(map, mapX, mapY)
    if mapX < 1 or mapX > map.width or mapY < 1 or mapY > map.height then
        return false
    end

    for _, layer in ipairs(map.layers) do
        if layer.visible then
            local tile = layer.grid[mapY][mapX]
            if tile and tile.path then
                if tile.path:find("Water") then
                    return false
                end
            end
        end
    end

    return true
end

function MapBuilder.Render(map, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    for _, layer in ipairs(map.layers) do
        if layer.visible then
            for y = 1, map.height do
                for x = 1, map.width do
                    local tile = layer.grid[y][x]
                    if tile then
                        local sx, sy = MapBuilder.MapToScreen(x, y, offsetX, offsetY)

                        if tile.path and MapBuilder.imageCache[tile.path] then
                            local img = MapBuilder.imageCache[tile.path]
                            DrawImage(img, sx - MapBuilder.tileWidth / 2, sy - MapBuilder.tileHeight / 2)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 游戏主循环示例
-- ============================================================================

local Game = {}

Game.map = nil
Game.cameraX = 0
Game.cameraY = 0
Game.playerX = 1
Game.playerY = 1
Game.moveSpeed = 4.0

function Game.Start()
    Game.map = MapBuilder.Load("output/output.json")
    if not Game.map then
        print("地图加载失败")
        return
    end

    MapBuilder.SetPerspective("isometric")
    print("地图加载成功: " .. Game.map.width .. "x" .. Game.map.height)
end

function Game.Update(dt)
    local dx = 0
    local dy = 0

    if MapBuilder.perspective == "isometric" then
        if input:GetKeyDown(KEY_W) then dx = dx - 1; dy = dy - 1 end
        if input:GetKeyDown(KEY_S) then dx = dx + 1; dy = dy + 1 end
        if input:GetKeyDown(KEY_A) then dx = dx - 1; dy = dy + 1 end
        if input:GetKeyDown(KEY_D) then dx = dx + 1; dy = dy - 1 end
    else
        if input:GetKeyDown(KEY_W) then dy = dy - 1 end
        if input:GetKeyDown(KEY_S) then dy = dy + 1 end
        if input:GetKeyDown(KEY_A) then dx = dx - 1 end
        if input:GetKeyDown(KEY_D) then dx = dx + 1 end
    end

    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dx = dx / len
            dy = dy / len
        end

        local newX = Game.playerX + dx * Game.moveSpeed * dt
        local newY = Game.playerY + dy * Game.moveSpeed * dt
        local gridX = math.floor(newX + 0.5)
        local gridY = math.floor(newY + 0.5)

        if MapBuilder.IsWalkable(Game.map, gridX, gridY) then
            Game.playerX = newX
            Game.playerY = newY
        end
    end

    local playerScreenX, playerScreenY = MapBuilder.MapToScreen(Game.playerX, Game.playerY)
    Game.cameraX = 400 - playerScreenX
    Game.cameraY = 300 - playerScreenY
end

function Game.Render()
    if not Game.map then return end

    MapBuilder.Render(Game.map, Game.cameraX, Game.cameraY)

    local px, py = MapBuilder.MapToScreen(Game.playerX, Game.playerY, Game.cameraX, Game.cameraY)
    nvg:BeginPath()
    nvg:Circle(px, py - 10, 12)
    nvg:FillColor(66, 165, 245, 255)
    nvg:Fill()
end

return MapBuilder
