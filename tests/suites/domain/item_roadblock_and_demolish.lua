local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _assert_tile_id_sequence = support.assert_tile_id_sequence
local executor = support.executor
local choice_resolver = support.choice_resolver
local gameplay_rules = require("src.config.gameplay.rules")
local roadblock = require("src.rules.items.roadblock")

local function _install_narrow_ports(game, ui_port)
  game.ui_port = ui_port
  game.anim_gate_port = {
    wait_move_anim = ui_port and ui_port.wait_move_anim == true,
    wait_action_anim = ui_port and ui_port.wait_action_anim == true,
  }
  game.popup_port = {
    push_popup = function(_, payload, popup_opts)
      if ui_port and type(ui_port.push_popup) == "function" then
        return ui_port:push_popup(payload, popup_opts)
      end
      return false
    end,
  }
  game.tile_feedback_port = {
    on_tile_upgraded = function(_, tile_id, level)
      if ui_port and type(ui_port.on_tile_upgraded) == "function" then
        return ui_port:on_tile_upgraded(tile_id, level) == true
      end
      return false
    end,
  }
end

local function _set_ui_port(game, overrides)
  _install_narrow_ports(game, support.build_ui_port(overrides))
end

local function _test_roadblock_manual_choice_shows_seven_tiles_with_tile_names_only()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  local expected = roadblock.manual_candidates(g, p, 3)
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should open choice")

  local pending = res.intent.choice_spec
  assert(pending and pending.kind == "roadblock_target", "roadblock should open target choice")
  _assert_eq(#pending.options, 7, "manual roadblock should expose seven nearest unique options")
  for i, cand in ipairs(expected) do
    _assert_eq(pending.options[i].id, cand.idx, "roadblock option should keep board index at slot " .. i)
    _assert_eq(pending.options[i].label, cand.tile.name, "roadblock option should show tile name only at slot " .. i)
    _assert_eq(pending.body_lines[i], cand.tile.name, "roadblock body should show tile name only at slot " .. i)
  end
end

local function _test_roadblock_manual_choice_allows_current_tile()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  local current_idx = p.position
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should wait for target choice")
  local pending = _open_choice(g, res.intent.choice_spec)
  _assert_eq(pending.options[1].id, current_idx, "slot1 should target current tile")

  choice_resolver.resolve(g, pending, { option_id = current_idx })
  _assert_eq(g.board:has_roadblock(current_idx), true, "manual roadblock should allow current tile placement")
end

local function _test_roadblock_manual_choice_hongkong_keeps_nearest_slots_ordered()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  g:update_player_position(p, 7)
  p.inventory:add({ id = item_id })

  local expected_names = {
    "香港路",
    "广州路",
    "澳门路",
    "医院",
    "道具卡",
    "海口路",
    "南宁路",
  }

  local candidates = roadblock.manual_candidates(g, p, 3)
  _assert_eq(#candidates, 7, "hongkong roadblock candidates should still expose seven slots")
  for index, expected_name in ipairs(expected_names) do
    _assert_eq(candidates[index].tile.name, expected_name, "hongkong candidate name mismatch at slot " .. index)
  end

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should open choice at hongkong")
  local pending = _open_choice(g, res.intent.choice_spec)
  for index, expected_name in ipairs(expected_names) do
    _assert_eq(pending.options[index].label, expected_name, "pending roadblock option label mismatch at slot " .. index)
  end
  _assert_eq(pending.options[6].id, 4, "nearest haikou slot should keep the expected board index")
end

local function _test_roadblock_manual_choice_hongkong_nearest_haikou_slot_places_correctly()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  g:update_player_position(p, 7)
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should wait for target choice at hongkong")
  local pending = _open_choice(g, res.intent.choice_spec)

  _assert_eq(pending.options[6].id, 4, "nearest haikou slot should resolve before placement")
  choice_resolver.resolve(g, pending, { option_id = pending.options[6].id })

  _assert_eq(g.board:has_roadblock(4), true, "nearest haikou slot should place roadblock on haikou")
  _assert_eq(g.board:has_roadblock(10), false, "nearest haikou slot should not incorrectly place roadblock on nanning")
end

local function _test_roadblock_manual_candidates_expose_nearest_unique_tiles_at_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(45))
  g:set_player_status(p, "move_dir", nil)

  local candidates = roadblock.manual_candidates(g, p, 3)
  local expected_names = {
    "机会卡",
    "重庆路",
    "道具卡",
    "海口路",
    "广州路",
    "天津路",
    "台北路",
  }

  _assert_eq(#candidates, #expected_names, "intersection roadblock ui should expose seven nearest unique target tiles")
  for index, expected_name in ipairs(expected_names) do
    _assert_eq(candidates[index].tile.name, expected_name, "intersection candidate name mismatch at slot " .. index)
  end
end

local function _test_roadblock_manual_candidates_use_shared_manhattan_range_at_branch()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))

  local candidates = roadblock.manual_candidates(g, p, 3)
  local expected_ids = { 42, 3, 4, 45, 2, 5, 31 }

  _assert_tile_id_sequence(candidates, expected_ids, "branch roadblock candidate sequence mismatch")
end

local function _test_demolish_manual_choice_uses_manhattan_range_at_branch()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.monster
  g:update_player_position(p, g.board:index_of_tile_id(42))
  p.inventory:add({ id = item_id })

  local target_ids = { 3, 4, 31, 5, 2, 1 }
  local target_indices = {}
  for _, tile_id in ipairs(target_ids) do
    local tile_ref = assert(g.board:get_tile(g.board:index_of_tile_id(tile_id)), "missing target tile")
    g:set_tile_owner(tile_ref, g.players[2].id)
    g:set_tile_level(tile_ref, 1)
    target_indices[#target_indices + 1] = g.board:index_of_tile_id(tile_id)
  end

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting == true, "monster manual use should open choice")
  local pending = res.intent.choice_spec
  assert(pending and pending.kind == "demolish_target", "monster manual use should expose demolish target choice")

  local option_ids = {}
  for _, option in ipairs(pending.options or {}) do
    option_ids[#option_ids + 1] = option.id
  end
  for _, target_idx in ipairs(target_indices) do
    assert(support.list_contains(option_ids, target_idx), "demolish manual choice should include index " .. tostring(target_idx))
  end
end

local function _test_roadblock_ai_uses_auto_candidates_only()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = true })
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "ai roadblock should apply immediately")
  _assert_eq(g.board:has_roadblock(p.position), false, "ai roadblock should not place on current tile")
end

return {
  _test_roadblock_manual_choice_shows_seven_tiles_with_tile_names_only,
  _test_roadblock_manual_choice_allows_current_tile,
  _test_roadblock_manual_choice_hongkong_keeps_nearest_slots_ordered,
  _test_roadblock_manual_choice_hongkong_nearest_haikou_slot_places_correctly,
  _test_roadblock_manual_candidates_expose_nearest_unique_tiles_at_intersection,
  _test_roadblock_manual_candidates_use_shared_manhattan_range_at_branch,
  _test_demolish_manual_choice_uses_manhattan_range_at_branch,
  _test_roadblock_ai_uses_auto_candidates_only,
}
