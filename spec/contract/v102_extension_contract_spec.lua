local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

describe("v102_extension_contract", function()
  it("publishes_reveal_constants", function()
    local event_kinds = require("src.config.gameplay.event_kinds")
    local timing = require("src.config.gameplay.timing")

    _assert_eq(event_kinds.item_get_reveal, "item_get_reveal", "item reveal event kind should be stable")
    _assert_eq(timing.item_get_reveal_seconds, 3.0, "item reveal duration should be fixed at 3s")
  end)

  it("splits_skin_and_item_atlas_schema", function()
    local skin_schema = require("src.ui.schema.skin")
    local item_atlas_schema = require("src.ui.schema.item_atlas")
    local market_schema = require("src.ui.schema.market")
    local market_layout = require("src.ui.schema.market_layout")

    _assert_eq(#skin_schema.slots, 6, "skin schema should expose six slots")
    _assert_eq(#item_atlas_schema.slots, 8, "item atlas schema should expose eight slots")
    assert(market_schema.tab_skin == nil, "market schema should not expose retired skin tab")
    assert(market_layout.tab_skin == nil, "market layout should not expose retired skin tab")
  end)

  it("item_atlas_catalog_is_derived_from_items", function()
    local items = require("src.config.content.items")
    local item_atlas = require("src.config.content.item_atlas")

    _assert_eq(#item_atlas, #items, "atlas should mirror visible item catalog size")
    _assert_eq(item_atlas[1].id, items[1].id, "atlas should preserve item id")
    _assert_eq(item_atlas[1].description, items[1].description, "atlas should reuse item description")
  end)

  it("coordinators_keep_skin_and_atlas_state_separate", function()
    local skin_panel = require("src.ui.coord.skin_panel")
    local item_atlas = require("src.ui.coord.item_atlas")
    local state = { ui = {} }

    skin_panel.open(state, 1)
    skin_panel.handle_action(state, "buy", 1)
    skin_panel.handle_action(state, "equip", 1)
    item_atlas.open(state, 1)
    item_atlas.handle_action(state, { type = "select", slot_index = 2 }, 1)

    _assert_eq(state.ui.skin_panel.open, true, "skin panel should open independently")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], skin_panel.catalog[1].product_id,
      "skin panel should keep selected skin by role")
    _assert_eq(state.ui.item_atlas.open, true, "item atlas should open independently")
    _assert_eq(state.ui.item_atlas.selected_item_id, item_atlas.catalog[2].id,
      "item atlas should select catalog items by slot")
  end)

  it("view_command_dispatches_v102_extension_intents", function()
    local view_command = require("src.ui.ports.view_command").build()
    local state = { ui = {} }

    assert(view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 7 }) == true,
      "skin open intent should be handled")
    assert(view_command.dispatch(state, { type = "skin_panel_action", action = "buy", actor_role_id = 7 }) == true,
      "skin action intent should be handled")
    assert(view_command.dispatch(state, { type = "open_gallery_panel", actor_role_id = 7 }) == true,
      "gallery open intent should be handled")
    assert(view_command.dispatch(state, { type = "item_atlas_action", action = { type = "select", slot_index = 1 }, actor_role_id = 7 }) == true,
      "atlas action intent should be handled")

    _assert_eq(state.ui.skin_panel.owned_by_role["7"][require("src.ui.coord.skin_panel").catalog[1].product_id], true,
      "skin action should update skin panel")
    _assert_eq(state.ui.item_atlas.selected_item_id, require("src.ui.coord.item_atlas").catalog[1].id,
      "atlas action should update item atlas")
  end)

  it("host_integrations_are_explicit_noops", function()
    local integrations = require("src.app.host_integrations")
    local names = { "sign_in", "share_task", "fan_club", "gift", "achievement", "leaderboard" }

    for _, name in ipairs(names) do
      local module = integrations[name]
      assert(type(module) == "table", "missing integration module: " .. name)
      _assert_eq(module.host_pending, true, name .. " should be marked as host pending")
    end
    _assert_eq(integrations.fan_club.starting_cash_bonus(), 0, "fan club should not change cash before host integration")
  end)

  it("host_integration_stubs_keep_todo_markers", function()
    local paths = {
      "src/app/host_integrations/sign_in.lua",
      "src/app/host_integrations/share_task.lua",
      "src/app/host_integrations/fan_club.lua",
      "src/app/host_integrations/gift.lua",
      "src/app/host_integrations/achievement.lua",
      "src/app/host_integrations/leaderboard.lua",
    }

    for _, path in ipairs(paths) do
      local file = assert(io.open(path, "r"))
      local content = file:read("*a")
      file:close()
      assert(string.find(content, "TODO_HOST_INTEGRATION", 1, true) ~= nil,
        "missing TODO_HOST_INTEGRATION marker in " .. path)
    end
  end)

  it("skin_equip_contract_loads_without_ui_dependency", function()
    local skin_equip = require("src.rules.cosmetics.skin_equip")

    _assert_eq(type(skin_equip.equip), "function", "skin equip should expose equip")
    _assert_eq(type(skin_equip.unequip), "function", "skin equip should expose unequip")
  end)
end)
