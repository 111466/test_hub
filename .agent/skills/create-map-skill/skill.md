---
name: "map-json-builder"
description: |
  地图 JSON 解析与构建 Skill。
  提供从编辑器导出的 JSON 地图数据解析、渲染、碰撞检测等完整功能。
  支持等距视角 (Isometric) 和正视视角 (Top-down) 两种渲染模式。
  包含完整的示例代码，可直接集成到游戏项目中。
use-when:
  - 用户需要在游戏中加载并渲染编辑器导出的 JSON 地图
  - 用户需要实现地图碰撞检测
  - 用户需要解析 output.json 文件
  - 用户提到"加载地图"、"解析地图"、"渲染地图"
  - 用户需要在游戏中使用等距/正视视角
trigger-keywords:
  - 加载地图
  - 解析地图
  - 渲染地图
  - 地图构建
  - 地图碰撞
  - output.json
  - map json
  - isometric map
  - top-down map
---

# 地图 JSON 构建 Skill

从等距场景编辑器导出的 JSON 地图数据，在游戏中进行解析、渲染和碰撞检测的完整解决方案。

## 功能清单

- **JSON 解析**: 完整解析 v4 格式地图数据
- **双视角渲染**: 等距视角 (Isometric) + 正视视角 (Top-down)
- **图层系统**: 支持多层渲染、可见性控制
- **资源缓存**: 自动缓存瓦片图片资源
- **碰撞检测**: 基于瓦片标签的行走判定
- **坐标转换**: 地图坐标 ↔ 屏幕坐标双向转换

## 数据格式

地图使用 JSON v4 格式，核心结构：

```json
{
  "version": 4,
  "width": 8,
  "height": 8,
  "layers": [
    {
      "name": "地面",
      "visible": true,
      "tiles": [
        {"x": 1, "y": 1, "id": 322, "path": "Tiles/Water Background color.png"}
      ]
    }
  ]
}
```

详细规范见 `references/json-spec.md`。

## 快速开始

### 1. 基础用法 (Lua)

```lua
local MapBuilder = require("MapBuilder")

function Start()
    -- 加载并解析地图
    local map = MapBuilder.Load("output.json")
    
    -- 设置视角模式
    MapBuilder.SetPerspective("isometric")  -- 或 "topdown"
    
    -- 设置瓦片尺寸
    MapBuilder.SetTileSize(64, 32)
end

function Render()
    -- 渲染地图
    MapBuilder.Render(map, cameraX, cameraY)
end
```

### 2. 基础用法 (Python)

```python
from map_builder import MapBuilder

# 加载地图
map_data = MapBuilder.load("output.json")

# 渲染
screen = pygame.display.set_mode((800, 600))
MapBuilder.render(map_data, screen, perspective="isometric")
```

## API 参考

### MapBuilder.Load(jsonPath)

加载并解析地图 JSON 文件。

**参数:**
- `jsonPath` (string) - JSON 文件路径

**返回:**
- `table` - 解析后的地图数据对象

---

### MapBuilder.SetPerspective(mode)

设置渲染视角。

**参数:**
- `mode` (string) - `"isometric"` (等距) 或 `"topdown"` (正视)

---

### MapBuilder.SetTileSize(width, height)

设置瓦片像素尺寸。

**参数:**
- `width` (number) - 瓦片宽度
- `height` (number) - 瓦片高度

---

### MapBuilder.MapToScreen(mapX, mapY)

地图坐标 → 屏幕坐标。

**参数:**
- `mapX` (number) - 地图 X 坐标 (1-based)
- `mapY` (number) - 地图 Y 坐标 (1-based)

**返回:**
- `screenX, screenY` - 屏幕像素坐标

---

### MapBuilder.ScreenToMap(screenX, screenY)

屏幕坐标 → 地图坐标。

**参数:**
- `screenX` (number) - 屏幕 X 坐标
- `screenY` (number) - 屏幕 Y 坐标

**返回:**
- `mapX, mapY` - 地图坐标 (1-based)

---

### MapBuilder.IsWalkable(map, mapX, mapY)

检查地图坐标是否可行走。

**参数:**
- `map` (table) - 地图数据对象
- `mapX` (number) - 地图 X 坐标
- `mapY` (number) - 地图 Y 坐标

**返回:**
- `boolean` - 是否可行走

---

### MapBuilder.Render(map, offsetX, offsetY)

渲染地图。

**参数:**
- `map` (table) - 地图数据对象
- `offsetX` (number) - 相机 X 偏移
- `offsetY` (number) - 相机 Y 偏移

## 文件清单

| 文件 | 说明 |
|------|------|
| `skill.md` | 本文件，Skill 说明文档 |
| `references/json-spec.md` | JSON 格式详细规范 |
| `references/examples.lua` | Lua 完整示例代码 |
| `references/examples.py` | Python 完整示例代码 |
| `references/coordinates.md` | 坐标系转换详解 |

## 视角说明

### 等距视角 (Isometric)

菱形瓦片排列，适合策略游戏、RPG。

坐标转换公式:
```
screenX = (mapX - mapY) * (tileWidth / 2)
screenY = (mapX + mapY) * (tileHeight / 2)
```

### 正视视角 (Top-down)

方格排列，适合 Roguelike、动作游戏。

坐标转换公式:
```
screenX = mapX * tileWidth
screenY = mapY * tileHeight
```

## 集成示例

完整的 Lua 游戏集成代码见 `references/examples.lua`，包含：

- 地图加载与解析
- 双视角渲染切换
- 角色移动与碰撞
- 相机跟随
- 鼠标点击拾取瓦片

## 注意事项

1. **坐标系**: 地图坐标是 1-based，屏幕坐标是 0-based
2. **渲染顺序**: 图层按索引顺序渲染，索引小的在底层
3. **稀疏存储**: tiles 数组只包含非空瓦片，解析时先创建全零网格
4. **资源路径**: tile.path 是相对于 assets/ 的路径
