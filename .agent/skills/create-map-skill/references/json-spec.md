# 地图 JSON 格式规范 (v4)

## 完整结构

```json
{
  "version": 4,
  "width": 8,
  "height": 8,
  "showGrid": true,
  "layers": [
    {
      "name": "地面",
      "visible": true,
      "locked": false,
      "opacity": 1.0,
      "tiles": [
        {
          "x": 1,
          "y": 1,
          "id": 322,
          "path": "Tiles/Water Background color.png"
        }
      ]
    }
  ]
}
```

## 字段说明

### 根级别字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `version` | number | 是 | 格式版本，固定为 4 |
| `width` | number | 是 | 地图宽度（列数），1-based |
| `height` | number | 是 | 地图高度（行数），1-based |
| `showGrid` | boolean | 否 | 编辑器网格显示状态，游戏中可忽略 |
| `layers` | array | 是 | 图层数组 |
| `imageRegistry` | array | 否 | 图片瓦片注册表 |
| `tileCustomizations` | array | 否 | 颜色瓦片自定义属性 |

### Layer (图层) 对象

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 图层名称 |
| `visible` | boolean | 否 | 是否可见，默认 true |
| `locked` | boolean | 否 | 是否锁定，默认 false |
| `opacity` | number | 否 | 不透明度 0.0~1.0，默认 1.0 |
| `tiles` | array | 是 | 非空瓦片列表（稀疏存储） |

### Tile (瓦片) 对象

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `x` | number | 是 | 地图 X 坐标 (1-based) |
| `y` | number | 是 | 地图 Y 坐标 (1-based) |
| `id` | number | 是 | 瓦片 ID |
| `path` | string | 否 | 图片资源路径（相对 assets/） |
| `flipH` | boolean | 否 | 是否水平翻转 |
| `tag` | string | 否 | 自定义标签 |

## 瓦片 ID 约定

| ID 范围 | 类型 | 说明 |
|---------|------|------|
| 0 | 空 | 无瓦片（不会出现在 tiles 数组中） |
| 1~5 | 颜色瓦片 | 内置预设颜色 |
| 100+ | 图片瓦片 | 图片资源 |

## 内置颜色瓦片

| ID | 默认名称 | 默认颜色 (RGBA) |
|----|---------|----------------|
| 1 | 草地 | (76, 175, 80, 255) |
| 2 | 水面 | (33, 150, 243, 255) |
| 3 | 沙地 | (255, 193, 7, 255) |
| 4 | 石头 | (158, 158, 158, 255) |
| 5 | 泥土 | (121, 85, 72, 255) |

## 解析步骤

1. 读取 JSON 并解析
2. 创建 `width × height` 的全零网格
3. 遍历每个图层
4. 对每个图层，遍历 tiles 数组，填入网格
5. 建立资源缓存（按需加载图片）
6. 按图层顺序渲染

## 稀疏存储

tiles 数组只包含非空瓦片（id > 0），这样可以大幅减小文件体积。

示例：
```json
{
  "width": 8,
  "height": 8,
  "layers": [
    {
      "name": "地面",
      "tiles": [
        {"x": 1, "y": 1, "id": 322, "path": "..."},
        {"x": 2, "y": 1, "id": 322, "path": "..."},
        ...
      ]
    }
  ]
}
```
