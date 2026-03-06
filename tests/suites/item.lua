local support = require("TestSupport")
local default_map = require("Config.Maps.DefaultMap")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _resolve_choice_first = support.resolve_choice_first
local _tile_state = support.tile_state
local _assert_eq = support.assert_eq
local executor = support.executor
local choice_resolver = support.choice_resolver
local gameplay_rules = require("src.core.config.GameplayRules")
local item_phase = require("src.game.systems.items.ItemPhase")
local roadblock = require("src.game.systems.items.ItemRoadblock")

local function _test_monster_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 2)
  p.inventory:add({ id = 2008 })
  local res = executor.use_item(g, p, 2008, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "monster should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "monster use ok")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed")
end

local function _test_missile_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 4
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 1)
  g:update_player_position(g.players[2], idx)
  g.board:place_roadblock(idx)
  g.board:place_mine(idx)
  p.inventory:add({ id = 2013 })
  local res = executor.use_item(g, p, 2013, {})
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "missile should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "missile use ok")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed by missile")
  _assert_eq(g.board:has_roadblock(idx), false, "roadblock cleared")
  _assert_eq(g.board:has_mine(idx), false, "mine cleared")
  assert(g.players[2].status.stay_turns > 0, "target sent to hospital")
end

local function _test_demolish_card_no_target_returns_false()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = 2008 })

  local res = executor.use_item(g, p, 2008, { by_ai = false })
  _assert_eq(res, false, "demolish without target should return false instead of crashing")
end

local function _test_item_phase_filters_unusable_target_items()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = 2008 }) -- 怪兽卡（无可拆目标）
  p.inventory:add({ id = 2011 }) -- 均富卡（目标玩家已出局）
  g.players[2].eliminated = true

  local spec = item_phase.build_choice_spec(g, p, "post_action")
  _assert_eq(spec, nil, "item_phase should not expose unusable target items")
end

local function _test_item_phase_keeps_demolish_when_target_exists()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 1)
  p.inventory:add({ id = 2008 })

  local spec = item_phase.build_choice_spec(g, p, "post_action")
  assert(spec and spec.options and #spec.options > 0, "item_phase should include demolish when target exists")
  _assert_eq(spec.options[1].id, 2008, "demolish item should be selectable when target exists")
end

local function _test_item_phase_hides_rent_cards_on_owned_land()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:update_player_position(p, idx)
  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  p.inventory:add({ id = gameplay_rules.item_ids.strong })
  p.inventory:add({ id = gameplay_rules.item_ids.free_rent })

  local spec = item_phase.build_choice_spec(g, p, "post_action")
  _assert_eq(spec, nil, "owned land should not expose strong/free rent cards")
end

local function _test_item_phase_keeps_rent_cards_on_other_owned_land()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:update_player_position(p, idx)
  g:set_tile_owner(tile_ref, g.players[2].id)
  g:set_player_cash(p, 100000)
  p.inventory:add({ id = gameplay_rules.item_ids.strong })
  p.inventory:add({ id = gameplay_rules.item_ids.free_rent })

  local spec = assert(item_phase.build_choice_spec(g, p, "post_action"), "other player land should expose rent cards")
  local found = {}
  for _, option in ipairs(spec.options) do
    found[option.id] = true
  end
  _assert_eq(found[gameplay_rules.item_ids.strong], true, "strong card should stay available on other owned land")
  _assert_eq(found[gameplay_rules.item_ids.free_rent], true, "free rent card should stay available on other owned land")
end

local function _test_item_equalize_cash()
  local g = _new_game()
  local user = g.players[1]
  local target = g.players[2]
  g:set_player_cash(user, 1000)
  g:set_player_cash(target, 9000)
  user.inventory:add({ id = 2011 })
  local res = executor.use_item(g, user, 2011, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "item_target_player", "equalize should open choice")
    local first = pending.options[1]
    choice_resolver.resolve(g, pending, { option_id = first.id })
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "equalize use ok")
  _assert_eq(user.cash, 5000, "equalize user cash")
  _assert_eq(target.cash, 5000, "equalize target cash")
end

