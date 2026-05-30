local effect_runner = require("src.rules.effects.runner")
local intent_output_port = require("src.rules.ports.intent_output")
local number_utils = require("src.foundation.number")

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

local function _build_optional_confirm_copy(effect_id, tile_name, cost)
  if effect_id == "buy_land" then
    return "买地", "地块：" .. tostring(tile_name or "") .. "。要买吗？"
  end
  if effect_id == "upgrade_land" then
    local cost_text = number_utils.format_integer_part(cost or 0)
    return "加盖", "为 " .. tostring(tile_name or "") .. " 加盖，花费 " .. cost_text
  end
  return nil, nil
end

local function _resolve_optional_route(optional)
  if type(optional) ~= "table" or #optional == 0 then
    return nil, nil
  end
  if #optional == 1 then
    return "secondary_confirm", true
  end
  return "player", false
end

local function _build_optional_choice(optional, player, tile, game_ctx, opts)
  local body_lines = {}
  local options = {}
  local effect_ids = {}
  local cost_resolver = opts.optional_cost_resolver
  for _, eff in ipairs(optional) do
    local label = eff.label or eff.id
    local cost = cost_resolver and cost_resolver(eff.id, tile, game_ctx.game) or nil
    local confirm_title, confirm_body = _build_optional_confirm_copy(eff.id, tile and tile.name or nil, cost)
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

  local route_key, requires_confirm = _resolve_optional_route(optional)

  local choice_spec = {
    kind = opts.optional_choice_kind or "landing_optional_effect",
    owner_role_id = player.id,
    route_key = route_key,
    requires_confirm = requires_confirm == true,
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

local function _partition_scanned_effects(scanned, mandatory, optional)
  for _, entry in ipairs(scanned) do
    if entry.ok then
      local target = entry.mandatory and mandatory or optional
      table.insert(target, entry.effect)
    end
  end
end

local function _apply_need_landing(out, opts)
  if not (opts.on_need_landing and type(out) == "table" and out.kind == "need_landing") then
    return out
  end
  return opts.on_need_landing(out) or out
end

local function _dispatch_effect_payload(game, out, res)
  local payload = out or res
  if payload then
    intent_output_port.dispatch(game, payload)
  end
end

local function _finalize_waiting_output(out, opts)
  if type(out) ~= "table" or out.waiting ~= true then
    return nil
  end
  out.next_state = out.next_state or opts.next_state
  out.next_args = out.next_args or opts.next_args
  out.intent = nil
  return out
end

local function _run_mandatory_effect(mandatory_effect, player, tile, game_ctx, opts)
  local res = effect_runner.execute(mandatory_effect, player, tile, game_ctx)
  local out = _apply_need_landing(res and res.result, opts)
  _dispatch_effect_payload(game_ctx.game, out, res)

  local waiting = _finalize_waiting_output(out, opts)
  if waiting then
    return waiting, true
  end

  if opts.stop_if and opts.stop_if(out, res) then
    return out, true
  end

  return nil, false
end

local function _run_mandatory_effects(mandatory, player, tile, game_ctx, opts)
  for _, mandatory_effect in ipairs(mandatory) do
    local result, should_stop = _run_mandatory_effect(mandatory_effect, player, tile, game_ctx, opts)
    if should_stop then
      return result
    end
  end
  return nil
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

  _partition_scanned_effects(scanned, mandatory, optional)

  local mandatory_result = _run_mandatory_effects(mandatory, player, tile, game_ctx, opts)
  if mandatory_result ~= nil then
    return _finalize(mandatory_result)
  end

  if opts.allow_optional == false or #optional == 0 then
    return _finalize(nil)
  end

  return _finalize(_build_optional_choice(optional, player, tile, game_ctx, opts))
end

return pipeline

--[[ mutate4lua-manifest
version=2
projectHash=25e0cebfb4e8a5da
scope.0.id=chunk:src/rules/effects/pipeline.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=185
scope.0.semanticHash=efa6b3f8d19b9ae3
scope.1.id=function:_acquire_list:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=16
scope.1.semanticHash=2c8764122a96fa66
scope.2.id=function:_build_optional_confirm_copy:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=34
scope.2.semanticHash=6221cf4b413b932b
scope.3.id=function:_resolve_optional_route:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=44
scope.3.semanticHash=485a5a3d2340b812
scope.4.id=function:_apply_need_landing:107
scope.4.kind=function
scope.4.startLine=107
scope.4.endLine=112
scope.4.semanticHash=b678a268123f38dd
scope.5.id=function:_dispatch_effect_payload:114
scope.5.kind=function
scope.5.startLine=114
scope.5.endLine=119
scope.5.semanticHash=19a3c0384777c35e
scope.6.id=function:_finalize_waiting_output:121
scope.6.kind=function
scope.6.startLine=121
scope.6.endLine=129
scope.6.semanticHash=0d484ff6ebde347f
scope.7.id=function:_run_mandatory_effect:131
scope.7.kind=function
scope.7.startLine=131
scope.7.endLine=146
scope.7.semanticHash=56051cba2e1807ac
scope.8.id=function:_finalize:164
scope.8.kind=function
scope.8.startLine=164
scope.8.endLine=168
scope.8.semanticHash=5b915aedac7ad841
scope.9.id=function:pipeline.run:158
scope.9.kind=function
scope.9.startLine=158
scope.9.endLine=182
scope.9.semanticHash=5b4f2272046eceb8
]]
