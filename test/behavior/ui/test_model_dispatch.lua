-- UI model and action dispatch behavior: 31 explicit busted cases.
-- luacheck: ignore 143 (genuine busted injects luassert)
local luassert = assert

local support = require("test.support.shared_support")
local control = require("src.player.control")
local _new_game = support.new_game
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local dispatch = require("src.turn.actions.action_dispatcher")
local modal_presenter = require("src.ui.coord.modal")
local panel_slice = require("src.ui.view.panel_slice")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local runtime_state = require("src.state.runtime")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

local _build_choice_modal_state = support.build_choice_modal_state

local function _panel_game(players, coins_by_key)
  return {
    players = players,
    player_cash = function(_, player)
      local key = player and (player.id or player.name) or nil
      return coins_by_key and coins_by_key[key] or 0
    end,
  }
end

local function _build_market_nav_dispatch_env()
  local game = _new_game()
  local state = {
    pending_choice = nil,
    ui = {
      input_blocked = false,
    },
  }
  local calls = {
    sync_pending_choice = 0,
    invalidate_ui_model = 0,
  }
  state._resolved_gameplay_loop_ports = {
    output = {
      get_pending_choice = function(current_state)
        return current_state.pending_choice
      end,
      sync_pending_choice = function(_, choice)
        calls.sync_pending_choice = calls.sync_pending_choice + 1
        calls.synced_choice = choice
      end,
      invalidate_ui_model = function()
        calls.invalidate_ui_model = calls.invalidate_ui_model + 1
      end,
      clear_pending_choice = function() end,
    },
    ui_sync = {
      get_ui_state = function(current_state)
        return current_state and current_state.ui or nil
      end,
      resolve_ui_gate = function()
        return {
          input_blocked = false,
          choice_active = false,
          market_active = false,
          popup_active = false,
        }
      end,
    },
  }
  return game, state, calls
end

local function _with_reloaded_turn_dispatch(overrides, fn)
  local original_dispatch = package.loaded["src.turn.actions.action_dispatcher"]
  local original_handlers = package.loaded["src.turn.actions.action_dispatcher_handlers"]
  local original_helpers = package.loaded["src.turn.actions.action_dispatcher_helpers"]
  local original_market = package.loaded["src.turn.actions.action_dispatcher_market"]
  local originals = {}
  for module_name, module_value in pairs(overrides or {}) do
    originals[module_name] = package.loaded[module_name]
    package.loaded[module_name] = module_value
  end
  package.loaded["src.turn.actions.action_dispatcher"] = nil
  package.loaded["src.turn.actions.action_dispatcher_handlers"] = nil
  package.loaded["src.turn.actions.action_dispatcher_helpers"] = nil
  package.loaded["src.turn.actions.action_dispatcher_market"] = nil
  local ok, result = pcall(function()
    return fn(require("src.turn.actions.action_dispatcher"))
  end)
  package.loaded["src.turn.actions.action_dispatcher"] = original_dispatch
  package.loaded["src.turn.actions.action_dispatcher_handlers"] = original_handlers
  package.loaded["src.turn.actions.action_dispatcher_helpers"] = original_helpers
  package.loaded["src.turn.actions.action_dispatcher_market"] = original_market
  for module_name, _ in pairs(overrides or {}) do
    package.loaded[module_name] = originals[module_name]
  end
  if not ok then
    error(result)
  end
  return result
end

describe("TestModelDispatch", function()

it("test_ui_model_structure", function()
  local ui_model = require("src.ui.view")
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
  luassert.truthy(model.panel and model.panel.turn_label, "ui_model.panel.turn_label expected")
  luassert.truthy(type(model.item_slots) == "table" and model.item_slots[1] == 2001, "ui_model.item_slots[1] expected")
  luassert.truthy(model.board and model.board.tiles and model.board.tile_states, "ui_model.board data")
end)

it("test_ui_panel_clamps_negative_assets_to_zero", function()
  local ui_panel = require("src.ui.view.panel_builder")
  local statuses = ui_panel.build_player_statuses(
    _panel_game({
      {
        id = 1,
        name = "P1",
        eliminated = false,
        properties = {},
      },
    }, { [1] = -123 }), {
    board = {
      get_tile_by_id = function()
        return nil
      end,
    },
  }, 1)

  local row = statuses and statuses[1] or nil
  luassert.truthy(row ~= nil, "panel row should exist")
  _assert_eq(row.cash_value, 0, "negative cash_value should normalize as zero")
  _assert_eq(row.cash, "现金: 0", "negative cash should render as zero")
  _assert_eq(row.total_assets_value, 0, "negative total_assets_value should normalize as zero")
  _assert_eq(row.total_assets, "总资产: 0", "negative total assets should render as zero")
end)

it("test_ui_panel_handles_invalid_cash_missing_role_id_and_empty_remote_name", function()
  local ui_panel = require("src.ui.view.panel_builder")
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local resolve_calls = 0

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(role_id)
      resolve_calls = resolve_calls + 1
      if role_id == nil then
        error("role id should be checked before resolving")
      end
      return {
        get_name = function()
          return ""
        end,
        get_head_icon = function()
          return 42
        end,
      }
    end },
  }, function()
    local statuses = ui_panel.build_player_statuses(
      _panel_game({
        {
          name = "NoId",
          eliminated = false,
          properties = {},
        },
        {
          id = 2,
          name = "Local",
          eliminated = true,
          properties = { [20] = true },
        },
      }, { NoId = 7, [2] = "not-a-number" }), {
      board = {
        get_tile_by_id = function(_, tile_id)
          if tile_id == 20 then
            return {
              type = "land",
              price = 50,
              upgrade_costs = { 100 },
            }
          end
          return nil
        end,
      },
    }, 2)

    local row1 = statuses and statuses[1] or nil
    local row2 = statuses and statuses[2] or nil
    luassert.truthy(row1 ~= nil, "first panel row should exist")
    luassert.truthy(row2 ~= nil, "second panel row should exist")
    _assert_eq(resolve_calls, 1, "missing role id should not resolve a role")
    _assert_eq(row1.name, "NoId", "missing role id should keep local name")
    _assert_eq(row1.cash_value, 7, "valid local row should keep cash")
    _assert_eq(row2.name, "Local (出局)", "empty remote name should fall back to local eliminated label")
    _assert_eq(row2.avatar, 42, "valid remote avatar should be used")
    _assert_eq(row2.eliminated, true, "eliminated flag should be exposed on the panel row")
    _assert_eq(row2.cash_value, 0, "invalid cash should normalize to zero")
    _assert_eq(row2.cash, "现金: 0", "invalid cash should render as zero")
    _assert_eq(row2.land_count, "地块: 1", "owned land count should still render")
    _assert_eq(row2.total_assets_value, 50, "missing land level should not include upgrade cost")
    _assert_eq(row2.total_assets, "总资产: 50", "missing land level should render purchase value only")
  end)
