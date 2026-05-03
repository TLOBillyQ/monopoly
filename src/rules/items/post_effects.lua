local constants = require("src.config.content.constants")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.lang.number")
local obstacle_clear = require("src.rules.items.obstacle_clear")

local post_effects = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local target_item_order = {
  item_ids.share_wealth,
  item_ids.exile,
  item_ids.tax,
  item_ids.invite_deity,
  item_ids.send_poor,
  item_ids.poor,
}

local function _should_emit_share_wealth_cash_receive(context)
  local mode = context and context.share_wealth_cash_receive_mode or nil
  if mode == "item_target_player_only" then
    return false
  end
  return not (context and context.suppress_cash_receive_anim == true)
end

local function _build_exile_log_entry(user, target)
  return user.name
    .. " 使用流放卡，将 "
    .. target.name
    .. " 送往深山，停留 "
    .. number_utils.format_integer_part(constants.mountain_stay_turns)
    .. " 回合"
end

local target_effects = {
  [item_ids.share_wealth] = {
    apply = function(game, user, target, context)
      if game:angel_immune_to_item(target, item_ids.share_wealth) then
        event_feed.publish(game, {
          kind = event_kinds.item_immune,
          text = target.name .. " 有天使，均富无效",
        })
        return true
      end
      local user_cash = game:player_balance(user, "金币")
      local target_cash = game:player_balance(target, "金币")
      local total = user_cash + target_cash
      local half = math.floor(total / 2)
      local user_delta = half - user_cash
      local target_delta = (total - half) - target_cash
      local should_emit_cash_receive = _should_emit_share_wealth_cash_receive(context)
      if should_emit_cash_receive and type(game.add_player_cash) == "function" then
        game:add_player_cash(user, user_delta)
        game:add_player_cash(target, target_delta)
      else
        game:set_player_cash(user, half)
        game:set_player_cash(target, total - half)
      end
      event_feed.publish(game, {
        kind = event_kinds.equality_card,
        text = user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金",
      })
      return true
    end,
  },
  [item_ids.exile] = {
    apply = function(game, user, target)
      if game:angel_immune_to_item(target, item_ids.exile) then
        event_feed.publish(game, {
          kind = event_kinds.item_immune,
          text = target.name .. " 有天使，流放无效",
        })
        return true
      end
      local idx = game.board:find_first_by_type("mountain")
      local from_index = target.position
      local queued = false
      local log_entry = _build_exile_log_entry(user, target)
      if idx then
        idx = game:player_relocate(target, {
          destination_index = idx,
          move_dir_mode = "clear",
        })
        queued = action_anim_port.queue(game, {
          kind = "teleport_effect",
          player_id = target.id,
          from_index = from_index,
          to_index = idx,
          duration = action_anim_duration,
        })
      end
      if queued then
        return {
          ok = true,
          action_anim = true,
          after_action_anim = {
            next_state = "move_followup",
            next_args = {
              mode = "apply_location_effects",
              log_entries = { log_entry },
              effects = {
                { player_id = target.id, effect = "mountain" },
              },
            },
          },
        }
      end
      event_feed.publish(game, {
        kind = event_kinds.item_used,
        text = log_entry,
      })
      game:player_apply_mountain_effects(target)
      return true
    end,
  },
  [item_ids.tax] = {
    apply = function(game, user, target)
      if game:angel_immune_to_item(target, item_ids.tax) then
        event_feed.publish(game, {
          kind = event_kinds.item_immune,
          text = target.name .. " 有天使，查税无效",
        })
        return true
      end
      local tax_free_idx = inventory.find_index(target, item_ids.tax_free)
      if tax_free_idx then
        inventory.remove_by_index(target, tax_free_idx)
        event_feed.publish(game, {
          kind = event_kinds.tax_immune,
          text = target.name .. " 使用免税卡抵消查税",
        })
        return true
      end
      local fee = math.floor(game:player_balance(target, "金币") * 0.5)
      game:deduct_player_cash(target, fee)
      event_feed.publish(game, {
        kind = event_kinds.tax_card,
        text = user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. number_utils.format_integer_part(fee) .. " 税金",
      })
      if game:player_balance(target, "金币") <= 0 then
        bankruptcy_port.eliminate(game, target, { reason = target.name .. " 支付查税费用后破产" })
      end
      return true
    end,
  },
  [item_ids.invite_deity] = {
    filter_target = function(game, _, target)
      return game:player_has_any_deity(target)
    end,
    apply = function(game, user, target)
      local target_type = target.status.deity.type
      game:transfer_deity(target, user)
      event_feed.publish(game, {
        kind = event_kinds.deity_evicted,
        text = user.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. target_type,
      })
      return true
    end,
  },
  [item_ids.send_poor] = {
    require_user = function(game, user)
      if not game:player_has_deity(user, "poor") then
        return false
      end
      return true
    end,
    apply = function(game, user, target)
      assert(game:player_has_deity(user, "poor"),
        "send_poor.apply: user must have effective poor deity")
      game:transfer_deity(user, target)
      event_feed.publish(game, {
        kind = event_kinds.deity_transferred,
        text = user.name .. " 使用送神卡，将穷神送给 " .. target.name,
      })
      return true
    end,
  },
  [item_ids.poor] = {
    apply = function(game, user, target)
      game:set_player_deity(target, "poor", constants.deity_duration_turns)
      event_feed.publish(game, {
        kind = event_kinds.deity_attached,
        text = user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身",
      })
      return true
    end,
  },
}

