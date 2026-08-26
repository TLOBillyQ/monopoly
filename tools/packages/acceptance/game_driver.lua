local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local default_ports = require("src.turn.output.default_ports")
local compose_game = require("src.app.compose_game")
local game_factory = require("src.app.game_factory")
local movement = require("src.rules.movement")
local route_plan = require("src.rules.board.route_plan")
local mine_effect = require("src.rules.effects.mine")
local roll_module = require("src.turn.phases.roll")
local dice_mult = require("src.turn.phases.dice_multiplier")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local inventory = require("src.rules.items.inventory")
local item_availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local roadblock_rules = require("src.rules.items.roadblock")
local demolish_rules = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")
local market_choice = require("src.rules.market.choice")
local board_query = require("src.rules.board.query")
local intent_output_port = require("src.rules.ports.intent_output")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local card_reveal_port = require("src.rules.ports.card_reveal")
local share_panel_port = require("src.foundation.ports.share_panel")
local host_share_panel = require("src.host.share_panel")
local land_presenter = require("src.rules.land.presenter")
local gain_reveal = require("src.rules.items.gain_reveal")
local bankruptcy = require("src.rules.endgame.bankruptcy")
local screen_openers_port = require("src.ui.seams.screen_openers")
local resolver_seam = require("src.ui.seams.local_actor_resolver")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local chance_handlers = require("src.rules.chance.handlers")
local endgame_rules = require("src.rules.endgame")
local asset_total = require("src.rules.land.asset_total")
local turn_dispatch = require("src.turn.actions.action_dispatcher")

local driver = {}

local OUTER_RING_SIZE = 32

-- The black market's paid-currency purchase is a host-side gateway (real production
-- wires src.host.paid_purchase_gateway). Turn-flow scenarios never assert a market
-- purchase, but a played turn with an uncontrolled roll can incidentally route through
-- the off-ring market, and src/turn's market setup asserts a configured gateway — so
-- without one such a turn crashes. Install a no-op gateway in new_game so any incidental
-- market routing is a safe no-op, keeping play_turn robust to any roll. Suites that
-- need a real gateway configure their own after new_game, wholesale as usual.
local _NOOP_PAID_GATEWAY = {
  setup_for_game = function() end,
  can_start = function() return false, "acceptance_noop" end,
  start = function() return false, "acceptance_noop" end,
}

local function _build_queue_rng(queue)
  local index = 0
  return game_factory.build_rng(function(min, max)
    index = index + 1
    if index > #queue then
      return math.random(min, max)
    end
    return queue[index]
  end)
end