end)

it("test_ui_panel_missing_player_name_renders_blank_label", function()
  local ui_panel = require("src.ui.view.panel_builder")
  local statuses = ui_panel.build_player_statuses(
    _panel_game({
      {
        id = 1,
        eliminated = false,
        properties = {},
      },
    }, { [1] = 0 }), nil, 1)

  local row = statuses and statuses[1] or nil
  luassert.truthy(row ~= nil, "panel row should exist")
  _assert_eq(row.name, "", "missing player name should render as blank")
end)

it("test_ui_panel_empty_rows_and_zero_count_do_not_leak_cache_entries", function()
  local ui_panel = require("src.ui.view.panel_builder")
  local statuses = ui_panel.build_player_statuses({
    players = {},
  }, nil, 2)

  local row = statuses and statuses[1] or nil
  luassert.truthy(row ~= nil, "empty panel row should exist")
  _assert_eq(row.name, "", "empty row name should be blank")
  _assert_eq(row.avatar, nil, "empty row avatar should be nil")
  _assert_eq(row.eliminated, false, "empty row should not be eliminated")
  _assert_eq(row.cash_value, nil, "empty row cash value should be nil")
  _assert_eq(row.total_assets_value, nil, "empty row total value should be nil")
  _assert_eq(row.cash, "", "empty row cash label should be blank")
  _assert_eq(row.land_count, "", "empty row land label should be blank")
  _assert_eq(row.total_assets, "", "empty row total label should be blank")

  statuses = ui_panel.build_player_statuses({ players = {} }, nil, 0)
  _assert_eq(#statuses, 0, "zero requested rows should trim the status array")
  _assert_eq(statuses[0], nil, "zero requested rows should not write a cache entry at index 0")
  _assert_eq(statuses[1], nil, "zero requested rows should clear previous array rows")
end)

it("test_ui_panel_builds_empty_rows_and_counts_land_assets_only", function()
  local ui_panel = require("src.ui.view.panel_builder")
  local statuses = ui_panel.build_player_statuses(
    _panel_game({
      {
        id = 1,
        name = "P1",
        eliminated = false,
        properties = {
          [10] = true,
          [11] = true,
        },
      },
    }, { [1] = 120 }), {
    board = {
      get_tile_by_id = function(_, tile_id)
        if tile_id == 10 then
          return {
            type = "land",
            level = 2,
            price = 300,
            upgrade_costs = { 100, 150 },
          }
        end
        return {
          type = "chance",
          level = 5,
          price = 999,
        }
      end,
    },
  }, 2)

  local row1 = statuses and statuses[1] or nil
  local row2 = statuses and statuses[2] or nil
  luassert.truthy(row1 ~= nil, "first panel row should exist")
  _assert_eq(row1.land_count, "地块: 2", "panel should count owned properties")
  _assert_eq(row1.total_assets_value, 670, "panel should only add invested value for land tiles")
  _assert_eq(row1.total_assets, "总资产: 670", "panel should render total assets with land investment")
  luassert.truthy(row2 ~= nil, "second panel row should exist")
  _assert_eq(row2.name, "", "missing player slots should render empty name")
  _assert_eq(row2.cash, "", "missing player slots should render empty cash")
  _assert_eq(row2.total_assets_value, nil, "missing player slots should keep total assets empty")
end)

it("test_ui_model_player_slot_map_and_choice_owner", function()
  local ui_model = require("src.ui.view")
  local g = _new_game({ ai = {} })
  g.players[1].inventory:add({ id = 2001 })
  g.players[2].inventory:add({ id = 2002 })
  control.initialize(g.players[1])
  control.toggle_manual_delegation(g.players[2])
  require("src.turn.output.player_control_snapshot").install(g)
  g.turn.pending_choice = {
    id = 77,
    kind = "item_phase_passive",
    route_key = "base_inline",
    owner_role_id = "2",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    options = { { id = 2002, label = "用道具" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = "2" },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
    player_control_by_player = g.player_control_snapshots,
  })

  luassert.truthy(model.current_player_id == 1, "current_player_id expected")
  luassert.truthy(model.item_choice_owner_id == 2, "item_choice_owner_id should normalize choice owner role id")
  luassert.truthy(model.item_slots and model.item_slots[1] == 2001, "current player slot expected")
  luassert.truthy(model.item_slots_by_player and model.item_slots_by_player[1][1] == 2001, "player1 slot map expected")
  luassert.truthy(model.item_slots_by_player and model.item_slots_by_player[2][1] == 2002, "player2 slot map expected")
  luassert.truthy(model.delegated_by_player and model.delegated_by_player[1] == false, "player1 delegation expected false")
  luassert.truthy(model.delegated_by_player and model.delegated_by_player[2] == true, "player2 delegation expected true")
  luassert.truthy(model.panel and model.panel.auto_label_by_player and model.panel.auto_label_by_player[1] == "托管",
    "player1 auto label should use fixed delegate copy")
  luassert.truthy(model.panel and model.panel.auto_label_by_player and model.panel.auto_label_by_player[2] == "托管",
    "player2 auto label should use fixed delegate copy")
end)

it("test_ui_model_build_falls_back_when_no_current_player", function()
  local ui_model = require("src.ui.view")
  local g = _new_game()
  g.turn.current_player_index = nil

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = {}, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  _assert_eq(model.current_player_name, "-", "no current player should fall back to the dash name")
  _assert_eq(model.current_player_cash, 0, "no current player should fall back to zero cash")
  luassert.is_nil(model.current_player_id, "no current player should leave the id nil")
end)

it("test_panel_auto_label_stays_fixed_across_auto_states", function()
  local panel_view = require("src.ui.view.panel_builder")

  _assert_eq(panel_view.build_auto_label(false), "托管", "disabled auto label should be fixed")
  _assert_eq(panel_view.build_auto_label(true), "托管", "enabled auto label should be fixed")
end)

it("test_panel_turn_label_defaults_missing_countdown_to_zero", function()
  local panel_view = require("src.ui.view.panel_builder")

  _assert_eq(panel_view.build_turn_label(nil, 7), "倒计时:7", "explicit countdown should render")
  _assert_eq(panel_view.build_turn_label(nil, nil), "倒计时:0", "missing countdown should render as zero")
  _assert_eq(panel_view.build_turn_label(nil, 0), "倒计时:0", "zero countdown should stay zero")
end)

it("test_ui_model_player_profile_prefers_role_api_with_fallback", function()
  local ui_model = require("src.ui.view")
  local g = _new_game()
  g.players[1].name = "本地玩家1"
  g.players[2].name = "本地玩家2"
  g.players[2].eliminated = true
  local role_by_id = {
    [1] = {
      get_name = function()
        return "远端昵称1"
      end,
      get_head_icon = function()
        return 12345
      end,
    },
    [2] = {
      get_name = function()
        error("name failed")
      end,
      get_head_icon = function()
        error("avatar failed")
      end,
    },
  }
  local model = nil
  _with_patches({
    { target = GameAPI, key = "get_role", value = function(role_id)
      return role_by_id[role_id]
    end },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local row1 = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
  local row2 = model and model.panel and model.panel.player_rows and model.panel.player_rows[2] or nil
  luassert.truthy(row1 and row1.name == "远端昵称1", "player1 should use role name")
  luassert.truthy(row1 and row1.avatar == 12345, "player1 should use role avatar")
  luassert.truthy(row2 and row2.name == "本地玩家2 (出局)", "player2 name should fallback to local name with eliminated suffix")
  luassert.truthy(row2 and row2.avatar == nil, "player2 avatar should fallback to nil when role api failed")
end)

it("test_ui_model_player_profile_accepts_stringified_avatar", function()
  local ui_model = require("src.ui.view")
  local g = _new_game()
  g.players[1].name = "本地玩家1"
  local icon_obj = setmetatable({}, {
    __tostring = function()
      return "67890"
    end,
  })
  local role_by_id = {
    [1] = {
      get_name = function()
        return "远端昵称1"
      end,
      get_head_icon = function()
        return icon_obj
      end,
    },
  }
  local model = nil
  _with_patches({
    { target = GameAPI, key = "get_role", value = function(role_id)
      return role_by_id[role_id]
    end },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local row1 = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
  luassert.truthy(row1 and row1.avatar == 67890, "player1 avatar should parse stringified icon key")
end)

it("test_ui_model_player_profile_uses_slot_avatar_for_synthetic_ai", function()
  local ui_model = require("src.ui.view")
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local runtime_refs = require("src.config.content.runtime_refs")
  local g = _new_game()
  g.players[3] = g.players[3] or {
    id = 3,
    name = "AI3",
    eliminated = false,
    inventory = { items = {} },
    properties = {},
    status = { stay_turns = 0, deity = nil },
    _coin_role = require("src.player.actions.balance").new_memory_coin_role(0),
  }
  g.players[4] = g.players[4] or {
    id = 4,
    name = "AI4",
    eliminated = false,
    inventory = { items = {} },
    properties = {},
    status = { stay_turns = 0, deity = nil },
    _coin_role = require("src.player.actions.balance").new_memory_coin_role(0),
  }
  g.players[1].name = "本地玩家1"
  g.players[2].name = "AI2"
  g.players[3].name = "AI3"
  g.players[4].name = "AI4"

  local avatar_ai_2 = runtime_refs.images.AI2
  local avatar_ai_3 = runtime_refs.images.AI3
  local avatar_ai_4 = runtime_refs.images.AI4
  local model = nil
  _with_patches({
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function(player_id)
        if player_id == 1 then
          return {
            get_name = function()
              return "远端昵称1"
            end,
            get_head_icon = function()
              return 12345
            end,
          }
        end
        if player_id == 2 then
          return {
            get_name = function()
              return "AI2"
            end,
            get_head_icon = function()
              return avatar_ai_2
            end,
          }
        end
        if player_id == 3 then
          return {
            get_name = function()
              return "AI3"
            end,
            get_head_icon = function()
              return avatar_ai_3
            end,
          }
        end
        if player_id == 4 then
          return {
            get_name = function()
              return "AI4"
            end,
            get_head_icon = function()
              return avatar_ai_4
            end,
          }
        end
        return nil
      end,
    },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local player_rows = model and model.panel and model.panel.player_rows or nil
  local row1 = player_rows and player_rows[1] or nil
  local row2 = player_rows and player_rows[2] or nil
  local row3 = player_rows and player_rows[3] or nil
  local row4 = player_rows and player_rows[4] or nil
  luassert.truthy(row1 and row1.avatar == 12345, "player1 should keep real role avatar")
  luassert.truthy(row2 and row2.avatar == avatar_ai_2, "player2 should use slot-mapped AI2 avatar")
  luassert.truthy(row3 and row3.avatar == avatar_ai_3, "player3 should use slot-mapped AI3 avatar")
  luassert.truthy(row4 and row4.avatar == avatar_ai_4, "player4 should use slot-mapped AI4 avatar")
end)

it("test_turn_dispatch_rejects_non_current_actor", function()
  local g = _new_game({ ai = {} })
  local state = {
    ui = {
      input_blocked = false,
    },
  }

  local res_auto = dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 2,
  }, {})
  luassert.truthy(res_auto and res_auto.status == "applied", "auto button should allow non-current actor")
  luassert.truthy(control.is_delegated(g.players[2]), "player2 delegation should toggle")

  local res_next = dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "next",
    actor_role_id = 2,
  }, {})
  luassert.truthy(res_next and res_next.status == "rejected", "next button should reject non-current actor")
end)

it("test_turn_dispatch_rejects_choice_non_owner", function()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
    },
  }
  g.turn.pending_choice = {
    id = 9,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = "1",
    options = { { id = 1, label = "X" } },
    allow_cancel = true,
    meta = { player_id = "1" },
  }
  state.pending_choice = g.turn.pending_choice

  local dispatched = nil
  function g:dispatch_action(action)
    dispatched = action
    self.turn.pending_choice = nil
  end

  local res = dispatch.dispatch_action(g, state, {
    type = "choice_select",
    choice_id = 9,
    option_id = 1,
    actor_role_id = 2,
  }, {})

  luassert.truthy(res and res.status == "rejected", "choice_select should reject non-owner actor")
  luassert.truthy(dispatched == nil, "rejected choice should not dispatch")
  luassert.truthy(g.turn.pending_choice ~= nil, "rejected choice should keep pending")
end)

