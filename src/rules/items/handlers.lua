local logger = require("src.foundation.log")
local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local inventory = require("src.rules.items.inventory")
local number_utils = require("src.foundation.number")
local event_kinds = require("src.config.gameplay.event_kinds")
local roadblock = require("src.rules.items.roadblock")
local remote_dice = require("src.rules.items.remote_dice")
local demolish = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local board_query = require("src.rules.board.query")

local handlers = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _resolve_apply_ok(res)
  if type(res) == "table" then
    if type(res.ok) == "boolean" then
      return res.ok
    end
    return true
  end
  return res == true
end

local function _queue_target_player_anim(game, user, item_id, target)
  return action_anim_port.queue(game, {
    kind = "item_target_player",
    player_id = user.id,
    target_player_id = target.id,
    item_id = item_id,
    item_name = inventory.item_name(item_id),
    duration = action_anim_duration,
  })
end

local function _apply_target_player_item(game, user, item_id, target, context)
  context = context or {}
  if item_id == item_ids.share_wealth then
    context.share_wealth_cash_receive_mode = "item_target_player_only"
    context.suppress_cash_receive_anim = true
  end
  local apply_res = effects.apply_target(game, user, item_id, target, context)
  local ok = _resolve_apply_ok(apply_res)
  if not ok then
    return apply_res
  end
  if context.item_preconsumed ~= true and not (type(apply_res) == "table" and apply_res.item_consumed == true) then
    assert(inventory.consume(user, item_id) == true, "consume target item failed: " .. tostring(item_id))
  end
  local already_queued = type(apply_res) == "table" and apply_res.action_anim
  local queued = (not already_queued) and _queue_target_player_anim(game, user, item_id, target)
  if type(apply_res) == "table" then
    apply_res.ok = true
    if queued then
      apply_res.action_anim = true
    end
    return apply_res
  end
  return { ok = true, action_anim = queued }
end

local function _run_item_choice_flow(game, player, item_id, context, opts)
  context = context or {}
  local candidates = assert(opts.candidates(game, player, item_id, context), "missing candidates")
  if #candidates == 0 then
    if opts.on_empty then
      opts.on_empty(game, player, item_id, context)
    end
    return false
  end

  if context.by_ai then
    assert(opts.ai_select ~= nil, "missing ai_select")
    return opts.ai_select(game, player, item_id, candidates, context)
  end

  assert(opts.choice_spec ~= nil, "missing choice_spec")
  local choice_spec = assert(opts.choice_spec(game, player, item_id, candidates, context), "missing choice_spec")
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = choice_spec,
    },
  }
end

function handlers.handle_target_player_item(game, player, item_id, context)
  context = context or {}
  local resolve_candidates = context.resolve_target_candidates
  assert(resolve_candidates ~= nil, "missing resolve_target_candidates")
  if context.target_id then
    local target = game:find_player_by_id(context.target_id)
    if not target or target.id == player.id or target.eliminated then
      logger.warn("目标玩家无效:", tostring(context.target_id))
      return false
    end
    local candidates = resolve_candidates(game, player, item_id)
    local matched = false
    for _, cand in ipairs(candidates) do
      if cand.id == target.id then
        matched = true
        break
      end
    end
    if not matched then
      logger.warn("目标玩家不在可选列表中:", tostring(context.target_id))
      return false
    end
    return _apply_target_player_item(game, player, item_id, target, context)
  end

  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = resolve_candidates,
    on_empty = function()
      logger.warn("没有可选择的目标玩家")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local target = auto_play_port.pick_target_player(inner_game, inner_player, inner_item_id, candidates)
      assert(target ~= nil, "missing target player")
      return _apply_target_player_item(inner_game, inner_player, inner_item_id, target, context)
    end,
    choice_spec = function(inner_game, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      local slot_layout = {}
      local seat_by_role_id = {}
      for seat, p in ipairs(inner_game.players or {}) do
        seat_by_role_id[p.id] = seat
      end
      for i, t in ipairs(candidates) do
        local deity_text = ""
        if t.status.deity then
          deity_text = " 神:" .. t.status.deity.type
        end
        local cash_text = number_utils.format_integer_part(game:player_balance(t, "金币"))
        table.insert(body_lines, t.name .. " 现金:" .. cash_text .. deity_text)
        table.insert(options, { id = t.id, label = t.name })
        slot_layout[i] = seat_by_role_id[t.id] or i
      end
      return {
        kind = "item_target_player",
        route_key = "player",
        pre_confirm_on_select = false,
        owner_role_id = inner_player.id,
        title = inventory.item_name(inner_item_id) .. "：选择目标玩家",
        body_lines = body_lines,
        options = options,
        target_slot_layout = slot_layout,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { item_id = inner_item_id, player_id = inner_player.id },
      }
    end,
  })
end

