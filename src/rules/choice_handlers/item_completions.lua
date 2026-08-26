local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local normalize = require("src.rules.choice_handlers.item_normalize")

local completions = {}

function completions.build(helpers)
  local finish_choice = helpers.finish_choice
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function _resolve_phase_completion(game, player, meta, result)
    return item_phase.resolve_completion(game, player, meta, result)
  end

  -- 道具 completion 收尾后「这扇窗该不该清」的唯一裁决点。原先 item_phase_handlers
  -- 的 _keeps_choice_open/_finish_unless_open 与本模块的 _clear_unless_open 各写了
  -- 一份同款判定(直用道具一份、跟随选择道具一份),两处逐字重复 —— 正是残留能藏住的
  -- 土壤(5ce62507:跟随选择道具作为阶段最后一张牌用掉时,少清一次就把 choice 门控
  -- 带进下一位玩家的回合)。二者收敛到此。
  --
  -- completion 重开了道具窗口(reopened)或原地等待(stay)时,pending_choice 是那个
  -- 要继续用的窗口,不能动;否则 pending_choice 还是刚结算掉的那扇窗,必须清。
  -- completion 为 nil 时不在这里兜底:resolver._build_resolve_result 是 resolve
  -- 结果的唯一兜底点,这里再补一个就又是两个 owner。
  local function _settle_choice_window(game, completion)
    if completion ~= nil and (completion.stay == true or completion.reopened == true) then
      return completion
    end
    finish_choice(game, false)
    return completion
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if normalize.is_repeatable_phase_meta(meta) then
      return _settle_choice_window(game, item_phase.resolve_completion(game, player, meta, result))
    end
    finish_active_item_phase(game)
    return normalize.merge_after_action_anim(result, finish_choice(game, false))
  end

  local function _meta_of(choice)
    return choice and choice.meta or nil
  end

  local function _resolve_followup_cancel(game, choice)
    local meta = _meta_of(choice)
    if normalize.is_repeatable_phase_meta(meta) then
      local player = normalize.validate_item_player(game, choice.kind, meta)
      local open_opts = {
        elapsed_seconds = game.turn.choice_elapsed_seconds or 0,
      }
      if item_phase.reopen_or_finish(game, player, meta, open_opts) then
        return { stay = true }
      end
      return nil
    end
    finish_active_item_phase(game)
    return nil
  end

  return {
    phase_completion = _resolve_phase_completion,
    followup_completion = _resolve_followup_completion,
    followup_cancel = _resolve_followup_cancel,
    settle_choice_window = _settle_choice_window,
  }
end

function completions.item_target_handler(kind, execute_fn, complete, opts)
  opts = opts or {}
  return {
    required_meta = { "player_id", "item_id" },
    cancel = {
      resolve = function(game, choice)
        return complete.followup_cancel(game, choice)
      end,
    },
    normalize_meta = opts.normalize_meta or normalize.item_target_meta,
    meta_validator = opts.meta_validator or normalize.validate_item_owner_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

return completions

--[[ mutate4lua-manifest
version=4
projectHash=dc2425864982609d
scope.0.id=chunk:src/rules/choice_handlers/item_completions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=92
scope.0.semanticHash=af2657eaf29dbe68
scope.1.id=function:completions.build
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=71
scope.1.semanticHash=b5ee47aab7581640
scope.2.id=function:_resolve_phase_completion
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=360776c78d632b1f
scope.3.id=function:_settle_choice_window
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=31
scope.3.semanticHash=ff6e9b78187b9c43
scope.4.id=function:_resolve_followup_completion
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=43
scope.4.semanticHash=f79c54f9e621bbcd
scope.5.id=function:_meta_of
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=47
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_resolve_followup_cancel
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=63
scope.6.semanticHash=c5f23104e7021d19
scope.7.id=function:completions.item_target_handler
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=89
scope.7.semanticHash=03417973627dad03
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=80
scope.8.semanticHash=aba9250a8c6b104f
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=86
scope.9.semanticHash=3c26bf1ea8e4b724
]]