it("test_turn_dispatch_auto_rejects_unmapped_role", function()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
    },
  }
  local before = control.is_delegated(g.players[1])
  local res = dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 99,
  }, {})
  luassert.truthy(res and res.status == "rejected", "auto button should reject unmapped role")
  luassert.truthy(control.is_delegated(g.players[1]) == before, "mapped players delegation should keep unchanged")
end)

it("test_turn_dispatch_choice_action_prefers_turn_pending_choice", function()
  local g = _new_game()
  local turn_choice = {
    id = 707,
    kind = "item_phase_passive",
    owner_role_id = 1,
    options = { { id = 2005, label = "地雷卡" } },
    allow_cancel = true,
    meta = { player_id = 1, phase = "post_action" },
  }
  local stale_state_choice = {
    id = 808,
    kind = "item_phase_passive",
    owner_role_id = 1,
    options = { { id = 2004, label = "路障卡" } },
    allow_cancel = true,
    meta = { player_id = 1, phase = "post_action" },
  }
  g.turn.pending_choice = turn_choice

  local cleared = 0
  local dispatched = nil
  local state = {
    pending_choice = stale_state_choice,
    ui = {
      input_blocked = false,
    },
    _resolved_gameplay_loop_ports = {
      output = {
        get_pending_choice = function(current_state)
          return current_state.pending_choice
        end,
        clear_pending_choice = function(current_state)
          cleared = cleared + 1
          current_state.pending_choice = nil
        end,
        invalidate_ui_model = function() end,
      },
      ui_sync = {
        get_ui_state = function(current_state)
          return current_state and current_state.ui or nil
        end,
        resolve_ui_gate = function()
          return {
            input_blocked = false,
            choice_active = false,
            market_active = false,
            popup_active = false,
          }
        end,
      },
    },
  }

  function g:dispatch_action(action)
    dispatched = action
    self.turn.pending_choice = nil
  end

  local res = dispatch.dispatch_action(g, state, {
    type = "choice_select",
    choice_id = 707,
    option_id = 2005,
    actor_role_id = 1,
  }, {})
  _assert_eq(res and res.status, "applied", "choice_select should apply with turn pending choice")

  _assert_eq(dispatched and dispatched.choice_id, 707, "dispatch should keep turn pending choice id")
  _assert_eq(dispatched and dispatched.option_id, 2005, "dispatch should keep turn pending choice option")
  _assert_eq(cleared, 1, "resolved choice should clear stale runtime pending choice")
end)

