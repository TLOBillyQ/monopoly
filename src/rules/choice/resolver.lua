local logger = require("src.foundation.log")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local tables = require("src.foundation.tables")
local event_kinds = require("src.config.gameplay.event_kinds")
local dirty_tracker = require("src.state.dirty_tracker")

local choice_resolver = {}

local function _find_option_id(choice, target_option_id)
  return item_preconsume_policy.each_option(choice, function(_, option_id)
    if option_id == target_option_id then
      return option_id
    end
  end)
end

local function _choice_title(choice)
  if choice and choice.title and choice.title ~= "" then
    return choice.title
  end
  return "请选择"
end

local function _clear_choice(game)
  game.turn.pending_choice = nil
  dirty_tracker.mark(game.dirty, "turn")
end

local function _finish_choice(game, stay)
  _clear_choice(game)
  return { status = stay and "waiting" or "resolved", stay = stay }
end

local function _option_exists(choice, target_option_id)
  if choice == nil or target_option_id == nil then
    return false
  end
  return item_preconsume_policy.each_option(choice, function(_, option_id)
    if option_id == target_option_id or tostring(option_id) == tostring(target_option_id) then
      return true
    end
  end) == true
end

local function _build_select_action(choice, option_id, action)
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
    actor_role_id = action and action.actor_role_id or nil,
  }
end

local function _resolve_descriptor(game, choice)
  local registries = assert(game.registries, "missing game.registries")
  local choice_registry = assert(registries.choices, "missing choice registry")
  local descriptor = type(choice_registry.descriptor_for) == "function"
      and choice_registry:descriptor_for(choice.kind)
      or choice_registry.handlers[choice.kind]
  assert(descriptor ~= nil, "unknown choice kind: " .. tostring(choice.kind))
  assert(type(descriptor.execute) == "function", "invalid choice descriptor: " .. tostring(choice.kind))
  return descriptor
end

local function _resolve_cancel_followup(game, choice, descriptor)
  local cancel = descriptor and descriptor.cancel or nil
  if type(cancel) ~= "table" then
    return nil, nil
  end
  if cancel.mode == "select_option" then
    return _find_option_id(choice, cancel.option_id), nil
  end
  return nil, nil
end

local base_helpers = {
  is_cancel = item_preconsume_policy.is_cancel_action,
  clear_choice = _clear_choice,
  finish_choice = _finish_choice,
  contains = tables.contains,
}

function choice_resolver.helpers(overrides)
  local out = {}
  for key, value in pairs(base_helpers) do
    out[key] = value
  end
  for key, value in pairs(overrides or {}) do
    out[key] = value
  end
  return setmetatable(out, {
    __newindex = function()
      error("helpers is read-only")
    end,
    __metatable = false,
  })
end

local function _emit_skip_event(choice, opts)
  if opts and type(opts.on_event) == "function" then
    opts.on_event({
      kind = event_kinds.choice_skipped,
      text = "跳过选择：" .. _choice_title(choice),
      tip = false,
    })
  end
end

local function _handle_cancel_result(game, choice, cancel_result, descriptor, opts)
  if type(cancel_result) == "table" and cancel_result.stay then
    cancel_result.status = cancel_result.status or "waiting"
    return cancel_result
  end
  _emit_skip_event(choice, opts)
  _clear_choice(game)
  return { status = "resolved", stay = false }
end

local function _resolve_cancel_fallback(game, choice, action, descriptor, opts)
  local fallback_option_id, cancel_result = _resolve_cancel_followup(game, choice, descriptor)
  if fallback_option_id ~= nil then
    action = _build_select_action(choice, fallback_option_id, action)
    return nil, action
  end
  cancel_result = cancel_result or (descriptor.cancel and descriptor.cancel.resolve)
  if type(cancel_result) == "function" then
    cancel_result = cancel_result(game, choice)
  end
  return _handle_cancel_result(game, choice, cancel_result, descriptor, opts)
end

local function _try_cancel_action(game, choice, action, descriptor, opts)
  if not item_preconsume_policy.is_cancel_action(action) then return nil, action end
  local cancel_result, new_action = _resolve_cancel_fallback(game, choice, action, descriptor, opts)
  if cancel_result then return cancel_result, action end
  return nil, new_action
end