function handlers.handle_remote_dice(game, player, item_id, context)
  local dice_count = game:player_dice_count(player)
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function()
      return { 1, 2, 3, 4, 5, 6 }
    end,
    ai_select = function(inner_game, inner_player, inner_item_id)
      local value, target_tile = auto_play_port.pick_remote_dice_value(inner_game, inner_player, dice_count)
      assert(value ~= nil, "missing remote dice value")
      assert(inventory.consume(inner_player, inner_item_id) == true, "consume remote dice failed")
      local apply_res = remote_dice.apply(inner_game, inner_player, dice_count, value)
      if _resolve_apply_ok(apply_res) and target_tile then
        event_feed.publish(inner_game, {
          kind = event_kinds.remote_dice,
          text = inner_player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. number_utils.format_integer_part(value),
        })
      end
      return apply_res
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, value in ipairs(candidates) do
        table.insert(options, { id = value, label = tostring(value) })
        table.insert(body_lines, "点数 " .. number_utils.format_integer_part(value))
      end
      return {
        kind = "remote_dice_value",
        route_key = "remote",
        pre_confirm_on_select = false,
        owner_role_id = inner_player.id,
        title = "遥控骰子：选择点数",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { player_id = inner_player.id, item_id = inner_item_id, dice_count = dice_count },
      }
    end,
  })
end

function handlers.handle_roadblock(game, player, item_id, context)
  context = context or {}
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player, _, inner_context)
      if inner_context.by_ai then
        return roadblock.auto_candidates(inner_game, inner_player, 3)
      end
      return roadblock.manual_candidates(inner_game, inner_player, 3)
    end,
    on_empty = function(_, inner_player)
      -- migrated as DEV: internal candidate resolution failure, no player-visible state change occurred
      logger.info(inner_player.name .. " 无可放置路障的位置")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local best = roadblock.pick_best(candidates)
      assert(best ~= nil and best.idx ~= nil, "missing roadblock target")
      local idx = best.idx
      assert(inventory.consume(inner_player, inner_item_id) == true, "consume roadblock failed")
      return roadblock.apply(inner_game, inner_player, idx)
    end,
    choice_spec = function(inner_game, inner_player, inner_item_id, candidates)
      local flat_options = {}
      local body_lines = {}
      for _, cand in ipairs(candidates) do
        table.insert(flat_options, { id = cand.idx, label = cand.label })
        table.insert(body_lines, cand.label)
      end
      local options, slot_layout = board_query.arrange_target_options(inner_game.board, inner_player, flat_options)
      return {
        kind = "roadblock_target",
        route_key = "target",
        owner_role_id = inner_player.id,
        title = "路障卡：选择位置",
        body_lines = body_lines,
        options = options,
        target_slot_layout = slot_layout,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { player_id = inner_player.id, item_id = inner_item_id },
      }
    end,
  })
end

local demolish_items = {
  [item_ids.monster] = { title = "怪兽卡", injure = false },
  [item_ids.missile] = { title = "导弹卡", injure = true },
}

function handlers.handle_demolish(game, player, item_id, context)
  context = context or {}
  local cfg = assert(demolish_items[item_id], "missing demolish cfg: " .. tostring(item_id))
  return demolish.use(game, player, 3, inventory.consume, {
    item_id = item_id,
    injure = cfg.injure,
    title = cfg.title,
    by_ai = context.by_ai,
  })
end

return handlers

--[[ mutate4lua-manifest
version=2
projectHash=cc2959f7227d433f
scope.0.id=chunk:src/rules/items/handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=265
scope.0.semanticHash=ae7a1da0bce37fa4
scope.1.id=function:_resolve_apply_ok:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=27
scope.1.semanticHash=2cc394890489e66e
scope.2.id=function:_queue_target_player_anim:29
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=38
scope.2.semanticHash=2f0d5f311c2b0876
scope.3.id=function:_apply_target_player_item:40
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=64
scope.3.semanticHash=8c817c7efb021bd0
scope.4.id=function:_run_item_choice_flow:66
scope.4.kind=function
scope.4.startLine=66
scope.4.endLine=90
scope.4.semanticHash=6cd113763d727da6
scope.5.id=function:anonymous@119:119
scope.5.kind=function
scope.5.startLine=119
scope.5.endLine=121
scope.5.semanticHash=feeb6324f9439c8c
scope.6.id=function:anonymous@122:122
scope.6.kind=function
scope.6.startLine=122
scope.6.endLine=126
scope.6.semanticHash=4a9abe9b8f49acd1
scope.7.id=function:anonymous@165:165
scope.7.kind=function
scope.7.startLine=165
scope.7.endLine=167
scope.7.semanticHash=56d6b7cdaf3befce
scope.8.id=function:anonymous@168:168
scope.8.kind=function
scope.8.startLine=168
scope.8.endLine=180
scope.8.semanticHash=2b5e1e77a47e7534
scope.9.id=function:anonymous@181:181
scope.9.kind=function
scope.9.startLine=181
scope.9.endLine=202
scope.9.semanticHash=9fa047b05de17b69
scope.10.id=function:anonymous@207:207
scope.10.kind=function
scope.10.startLine=207
scope.10.endLine=212
scope.10.semanticHash=dde1543641e898c3
scope.11.id=function:anonymous@213:213
scope.11.kind=function
scope.11.startLine=213
scope.11.endLine=216
scope.11.semanticHash=06acd6cb99daa648
scope.12.id=function:anonymous@217:217
scope.12.kind=function
scope.12.startLine=217
scope.12.endLine=223
scope.12.semanticHash=e582cdaae2408b75
scope.13.id=function:anonymous@224:224
scope.13.kind=function
scope.13.startLine=224
scope.13.endLine=246
scope.13.semanticHash=fa7cc696e99b4cb0
scope.14.id=function:handlers.handle_demolish:253
scope.14.kind=function
scope.14.startLine=253
scope.14.endLine=262
scope.14.semanticHash=6bb67340908cdc5e
]]