-- 槽位 → 道具按「行动者自己的背包」解析：两名玩家同一槽位各持不同的卡,
-- 派发出去的必须是点击者手里那张,绝不串到另一名玩家的背包。
it("test_turn_dispatch_item_slot_resolves_actor_own_inventory", function()
  local g = _new_game()
  local captured = nil
  local actor = g.players[2]
  g.players[1].inventory:add({ id = 3001 })
  actor.inventory:add({ id = 4001 })
  g.turn.current_player_index = 2
  g.turn.pending_choice = {
    id = 66,
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    owner_role_id = actor.id,
    options = { { id = 4001, label = "用 4001" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = actor.id, phase = "pre_action" },
  }
  function g:dispatch_action(action)
    captured = action
    self.turn.pending_choice = nil
  end

  local state = {
    pending_choice = g.turn.pending_choice,
    ui = { input_blocked = false },
  }
  _bind_ui_runtime(state)

  local res = dispatch.dispatch_action(g, state, {
    type = "item_slot_click",
    slot_index = 1,
    actor_role_id = actor.id,
  }, {})

  luassert.truthy(res and res.status == "applied", "item slot click should apply")
  luassert.truthy(captured and captured.type == "choice_select", "choice_select should dispatch")
  luassert.truthy(captured and captured.option_id == 4001, "should read the clicker's own bag, not the other player's")
end)

it("test_turn_dispatch_market_navigation_prefers_turn_pending_choice", function()
  local g, state, calls = _build_market_nav_dispatch_env()
  local turn_choice = {
    id = 101,
    kind = "market_buy",
    owner_role_id = 1,
  }
  state.pending_choice = {
    id = 202,
    kind = "market_buy",
    owner_role_id = 1,
  }
  g.turn.pending_choice = turn_choice

  local validated_choice = nil
  local applied_choice = nil
  local base_validator = require("src.turn.actions.validator")
  local validator_stub = {}
  for key, value in pairs(base_validator) do
    validator_stub[key] = value
  end
  -- 派发器经单入口 validate 校验；stub 的 validate 委托本地覆写的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  validator_stub.validate_choice_action = function(_, _, choice)
    validated_choice = choice
    return true
  end
  _with_reloaded_turn_dispatch({
    ["src.turn.actions.validator"] = validator_stub,
    ["src.rules.market"] = {
      choice = {
        apply_navigation = function(_, choice, action)
          applied_choice = choice
          _assert_eq(action.type, "market_page_next", "should pass navigation action through")
          return true
        end,
      },
    },
  }, function(dispatch_module)
    local res = dispatch_module.dispatch_action(g, state, {
      type = "market_page_next",
      actor_role_id = 1,
      choice_id = turn_choice.id,
    }, {})
    _assert_eq(res and res.status, "applied", "market navigation should apply")
  end)

  _assert_eq(validated_choice, turn_choice, "turn pending choice should take precedence")
  _assert_eq(applied_choice, turn_choice, "navigation should apply to turn pending choice")
  _assert_eq(calls.sync_pending_choice, 1, "successful navigation should sync pending choice once")
  _assert_eq(calls.synced_choice, turn_choice, "synced choice should be turn pending choice")
  _assert_eq(calls.invalidate_ui_model, 1, "market navigation should invalidate ui once")
end)

it("test_turn_dispatch_market_navigation_falls_back_to_state_choice", function()
  local g, state, calls = _build_market_nav_dispatch_env()
  local state_choice = {
    id = 303,
    kind = "market_buy",
    owner_role_id = 1,
  }
  state.pending_choice = state_choice

  local validated_choice = nil
  local base_validator = require("src.turn.actions.validator")
  local validator_stub = {}
  for key, value in pairs(base_validator) do
    validator_stub[key] = value
  end
  -- 派发器经单入口 validate 校验；stub 的 validate 委托本地覆写的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  validator_stub.validate_choice_action = function(_, _, choice)
    validated_choice = choice
    return true
  end
  _with_reloaded_turn_dispatch({
    ["src.turn.actions.validator"] = validator_stub,
    ["src.rules.market"] = {
      choice = {
        apply_navigation = function()
          return true
        end,
      },
    },
  }, function(dispatch_module)
    local res = dispatch_module.dispatch_action(g, state, {
      type = "market_tab_select",
      actor_role_id = 1,
      choice_id = state_choice.id,
      tab = "item",
    }, {})
    _assert_eq(res and res.status, "applied", "state fallback choice should still apply")
  end)

  _assert_eq(validated_choice, state_choice, "state pending choice should be used when turn choice is absent")
  _assert_eq(calls.synced_choice, state_choice, "synced choice should match state pending choice")
end)

it("test_turn_dispatch_market_navigation_rejects_non_market_choice", function()
  local g, state, calls = _build_market_nav_dispatch_env()
  state.pending_choice = {
    id = 404,
    kind = "item_phase_passive",
    owner_role_id = 1,
  }

  local validate_calls = 0
  local apply_calls = 0
  local base_validator = require("src.turn.actions.validator")
  local validator_stub = {}
  for key, value in pairs(base_validator) do
    validator_stub[key] = value
  end
  -- 派发器经单入口 validate 校验；stub 的 validate 委托本地覆写的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  validator_stub.validate_choice_action = function()
    validate_calls = validate_calls + 1
    return true
  end
  _with_reloaded_turn_dispatch({
    ["src.turn.actions.validator"] = validator_stub,
    ["src.rules.market"] = {
      choice = {
        apply_navigation = function()
          apply_calls = apply_calls + 1
          return true
        end,
      },
    },
  }, function(dispatch_module)
    local res = dispatch_module.dispatch_action(g, state, {
      type = "market_page_prev",
      actor_role_id = 1,
      choice_id = 404,
    }, {})
    _assert_eq(res and res.status, "rejected", "non-market choice should reject navigation")
  end)

  _assert_eq(validate_calls, 0, "non-market choice should reject before choice validation")
  _assert_eq(apply_calls, 0, "non-market choice should reject before navigation apply")
  _assert_eq(calls.sync_pending_choice, 0, "rejected navigation should not sync pending choice")
end)

it("test_turn_dispatch_market_navigation_rejects_when_validator_fails", function()
  local g, state, calls = _build_market_nav_dispatch_env()
  state.pending_choice = {
    id = 505,
    kind = "market_buy",
    owner_role_id = 1,
  }

  local apply_calls = 0
  local base_validator = require("src.turn.actions.validator")
  local validator_stub = {}
  for key, value in pairs(base_validator) do
    validator_stub[key] = value
  end
  -- 派发器经单入口 validate 校验；stub 的 validate 委托本地覆写的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  validator_stub.validate_choice_action = function()
    return false
  end
  _with_reloaded_turn_dispatch({
    ["src.turn.actions.validator"] = validator_stub,
    ["src.rules.market"] = {
      choice = {
        apply_navigation = function()
          apply_calls = apply_calls + 1
          return true
        end,
      },
    },
  }, function(dispatch_module)
    local res = dispatch_module.dispatch_action(g, state, {
      type = "market_page_next",
      actor_role_id = 1,
      choice_id = 505,
    }, {})
    _assert_eq(res and res.status, "rejected", "validator failure should reject navigation")
  end)

  _assert_eq(apply_calls, 0, "validator failure should stop before apply_navigation")
  _assert_eq(calls.sync_pending_choice, 0, "validator failure should not sync pending choice")
end)

it("test_turn_dispatch_market_navigation_rejects_when_apply_fails", function()
  local g, state, calls = _build_market_nav_dispatch_env()
  state.pending_choice = {
    id = 606,
    kind = "market_buy",
    owner_role_id = 1,
  }

  local base_validator = require("src.turn.actions.validator")
  local validator_stub = {}
  for key, value in pairs(base_validator) do
    validator_stub[key] = value
  end
  -- 派发器经单入口 validate 校验；stub 的 validate 委托本地覆写的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  validator_stub.validate_choice_action = function()
    return true
  end
  _with_reloaded_turn_dispatch({
    ["src.turn.actions.validator"] = validator_stub,
    ["src.rules.market"] = {
      choice = {
        apply_navigation = function()
          return false
        end,
      },
    },
  }, function(dispatch_module)
    local res = dispatch_module.dispatch_action(g, state, {
      type = "market_page_next",
      actor_role_id = 1,
      choice_id = 606,
    }, {})
    _assert_eq(res and res.status, "rejected", "apply_navigation failure should reject navigation")
  end)

  _assert_eq(calls.sync_pending_choice, 0, "failed apply_navigation should not sync pending choice")
end)

it("test_ui_intent_dispatcher_market_confirm_routes_choice_select", function()
  local captured = nil
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        captured = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = {
      input_blocked = false,
    },
  }
  local game = {}

  _with_patches({}, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_confirm",
      choice_id = 12,
      option_id = 34,
    }, {})
  end)

  luassert.truthy(captured and captured.type == "choice_select", "market_confirm should route as choice_select")
  _assert_eq(captured and captured.choice_id, 12, "market_confirm should keep choice id")
  _assert_eq(captured and captured.option_id, 34, "market_confirm should keep option id")