local post_effects_cfg = {

  [item_ids.free_rent] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [item_ids.dice_multiplier] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [item_ids.tax_free] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },


  [item_ids.mine] = { type = "place_mine_here" },
  [item_ids.clear_obstacles] = { type = "clear_obstacles_ahead", distance = 12 },


  [item_ids.steal] = { type = "log", message = " 准备偷窃（将在经过玩家时触发）" },
  [item_ids.strong] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },


  [item_ids.rich] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [item_ids.angel] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
}

local handlers = {}

local function _handle_set_status(game, player, cfg)
  local value = assert(cfg.value, "missing status value")
  game:set_player_status(player, cfg.key, value)
  if cfg.message then
    event_feed.publish(game, {
      kind = event_kinds.item_used,
      text = player.name .. cfg.message,
    })
  end
  return true
end

local function _handle_deity(game, player, cfg)
  game:set_player_deity(player, cfg.deity, constants.deity_duration_turns)
  if cfg.log then
    event_feed.publish(game, {
      kind = event_kinds.deity_attached,
      text = player.name .. cfg.log,
    })
  end
  return true
end

local function _handle_log(game, player, cfg)
  assert(cfg.message ~= nil, "missing log message")
  event_feed.publish(game, {
    kind = event_kinds.item_used,
    text = player.name .. cfg.message,
  })
  return true
end

local function _handle_place_mine_here(game, player)
  game:place_mine(player.position, {
    owner_id = player.id,
    armed = true,
    placed_turn_count = game.turn and game.turn.turn_count or nil,
    owner_turn_started_count_at_placement = player
      and player.status
      and player.status.own_turn_started_count
      or 0,
  })
  event_feed.publish(game, {
    kind = event_kinds.mine_placed,
    text = player.name .. " 在脚下埋设地雷",
  })
  local queued = action_anim_port.queue(game, {
    kind = "mine",
    player_id = player.id,
    tile_index = player.position,
    duration = action_anim_duration,
  })
  if queued then
    return { ok = true, action_anim = true }
  end
  return true
end

local function _handle_clear_obstacles_ahead(game, player, cfg, context)
  return obstacle_clear.handle(game, player, cfg, context)
end

handlers.set_status = _handle_set_status
handlers.deity = _handle_deity
handlers.log = _handle_log
handlers.place_mine_here = _handle_place_mine_here
handlers.clear_obstacles_ahead = _handle_clear_obstacles_ahead

function post_effects.get_target_spec(item_id)
  return target_effects[item_id]
end

function post_effects.target_item_ids()
  return target_item_order
end

function post_effects.apply_target(game, user, item_id, target, context)
  assert(user ~= nil and target ~= nil, "missing user/target")
  assert(user.id ~= target.id,
         "apply_target: user and target must differ (item_id=" .. tostring(item_id) .. ")")
  local spec = target_effects[item_id]
  assert(spec ~= nil and spec.apply ~= nil, "missing target spec: " .. tostring(item_id))
  return spec.apply(game, user, target, context)
end

function post_effects.apply_post(game, player, item_id, context)
  context = context or {}
  local cfg = assert(post_effects_cfg[item_id], "missing post effect: " .. tostring(item_id))
  local handler = assert(handlers[cfg.type], "missing post effect handler: " .. tostring(cfg.type))
  return handler(game, player, cfg, context)
end

return post_effects
