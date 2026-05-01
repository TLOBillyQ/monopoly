local auto_runner = require("src.turn.policies.auto_runner")
local composition_root = require("src.app.compose_game")
local app = require("src.state.game_state")
local tiles_cfg = require("src.config.content.tiles")
local default_map = require("src.config.content.maps.default_map")
local runtime_refs = require("src.config.content.runtime_refs")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_id_utils = require("src.foundation.identity.role_id")
local default_ports = require("src.turn.output.default_ports")
local logger = require("src.foundation.log.logger")
local fallback_registry = require("src.rules.choice.fallback_registry")

local function _register_default_choice_fallbacks()
  fallback_registry.register("market_buy", function(_, choice)
    return { type = "choice_cancel", choice_id = choice and choice.id }
  end)
  fallback_registry.register("item_target_tile", function(_, choice)
    return { type = "choice_cancel", choice_id = choice and choice.id }
  end)
  fallback_registry.register("item_target_player", function(_, choice)
    return { type = "choice_cancel", choice_id = choice and choice.id }
  end)
  fallback_registry.register("steal_target", function(_, choice)
    return { type = "choice_cancel", choice_id = choice and choice.id }
  end)
end

_register_default_choice_fallbacks()

local max_player_count = 4
local synthetic_ai_cfg = runtime_refs.synthetic_ai or {}
local synthetic_unit_keys = synthetic_ai_cfg.unit_keys or {}
local synthetic_avatar_refs = runtime_refs.images or {}
local synthetic_ai_names = synthetic_ai_cfg.names or {}
local M = {}

local function _is_release_build(build_mode)
  return build_mode == "release"
end

local function _resolve_startup_map(startup)
  if _is_release_build(startup and startup.build_mode) then
    return default_map
  end
  return require("src.app.profile_source").resolve_map(startup)
end

local function _apply_startup_bootstrap(game, startup)
  if _is_release_build(startup and startup.build_mode) then
    return
  end
  local bootstrap = require("src.app.profile_bootstrap")
  local startup_profile_source = require("src.app.profile_source")
  bootstrap.apply_bootstrap(game, startup_profile_source.resolve_bootstrap(startup))
end

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
     local pick_index = GameAPI.random_int(index, #pool)
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
    name = synthetic_ai_names[slot_index] or ("AI" .. tostring(slot_index)),
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
  for _, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      if ai == nil then
        ai = {}
      end
      ai[role.role_id] = true
    end
  end
  return ai
end

local function _build_synthetic_player_specs(role_roster)
  local specs = {}
  for _, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      specs[#specs + 1] = {
        player_id = role.role_id,
        name = role.name,
        unit_key = role.unit_key,
        avatar_image_key = role.avatar_image_key,
      }
    end
  end
  return specs
end

function M.build_game_factory(state, opts)
  assert(state ~= nil, "missing state")
  opts = opts or {}
  local build_mode = opts.build_mode
  local profile_name = opts.profile_name
  local profile_source = opts.profile_source
  local profile_module = opts.profile_module
  return function()
    local startup = {
      build_mode = build_mode,
      profile_name = profile_name,
      profile_source = profile_source,
      profile_module = profile_module,
    }
    local map_cfg = _resolve_startup_map(startup)
    local role_roster = _build_startup_roster(max_player_count)
    local forced_ai = _build_startup_ai_map(role_roster)
    logger.info("[Eggy]", "使用四槽角色驱动初始化，角色数量:", tostring(#role_roster))
    local created_game = composition_root.new_game(default_ports.resolve_game_opts({
      role_roster = role_roster,
      ai = forced_ai,
      auto_all = false,
      map = map_cfg,
      tiles = tiles_cfg,
    }), app)
    created_game.startup_synthetic_players = _build_synthetic_player_specs(role_roster)
    _apply_startup_bootstrap(created_game, startup)
    return created_game
  end
end

function M.build_auto_runner()
  return auto_runner:new({
    interval = timing.auto_decision_delay_seconds,
  })
end

return M
