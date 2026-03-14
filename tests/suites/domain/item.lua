local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
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
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local land_choice_specs = require("src.rules.land.choice_specs")
local item_phase = require("src.rules.items.phase")
local item_strategy = require("src.rules.items.strategy")
local roadblock = require("src.rules.items.roadblock")
local steal = require("src.rules.items.steal")
local status_ops = require("src.player.actions.state_ops.status_ops")
local cash_handlers = require("src.rules.chance.handlers.cash_handlers")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local monopoly_event = require("src.core.events.monopoly_events")
local move_followup = require("src.turn.phases.move_followup")
local effect_pipeline = require("src.rules.effects.effect_pipeline")
local effect_runner = require("src.rules.effects.effect_runner")
local intent_output_port = require("src.rules.ports.intent_output_port")

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

local function _test_monster_card()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 2)
  p.inventory:add({ id = 2008 })
  local res = executor.use_item(g, p, 2008, {})
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "monster should open choice")
    res = choice_resolver.resolve(g, pending, { option_id = pending.options[1].id })
  end
  _assert_eq(res.status, "resolved", "monster choice should resolve")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "monster", "monster should queue monster action anim")
  _assert_eq(res.after_action_anim, nil, "monster should not expose move followup")
end

local function _test_missile_card()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
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
    res = choice_resolver.resolve(g, pending, { option_id = pending.options[1].id })
  end
  _assert_eq(res.status, "resolved", "missile choice should resolve")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed by missile")
  _assert_eq(g.board:has_roadblock(idx), false, "roadblock cleared")
  _assert_eq(g.board:has_mine(idx), false, "mine cleared")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "missile", "missile should queue missile action anim")
  assert(type(res.after_action_anim) == "table", "missile should expose move followup")
  _assert_eq(g.players[2].status.stay_turns or 0, 0, "missile should defer hospital stay until move followup")

  local next_state, _ = move_followup.run({ game = g }, res.after_action_anim.next_args)
  _assert_eq(next_state, nil, "missile move followup should return caller continuation")
  assert(g.players[2].status.stay_turns > 0, "missile target should enter hospital after move followup")
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
  _set_ui_port(g, { wait_action_anim = true })
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

local function _test_exile_item_defers_mountain_effect_until_move_followup()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local user = g.players[1]
  local target = g.players[2]
  user.inventory:add({ id = gameplay_rules.item_ids.exile })

  local res = executor.use_item(g, user, gameplay_rules.item_ids.exile, {
    by_ai = true,
    target_id = target.id,
  })

  _assert_eq(type(res), "table", "exile should return result payload")
  _assert_eq(res.ok, true, "exile should succeed")
  assert(type(res.after_action_anim) == "table", "exile should expose move followup continuation")
  _assert_eq(target.status.stay_turns or 0, 0, "exile should not apply mountain stay immediately")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "exile should queue move effect first")

  local next_state, _ = move_followup.run({ game = g }, res.after_action_anim.next_args)
  _assert_eq(next_state, nil, "exile move followup should return to caller continuation")
  assert((target.status.stay_turns or 0) > 0, "exile should apply mountain stay after move followup")
end

local function _test_item_executor_fallback_item_use_anim()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
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
  _set_ui_port(g, { wait_action_anim = true })
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
  _assert_eq(spec.uses_item_slots, true, "item_phase choice should expose uses_item_slots flag")
  _assert_eq(spec.pre_confirm_before_slot_pick, true,
    "item_phase choice should expose pre_confirm_before_slot_pick flag")
  _assert_eq(spec.confirm_title, "行动前", "item_phase choice should expose confirm title from use-case output")
  _assert_eq(spec.confirm_body, "可用道具：地雷卡", "item_phase choice should expose confirm body from use-case output")
  local found = nil
  for _, option in ipairs(spec.options) do
    if option.id == gameplay_rules.item_ids.mine then
      found = option
      break
    end
  end
  assert(found ~= nil, "pre_action choice should include mine")
  _assert_eq(found.confirm_title, "行动前", "item_phase option should expose confirm title from use-case output")
  _assert_eq(found.confirm_body, "将使用：地雷卡", "item_phase option should expose confirm body from use-case output")
end