local function _test_target_item_manual_direct_exec_and_duration()
  local g = _new_game()
  g.ui_port = support.build_ui_port({ wait_action_anim = true })
  local user = g.players[1]
  local target = g.players[2]
  g:set_player_cash(user, 1000)
  g:set_player_cash(target, 9000)
  user.inventory:add({ id = 2011 })

  local res = executor.use_item(g, user, 2011, {})
  assert(type(res) == "table" and res.waiting, "target item should open choice first")
  _open_choice(g, res.intent.choice_spec)
  local pending = _get_choice(g)
  assert(pending and pending.kind == "item_target_player", "pending choice kind")

  choice_resolver.resolve(g, pending, { option_id = target.id })
  _assert_eq(_get_choice(g), nil, "choice should be resolved directly without reopening")
  _assert_eq(user.cash, 5000, "manual target item should apply to user")
  _assert_eq(target.cash, 5000, "manual target item should apply to target")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "item_target_player", "target item should queue anim")
  _assert_eq(
    g.turn.action_anim.duration,
    gameplay_rules.action_anim_default_seconds or 1.0,
    "target item anim should use default duration"
  )
end

local function _test_item_executor_fallback_item_use_anim()
  local g = _new_game()
  g.ui_port = support.build_ui_port({ wait_action_anim = true })
  local p = g:current_player()
  p.inventory:add({ id = 2003 })

  local res = executor.use_item(g, p, 2003, { by_ai = true })
  assert(type(res) == "table" and res.action_anim, "fallback item anim should be marked")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "item_use", "fallback should queue item_use anim")
  _assert_eq(
    g.turn.action_anim.duration,
    gameplay_rules.action_anim_default_seconds or 1.0,
    "fallback item anim should use default duration"
  )
end

local function _test_item_executor_keeps_specific_anim_without_fallback()
  local g = _new_game()
  g.ui_port = support.build_ui_port({ wait_action_anim = true })
  local p = g:current_player()
  p.inventory:add({ id = 2005 })

  local res = executor.use_item(g, p, 2005, { by_ai = true })
  assert(type(res) == "table" and res.action_anim, "mine should return action anim marker")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "mine", "specific mine anim should not be replaced")
  _assert_eq(
    g.turn.action_anim.duration,
    gameplay_rules.action_anim_default_seconds or 1.0,
    "specific mine anim should use default duration"
  )
end

local function _test_item_phase_exposes_mine_in_pre_action()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.mine })

  local spec = assert(item_phase.build_choice_spec(g, p, "pre_action"), "mine should be offered in pre_action")
  local found = false
  for _, option in ipairs(spec.options) do
    if option.id == gameplay_rules.item_ids.mine then
      found = true
      break
    end
  end
  _assert_eq(found, true, "pre_action choice should include mine")
end

local function _test_roadblock_manual_choice_shows_seven_tiles_with_tile_names_only()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  local expected = roadblock.ui_candidates(g, p, 3)
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should open choice")

  local pending = res.intent.choice_spec
  assert(pending and pending.kind == "roadblock_target", "roadblock should open target choice")
  _assert_eq(#pending.options, 7, "manual roadblock should expose forward3/current/back3")
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
  _assert_eq(pending.options[4].id, current_idx, "slot4 should target current tile")

  choice_resolver.resolve(g, pending, { option_id = current_idx })
  _assert_eq(g.board:has_roadblock(current_idx), true, "manual roadblock should allow current tile placement")
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

local function _test_item_phase_select_remote_dice_consumes_immediately_and_locks_followup()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.remote_dice })

  local spec = assert(item_phase.build_choice_spec(g, p, "pre_action"), "item_phase should open when remote dice exists")
  local pending = _open_choice(g, spec)
  local before_count = support.inventory.count(p)
  _assert_eq(before_count, 1, "precondition inventory count")

  local res = choice_resolver.resolve(g, pending, {
    type = "choice_select",
    choice_id = pending.id,
    option_id = gameplay_rules.item_ids.remote_dice,
    actor_role_id = p.id,
  })
  assert(res and res.stay == true, "selecting remote dice should open follow-up choice")

  local after_pending = _get_choice(g)
  assert(after_pending and after_pending.kind == "remote_dice_value", "follow-up choice kind should be remote_dice_value")
  _assert_eq(support.inventory.count(p), 0, "slot item should be consumed immediately after slot select")
  _assert_eq(after_pending.allow_cancel, false, "follow-up choice should not allow cancel after consume")
  assert(after_pending.meta and after_pending.meta.item_preconsumed == true, "follow-up choice should mark preconsumed")
