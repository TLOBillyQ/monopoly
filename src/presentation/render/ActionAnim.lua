local runtime_constants = require("Config.RuntimeConstants")
local gameplay_rules = require("Config.GameplayRules")

local prefab = require("Data.Prefab")
local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")

local action_anim = {}

local durations = {
  missile = 1.2,
  monster = 1.2,
}

local dice_screen_nodes = {
  screen = "骰子屏",
  spin = "骰子-旋转骰子底图",
  faces = {
    "骰子-骰子点数1",
    "骰子-骰子点数2",
    "骰子-骰子点数3",
    "骰子-骰子点数4",
    "骰子-骰子点数5",
    "骰子-骰子点数6",
  },
}

local function _resolve_tile_name(state, tile_index)
  if not state or not tile_index then
    return "未知地块"
  end
  local game = state.game
  local board = game and game.board or nil
  local tile = board and board.get_tile and board:get_tile(tile_index) or nil
  if tile and tile.name then
    return tile.name
  end
  return "未知地块"
end

local function _resolve_player_name(state, player_id)
  if not player_id then
    return "未知玩家"
  end
  local game = state and state.game or nil
  local player = game and game.find_player_by_id and game:find_player_by_id(player_id) or nil
  if player and player.name then
    return player.name
  end
  return tostring(player_id)
end

local function _build_tip(state, anim)
  if anim.focus_text and anim.focus_text ~= "" then
    return anim.focus_text
  end
  local kind = anim.kind
  if kind == "roll" then
    local rolls = anim.rolls and table.concat(anim.rolls, ",") or "?"
    local total = anim.total or "?"
    return "投骰动画：" .. rolls .. " => " .. total
  end
  if kind == "roadblock" then
    return "路障动画：放置在 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "mine" then
    return "地雷动画：埋设在 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "missile" then
    return "导弹动画：轰炸 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "monster" then
    return "怪兽动画：破坏 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "clear_obstacles" then
    local count = anim.cleared_indices and #anim.cleared_indices or 0
    return "清障动画：清除数量 " .. tostring(count)
  end
  if kind == "upgrade_land" then
    return "加盖动画：" .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "chance" then
    return "机会卡展示：" .. tostring(anim.card_desc or anim.card_id or "?")
  end
  if kind == "item_use" then
    return "道具生效：" .. tostring(anim.item_name or anim.item_id or "?")
  end
  if kind == "item_target_player" then
    local target_name = _resolve_player_name(state, anim.target_player_id)
    return "目标道具：" .. tostring(anim.item_name or anim.item_id or "?")
      .. " -> 玩家 " .. target_name
  end
  if kind == "move_effect" then
    return "位移动画：从 "
      .. _resolve_tile_name(state, anim.from_index)
      .. " 到 "
      .. _resolve_tile_name(state, anim.to_index)
  end
  return "动作动画"
end