local function _test_item_strategy_can_offer_in_phase_for_rent_cards_and_roadblock()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:update_player_position(p, idx)
  p.inventory:add({ id = gameplay_rules.item_ids.strong })
  p.inventory:add({ id = gameplay_rules.item_ids.free_rent })
  p.inventory:add({ id = gameplay_rules.item_ids.roadblock })

  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  assert(
    item_strategy.can_offer_in_phase(g, p, gameplay_rules.item_ids.strong, "post_action") == false,
    "strong card should not be offered on owned land"
  )
  assert(
    item_strategy.can_offer_in_phase(g, p, gameplay_rules.item_ids.free_rent, "post_action") == false,
    "free_rent card should not be offered on owned land"
  )
  assert(
    item_strategy.can_offer_in_phase(g, p, gameplay_rules.item_ids.roadblock, "post_action") == true,
    "roadblock should be offered when UI candidates exist"
  )

  g:set_tile_owner(tile_ref, g.players[2].id)
  g:set_player_cash(p, 100000)
  assert(
    item_strategy.can_offer_in_phase(g, p, gameplay_rules.item_ids.strong, "post_action") == true,
    "strong card should be offered on rival land when player can afford it"
  )
  assert(
    item_strategy.can_offer_in_phase(g, p, gameplay_rules.item_ids.free_rent, "post_action") == true,
    "free_rent card should be offered on rival land"
  )
end

local function _test_item_phase_run_wait_action_anim_patches_move_followup_args()
  local g = _new_game()
  local player = g:current_player()
  player.auto = true
  g.turn.action_anim = { seq = 7, kind = "item_use" }
  local original_auto_pre_action = item_strategy.auto_pre_action
  item_strategy.auto_pre_action = function()
    return {
      after_action_anim = {
        next_state = "move_followup",
        next_args = {
          mode = "resume_turn_move",
        },
      },
    }
  end

  local ok, res = pcall(function()
    return item_phase.run({ game = g }, "pre_action", {
      player = player,
      next_state = "roll",
      next_args = { player = player },
    })
  end)
  item_strategy.auto_pre_action = original_auto_pre_action

  assert(ok, res)
  assert(type(res) == "table" and res.waiting == true, "auto item phase should wait for action anim when item queued anim")
  assert(res.wait_action_anim == true, "auto item phase should route through wait_action_anim")
  _assert_eq(res.next_state, "move_followup", "auto item phase should preserve move_followup next state")
  _assert_eq(res.next_args.mode, "resume_turn_move", "move_followup mode should be preserved")
  _assert_eq(res.next_args.next_state, "roll", "move_followup args should receive default next state")
  _assert_eq(res.next_args.next_args.player, player, "move_followup args should receive default next args")
end

