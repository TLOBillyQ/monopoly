local board_scene = require("src.presentation.render.BoardScene")
local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local ui_view = require("src.presentation.api.UIView")
local ui_event_router = require("src.presentation.interaction.UIEventRouter")
local ui_nodes = require("src.presentation.shared.UINodes")
local market_ui = require("src.presentation.shared.MarketLayout")
local map_cfg = require("Config.Map")
local ui_events = require("src.presentation.shared.UIEvents")

local M = {}

local function _start_tick_loop(state, current_game_ref, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval) / 30.0
  SetFrameOut(tick_interval, function()
    gameplay_loop.tick(current_game_ref[1], state, tick_seconds)
  end, -1)
end

-- current_game_ref 是一个单元素数组 { nil }，供 set/get 当前 game 使用
function M.install(state, current_game_ref)
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    require "vendor.third_party.UIManager.Utils"
    local ui_manager_nodes = require("Data.UIManagerNodes")
    UIManager.Builder:new(ui_manager_nodes)
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    local current_game = gameplay_loop.new_game(state)
    current_game_ref[1] = current_game
    gameplay_loop.set_game(state, current_game)
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

    if not state.tick_started then
      state.tick_started = true
      _start_tick_loop(state, current_game_ref)
    end
  end)
end

return M