local function _build_event_capture_port(events)
  return {
    publish = function(_, _, event)
      events[#events + 1] = event
      return true
    end,
  }
end

function driver.new_game(opts)
  opts = opts or {}
  -- 进程级全局端口先 reset 再 configure（#164）：每个 ctx 从已知基线出发，
  -- 上一个套件的残留配置（如 resolve_role）不再毒化本局构造。
  runtime_ports.reset_for_tests()
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(_NOOP_PAID_GATEWAY)
  -- #329:card_reveal 纯契约 port 的 acceptance 装配点(与 host_install 同款
  -- thunk 接线,闭包调用时读模块字段,步骤内 patch 仍可截获)。
  card_reveal_port.reset_for_tests()
  card_reveal_port.configure({
    push_land_popup = function(...) return land_presenter.push_popup(...) end,
    queue_gain_reveal = function(...) return gain_reveal.queue(...) end,
    bankruptcy_text = function(...) return bankruptcy.resolve_bankruptcy_text(...) end,
  })
  -- #463:share_panel 纯契约 port 的 acceptance 装配点(与 host_install 同款
  -- thunk 接线,闭包调用时读模块字段,步骤内 patch 仍可截获)。
  share_panel_port.reset_for_tests()
  share_panel_port.configure({
    try_show = function(...) return host_share_panel.try_show(...) end,
  })
  -- #332:local_actor_resolver 接缝的 acceptance 装配点(与 host_install 同款)。
  resolver_seam.reset_for_tests()
  resolver_seam.configure(require("src.ui.render.support.local_actor_resolver"))
  -- #332:screen_openers 接缝的 acceptance 装配点(与 host_install 同款惰性
  -- thunk,屏模块首次开屏时才装载)。
  screen_openers_port.reset_for_tests()
  screen_openers_port.configure({
    open_secondary_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open(...)
    end,
    open_pre_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open_pre_confirm(...)
    end,
    open_item_phase_pre_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open_item_phase_pre_confirm(...)
    end,
    refresh_secondary_confirm_copy = function(...)
      return require("src.ui.screens.secondary_confirm").refresh_copy(...)
    end,
    open_market = function(...)
      return require("src.ui.screens.market").open(...)
    end,
    close_market = function(...)
      return require("src.ui.screens.market").close(...)
    end,
  })
  local rng_queue = {}
  local captured_events = {}
  local game = compose_game.new_game(default_ports.resolve_game_opts({
    players = opts.players or {"P1", "P2", "P3", "P4"},
    ai = opts.ai or {[2] = true, [3] = true, [4] = true},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
    rng = _build_queue_rng(rng_queue),
  }))
  game.event_feed_port = _build_event_capture_port(captured_events)
  -- #513: 验收对局补齐两个 runtime port；与生产宿主的 _initialize_ports 等效占位。
  -- anim gate 默认双 false（无动画等待），步骤可在 new_game 后覆写这两个开关。
  game.anim_gate_port = game.anim_gate_port or { wait_move_anim = false, wait_action_anim = false }
  -- 破产清算调用 on_tiles_cleared；注入无副作用 stub（与 shared_support 同款）。
  game.bankruptcy_feedback_port = game.bankruptcy_feedback_port or {
    on_tiles_cleared = function() end,
  }
  -- Production wires runtime_ports.rng_next_int through host default_ports; without it
  -- an uncontrolled roll that lands a transit tile crashes in weighted_draw's item
  -- draw. Route the port to this game's rng so scenario-stocked queues stay authoritative
  -- (set_next_rolls swaps game.rng, and the closure reads it at call time).
  runtime_ports.configure({
    rng_next_int = function(min, max)
      return game.rng:next_int(min, max)
    end,
  })
  return {
    game = game,
    outer_ring_size = OUTER_RING_SIZE,
    _rng_queue = rng_queue,
    _events = captured_events,
  }
end

function driver.current_player(ctx)
  return ctx.game.players[1]
end

function driver.set_player_position(ctx, player, index)
  ctx.game:update_player_position(player, index)
end

function driver.clear_move_state(ctx, player)
  ctx.game:set_player_status(player, "move_dir", nil)
end

function driver.move(ctx, player, steps)
  return movement.move(ctx.game, player, steps)
end

function driver.set_next_rolls(ctx, values)
  ctx._rng_queue = values
  ctx.game.rng = _build_queue_rng(values)
end

function driver.player_position(_, player)
  return player.position
end

function driver.player_cash(ctx, player)
  return ctx.game:player_cash(player)
end

function driver.tile_at(ctx, index)
  return ctx.game.board:get_tile(index)
end

function driver.tile_owner(ctx, index)
  local tile = ctx.game.board:get_tile(index)
  if tile then
    return tile.owner_id
  end
  return nil
end

function driver.tile_level(ctx, index)
  local tile = ctx.game.board:get_tile(index)
  if tile then
    return tile.level
  end
  return nil
end

function driver.sync_outer_facing(ctx, player)
  local tile = ctx.game.board:get_tile(player.position)
  if not tile then return end
  local map = ctx.game.board.map
  local next_id = map.outer_next[tile.id]
  if next_id then
    ctx.game:set_player_status(player, "move_dir", map.direction(tile.id, next_id))
  end
end