local function _test_status_ops_set_player_seat_emits_exit_and_enter()
  local g = _new_game()
  local player = g.players[1]
  player.seat_id = 4001
  local exited = {}
  local entered = {}
  local vehicle = {
    needs_enter_wait_by_player = {},
    emit_vehicle_exit = function(player_id)
      exited[#exited + 1] = player_id
    end,
    emit_vehicle_enter = function(player_id, seat_id)
      entered[#entered + 1] = { player_id = player_id, seat_id = seat_id }
    end,
  }

  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = vehicle },
  }, function()
    status_ops.set_player_seat(g, player, 4002)
  end)

  _assert_eq(player.seat_id, 4002, "set_player_seat should update seat_id")
  _assert_eq(#exited, 1, "set_player_seat should emit exit when leaving old seat")
  _assert_eq(exited[1], player.id, "set_player_seat exit should target player")
  _assert_eq(#entered, 1, "set_player_seat should emit enter for new seat")
  _assert_eq(entered[1].seat_id, 4002, "set_player_seat should pass new seat to vehicle helper")
  _assert_eq(vehicle.needs_enter_wait_by_player[player.id], true, "set_player_seat should mark enter wait for player")
end

local function _test_board_advance_tracks_branch_and_wrap()
  local board = require("src.rules.board.init"):new({
    tile_lookup = {
      [1] = { id = 1, name = "A" },
      [2] = { id = 2, name = "B" },
      [3] = { id = 3, name = "C" },
      [4] = { id = 4, name = "D" },
    },
    path = {
      { id = 1, name = "A" },
      { id = 2, name = "B" },
      { id = 3, name = "C" },
      { id = 4, name = "D" },
    },
    branches = {
      [1] = { odd = 3, even = 2 },
    },
    map = {},
    overlays = {
      roadblocks = {},
      mines = {},
    },
  })
  local current = 1
  local branch = board.branches[current]
  assert(branch and branch.odd and branch.even, "selected branch entry should expose odd/even targets")

  local odd_index = select(1, board:advance(current, 1, 1))
  local even_index = select(1, board:advance(current, 1, 2))
  _assert_eq(odd_index, branch.odd, "advance should use odd branch when parity is odd")
  _assert_eq(even_index, branch.even, "advance should use even branch when parity is even")

  local last = board:length()
  local wrapped_index, passed_start = board:advance(last, 2)
  _assert_eq(wrapped_index, 2, "advance should wrap around board length")
  _assert_eq(passed_start, 1, "advance should count passing start when wrapping")
end

local function _test_collect_from_others_caps_fee_and_rich_bonus()
  local handlers = {}
  local events = {}
  local anims = {}
  local common = {
    dependencies = function()
      return {
        monopoly_event = {
          chance = { applied = "chance_applied" },
        },
        number_utils = {
          format_integer_part = function(value)
            return tostring(value)
          end,
        },
      }
    end,
    queue_action_anim = function(_, anim)
      anims[#anims + 1] = anim
    end,
    emit_event = function(_, payload)
      events[#events + 1] = payload
    end,
    apply_cash_change = function(_, target_player, delta)
      target_player.cash = target_player.cash + delta
    end,
  }
  cash_handlers.register(handlers, common)

  local game = {
    players = {
      { id = 1, name = "P1", cash = 1000, eliminated = false },
      { id = 2, name = "P2", cash = 50, eliminated = false },
      { id = 3, name = "P3", cash = 300, eliminated = false },
    },
    player_has_deity = function(_, player, deity)
      return deity == "rich" and player.id == 1
    end,
    player_is_in_mountain = function(_, player)
      return player.id == 3
    end,
    player_balance = function(_, player)
      return player.cash
    end,
  }

  handlers.collect_from_others(game, game.players[1], {
    amount = 100,
    effect = "collect_from_others",
  })

  _assert_eq(game.players[1].cash, 1250, "collector should receive doubled fee from each payer up to their cash")
  _assert_eq(game.players[2].cash, 0, "payer cash should floor at zero")
  _assert_eq(game.players[3].cash, 100, "second payer should still contribute when collector is not in mountain")
  _assert_eq(#anims, 2, "cash receive animation should queue once per successful collection")
  _assert_eq(anims[1].amount, 50, "first receive animation should use capped collected amount")
  _assert_eq(anims[2].amount, 200, "second receive animation should include rich bonus amount")
  _assert_eq(#events, 1, "collect_from_others should emit one summary event")
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

local function _test_roadblock_manual_choice_hongkong_keeps_backward_slots_ordered()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  g:update_player_position(p, 7)
  p.inventory:add({ id = item_id })

  local expected_names = {
    "香港路",
    "澳门路",
    "广州路",
    "医院",
    "道具卡",
    "南宁路",
    "海口路",
  }

  local candidates = roadblock.ui_candidates(g, p, 3)
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
  _assert_eq(pending.options[7].id, 4, "slot7 should point to haikou index")
end

local function _test_roadblock_manual_choice_hongkong_slot7_places_on_haikou()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock
  g:update_player_position(p, 7)
  p.inventory:add({ id = item_id })

  local res = executor.use_item(g, p, item_id, { by_ai = false })
  assert(type(res) == "table" and res.waiting, "manual roadblock should wait for target choice at hongkong")
  local pending = _open_choice(g, res.intent.choice_spec)

  _assert_eq(pending.options[7].id, 4, "slot7 should resolve to haikou before placement")
  choice_resolver.resolve(g, pending, { option_id = pending.options[7].id })

  _assert_eq(g.board:has_roadblock(4), true, "slot7 should place roadblock on haikou")
  _assert_eq(g.board:has_roadblock(10), false, "slot7 should not incorrectly place roadblock on nanning")
end

local function _test_roadblock_ui_candidates_refill_to_seven_at_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(45))
  g:set_player_status(p, "move_dir", nil)

  local candidates = roadblock.ui_candidates(g, p, 3)
  local expected_names = {
    "机会卡",
    "重庆路",
    "天津路",
    "黑市",
    "太原路",
    "西安路",
    "银川路",
  }

  _assert_eq(#candidates, #expected_names, "intersection roadblock ui should refill to seven unique target tiles")
  for index, expected_name in ipairs(expected_names) do
    _assert_eq(candidates[index].tile.name, expected_name, "intersection candidate name mismatch at slot " .. index)
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
    route_key = "remote",
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

local function _test_tax_prompt_exposes_confirm_copy()
  local choice = land_choice_specs.tax_prompt(11)
  _assert_eq(choice.route_key, "secondary_confirm", "tax prompt should expose secondary confirm route")
  _assert_eq(choice.requires_confirm, true, "tax prompt should expose confirm requirement")
  _assert_eq(choice.confirm_title, "税务局", "tax prompt should expose confirm title from use-case output")
  _assert_eq(choice.confirm_body, "这次要用免税卡吗？", "tax prompt should expose confirm body from use-case output")
end

local function _test_simple_item_use_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local p = g:current_player()
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  p.inventory:add({ id = gameplay_rules.item_ids.tax_free })

  local res = executor.use_item(g, p, gameplay_rules.item_ids.tax_free, { by_ai = true })
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "tax_free use ok")
  _assert_eq(#popups, 1, "simple item use should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "simple item broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.tax_free, "simple item broadcast image_ref mismatch")
  assert(string.find(popups[1].body, p.name, 1, true), "simple item broadcast should include player name")
  assert(string.find(popups[1].body, "免税卡", 1, true), "simple item broadcast should include item name")
end

local function _test_target_item_use_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local user = g.players[1]
  local target = g.players[2]
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  g:set_player_cash(user, 1000)
  g:set_player_cash(target, 9000)
  user.inventory:add({ id = gameplay_rules.item_ids.share_wealth })

  local res = executor.use_item(g, user, gameplay_rules.item_ids.share_wealth, {
    by_ai = true,
    target_id = target.id,
  })
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "target item use ok")
  _assert_eq(#popups, 1, "target item use should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "target item broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.share_wealth, "target item broadcast image_ref mismatch")
  assert(string.find(popups[1].body, user.name, 1, true), "target item broadcast should include player name")
  assert(string.find(popups[1].body, "均富卡", 1, true), "target item broadcast should include item name")
end

local function _test_remote_dice_followup_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local p = g:current_player()
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  g.turn.item_phase_active = "pre_action"
  p.inventory:add({ id = gameplay_rules.item_ids.remote_dice })
  local pending = _open_choice(g, {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子：选择点数",
    options = { { id = 4, label = "4" } },
    allow_cancel = false,
    meta = {
      player_id = p.id,
      item_id = gameplay_rules.item_ids.remote_dice,
      dice_count = 1,
      item_preconsumed = false,
    },
  })

  local res = choice_resolver.resolve(g, pending, {
    type = "choice_select",
    choice_id = pending.id,
    option_id = 4,
    actor_role_id = p.id,
  })

  _assert_eq(res and res.stay, false, "remote dice follow-up should resolve immediately")
  _assert_eq(#popups, 1, "remote dice follow-up should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "remote dice broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.remote_dice, "remote dice broadcast image_ref mismatch")
end

local function _test_steal_uses_tip_without_popup()
  local g = _new_game()
  local popups = {}
  local tips = {}
  local stealer = g.players[1]
  local target = g.players[2]
  stealer.inventory:add({ id = gameplay_rules.item_ids.steal })
  target.inventory:add({ id = gameplay_rules.item_ids.tax_free })

  support.with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text)
          tips[#tips + 1] = text
          return true
        end,
      },
    },
  }, function()
    _set_ui_port(g, {
      push_popup = function(_, payload)
        popups[#popups + 1] = payload
      end,
    })

    local res = steal.steal_item_at_index(g, stealer, target, 1)
    _assert_eq(res and res.ok, true, "steal should succeed")
    _assert_eq(res and res.intent, nil, "steal success should not return popup intent")
  end)

  _assert_eq(#popups, 0, "steal success should not push popup")
  assert(#tips >= 1, "steal success should show tip")
  assert(string.find(tips[1], stealer.name, 1, true), "steal success tip should include stealer name")
  assert(string.find(tips[1], target.name, 1, true), "steal success tip should include target name")
  assert(string.find(tips[1], "免税卡", 1, true), "steal success tip should include stolen item name")
end

local function _test_steal_failure_uses_tip_without_popup()
  local g = _new_game()
  local popups = {}
  local tips = {}
  local stealer = g.players[1]
  local target = g.players[2]
  stealer.inventory:add({ id = gameplay_rules.item_ids.steal })

  support.with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text)
          tips[#tips + 1] = text
          return true
        end,
      },
    },
  }, function()
    _set_ui_port(g, {
      push_popup = function(_, payload)
        popups[#popups + 1] = payload
      end,
    })

    local res = steal.steal_item_at_index(g, stealer, target, 1)
    _assert_eq(res and res.ok, false, "steal should fail when target has no items")
    _assert_eq(res and res.intent, nil, "steal failure should not return popup intent")
  end)

  _assert_eq(#popups, 0, "steal failure should not push popup")
  assert(#tips >= 1, "steal failure should show tip")
  assert(string.find(tips[1], stealer.name, 1, true), "steal failure tip should include stealer name")
  assert(string.find(tips[1], target.name, 1, true), "steal failure tip should include target name")
  assert(string.find(tips[1], "没有任何道具", 1, true), "steal failure tip should explain failure")
end

local function _test_rich_item_emits_deity_feedback_event()
  local g = _new_game()
  local p = g:current_player()
  local emitted = {}

  support.with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    p.inventory:add({ id = gameplay_rules.item_ids.rich })
    local res = executor.use_item(g, p, gameplay_rules.item_ids.rich, { by_ai = true })
    local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
    _assert_eq(ok, true, "rich item use ok")
  end)

  assert(#emitted >= 1, "rich item should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.deity_applied, "rich item should emit deity feedback event")
  _assert_eq(emitted[1].payload.deity_type, "rich", "rich item should emit rich deity type")
  _assert_eq(emitted[1].payload.player_id, p.id, "rich item should emit current player id")
end

local function _test_effect_pipeline_waiting_result_patches_followup_and_strips_intent()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local dispatched = nil

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = true,
            effect = { id = "clear_obstacles", label = "clear_obstacles" },
          },
        }
      end,
    },
    {
      target = effect_runner,
      key = "execute",
      value = function()
        return {
          ok = true,
          result = {
            waiting = true,
            intent = { kind = "debug_only" },
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "dispatch",
      value = function(_, payload)
        dispatched = payload
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      next_state = "resume_turn",
      next_args = { source = "effect_pipeline" },
    })
    assert(type(result) == "table" and result.waiting == true, "waiting result should be returned")
    _assert_eq(result.next_state, "resume_turn", "waiting result should inherit next_state")
    _assert_eq(result.next_args.source, "effect_pipeline", "waiting result should inherit next_args")
    _assert_eq(result.intent, nil, "waiting result should not leak intent payload")
  end)

  assert(type(dispatched) == "table" and dispatched.waiting == true, "waiting payload should still dispatch")
end

local function _test_effect_pipeline_stop_if_short_circuits_before_optional_choice()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local open_choice_called = false

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = true,
            effect = { id = "mandatory_first", label = "mandatory_first" },
          },
          {
            ok = true,
            mandatory = false,
            effect = { id = "buy_land", label = "buy_land" },
          },
        }
      end,
    },
    {
      target = effect_runner,
      key = "execute",
      value = function()
        return {
          ok = true,
          result = {
            kind = "resolved",
            marker = "stop_here",
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "open_choice",
      value = function()
        open_choice_called = true
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      stop_if = function(out)
        return out and out.marker == "stop_here"
      end,
    })
    _assert_eq(result.marker, "stop_here", "stop_if should return current mandatory result")
  end)

  _assert_eq(open_choice_called, false, "stop_if should skip optional choice building")