local function _resolve_tile_pos(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  local tile = assert(tiles[tile_index], "missing tile unit: " .. tostring(tile_index))
  assert(tile.get_position ~= nil, "missing tile.get_position: " .. tostring(tile_index))
  return tile.get_position()
end

local function _ensure_overlays(scene)
  if not scene.overlay_units then
    scene.overlay_units = { roadblocks = {}, mines = {} }
  end
  return scene.overlay_units
end

local function _get_overlay_bucket(overlays, kind)
  if kind == "roadblock" then
    return overlays.roadblocks
  end
  if kind == "mine" then
    return overlays.mines
  end
  return nil
end

local function _spawn_unit_group(group_id, pos)
  assert(group_id ~= nil, "missing group_id")
  assert(pos ~= nil, "missing pos")
  assert(GameAPI ~= nil and GameAPI.create_unit_group ~= nil, "missing GameAPI.create_unit_group")
  return GameAPI.create_unit_group(group_id, pos, runtime_constants.q_zero)
end

local function _spawn_unit(unit_id, pos)
  assert(unit_id ~= nil, "missing unit_id")
  assert(pos ~= nil, "missing pos")
  assert(GameAPI ~= nil and GameAPI.create_unit_with_scale ~= nil, "missing GameAPI.create_unit_with_scale")
  return GameAPI.create_unit_with_scale(unit_id, pos, runtime_constants.q_zero, runtime_constants.v3_one)
end

local function _destroy_unit(entry)
  if not entry or not entry.handle then
    return
  end
  if entry.kind == "group" then
    if GameAPI and GameAPI.destroy_unit_with_children then
      GameAPI.destroy_unit_with_children(entry.handle, true)
    end
    return
  end
  if GameAPI and GameAPI.destroy_unit then
    GameAPI.destroy_unit(entry.handle)
  end
end

function action_anim.clear_overlay(state, kind, tile_index)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return
  end
  local entry = bucket[tile_index]
  if not entry then
    return
  end
  _destroy_unit(entry)
  bucket[tile_index] = nil
end

local function _spawn_overlay(state, kind, tile_index, group_id, unit_id)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return false
  end
  if bucket[tile_index] then
    action_anim.clear_overlay(state, kind, tile_index)
  end
  local pos = _resolve_tile_pos(state, tile_index) + math.Vector3(0.0, 1.0, 0.0)
  if group_id then
    local handle = _spawn_unit_group(group_id, pos)
    bucket[tile_index] = { kind = "group", handle = handle }
    return true
  end
  if unit_id then
    local handle = _spawn_unit(unit_id, pos)
    bucket[tile_index] = { kind = "unit", handle = handle }
    return true
  end
  return false
end

local function _spawn_transient(group_id, unit_id, pos, duration)
  if not group_id and not unit_id then
    return
  end
  local entry
  if group_id then
    entry = { kind = "group", handle = _spawn_unit_group(group_id, pos) }
  else
    entry = { kind = "unit", handle = _spawn_unit(unit_id, pos) }
  end
  if duration and duration > 0 then
    SetTimeOut(duration, function()
      _destroy_unit(entry)
    end)
  else
    _destroy_unit(entry)
  end
end

local function _show_tip(text, duration)
  if GlobalAPI and GlobalAPI.show_tips then
    GlobalAPI.show_tips(text, duration)
  end
end

local function _resolve_roll_face(anim)
  if not anim then
    return nil
  end
  local total = anim.total
  if type(total) == "number" then
    if total >= 1 and total <= 6 then
      return total
    end
    if total > 6 then
      local rolls = anim.rolls
      local first = type(rolls) == "table" and rolls[1] or nil
      if type(first) == "number" and first >= 1 and first <= 6 then
        return first
      end
    end
  end
  local rolls = anim.rolls
  local first = type(rolls) == "table" and rolls[1] or nil
  if type(first) == "number" and first >= 1 and first <= 6 then
    return first
  end
  return nil
end

local function _set_node_visible(node, visible)
  if not node then
    return
  end
  node.visible = visible == true
end

local function _set_dice_face_visible(nodes, face)
  for index, node in ipairs(nodes.faces or {}) do
    _set_node_visible(node, face == index)
  end
end

local function _spin_node(node, duration)
  if not node or not duration or duration <= 0 then
    return
  end
  local steps = 12
  local step_time = duration / steps
  pcall(function()
    node.rotation = runtime_constants.q_zero
  end)
  for i = 1, steps do
    local delay = step_time * (i - 1)
    local angle = 360 * i / steps
    SetTimeOut(delay, function()
      pcall(function()
        node.rotation = math.Quaternion(0.0, 0.0, angle)
      end)
    end)
  end
end

local function _play_roll_dice_screen(_, anim, duration, hold_seconds)
  local face = _resolve_roll_face(anim)
  runtime.for_each_role_or_global(function()
    local nodes = {
      screen = runtime.query_node(dice_screen_nodes.screen),
      spin = runtime.query_node(dice_screen_nodes.spin),
      faces = {},
    }
    for index, name in ipairs(dice_screen_nodes.faces) do
      nodes.faces[index] = runtime.query_node(name)
    end

    _set_node_visible(nodes.screen, true)
    _set_node_visible(nodes.spin, true)
    _set_dice_face_visible(nodes, nil)

    _spin_node(nodes.spin, duration)

    SetTimeOut(duration, function()
      if face then
        _set_dice_face_visible(nodes, face)
      end
    end)

    SetTimeOut(duration + hold_seconds, function()
      _set_node_visible(nodes.screen, false)
      _set_node_visible(nodes.spin, false)
      _set_dice_face_visible(nodes, nil)
    end)
  end)
end

function action_anim.play(state, anim)
  assert(anim ~= nil, "missing anim")
  assert(state ~= nil, "missing state")
  local default_duration = gameplay_rules.action_anim_default_seconds or 1.0
  local duration = anim.duration or durations[anim.kind] or default_duration
  if duration <= 0 then
    duration = default_duration
  end

  local kind = anim.kind
  if kind == "roll" then
    local hold_seconds = 0.5
    _play_roll_dice_screen(state, anim, duration, hold_seconds)
    return duration + hold_seconds
  end
  local tip_duration = duration
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end
  _show_tip(_build_tip(state, anim), tip_duration)
  if kind == "roadblock" then
    local tile_index = assert(anim.tile_index, "missing roadblock tile_index")
    local group_id = prefab.group["路障"]
    local unit_id = prefab.unit and prefab.unit["路障"] or nil
    _spawn_overlay(state, "roadblock", tile_index, group_id, unit_id)
  elseif kind == "mine" then
    local tile_index = assert(anim.tile_index, "missing mine tile_index")
    local group_id = prefab.group["地雷"]
    local unit_id = prefab.unit and prefab.unit["地雷"] or nil
    if not group_id and not unit_id then
      _show_tip("缺少地雷 prefab，跳过生成", 1.5)
      logger.warn("[Eggy]", "地雷 prefab 缺失，已跳过生成")
    else
      _spawn_overlay(state, "mine", tile_index, group_id, unit_id)
    end
  elseif kind == "missile" then
    local tile_index = assert(anim.tile_index, "missing missile tile_index")
    action_anim.clear_overlay(state, "roadblock", tile_index)
    action_anim.clear_overlay(state, "mine", tile_index)
    local unit_id = prefab.unit and prefab.unit["导弹"] or nil
    local group_id = prefab.group["导弹"]
    local pos = _resolve_tile_pos(state, tile_index) + math.Vector3(0.0, 1.0, 0.0)
    _spawn_transient(group_id, unit_id, pos, duration)
  elseif kind == "clear_obstacles" then
    local cleared = anim.cleared_indices or {}
    for _, idx in ipairs(cleared) do
      action_anim.clear_overlay(state, "roadblock", idx)
      action_anim.clear_overlay(state, "mine", idx)
    end
    local player_id = assert(anim.player_id, "missing clear_obstacles player_id")
    local game = assert(state.game, "missing state.game")
    local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
    local pos = _resolve_tile_pos(state, player.position) + math.Vector3(0.0, 1.0, 0.0)
    local robot_id = prefab.group["清障机器人"]
    _spawn_transient(robot_id, nil, pos, duration)
  end

  return duration
end

return action_anim
