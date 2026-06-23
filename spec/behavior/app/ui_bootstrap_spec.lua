---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local with_patches = support.with_patches

local function _shared_install_patches()
  return {
    { target = _G, key = "RegisterTriggerEvent", value = function(_, cb) cb() end },
    { target = _G, key = "EVENT", value = { GAME_INIT = "GAME_INIT" } },
    { target = package.loaded, key = "vendor.third_party.UIManager.Utils", value = true },
    { target = _G, key = "UIManager", value = { Builder = { new = function() return {} end } } },
    { target = require("src.ui.coord.ui_events"), key = "send_to_all", value = function() end },
    { target = require("src.ui.coord.canvas_event_router"), key = "bind", value = function() end },
    { target = require("src.ui.coord.ui_runtime"), key = "init_ui_assets", value = function() end },
    { target = require("src.ui.coord.ui_runtime"), key = "capture_player_colors", value = function() end },
    { target = require("src.ui.render.board.scene"), key = "init", value = function() end },
    { target = require("src.host.context"), key = "current", value = function() return nil end },
    { target = require("src.foundation.ports.runtime_ports"), key = "resolve_roles", value = function() return {} end },
    { target = require("src.foundation.ports.runtime_ports"), key = "schedule", value = function(_, fn) fn() end },
    { target = require("src.state.ui_role_globals"), key = "install", value = function() return {} end },
  }
end

