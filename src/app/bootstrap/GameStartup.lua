local auto_runner = require("src.game.flow.turn.AutoRunner")
local board_view = require("src.presentation.render.BoardRuntime")
local game = require("src.game.core.runtime.Game")
local ui_view = require("src.presentation.api.UIViewService")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local gameplay_rules = require("Config.GameplayRules")
local test_profile_bootstrap = require("src.app.testing.TestProfileBootstrap")
local logger = require("src.core.Logger")
local runtime_state = require("src.core.RuntimeState")
local runtime_ports = require("src.core.RuntimePorts")

local max_player_count = 4

local M = {}

local function _resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  return {}
end

local function _build_role_roster(max_players)
  local roster = {}
  local roles = _resolve_roles()
  for _, role in ipairs(roles) do
    local role_id = nil
    if role and role.get_roleid then
      local ok, id = pcall(role.get_roleid)
      if ok and id ~= nil then
        role_id = id
      end
    end
    if role_id ~= nil then
      local role_name = nil
      if role.get_name then
        local ok, name = pcall(role.get_name)
        if ok and name and name ~= "" then
          role_name = name
        end
      end
      roster[#roster + 1] = { role_id = role_id, name = role_name }
    end
    if max_players and #roster >= max_players then
      break
    end
  end
  if max_players and #roles > max_players then
    logger.warn(
      "[Eggy]",
      "角色数量超过上限，已截断:",
      tostring(#roles),
      "->",
      tostring(max_players)
    )
  end
  return roster
end

local function _build_non_p1_ai_map(player_count)
  if gameplay_rules.test_force_non_p1_ai ~= true then
    return nil
  end
  local ai = {}
  for i = 2, player_count or 0 do
    ai[i] = true
  end
  return ai
end

-- state 中保存当前 game 的引用，由 UIBootstrap 在 GAME_INIT 之后赋值
function M.build_state(get_current_game)
  local ui = ui_view.build_ui_state()
  local state = {
    ui = ui,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    wait_move_anim = true,
    wait_action_anim = true,
    game_factory = function()
      local role_roster = _build_role_roster(max_player_count)
      local forced_ai = _build_non_p1_ai_map(#role_roster)
      local created_game = nil
      if #role_roster > 0 then
        logger.info("[Eggy]", "使用角色驱动初始化，角色数量:", tostring(#role_roster))
        created_game = game:new({
          role_roster = role_roster,
          ai = forced_ai,
          auto_all = false,
          map = map_cfg,
          tiles = tiles_cfg,
        })
      else
        logger.warn("[Eggy]", "角色列表为空，回退调试玩家初始化")
        local player_names = { "玩家1", "AI2", "AI3", "AI4" }
        local fallback_ai = _build_non_p1_ai_map(#player_names) or { [2] = true, [3] = true, [4] = true }
        created_game = game:new({
          players = player_names,
          ai = fallback_ai,
          auto_all = false,
          map = map_cfg,
          tiles = tiles_cfg,
        })
      end
      test_profile_bootstrap.apply(created_game)
      return created_game
    end,
    auto_runner = auto_runner:new({ interval = ui.auto_interval }),
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    choice_visible_option_ids = nil,
    pending_choice_selected_option_id = nil,
    tick_started = false,
    ui_dirty = false,
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
  }

  runtime_state.ensure_all(state)

  state.push_popup = function(_, payload)
    local ok = ui_view.push_popup(state, payload)
    if state.ui then
      local current_game = get_current_game()
      if ok and current_game and current_game.turn then
        state.ui.popup_owner_index = current_game.turn.current_player_index
      else
        state.ui.popup_owner_index = nil
      end
    end
    return ok
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    board_view.on_tile_upgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    board_view.on_tile_owner_changed(state, tile_id, owner_id)
  end

  return state
end

return M