end)

it("test_ui_model_update_refreshes_targeted_slices_only", function()
  local ui_model = require("src.ui.view")
  local g = _new_game()
  local state = {
    ui = {
      item_slots = { 1, 2, 3, 4, 5 },
      auto_play = false,
    },
  }
  local env = {
    game = g,
    ui_state = state,
    last_turn = g.last_turn,
    finished = g.finished,
  }
  local model = ui_model.build(g, env)

  local original_board = model.board
  local original_turn_label = model.panel.turn_label
  local original_choice_owner_id = model.item_choice_owner_id
  local original_popup = model.popup

  g:set_player_cash(g.players[1], 4321)
  control.toggle_manual_delegation(g.players[1])
  g.turn.turn_count = 7
  g.turn.countdown_seconds = 12
  g.turn.countdown_active = true

  local updated = ui_model.update(model, g, env, {
    turn = true,
    turn_countdown = true,
  })

  luassert.truthy(updated == model, "update should mutate existing model table")
  luassert.truthy(updated.board == original_board, "turn-only refresh should keep board slice")
  luassert.truthy(updated.panel.turn_label ~= original_turn_label, "turn refresh should rebuild turn label")
  luassert.truthy(updated.item_choice_owner_id == original_choice_owner_id, "turn refresh should keep normalized choice owner when choice is unchanged")
  luassert.truthy(updated.popup == original_popup, "non-ui refresh should keep popup slice")
  _assert_eq(updated.current_player_cash, 4321, "current player cash should refresh")
  _assert_eq(updated.turn_count, 7, "turn count should refresh")
  luassert.truthy(updated.panel.turn_label ~= nil, "turn label should remain populated")
end)

