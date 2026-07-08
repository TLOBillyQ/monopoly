local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local demolish = require("src.rules.items.demolish")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local flow_context = require("src.rules.items.use_flow_context")
local flow_result = require("src.rules.items.use_flow_result")
local remote_dice = require("src.rules.items.remote_dice")
local resolvers = require("src.rules.items.use_flow_resolvers")
local roadblock = require("src.rules.items.roadblock")
local settlement = require("src.rules.items.settlement")
local use_flow = require("src.rules.items.use_flow")

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

local function _with_item_handler(game, item_id, handler, fn)
  local handlers = assert(game.registries and game.registries.items and game.registries.items.handlers,
    "missing item handlers")
  local previous = handlers[item_id]
  handlers[item_id] = handler
  local ok, result = pcall(fn)
  handlers[item_id] = previous
  if not ok then
    error(result, 0)
  end
  return result
end

local function _with_patches(patches, fn)
  local previous = {}
  for index, patch in ipairs(patches) do
    previous[index] = patch.target[patch.key]
    patch.target[patch.key] = patch.value
  end

  local ok, result = pcall(fn)
  for index = #patches, 1, -1 do
    local patch = patches[index]
    patch.target[patch.key] = previous[index]
  end
  if not ok then
    error(result, 0)
  end
  return result
end

