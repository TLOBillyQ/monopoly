---@class GameManager
---@field gaming boolean 是否开始游戏
GameManager = {}

function GameManager.start_game()
    if not GameManager.gaming then
        GameManager.gaming = true
        LevelData.current_mode = LevelData.current_mode or "LootEscaper"
        for _, role in ipairs(ALLROLES) do
            role.send_ui_custom_event("请求探索动画", {})
        end
        SetFrameOut(30, function(frameout)
            MapManager.enter_level(LevelData.current_select_level)
        end, 1)
    end
end
