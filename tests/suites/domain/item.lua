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
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local land_choice_specs = require("src.rules.land.choice_specs")
local item_phase = require("src.rules.items.phase")
local item_strategy = require("src.rules.items.strategy")
local steal = require("src.rules.items.steal")
local status_ops = require("src.player.actions.state_ops.status_ops")
local cash_handlers = require("src.rules.chance.handlers.cash_handlers")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local monopoly_event = require("src.core.events.monopoly_events")
local move_followup = require("src.turn.phases.move_followup")

local function _find_option_id_by_label(choice, label)
  for _, option in ipairs(choice and choice.options or {}) do
    if option.label == label then
      return option.id
    end
  end
  return nil
end

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
  _assert_eq(
    res.after_action_anim.next_args.log_entries[1],
    p.name .. " 发射导弹轰炸 " .. tile_ref.name .. "，建筑被摧毁，1 名玩家送医",
    "missile should defer main strike log until move followup"
  )
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
  p.inventory:add({ id = item_ids.strong })
  p.inventory:add({ id = item_ids.free_rent })

  local spec = item_phase.build_choice_spec(g, p, "post_action")
  _assert_eq(spec, nil, "owned land should not expose reactive cards in active windows")
end

local function _test_item_phase_hides_rent_cards_on_other_owned_land()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:update_player_position(p, idx)
  g:set_tile_owner(tile_ref, g.players[2].id)
  p.inventory:add({ id = item_ids.strong })
  p.inventory:add({ id = item_ids.free_rent })

  local spec = item_phase.build_choice_spec(g, p, "post_action")
  _assert_eq(spec, nil, "other player land should still hide reactive cards in active windows")
end

local function _test_build_wait_choice_args_requires_resume_next_state()
  local ok, err = pcall(function()
    item_phase.build_wait_choice_args(nil)
  end)
  _assert_eq(ok, false, "build_wait_choice_args should assert when meta is missing")
  assert(type(err) == "string" and string.find(err, "missing meta%.resume_next_state", 1, false),
    "build_wait_choice_args should explain missing resume_next_state")
end

local function _test_build_wait_choice_args_allows_nil_resume_next_args()
  local result = item_phase.build_wait_choice_args({
    resume_next_state = "landing",
    resume_next_args = nil,
  })
  _assert_eq(result.next_state, "landing", "build_wait_choice_args should forward resume_next_state")
  _assert_eq(result.next_args, nil, "build_wait_choice_args should preserve nil resume_next_args")
end

local function _test_build_wait_choice_args_restores_next_state_and_args()
  local resume_next_args = { tile_id = 12, skip_anim = true }
  local result = item_phase.build_wait_choice_args({
    resume_next_state = "move_followup",
    resume_next_args = resume_next_args,
  })
  _assert_eq(result.next_state, "move_followup", "build_wait_choice_args should restore resume_next_state")
  assert(result.next_args == resume_next_args, "build_wait_choice_args should forward the original next_args table")
end

local function _test_wait_choice_arg_helpers_split_state_and_args()
  local resume_next_args = { tile_id = 12, skip_anim = true }
  local next_state = item_phase._build_wait_choice_next_state({
    resume_next_state = "move_followup",
  })
  local next_args = item_phase._build_wait_choice_next_args({
    resume_next_args = resume_next_args,
  })

  _assert_eq(next_state, "move_followup", "_build_wait_choice_next_state should forward resume_next_state")
  assert(next_args == resume_next_args, "_build_wait_choice_next_args should forward the original next_args table")
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
    timing.action_anim_default_seconds or 1.0,
    "target item anim should use default duration"
  )
end

