local intent_output_port = require("src.rules.ports.intent_output")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local logger = require("src.foundation.log.logger")
local steal = require("src.rules.items.steal")
local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

local function _open_steal_item_choice(game, stealer, target)
  local lines = {}
  local options = {}
  for index, item in ipairs(inventory.items(target)) do
    local label = inventory.item_name(item.id)
    table.insert(lines, index .. ". " .. label)
    table.insert(options, { id = index, label = label })
  end
  intent_output_port.open_choice(game, {
    kind = "steal_item",
    route_key = "player",
    owner_role_id = stealer.id,
    title = "选择要偷的道具",
    body_lines = lines,
    options = options,
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = stealer.id, target_id = target.id },
  })
end

function M.build(helpers)
  local complete = completions.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_steal_item(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local stealer = normalize.validate_item_player(game, choice.kind, meta)
    local target = normalize.validate_item_target(game, "target_id", meta)
    local result = steal.steal_item_at_index(game, stealer, target, index)
    if result == nil then
      logger.warn("steal_item resolved nil result:", tostring(index), tostring(target and target.id))
      return complete.followup_completion(game, choice, stealer, result)
    end
    intent_output_port.dispatch(game, result.intent or {})
    return complete.followup_completion(game, choice, stealer, result)
  end

  local function _handle_steal_prompt(game, choice, action)
    local meta = choice.meta
    local stealer = normalize.validate_item_player(game, choice.kind, meta)
    local target = normalize.validate_item_target(game, "target_id", meta)
    if target.eliminated then
      return finish_choice(game, false)
    end

    if action.option_id == "use" then
      if inventory.count(target) <= 1 then
        local result = steal.steal_item_at_index(game, stealer, target, 1)
        if result then
          intent_output_port.dispatch(game, result.intent or {})
        end
        return finish_choice(game, false)
      end
      _open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if inventory.find_index(stealer, item_ids.steal) and queue[next_index] then
      local spec = steal.build_prompt_spec(game, stealer, queue, next_index)
      assert(spec ~= nil, "missing steal prompt spec")
      intent_output_port.open_choice(game, spec)
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  return {
    steal_item = {
      required_meta = { "player_id", "target_id" },
      cancel = {
        resolve = function(game, choice)
          return complete.followup_cancel(game, choice)
        end,
      },
      normalize_meta = normalize.steal_meta,
      meta_validator = normalize.validate_steal_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id("steal_item", action)
      end,
      execute = _handle_steal_item,
    },
    steal_prompt = {
      required_meta = { "player_id", "target_id", "queue", "index" },
      cancel = { mode = "select_option", option_id = "skip" },
      normalize_meta = normalize.steal_prompt_meta,
      meta_validator = normalize.validate_steal_prompt_meta,
      execute = _handle_steal_prompt,
    },
  }
end

return M