it("test_ui_model_update_refreshes_inventory_owned_slots", function()
  local ui_model = require("src.ui.view")
  local g = _new_game()
  local state = {
    ui = {
      item_slots = { 1, 2, 3, 4, 5 },
      auto_play = false,
    },
  }
  local env = {
    game = g,
    ui_state = state,
    last_turn = g.last_turn,
    finished = g.finished,
  }
  local model = ui_model.build(g, env)
  local before_has_2001 = false
  for _, id in ipairs(model.item_slots or {}) do
    if id == 2001 then before_has_2001 = true end
  end

  g.players[1].inventory:add({ id = 2001 })

  local updated = ui_model.update(model, g, env, {
    inventory = true,
  })

  local after_has_2001 = false
  for _, id in ipairs(updated.item_slots or {}) do
    if id == 2001 then after_has_2001 = true end
  end
  luassert.truthy(not before_has_2001, "item 2001 should not be present before inventory add")
  luassert.truthy(after_has_2001, "inventory refresh should include newly added item")
  luassert.truthy(updated.item_slots_by_player ~= nil, "inventory refresh should keep per-player slots")
  luassert.truthy(updated.item_choice_owner_id ~= nil or updated.choice == nil, "inventory refresh should recompute choice owner when needed")
end)

it("test_panel_slice_update_refreshes_only_requested_flags", function()
  local g = _new_game()
  local env = { game = g }
  local turn = g.turn
  local current_player_id = g.players[1].id
  local delegated_by_player = { [current_player_id] = false }
  local panel = panel_slice.build(g, env, turn, current_player_id, delegated_by_player)
  local player_rows = panel.player_rows
  local auto_label = panel.auto_label
  _assert_eq(auto_label, "托管", "initial auto label should use fixed delegate copy")

  control.toggle_manual_delegation(g.players[1])
  turn.no_action_notice_active = true
  turn.no_action_notice_text = "locked"

  local updated = panel_slice.update(panel, g, env, turn, current_player_id, {
    [current_player_id] = true,
  }, {
    auto_label = true,
  })

  luassert.truthy(updated == panel, "panel update should mutate the existing panel table")
  luassert.truthy(updated.player_rows == player_rows, "auto-label-only refresh should keep player rows")
  luassert.truthy(updated.auto_label == auto_label, "auto-label-only refresh should keep fixed delegate copy")
  luassert.truthy(updated.no_action_text ~= "locked", "no_action notice should not refresh without turn_label flag")
end)

