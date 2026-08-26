local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local chance_cfg = require("src.config.content.chance_cards")
local chance_resolver = require("src.rules.chance.resolver")
local presenter = require("src.rules.land.presenter")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")

local popup_show_seconds = timing.popup_dwell_default_seconds or 1.0

local M = {}

local function _build_weights(config)
  local weights = {}
  for i, cfg in ipairs(config) do
    weights[i] = math.max(0, cfg.weight or 0)
  end
  return weights
end

local chance_weights = _build_weights(chance_cfg)

local function _collect_drawable_cards()
  local drawable = {}
  local first_drawable = nil
  for i, card in ipairs(chance_cfg) do
    first_drawable = first_drawable or card
    table.insert(drawable, { index = i, card = card })
  end
  return drawable, first_drawable
end

local function _calc_total_weight(drawable)
  local total = 0
  for _, item in ipairs(drawable) do
    total = total + (chance_weights[item.index] or 0)
  end
  return total
end

local function _pick_weighted_card(drawable, total_weight, rng)
  assert(rng and type(rng.next_int) == "function", "missing game.rng.next_int for chance draw")
  local pick = rng:next_int(1, total_weight)
  local accumulated = 0
  for _, item in ipairs(drawable) do
    accumulated = accumulated + (chance_weights[item.index] or 0)
    if accumulated >= pick then return item.card end
  end
  return nil
end

local function _fallback_chance_card(first_drawable)
  if #chance_cfg == 0 then return nil end
  return first_drawable
end

local function _pick_chance_card(game)
  local drawable, first_drawable = _collect_drawable_cards()

  if first_drawable == nil then return nil end

  local total_weight = _calc_total_weight(drawable)
  if total_weight <= 0 then return first_drawable end

  local picked = _pick_weighted_card(drawable, total_weight, game and game.rng)
  if picked then return picked end

  return _fallback_chance_card(first_drawable)
end

M.executors = {
  chance_draw_and_resolve = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local card = _pick_chance_card(ctx.game) or chance_cfg[1]
      if not card then return end
      event_feed.publish(ctx.game, {
        kind = event_kinds.chance_card,
        text = ctx.player.name .. " 抽到机会卡 " .. card.description,
      })
      achievement_progress.chance_card_drawn(ctx.game, ctx.player)
      presenter.push_popup(ctx.game, "机会卡", ctx.player.name .. " 抽到机会卡：" .. card.description, {
        kind = "chance_card",
        image_ref = card.id,
        auto_close_seconds = popup_show_seconds,
        popup_opts = { policy = "defer" },
        broadcast = true,
      })
      presenter.queue_action_anim(ctx.game, {
        kind = "chance",
        player_id = ctx.player.id,
        card_id = card.id,
        card_desc = card.description,
        duration = popup_show_seconds,
      })
      return chance_resolver.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
}

M._build_weights = _build_weights
M._collect_drawable_cards = _collect_drawable_cards
M._calc_total_weight = _calc_total_weight

return M

--[[ mutate4lua-manifest
version=4
projectHash=fa7dd5c42dbdfab7
scope.0.id=chunk:src/rules/land/effect_chance.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=108
scope.0.semanticHash=e70aa284acc88575
scope.1.id=function:_build_weights
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=19
scope.1.semanticHash=6ba753fc9243dcb8
scope.2.id=function:_collect_drawable_cards
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=31
scope.2.semanticHash=4abbd7b3e80a33e1
scope.3.id=function:_calc_total_weight
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=7170552d57b095e9
scope.4.id=function:_pick_weighted_card
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=50
scope.4.semanticHash=e10cabf28666d2fd
scope.5.id=function:_fallback_chance_card
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=55
scope.5.semanticHash=b185908f54114d35
scope.6.id=function:_pick_chance_card
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=69
scope.6.semanticHash=05f73ea48d0800e1
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=75
scope.7.semanticHash=5478285cc23f89ec
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=99
scope.8.semanticHash=d801c58c430a6548
]]
