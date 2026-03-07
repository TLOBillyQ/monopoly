local effect_runner = require("src.game.systems.effects.EffectRunner")
local intent_output_port = require("src.game.ports.IntentOutputPort")

local pipeline = {}

local list_pool = {}

local function _acquire_list()
  local list = list_pool[#list_pool]
  if list then
    list_pool[#list_pool] = nil
    return list
  end
  return {}
end

local function _release_list(list)
  for i = #list, 1, -1 do
    list[i] = nil
  end
  list_pool[#list_pool + 1] = list
end

local function _build_optional_confirm_copy(effect_id, tile_name)
  if effect_id == "buy_land" then
    return "买地", "地块：" .. tostring(tile_name or "") .. "。要买吗？"
  end
  if effect_id == "upgrade_land" then
    return "加盖", "地块：" .. tostring(tile_name or "") .. "。要加盖吗？"
  end
  return nil, nil
end

local function _uses_secondary_confirm_route(optional)
  if type(optional) ~= "table" or #optional == 0 then
    return false
  end
  for _, eff in ipairs(optional) do
    local effect_id = eff and eff.id or nil
    if effect_id ~= "buy_land" and effect_id ~= "upgrade_land" then
      return false
    end
  end
  return true
end

local function _build_optional_choice(optional, player, tile, game_ctx, opts)
  local body_lines = {}
  local options = {}
  local effect_ids = {}
  for _, eff in ipairs(optional) do
    local label = eff.label or eff.id
    local confirm_title, confirm_body = _build_optional_confirm_copy(eff.id, tile and tile.name or nil)
    table.insert(body_lines, label)
    table.insert(options, {
      id = eff.id,
      label = label,
      confirm_title = confirm_title,
      confirm_body = confirm_body,
    })
    table.insert(effect_ids, eff.id)
  end

  local meta = {
    effect_ids = effect_ids,
    player_id = player.id,
    tile_id = tile.id,
    move_result = game_ctx.move_result,
  }

  local choice_spec = {
    kind = opts.optional_choice_kind or "landing_optional_effect",
    owner_role_id = player.id,
    route_key = _uses_secondary_confirm_route(optional) and "secondary_confirm" or nil,
    requires_confirm = _uses_secondary_confirm_route(optional) and true or nil,
    title = opts.optional_title,
    body_lines = body_lines,
    options = options,
    allow_cancel = opts.optional_allow_cancel,
    cancel_label = opts.optional_cancel_label,
    meta = meta,
  }

  local out = {
    waiting = true,
    reason = opts.optional_reason or "optional_effect",
    next_state = opts.next_state,
    next_args = opts.next_args,
  }

  intent_output_port.open_choice(game_ctx.game, choice_spec)
  return out
end

function pipeline.run(effect_defs, player, tile, game_ctx, opts)
  opts = opts or {}
  local scanned = effect_runner.scan(effect_defs, player, tile, game_ctx)
  local mandatory = _acquire_list()
  local optional = _acquire_list()

  local function _finalize(result)
    _release_list(mandatory)
    _release_list(optional)
    return result
  end

  for _, entry in ipairs(scanned) do
    if entry.ok then
      if entry.mandatory then
        table.insert(mandatory, entry.effect)
      else
        table.insert(optional, entry.effect)
      end
    end
  end

  for _, eff in ipairs(mandatory) do
    local res = effect_runner.execute(eff, player, tile, game_ctx)
    local out = res and res.result

    if opts.on_need_landing and type(out) == "table" and out.kind == "need_landing" then
      out = opts.on_need_landing(out) or out
    end

    local payload = out or res
    if payload then
      intent_output_port.dispatch(game_ctx.game, payload)
    end

    if type(out) == "table" and out.waiting then
      out.next_state = out.next_state or opts.next_state
      out.next_args = out.next_args or opts.next_args
      out.intent = nil
      return _finalize(out)
    end

    if opts.stop_if and opts.stop_if(out, res) then
      return _finalize(out)
    end
  end

  if opts.allow_optional == false or #optional == 0 then
    return _finalize(nil)
  end

  return _finalize(_build_optional_choice(optional, player, tile, game_ctx, opts))
end

return pipeline
