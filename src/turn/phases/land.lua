local runtime_state = require("src.state.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_defs = require("src.rules.land.landing_defs")
local effect_pipeline = require("src.rules.effects.pipeline")
local effect_runner = require("src.rules.effects.runner")
local land_actions = require("src.rules.land.actions")
local pricing = require("src.rules.land.pricing")
local wait_callbacks = require("src.turn.waits.callback_registry")

local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

local function _is_relocation_action_anim(entry)
  return entry and (entry.kind == "move_effect" or entry.kind == "teleport_effect" or entry.kind == "forced_relocation")
end

local function _has_pending_relocation_action_anim(game)
  if not game or not game.turn then
    return false
  end
  local current = game.turn.action_anim
  if _is_relocation_action_anim(current) then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_relocation_action_anim(entry) then
      return true
    end
  end
  return false
end

local function _is_landing_visual_hold_active(game)
  if not game then
    return false
  end
  local state = game.landing_visual_hold_state
  if state ~= nil and runtime_state.get_landing_visual_hold_source(state) ~= nil then
    return runtime_state.get_landing_visual_hold_active(state)
  end
  local turn = game.turn or nil
  return turn and turn.landing_visual_hold_active == true or false
end

local _is_effect_idle = runtime_ports.is_effect_idle

local function _landing_optional_cost(effect_id, tile, game)
  if effect_id ~= "upgrade_land" or tile == nil or game == nil then
    return nil
  end
  local st = land_actions.safe_tile_state(game, tile)
  return pricing.upgrade_cost(tile, (st and st.level) or 0)
end

local max_landing_depth = 10
local callback_keys = wait_callbacks.callback_keys
local _resolve_landing

local function _resolve_target_player(game, player, out)
  if not out.player_id then
    return player
  end
  return game:find_player_by_id(out.player_id)
end

local function _resolve_next_tile(game, target_player, out)
  if not target_player then
    return nil
  end
  local idx = out.board_index or target_player.position
  if not idx then
    return nil
  end
  return game.board:get_tile(idx)
end

local function _build_move_followup_result(target_player, out, wait_key)
  return {
    waiting = true,
    [wait_key] = true,
    next_state = "move_followup",
    next_args = {
      mode = "resolve_landing",
      player_id = target_player.id,
      move_result = out.move_result,
    },
  }
end

local function _register_action_anim_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_action_anim, callback)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
  end
  return "wait_action_anim", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _register_landing_visual_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_landing_visual, callback)
  return "wait_landing_visual", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resume_wait_choice(next_state, next_args)
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _wait_for_choice_via(register_fn)
  return function(game, next_state, next_args)
    return register_fn(game, "wait_choice", {
      next_state = next_state,
      next_args = next_args,
    }, function()
      return _resume_wait_choice(next_state, next_args)
    end)
  end
end

local _wait_for_choice_via_action_anim = _wait_for_choice_via(_register_action_anim_resume)
local _wait_for_choice_via_landing_visual = _wait_for_choice_via(_register_landing_visual_resume)

local function _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args)
  local action_anim_state, action_anim_args = _wait_for_choice_via_action_anim(game, next_state, next_args)
  return _register_landing_visual_resume(game, action_anim_state, action_anim_args, function()
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end)
end

local function _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  if next_state == "move_followup" then game.turn.move_followup_pending = true end
  local move_anim_args = { next_state = next_state, next_args = next_args }
  local function _resume() return "wait_move_anim", move_anim_args end
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "wait_move_anim",
        next_args = move_anim_args,
      }, function()
        return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
      end)
    end
    return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
  end
  if has_hold_or_pending then return _register_landing_visual_resume(game, "wait_move_anim", move_anim_args, _resume) end
  return "wait_move_anim", move_anim_args
end

local function _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = next_state,
        next_args = next_args,
      }, function()
        return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
      end)
    end
    return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  if has_hold_or_pending then
    return _register_landing_visual_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  return next_state, next_args
end

local function _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
  if has_anim then
    if has_hold_or_pending then return _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args) end
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end
  if has_hold_or_pending then return _wait_for_choice_via_landing_visual(game, next_state, next_args) end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

