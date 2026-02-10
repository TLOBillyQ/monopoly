local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_flow = support.turn_flow
local turn_move = support.turn_move
local turn_dispatch = require("src.game.turn.TurnDispatch")
local market_view = require("src.ui.MarketView")
local market_layout = require("src.ui.MarketLayout")
local ui_view = require("src.ui.UIView")
local action_anim = require("src.ui.ActionAnim")
local market_cfg = require("Config.Generated.Market")

local function _test_move_anim_callback_and_delay()
  local dispatched = {}
  local layer = { wait_move_anim = true }
  local game = {
    turn = {
      move_anim = { seq = 1 },
      phase = "wait_move_anim",
    },
    dispatch_action = function(_, action)
      table.insert(dispatched, action)
    end,
  }
  local delay_called = nil
  local function call_delay(delay, cb)
    delay_called = delay
    cb()
  end
  _with_patches({
    { key = "LuaAPI", value = { call_delay_time = call_delay } },
    { key = "SetTimeOut", value = call_delay },
  }, function()
    turn_anim.step_move_anim(game, layer, {
      on_move_anim = function(_, anim)
        _assert_eq(anim.seq, 1, "anim seq forwarded")
        return 0.2
      end,
    })
  end)
  _assert_eq(delay_called, 0.2, "delay requested")
  _assert_eq(#dispatched, 1, "move_anim_done dispatched")
  _assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
end

local function _test_popup_timeout_auto_confirm()
  local g = _new_game()
  local layer = {}
  layer.ui_modal_elapsed = 0
  layer.ui_modal_ref = nil
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return
  end
  local near_timeout = timeout * 0.9
  local popup = {
    active = true,
    confirm_called = 0,
    confirm = function(self)
      self.confirm_called = self.confirm_called + 1
      self.active = false
      return true
    end,
  }
  layer.modal = { active = popup }
  local timeout_opts = {
    is_active = function(l)
      return l.modal and l.modal.active and l.modal.active.active
    end,
    get_ref = function(l)
      return l.modal and l.modal.active
    end,
    on_timeout = function(l)
      l.modal.active:confirm()
    end,
  }
  tick_timeout.step_modal_timeout(layer, near_timeout, timeout_opts)
  _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
  tick_timeout.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
  _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
end

local function _test_invalid_choice_option_rejected()
  local g = _new_game()
  local choice = _open_choice(g, {
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  choice_resolver.resolve(g, choice, { option_id = 999 })
  assert(_get_choice(g) ~= nil, "invalid option should keep choice")
end

local function _test_move_anim_wait_and_resume()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_move_anim = true })
  local player = g:current_player()
  g.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  local phases = {
    start = function()
      return "move", { player = player, total = 1, raw_total = 1 }
    end,
    move = turn_move,
    landing = function()
      return nil
    end,
  }
  g.turn_flow = turn_flow:new(g, phases)

  local res = g.turn_flow:run_until_wait()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.turn.move_anim and g.turn.move_anim.seq
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.turn.move_anim == nil, "move_anim should be cleared")
  local phase = g.turn.phase
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

local function _test_ui_model_structure()
  local ui_model = require("src.ui.UIModel")
  local g = _new_game()
  local player = g:current_player()
  player.inventory:add({ id = 2001 })
  local ui_state = {
    ui = {
      auto_play = false,
      item_slots = { 1, 2, 3, 4, 5 },
    },
  }
  local model = ui_model.build(g, {
    game = g,
    ui_state = ui_state,
    last_turn = g.last_turn,
    finished = g.finished,
  })
  assert(model.panel and model.panel.turn_label, "ui_model.panel.turn_label expected")
  assert(type(model.item_slots) == "table" and model.item_slots[1] == 2001, "ui_model.item_slots[1] expected")
  assert(model.board and model.board.tiles and model.board.tile_states, "ui_model.board data")
end

local function _test_ui_model_player_slot_map_and_choice_owner()
  local ui_model = require("src.ui.UIModel")
  local g = _new_game()
  g.players[1].inventory:add({ id = 2001 })
  g.players[2].inventory:add({ id = 2002 })
  g.turn.pending_choice = {
    id = 77,
    kind = "item_phase_choice",
    options = { { id = 2002, label = "用道具" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = 2 },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  assert(model.current_player_id == 1, "current_player_id expected")
  assert(model.item_choice_owner_id == 2, "item_choice_owner_id expected")
  assert(model.item_slots and model.item_slots[1] == 2001, "current player slot expected")
  assert(model.item_slots_by_player and model.item_slots_by_player[1][1] == 2001, "player1 slot map expected")
  assert(model.item_slots_by_player and model.item_slots_by_player[2][1] == 2002, "player2 slot map expected")
end

local function _test_turn_dispatch_rejects_non_current_actor()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
      auto_play = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
    auto_runner = {
      set_enabled = function() end,
      reset_timer = function() end,
    },
  }

  local res_auto = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 2,
  }, {})
  assert(res_auto and res_auto.status == "rejected", "auto button should reject non-current actor")
  assert(state.ui.auto_play == false, "auto_play should stay false")

  local res_next = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "next",
    actor_role_id = 2,
  }, {})
  assert(res_next and res_next.status == "rejected", "next button should reject non-current actor")
