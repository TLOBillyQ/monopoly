local auto_runner = require("src.game.flow.turn.auto.runner")
local board_view = require("src.presentation.view.render.board")
local game = require("src.game.core.runtime.game")
local ui_view = require("src.presentation.runtime.ui_runtime")
local modal_controller = require("src.presentation.runtime.controllers.modal_controller")
local tiles_cfg = require("src.config.content.tiles")
local runtime_refs = require("src.config.content.runtime_refs")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local logger = require("src.core.utils.logger")
local runtime_state = require("src.core.state_access.runtime_state")
local runtime_ports = require("src.core.ports.runtime_ports")
local role_id_utils = require("src.core.utils.role_id")
local default_ports = require("src.game.runtime.default_ports")

local max_player_count = 4
local synthetic_unit_keys = { 9000601, 9000602, 9000603, 9000604, 9000605, 9000607 }
local synthetic_avatar_refs = runtime_refs.images or {}

local M = {}

local function _resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  local retried = runtime_ports.resolve_roles()
  if type(retried) == "table" and #retried > 0 then
    logger.info("[Eggy]", "角色列表二次拉取成功，角色数量:", tostring(#retried))
    return retried
  end
  return {}
end

local function _pick_synthetic_unit_keys(count)
  local selected = {}
  if count == nil or count <= 0 then
    return selected
  end
  local pool = {}
  for index, unit_key in ipairs(synthetic_unit_keys) do
    pool[index] = unit_key
  end
  local limit = count
  if limit > #pool then
    limit = #pool
  end
  for index = 1, limit do
    local pick_index = runtime_ports.rng_next_int(index, #pool)
    local picked = pool[pick_index]
    pool[pick_index] = pool[index]
    pool[index] = picked
    selected[index] = pool[index]
  end
  return selected
end

local function _resolve_role_id_from_role(role)
  if not (role and role.get_roleid) then
    return nil
  end
  local ok, id = pcall(role.get_roleid)
  if not ok or id == nil then
    return nil
  end
  return role_id_utils.normalize(id)
end

local function _resolve_role_name(role)
  if not role.get_name then
    return nil
  end
  local ok, name = pcall(role.get_name)
  if not ok or not name or name == "" then
    return nil
  end
  return name
end

local function _add_real_roles_to_roster(roster, roles, max_players)
  for _, role in ipairs(roles) do
    local role_id = _resolve_role_id_from_role(role)
    if role_id ~= nil then
      local role_name = _resolve_role_name(role)
      roster[#roster + 1] = { role_id = role_id, name = role_name }
    end
    if max_players and #roster >= max_players then
      break
    end
  end
  return roster
end

local function _build_synthetic_role(slot_index, unit_key)
  local avatar_ref_id = "AI" .. tostring(slot_index)
  return {
    role_id = -slot_index,
    name = "AI" .. tostring(slot_index),
    synthetic = true,
    unit_key = unit_key,
    avatar_image_key = synthetic_avatar_refs[avatar_ref_id],
  }
end

local function _add_synthetic_roles_to_roster(roster, max_players, selected_unit_keys)
  local missing_count = max_players and (max_players - #roster) or 0
  for index = 1, missing_count do
    local slot_index = #roster + 1
    roster[slot_index] = _build_synthetic_role(slot_index, selected_unit_keys[index])
  end
  return roster
end

local function _warn_if_roles_truncated(roles_count, max_players)
  if max_players and roles_count > max_players then
    logger.warn(
      "[Eggy]",
      "角色数量超过上限，已截断:",
      tostring(roles_count),
      "->",
      tostring(max_players)
    )
  end
end

local function _build_startup_roster(max_players)
  local roster = {}
  local roles = _resolve_roles()
  roster = _add_real_roles_to_roster(roster, roles, max_players)
  local missing_count = max_players and (max_players - #roster) or 0
  local selected_unit_keys = _pick_synthetic_unit_keys(missing_count)
  roster = _add_synthetic_roles_to_roster(roster, max_players, selected_unit_keys)
  _warn_if_roles_truncated(#roles, max_players)
  return roster
end

local function _build_startup_ai_map(role_roster)
  local ai = nil
  for index, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      if ai == nil then
        ai = {}
      end
      ai[index] = true
      ai[role.role_id] = true
    end
  end
  return ai
end

-- state 中保存当前 game 的引用，由 UIBootstrap 在 GAME_INIT 之后赋值
function M.build_state(get_current_game, opts)
  opts = opts or {}
  local profile_name = opts.profile_name
  local ui = ui_view.build_ui_state()
  local state = nil
  state = {
    ui = ui,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    wait_move_anim = true,
    wait_action_anim = true,
    active_profile_name = profile_name,
    game_factory = function()
      local active_profile = state.active_profile_name or profile_name
      local map_cfg = test_profile_resolver.resolve_map(active_profile)
      local role_roster = _build_startup_roster(max_player_count)
      local forced_ai = _build_startup_ai_map(role_roster)
      logger.info("[Eggy]", "使用四槽角色驱动初始化，角色数量:", tostring(#role_roster))
      local created_game = game:new(default_ports.resolve_game_opts({
        role_roster = role_roster,
        ai = forced_ai,
        auto_all = false,
        map = map_cfg,
        tiles = tiles_cfg,
      }))
      local synthetic_players = {}
      for _, role in ipairs(role_roster) do
        if role and role.synthetic == true then
          synthetic_players[#synthetic_players + 1] = {
            player_id = role.role_id,
            name = role.name,
            unit_key = role.unit_key,
            avatar_image_key = role.avatar_image_key,
          }
        end
      end
      created_game.startup_synthetic_players = synthetic_players
      test_profile_bootstrap.apply(created_game, active_profile)
      return created_game
    end,
    auto_runner = auto_runner:new({ interval = gameplay_rules.ai_auto_turn_interval_seconds }),
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    tick_started = false,
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
  }

  runtime_state.ensure_all(state)

  state.push_popup = function(_, payload, opts)
    local ok = modal_controller.push_popup(state, payload, opts)
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
  state.on_board_visual_sync = function(_, payload)
    return board_view.sync_many(state, payload)
  end

  return state
end

return M
