local fixture = require("spec.e2e.support.editor_fixture")
local editor_assert = require("spec.e2e.support.editor_assert")

-- Forwarding closure so `pending` resolves at call-time. Busted's
-- file-load `pending` is a different function than the one injected inside
-- `it()`, and only the latter actually pends the test.
local hooks = fixture.bind({ pending = function(msg) pending(msg) end })

describe("e2e: editor-cli connection", function()
  before_each(hooks.clean_logs)

  it("editor reports a status payload", function()
    hooks.skip_if_unavailable()
    local status = editor_assert.editor_online()
    assert.is_table(status)
  end)

  it("exec runs a no-op lua snippet without erroring", hooks.with_edit_mode(function(client)
    client.exec("local _ = 1 + 1")
  end))

  it("marker round-trip returns the value we emitted", hooks.with_edit_mode(function()
    local value = editor_assert.marker_roundtrip(42)
    assert.equals(42, value)
  end))

  it("marker round-trip survives string payloads with quotes", hooks.with_edit_mode(function()
    local value = editor_assert.marker_roundtrip([[has "quotes" and 'apostrophes']])
    assert.equals([[has "quotes" and 'apostrophes']], value)
  end))
end)