local function _resolve_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)
  local has_anim = _has_action_anim(game)
  local has_hold_or_pending = _is_landing_visual_hold_active(game) or not _is_effect_idle()
  if wait_move_anim == true then
    return _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  if wait_action_anim == true then
    return _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  return _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
end

local function _resolve_finished_landing_state(game, player)
  local function _resume_post_action()
    return "post_action", { player = player }
  end

  local has_anim = _has_action_anim(game)
  local has_hold = _is_landing_visual_hold_active(game)
  local effects_pending = not _is_effect_idle()

  if has_anim then
    if has_hold or effects_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "post_action",
        next_args = { player = player },
      }, function()
        return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
      end)
    end
    return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  if has_hold or effects_pending then
    return _register_landing_visual_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  return "post_action", { player = player }
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return _resolve_wait_state(game, next_state, next_args, res.wait_action_anim, res.wait_move_anim)
end

local function _resolve_followup_landing(game, player, out, depth)
  local target_player = _resolve_target_player(game, player, out)
  local next_tile = _resolve_next_tile(game, target_player, out)
  if not next_tile then
    return out
  end
  if out.wait_move_anim == true then
    return _build_move_followup_result(target_player, out, "wait_move_anim")
  end
  if _has_pending_relocation_action_anim(game) then
    return _build_move_followup_result(target_player, out, "wait_action_anim")
  end
  return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
end

function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = effect_runner.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    return _resolve_followup_landing(game, player, out, depth)
  end

  return effect_pipeline.run(landing_defs, player, tile, game_ctx, {
    next_state = "post_action",
    next_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    optional_cost_resolver = _landing_optional_cost,
    on_need_landing = handle_need_landing,
  })
end

local function _phase_land(turn_mgr, args)
  local player = args.player
  local move_result = args.move_result
  local game = turn_mgr.game
  local tile = game.board:get_tile(player.position)

  local res = _resolve_landing(game, player, tile, move_result)
  if res and res.waiting then
    return _resolve_waiting_landing_result(game, res, player, move_result)
  end
  return _resolve_finished_landing_state(game, player)
end

return {
  run = _phase_land,
  _resolve_wait_state = _resolve_wait_state,
  resolve_wait_state = _resolve_wait_state,
}