local function _test_exile_item_defers_mountain_effect_until_move_followup()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local user = g.players[1]
  local target = g.players[2]
  user.inventory:add({ id = item_ids.exile })

  local res = executor.use_item(g, user, item_ids.exile, {
    by_ai = true,
    target_id = target.id,
  })

  _assert_eq(type(res), "table", "exile should return result payload")
  _assert_eq(res.ok, true, "exile should succeed")
  assert(type(res.after_action_anim) == "table", "exile should expose move followup continuation")
  _assert_eq(target.status.stay_turns or 0, 0, "exile should not apply mountain stay immediately")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "teleport_effect", "exile should queue teleport effect first")
  _assert_eq(
    res.after_action_anim.next_args.log_entries[1],
    user.name .. " 使用流放卡，将 " .. target.name .. " 送往深山，停留 2 回合",
    "exile should defer main log entry until move followup"
  )

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
    timing.action_anim_default_seconds or 1.0,
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
    timing.action_anim_default_seconds or 1.0,
    "specific mine anim should use default duration"
  )
end

local function _test_item_phase_exposes_mine_in_pre_action()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.mine })

  local spec = assert(item_phase.build_choice_spec(g, p, "pre_action"), "mine should be offered in pre_action")
  _assert_eq(spec.uses_item_slots, true, "item_phase choice should expose uses_item_slots flag")
  _assert_eq(spec.pre_confirm_before_slot_pick, true,
    "item_phase choice should expose pre_confirm_before_slot_pick flag")
  _assert_eq(spec.confirm_title, "行动前", "item_phase choice should expose confirm title from use-case output")
  _assert_eq(spec.confirm_body, "可用道具：地雷卡", "item_phase choice should expose confirm body from use-case output")
  local found = nil
  for _, option in ipairs(spec.options) do
    if option.id == item_ids.mine then
      found = option
      break
    end
  end
  assert(found ~= nil, "pre_action choice should include mine")
  _assert_eq(found.confirm_title, "行动前", "item_phase option should expose confirm title from use-case output")
  _assert_eq(found.confirm_body, "将使用：地雷卡", "item_phase option should expose confirm body from use-case output")
end

local function _test_item_phase_exposes_mine_in_post_action()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.mine })

  local spec = assert(item_phase.build_choice_spec(g, p, "post_action"), "mine should be offered in post_action")
  _assert_eq(spec.confirm_title, "行动后", "post_action choice should expose confirm title from use-case output")
  _assert_eq(spec.confirm_body, "可用道具：地雷卡", "post_action choice should expose confirm body from use-case output")
  local found = nil
  for _, option in ipairs(spec.options) do
    if option.id == item_ids.mine then
      found = option
      break
    end
  end
  assert(found ~= nil, "post_action choice should include mine")
  _assert_eq(found.confirm_title, "行动后", "post_action option should expose confirm title from use-case output")
  _assert_eq(found.confirm_body, "将使用：地雷卡", "post_action option should expose confirm body from use-case output")
end

local function _test_item_phase_exposes_send_poor_in_post_action()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.send_poor })
  g:set_player_deity(p, "poor", 2)

  local pre_action = item_phase.build_choice_spec(g, p, "pre_action")
  _assert_eq(pre_action, nil, "send_poor should not be offered in pre_action")

  local spec = assert(item_phase.build_choice_spec(g, p, "post_action"), "send_poor should be offered in post_action")
  _assert_eq(spec.confirm_title, "行动后", "post_action choice should expose confirm title from use-case output")
  _assert_eq(spec.confirm_body, "可用道具：送神卡", "post_action choice should expose confirm body from use-case output")
  local found = nil
  for _, option in ipairs(spec.options) do
    if option.id == item_ids.send_poor then
      found = option
      break
    end
  end
  assert(found ~= nil, "post_action choice should include send_poor")
  _assert_eq(found.confirm_title, "行动后", "post_action option should expose confirm title from use-case output")
  _assert_eq(found.confirm_body, "将使用：送神卡", "post_action option should expose confirm body from use-case output")
end

