-- turn_flow acceptance steps — driven against the REAL turn machine.
--
-- Every step routes through the turn_driver / game_driver facades over a shared ctx
-- (ADR 0017 D1.1): rotation / elimination / detention / temporal reset run through
-- src/turn/*; landing settlement, choice deadlines, inter-turn waits, the item-target
-- timer and the AI item / landing decisions all read real src state. There is no
-- world.turn fixture and no AI_ITEM_PRIORITY / AI_TRIGGER_KNOWN copy: the AI priority,
-- per-card triggers and choice timeouts come solely from src (strategy.lua, the item
-- config's offer_in_phases, scope_timeouts, choice_auto). Assertions read real game
-- state — tile ownership, cash, inventory, phase order, deadline levels.

local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local turn_driver = require("tools.acceptance.turn_driver")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")

local turn_flow_steps = {}

-- A standard land tile on the outer ring (福州路) we re-price for deterministic rent.
local _RENT_TILE_ID = 1

-- ── ctx accessors ─────────────────────────────────────────────────────────────

local function _ctx(world) return world.driver end
local function _game(world) return world.driver.game end
local function _p(world, i) return world.driver.game.players[i] end

-- In the AI scenarios seat 2 is the computer player and seat 1 a human opponent.
local function _ai(world) return _p(world, 2) end
local function _opp(world) return _p(world, 1) end

-- (Re)create an all-human game of `count` players — turn-lifecycle scenarios want
-- deterministic human turns (no AI auto-resolution mid-drive). The background already
-- seeded a default-AI ctx; lifecycle scenarios overwrite it here so they never depend
-- on it. Returns the ctx.
local function _human_game(world, count)
  local names = {}
  for i = 1, count do names[i] = "玩家" .. tostring(i) end
  world.driver = game_driver.new_game({ players = names, ai = {} })
  return world.driver
end

-- (Re)create the default game where seats 2..4 are computer players (the AI scenarios).
local function _ai_game(world)
  world.driver = game_driver.new_game()
  return world.driver
end

-- ── outer-ring seating helpers (real map geometry, no teleport-onto) ───────────

local function _seat_forward(world, player, index)
  local game = _game(world)
  local map = game.board.map
  game:update_player_position(player, index)
  local tile_id = game.board:get_tile(index).id
  if map.outer_next[tile_id] then
    game:set_player_status(player, "move_dir", map.direction(tile_id, map.outer_next[tile_id]))
  end
end

local function _first_tile_of_type(world, tile_type)
  for i = 1, _ctx(world).outer_ring_size do
    local tile = _game(world).board:get_tile(i)
    if tile and tile.type == tile_type then return i end
  end
  return nil
end

-- Seat `player` `back` ring steps before the first tile of `tile_type`, facing forward,
-- so that tile lies just ahead — used to satisfy "道具格 within range" AI triggers.
local function _seat_before_type(world, player, tile_type, back)
  local game = _game(world)
  local map = game.board.map
  local id = game.board:get_tile(assert(_first_tile_of_type(world, tile_type), "no " .. tile_type .. " tile")).id
  for _ = 1, back do id = map.outer_prev[id] end
  _seat_forward(world, player, game.board:index_of_tile_id(id))
end

-- Set up the rent tile: opponent (player 2) owns _RENT_TILE_ID at a deterministic price,
-- and player 1 is seated one step before it with a queued roll of 1 so the real move+land
-- path settles rent. Returns player 1.
local function _seat_for_rent(world)
  local p1 = _p(world, 1)
  game_driver.set_tile_owner(_ctx(world), _RENT_TILE_ID, _p(world, 2).id)
  local tile = _game(world).board:get_tile_by_id(_RENT_TILE_ID)
  tile.price = 1000
  tile.level = 0
  game_driver.seat_before_tile(_ctx(world), p1, _RENT_TILE_ID)
  game_driver.set_next_rolls(_ctx(world), { 1 })
  return p1
end

-- Open a real black-market purchase choice by passing through a sold-out market.
local function _open_market_choice(world)
  local p1 = _p(world, 1)
  game_driver.set_market_sold_out(_ctx(world))
  game_driver.seat_to_pass_through_market(_ctx(world), p1)
  return turn_driver.advance_to_choice(_ctx(world))
end

-- Open a real 普通 choice (rent-card prompt): opponent owns the rent tile and player 1
-- holds a seizure card, so landing raises the rent_card_prompt choice.
local function _open_normal_choice(world)
  local p1 = _seat_for_rent(world)
  game_driver.give_item(_ctx(world), p1, item_ids.strong)
  return turn_driver.advance_to_choice(_ctx(world))
end

-- ── AI per-card trigger maps (scenario 22) ────────────────────────────────────
-- The card-name -> item id map is the only Chinese<->id binding here; the priority and
-- the trigger predicates live entirely in src (strategy.lua / the agent). "其他卡" maps
-- to a plain auto-usable card (mine) — used whenever held, no trigger condition.
local _AI_CARD_IDS = {
  ["遥控骰子卡"] = item_ids.remote_dice,
  ["路障卡"] = item_ids.roadblock,
  ["偷窃卡"] = item_ids.steal,
  ["怪兽卡"] = item_ids.monster,
  ["均富卡"] = item_ids.share_wealth,
  ["流放卡"] = item_ids.exile,
  ["导弹卡"] = item_ids.missile,
  ["查税卡"] = item_ids.tax,
  ["请神卡"] = item_ids.invite_deity,
  ["送神卡"] = item_ids.send_poor,
  ["穷神卡"] = item_ids.poor,
  ["其他卡"] = item_ids.mine,
}

-- Each trigger-condition string maps to a board setup that makes the REAL strategy
-- predicate fire for that card (verified against src). The condition string is the
-- single key; the setup composes real game state (positions, ownership, cash, deities).
local function _build_trigger_setups()
  return {
    -- remote dice / roadblock: an item tile (道具格) ahead within range.
    ["移动范围内存在道具格"] = function(world)
      _seat_before_type(world, _ai(world), "item", 2)
    end,
    ["前方存在道具格"] = function(world)
      _seat_before_type(world, _ai(world), "item", 2)
    end,
    -- steal: another player holding at least one item.
    ["存在持有道具的其他玩家"] = function(world)
      inventory.add(_opp(world), { id = item_ids.mine })
    end,
    -- monster / missile: an opponent-owned, leveled building within 3 tiles.
    ["前后3格内存在他人等级最高的建筑"] = function(world)
      local game = _game(world)
      _seat_forward(world, _ai(world), 5)
      local map = game.board.map
      local id = game.board:get_tile(5).id
      id = map.outer_next[map.outer_next[id]]
      local tile = game.board:get_tile(game.board:index_of_tile_id(id))
      tile.type = "land"
      game:set_tile_owner(tile, _opp(world).id)
      tile.level = 2
    end,
    -- share_wealth: the AI is not the richest -> a richer opponent exists.
    ["电脑玩家不是现金最多的角色"] = function(world)
      _game(world):set_player_cash(_opp(world), 999999)
    end,
    -- exile / tax / poor: another player is the richest cash holder.
    ["存在其他现金最多的角色"] = function(world)
      _game(world):set_player_cash(_opp(world), 999999)
    end,
    -- invite_deity: another player carries an angel deity.
    ["其他角色附有天使"] = function(world)
      _game(world):set_player_deity(_opp(world), "angel", 5)
    end,
    -- invite_deity: another player carries a 财神 (rich) deity and nobody has an angel.
    ["其他角色附有财神且无人附有天使"] = function(world)
      _game(world):set_player_deity(_opp(world), "rich", 5)
    end,
    -- send_poor: the AI carries the 穷神 (poor) deity and a richer opponent exists.
    ["电脑玩家附有穷神且存在现金最多对手"] = function(world)
      _game(world):set_player_deity(_ai(world), "poor", 5)
      _game(world):set_player_cash(_opp(world), 999999)
    end,
    -- 其他卡 (mine): always usable, no board condition.
    ["道具当前可用"] = function() end,
  }
end

-- ── phase-name mapping (scenario 5) ───────────────────────────────────────────
local _PHASE_TOKENS = {
  ["开始"] = "start",
  ["等待行动"] = "wait_action",
  ["掷骰"] = "roll",
  ["移动"] = "move",
  ["落地"] = "landing",
  ["结束"] = "end_turn",
}

local function _seq_contains_in_order(seq, tokens)
  local cursor = 1
  for _, observed in ipairs(seq) do
    if observed == tokens[cursor] then
      cursor = cursor + 1
      if cursor > #tokens then return true end
    end
  end
  return false
end

-- Warning-level label mapping (scenario 14): Chinese level -> src deadline level.
local _WARN_LEVELS = { ["警告"] = "warn_5s", ["紧急"] = "warn_3s", ["到期"] = "expired" }
-- Choice-type label -> the real pending_choice.kind it opens (scenario 9).
local _CHOICE_KINDS = {
  ["普通选择"] = "rent_card_prompt",
  ["黑市购买"] = "market_buy",
  ["道具目标选择"] = "item_target_player",
}

function turn_flow_steps.handlers()
  local trigger_setups = _build_trigger_setups()

  return {
    -- ── 轮转 (scenario 0) ──────────────────────────────────────────────────────
    ["游戏有<玩家人数>名玩家参与"] = function(world, example)
      local count = number_utils.to_integer(example["玩家人数"])
      if count == nil then return nil, "invalid player count: " .. tostring(example["玩家人数"]) end
      _human_game(world, count)
      return true
    end,

    ["游戏当前玩家数为<验证玩家人数>名"] = function(world, example)
      local expected = number_utils.to_integer(example["验证玩家人数"])
      local actual = turn_driver.participant_count(_ctx(world))
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " players, got " .. tostring(actual)
      end
      return true
    end,

    ["当前是玩家<当前玩家>的回合"] = function(world, example)
      turn_driver.set_current_player(_ctx(world), number_utils.to_integer(example["当前玩家"]))
      return true
    end,

    ["回合结束"] = function(world)
      turn_driver.play_turn(_ctx(world))
      return true
    end,

    ["下一回合轮到玩家<下一玩家>"] = function(world, example)
      local expected = number_utils.to_integer(example["下一玩家"])
      local actual = turn_driver.current_player_index(_ctx(world))
      if actual ~= expected then
        return nil, "expected player " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    -- ── 淘汰跳过 (scenario 1) ──────────────────────────────────────────────────
    ["玩家2已被淘汰"] = function(world)
      -- Game-preserving precondition shared with the deities suite, which sets a deity
      -- on player 2 BEFORE eliminating them then asserts an eliminated player's deity
      -- does not decrement. Creating a fresh game here would wipe that deity, so
      -- eliminate in whatever game the scenario (or its background) already built, only
      -- seeding a default game if none exists. The turn-flow elimination-skip scenario
      -- needs a *full human* table instead and uses its own phrase below.
      if not world.driver then
        _ai_game(world)
      end
      turn_driver.eliminate(_ctx(world), _p(world, 2))
      return true
    end,

    ["四人human局中玩家2已被淘汰"] = function(world)
      -- The elimination-skip rotation scenario drives real played turns, so it needs a
      -- full 4-player human table (no AI auto-play diverting the rotation): rebuild the
      -- background game as all-human before eliminating player 2.
      _human_game(world, 4)
      turn_driver.eliminate(_ctx(world), _p(world, 2))
      return true
    end,

    ["当前是玩家1的回合"] = function(world)
      turn_driver.set_current_player(_ctx(world), 1)
      return true
    end,

    ["玩家1的回合结束"] = function(world)
      turn_driver.play_turn(_ctx(world))
      return true
    end,

    ["跳过玩家2直接轮到玩家3"] = function(world)
      local actual = turn_driver.current_player_index(_ctx(world))
      if actual ~= 3 then return nil, "expected player 3, got " .. tostring(actual) end
      return true
    end,

    -- ── 扣留 (scenarios 2, 3) ──────────────────────────────────────────────────
    ["玩家需停留<剩余回合>回合"] = function(world, example)
      local turns = number_utils.to_integer(example["剩余回合"])
      if turns == nil then return nil, "invalid detained turns: " .. tostring(example["剩余回合"]) end
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      turn_driver.detain(_ctx(world), _p(world, 1), turns)
      world.detained = _p(world, 1)
      world.position_before = world.detained.position
      return true
    end,

    ["该玩家的回合开始"] = function(world)
      -- Drive the detained player's turn and record the real phase sequence.
      world.detain_seq = turn_driver.observe_turn_phases(_ctx(world))
      return true
    end,

    ["玩家无法掷骰和移动"] = function(world)
      for _, phase in ipairs(world.detain_seq or {}) do
        if phase == "roll" or phase == "move" then
          return nil, "a detained player must not reach roll/move, saw " .. phase
        end
      end
      if world.detained.position ~= world.position_before then
        return nil, "a detained player must not move"
      end
      return true
    end,

    ["剩余停留回合变为<减后回合>"] = function(world, example)
      local expected = number_utils.to_integer(example["减后回合"])
      local actual = turn_driver.stay_turns(_ctx(world), world.detained)
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " remaining, got " .. tostring(actual)
      end
      return true
    end,

    ["回合直接结束"] = function(world)
      local seq = world.detain_seq or {}
      local saw_start, saw_end = false, false
      for _, phase in ipairs(seq) do
        if phase == "start" then saw_start = true end
        if phase == "end_turn" then saw_end = true end
      end
      if not (saw_start and saw_end) then
        return nil, "a detained turn must still run start -> end_turn"
      end
      return true
    end,

    ["玩家剩余停留回合为1"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      turn_driver.detain(_ctx(world), _p(world, 1), 1)
      world.detained = _p(world, 1)
      return true
    end,

    ["该玩家的扣留回合结束"] = function(world)
      turn_driver.play_turn(_ctx(world)) -- the single detained turn clears stay_turns
      return true
    end,

    ["下一次轮到该玩家"] = function(world)
      -- Play around the table until the detained player is up again.
      for _ = 1, turn_driver.participant_count(_ctx(world)) do
        if turn_driver.current_player_index(_ctx(world)) == 1 then break end
        turn_driver.play_turn(_ctx(world))
      end
      if turn_driver.current_player_index(_ctx(world)) ~= 1 then
        return nil, "rotation did not return to the detained player"
      end
      return true
    end,

    ["玩家可以正常掷骰"] = function(world)
      local player = world.detained
      if turn_driver.stay_turns(_ctx(world), player) ~= 0 then
        return nil, "detention should have expired"
      end
      local position_before = player.position
      turn_driver.play_turn(_ctx(world))
      if player.position == position_before then
        return nil, "after detention expires the player should roll and move"
      end
      return true
    end,

    -- ── 临时态清除 (scenario 4) ────────────────────────────────────────────────
    ["玩家本回合使用了遥控骰子"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      -- A small remote-dice value keeps the turn's move on the outer ring (an even
      -- total can route through the off-ring black market, whose paid gateway the
      -- acceptance compose does not wire). The scenario only needs the effect present.
      game_driver.apply_remote_dice(_ctx(world), _p(world, 1), 1, 1)
      return true
    end,

    ["玩家本回合触发了骰子加倍卡"] = function(world)
      game_driver.set_dice_multiplier(_ctx(world), _p(world, 1), 2)
      return true
    end,

    ["玩家的回合结束"] = function(world)
      turn_driver.play_turn(_ctx(world))
      return true
    end,

    ["遥控骰子效果被清除"] = function(world)
      if turn_driver.pending_remote_dice(_ctx(world), _p(world, 1)) ~= nil then
        return nil, "remote dice should be cleared at end of turn"
      end
      return true
    end,

    ["骰子加倍倍率重置为1"] = function(world)
      local mult = turn_driver.dice_multiplier(_ctx(world), _p(world, 1))
      if mult ~= 1 then return nil, "multiplier should reset to 1, got " .. tostring(mult) end
      return true
    end,

    -- ── 阶段序 (scenario 5) ────────────────────────────────────────────────────
    ["玩家未被扣留且未被淘汰"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      return true
    end,

    ["玩家的回合开始"] = function(world)
      world.phase_seq = turn_driver.observe_turn_phases(_ctx(world))
      return true
    end,

    ["依次经过阶段<阶段序列>"] = function(world, example)
      local tokens = {}
      for name in tostring(example["阶段序列"]):gmatch("[^→]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        local token = _PHASE_TOKENS[trimmed]
        if token == nil then return nil, "unknown phase name: " .. tostring(trimmed) end
        tokens[#tokens + 1] = token
      end
      if not _seq_contains_in_order(world.phase_seq or {}, tokens) then
        return nil, "real phase order does not contain the expected milestones in order"
      end
      return true
    end,

    -- ── 落地结算: 黑市售罄 / 免租 / 强夺 (scenarios 6, 7, 8) ────────────────────
    ["玩家落在黑市格"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.market_id = game_driver.seat_to_land_on_market(_ctx(world), _p(world, 1))
      return true
    end,

    ["黑市所有商品已售罄"] = function(world)
      game_driver.set_market_sold_out(_ctx(world))
      return true
    end,

    ["回合落地结算执行"] = function(world)
      world.p1_cash_before = game_driver.player_cash(_ctx(world), _p(world, 1))
      world.landing_choice = turn_driver.advance_to_choice(_ctx(world))
      return true
    end,

    ["不弹出购买选择"] = function(world)
      if world.landing_choice ~= nil then
        return nil, "a sold-out market must raise no purchase choice"
      end
      return true
    end,

    ["回合直接进入结束阶段"] = function(world)
      if turn_driver.pending_choice(_ctx(world)) ~= nil then
        return nil, "turn should proceed to the end phase, not stall on a choice"
      end
      local landed = _game(world).board:get_tile(_p(world, 1).position)
      if not (landed and landed.id == world.market_id) then
        return nil, "the player should have landed on the market tile"
      end
      return true
    end,

    ["玩家本回合落在对手拥有的地块"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      _seat_for_rent(world)
      return true
    end,

    ["玩家持有免租卡"] = function(world)
      game_driver.give_item(_ctx(world), _p(world, 1), item_ids.free_rent)
      return true
    end,

    ["免租卡被自动消耗"] = function(world)
      if game_driver.has_item(_ctx(world), _p(world, 1), item_ids.free_rent) then
        return nil, "the free-rent card should be auto-consumed"
      end
      return true
    end,

    ["不需要玩家手动选择"] = function(world)
      if world.landing_choice ~= nil then
        return nil, "a lone free-rent card must not raise a manual choice"
      end
      return true
    end,

    ["玩家不支付租金"] = function(world)
      local now = game_driver.player_cash(_ctx(world), _p(world, 1))
      if now ~= world.p1_cash_before then
        return nil, "no rent should be paid (cash changed " .. tostring(world.p1_cash_before) ..
          " -> " .. tostring(now) .. ")"
      end
      return true
    end,

    ["玩家同时持有强夺卡和免租卡"] = function(world)
      game_driver.give_item(_ctx(world), _p(world, 1), item_ids.strong)
      game_driver.give_item(_ctx(world), _p(world, 1), item_ids.free_rent)
      return true
    end,

    ["先弹出强夺卡使用提示"] = function(world)
      local choice = world.landing_choice
      if not (choice and choice.kind == "rent_card_prompt" and choice.meta
          and choice.meta.card_kind == "strong") then
        return nil, "the seizure (strong) card prompt should be raised first"
      end
      return true
    end,

    ["若玩家拒绝强夺则自动消耗免租卡"] = function(world)
      turn_driver.resolve_choice(_ctx(world), "skip")
      if not game_driver.has_item(_ctx(world), _p(world, 1), item_ids.strong) then
        return nil, "declining the seizure should keep the strong card"
      end
      if game_driver.has_item(_ctx(world), _p(world, 1), item_ids.free_rent) then
        return nil, "declining the seizure should auto-consume the free-rent card"
      end
      return true
    end,

    -- ── 选择超时自动决定 (scenario 9) ──────────────────────────────────────────
    ["玩家面临<选择类型>选择"] = function(world, example)
      local label = example["选择类型"]
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.choice_label = label
      world.is_target_select = false
      if label == "普通选择" then
        world.opened_choice = _open_normal_choice(world)
      elseif label == "黑市购买" then
        world.opened_choice = _open_market_choice(world)
      elseif label == "道具目标选择" then
        local p1 = _p(world, 1)
        game_driver.give_item(_ctx(world), p1, item_ids.steal)
        inventory.add(_p(world, 2), { id = item_ids.mine })
        world.opened_choice = turn_driver.open_target_item_choice(_ctx(world), p1, item_ids.steal)
        world.is_target_select = true
      else
        return nil, "unknown choice type: " .. tostring(label)
      end
      return true
    end,

    ["当前选择类型为<验证选择类型>"] = function(world, example)
      local expected_kind = _CHOICE_KINDS[example["验证选择类型"]]
      local choice = turn_driver.pending_choice(_ctx(world))
      if not (choice and choice.kind == expected_kind) then
        return nil, "expected choice kind " .. tostring(expected_kind) ..
          ", got " .. tostring(choice and choice.kind)
      end
      return true
    end,

    ["超时时间为<超时秒数>秒"] = function(world, example)
      world.expected_timeout = number_utils.to_integer(example["超时秒数"])
      return true
    end,

    ["选择超时配置为<验证超时秒数>秒"] = function(world, example)
      local expected = number_utils.to_integer(example["验证超时秒数"])
      local actual = turn_driver.choice_timeout_seconds(_ctx(world))
      if actual ~= expected then
        return nil, "expected configured timeout " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家在超时时间内未操作"] = function(world)
      local timeout = world.expected_timeout or turn_driver.choice_timeout_seconds(_ctx(world))
      world.original_choice_kind = turn_driver.pending_choice(_ctx(world)).kind
      if world.is_target_select then
        turn_driver.arm_target_select_deadline(_ctx(world))
        turn_driver.elapse_target_select_deadline(_ctx(world), timeout - 5) -- remaining 5
        world.warn_level = turn_driver.target_select_deadline_level(_ctx(world))
        turn_driver.elapse_target_select_deadline(_ctx(world), 6) -- past expiry
      else
        turn_driver.arm_choice_deadline(_ctx(world))
        turn_driver.elapse_choice_deadline(_ctx(world), timeout - 5) -- remaining 5
        world.warn_level = turn_driver.choice_deadline_level(_ctx(world))
        turn_driver.elapse_choice_deadline(_ctx(world), 6) -- past expiry
      end
      return true
    end,

    ["系统在剩余<警告秒数>秒时发出警告"] = function(world, example)
      local warn_at = number_utils.to_integer(example["警告秒数"])
      if warn_at ~= 5 then return nil, "expected the 5s warning threshold, got " .. tostring(warn_at) end
      if world.warn_level ~= "warn_5s" then
        return nil, "expected a 5s warning level, got " .. tostring(world.warn_level)
      end
      return true
    end,

    ["超时后自动执行默认选项"] = function(world)
      local choice = turn_driver.pending_choice(_ctx(world))
      if choice and choice.kind == world.original_choice_kind then
        return nil, "the timed-out choice should have been auto-resolved"
      end
      return true
    end,

    -- ── 回合间等待 (scenario 10) ───────────────────────────────────────────────
    ["回合间等待时间已配置"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      return true
    end,

    ["当前玩家的回合结束"] = function(world)
      turn_driver.advance_to_inter_turn_wait(_ctx(world))
      return true
    end,

    ["经过等待间隔后下一玩家回合才开始"] = function(world)
      local seconds = turn_driver.inter_turn_wait_seconds(_ctx(world))
      if not (seconds and seconds > 0) then
        return nil, "a positive inter-turn interval should be configured"
      end
      if turn_driver.current_player_index(_ctx(world)) ~= 1 then
        return nil, "the next player must not start before the interval elapses"
      end
      turn_driver.elapse_inter_turn_wait(_ctx(world), seconds)
      if turn_driver.current_player_index(_ctx(world)) ~= 2 then
        return nil, "elapsing the interval should hand off to the next player"
      end
      return true
    end,

    -- ── 路障停留不致扣留 (scenario 11) ─────────────────────────────────────────
    ["玩家本回合因路障停止移动"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      local p1 = _p(world, 1)
      -- Place a roadblock two ring tiles ahead and roll past it: the real move phase
      -- stops the player at the roadblock this turn.
      local map = _game(world).board.map
      local here = _game(world).board:get_tile(p1.position).id
      local ahead = map.outer_next[map.outer_next[here]]
      game_driver.place_roadblock(_ctx(world), ahead)
      -- An odd roll keeps the move on the outer ring; the roadblock two tiles ahead
      -- still halts the player there (the rest of the roll is forfeit).
      game_driver.set_next_rolls(_ctx(world), { 5 })
      turn_driver.play_turn(_ctx(world))
      return true
    end,

    ["下一回合轮到该玩家"] = function(world)
      for _ = 1, turn_driver.participant_count(_ctx(world)) do
        if turn_driver.current_player_index(_ctx(world)) == 1 then break end
        turn_driver.play_turn(_ctx(world))
      end
      if turn_driver.current_player_index(_ctx(world)) ~= 1 then
        return nil, "rotation did not return to player 1"
      end
      return true
    end,

    ["玩家可以正常掷骰和移动"] = function(world)
      local p1 = _p(world, 1)
      if turn_driver.stay_turns(_ctx(world), p1) ~= 0 then
        return nil, "a roadblock stop must not detain the player"
      end
      local position_before = p1.position
      turn_driver.play_turn(_ctx(world))
      if p1.position == position_before then
        return nil, "the player should roll and move normally next turn"
      end
      return true
    end,

    ["不会被额外扣留"] = function(world)
      if turn_driver.stay_turns(_ctx(world), _p(world, 1)) ~= 0 then
        return nil, "a roadblock must not cause detention"
      end
      return true
    end,

    -- ── 温和跳过不扣金币 (scenario 12) ─────────────────────────────────────────
    ["玩家面临黑市购买选择"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.opened_choice = _open_market_choice(world)
      return true
    end,

    ["玩家当前金币为5000"] = function(world)
      _game(world):set_player_cash(_p(world, 1), 5000)
      world.coins_before = 5000
      return true
    end,

    ["超时未操作系统自动跳过"] = function(world)
      turn_driver.arm_choice_deadline(_ctx(world))
      turn_driver.elapse_choice_deadline(_ctx(world), 61) -- past the 60s market deadline
      return true
    end,

    ["玩家金币仍为5000"] = function(world)
      local now = game_driver.player_cash(_ctx(world), _p(world, 1))
      if now ~= 5000 then return nil, "expected 5000 coins, got " .. tostring(now) end
      return true
    end,

    -- ── 道具目标超时留存 (scenario 13, reframed) ───────────────────────────────
    ["玩家持有一张需指定目标的道具"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      game_driver.give_item(_ctx(world), _p(world, 1), item_ids.steal)
      inventory.add(_p(world, 2), { id = item_ids.mine }) -- a valid target exists
      return true
    end,

    ["玩家已发起使用但尚未选定目标"] = function(world)
      local choice = turn_driver.open_target_item_choice(_ctx(world), _p(world, 1), item_ids.steal)
      if not (choice and choice.kind == "item_target_player") then
        return nil, "using a target item should raise the target-select choice"
      end
      if not game_driver.has_item(_ctx(world), _p(world, 1), item_ids.steal) then
        return nil, "the item must not be pre-consumed before a target is applied"
      end
      return true
    end,

    ["目标选择超时系统自动取消"] = function(world)
      turn_driver.arm_target_select_deadline(_ctx(world))
      turn_driver.elapse_target_select_deadline(_ctx(world), 16) -- past the 15s target-select deadline
      return true
    end,

    ["该道具未被消耗仍在玩家背包"] = function(world)
      if not game_driver.has_item(_ctx(world), _p(world, 1), item_ids.steal) then
        return nil, "a target item is consumed only on apply — a timeout must leave it in the bag"
      end
      return true
    end,

    -- ── 分阶段警告 (scenario 14) ───────────────────────────────────────────────
    ["玩家面临选择且超时时间为<超时秒数>秒"] = function(world, example)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.expected_timeout = number_utils.to_integer(example["超时秒数"])
      world.opened_choice = _open_normal_choice(world)
      return true
    end,

    ["剩余时间降至<警告阈值>秒"] = function(world, example)
      local threshold = number_utils.to_integer(example["警告阈值"])
      local timeout = world.expected_timeout or turn_driver.choice_timeout_seconds(_ctx(world))
      turn_driver.arm_choice_deadline(_ctx(world))
      world.threshold = threshold
      if threshold > 0 then
        -- A warning threshold: the deadline is still live; read its latched level.
        turn_driver.elapse_choice_deadline(_ctx(world), timeout - threshold)
        world.warn_level = turn_driver.choice_deadline_level(_ctx(world))
      else
        -- 到期 (remaining 0): the real timeout fires and auto-resolves the choice — src
        -- removes the deadline entry on expiry, so 到期 is observed as the choice being
        -- resolved, not as a peekable level.
        world.original_kind = turn_driver.pending_choice(_ctx(world)).kind
        turn_driver.elapse_choice_deadline(_ctx(world), timeout + 1)
        local choice = turn_driver.pending_choice(_ctx(world))
        world.expired = (choice == nil) or (choice.kind ~= world.original_kind)
      end
      return true
    end,

    ["倒计时状态变为<警告级别>"] = function(world, example)
      if example["警告级别"] == "到期" then
        if not world.expired then
          return nil, "at 0 seconds the deadline should expire and auto-resolve the choice"
        end
        return true
      end
      local expected = _WARN_LEVELS[example["警告级别"]]
      if world.warn_level ~= expected then
        return nil, "expected level " .. tostring(expected) .. ", got " .. tostring(world.warn_level)
      end
      return true
    end,

    ["每个警告级别仅触发一次"] = function(world)
      if world.threshold == 0 then
        -- src latches the timeout once (fired_timeout): a further elapse must not
        -- re-open the resolved choice.
        turn_driver.elapse_choice_deadline(_ctx(world), 5)
        if not world.expired then return nil, "the expired timeout must stay resolved" end
        return true
      end
      -- A warning level latches once: re-reading without further elapse is stable.
      if turn_driver.choice_deadline_level(_ctx(world)) ~= world.warn_level then
        return nil, "a latched warning level should not change on re-read"
      end
      return true
    end,

    -- ── 关闭弹窗 (scenario 15) ──────────────────────────────────────────────────
    ["玩家面临选择且弹窗已打开"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.opened_choice = _open_normal_choice(world)
      if world.opened_choice == nil then return nil, "a choice popup should be open" end
      return true
    end,

    ["选择超时系统自动决定"] = function(world)
      turn_driver.arm_choice_deadline(_ctx(world))
      turn_driver.elapse_choice_deadline(_ctx(world), 16) -- past the 15s 普通 deadline
      return true
    end,

    ["选择弹窗被关闭"] = function(world)
      if turn_driver.pending_choice(_ctx(world)) ~= nil then
        return nil, "the choice popup should be closed after timeout"
      end
      return true
    end,

    ["待处理选择指示被清除"] = function(world)
      if turn_driver.pending_choice(_ctx(world)) ~= nil then
        return nil, "the pending-choice indicator should be cleared"
      end
      return true
    end,

    -- ── 黑市浏览计时器不暂停 (scenario 16) ─────────────────────────────────────
    ["玩家路过黑市且黑市窗口打开"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      world.opened_choice = _open_market_choice(world)
      if not (world.opened_choice and world.opened_choice.kind == "market_buy") then
        return nil, "a market-purchase window should be open"
      end
      turn_driver.arm_choice_deadline(_ctx(world))
      world.remaining_before = turn_driver.choice_deadline_remaining(_ctx(world))
      return true
    end,

    ["行动计时器运行中"] = function(world)
      if not (world.remaining_before and world.remaining_before > 0) then
        return nil, "the action timer should be running"
      end
      return true
    end,

    ["计时器继续倒计时不暂停"] = function(world)
      turn_driver.elapse_choice_deadline(_ctx(world), 5)
      local now = turn_driver.choice_deadline_remaining(_ctx(world))
      if not (now and now < world.remaining_before) then
        return nil, "the timer must keep counting down during market browsing"
      end
      return true
    end,

    -- ── 阻断性提示前不切换 (scenario 17) ───────────────────────────────────────
    ["当前玩家的回合已结束"] = function(world)
      _human_game(world, 4)
      turn_driver.set_current_player(_ctx(world), 1)
      turn_driver.reset_tips(_ctx(world))
      turn_driver.advance_to_inter_turn_wait(_ctx(world))
      return true
    end,

    ["正在显示阻断性游戏提示"] = function(world)
      turn_driver.hold_inter_turn_with_blocking_tip(_ctx(world))
      return true
    end,

    ["回合间等待时间到期"] = function(world)
      turn_driver.elapse_inter_turn_wait(_ctx(world), 5) -- well past the interval
      return true
    end,

    ["等待提示显示完毕后才切换到下一玩家回合"] = function(world)
      if turn_driver.current_player_index(_ctx(world)) ~= 1 then
        return nil, "a blocking prompt should hold the gate — the next player must not start"
      end
      turn_driver.reset_tips(_ctx(world))
      turn_driver.elapse_inter_turn_wait(_ctx(world), 5)
      if turn_driver.current_player_index(_ctx(world)) ~= 2 then
        return nil, "once the blocking prompt clears the wait should hand off"
      end
      return true
    end,

    -- ── 电脑玩家落地结算 (scenarios 18, 19, 20) ────────────────────────────────
    ["本回合行动玩家是电脑"] = function(world)
      _ai_game(world)
      turn_driver.set_current_player(_ctx(world), 2)
      if not turn_driver.is_ai(_ctx(world), _ai(world)) then
        return nil, "seat 2 should be a computer player"
      end
      return true
    end,

    ["电脑玩家持有充足金币"] = function(world)
      -- The default starting balance is ample; this just records the precondition.
      world.ai_cash_before = game_driver.player_cash(_ctx(world), _ai(world))
      return true
    end,

    ["电脑玩家落在无主地块"] = function(world)
      local ai = _ai(world)
      local idx = game_driver.first_land_tile(_ctx(world))
      game_driver.set_player_position(_ctx(world), ai, idx)
      world.ai_tile_idx = idx
      world.ai_cash_before = game_driver.player_cash(_ctx(world), ai)
      turn_driver.settle_landing(_ctx(world), ai)
      world.ai_landing_option = turn_driver.auto_resolve_landing_choice(_ctx(world))
      return true
    end,

    ["系统自动执行购买"] = function(world)
      if world.ai_landing_option ~= "buy_land" then
        return nil, "the AI should auto-buy the unowned tile, got " .. tostring(world.ai_landing_option)
      end
      if game_driver.tile_owner(_ctx(world), world.ai_tile_idx) ~= _ai(world).id then
        return nil, "the tile should now be owned by the AI"
      end
      if game_driver.player_cash(_ctx(world), _ai(world)) >= world.ai_cash_before then
        return nil, "the purchase should deduct cash"
      end
      return true
    end,

    ["电脑玩家落在自有可升级地块"] = function(world)
      local ai = _ai(world)
      local idx, tile_id = game_driver.first_land_tile(_ctx(world))
      game_driver.set_tile_owner(_ctx(world), tile_id, ai.id)
      game_driver.set_player_position(_ctx(world), ai, idx)
      world.ai_tile_idx = idx
      world.ai_level_before = game_driver.tile_level(_ctx(world), idx)
      world.ai_cash_before = game_driver.player_cash(_ctx(world), ai)
      turn_driver.settle_landing(_ctx(world), ai)
      world.ai_landing_option = turn_driver.auto_resolve_landing_choice(_ctx(world))
      return true
    end,

    ["系统自动执行升级"] = function(world)
      if world.ai_landing_option ~= "upgrade_land" then
        return nil, "the AI should auto-upgrade its own tile, got " .. tostring(world.ai_landing_option)
      end
      if game_driver.tile_level(_ctx(world), world.ai_tile_idx) <= world.ai_level_before then
        return nil, "the upgrade should raise the tile level"
      end
      if game_driver.player_cash(_ctx(world), _ai(world)) >= world.ai_cash_before then
        return nil, "the upgrade should deduct cash"
      end
      return true
    end,

    ["电脑玩家持有免租卡"] = function(world)
      game_driver.give_item(_ctx(world), _ai(world), item_ids.free_rent)
      return true
    end,

    ["电脑玩家落在需付租金的对手地块"] = function(world)
      local ai = _ai(world)
      local idx, tile_id = game_driver.first_land_tile(_ctx(world))
      game_driver.set_tile_owner(_ctx(world), tile_id, _opp(world).id)
      game_driver.set_player_position(_ctx(world), ai, idx)
      world.ai_cash_before = game_driver.player_cash(_ctx(world), ai)
      world.ai_landing_choice = turn_driver.settle_landing(_ctx(world), ai)
      return true
    end,

    ["系统自动消耗免租卡"] = function(world)
      if game_driver.has_item(_ctx(world), _ai(world), item_ids.free_rent) then
        return nil, "the AI should auto-consume the free-rent card"
      end
      if world.ai_landing_choice ~= nil then
        return nil, "免租 settles as a mandatory effect — no manual choice"
      end
      if game_driver.player_cash(_ctx(world), _ai(world)) ~= world.ai_cash_before then
        return nil, "the AI should pay no rent when免租 applies"
      end
      return true
    end,

    -- ── 电脑玩家道具阶段 (scenarios 21, 22, reframed) ───────────────────────────
    ["电脑玩家背包中持有满足触发条件的主动道具"] = function(world)
      local ai = _ai(world)
      -- A real, trigger-gated card: clear-obstacles fires only with an obstacle ahead.
      game_driver.give_item(_ctx(world), ai, item_ids.clear_obstacles)
      game_driver.seat_with_obstacle_ahead(_ctx(world), ai)
      world.ai_card_id = item_ids.clear_obstacles
      return true
    end,

    ["电脑玩家背包中持有<道具>"] = function(world, example)
      local name = example["道具"]
      local id = _AI_CARD_IDS[name]
      if id == nil then return nil, "unknown AI card: " .. tostring(name) end
      game_driver.give_item(_ctx(world), _ai(world), id)
      world.ai_card_id = id
      return true
    end,

    ["棋盘状态满足<触发条件>"] = function(world, example)
      local condition = example["触发条件"]
      local setup = trigger_setups[condition]
      if setup == nil then return nil, "unknown trigger condition: " .. tostring(condition) end
      setup(world)
      return true
    end,

    ["电脑玩家的道具使用阶段执行"] = function(world)
      local ai = _ai(world)
      -- Drive the real AI item-use strategy in both offer windows src uses; the AI holds
      -- only the one card, so only it can be consumed, in whichever window src allows.
      turn_driver.run_ai_item_phase(_ctx(world), ai, "pre_action")
      if game_driver.has_item(_ctx(world), ai, world.ai_card_id) then
        turn_driver.run_ai_item_phase(_ctx(world), ai, "post_action")
      end
      return true
    end,

    ["该道具被自动消耗"] = function(world)
      if game_driver.has_item(_ctx(world), _ai(world), world.ai_card_id) then
        return nil, "the triggered active item should have been consumed"
      end
      return true
    end,

    ["该<道具>被消耗"] = function(world, example)
      local id = _AI_CARD_IDS[example["道具"]]
      if game_driver.has_item(_ctx(world), _ai(world), id) then
        return nil, "the AI should have consumed " .. tostring(example["道具"])
      end
      return true
    end,
  }
end

return turn_flow_steps
