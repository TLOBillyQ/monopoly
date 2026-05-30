local runtime_state = {}

local function _runtime_state()
return require("src.state.runtime")
end

function runtime_state.ensure_all(state)
  return _runtime_state().ensure_all(state)
end

function runtime_state.ensure_ui_runtime(state)
  return _runtime_state().ensure_ui_runtime(state)
end

function runtime_state.ensure_board_runtime(state)
  return _runtime_state().ensure_board_runtime(state)
end

function runtime_state.ensure_anim_runtime(state)
  return _runtime_state().ensure_anim_runtime(state)
end

function runtime_state.ensure_turn_runtime(state)
  return _runtime_state().ensure_turn_runtime(state)
end

function runtime_state.ensure_debug_runtime(state)
  return _runtime_state().ensure_debug_runtime(state)
end

function runtime_state.log_once(state, level, key, ...)
  return _runtime_state().log_once(state, level, key, ...)
end

function runtime_state.is_ui_dirty(state)
  return _runtime_state().is_ui_dirty(state)
end

function runtime_state.set_ui_dirty(state, dirty)
  return _runtime_state().set_ui_dirty(state, dirty)
end

function runtime_state.get_ui_model(state)
  return _runtime_state().get_ui_model(state)
end

function runtime_state.set_ui_model(state, model)
  return _runtime_state().set_ui_model(state, model)
end

function runtime_state.get_local_actor_role_id(state)
  local impl = _runtime_state()
  if type(impl.get_local_actor_role_id) == "function" then
    return impl.get_local_actor_role_id(state)
  end
  return state and state.local_actor_role_id or nil
end

function runtime_state.set_local_actor_role_id(state, role_id)
  local impl = _runtime_state()
  if type(impl.set_local_actor_role_id) == "function" then
    impl.set_local_actor_role_id(state, role_id)
  end
  if state then
    state.local_actor_role_id = role_id
  end
  return role_id
end

function runtime_state.get_pending_choice(state)
  return _runtime_state().get_pending_choice(state)
end

function runtime_state.get_pending_choice_id(state)
  return _runtime_state().get_pending_choice_id(state)
end

function runtime_state.set_pending_choice_id(state, choice_id)
  return _runtime_state().set_pending_choice_id(state, choice_id)
end

function runtime_state.get_pending_choice_elapsed(state)
  return _runtime_state().get_pending_choice_elapsed(state)
end

function runtime_state.set_pending_choice_elapsed(state, elapsed_seconds)
  return _runtime_state().set_pending_choice_elapsed(state, elapsed_seconds)
end

function runtime_state.set_pending_choice(state, choice, opts)
  return _runtime_state().set_pending_choice(state, choice, opts)
end

function runtime_state.get_modal_elapsed(state)
  return _runtime_state().get_modal_elapsed(state)
end

function runtime_state.get_modal_ref(state)
  return _runtime_state().get_modal_ref(state)
end

function runtime_state.set_modal_timer(state, payload)
  return _runtime_state().set_modal_timer(state, payload)
end

function runtime_state.set_follow_target_position(state, player_id, position, opts)
  return _runtime_state().set_follow_target_position(state, player_id, position, opts)
end

function runtime_state.get_follow_target_position(state, player_id)
  return _runtime_state().get_follow_target_position(state, player_id)
end

return runtime_state

