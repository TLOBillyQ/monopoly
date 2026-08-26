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

local function _buy_land_confirm_copy(tile_name)
  return "买地", "地块：" .. tostring(tile_name or "") .. "。要买吗？"
end

local function _upgrade_land_confirm_copy(tile_name, cost)
  local cost_text = number_utils.format_integer_part(cost or 0)
  return "加盖", "为 " .. tostring(tile_name or "") .. " 加盖，花费 " .. cost_text
end

-- 只有买地/加盖有二次确认文案;其余可选 effect 不弹确认。
local function _build_optional_confirm_copy(effect_id, tile_name, cost)
  if effect_id == "buy_land" then
    return _buy_land_confirm_copy(tile_name)
  end
  if effect_id == "upgrade_land" then
    return _upgrade_land_confirm_copy(tile_name, cost)
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

local function _tile_name(tile)
  return tile and tile.name or nil
end

-- 返回 option 表与它的 label(label 同时进 body_lines,保持两处同源)。
local function _build_optional_option(eff, tile, game_ctx, cost_resolver)
  local label = eff.label or eff.id
  local cost = cost_resolver and cost_resolver(eff.id, tile, game_ctx.game) or nil
  local confirm_title, confirm_body = _build_optional_confirm_copy(eff.id, _tile_name(tile), cost)
  return {
    id = eff.id,
    label = label,
    confirm_title = confirm_title,
    confirm_body = confirm_body,
  }, label
end

local function _collect_optional_options(optional, tile, game_ctx, cost_resolver)
  local body_lines = {}
  local options = {}
  local effect_ids = {}
  for _, eff in ipairs(optional) do
    local option, label = _build_optional_option(eff, tile, game_ctx, cost_resolver)
    table.insert(body_lines, label)
    table.insert(options, option)
    table.insert(effect_ids, eff.id)
  end
  return body_lines, options, effect_ids
end

local function _build_optional_choice(optional, player, tile, game_ctx, opts)
  local body_lines, options, effect_ids =
    _collect_optional_options(optional, tile, game_ctx, opts.optional_cost_resolver)

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
version=4
projectHash=30d2add34b59a8ca
scope.0.id=chunk:src/rules/effects/pipeline.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=209
scope.0.semanticHash=de320e055c773790
scope.1.id=function:_acquire_list
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=16
scope.1.semanticHash=d18c056f03edcabe
scope.2.id=function:_release_list
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=ef6910f00506d648
scope.3.id=function:_buy_land_confirm_copy
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=10b5d023161c3819
scope.4.id=function:_upgrade_land_confirm_copy
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=32
scope.4.semanticHash=2f720ce9b9bc7b14
scope.5.id=function:_build_optional_confirm_copy
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=43
scope.5.semanticHash=dc7525996b2033e1
scope.6.id=function:_resolve_optional_route
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=53
scope.6.semanticHash=9b8a66a59d51e42d
scope.7.id=function:_tile_name
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=616a2ca60599c94f
scope.8.id=function:_build_optional_option
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=70
scope.8.semanticHash=d54cda733c947750
scope.9.id=function:_collect_optional_options
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=83
scope.9.semanticHash=416606be22a12e0c
scope.10.id=function:_build_optional_choice
scope.10.kind=function
scope.10.startLine=85
scope.10.endLine=120
scope.10.semanticHash=03d612d927083d18
scope.11.id=function:_partition_scanned_effects
scope.11.kind=function
scope.11.startLine=122
scope.11.endLine=129
scope.11.semanticHash=706f42e447d8c219
scope.12.id=function:_apply_need_landing
scope.12.kind=function
scope.12.startLine=131
scope.12.endLine=136
scope.12.semanticHash=4e992a8958cb8c34
scope.13.id=function:_dispatch_effect_payload
scope.13.kind=function
scope.13.startLine=138
scope.13.endLine=143
scope.13.semanticHash=5e6f2299b975f01c
scope.14.id=function:_finalize_waiting_output
scope.14.kind=function
scope.14.startLine=145
scope.14.endLine=153
scope.14.semanticHash=c82516cf21a76bcf
scope.15.id=function:_run_mandatory_effect
scope.15.kind=function
scope.15.startLine=155
scope.15.endLine=170
scope.15.semanticHash=caaef760ef16a203
scope.16.id=function:_run_mandatory_effects
scope.16.kind=function
scope.16.startLine=172
scope.16.endLine=180
scope.16.semanticHash=d5544ae71c18ccf0
scope.17.id=function:pipeline.run
scope.17.kind=function
scope.17.startLine=182
scope.17.endLine=206
scope.17.semanticHash=cf4d89a2adb968d2
scope.18.id=function:_finalize
scope.18.kind=function
scope.18.startLine=188
scope.18.endLine=192
scope.18.semanticHash=6740bc55df2cb33b
]]