it("test_panel_slice_tracks_countdown_visibility", function()
  local g = _new_game()
  local env = { game = g }
  local turn = g.turn
  local current_player_id = g.players[1].id
  local delegated_by_player = { [current_player_id] = false }
  local panel = panel_slice.build(g, env, turn, current_player_id, delegated_by_player)

  _assert_eq(panel.countdown_visible, false, "initial countdown should be hidden when inactive")

  turn.countdown_active = true
  turn.countdown_seconds = 12
  local updated = panel_slice.update(panel, g, env, turn, current_player_id, delegated_by_player, {
    turn_label = true,
  })

  luassert.truthy(updated == panel, "panel update should reuse panel table")
  _assert_eq(updated.countdown_visible, true, "turn label refresh should track active countdown visibility")
end)

it("test_modal_presenter_select_choice_option_refreshes_secondary_confirm_copy", function()
  local state = _build_choice_modal_state()
  local canvas_store = require("src.ui.state.canvas_store")
  local labels = {}
  local choice_dirty_marks = 0
  state.ui.set_label = function(_, node_name, value)
    labels[node_name] = value
  end
  state.game = {}
  state.ui.choice_active = true
  state.ui.active_choice_screen_key = "secondary_confirm"
  state.ui.choice_screens.secondary_confirm = {
    title = "通用二次确认_标题",
    body = "通用二次确认_文本",
  }
  state.ui_model = {
    choice = {
      kind = "tax_card_prompt",
      route_key = "secondary_confirm",
      options = {
        { id = "confirm", label = "确认" },
      },
    },
  }
  _bind_ui_runtime(state)

  _with_patches({
    {
      target = canvas_store,
      key = "mark_dirty",
      value = function(_, key)
        if key == "choice" then
          choice_dirty_marks = choice_dirty_marks + 1
        end
      end,
    },
  }, function()
    modal_presenter.select_choice_option(state, "confirm")
  end)

  luassert.truthy(labels["通用二次确认_标题"] ~= nil, "secondary confirm title should refresh")
  luassert.truthy(labels["通用二次确认_文本"] ~= nil, "secondary confirm body should refresh")
  _assert_eq(choice_dirty_marks, 0, "secondary confirm selection should not write choice canvas dirty")
  _assert_eq(state.ui_runtime and state.ui_runtime.ui_dirty, true, "secondary confirm selection should invalidate ui_model")
end)

