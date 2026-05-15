---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.runtime_support")
local _assert_eq = support.assert_eq
local runtime_constants = require("src.config.gameplay.runtime_constants")

describe("synthetic_actor_registry", function()
  it("spawns_from_first_path_tile", function()
    local registry_module = require("src.host.synthetic_actor_registry")
    local created = {}
    local registry = registry_module.new({
      LuaAPI = {
        query_unit = function(name)
          return {
            get_position = function()
              created.query_name = name
              return { x = 1, y = 2, z = 3 }
            end,
          }
        end,
      },
      GameAPI = {
        create_creature_fixed_scale = function(unit_key, pos, rot)
          created[#created + 1] = { unit_key = unit_key, pos = pos, rot = rot }
          return {
            start_ai = function() end,
          }
        end,
      },
    })

    registry.register_specs({
      { player_id = -2, unit_key = "npc_2", avatar_image_key = 1002 },
    })
    registry.spawn_pending({
      path = { 7, 8, 9 },
    })

    _assert_eq(created.query_name, "t7", "registry should use the first path tile as spawn anchor")
    _assert_eq(created[1].unit_key, "npc_2", "registry should spawn configured synthetic unit key")
    _assert_eq(created[1].pos.x, 1, "registry should pass queried spawn position to GameAPI")
    _assert_eq(created[1].rot, runtime_constants.q_left, "registry should spawn synthetic actors facing left")
  end)

  it("reset_destroys_spawned_actor_and_clears_registry", function()
    local registry_module = require("src.host.synthetic_actor_registry")
    local destroyed = {}
    local spawned_unit = {
      id = "synthetic_unit",
      start_ai = function() end,
    }
    local registry = registry_module.new({
      LuaAPI = {
        query_unit = function()
          return {
            get_position = function()
              return { x = 0, y = 0, z = 0 }
            end,
          }
        end,
      },
      GameAPI = {
        create_creature_fixed_scale = function()
          return spawned_unit
        end,
        destroy_unit = function(unit)
          destroyed[#destroyed + 1] = unit
        end,
      },
    })

    registry.register_specs({
      { player_id = -3, unit_key = "npc_3", avatar_image_key = 1003 },
    })
    registry.spawn_pending({
      path = { 1 },
    })
    assert(registry.resolve_actor(-3) ~= nil, "spawned synthetic actor should be resolvable before reset")

    registry.reset()

    _assert_eq(#destroyed, 1, "registry reset should destroy spawned synthetic actor")
    _assert_eq(destroyed[1], spawned_unit, "registry reset should destroy the created unit")
    _assert_eq(registry.resolve_actor(-3), nil, "registry reset should clear actor lookup")
  end)

  it("adapter_lose_destroys_unit_and_drops_from_registry", function()
    local registry_module = require("src.host.synthetic_actor_registry")
    local destroyed = {}
    local spawned_unit = {
      id = "synthetic_unit_lose",
      start_ai = function() end,
    }
    local registry = registry_module.new({
      LuaAPI = {
        query_unit = function()
          return {
            get_position = function()
              return { x = 0, y = 0, z = 0 }
            end,
          }
        end,
      },
      GameAPI = {
        create_creature_fixed_scale = function()
          return spawned_unit
        end,
        destroy_unit = function(unit)
          destroyed[#destroyed + 1] = unit
        end,
      },
    })

    registry.register_specs({
      { player_id = -4, unit_key = "npc_4", avatar_image_key = 1004 },
    })
    registry.spawn_pending({ path = { 1 } })

    local actor = assert(registry.resolve_actor(-4), "actor must exist before lose")
    local adapter = assert(actor.adapter, "actor must expose adapter")

    _assert_eq(adapter.lose(), true, "lose should report retirement happened")
    _assert_eq(#destroyed, 1, "lose should destroy the synthetic unit")
    _assert_eq(destroyed[1], spawned_unit, "lose should destroy the spawned unit")
    _assert_eq(registry.resolve_actor(-4), nil, "lose should drop the actor from the registry")

    _assert_eq(adapter.lose(), false, "second lose call should be a no-op")
    _assert_eq(#destroyed, 1, "second lose call should not double-destroy the unit")
  end)

  it("adapter_die_retires_actor_like_lose", function()
    local registry_module = require("src.host.synthetic_actor_registry")
    local destroyed = {}
    local spawned_unit = {
      id = "synthetic_unit_die",
      start_ai = function() end,
    }
    local registry = registry_module.new({
      LuaAPI = {
        query_unit = function()
          return {
            get_position = function()
              return { x = 0, y = 0, z = 0 }
            end,
          }
        end,
      },
      GameAPI = {
        create_creature_fixed_scale = function()
          return spawned_unit
        end,
        destroy_unit = function(unit)
          destroyed[#destroyed + 1] = unit
        end,
      },
    })

    registry.register_specs({
      { player_id = -5, unit_key = "npc_5", avatar_image_key = 1005 },
    })
    registry.spawn_pending({ path = { 1 } })

    local adapter = assert(registry.resolve_actor(-5).adapter, "adapter required")
    _assert_eq(adapter.die(), true, "die should retire the actor")
    _assert_eq(#destroyed, 1, "die should destroy the unit")
    _assert_eq(adapter.lose(), false, "lose after die should be a no-op")
  end)
end)