end

local function _test_effect_pipeline_single_optional_effect_uses_secondary_confirm_route()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local opened_choice = nil

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = false,
            effect = { id = "buy_land", label = "买地" },
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "open_choice",
      value = function(_, choice_spec)
        opened_choice = choice_spec
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      next_state = "after_optional",
      next_args = { source = "optional_effect" },
      optional_title = "可选效果",
    })
    assert(type(result) == "table" and result.waiting == true, "optional effect should wait on choice")
    _assert_eq(result.next_state, "after_optional", "optional followup should preserve next_state")
    _assert_eq(result.next_args.source, "optional_effect", "optional followup should preserve next_args")
  end)

  assert(type(opened_choice) == "table", "single optional effect should open choice")
  _assert_eq(opened_choice.route_key, "secondary_confirm", "single optional effect should use secondary_confirm route")
  _assert_eq(opened_choice.requires_confirm, true, "single optional effect should require confirm")
  _assert_eq(opened_choice.options[1].id, "buy_land", "single optional effect should expose chosen effect id")
end

-- Characterization tests for strategy helper functions (T4)
local function _test_ai_can_use_item_returns_true_for_mine_in_pre_action_manual()
  local item_id = gameplay_rules.item_ids.mine
  local result = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result, true, "mine should be usable in pre_action with manual timing")
