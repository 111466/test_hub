# 坐标系与转换详解

## 坐标系说明

### 地图逻辑坐标 (Map Coordinates)

- **范围**: (1, 1) 到 (width, height)
- **原点**: 地图左上角
- **单位**: 瓦片格子
- **特点**: 与视角无关，是通用的网格位置

```
(1,1) → (2,1) → (3,1) → ...
  ↓
(1,2) → (2,2) → (3,2) → ...
  ↓
...
```

### 屏幕像素坐标 (Screen Coordinates)

- **范围**: (0, 0) 到 (screenWidth, screenHeight)
- **原点**: 屏幕左上角
- **单位**: 像素
- **特点**: 取决于渲染视角

---

## 等距视角 (Isometric)

### 坐标转换公式

```
TILE_W = 64   -- 瓦片宽度（像素）
TILE_H = 32   -- 瓦片高度（像素）

screenX = (mapX - mapY) * (TILE_W / 2) + offsetX
screenY = (mapX + mapY) * (TILE_H / 2) + offsetY
```

### 逆转换（屏幕 → 地图）

```
-- 先减去偏移
sx = screenX - offsetX
sy = screenY - offsetY

mapX = (sx / (TILE_W / 2) + sy / (TILE_H / 2)) / 2
mapY = (sy / (TILE_H / 2) - sx / (TILE_W / 2)) / 2

-- 取整得到网格坐标
mapX = math.floor(mapX + 0.5)
mapY = math.floor(mapY + 0.5)
```

### 视觉效果

菱形瓦片排列，形成 45° 俯视视角：

```
        ╱╲
       ╱  ╲
      ╱    ╲
     ╲      ╱
      ╲    ╱
       ╲  ╱
        ╲╱
```

---

## 正视视角 (Top-down)

### 坐标转换公式

```
TILE_W = 64   -- 瓦片宽度（像素）
TILE_H = 64   -- 瓦片高度（像素）

screenX = mapX * TILE_W + offsetX
screenY = mapY * TILE_H + offsetY
```

### 逆转换（屏幕 → 地图）

```
mapX = math.floor((screenX - offsetX) / TILE_W) + 1
mapY = math.floor((screenY - offsetY) / TILE_H) + 1
```

### 视觉效果

方格排列，正上方俯视视角：

```
┌─────┬─────┬─────┐
│     │     │     │
├─────┼─────┼─────┤
│     │     │     │
├─────┼─────┼─────┤
│     │     │     │
└─────┴─────┴─────┘
```

---

## Lua 实现示例

```lua
local MapCoord = {}

MapCoord.TILE_W_ISO = 64
MapCoord.TILE_H_ISO = 32
MapCoord.TILE_W_TOP = 64
MapCoord.TILE_H_TOP = 64

function MapCoord.MapToScreenIso(mapX, mapY, offsetX, offsetY)
    local sx = (mapX - mapY) * (MapCoord.TILE_W_ISO / 2)
    local sy = (mapX + mapY) * (MapCoord.TILE_H_ISO / 2)
    return sx + offsetX, sy + offsetY
end

function MapCoord.ScreenToMapIso(screenX, screenY, offsetX, offsetY)
    local sx = screenX - offsetX
    local sy = screenY - offsetY
    local mapX = (sx / (MapCoord.TILE_W_ISO / 2) + sy / (MapCoord.TILE_H_ISO / 2)) / 2
    local mapY = (sy / (MapCoord.TILE_H_ISO / 2) - sx / (MapCoord.TILE_W_ISO / 2)) / 2
    return math.floor(mapX + 0.5), math.floor(mapY + 0.5)
end

function MapCoord.MapToScreenTop(mapX, mapY, offsetX, offsetY)
    local sx = mapX * MapCoord.TILE_W_TOP
    local sy = mapY * MapCoord.TILE_H_TOP
    return sx + offsetX, sy + offsetY
end

function MapCoord.ScreenToMapTop(screenX, screenY, offsetX, offsetY)
    local mapX = math.floor((screenX - offsetX) / MapCoord.TILE_W_TOP) + 1
    local mapY = math.floor((screenY - offsetY) / MapCoord.TILE_H_TOP) + 1
    return mapX, mapY
end

return MapCoord
```

---

## Python 实现示例

```python
import math

class MapCoord:
    TILE_W_ISO = 64
    TILE_H_ISO = 32
    TILE_W_TOP = 64
    TILE_H_TOP = 64

    @staticmethod
    def map_to_screen_iso(map_x, map_y, offset_x=0, offset_y=0):
        sx = (map_x - map_y) * (MapCoord.TILE_W_ISO / 2)
        sy = (map_x + map_y) * (MapCoord.TILE_H_ISO / 2)
        return sx + offset_x, sy + offset_y

    @staticmethod
    def screen_to_map_iso(screen_x, screen_y, offset_x=0, offset_y=0):
        sx = screen_x - offset_x
        sy = screen_y - offset_y
        map_x = (sx / (MapCoord.TILE_W_ISO / 2) + sy / (MapCoord.TILE_H_ISO / 2)) / 2
        map_y = (sy / (MapCoord.TILE_H_ISO / 2) - sx / (MapCoord.TILE_W_ISO / 2)) / 2
        return int(map_x + 0.5), int(map_y + 0.5)

    @staticmethod
    def map_to_screen_top(map_x, map_y, offset_x=0, offset_y=0):
        sx = map_x * MapCoord.TILE_W_TOP
        sy = map_y * MapCoord.TILE_H_TOP
        return sx + offset_x, sy + offset_y

    @staticmethod
    def screen_to_map_top(screen_x, screen_y, offset_x=0, offset_y=0):
        map_x = int((screen_x - offset_x) / MapCoord.TILE_W_TOP) + 1
        map_y = int((screen_y - offset_y) / MapCoord.TILE_H_TOP) + 1
        return map_x, map_y
```

---

## 相机偏移

渲染时通常需要加上相机偏移，使地图居中或跟随角色：

```lua
-- 相机跟随角色
cameraX = screenWidth / 2 - playerScreenX
cameraY = screenHeight / 2 - playerScreenY

-- 渲染所有瓦片时加上 cameraX, cameraY
```