end

local function _test_preconsumed_followup_cancel_falls_back_to_first_option()
  local g = _new_game()
  local p = g:current_player()
  g.turn.item_phase_active = "pre_action"
  local pending = _open_choice(g, {
    kind = "remote_dice_value",
    title = "遥控骰子：选择点数",
    options = { { id = 4, label = "4" }, { id = 2, label = "2" } },
    allow_cancel = false,
    meta = {
      player_id = p.id,
      item_id = gameplay_rules.item_ids.remote_dice,
      dice_count = 1,
      item_preconsumed = true,
    },
  })

  local res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
    actor_role_id = p.id,
  })
  _assert_eq(res and res.stay, false, "preconsumed follow-up should resolve instead of staying")
  _assert_eq(g.turn.pending_choice, nil, "preconsumed follow-up cancel should not keep choice")
  assert(p.status.pending_remote_dice and p.status.pending_remote_dice.values, "remote dice value should still be applied")
  _assert_eq(p.status.pending_remote_dice.values[1], 4, "cancel should fallback to first option value")
end

local function _test_tax_prompt_cancel_maps_to_skip_and_executes_pay_tax()
  local g = _new_game()
  local p = g:current_player()
  g:set_player_cash(p, 1000)
  local pending = _open_choice(g, {
    kind = "tax_card_prompt",
    title = "是否使用免税卡",
    options = {
      { id = "use", label = "使用" },
      { id = "skip", label = "不用" },
    },
    allow_cancel = true,
    cancel_label = "不用",
    meta = {
      player_id = p.id,
    },
  })

  local res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
    actor_role_id = p.id,
  })

  _assert_eq(res and res.stay, false, "tax prompt cancel should resolve immediately")
  _assert_eq(g.turn.pending_choice, nil, "tax prompt cancel should clear pending choice")
  _assert_eq(p.cash, 500, "tax prompt cancel should pay tax through skip path")
end

return {
  name = "item",
  tests = {
    { name = "monster_card", run = _test_monster_card },
    { name = "missile_card", run = _test_missile_card },
    { name = "demolish_card_no_target_returns_false", run = _test_demolish_card_no_target_returns_false },
    { name = "item_phase_filters_unusable_target_items", run = _test_item_phase_filters_unusable_target_items },
    { name = "item_phase_keeps_demolish_when_target_exists", run = _test_item_phase_keeps_demolish_when_target_exists },
    { name = "item_phase_hides_rent_cards_on_owned_land", run = _test_item_phase_hides_rent_cards_on_owned_land },
    { name = "item_phase_keeps_rent_cards_on_other_owned_land", run = _test_item_phase_keeps_rent_cards_on_other_owned_land },
    { name = "item_equalize_cash", run = _test_item_equalize_cash },
    { name = "target_item_manual_direct_exec_and_duration", run = _test_target_item_manual_direct_exec_and_duration },
    { name = "item_executor_fallback_item_use_anim", run = _test_item_executor_fallback_item_use_anim },
    { name = "item_executor_keeps_specific_anim_without_fallback", run = _test_item_executor_keeps_specific_anim_without_fallback },
    { name = "item_phase_exposes_mine_in_pre_action", run = _test_item_phase_exposes_mine_in_pre_action },
    {
      name = "roadblock_manual_choice_shows_seven_tiles_with_tile_names_only",
      run = _test_roadblock_manual_choice_shows_seven_tiles_with_tile_names_only,
    },
    { name = "roadblock_manual_choice_allows_current_tile", run = _test_roadblock_manual_choice_allows_current_tile },
    { name = "roadblock_ai_uses_auto_candidates_only", run = _test_roadblock_ai_uses_auto_candidates_only },
    {
      name = "item_phase_select_remote_dice_consumes_immediately_and_locks_followup",
      run = _test_item_phase_select_remote_dice_consumes_immediately_and_locks_followup,
    },
    {
      name = "preconsumed_followup_cancel_falls_back_to_first_option",
      run = _test_preconsumed_followup_cancel_falls_back_to_first_option,
    },
    {
      name = "tax_prompt_cancel_maps_to_skip_and_executes_pay_tax",
      run = _test_tax_prompt_cancel_maps_to_skip_and_executes_pay_tax,
    },
  },
}