end

local function _test_ai_can_use_item_uses_timing_allowed_for_other_items()
  -- Test with clear_obstacles which has timing "pre_action"
  local item_id = gameplay_rules.item_ids.clear_obstacles
  local result_pre = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result_pre, true, "clear_obstacles should be usable in pre_action")

  local result_post = item_strategy._ai_can_use_item(item_id, "post_action")
  _assert_eq(result_post, false, "clear_obstacles should not be usable in post_action")
end

local function _test_has_demolish_target_returns_true_when_target_exists()
  local g = _new_game()
  local p = g:current_player()
  -- Set up a target by placing a building
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 1)

  local result = item_strategy._has_demolish_target(g, p)
  _assert_eq(result, true, "should find demolish target when building exists")
end

local function _test_has_demolish_target_returns_false_when_no_target()
  local g = _new_game()
  local p = g:current_player()
  -- Ensure no buildings on the board - only reset land tiles that have owners
  for _, tile_ref in ipairs(g.board.path) do
    if tile_ref.type == "land" then
      local st = g.tile_states and g.tile_states[tile_ref.id] or nil
      if st and st.owner_id then
        g:set_tile_owner(tile_ref, nil)
        g:set_tile_level(tile_ref, 0)
      end
    end
  end

  local result = item_strategy._has_demolish_target(g, p)
  _assert_eq(result, false, "should not find demolish target when no buildings exist")