local function _with_install_patches(extras, fn)
  local patches = _shared_install_patches()
  for _, extra in ipairs(extras or {}) do
    patches[#patches + 1] = extra
  end
  return with_patches(patches, fn)
end

local function _install_with_runtime(state, opts)
  local ui_bootstrap = require("src.app.ui_bootstrap")
  return ui_bootstrap.install(state, { { board = { map = {} } } }, opts or {
    start_runtime = function() return { board = { map = {} } } end,
  })
end

local function _contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

describe("ui_bootstrap", function()
  it("bootstrap_nodes_build_required_click_nodes_includes_schema_groups_and_extras", function()
    local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
    local base_nodes = require("src.ui.schema.base")
    local player_choice_nodes = require("src.ui.schema.player_choice")
    local remote_choice_nodes = require("src.ui.schema.remote_choice")
    local permanent_nodes = require("src.ui.schema.permanent")
    local base_contract = require("src.ui.schema.base_contract")

    local required = bootstrap_nodes.build_required_click_nodes({ extra = { "额外_按钮" } })

    assert(_contains(required, base_nodes.action_button), "required nodes should include base action button")
    assert(_contains(required, base_nodes.end_button), "required nodes should include optional end button")
    assert(_contains(required, player_choice_nodes.slots[1]), "required nodes should include player choice slots")
    assert(_contains(required, remote_choice_nodes.options[1]), "required nodes should include remote choice options")
    assert(_contains(required, permanent_nodes.card_outlines[1]), "required nodes should include permanent card outlines")
    assert(_contains(required, base_contract.action_log.toggle_targets[1]),
      "required nodes should include action log toggle targets")
    assert(_contains(required, "额外_按钮"), "required nodes should include caller extras")
  end)

  it("bootstrap_nodes_ignores_non_table_extra_nodes", function()
    local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
    local required = bootstrap_nodes.build_required_click_nodes({ extra = "not-a-list" })

    assert(_contains(required, "not-a-list") == false, "non-table extras should not be appended")
  end)

  it("bootstrap_nodes_fallback_validation_filters_known_and_dedupes_missing_nodes", function()
    local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
    local ui_manager_nodes = {
      { "已知按钮" },
      { "" },
      { 123 },
      { [0] = "零号槽不是节点名" },
      "malformed",
    }

    local missing = bootstrap_nodes.validate_required_nodes(ui_manager_nodes, {
      "已知按钮",
      "缺失按钮",
      "缺失按钮",
      "零号槽不是节点名",
      "",
      123,
    })

    assert(#missing == 2, "fallback validation should report each missing string node once")
    assert(missing[1] == "缺失按钮", "fallback validation should keep the missing node name")
    assert(missing[2] == "零号槽不是节点名",
      "fallback validation should only read exported node names from entry slot 1")

    local empty_missing = bootstrap_nodes.validate_required_nodes({}, { "" })
    assert(#empty_missing == 0, "empty required node names should be ignored")
  end)

  it("bootstrap_nodes_assert_reports_single_missing_node", function()
    local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
    local ok, err = pcall(function()
      bootstrap_nodes.assert_required_nodes({
        validate = function()
          return { "唯一缺失按钮" }
        end,
      })
    end)

    assert(ok == false, "one missing required node should fail bootstrap validation")
    assert(tostring(err):find("唯一缺失按钮", 1, true),
      "bootstrap validation error should include the missing node")
  end)

  it("required_click_nodes_appends_extras", function()
    local ui_manager_nodes = {
      { "基础屏_行动按钮" },
    }
    local missing = nil

    _with_install_patches({
      { target = package.loaded, key = "Data.UIManagerNodes", value = ui_manager_nodes },
    }, function()
      local ok, err = pcall(_install_with_runtime, {})
      missing = err
      assert(ok == false, "ui bootstrap should validate missing UI nodes")
    end)

    assert(tostring(missing):find("UI 节点缺失", 1, true) ~= nil, "ui bootstrap should report missing required nodes")
  end)

  it("scheduled callback switches canvas to base to hide non-base canvases", function()
    local canvas_coordinator = require("src.ui.coord.canvas_coordinator")
    local base_nodes = require("src.ui.schema.base")

    local ui_manager_nodes = { validate = function() return {} end }
    local switch_calls = {}

    _with_install_patches({
      { target = package.loaded, key = "Data.UIManagerNodes", value = ui_manager_nodes },
      { target = canvas_coordinator, key = "switch", value = function(ui, target)
        switch_calls[#switch_calls + 1] = { ui = ui, target = target }
      end },
    }, function()
      _install_with_runtime({ ui = {} })
    end)

    local switched_to_base = false
    for _, call in ipairs(switch_calls) do
      if call.target == base_nodes.canvas then
        switched_to_base = true
        break
      end
    end
    assert(switched_to_base,
      "bootstrap should switch canvas to base to hide non-base canvases at startup")
  end)

  it("install_uses_existing_current_game_ref_without_start_runtime", function()
    local board_scene = require("src.ui.render.board.scene")
    local map = { path = { 9, 8, 7 } }
    local current_game = { board = { map = map } }
    local captured = {}
    local start_called = false

    _with_install_patches({
      { target = package.loaded, key = "Data.UIManagerNodes", value = { validate = function() return {} end } },
      { target = board_scene, key = "init", value = function(state, board_map, game)
        captured.state = state
        captured.map = board_map
        captured.game = game
      end },
    }, function()
      local state = { ui = {} }
      require("src.app.ui_bootstrap").install(state, { current_game }, {
        start_runtime = function()
          start_called = true
          return { board = { map = {} } }
        end,
      })
      assert(captured.state == state, "bootstrap should initialize board scene with install state")
    end)

    assert(start_called == false, "existing current_game ref should not invoke start_runtime")
    assert(captured.game == current_game, "bootstrap should use existing current_game ref")
    assert(captured.map == map, "bootstrap should pass current game board map to board scene")
  end)

  it("install_falls_back_to_start_runtime_when_current_game_ref_is_empty", function()
    local board_scene = require("src.ui.render.board.scene")
    local map = { path = { 1 } }
    local current_game = { board = { map = map } }
    local current_game_ref = { nil }
    local captured = {}
    local start_called = false

    _with_install_patches({
      { target = package.loaded, key = "Data.UIManagerNodes", value = { validate = function() return {} end } },
      { target = board_scene, key = "init", value = function(_, board_map, game)
        captured.map = board_map
        captured.game = game
      end },
    }, function()
      require("src.app.ui_bootstrap").install({ ui = {} }, current_game_ref, {
        start_runtime = function(_, ref)
          start_called = true
          ref[1] = current_game
          return current_game
        end,
      })
    end)

    assert(start_called == true, "empty current_game ref should invoke start_runtime")
    assert(current_game_ref[1] == current_game, "start_runtime should be able to populate the shared game ref")
    assert(captured.game == current_game, "bootstrap should use the runtime-created current game")
    assert(captured.map == map, "bootstrap should pass runtime-created board map to board scene")
  end)

  it("install_accepts_nil_opts_when_current_game_ref_is_present", function()
    local ui_manager_nodes = { validate = function() return {} end }
    local ok, err
    _with_install_patches({
      { target = package.loaded, key = "Data.UIManagerNodes", value = ui_manager_nodes },
    }, function()
      ok, err = pcall(function()
        require("src.app.ui_bootstrap").install({ ui = {} }, { { board = { map = {} } } }, nil)
      end)
    end)

    assert(ok == true, "nil opts should be accepted when current_game already exists: " .. tostring(err))
  end)

  it("spawns_startup_synthetic_actors", function()
    local ui_bootstrap = require("src.app.ui_bootstrap")
    local capture = {
      registered_specs = nil,
      spawned_map = nil,
    }

    with_patches({
      {
        target = require("src.host.context"),
        key = "current",
        value = function()
          return {
            synthetic_actor_registry = {
              register_specs = function(specs)
                capture.registered_specs = specs
              end,
              spawn_pending = function(map_cfg)
                capture.spawned_map = map_cfg
              end,
            },
          }
        end,
      },
    }, function()
      local game = {
        startup_synthetic_players = {
          { player_id = -2, unit_key = "npc_2" },
        },
        board = { map = { path = { 1, 2, 3 } } },
      }
      ui_bootstrap.spawn_startup_synthetic_actors(game)
    end)

    assert(type(capture.registered_specs) == "table" and capture.registered_specs[1].player_id == -2,
      "ui bootstrap should register startup synthetic actor specs")
    assert(capture.spawned_map and capture.spawned_map.path[1] == 1,
      "ui bootstrap should spawn pending synthetic actors with board map")
  end)
end)