function driver.place_roadblock(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game:place_roadblock(idx)
end

function driver.has_roadblock(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  return ctx.game.board:has_roadblock(idx)
end

function driver.place_mine(ctx, tile_id, data)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game:place_mine(idx, data)
end

function driver.has_mine(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  return ctx.game.board:has_mine(idx)
end

function driver.set_tile_type(ctx, tile_id, tile_type)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game.board:get_tile(idx).type = tile_type
end

function driver.set_player_deity(ctx, player, name, duration)
  ctx.game:set_player_deity(player, name, duration or 5)
end

function driver.tile_n_before_start(ctx, n)
  local map = ctx.game.board.map
  local id = map.start_id
  for _ = 1, n do
    id = map.outer_prev[id]
  end
  return ctx.game.board:index_of_tile_id(id)
end

function driver.set_player_facing(ctx, player, facing)
  ctx.game:set_player_status(player, "move_dir", facing)
end

function driver.move_with_opts(ctx, player, steps, opts)
  return movement.move(ctx.game, player, steps, opts)
end

function driver.try_trigger_mine(ctx, player)
  local pos = player.position
  if not mine_effect.can_trigger(ctx.game, player, pos) then
    return nil
  end
  local result = mine_effect.apply(ctx.game, player, pos)
  if result and result.hospitalized then
    ctx.game:player_apply_hospital_effects(player)
  end
  return result
end

function driver.events(ctx)
  return ctx._events
end

-- ── landing-settlement setup (cluster 3 support) ──────────────────────────────

-- Give a player a real inventory item by id (e.g. item_ids.free_rent / .strong),
-- so landing settlement sees a genuine card holding rather than a fixture flag.
function driver.give_item(_, player, item_id)
  inventory.add(player, { id = item_id })
end

function driver.has_item(_, player, item_id)
  return inventory.find_index(player, item_id) ~= nil
end

function driver.set_tile_owner(ctx, tile_id, owner_id)
  local tile = ctx.game.board:get_tile_by_id(tile_id)
  ctx.game:set_tile_owner(tile, owner_id)
end

-- Find the first ownable land tile on the outer ring; returns its ring index and tile
-- id. Lets a landing-settlement test seat a player there (by index) and set ownership
-- (by id) over the real map without hardcoding a tile. The map always has land tiles.
function driver.first_land_tile(ctx)
  for i = 1, OUTER_RING_SIZE do
    local tile = ctx.game.board:get_tile(i)
    if tile and tile.type == "land" then
      return i, tile.id
    end
  end
  error("no land tile on the outer ring")
end

-- Place `player` on `tile_id` and orient them forward along the outer ring (facing the
-- next ring tile) — the seating every ring-based setup verb shares. The outer ring is a
-- complete 32-tile cycle, so outer_next is always defined for a ring tile. Returns tile_id.
local function _seat_facing_forward(ctx, player, tile_id)
  local map = ctx.game.board.map
  ctx.game:update_player_position(player, ctx.game.board:index_of_tile_id(tile_id))
  ctx.game:set_player_status(player, "move_dir", map.direction(tile_id, map.outer_next[tile_id]))
  return tile_id
end

-- Seat a player one ring-step before the target tile (and face the ring forward) so
-- a roll of 1 lands them exactly on it — the real move+land path, no teleporting
-- onto the tile mid-settlement.
function driver.seat_before_tile(ctx, player, tile_id)
  _seat_facing_forward(ctx, player, ctx.game.board.map.outer_prev[tile_id])
end

-- Mark every black-market good sold out by zeroing its global purchase limit, the
-- same state production reaches once stock is exhausted.
function driver.set_market_sold_out(ctx)
  local limits = ctx.game.market_limits or {}
  for product_id in pairs(limits) do
    limits[product_id] = 0
  end
end

-- 黑市只读视角(#201):不开窗构建当前陈列与售罄/可购标记的只读视图,
-- 供「售罄仍可见」类断言直接读取,无需先走真实购买链。
function driver.peek_market(ctx, player, opts)
  return market_choice.builder.build(player, ctx.game, opts or { active_tab = "item", page_index = 1 })
end

-- The black market sits off the 32-tile outer ring on an inner cross-path, reachable
-- only through an entry_point the direction resolver gates. Seat + roll planning is a
-- rules concern (src.rules.board.route_plan): the driver just consumes the plan and
-- queues the roll on the rng so a plain played turn routes through the real movement
-- path — no teleporting, no restating the resolver's entry-gate rule here (#163).

-- Seat the player per a market route plan and queue its roll. Returns the market
-- tile id.
local function _seat_by_market_plan(ctx, player, plan_fn)
  local map = ctx.game.board.map
  local plan = assert(plan_fn(map, map.market_id))
  _seat_facing_forward(ctx, player, plan.seat_id)
  driver.set_next_rolls(ctx, { plan.roll })
  return map.market_id
end

-- Seat + roll so a played turn LANDS the player exactly on the black market (final
-- step), driving the real landing settlement (market effect).
function driver.seat_to_land_on_market(ctx, player)
  return _seat_by_market_plan(ctx, player, route_plan.plan_land_on)
end

-- Seat + roll so a played turn PASSES THROUGH the market mid-move (the real
-- market_interrupt fires) rather than landing on it, with at least one step
-- remaining.
function driver.seat_to_pass_through_market(ctx, player)
  return _seat_by_market_plan(ctx, player, route_plan.plan_pass_through)
end

-- ── AI item-phase setup (cluster 5 support) ───────────────────────────────────

-- ── item / board observation verbs (ADR 0017, #165) ─────────────────────
-- step 模块不得直 require src.rules 内部;道具与棋盘的观察/铺置动词收进 driver。

function driver.clear_items(_, player)
  inventory.clear(player)
end

-- CONTEXT「道具槽位」:模型层背包是固定槽位、空洞 false 占位;验收步骤面向「持有的卡」
-- 计数/取首张,这里压实为密集占用卡列表,屏蔽槽位表示。
function driver.items_of(_, player)
  local occupied = {}
  for _, item in ipairs(inventory.items(player)) do
    if item ~= false then
      occupied[#occupied + 1] = item
    end
  end
  return occupied
end

-- 道具在指定阶段是否可 offer;返回 ok, deny_reason(availability 同形)。
function driver.item_offer_allowed(ctx, player, item_id, phase)
  return item_availability.can_offer_in_phase(ctx.game, player, item_id, phase)
end

-- 构建并打开被动道具阶段 choice,标记阶段激活;返回 choice spec(nil 表示没建成)。
function driver.open_item_phase(ctx, player, phase, opts)
  local spec = item_phase.build_passive_choice_spec(ctx.game, player, phase, opts)
  if spec == nil then
    return nil
  end
  intent_output_port.open_choice(ctx.game, spec)
  item_phase.mark_active(ctx.game, phase)
  return spec
end

-- 目标类道具的候选面:走真实 item registry(availability / 无目标提示同源)。
function driver.target_candidates(ctx, player, item_id)
  local registry = assert(ctx.game.registries and ctx.game.registries.items, "missing item registry")
  return registry:target_candidates(ctx.game, player, item_id)
end

function driver.roadblock_candidates(ctx, player, range)
  return roadblock_rules.auto_candidates(ctx.game, player, range)
end

function driver.demolish_target(ctx, player, range)
  return demolish_rules.find_target(ctx.game, player, range)
end

-- 拆除类道具的 injure 口径:导弹命中送医,怪兽只拆建筑
-- (与 src.rules.items.handlers 的 demolish_items 同一事实)。
local DEMOLISH_INJURE = {
  [item_ids.monster] = false,
  [item_ids.missile] = true,
}

-- 拆除类道具「使用」动词(#199):真实消耗一张卡牌并对指定地块执行真实拆迁应用
-- (含送医后果),与生产 use → commit → apply 同序。返回 demolish.apply 的结果。
function driver.use_demolish_on(ctx, player, tile_idx, item_id)
  local injure = DEMOLISH_INJURE[item_id]
  assert(injure ~= nil, "not a demolish item: " .. tostring(item_id))
  inventory.consume(player, item_id)
  return demolish_rules.apply(ctx.game, player, tile_idx, { item_id = item_id, injure = injure })
end

-- 道具槽位点击派发动词(#199):走生产同一条 intent(item_slot_click)。槽位 → 道具
-- 由 turn 层从玩家真实背包解析,验收不再注入任何 UI 槽位镜像。
function driver.click_item_slot(ctx, player, slot_index)
  return turn_dispatch.dispatch_action(ctx.game, {}, {
    type = "item_slot_click",
    slot_index = slot_index,
    actor_role_id = player.id,
    input_source = "touch",
  }, nil)
end

function driver.tile_indices_in_range(ctx, position, range)
  return board_query.indices_in_range(ctx.game.board, position, range)
end

-- Seat `player` on the outer ring facing forward. Used to give the AI item-phase a
-- concrete board position from which its trigger predicates (e.g. obstacles ahead)
-- evaluate over real movement geometry.
function driver.seat_on_ring(ctx, player)
  return _seat_facing_forward(ctx, player, ctx.game.board.map.start_id)
end

-- Seat `player` on the ring and place a roadblock a couple of tiles ahead on the path,
-- so the AI's clear-obstacles trigger (strategy.has_obstacles_ahead) fires through the
-- real board scan rather than a flag. Returns the obstacle tile id.
function driver.seat_with_obstacle_ahead(ctx, player)
  local seat_id = driver.seat_on_ring(ctx, player)
  local map = ctx.game.board.map
  local ahead = map.outer_next[map.outer_next[seat_id]]
  driver.place_roadblock(ctx, ahead)
  return ahead
end

function driver.roll_dice(ctx, player, dice_count)
  local override = player.status and player.status.pending_remote_dice
    and player.status.pending_remote_dice.values
  local results, raw_total = roll_module._roll_dice(dice_count, override, ctx.game.rng)
  local total = dice_mult.apply_roll_total(ctx.game, raw_total, player)
  event_feed.publish(ctx.game, {
    kind = event_kinds.dice_roll,
    text = player.name .. " 投骰: [" .. table.concat(results, ",") .. "] => " .. tostring(total),
    tip = true,
  })
  ctx.game.last_turn = ctx.game.last_turn or {}
  ctx.game.last_turn.rolls = results
  ctx.game.last_turn.total = total
  ctx.game.last_turn.raw_total = raw_total
  if override then
    ctx.game:set_player_status(player, "pending_remote_dice", nil)
  end
  local mult = player.status and player.status.pending_dice_multiplier or 1
  if mult > 1 then
    ctx.game:set_player_status(player, "pending_dice_multiplier", 1)
  end
  return results, raw_total, total
end

function driver.apply_remote_dice(ctx, player, dice_count, value)
  local values = {}
  for i = 1, dice_count do values[i] = value end
  ctx.game:set_player_status(player, "pending_remote_dice", { values = values })
end

function driver.set_dice_multiplier(ctx, player, mult)
  ctx.game:set_player_status(player, "pending_dice_multiplier", mult)
end

function driver.last_rolls(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.rolls
end

function driver.last_total(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.total
end

function driver.last_raw_total(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.raw_total
end

-- ── chance / endgame settlement verbs (#200) ─────────────────────────────────
-- 机会卡多人转账与胜利判定走真实 src 结算链,步骤只做声明式调用,不再在
-- 步骤体内循环转账或 fixture 判定。

-- 机会卡「向每位玩家支付 amount」:真实 charge + 破产链(payer 侧故意不守恒,
-- 每个收款人拿满,语义见 src.rules.chance.cash_handlers)。
function driver.chance_pay_others(ctx, player, amount)
  chance_handlers.build().pay_others(ctx.game, player, { amount = amount })
end

-- 机会卡「从每位玩家收取 amount」:真实 transfer(守恒、按流动性封顶)+ 破产链。
function driver.chance_collect_from_others(ctx, player, amount)
  chance_handlers.build().collect_from_others(ctx.game, player, { amount = amount })
end

-- 真实胜利条件判定;返回结构化结果(是否终局、唯一胜者、胜者列表)供步骤断言。
function driver.check_victory(ctx)
  endgame_rules.check_victory(ctx.game)
  return {
    finished = ctx.game.finished == true,
    winner = ctx.game.winner,
    winners = ctx.game.winners,
  }
end

-- 玩家总资产观察(现金 + 地块总投入),供胜利判定断言。
function driver.player_total_assets(ctx, player)
  return asset_total.player_total(ctx.game, player)
end

return driver
