local support = require("support.domain_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")
local property_value = require("src.rules.commerce.property_value")

local _assert_eq = support.assert_eq

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _with_offer_phase_cfg(item_ids_to_patch, fn)
  local original_cfg = inventory.cfg
  support.with_patches({
    {
      target = inventory,
      key = "cfg",
      value = function(item_id)
        local cfg = original_cfg(item_id)
        if item_ids_to_patch[item_id] ~= true or type(cfg) ~= "table" then
          return cfg
        end
        local patched = {}
        for key, value in pairs(cfg) do
          patched[key] = value
        end
        patched.offer_in_phases = { "post_action" }
        return patched
      end,
    },
  }, fn)
end

local function _set_current_player_on_rival_land(g, level)
  local p = g:current_player()
  local rival = g.players[2]
  local land_index, land_tile = support.first_land_tile(g.board)
  g:update_player_position(p, land_index)
  g:set_tile_owner(land_tile, rival.id)
  g:set_player_property(rival, land_tile.id, true)
  if level ~= nil then
    g:set_tile_level(land_tile, level)
  end
  return p, land_tile
end

describe("item_availability_rent_response_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("free_rent unavailable on non-property tile", function()
    _with_offer_phase_cfg({ [item_ids.free_rent] = true }, function()
      local g = _new_game()
      local p = g:current_player()
      local start_index = support.first_tile_by_type(g.board, "start")

      g:update_player_position(p, start_index)

      local result = availability.analyze_offer(g, p, item_ids.free_rent, "post_action")
      _assert_eq(result.can_offer, false, "free_rent should stay unavailable on non-property tile")
      _assert_eq(result.deny_reason, "special_condition_failed", "free_rent non-property tile deny reason")
    end)
  end)

  it("free_rent unavailable on own tile", function()
    _with_offer_phase_cfg({ [item_ids.free_rent] = true }, function()
      local g = _new_game()
      local p = g:current_player()
      local land_index, land_tile = support.first_land_tile(g.board)

      g:update_player_position(p, land_index)
      g:set_tile_owner(land_tile, p.id)
      g:set_player_property(p, land_tile.id, true)

      local result = availability.analyze_offer(g, p, item_ids.free_rent, "post_action")
      _assert_eq(result.can_offer, false, "free_rent should stay unavailable on self-owned tile")
      _assert_eq(result.deny_reason, "special_condition_failed", "free_rent own-tile deny reason")
    end)
  end)

  it("free_rent available on rival tile", function()
    _with_offer_phase_cfg({ [item_ids.free_rent] = true }, function()
      local g = _new_game()
      local p = _set_current_player_on_rival_land(g)

      local result = availability.analyze_offer(g, p, item_ids.free_rent, "post_action")
      _assert_eq(result.can_offer, true, "free_rent should be offered on rival-owned tile")
      _assert_eq(result.can_execute_now, true, "free_rent should execute immediately when offered")
      _assert_eq(result.deny_reason, "ok", "free_rent rival-tile keeps ok deny_reason")
    end)
  end)

  it("strong unavailable when cash is below total invested", function()
    _with_offer_phase_cfg({ [item_ids.strong] = true }, function()
      local g = _new_game()
      local p, land_tile = _set_current_player_on_rival_land(g, 2)
      local total_invested = property_value.total_invested(land_tile, 2)

      g:set_player_cash(p, total_invested - 1)

      local result = availability.analyze_offer(g, p, item_ids.strong, "post_action")
      _assert_eq(result.can_offer, false, "strong should stay unavailable below total invested")
      _assert_eq(result.deny_reason, "special_condition_failed", "strong low-cash deny reason")
    end)
  end)

  it("strong available when cash covers total invested", function()
    _with_offer_phase_cfg({ [item_ids.strong] = true }, function()
      local g = _new_game()
      local p, land_tile = _set_current_player_on_rival_land(g, 2)
      local total_invested = property_value.total_invested(land_tile, 2)

      g:set_player_cash(p, total_invested)

      local result = availability.analyze_offer(g, p, item_ids.strong, "post_action")
      _assert_eq(result.can_offer, true, "strong should be offered when cash covers total invested")
      _assert_eq(result.can_execute_now, true, "strong should execute immediately when offered")
      _assert_eq(result.deny_reason, "ok", "strong exact-cash keeps ok deny_reason")
    end)
  end)
end)