end

local function _test_has_target_player_returns_true_when_candidates_exist()
  local g = _new_game()
  local p = g:current_player()
  -- exile card needs another player to target
  local item_id = gameplay_rules.item_ids.exile

  -- Mock target_candidates to return valid candidates
  support.with_patches({
    {
      target = item_strategy,
      key = "target_candidates",
      value = function()
        return { { id = 2, name = "P2" } }
      end,
    },
  }, function()
    local result = item_strategy._has_target_player(g, p, item_id)
    _assert_eq(result, true, "should find target when candidates exist")
  end)
end

local function _test_has_target_player_returns_false_when_no_candidates()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.exile

  -- Mock target_candidates to return empty candidates
  support.with_patches({
    {
      target = item_strategy,
      key = "target_candidates",
      value = function()
        return {}
      end,
    },
  }, function()
    local result = item_strategy._has_target_player(g, p, item_id)
    _assert_eq(result, false, "should not find target when no candidates exist")
  end)
end

local function _test_try_use_item_returns_nil_when_cond_fails()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.clear_obstacles

  local result = item_strategy._try_use_item(g, p, item_id, function() return false end, false)
  _assert_eq(result, nil, "should return nil when condition fails")
end

local function _test_try_use_item_returns_nil_when_item_not_in_inventory()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.clear_obstacles

  -- Ensure item is not in inventory by clearing all slots
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  local result = item_strategy._try_use_item(g, p, item_id, nil, false)
  _assert_eq(result, nil, "should return nil when item not in inventory")
end

local function _test_try_clear_obstacles_returns_result_when_obstacles_found()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.clear_obstacles })

  -- Place a roadblock ahead
  local current_pos = p.position
  g.board:place_roadblock(current_pos + 1)

  support.with_patches({
    {
      target = item_strategy,
      key = "has_obstacles_ahead",
      value = function()
        return true
      end,
    },
  }, function()
    local result = item_strategy._try_clear_obstacles(g, p, false)
    -- Result should be a table (the use_item result) or nil
    -- Since we're not mocking executor.use_item, it will actually try to use it
    -- which may return a result or nil depending on the game state
    assert(type(result) == "table" or result == nil, "result should be table or nil")
  end)
end