--[[ mutate4lua-manifest
version=2
projectHash=a3e31336eeca775d
scope.0.id=chunk:src/turn/phases/land.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=301
scope.0.semanticHash=a609da70ac111373
scope.1.id=function:_has_action_anim:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=19
scope.1.semanticHash=71fa5b89362e50c4
scope.2.id=function:_is_relocation_action_anim:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=b3ceeff0fbd803be
scope.3.id=function:_is_landing_visual_hold_active:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=55
scope.3.semanticHash=2783f896cfdc879c
scope.4.id=function:_landing_optional_cost:59
scope.4.kind=function
scope.4.startLine=59
scope.4.endLine=65
scope.4.semanticHash=9450f522a46e2534
scope.5.id=function:_resolve_target_player:71
scope.5.kind=function
scope.5.startLine=71
scope.5.endLine=76
scope.5.semanticHash=f7e21db0efd1d680
scope.6.id=function:_resolve_next_tile:78
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=87
scope.6.semanticHash=0a5c64151445ca16
scope.7.id=function:_build_move_followup_result:89
scope.7.kind=function
scope.7.startLine=89
scope.7.endLine=100
scope.7.semanticHash=9f0d97cd037d0b96
scope.8.id=function:_register_action_anim_resume:102
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=111
scope.8.semanticHash=1f3f4c4f76b20ccb
scope.9.id=function:_register_landing_visual_resume:113
scope.9.kind=function
scope.9.startLine=113
scope.9.endLine=119
scope.9.semanticHash=6aed8181f753644f
scope.10.id=function:_resume_wait_choice:121
scope.10.kind=function
scope.10.startLine=121
scope.10.endLine=126
scope.10.semanticHash=d7faa0645c59b87a
scope.11.id=function:anonymous@133:133
scope.11.kind=function
scope.11.startLine=133
scope.11.endLine=135
scope.11.semanticHash=ad407e8da264a75a
scope.12.id=function:anonymous@129:129
scope.12.kind=function
scope.12.startLine=129
scope.12.endLine=136
scope.12.semanticHash=3483fc07d5b30424
scope.13.id=function:_wait_for_choice_via:128
scope.13.kind=function
scope.13.startLine=128
scope.13.endLine=137
scope.13.semanticHash=7cdb597f4a0194e5
scope.14.id=function:anonymous@144:144
scope.14.kind=function
scope.14.startLine=144
scope.14.endLine=146
scope.14.semanticHash=0538e98a3f661570
scope.15.id=function:_wait_for_choice_via_landing_visual_then_action_anim:142
scope.15.kind=function
scope.15.startLine=142
scope.15.endLine=147
scope.15.semanticHash=5af277558825d428
scope.16.id=function:_resume:152
scope.16.kind=function
scope.16.startLine=152
scope.16.endLine=152
scope.16.semanticHash=f294f7498d372cc3
scope.17.id=function:anonymous@158:158
scope.17.kind=function
scope.17.startLine=158
scope.17.endLine=160
scope.17.semanticHash=74fe092ff0dc29f5
scope.18.id=function:_resolve_wait_move_anim:149
scope.18.kind=function
scope.18.startLine=149
scope.18.endLine=166
scope.18.semanticHash=41083099197b537b
scope.19.id=function:anonymous@175:175
scope.19.kind=function
scope.19.startLine=175
scope.19.endLine=175
scope.19.semanticHash=eb80000d7c712429
scope.20.id=function:anonymous@174:174
scope.20.kind=function
scope.20.startLine=174
scope.20.endLine=176
scope.20.semanticHash=6b790b3fcadde68b
scope.21.id=function:anonymous@178:178
scope.21.kind=function
scope.21.startLine=178
scope.21.endLine=178
scope.21.semanticHash=eb80000d7c712429
scope.22.id=function:anonymous@181:181
scope.22.kind=function
scope.22.startLine=181
scope.22.endLine=181
scope.22.semanticHash=eb80000d7c712429
scope.23.id=function:_resolve_wait_action_anim_state:168
scope.23.kind=function
scope.23.startLine=168
scope.23.endLine=184
scope.23.semanticHash=eb9048310f3829cc
scope.24.id=function:_route_choice_wait_state:186
scope.24.kind=function
scope.24.startLine=186
scope.24.endLine=193
scope.24.semanticHash=9d44aacda1c88305
scope.25.id=function:_resolve_wait_state:195
scope.25.kind=function
scope.25.startLine=195
scope.25.endLine=205
scope.25.semanticHash=91783596957f63f8
scope.26.id=function:_resume_post_action:208
scope.26.kind=function
scope.26.startLine=208
scope.26.endLine=210
scope.26.semanticHash=4783bb92de224ac3
scope.27.id=function:anonymous@221:221
scope.27.kind=function
scope.27.startLine=221
scope.27.endLine=223
scope.27.semanticHash=015ba9572b2278f5
scope.28.id=function:_resolve_finished_landing_state:207
scope.28.kind=function
scope.28.startLine=207
scope.28.endLine=231
scope.28.semanticHash=064dd0565e9c3603
scope.29.id=function:_resolve_landing_wait_args:233
scope.29.kind=function
scope.29.startLine=233
scope.29.endLine=235
scope.29.semanticHash=0999c654f2cffe0d
scope.30.id=function:_resolve_waiting_landing_result:237
scope.30.kind=function
scope.30.startLine=237
scope.30.endLine=240
scope.30.semanticHash=9d7ddf22b6ea23d9
scope.31.id=function:_resolve_followup_landing:242
scope.31.kind=function
scope.31.startLine=242
scope.31.endLine=255
scope.31.semanticHash=8756b67fe1398e24
scope.32.id=function:handle_need_landing:264
scope.32.kind=function
scope.32.startLine=264
scope.32.endLine=269
scope.32.semanticHash=67bd0e16b9251492
scope.33.id=function:_resolve_landing:257
scope.33.kind=function
scope.33.startLine=257
scope.33.endLine=281
scope.33.semanticHash=e956b8396a181c4c
scope.34.id=function:_phase_land:283
scope.34.kind=function
scope.34.startLine=283
scope.34.endLine=294
scope.34.semanticHash=29ae81d682687811
]]
