---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local with_patches = support.with_patches

describe("ui_bootstrap", function()
  it("required_click_nodes_appends_extras", function()
    local ui_bootstrap = require("src.app.ui_bootstrap")
    local ui_manager_nodes = {
      { "基础屏_行动按钮" },
    }
    local missing = nil

    with_patches({
      {
        target = _G,
        key = "RegisterTriggerEvent",
        value = function(_, cb)
          cb()
        end,
      },
      {
        target = _G,
        key = "EVENT",
        value = {
          GAME_INIT = "GAME_INIT",
        },
      },
      {
        target = package.loaded,
        key = "vendor.third_party.UIManager.Utils",
        value = true,
      },
      {
        target = package.loaded,
        key = "Data.UIManagerNodes",
        value = ui_manager_nodes,
      },
      {
        target = _G,
        key = "UIManager",
        value = {
          Builder = {
            new = function()
              return {}
            end,
          },
        },
      },
      {
        target = require("src.ui.coord.ui_events"),
        key = "send_to_all",
        value = function() end,
      },
      {
        target = require("src.ui.coord.canvas_event_router"),
        key = "bind",
        value = function() end,
      },
      {
        target = require("src.ui.coord.ui_runtime"),
        key = "init_ui_assets",
        value = function() end,
      },
      {
        target = require("src.ui.coord.ui_runtime"),
        key = "capture_player_colors",
        value = function() end,
      },
      {
        target = require("src.ui.render.board.scene"),
        key = "init",
        value = function() end,
      },
      {
        target = require("src.host.context"),
        key = "current",
        value = function()
          return nil
        end,
      },
      {
        target = require("src.foundation.ports.runtime_ports"),
        key = "resolve_roles",
        value = function()
          return {}
        end,
      },
      {
        target = require("src.foundation.ports.runtime_ports"),
        key = "schedule",
        value = function(_, fn)
          fn()
        end,
      },
      {
      target = require("src.state.ui_role_globals"),
        key = "install",
        value = function()
          return {}
        end,
      },
    }, function()
      local ok, err = pcall(function()
        ui_bootstrap.install({}, {
          {
            board = { map = {} },
          },
        }, {
          start_runtime = function()
            return {
              board = { map = {} },
            }
          end,
        })
      end)
      missing = err
      assert(ok == false, "ui bootstrap should validate missing UI nodes")
    end)

    assert(tostring(missing):find("UI 节点缺失", 1, true) ~= nil, "ui bootstrap should report missing required nodes")
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