end

local function _test_turn_dispatch_item_slot_uses_actor_slot_map()
  local g = _new_game()
  local captured = nil
  g.turn.pending_choice = {
    id = 66,
    kind = "item_phase_choice",
    options = { { id = 3001, label = "用 3001" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = 1 },
  }
  function g:dispatch_action(action)
    captured = action
    self.turn.pending_choice = nil
  end

  local state = {
    pending_choice = g.turn.pending_choice,
    ui = {
      input_blocked = false,
      item_slot_item_ids = { [1] = 9999 },
      item_slot_item_ids_by_role = {
        [1] = { [1] = 3001 },
        [2] = { [1] = 4001 },
      },
    },
  }

  local res = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "item_slot_1",
    actor_role_id = 1,
  }, {})

  assert(res and res.status == "applied", "item slot action should apply")
  assert(captured and captured.type == "choice_select", "choice_select should dispatch")
  assert(captured and captured.option_id == 3001, "should read actor role slot mapping")
end

local function _test_ui_view_render_by_role_slots_are_isolated()
  local main_view = require("src.ui.UIView")

  local image_logs = {}
  local node_map = {}
  local touch_logs = {}

  local function role_key()
    local role = UIManager and UIManager.client_role or nil
    if role and role.get_roleid then
      return role.get_roleid()
    end
    return 0
  end

  for i = 1, 5 do
    local node_name = "道具槽位" .. tostring(i)
    local storage = {}
    node_map[node_name] = setmetatable({}, {
      __index = function(_, k)
        return storage[k]
      end,
      __newindex = function(t, k, v)
        if k == "image_texture" then
          local rk = role_key()
          image_logs[rk] = image_logs[rk] or {}
          image_logs[rk][node_name] = v
        end
        storage[k] = v
      end,
    })
  end

  local function query_nodes_by_name(name)
    local node = node_map[name]
    if not node then
      node = {}
      node_map[name] = node
    end
    return { node }
  end

  local state = {
    ui_refs = {
      ["空"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
    },
    ui = {
      item_slots = { "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" },
      set_label = function() end,
      set_button = function() end,
      set_touch_enabled = function(_, name, enabled)
        local rk = role_key()
        touch_logs[rk] = touch_logs[rk] or {}
        touch_logs[rk][name] = enabled
      end,
      item_slot_item_ids_by_role = {},
    },
  }

  local ui_model = {
    panel = {
      turn_label = "回合: 1",
      auto_label = "自动：关",
      player_rows = {
        { name = "P1", cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
        { name = "P2", cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      },
    },
    item_slots_by_player = {
      [1] = { 2001 },
      [2] = { 2002 },
    },
    item_slots = { 2001 },
    current_player_id = 1,
    item_choice_owner_id = 1,
    choice = nil,
  }

  local roles = {
    { get_roleid = function() return 1 end },
    { get_roleid = function() return 2 end },
  }

  _with_patches({
    { key = "all_roles", value = roles },
    { key = "UIManager", value = { client_role = nil, query_nodes_by_name = query_nodes_by_name } },
  }, function()
    main_view.refresh_panel(state, ui_model)
  end)

  assert(image_logs[1] and image_logs[1]["道具槽位1"] == "ICON2001", "role1 slot icon expected")
  assert(image_logs[2] and image_logs[2]["道具槽位1"] == "ICON2002", "role2 slot icon expected")
  assert(touch_logs[1] and touch_logs[1]["行动按钮"] == true, "current role action button should be enabled")
  assert(touch_logs[2] and touch_logs[2]["行动按钮"] == false, "non-current role action button should be disabled")
  assert(state.ui.item_slot_item_ids_by_role[1] and state.ui.item_slot_item_ids_by_role[1][1] == 2001, "role1 slot map expected")
  assert(state.ui.item_slot_item_ids_by_role[2] and state.ui.item_slot_item_ids_by_role[2][1] == 2002, "role2 slot map expected")
end

local function _test_market_selection_updates_icon_without_resize()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local option_id = entry.product_id
  local selected_node = {}
  local reset_calls = 0
  selected_node.reset_size = function()
    reset_calls = reset_calls + 1
  end
  local labels = {}
  local state = {
    ui_refs = {
      ["空"] = 1001,
      [tostring(option_id)] = 1002,
    },
    ui = {
      set_label = function(_, name, text)
        labels[name] = text
      end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.refresh_market_selection(state, option_id)

  _assert_eq(selected_node.image_texture, 1002, "market selected icon should update")
  _assert_eq(reset_calls, 0, "market selected icon should not call reset_size")
  _assert_eq(labels[market_layout.price_label], "售价：" .. tostring(entry.price) .. " " .. entry.currency,
    "market price label should update")
end

local function _test_market_close_resets_icon_without_resize()
  local reset_calls = 0
  local selected_node = {
    reset_size = function()
      reset_calls = reset_calls + 1
    end,
  }
  local state = {
    market_choice_option_ids = { 1, 2 },
    pending_choice_selected_option_id = 1,
    ui_refs = {
      ["空"] = 4321,
    },
    ui = {
      market_active = true,
      set_visible = function() end,
      set_label = function() end,
      set_touch_enabled = function() end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.close_market_panel(state)

  _assert_eq(state.ui.market_active, false, "market panel should be inactive")
  _assert_eq(state.market_choice_option_ids, nil, "market options should clear")
  _assert_eq(state.pending_choice_selected_option_id, nil, "selected market option should clear")
  _assert_eq(selected_node.image_texture, 4321, "market selected icon should reset to empty key")
  _assert_eq(reset_calls, 0, "market close should not call reset_size")
end

local function _test_item_slot_uses_keep_size_path()
  local keep_size_calls = 0
  local last_image_key = nil
  local slot_node = {
    set_texture_keep_size = function(_, image_key)
      keep_size_calls = keep_size_calls + 1
      last_image_key = image_key
    end,
  }
  local state = {
    ui_refs = {
      ["空"] = "EMPTY",
      ["2001"] = "ICON2001",
    },
    ui = {
      item_slots = { "道具槽位1" },
      set_touch_enabled = function() end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = {
      [1] = { 2001 },
    },
    choice = nil,
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { slot_node } end } },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = false,
    })
  end)

  _assert_eq(keep_size_calls, 1, "item slot should use keep-size texture path")
  _assert_eq(last_image_key, "ICON2001", "item slot should set expected image key")
end

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")
  local board_view_mod = require("src.ui.BoardView")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh_board", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function()
      return {
        set_camera_bind_mode = function() end,
        set_camera_lock_position = function() end,
      }
    end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
  }

  local game = {
    finished = false,
    winner = nil,
    players = { [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } } },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = { input_blocked = false },
  }

  local ok, err = pcall(function()
    _with_patches(patches, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
  end)

  assert(ok, "tick should not error without anim: " .. tostring(err))
end

local function _test_action_anim_queue_consumes_in_order()
  local phases = {
    start = function()
      return "wait_action_anim", { resume_state = "done", resume_args = {} }
    end,
    done = function()
      return nil
    end,
  }
  local g = {
    turn = {
      phase = "start",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      action_anim = { seq = 1, kind = "item_use", player_id = 1 },
      action_anim_queue = { { seq = 2, kind = "item_use", player_id = 1 } },
    },
    dirty = { turn = false, any = false },
    board = {
      get_tile_by_id = function()
        return { level = 0, name = "" }
      end,
    },
    players = {
      [1] = {
        id = 1,
        name = "P1",
        cash = 0,
        status = { stay_turns = 0, deity = nil },
        inventory = { items = {} },
        properties = {},
      }
    },
  }
  function g:current_player()
    return self.players[self.turn.current_player_index]
  end
  function g:player_balance(player)
    return player.cash
  end
  g.turn_flow = turn_flow:new(g, phases)

  local state = g.turn_flow:run_until_wait()
  _assert_eq(state, "wait_action_anim", "should wait action anim")
  _assert_eq(g.turn.action_anim.seq, 1, "current anim should be seq1")

  g.turn_flow:dispatch({ type = "action_anim_done", seq = 1 })
  _assert_eq(g.turn.phase, "wait_action_anim", "should still wait second anim")
  _assert_eq(g.turn.action_anim.seq, 2, "current anim should switch to seq2")

  g.turn_flow:dispatch({ type = "action_anim_done", seq = 2 })
  assert(g.turn.phase ~= "wait_action_anim", "should leave action anim wait after queue drained")
  assert(g.turn.action_anim == nil, "action_anim should be nil after queue drained")
end

local function _test_action_anim_default_duration()
  local durations = {}
  local state = {
    game = { turn = { current_player_index = 1 }, players = { [1] = { id = 1 } } },
  }
  _with_patches({
    { key = "GlobalAPI", value = { show_tips = function(_, duration) durations[#durations + 1] = duration end } },
    { key = "SetTimeOut", value = function() end },
  }, function()
    local d1 = action_anim.play(state, { kind = "item_use", player_id = 1 })
    local d2 = action_anim.play(state, { kind = "item_use", player_id = 1, duration = 1.8 })
    _assert_eq(d1, 1.0, "default action anim duration should be 1s")
    _assert_eq(d2, 1.8, "explicit action anim duration should override")
  end)
  _assert_eq(#durations, 2, "tip should be shown twice")
end

local function _test_action_anim_player_focus_and_restore()
  local delayed = nil
  local follow_events = 0
  local state = {
    game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1 }, [2] = { id = 2 } },
    },
  }
  local helper = { target_role_id = nil }
  _with_patches({
    { key = "camera_helper", value = helper },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "SetTimeOut", value = function(_, cb) delayed = cb end },
    { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
  }, function()
    action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      focus_target_player_id = 2,
      duration = 0.5,
    })
    _assert_eq(helper.target_role_id, 2, "camera should follow target player during focus")
    _assert_eq(state.camera_focus_active, true, "camera focus should be active")
    assert(delayed ~= nil, "camera restore callback should be scheduled")
    delayed()
    _assert_eq(helper.target_role_id, 1, "camera should restore to current turn player")
    _assert_eq(state.camera_focus_active, false, "camera focus should be cleared")
    assert(follow_events >= 2, "follow event should fire on focus and restore")
  end)
end

local function _test_action_anim_tile_focus_and_restore_track()
  local delayed = nil
  local bind_modes = {}
  local lock_positions = {}
  local helper = { target_role_id = nil }
  local role = {
    set_camera_bind_mode = function(mode)
      bind_modes[#bind_modes + 1] = mode
    end,
    set_camera_lock_position = function(pos)
      lock_positions[#lock_positions + 1] = pos
    end,
  }
  local state = {
    board_scene = {
      tiles = {
        [1] = { get_position = function() return math.Vector3(1, 2, 3) end },
      },
    },
    game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1 } },
    },
  }
  _with_patches({
    { key = "all_roles", value = { role } },
    { key = "camera_helper", value = helper },
    { key = "Enums", value = { CameraBindMode = { BIND = 11, TRACK = 22 } } },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "SetTimeOut", value = function(_, cb) delayed = cb end },
    { key = "TriggerCustomEvent", value = function() end },
  }, function()
    action_anim.play(state, {
      kind = "upgrade_land",
      player_id = 1,
      tile_index = 1,
      focus_target_tile_index = 1,
      duration = 0.5,
    })
    _assert_eq(bind_modes[1], 11, "tile focus should set BIND mode")
    assert(#lock_positions > 0, "tile focus should lock camera position")
    _assert_eq(state.camera_focus_active, true, "camera focus should be active")
    assert(delayed ~= nil, "tile focus should schedule restore")
    delayed()
    _assert_eq(bind_modes[#bind_modes], 22, "tile focus should restore TRACK mode")
    _assert_eq(state.camera_focus_active, false, "camera focus should be cleared")
  end)
end

local function _test_tick_ui_sync_skip_follow_while_focus_active()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")
  local board_view_mod = require("src.ui.BoardView")
  local helper = { target_role_id = 99 }
  local follow_events = 0
  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh_board", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function() return {} end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
    { key = "camera_helper", value = helper },
    { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
  }
  local game = {
    finished = false,
    winner = nil,
    players = { [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } } },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    camera_focus_active = true,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = { input_blocked = false },
  }

  _with_patches(patches, function()
    gameplay_loop.tick(game, state, 0.1)
  end)

  _assert_eq(helper.target_role_id, 99, "focus active should skip default follow override")
  _assert_eq(follow_events, 0, "focus active should not trigger follow event")
end

return {
  _test_move_anim_callback_and_delay,
  _test_popup_timeout_auto_confirm,
  _test_invalid_choice_option_rejected,
  _test_move_anim_wait_and_resume,
  _test_ui_model_structure,
  _test_ui_model_player_slot_map_and_choice_owner,
  _test_turn_dispatch_rejects_non_current_actor,
  _test_turn_dispatch_item_slot_uses_actor_slot_map,
  _test_ui_view_render_by_role_slots_are_isolated,
  _test_market_selection_updates_icon_without_resize,
  _test_market_close_resets_icon_without_resize,
  _test_item_slot_uses_keep_size_path,
  _test_tick_skips_anim_when_no_anim,
  _test_action_anim_queue_consumes_in_order,
  _test_action_anim_default_duration,
  _test_action_anim_player_focus_and_restore,
  _test_action_anim_tile_focus_and_restore_track,
  _test_tick_ui_sync_skip_follow_while_focus_active,
}