local function _test_item_phase_dedupes_same_item_id_options()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.remote_dice })
  p.inventory:add({ id = item_ids.remote_dice })

  local spec = assert(item_phase.build_choice_spec(g, p, "pre_action"), "duplicate remote dice should still build choice")
  _assert_eq(#spec.options, 1, "item_phase choice should collapse duplicate item ids into one option")
  _assert_eq(spec.options[1] and spec.options[1].id, item_ids.remote_dice,
    "deduped option should keep remote dice id")
  _assert_eq(spec.confirm_body, "可用道具：遥控骰子卡", "deduped confirm body should not repeat card names")
end

local function _test_item_phase_run_loops_auto_repeatable_phase_until_no_action()
  local g = _new_game()
  local p = g:current_player()
  local auto_play_port = require("src.rules.ports.auto_play")
  local calls = 0

  support.with_patches({
    {
      target = auto_play_port,
      key = "is_auto_player",
      value = function()
        return true
      end,
    },
    {
      target = item_strategy,
      key = "auto_pre_action",
      value = function(_, _, phase)
        calls = calls + 1
        _assert_eq(phase, "pre_action", "auto repeatable phase should pass explicit phase to strategy")
        if calls < 3 then
          return { ok = true }
        end
        return nil
      end,
    },
  }, function()
    local result = item_phase.run({ game = g }, "pre_action", {
      player = p,
      next_state = "roll",
      next_args = { player = p },
    })
    _assert_eq(result, nil, "auto repeatable phase should resolve immediately when no waits/anim are produced")
  end)

  _assert_eq(calls, 3, "auto repeatable phase should keep probing until no further action is returned")
  assert(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
    "auto repeatable phase should mark done only after the final no-op probe")
end

local function _test_item_strategy_hides_reactive_cards_from_active_window()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:update_player_position(p, idx)
  p.inventory:add({ id = item_ids.strong })
  p.inventory:add({ id = item_ids.free_rent })
  p.inventory:add({ id = item_ids.roadblock })

  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  assert(
    item_strategy.can_offer_in_phase(g, p, item_ids.strong, "post_action") == false,
    "strong card should stay hidden in active windows"
  )
  assert(
    item_strategy.can_offer_in_phase(g, p, item_ids.free_rent, "post_action") == false,
    "free_rent card should stay hidden in active windows"
  )
  assert(
    item_strategy.can_offer_in_phase(g, p, item_ids.roadblock, "post_action") == true,
    "roadblock should be offered when UI candidates exist"
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
  status_ops.set_player_seat(g, player, nil)
  _assert_eq(player.seat_id, nil, "set_player_seat should stay nil after vehicle retirement")
end

local function _test_board_advance_tracks_branch_and_wrap()
  local board = require("src.rules.board"):new({
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
  _assert_eq(#anims, 1, "cash receive animation should collapse into one summary collection anim")
  _assert_eq(anims[1].amount, 250, "summary receive animation should use the total collected amount")
  _assert_eq(#events, 1, "collect_from_others should emit one summary event")
end

local function _test_item_phase_select_remote_dice_keeps_followup_cancelable_in_repeatable_phase()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.remote_dice })

  local spec = assert(item_phase.build_choice_spec(g, p, "pre_action", {
    next_state = "roll",
    next_args = { player = p },
  }), "item_phase should open when remote dice exists")
  local pending = _open_choice(g, spec)
  local before_count = support.inventory.count(p)
  _assert_eq(before_count, 1, "precondition inventory count")

  local res = choice_resolver.resolve(g, pending, {
    type = "choice_select",
    choice_id = pending.id,
    option_id = item_ids.remote_dice,
    actor_role_id = p.id,
  })
  assert(res and res.stay == true, "selecting remote dice should open follow-up choice")

  local after_pending = _get_choice(g)
  assert(after_pending and after_pending.kind == "remote_dice_value", "follow-up choice kind should be remote_dice_value")
  _assert_eq(support.inventory.count(p), 1, "repeatable pre_action should defer consume until follow-up confirm")
  _assert_eq(after_pending.allow_cancel, true, "repeatable pre_action follow-up should still allow cancel")
  assert(after_pending.meta and after_pending.meta.phase == "pre_action", "follow-up choice should carry repeatable phase context")
  assert(after_pending.meta and after_pending.meta.item_preconsumed ~= true, "repeatable phase follow-up should not mark preconsumed")
end

local function _test_repeatable_phase_followup_cancel_reopens_item_phase_without_consuming()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.remote_dice })

  local pending = _open_choice(g, assert(item_phase.build_choice_spec(g, p, "pre_action", {
    next_state = "roll",
    next_args = { player = p },
  }), "repeatable pre_action choice should open"))
  local select_res = choice_resolver.resolve(g, pending, {
    type = "choice_select",
    choice_id = pending.id,
    option_id = item_ids.remote_dice,
    actor_role_id = p.id,
  })
  assert(select_res and select_res.stay == true, "selecting remote dice should enter follow-up choice")

  local followup = _get_choice(g)
  local cancel_res = choice_resolver.resolve(g, followup, {
    type = "choice_cancel",
    choice_id = followup.id,
    actor_role_id = p.id,
  })
  assert(cancel_res and cancel_res.stay == true, "canceling repeatable follow-up should keep phase active")

  local reopened = _get_choice(g)
  assert(reopened and reopened.kind == "item_phase_choice", "cancel should reopen item phase choice")
  _assert_eq(support.inventory.count(p), 1, "cancel should not consume remote dice")
  assert(_find_option_id_by_label(reopened, "遥控骰子卡") ~= nil, "reopened phase should still offer remote dice")
end

local function _test_repeatable_phase_followup_confirm_consumes_and_reopens_item_phase()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.remote_dice })
  p.inventory:add({ id = item_ids.mine })

  local pending = _open_choice(g, assert(item_phase.build_choice_spec(g, p, "pre_action", {
    next_state = "roll",
    next_args = { player = p },
  }), "repeatable pre_action choice should open"))
  local select_res = choice_resolver.resolve(g, pending, {
    type = "choice_select",
    choice_id = pending.id,
    option_id = item_ids.remote_dice,
    actor_role_id = p.id,
  })
  assert(select_res and select_res.stay == true, "selecting remote dice should enter follow-up choice")

  local followup = _get_choice(g)
  local confirm_res = choice_resolver.resolve(g, followup, {
    type = "choice_select",
    choice_id = followup.id,
    option_id = 4,
    actor_role_id = p.id,
  })
  assert(confirm_res and confirm_res.stay == true, "confirming repeatable pre_action follow-up should reopen item phase immediately when no anim waits")
  _assert_eq(support.inventory.count(p), 1, "confirming follow-up should consume exactly one item")
  assert(p.status.pending_remote_dice and p.status.pending_remote_dice.values[1] == 4,
    "confirming follow-up should apply selected remote dice value")

  local reopened = _get_choice(g)
  assert(reopened and reopened.kind == "item_phase_choice", "confirming repeatable follow-up should reopen item phase")
  assert(_find_option_id_by_label(reopened, "地雷卡") ~= nil, "reopened phase should expose remaining pre_action item")
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
      item_id = item_ids.remote_dice,
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
  p.inventory:add({ id = item_ids.tax_free })

  local res = executor.use_item(g, p, item_ids.tax_free, { by_ai = true })
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "tax_free use ok")
  _assert_eq(#popups, 1, "simple item use should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "simple item broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, item_ids.tax_free, "simple item broadcast image_ref mismatch")
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
  user.inventory:add({ id = item_ids.share_wealth })

  local res = executor.use_item(g, user, item_ids.share_wealth, {
    by_ai = true,
    target_id = target.id,
  })
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "target item use ok")
  _assert_eq(#popups, 1, "target item use should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "target item broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, item_ids.share_wealth, "target item broadcast image_ref mismatch")
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
  p.inventory:add({ id = item_ids.remote_dice })
  local pending = _open_choice(g, {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子：选择点数",
    options = { { id = 4, label = "4" } },
    allow_cancel = false,
    meta = {
      player_id = p.id,
      item_id = item_ids.remote_dice,
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
  _assert_eq(popups[1].image_ref, item_ids.remote_dice, "remote dice broadcast image_ref mismatch")
end

local function _test_steal_uses_tip_without_popup()
  local g = _new_game()
  local popups = {}
  local tips = {}
  local stealer = g.players[1]
  local target = g.players[2]
  stealer.inventory:add({ id = item_ids.steal })
  target.inventory:add({ id = item_ids.tax_free })

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
  stealer.inventory:add({ id = item_ids.steal })

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
    p.inventory:add({ id = item_ids.rich })
    local res = executor.use_item(g, p, item_ids.rich, { by_ai = true })
    local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
    _assert_eq(ok, true, "rich item use ok")
  end)

  assert(#emitted >= 1, "rich item should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.deity_applied, "rich item should emit deity feedback event")
  _assert_eq(emitted[1].payload.deity_type, "rich", "rich item should emit rich deity type")
  _assert_eq(emitted[1].payload.player_id, p.id, "rich item should emit current player id")
end

local _roadblock_and_demolish_tests = require("suites.domain.item_roadblock_and_demolish")
local _effect_pipeline_tests = require("suites.domain.item_effect_pipeline")

return {
  name = "item",
  tests = {
    { name = "monster_card", run = _test_monster_card },
    { name = "missile_card", run = _test_missile_card },
    { name = "demolish_card_no_target_returns_false", run = _test_demolish_card_no_target_returns_false },
    { name = "item_phase_filters_unusable_target_items", run = _test_item_phase_filters_unusable_target_items },
    { name = "item_phase_keeps_demolish_when_target_exists", run = _test_item_phase_keeps_demolish_when_target_exists },
    { name = "item_phase_hides_rent_cards_on_owned_land", run = _test_item_phase_hides_rent_cards_on_owned_land },
    { name = "item_phase_hides_rent_cards_on_other_owned_land", run = _test_item_phase_hides_rent_cards_on_other_owned_land },
    { name = "build_wait_choice_args_requires_resume_next_state", run = _test_build_wait_choice_args_requires_resume_next_state },
    { name = "build_wait_choice_args_allows_nil_resume_next_args", run = _test_build_wait_choice_args_allows_nil_resume_next_args },
    { name = "build_wait_choice_args_restores_next_state_and_args", run = _test_build_wait_choice_args_restores_next_state_and_args },
    { name = "wait_choice_arg_helpers_split_state_and_args", run = _test_wait_choice_arg_helpers_split_state_and_args },
    { name = "item_equalize_cash", run = _test_item_equalize_cash },
    { name = "target_item_manual_direct_exec_and_duration", run = _test_target_item_manual_direct_exec_and_duration },
    {
      name = "exile_item_defers_mountain_effect_until_move_followup",
      run = _test_exile_item_defers_mountain_effect_until_move_followup,
    },
    { name = "item_executor_fallback_item_use_anim", run = _test_item_executor_fallback_item_use_anim },
    { name = "item_executor_keeps_specific_anim_without_fallback", run = _test_item_executor_keeps_specific_anim_without_fallback },
    { name = "item_phase_exposes_mine_in_pre_action", run = _test_item_phase_exposes_mine_in_pre_action },
    { name = "item_phase_exposes_mine_in_post_action", run = _test_item_phase_exposes_mine_in_post_action },
    { name = "item_phase_exposes_send_poor_in_post_action", run = _test_item_phase_exposes_send_poor_in_post_action },
    { name = "item_phase_dedupes_same_item_id_options", run = _test_item_phase_dedupes_same_item_id_options },
    {
      name = "item_phase_run_loops_auto_repeatable_phase_until_no_action",
      run = _test_item_phase_run_loops_auto_repeatable_phase_until_no_action,
    },
    { name = "item_strategy_hides_reactive_cards_from_active_window", run = _test_item_strategy_hides_reactive_cards_from_active_window },
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
      run = _roadblock_and_demolish_tests[1],
    },
    { name = "roadblock_manual_choice_allows_current_tile", run = _roadblock_and_demolish_tests[2] },
    {
      name = "roadblock_manual_choice_hongkong_keeps_nearest_slots_ordered",
      run = _roadblock_and_demolish_tests[3],
    },
    {
      name = "roadblock_manual_choice_hongkong_nearest_haikou_slot_places_correctly",
      run = _roadblock_and_demolish_tests[4],
    },
    {
      name = "roadblock_manual_candidates_expose_nearest_unique_tiles_at_intersection",
      run = _roadblock_and_demolish_tests[5],
    },
    {
      name = "roadblock_manual_candidates_use_shared_manhattan_range_at_branch",
      run = _roadblock_and_demolish_tests[6],
    },
    {
      name = "demolish_manual_choice_uses_manhattan_range_at_branch",
      run = _roadblock_and_demolish_tests[7],
    },
    { name = "roadblock_ai_uses_auto_candidates_only", run = _roadblock_and_demolish_tests[8] },
    {
      name = "item_phase_select_remote_dice_keeps_followup_cancelable_in_repeatable_phase",
      run = _test_item_phase_select_remote_dice_keeps_followup_cancelable_in_repeatable_phase,
    },
    {
      name = "repeatable_phase_followup_cancel_reopens_item_phase_without_consuming",
      run = _test_repeatable_phase_followup_cancel_reopens_item_phase_without_consuming,
    },
    {
      name = "repeatable_phase_followup_confirm_consumes_and_reopens_item_phase",
      run = _test_repeatable_phase_followup_confirm_consumes_and_reopens_item_phase,
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
      run = _effect_pipeline_tests[1],
    },
    {
      name = "effect_pipeline_stop_if_short_circuits_before_optional_choice",
      run = _effect_pipeline_tests[2],
    },
    {
      name = "effect_pipeline_single_optional_effect_uses_secondary_confirm_route",
      run = _effect_pipeline_tests[3],
    },

    -- Strategy helper characterization tests (T4)
    { name = "ai_can_use_item_returns_true_for_mine_in_pre_action_and_post_action", run = _effect_pipeline_tests[4] },
    { name = "ai_can_use_item_uses_offer_in_phases_for_other_items", run = _effect_pipeline_tests[5] },
    { name = "has_demolish_target_returns_true_when_target_exists", run = _effect_pipeline_tests[6] },
    { name = "has_demolish_target_returns_false_when_no_target", run = _effect_pipeline_tests[7] },
    { name = "has_target_player_returns_true_when_candidates_exist", run = _effect_pipeline_tests[8] },
    { name = "has_target_player_returns_false_when_no_candidates", run = _effect_pipeline_tests[9] },
    { name = "try_use_item_returns_nil_when_cond_fails", run = _effect_pipeline_tests[10] },
    { name = "try_use_item_returns_nil_when_item_not_in_inventory", run = _effect_pipeline_tests[11] },
    { name = "try_clear_obstacles_returns_result_when_obstacles_found", run = _effect_pipeline_tests[12] },
    { name = "try_clear_obstacles_returns_nil_when_no_obstacles", run = _effect_pipeline_tests[13] },
    { name = "try_remote_dice_returns_nil_when_no_dice_value_picked", run = _effect_pipeline_tests[14] },
    { name = "try_roadblock_returns_nil_when_no_target_picked", run = _effect_pipeline_tests[15] },
    { name = "try_target_items_returns_nil_when_no_items_in_inventory", run = _effect_pipeline_tests[16] },
    { name = "try_deity_items_returns_nil_when_no_deity_items", run = _effect_pipeline_tests[17] },
  },
}