--[[ mutate4lua-manifest
version=2
projectHash=f2d6bd8af0acd471
scope.0.id=chunk:src/ui/state/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=115
scope.0.semanticHash=67883d3d48cc742b
scope.1.id=function:_runtime_state:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=b2acb69ea10b5171
scope.2.id=function:runtime_state.ensure_all:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=87367d4de1e31c26
scope.3.id=function:runtime_state.ensure_ui_runtime:11
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=13
scope.3.semanticHash=52fd53f133853626
scope.4.id=function:runtime_state.ensure_board_runtime:15
scope.4.kind=function
scope.4.startLine=15
scope.4.endLine=17
scope.4.semanticHash=00dc292f5dcbabc6
scope.5.id=function:runtime_state.ensure_anim_runtime:19
scope.5.kind=function
scope.5.startLine=19
scope.5.endLine=21
scope.5.semanticHash=2237083b38a78f6a
scope.6.id=function:runtime_state.ensure_turn_runtime:23
scope.6.kind=function
scope.6.startLine=23
scope.6.endLine=25
scope.6.semanticHash=a6a1c3ccf9e349ca
scope.7.id=function:runtime_state.ensure_debug_runtime:27
scope.7.kind=function
scope.7.startLine=27
scope.7.endLine=29
scope.7.semanticHash=c0b51ecd81bb1620
scope.8.id=function:runtime_state.log_once:31
scope.8.kind=function
scope.8.startLine=31
scope.8.endLine=33
scope.8.semanticHash=60a76c855a9d2248
scope.9.id=function:runtime_state.is_ui_dirty:35
scope.9.kind=function
scope.9.startLine=35
scope.9.endLine=37
scope.9.semanticHash=34fdce1e4d53fc86
scope.10.id=function:runtime_state.set_ui_dirty:39
scope.10.kind=function
scope.10.startLine=39
scope.10.endLine=41
scope.10.semanticHash=a276b3ff52490272
scope.11.id=function:runtime_state.get_ui_model:43
scope.11.kind=function
scope.11.startLine=43
scope.11.endLine=45
scope.11.semanticHash=ea3454fc1ede628c
scope.12.id=function:runtime_state.set_ui_model:47
scope.12.kind=function
scope.12.startLine=47
scope.12.endLine=49
scope.12.semanticHash=63df9a496c63149a
scope.13.id=function:runtime_state.get_local_actor_role_id:51
scope.13.kind=function
scope.13.startLine=51
scope.13.endLine=57
scope.13.semanticHash=508f409d5be72158
scope.14.id=function:runtime_state.set_local_actor_role_id:59
scope.14.kind=function
scope.14.startLine=59
scope.14.endLine=68
scope.14.semanticHash=dcbd6d5bcb0ae545
scope.15.id=function:runtime_state.get_pending_choice:70
scope.15.kind=function
scope.15.startLine=70
scope.15.endLine=72
scope.15.semanticHash=b44b27739e5bcec6
scope.16.id=function:runtime_state.get_pending_choice_id:74
scope.16.kind=function
scope.16.startLine=74
scope.16.endLine=76
scope.16.semanticHash=8ab1214b20084922
scope.17.id=function:runtime_state.set_pending_choice_id:78
scope.17.kind=function
scope.17.startLine=78
scope.17.endLine=80
scope.17.semanticHash=74a8cfcd0f531276
scope.18.id=function:runtime_state.get_pending_choice_elapsed:82
scope.18.kind=function
scope.18.startLine=82
scope.18.endLine=84
scope.18.semanticHash=d82a4fa9ec62dc44
scope.19.id=function:runtime_state.set_pending_choice_elapsed:86
scope.19.kind=function
scope.19.startLine=86
scope.19.endLine=88
scope.19.semanticHash=6d036fdbd3f78248
scope.20.id=function:runtime_state.set_pending_choice:90
scope.20.kind=function
scope.20.startLine=90
scope.20.endLine=92
scope.20.semanticHash=ffa634918a13922c
scope.21.id=function:runtime_state.get_modal_elapsed:94
scope.21.kind=function
scope.21.startLine=94
scope.21.endLine=96
scope.21.semanticHash=07142c4e7eee9726
scope.22.id=function:runtime_state.get_modal_ref:98
scope.22.kind=function
scope.22.startLine=98
scope.22.endLine=100
scope.22.semanticHash=67ee7029876f93c6
scope.23.id=function:runtime_state.set_modal_timer:102
scope.23.kind=function
scope.23.startLine=102
scope.23.endLine=104
scope.23.semanticHash=9cc015d6ea7b22b2
scope.24.id=function:runtime_state.set_follow_target_position:106
scope.24.kind=function
scope.24.startLine=106
scope.24.endLine=108
scope.24.semanticHash=1e3f6c40139ec4a6
scope.25.id=function:runtime_state.get_follow_target_position:110
scope.25.kind=function
scope.25.startLine=110
scope.25.endLine=112
scope.25.semanticHash=99f8c467eb68d278
]]
