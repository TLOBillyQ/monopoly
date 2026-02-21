local board_scene = require("src.presentation.render.BoardScene")
local ui_view = require("src.presentation.api.UIViewService")
local ui_event_router = require("src.presentation.interaction.UIEventRouter")
local ui_nodes = require("src.presentation.shared.UINodes")
local market_ui = require("src.presentation.shared.MarketLayout")
local map_cfg = require("Config.Map")
local ui_events = require("src.presentation.shared.UIEvents")

local M = {}

-- current_game_ref 是一个单元素数组 { nil }，供 set/get 当前 game 使用
function M.install(state, current_game_ref, opts)
  opts = opts or {}
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    require "vendor.third_party.UIManager.Utils"
    local ui_manager_nodes = require("Data.UIManagerNodes")
    UIManager.Builder:new(ui_manager_nodes)
    local current_game = current_game_ref[1]
    if not current_game and type(opts.start_runtime) == "function" then
      current_game = opts.start_runtime(state, current_game_ref)
    end
    assert(current_game ~= nil, "missing current_game")

    ui_event_router.bind(state, function()
      return current_game_ref[1]
    end)

    if ui_events.set_roles then
      ui_events.set_roles(all_roles)
    end

    local required_nodes = ui_nodes.required_click_nodes({
      extra = market_ui.item_buttons or {},
    })
    local missing = ui_manager_nodes.validate(required_nodes)
    if #missing > 0 then
      error("UI 节点缺失: " .. table.concat(missing, ", "))
    end

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    board_scene.init(state, map_cfg, current_game)
    ui_view.init_ui_assets(state)
    ui_view.capture_player_colors(state, current_game)

    SetTimeOut(1.0, function()
      ui_events.send_to_all(ui_events.hide["加载屏"], {})
      ui_events.send_to_all(ui_events.show["基础屏"], {})
    end)
  end)
end

return M