it("test_modal_state_select_choice_option_invalidates_ui_model_without_choice_canvas_dirty", function()
  local modal_state = require("src.ui.state.modal")
  local canvas_store = require("src.ui.state.canvas_store")
  local state = {}
  local choice_dirty_marks = 0
  _bind_ui_runtime(state)
  runtime_state.set_ui_dirty(state, false)

  _with_patches({
    {
      target = canvas_store,
      key = "mark_dirty",
      value = function(_, key)
        if key == "choice" then
          choice_dirty_marks = choice_dirty_marks + 1
        end
      end,
    },
  }, function()
    modal_state.select_choice_option(state, 101)
  end)

  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, 101, "modal_state should still store selected option in ui_runtime")
  _assert_eq(choice_dirty_marks, 0, "modal_state choice selection should not write choice canvas dirty")
  _assert_eq(_ui_runtime(state).ui_dirty, true, "modal_state choice selection should invalidate ui_model")
end)

it("test_modal_presenter_close_choice_modal_resets_choice_and_market", function()
  local choice_state, choice_nodes, choice_query = _build_choice_modal_state()
  choice_state.ui.choice_active = true
  choice_state.ui.market_active = false
  choice_state.ui.active_choice_screen_key = "secondary_confirm"
  choice_nodes["通用二次确认屏"].visible = true
  _ui_runtime(choice_state).choice_visible_option_ids = { "stale-choice" }
  _ui_runtime(choice_state).pending_choice_selected_option_id = "stale-choice"

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = choice_query } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.close_choice_modal(choice_state)
  end)

  luassert.truthy(choice_state.ui.choice_active == false, "choice-only close should deactivate the choice screen")
  luassert.is_nil(choice_state.ui.active_choice_screen_key, "choice-only close should clear the active screen key")
  luassert.truthy(choice_nodes["通用二次确认屏"].visible == false,
    "choice-only close should hide the active choice canvas")
  luassert.is_nil(_ui_runtime(choice_state).choice_visible_option_ids,
    "choice-only close should clear visible option ids through public modal state")
  luassert.is_nil(_ui_runtime(choice_state).pending_choice_selected_option_id,
    "choice-only close should clear the selected option through public modal state")

  local market_state, market_nodes, market_query = _build_choice_modal_state()
  market_state.ui.choice_active = true
  market_state.ui.market_active = true
  market_state.ui.active_choice_screen_key = "secondary_confirm"
  market_nodes["通用二次确认屏"].visible = true
  market_nodes["黑市屏"].visible = true
  _ui_runtime(market_state).choice_visible_option_ids = { "stale-market" }
  _ui_runtime(market_state).pending_choice_selected_option_id = "stale-market"

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = market_query } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.close_choice_modal(market_state)
  end)

  luassert.truthy(market_state.ui.choice_active == false,
    "simultaneous choice and market close should deactivate the choice screen")
  luassert.is_nil(market_state.ui.active_choice_screen_key,
    "simultaneous choice and market close should clear the active screen key")
  luassert.truthy(market_nodes["通用二次确认屏"].visible == false,
    "simultaneous choice and market close should hide the choice canvas")
  luassert.truthy(market_state.ui.market_active == false,
    "simultaneous choice and market close should deactivate the market")
  luassert.truthy(market_nodes["黑市屏"].visible == false,
    "simultaneous choice and market close should hide the market canvas")
  luassert.is_nil(_ui_runtime(market_state).choice_visible_option_ids,
    "simultaneous choice and market close should clear visible option ids")
  luassert.is_nil(_ui_runtime(market_state).pending_choice_selected_option_id,
    "simultaneous choice and market close should clear the selected option")
end)


end)
