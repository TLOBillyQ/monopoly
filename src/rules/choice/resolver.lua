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

local function _handle_cancel_result(game, choice, cancel_result, descriptor, opts)
  if type(cancel_result) == "table" and cancel_result.stay then
    cancel_result.status = cancel_result.status or "waiting"
    return cancel_result
  end
  if opts and type(opts.on_event) == "function" then
    opts.on_event({
      kind = event_kinds.choice_skipped,
      text = "跳过选择：" .. _choice_title(choice),
      tip = false,
    })
  end
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
version=2
projectHash=4443d921930bf9b5
scope.0.id=chunk:src/rules/choice/resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=178
scope.0.semanticHash=bedb4a7742cdab05
scope.1.id=function:anonymous@10:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=a2e403522f6659cb
scope.2.id=function:_find_option_id:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=15
scope.2.semanticHash=0423d4868c790090
scope.3.id=function:_choice_title:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=22
scope.3.semanticHash=cf7847b888f699b9
scope.4.id=function:_clear_choice:24
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=27
scope.4.semanticHash=04c8fd3736c85f8f
scope.5.id=function:_finish_choice:29
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=32
scope.5.semanticHash=1558f4bbd49ab417
scope.6.id=function:anonymous@38:38
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=42
scope.6.semanticHash=a305517e05480e85
scope.7.id=function:_option_exists:34
scope.7.kind=function
scope.7.startLine=34
scope.7.endLine=43
scope.7.semanticHash=c2389e7380111216
scope.8.id=function:_build_select_action:45
scope.8.kind=function
scope.8.startLine=45
scope.8.endLine=52
scope.8.semanticHash=96d708849188dcb6
scope.9.id=function:_resolve_descriptor:54
scope.9.kind=function
scope.9.startLine=54
scope.9.endLine=63
scope.9.semanticHash=45a255510e3603c4
scope.10.id=function:_resolve_cancel_followup:65
scope.10.kind=function
scope.10.startLine=65
scope.10.endLine=74
scope.10.semanticHash=27e38fd0e484dd88
scope.11.id=function:anonymous@92:92
scope.11.kind=function
scope.11.startLine=92
scope.11.endLine=94
scope.11.semanticHash=894927f13387af54
scope.12.id=function:_handle_cancel_result:99
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=113
scope.12.semanticHash=724a6d9ef29a3383
scope.13.id=function:_resolve_cancel_fallback:115
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=126
scope.13.semanticHash=7d0a9d2cf55875ac
scope.14.id=function:_try_cancel_action:128
scope.14.kind=function
scope.14.startLine=128
scope.14.endLine=133
scope.14.semanticHash=b5210c5da6926add
scope.15.id=function:_maybe_normalize_action:135
scope.15.kind=function
scope.15.startLine=135
scope.15.endLine=140
scope.15.semanticHash=777c713eb859348f
scope.16.id=function:_build_resolve_result:142
scope.16.kind=function
scope.16.startLine=142
scope.16.endLine=148
scope.16.semanticHash=8067ba3508d2c803
scope.17.id=function:choice_resolver.resolve:150
scope.17.kind=function
scope.17.startLine=150
scope.17.endLine=171
scope.17.semanticHash=4b5af83b1ea7bdad
]]