describe("item_use_flow", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("begin rejects missing game before item checks", function()
    local result = use_flow.begin_item_use(nil, nil, item_ids.mine, {})

    _assert_eq(result.ok, false, "missing game should reject")
    _assert_eq(result.reason, "missing_game", "missing game reason")
  end)

  it("begin rejects missing actor with stable reason", function()
    local g = _new_game()

    local result = use_flow.begin_item_use(g, 9999, item_ids.mine, { phase = "pre_action" })

    _assert_eq(result.ok, false, "missing actor should reject")
    _assert_eq(result.status, "rejected", "missing actor status")
    _assert_eq(result.reason, "missing_actor", "missing actor reason")
  end)

  it("begin rejects missing item config and absent inventory before executing effect", function()
    local g = _new_game()
    local player = g:current_player()
    local missing_item_id = 999999
    player.inventory:add({ id = missing_item_id })

    local missing_cfg = use_flow.begin_item_use(g, player.id, missing_item_id, {})
    local missing_inventory = use_flow.begin_item_use(g, player.id, item_ids.mine, { phase = "pre_action" })

    _assert_eq(missing_cfg.ok, false, "missing cfg should reject")
    _assert_eq(missing_cfg.reason, "missing_item_cfg", "missing cfg reason")
    _assert_eq(missing_inventory.ok, false, "absent inventory item should reject")
    _assert_eq(missing_inventory.reason, "item_not_in_inventory", "absent inventory reason")
  end)

  it("begin rejects item outside current phase before executing effect", function()
    local g = _new_game()
    local player = g:current_player()
    player.inventory:add({ id = item_ids.remote_dice })

    local result = use_flow.begin_item_use(g, player.id, item_ids.remote_dice, { phase = "post_action" })

    _assert_eq(result.ok, false, "phase mismatch should reject")
    _assert_eq(result.reason, "offer_in_phases_not_allowed", "phase mismatch reason")
    _assert_eq(inventory.count(player), 1, "rejected item should remain")
  end)

  it("begin accepts table actors and games without find_player_by_id", function()
    local g = _new_game()
    local player = g.players[1]
    player.inventory:add({ id = item_ids.mine })
    player.inventory:add({ id = item_ids.mine })

    _with_item_handler(g, item_ids.mine, function()
      return { ok = true, action_anim = true }
    end, function()
      local table_actor = use_flow.begin_item_use(g, player, item_ids.mine, { by_ai = false })
      local fallback_game = {
        anim_gate_port = {},
        players = g.players,
        registries = g.registries,
        turn = g.turn,
      }
      local fallback_actor = use_flow.begin_item_use(fallback_game, player.id, item_ids.mine, { by_ai = false })

      _assert_eq(table_actor.ok, true, "table actor should apply")
      _assert_eq(fallback_actor.ok, true, "fallback player scan should apply")
    end)
  end)

  it("context resolves actors through finder before players fallback", function()
    local finder_player = { id = 7 }
    local fallback_player = { id = 7 }
    local calls = 0
    local game = {
      players = { fallback_player },
      find_player_by_id = function(_, actor_id)
        calls = calls + 1
        _assert_eq(actor_id, 7, "finder actor id")
        return finder_player
      end,
    }

    local resolved = flow_context.resolve_actor(game, 7)

    _assert_eq(resolved, finder_player, "finder player should win")
    _assert_eq(calls, 1, "finder should be called once")
  end)

  it("context counts zero matching items without offset", function()
    local g = _new_game()
    local player = g.players[1]
    inventory.clear(player)
    player.inventory:add({ id = item_ids.roadblock })

    _assert_eq(flow_context.count_item(player, item_ids.mine), 0, "absent item count")
    player.inventory:add({ id = item_ids.mine })
    _assert_eq(flow_context.count_item(player, item_ids.mine), 1, "single item count")
  end)

  it("begin preserves failed effect reasons and bag-full fallback", function()
    local g = _new_game()
    local player = g.players[1]
    player.inventory:add({ id = item_ids.mine })
    player.inventory:add({ id = item_ids.mine })

    _with_item_handler(g, item_ids.mine, function(_, _, _, context)
      if context.fail_with_bag_full then
        return { ok = false, bag_full = true }
      end
      return { ok = false, reason = "handler_blocked", item_consumed = true }
    end, function()
      local reason = use_flow.begin_item_use(g, player.id, item_ids.mine, {})
      local bag_full = use_flow.begin_item_use(g, player.id, item_ids.mine, {
        fail_with_bag_full = true,
      })

      _assert_eq(reason.ok, false, "handler reason should reject")
      _assert_eq(reason.reason, "handler_blocked", "handler reason should be preserved")
      _assert_eq(reason.item_consumed, true, "explicit consumed marker should be preserved")
      _assert_eq(bag_full.ok, false, "bag-full handler should reject")
      _assert_eq(bag_full.reason, "bag_full", "bag-full reason should be normalized")
    end)
  end)

  it("begin uses fallback rejection reason for false effect results", function()
    local g = _new_game()
    local player = g.players[1]
    player.inventory:add({ id = item_ids.mine })

    _with_item_handler(g, item_ids.mine, function()
      return false
    end, function()
      local result = use_flow.begin_item_use(g, player.id, item_ids.mine, {})

      _assert_eq(result.ok, false, "false handler result should reject")
      _assert_eq(result.reason, "no_candidates", "false handler fallback reason")
    end)
  end)

  it("begin treats successful raw effect shapes as applied", function()
    local g = _new_game()
    local player = g.players[1]
    player.inventory:add({ id = item_ids.mine })

    _with_item_handler(g, item_ids.mine, function(_, _, _, context)
      if context.table_without_ok then
        return { action_anim = true }
      end
      return true
    end, function()
      local plain_true = use_flow.begin_item_use(g, player.id, item_ids.mine, {})
      local table_without_ok = use_flow.begin_item_use(g, player.id, item_ids.mine, {
        table_without_ok = true,
      })

      _assert_eq(plain_true.ok, true, "plain true result should apply")
      _assert_eq(plain_true.status, "applied", "plain true status")
      _assert_eq(table_without_ok.ok, true, "table without ok should apply")
      _assert_eq(table_without_ok.status, "applied", "table without ok status")
    end)
  end)

  it("normalizes waiting effect metadata", function()
    local g = _new_game()
    local player = g.players[1]
    player.inventory:add({ id = item_ids.mine })
    local choice_spec = {
      kind = "item_target_player",
      options = { { id = player.id, label = player.name } },
    }

    local waiting = flow_result.normalize_effect({
      waiting = true,
      ok = false,
      intent = { choice_spec = choice_spec },
    }, player, item_ids.mine)

    _assert_eq(waiting.status, "waiting_choice", "waiting result status")
    _assert_eq(waiting.actor_id, player.id, "waiting result actor id")
    _assert_eq(waiting.choice_spec, choice_spec, "waiting result choice spec")
    _assert_eq(waiting.item_consumed, false, "waiting result should not consume")
  end)

  it("passes settled results through untouched", function()
    local g = _new_game()
    local player = g.players[1]
    local settled = settlement.execute(g, player, item_ids.mine, function()
      return { ok = false, reason = "blocked" }
    end, { fallback_reason = "fallback", context_preconsumed = true })

    _assert_eq(flow_result.normalize_effect(settled, player, item_ids.mine), settled,
      "settled results should pass through unchanged")
  end)

  it("begin returns structured waiting choice for manual target item", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })

    _assert_eq(result.ok, true, "steal begin should be accepted")
    _assert_eq(result.status, "waiting_choice", "steal should wait for target choice")
    _assert_eq(result.item_consumed, false, "waiting choice should not consume item")
    assert(result.choice_spec and result.choice_spec.kind == "item_target_player", "steal should expose target-player choice")
    _assert_eq(result.choice_spec.options[1].id, target.id, "target with item should be offered")
  end)

  it("resolve target-player choice applies item through shared flow", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })
    target.inventory:add({ id = item_ids.tax_free })

    local begin = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })
    local choice = support.open_choice(g, begin.choice_spec)

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = target.id,
      actor_role_id = user.id,
    })

    _assert_eq(result.ok, true, "target choice should apply")
    _assert_eq(result.status, "applied", "target choice status")
    _assert_eq(result.item_consumed, true, "steal card should be consumed")
    _assert_eq(_count_item(user, item_ids.steal), 0, "steal card should leave inventory")
    _assert_eq(inventory.count(target), 1, "target should lose one item")
  end)

  it("resolve rejects choices that do not belong to the selected item use", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = 4, label = "4" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.roadblock,
        dice_count = 1,
      },
    })

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id,
    }, {
      item_id = item_ids.remote_dice,
    })

    _assert_eq(result.ok, false, "wrong item metadata should reject")
    _assert_eq(result.reason, "item_mismatch", "wrong item reason")
    _assert_eq(_count_item(user, item_ids.remote_dice), 1, "rejected choice should not consume item")
  end)

  it("resolve accepts numeric submissions for string-like option ids", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { "4" },
      meta = {
        player_id = user.id,
        item_id = item_ids.remote_dice,
        dice_count = 1,
      },
    })

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id,
    })

    _assert_eq(result.ok, true, "string option should accept numeric submission")
    _assert_eq(result.status, "applied", "string option numeric submission status")
    _assert_eq(_count_item(user, item_ids.remote_dice), 0, "accepted string option should consume item")
  end)

  it("resolve accepts numeric submissions for table options with string ids", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = "4", label = "4" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.remote_dice,
        dice_count = 1,
      },
    })

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id,
    })

    _assert_eq(result.ok, true, "table string option id should accept numeric submission")
    _assert_eq(result.status, "applied", "table string option numeric submission status")
    _assert_eq(_count_item(user, item_ids.remote_dice), 0, "accepted table string option should consume item")
  end)

  it("resolve accepts string item ids in caller context when choice metadata is numeric", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = 4, label = "4" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.remote_dice,
        dice_count = 1,
      },
    })

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id,
    }, {
      item_id = tostring(item_ids.remote_dice),
    })

    _assert_eq(result.ok, true, "string context item id should match numeric choice metadata")
    _assert_eq(result.status, "applied", "string context item id status")
    _assert_eq(_count_item(user, item_ids.remote_dice), 0, "matched string context item id should consume item")
  end)

  it("resolver falls back to game dice count for remote dice choices", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local captured = {}
    g.player_dice_count = function(_, player)
      captured.dice_player = player
      return 2
    end

    _with_patches({
      {
        target = remote_dice,
        key = "apply",
        value = function(game, player, dice_count, option_id)
          captured.game = game
          captured.player = player
          captured.dice_count = dice_count
          captured.option_id = option_id
          return { ok = true }
        end,
      },
    }, function()
      local result = resolvers.resolve(g, {
        kind = "remote_dice_value",
      }, {
        option_id = 5,
      }, {}, {
        item_id = item_ids.remote_dice,
      }, user, item_ids.remote_dice)

      _assert_eq(result.ok, true, "remote dice resolver should apply")
      _assert_eq(captured.game, g, "remote dice game")
      _assert_eq(captured.player, user, "remote dice player")
      _assert_eq(captured.dice_player, user, "remote dice count player")
      _assert_eq(captured.dice_count, 2, "remote dice count fallback")
      _assert_eq(captured.option_id, 5, "remote dice selected value")
      _assert_eq(_count_item(user, item_ids.remote_dice), 0, "remote dice should consume item")
    end)
  end)

  it("resolver rejects invalid roadblock choices before consuming item", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.roadblock })

    _with_patches({
      {
        target = roadblock,
        key = "is_ui_candidate",
        value = function()
          return false
        end,
      },
      {
        target = roadblock,
        key = "apply",
        value = function()
          error("roadblock apply should not run")
        end,
      },
    }, function()
      local result = resolvers.resolve(g, {
        kind = "roadblock_target",
      }, {
        option_id = 9999,
      }, {}, {
        item_id = item_ids.roadblock,
      }, user, item_ids.roadblock)

      _assert_eq(result.ok, false, "invalid roadblock target should reject")
      _assert_eq(result.reason, "invalid_target", "invalid roadblock reason")
      _assert_eq(_count_item(user, item_ids.roadblock), 1, "invalid roadblock should not consume item")
    end)
  end)

  it("resolver dispatches demolish raw result intent", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.monster })
    local raw_intent = { kind = "push_popup", payload = { title = "done" } }
    local dispatches = {}
    local captured = {}

    _with_patches({
      {
        target = demolish,
        key = "apply",
        value = function(game, player, option_id, opts)
          captured.game = game
          captured.player = player
          captured.option_id = option_id
          captured.item_id = opts and opts.item_id or nil
          return { ok = true, intent = raw_intent }
        end,
      },
      {
        target = intent_output_port,
        key = "dispatch",
        value = function(game, payload)
          dispatches[#dispatches + 1] = { game = game, payload = payload }
        end,
      },
    }, function()
      local result = resolvers.resolve(g, {
        kind = "demolish_target",
      }, {
        option_id = 12,
      }, {}, {
        item_id = item_ids.monster,
      }, user, item_ids.monster)

      _assert_eq(result.ok, true, "demolish resolver should apply")
      _assert_eq(captured.game, g, "demolish game")
      _assert_eq(captured.player, user, "demolish player")
      _assert_eq(captured.option_id, 12, "demolish target")
      _assert_eq(captured.item_id, item_ids.monster, "demolish item id")
      _assert_eq(#dispatches, 1, "demolish should dispatch one intent")
      _assert_eq(dispatches[1].game, g, "demolish dispatch game")
      _assert_eq(dispatches[1].payload, raw_intent, "demolish dispatch intent")
      _assert_eq(_count_item(user, item_ids.monster), 0, "demolish should consume item")
    end)
  end)

  it("resolve rejects malformed choice submissions before applying effects", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = 4, label = "4" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.remote_dice,
        dice_count = 1,
      },
    })

    local missing_game = use_flow.resolve_item_use_choice(nil, choice, { option_id = 4 })
    local missing_choice = use_flow.resolve_item_use_choice(g, nil, { option_id = 4 })
    local missing_action = use_flow.resolve_item_use_choice(g, choice, nil)
    local choice_mismatch = use_flow.resolve_item_use_choice(g, choice, {
      choice_id = choice.id + 1,
      option_id = 4,
      actor_role_id = user.id,
    })
    local actor_mismatch = use_flow.resolve_item_use_choice(g, choice, {
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id + 1,
    })
    local invalid_option = use_flow.resolve_item_use_choice(g, choice, {
      choice_id = choice.id,
      option_id = 7,
      actor_role_id = user.id,
    })

    _assert_eq(missing_game.reason, "missing_game", "missing game reason")
    _assert_eq(missing_choice.reason, "missing_choice", "missing choice reason")
    _assert_eq(missing_action.reason, "missing_action", "missing action reason")
    _assert_eq(choice_mismatch.reason, "choice_mismatch", "choice mismatch reason")
    _assert_eq(actor_mismatch.reason, "actor_mismatch", "actor mismatch reason")
    _assert_eq(invalid_option.reason, "invalid_option", "invalid option reason")
    _assert_eq(_count_item(user, item_ids.remote_dice), 1, "malformed choices should not consume")
  end)

  it("resolve rejects missing actors and unsupported choice kinds", function()
    local g = _new_game()
    local user = g.players[1]
    local missing_actor_choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = 4, label = "4" } },
      meta = {
        player_id = 9999,
        item_id = item_ids.remote_dice,
        dice_count = 1,
      },
    })
    local unsupported_choice = support.open_choice(g, {
      kind = "unsupported_item_choice",
      options = { { id = "only", label = "Only" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.remote_dice,
      },
    })

    local missing_actor = use_flow.resolve_item_use_choice(g, missing_actor_choice, {
      choice_id = missing_actor_choice.id,
      option_id = 4,
    })
    local unsupported = use_flow.resolve_item_use_choice(g, unsupported_choice, {
      choice_id = unsupported_choice.id,
      option_id = "only",
      actor_role_id = user.id,
    })

    _assert_eq(missing_actor.reason, "missing_actor", "missing actor reason")
    _assert_eq(unsupported.reason, "unsupported_choice_kind", "unsupported kind reason")
  end)
end)
