local logger = require("src.core.utils.logger")
local inventory = require("src.rules.items.inventory")
local use_skip_choice = require("src.core.choice.use_skip_choice")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.core.ports.action_anim")
local tip_output = require("src.rules.ports.tip_output")
local auto_play_port = require("src.rules.ports.auto_play")

local steal = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _show_tip(game, text, dedupe_key)
  return tip_output.enqueue(game, {
    text = text,
    duration = action_anim_duration,
    dedupe_key = dedupe_key,
    blocks_inter_turn = false,
    source = "rules.items.steal",
  })
end

local function _fail_popup(game, stealer, target)
  local msg = "很遗憾，" .. target.name .. " 没有任何道具。"
  local log_text = stealer.name .. " 使用偷窃卡失败：" .. msg
  logger.event(log_text)
  _show_tip(game, log_text, "steal_fail:" .. tostring(stealer.id) .. ":" .. tostring(target.id))
  return {
    ok = false,
  }
end

function steal.steal_item_at_index(game, player, target, item_idx)
  inventory.consume(player, item_ids.steal)
  if inventory.count(target) == 0 then
    return _fail_popup(game, player, target)
  end
  local stolen = inventory.remove_by_index(target, item_idx or 1)
  assert(stolen ~= nil, "missing stolen item")
  assert(inventory.add(player, stolen) == true, "add stolen item failed")
  local name = inventory.item_name(stolen.id)
  local log_text = player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name
  logger.event(log_text)
  _show_tip(game, log_text, "steal_success:" .. tostring(player.id) .. ":" .. tostring(target.id) .. ":" .. tostring(stolen.id))
  local queued = action_anim_port.queue(game, {
    kind = "item_target_player",
    player_id = player.id,
    target_player_id = target.id,
    item_id = item_ids.steal,
    item_name = "偷窃卡",
    duration = action_anim_duration,
  })
  return {
    ok = true,
    stolen = stolen,
    action_anim = queued,
  }
end

function steal.build_prompt_spec(game, player, queue, index)
  assert(queue ~= nil, "missing queue")
  local target_id = assert(queue[index], "missing target id")
  assert(player ~= nil, "missing player")
  local target = assert(game:find_player_by_id(target_id), "missing target player: " .. tostring(target_id))
  local choice = use_skip_choice.build(
    "steal_prompt",
    "是否使用偷窃卡",
    { "目标：" .. target.name },
    { player_id = player.id, target_id = target.id, queue = queue, index = index },
    { skip = "跳过" }
  )
  choice.confirm_title = "偷窃卡"
  choice.confirm_body = "目标：" .. target.name
  return choice
end

function steal.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  if inventory.find_index(player, item_ids.steal) == nil then
    return
  end

  local queue = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = assert(game:find_player_by_id(target_id), "missing target player: " .. tostring(target_id))
    if not t.eliminated and not game:player_has_deity(t, "angel") then
      table.insert(queue, t.id)
    end
  end
  if #queue == 0 then
    return
  end

  if auto_play_port.is_auto_player(game, player) then
    local target = assert(game:find_player_by_id(queue[1]), "missing target player")
    return steal.steal_item_at_index(game, player, target, 1)
  end

  local spec = steal.build_prompt_spec(game, player, queue, 1)
  assert(spec ~= nil, "missing steal prompt spec")
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = spec,
    },
  }
end

return steal