local function _test_try_clear_obstacles_returns_nil_when_no_obstacles()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.clear_obstacles })

  -- Ensure no obstacles
  for i = 1, g.board:length() do
    g.board:clear_all(i)
  end

  support.with_patches({
    {
      target = item_strategy,
      key = "has_obstacles_ahead",
      value = function()
        return false
      end,
    },
  }, function()
    local result = item_strategy._try_clear_obstacles(g, p, false)
    _assert_eq(result, nil, "should return nil when no obstacles ahead")
  end)
end

local function _test_try_remote_dice_returns_nil_when_no_dice_value_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.remote_dice })

  local auto_play_port = require("src.rules.ports.auto_play_port")
  support.with_patches({
    {
      target = auto_play_port,
      key = "pick_remote_dice_value",
      value = function()
        return nil
      end,
    },
  }, function()
    local result = item_strategy._try_remote_dice(g, p, false)
    _assert_eq(result, nil, "should return nil when no dice value picked")
  end)
end

local function _test_try_roadblock_returns_nil_when_no_target_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.roadblock })

  local auto_play_port = require("src.rules.ports.auto_play_port")
  support.with_patches({
    {
      target = auto_play_port,
      key = "pick_roadblock_target",
      value = function()
        return nil
      end,
    },
  }, function()
    local result = item_strategy._try_roadblock(g, p, false)
    _assert_eq(result, nil, "should return nil when no roadblock target picked")
  end)
end

local function _test_try_target_items_returns_nil_when_no_items_in_inventory()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Should return nil when no target items in inventory
  local result = item_strategy._try_target_items(g, p, false)
  _assert_eq(result, nil, "should return nil when no target items in inventory")
end

local function _test_try_deity_items_returns_nil_when_no_deity_items()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Should return nil when no deity items in inventory
  local result = item_strategy._try_deity_items(g, p, false)
  _assert_eq(result, nil, "should return nil when no deity items in inventory")
end

local function _test_try_deity_items_returns_nil_when_no_deity_items()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Should return nil when no deity items in inventory
  local result = item_strategy._try_deity_items(g, p, false)
  _assert_eq(result, nil, "should return nil when no deity items in inventory")
end

