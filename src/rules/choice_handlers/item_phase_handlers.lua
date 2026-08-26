local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local intent_output_port = require("src.rules.ports.intent_output")
local completions = require("src.rules.choice_handlers.item_completions")
local normalize = require("src.rules.choice_handlers.item_normalize")

local phase_handlers = {}

local function _decorate_phase_followup(choice_spec, meta, item_id, player)
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
  choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
  choice_spec.meta.passive_origin = true
  item_phase.decorate_followup_choice_spec(choice_spec, meta)
end

local function _handle_passive_waiting_result(game, result, meta, player, item_id)
  local intent = result.intent or {}
  local choice_spec = intent.choice_spec
  if type(choice_spec) == "table" then
    _decorate_phase_followup(choice_spec, meta, item_id, player)
  end
  intent_output_port.dispatch(game, intent)
  return { stay = true }
end

local function _item_phase_handler(kind, execute_fn)
  return {
    required_meta = { "player_id", "phase" },
    cancel = {
      resolve = function(game, choice)
        item_phase.finish(game, choice.meta and choice.meta.phase or nil)
      end,
    },
    normalize_meta = normalize.item_phase_meta,
    meta_validator = normalize.validate_item_phase_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

function phase_handlers.build(helpers)
  local complete = completions.build(helpers)
  local begin_item_use = assert(helpers.begin_item_use, "missing begin_item_use helper")

  -- 「completion 收尾后这扇窗该不该清」只有一个裁决点:item_completions
  -- .settle_choice_window。直用道具与跟随选择道具走同一份判定。
  local settle_choice_window = complete.settle_choice_window

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = action.option_id

    local result = begin_item_use(game, player, item_id, { phase = meta.phase })
    assert(result ~= nil, "missing use_item result")
    if type(result) == "table" and result.waiting then
      return _handle_passive_waiting_result(game, result, meta, player, item_id)
    end

    if not (type(result) == "table" and result.ok == false) then
      availability.mark_effect_group_used(game, item_id)
    end
    return settle_choice_window(game, item_phase.resolve_completion(game, player, meta, result))
  end

  return {
    item_phase_passive = _item_phase_handler("item_phase_passive", _handle_item_phase_passive),
  }
end

return phase_handlers

--[[ mutate4lua-manifest
version=4
projectHash=f6e7168ef76ec530
scope.0.id=chunk:src/rules/choice_handlers/item_phase_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=2c7a9867d2dcae77
scope.1.id=function:_decorate_phase_followup
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=560359280a2e90a0
scope.2.id=function:_handle_passive_waiting_result
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=25
scope.2.semanticHash=85b54b2c71761d4b
scope.3.id=function:_item_phase_handler
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=42
scope.3.semanticHash=0d2155c22cfcb886
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=33
scope.4.semanticHash=47ea75c4e0ff5be4
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=3c26bf1ea8e4b724
scope.6.id=function:phase_handlers.build
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=72
scope.6.semanticHash=0f063a42e8bc3e2b
scope.7.id=function:_handle_item_phase_passive
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=67
scope.7.semanticHash=f5fa249646a34bde
]]
