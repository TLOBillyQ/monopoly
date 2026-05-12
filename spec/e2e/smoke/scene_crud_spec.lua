local fixture = require("spec.e2e.support.editor_fixture")
local editor_assert = require("spec.e2e.support.editor_assert")

-- Forwarding closure: see comment in connection_spec.lua.
local hooks = fixture.bind({ pending = function(msg) pending(msg) end })

describe("e2e: scene CRUD smoke", function()
  before_each(hooks.clean_logs)

  -- Use a fixed, project-unique id so a leaked unit from a prior run is
  -- still cleaned up by the teardown branch below.
  local TEST_UNIT_ID = "__e2e_smoke_unit__"

  local function _delete_if_present(client)
    client.exec(string.format(
      "local u = EditorAPI.scene.get_unit_by_id(%q); if u then EditorAPI.scene.delete_unit(u) end",
      TEST_UNIT_ID
    ))
  end

  it("creates a unit, finds it, then deletes it", hooks.with_edit_mode(function(client)
    _delete_if_present(client)

    client.exec(string.format(
      "EditorAPI.scene.create_unit({id=%q, x=0, y=0, z=0})",
      TEST_UNIT_ID
    ))

    local unit = editor_assert.unit_exists(TEST_UNIT_ID)
    assert.is_not_nil(unit)

    _delete_if_present(client)
    editor_assert.unit_absent(TEST_UNIT_ID)
  end))
end)
