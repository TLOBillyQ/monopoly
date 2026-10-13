require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- choice_contract.lua 直测:owner_role_id / meta player_id 解析路径与
-- copy_explicit_fields 守卫。owner 优先、meta 回落、非表输入的守卫是
-- 装配层契约,变异(守卫替换)只有逐臂断言能区分。

local choice_contract = require("src.config.choice.contract")

describe("TestChoiceContract", function()

  it("test_owner_role_id_wins_over_meta", function()
    local choice = { owner_role_id = 3, meta = { player_id = 9 } }
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id(choice) == 3, "owner_role_id must win over meta")
  end)

  it("test_meta_player_id_resolves_when_owner_is_absent", function()
    local choice = { meta = { player_id = 9 } }
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id(choice) == 9, "meta player_id must resolve when owner is absent")
  end)

  it("test_meta_player_id_survives_as_a_numeric_string", function()
    local choice = { meta = { player_id = "12" } }
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id(choice) == 12, "a numeric string player_id must be integer-normalized")
  end)

  it("test_non_table_meta_yields_nil", function()
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id({ owner_role_id = nil }) == nil, "no owner and no meta must yield nil")
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id({ meta = "junk" }) == nil, "a non-table meta must yield nil")
    luassert.truthy(choice_contract.resolve_owner_or_meta_role_id("not-a-choice") == nil, "a non-table choice must yield nil")
  end)

  it("test_copy_explicit_fields_returns_target_for_non_table_source", function()
    local target = { keep = 1 }
    local result = choice_contract.copy_explicit_fields("junk", target)
    luassert.truthy(result == target, "a non-table source must leave the target untouched")
    luassert.truthy(target.keep == 1, "target fields must survive")
  end)

  it("test_copy_explicit_fields_copies_only_explicit_fields", function()
    local target = {}
    local source = { owner_role_id = 2, route_key = "k", stray = "no" }
    choice_contract.copy_explicit_fields(source, target)
    luassert.truthy(target.owner_role_id == 2, "owner_role_id must copy")
    luassert.truthy(target.route_key == "k", "route_key must copy")
    luassert.truthy(target.stray == nil, "fields outside the explicit list must not copy")
  end)

end)
