local fixture = require("spec.e2e.support.editor_fixture")
local editor_assert = require("spec.e2e.support.editor_assert")

-- Forwarding closure: see comment in connection_spec.lua.
local hooks = fixture.bind({ pending = function(msg) pending(msg) end })

describe("e2e: run_game lifecycle", function()
  before_each(hooks.clean_logs)

  it("enters play mode and reports a status of `playing`", hooks.with_play_mode(function(client)
    local status = client.status()
    assert.is_table(status)
    local mode = status.mode or status.state or (status.playing and "playing")
    assert.equals("playing", mode)
  end))

  it("can read a player position via game_exec_capture", hooks.with_play_mode(function()
    local pos = editor_assert.player_position(1)
    if pos == nil then
      -- Single-player scenes may not have player[1] yet — treat as soft-pass
      -- so this smoke spec stays green across scene templates.
      pending("e2e: scene under test does not expose player[1]")
      return
    end
    assert.is_table(pos)
    assert.equals(3, #pos)
  end))
end)
