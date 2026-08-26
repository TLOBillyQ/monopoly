local constants = require("src.config.content.constants")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")
local angel_feedback = require("src.rules.items.angel_feedback")
local target_cash_effects = require("src.rules.items.target_cash_effects")
local steal = require("src.rules.items.steal")
local demolish = require("src.rules.items.demolish")

local target_effects = {}
-- timing 是静态配置,action_anim_default_seconds 键恒在,`or 1.0` 是死防御(#259 删除)。
local action_anim_duration = timing.action_anim_default_seconds

-- 请神卡只请正面神灵：穷神持有者与无神灵者都不进候选面（deities_008/009/010）。
local invitable_deities = { rich = true, angel = true }

local target_item_order = {
  item_ids.steal,
  item_ids.missile,
  item_ids.share_wealth,
  item_ids.exile,
  item_ids.tax,
  item_ids.invite_deity,
  item_ids.send_poor,
  item_ids.poor,
}

local function _build_exile_log_entry(user, target)
  return user.name
    .. " 使用流放卡，将 "
    .. target.name
    .. " 送往深山，停留 "
    .. number_utils.format_integer_part(constants.mountain_stay_turns)
    .. " 回合"
end

local specs = {
  [item_ids.steal] = {
    filter_target = function(_, _, target)
      return inventory.count(target) > 0
    end,
    apply = function(game, user, target, context)
      return steal.steal_random_item(game, user, target, context and context.commit_item_use or nil)
    end,
  },
  [item_ids.missile] = {
    apply = function(game, user, target)
      return demolish.apply(game, user, target.position, {
        item_id = item_ids.missile,
        injure = true,
        title = "导弹卡",
      })
    end,
  },
  [item_ids.share_wealth] = target_cash_effects.share_wealth,
  [item_ids.exile] = {
    apply = function(game, user, target)
      if game:angel_immune_to_item(target, item_ids.exile) then
        angel_feedback.publish(game, target, "流放")
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
  [item_ids.tax] = target_cash_effects.tax,
  [item_ids.invite_deity] = {
    filter_target = function(game, _, target)
      return invitable_deities[game:player_deity_type(target)] == true
    end,
    apply = function(game, user, target)
      local target_type = game:player_deity_type(target)
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

function target_effects.get(item_id)
  return specs[item_id]
end

function target_effects.ids()
  return target_item_order
end

return target_effects

--[[ mutate4lua-manifest
version=4
projectHash=e4bbc4ec885e7ac3
scope.0.id=chunk:src/rules/items/target_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=161
scope.0.semanticHash=894c3af9dc4cfd4d
scope.1.id=function:_build_exile_log_entry
scope.1.kind=function
scope.1.startLine=32
scope.1.endLine=39
scope.1.semanticHash=d885e46c83d85462
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=43
scope.2.endLine=45
scope.2.semanticHash=846a984e8b37333f
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=48
scope.3.semanticHash=021ea701d169c02b
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=57
scope.4.semanticHash=27b0294ae02b2bc3
scope.5.id=function:<anonymous>#4
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=105
scope.5.semanticHash=20961cadc656833a
scope.6.id=function:<anonymous>#5
scope.6.kind=function
scope.6.startLine=109
scope.6.endLine=111
scope.6.semanticHash=b4b82c53029ec3cf
scope.7.id=function:<anonymous>#6
scope.7.kind=function
scope.7.startLine=112
scope.7.endLine=120
scope.7.semanticHash=057f832d41596096
scope.8.id=function:<anonymous>#7
scope.8.kind=function
scope.8.startLine=123
scope.8.endLine=128
scope.8.semanticHash=c82d3609f6d8398e
scope.9.id=function:<anonymous>#8
scope.9.kind=function
scope.9.startLine=129
scope.9.endLine=138
scope.9.semanticHash=09ef6e641d7931a8
scope.10.id=function:<anonymous>#9
scope.10.kind=function
scope.10.startLine=141
scope.10.endLine=148
scope.10.semanticHash=a419140bb7b5edd1
scope.11.id=function:target_effects.get
scope.11.kind=function
scope.11.startLine=152
scope.11.endLine=154
scope.11.semanticHash=fc8eda1d7903d2b1
scope.12.id=function:target_effects.ids
scope.12.kind=function
scope.12.startLine=156
scope.12.endLine=158
scope.12.semanticHash=1136505bd37c301e
]]