local function _maybe_normalize_action(game, choice, action, descriptor)
  if descriptor.normalize_action == nil then return action end
  local normalized = descriptor.normalize_action(game, choice, action)
  if normalized ~= nil then return normalized end
  return action
end

local function _build_resolve_result(result)
  if result and result.stay then
    result.status = result.status or "waiting"
    return result
  end
  return result or { status = "resolved", stay = false }
end

function choice_resolver.resolve(game, choice, action, opts)
  assert(game, "missing game")
  assert(choice, "missing choice")
  assert(action, "missing action")
  opts = opts or {}

  local descriptor = _resolve_descriptor(game, choice)
  action = item_preconsume_policy.normalize_cancel_action(choice, action)

  local early_result, new_action = _try_cancel_action(game, choice, action, descriptor, opts)
  if early_result then return early_result end
  action = new_action

  action = _maybe_normalize_action(game, choice, action, descriptor)

  if not _option_exists(choice, action.option_id) then
    logger.warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    return { status = "rejected", stay = true }
  end

  return _build_resolve_result(descriptor.execute(game, choice, action))
end

choice_resolver._M_test = {
  _contains = tables.contains,
}

return choice_resolver

--[[ mutate4lua-manifest
version=4
projectHash=6218e325bc22d91a
scope.0.id=chunk:src/rules/choice/resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=182
scope.0.semanticHash=b8c6acfc4e6c7821
scope.1.id=function:_find_option_id
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=0ad88539202badff
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=14
scope.2.semanticHash=f20c827a1b46315c
scope.3.id=function:_choice_title
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=22
scope.3.semanticHash=1a98eb4d8db6dee3
scope.4.id=function:_clear_choice
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=27
scope.4.semanticHash=62290946acedb105
scope.5.id=function:_finish_choice
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=32
scope.5.semanticHash=a36f4c04e7c85b75
scope.6.id=function:_option_exists
scope.6.kind=function
scope.6.startLine=34
scope.6.endLine=43
scope.6.semanticHash=347f7ba415d7b257
scope.7.id=function:<anonymous>#2
scope.7.kind=function
scope.7.startLine=38
scope.7.endLine=42
scope.7.semanticHash=9875e396c963c3cb
scope.8.id=function:_build_select_action
scope.8.kind=function
scope.8.startLine=45
scope.8.endLine=52
scope.8.semanticHash=f8dd8f931f2278d1
scope.9.id=function:_resolve_descriptor
scope.9.kind=function
scope.9.startLine=54
scope.9.endLine=63
scope.9.semanticHash=ceb407023e097df3
scope.10.id=function:_resolve_cancel_followup
scope.10.kind=function
scope.10.startLine=65
scope.10.endLine=74
scope.10.semanticHash=ce15b996ea562393
scope.11.id=function:choice_resolver.helpers
scope.11.kind=function
scope.11.startLine=83
scope.11.endLine=97
scope.11.semanticHash=b9f464c65dd9b4b1
scope.12.id=function:<anonymous>#3
scope.12.kind=function
scope.12.startLine=92
scope.12.endLine=94
scope.12.semanticHash=b1f16ed07f03ac7a
scope.13.id=function:_emit_skip_event
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=107
scope.13.semanticHash=b8aa2377a9697136
scope.14.id=function:_handle_cancel_result
scope.14.kind=function
scope.14.startLine=109
scope.14.endLine=117
scope.14.semanticHash=01dfdfa86763125b
scope.15.id=function:_resolve_cancel_fallback
scope.15.kind=function
scope.15.startLine=119
scope.15.endLine=130
scope.15.semanticHash=87f81d52a70c3da5
scope.16.id=function:_try_cancel_action
scope.16.kind=function
scope.16.startLine=132
scope.16.endLine=137
scope.16.semanticHash=a0449f9516b3865d
scope.17.id=function:_maybe_normalize_action
scope.17.kind=function
scope.17.startLine=139
scope.17.endLine=144
scope.17.semanticHash=1d80d2a6e046a402
scope.18.id=function:_build_resolve_result
scope.18.kind=function
scope.18.startLine=146
scope.18.endLine=152
scope.18.semanticHash=365a5c9d6f348802
scope.19.id=function:choice_resolver.resolve
scope.19.kind=function
scope.19.startLine=154
scope.19.endLine=175
scope.19.semanticHash=296dd291c472043b
]]