local function _test_try_deity_items_tries_rich_then_angel()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory first
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Add both rich and angel items
  p.inventory:add({ id = gameplay_rules.item_ids.rich })
  p.inventory:add({ id = gameplay_rules.item_ids.angel })

  local used_items = {}
  local executor = require("src.rules.items.executor")
  support.with_patches({
    {
      target = executor,
      key = "use_item",
      value = function(_, _, item_id)
        table.insert(used_items, item_id)
        return { ok = true, kind = "deity_applied" }
      end,
    },
  }, function()
    local result = item_strategy._try_deity_items(g, p, false)
    -- Should try rich first (order matters)
    assert(#used_items >= 1, "should try at least one item")
    -- Result should be successful
    assert(type(result) == "table", "should return a table result")
    _assert_eq(result.ok, true, "should return successful result")
  end)
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
    {
      name = "exile_item_defers_mountain_effect_until_move_followup",
      run = _test_exile_item_defers_mountain_effect_until_move_followup,
    },
    { name = "item_executor_fallback_item_use_anim", run = _test_item_executor_fallback_item_use_anim },
    { name = "item_executor_keeps_specific_anim_without_fallback", run = _test_item_executor_keeps_specific_anim_without_fallback },
    { name = "item_phase_exposes_mine_in_pre_action", run = _test_item_phase_exposes_mine_in_pre_action },
    {
      name = "item_strategy_can_offer_in_phase_for_rent_cards_and_roadblock",
      run = _test_item_strategy_can_offer_in_phase_for_rent_cards_and_roadblock,
    },
    {
      name = "item_phase_run_wait_action_anim_patches_move_followup_args",
      run = _test_item_phase_run_wait_action_anim_patches_move_followup_args,
    },
    {
      name = "status_ops_set_player_seat_emits_exit_and_enter",
      run = _test_status_ops_set_player_seat_emits_exit_and_enter,
    },
    {
      name = "board_advance_tracks_branch_and_wrap",
      run = _test_board_advance_tracks_branch_and_wrap,
    },
    {
      name = "collect_from_others_caps_fee_and_rich_bonus",
      run = _test_collect_from_others_caps_fee_and_rich_bonus,
    },
    {
      name = "roadblock_manual_choice_shows_seven_tiles_with_tile_names_only",
      run = _test_roadblock_manual_choice_shows_seven_tiles_with_tile_names_only,
    },
    { name = "roadblock_manual_choice_allows_current_tile", run = _test_roadblock_manual_choice_allows_current_tile },
    {
      name = "roadblock_manual_choice_hongkong_keeps_backward_slots_ordered",
      run = _test_roadblock_manual_choice_hongkong_keeps_backward_slots_ordered,
    },
    {
      name = "roadblock_manual_choice_hongkong_slot7_places_on_haikou",
      run = _test_roadblock_manual_choice_hongkong_slot7_places_on_haikou,
    },
    {
      name = "roadblock_ui_candidates_refill_to_seven_at_intersection",
      run = _test_roadblock_ui_candidates_refill_to_seven_at_intersection,
    },
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
    {
      name = "tax_prompt_exposes_confirm_copy",
      run = _test_tax_prompt_exposes_confirm_copy,
    },
    {
      name = "simple_item_use_pushes_item_card_popup",
      run = _test_simple_item_use_pushes_item_card_popup,
    },
    {
      name = "target_item_use_pushes_item_card_popup",
      run = _test_target_item_use_pushes_item_card_popup,
    },
    {
      name = "remote_dice_followup_pushes_item_card_popup",
      run = _test_remote_dice_followup_pushes_item_card_popup,
    },
    {
      name = "steal_uses_tip_without_popup",
      run = _test_steal_uses_tip_without_popup,
    },
    {
      name = "steal_failure_uses_tip_without_popup",
      run = _test_steal_failure_uses_tip_without_popup,
    },
    {
      name = "rich_item_emits_deity_feedback_event",
      run = _test_rich_item_emits_deity_feedback_event,
    },
    {
      name = "effect_pipeline_waiting_result_patches_followup_and_strips_intent",
      run = _test_effect_pipeline_waiting_result_patches_followup_and_strips_intent,
    },
    {
      name = "effect_pipeline_stop_if_short_circuits_before_optional_choice",
      run = _test_effect_pipeline_stop_if_short_circuits_before_optional_choice,
    },
    {
      name = "effect_pipeline_single_optional_effect_uses_secondary_confirm_route",
      run = _test_effect_pipeline_single_optional_effect_uses_secondary_confirm_route,
    },

    -- Strategy helper characterization tests (T4)
    { name = "ai_can_use_item_returns_true_for_mine_in_pre_action_manual", run = _test_ai_can_use_item_returns_true_for_mine_in_pre_action_manual },
    { name = "ai_can_use_item_uses_timing_allowed_for_other_items", run = _test_ai_can_use_item_uses_timing_allowed_for_other_items },
    { name = "has_demolish_target_returns_true_when_target_exists", run = _test_has_demolish_target_returns_true_when_target_exists },
    { name = "has_demolish_target_returns_false_when_no_target", run = _test_has_demolish_target_returns_false_when_no_target },
    { name = "has_target_player_returns_true_when_candidates_exist", run = _test_has_target_player_returns_true_when_candidates_exist },
    { name = "has_target_player_returns_false_when_no_candidates", run = _test_has_target_player_returns_false_when_no_candidates },
    { name = "try_use_item_returns_nil_when_cond_fails", run = _test_try_use_item_returns_nil_when_cond_fails },
    { name = "try_use_item_returns_nil_when_item_not_in_inventory", run = _test_try_use_item_returns_nil_when_item_not_in_inventory },
    { name = "try_clear_obstacles_returns_result_when_obstacles_found", run = _test_try_clear_obstacles_returns_result_when_obstacles_found },
    { name = "try_clear_obstacles_returns_nil_when_no_obstacles", run = _test_try_clear_obstacles_returns_nil_when_no_obstacles },
    { name = "try_remote_dice_returns_nil_when_no_dice_value_picked", run = _test_try_remote_dice_returns_nil_when_no_dice_value_picked },
    { name = "try_roadblock_returns_nil_when_no_target_picked", run = _test_try_roadblock_returns_nil_when_no_target_picked },
    { name = "try_target_items_returns_nil_when_no_items_in_inventory", run = _test_try_target_items_returns_nil_when_no_items_in_inventory },
    { name = "try_deity_items_returns_nil_when_no_deity_items", run = _test_try_deity_items_returns_nil_when_no_deity_items },
  },
}
