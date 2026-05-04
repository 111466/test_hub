-- ============================================================================
-- 空项目脚手架
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil

local CONFIG = {
    Title = "My Game",
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = CONFIG.Title

    -- 初始化 UI
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 创建 UI
    CreateUI()

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("=== Game Started: " .. CONFIG.Title .. " ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- UI
-- ============================================================================

function CreateUI()
    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = CONFIG.Title,
                fontSize = 24,
                fontColor = { 255, 255, 255, 255 },
            },
        }
    }
    UI.SetRoot(uiRoot_)
end

-- ============================================================================
-- 游戏逻辑
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- TODO: 游戏更新逻辑
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    -- TODO: 按键处理
end
