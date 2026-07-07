local intent_dispatcher = require("src.turn.output.intent_dispatcher")

-- Minimal game that satisfies open_choice: a turn table for the choice sequence,
-- a plain dirty table for dirty_tracker.mark, and an event_feed_port that records
-- published events so the choice-log text can be asserted directly.
local function _choice_game(choice_seq)
  local events = {}
  local game = {
    turn = { choice_seq = choice_seq, pending_choice = nil },
    dirty = {},
    event_feed_port = {
      publish = function(_, _, event)
        events[#events + 1] = event
        return true
      end,
    },
  }
  return game, events
end

local function _recording_port()
  local port = { calls = {} }
  port.push_popup = function(_, payload, opts)
    port.calls[#port.calls + 1] = { payload = payload, opts = opts }
  end
  return port
end

describe("intent_dispatcher.open_choice survivors", function()
  it("omits the body separator when the first body line is empty", function()
    local game, events = _choice_game()
    intent_dispatcher.open_choice(game, {
      kind = "probe",
      title = "标题",
      body_lines = { "" },
      options = {},
      meta = {},
    }, {})
    assert.equals(1, #events)
    assert.equals("等待选择：标题", events[1].text)
  end)

  it("defaults the choice title to 请选择 when none is provided", function()
    local game = _choice_game()
    local entry = intent_dispatcher.open_choice(game, {
      kind = "probe",
      options = {},
      meta = {},
    }, {})
    assert.equals("请选择", entry.title)
  end)

  it("keeps a caller-provided cancel label", function()
    local game = _choice_game()
    local entry = intent_dispatcher.open_choice(game, {
      kind = "probe",
      options = {},
      cancel_label = "退出",
      meta = {},
    }, {})
    assert.equals("退出", entry.cancel_label)
  end)

  it("defaults the cancel label to 取消 when none is provided", function()
    local game = _choice_game()
    local entry = intent_dispatcher.open_choice(game, {
      kind = "probe",
      options = {},
      meta = {},
    }, {})
    assert.equals("取消", entry.cancel_label)
  end)

  it("increments the existing choice sequence by one", function()
    local game = _choice_game(5)
    local entry = intent_dispatcher.open_choice(game, {
      kind = "probe",
      options = {},
      meta = {},
    }, {})
    assert.equals(6, entry.id)
    assert.equals(6, game.turn.choice_seq)
  end)

  it("starts the choice sequence at one when unset", function()
    local game = _choice_game()
    local entry = intent_dispatcher.open_choice(game, {
      kind = "probe",
      options = {},
      meta = {},
    }, {})
    assert.equals(1, entry.id)
  end)
end)

describe("intent_dispatcher.push_popup survivors", function()
  it("uses game.popup_port directly and never resolves via ensure_popup_port", function()
    local port_a = _recording_port()
    local port_b = _recording_port()
    local ensure_called = false
    local game = {
      popup_port = port_a,
      ensure_popup_port = function()
        ensure_called = true
        return port_b
      end,
    }

    local ok = intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "x" })

    assert.is_true(ok)
    assert.is_false(ensure_called)
    assert.equals(1, #port_a.calls)
    assert.equals(0, #port_b.calls)
  end)

  it("resolves the popup port via ensure_popup_port when none is installed", function()
    local port_b = _recording_port()
    local ensure_called = false
    local game = {
      popup_port = nil,
      ensure_popup_port = function()
        ensure_called = true
        return port_b
      end,
    }

    local ok = intent_dispatcher.push_popup(game, { message = "hi" }, {})

    assert.is_true(ok)
    assert.is_true(ensure_called)
    assert.equals(1, #port_b.calls)
  end)

  it("forwards the opts table through to the popup port", function()
    local port_a = _recording_port()
    local game = { popup_port = port_a }

    intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "replace" })

    assert.equals("replace", port_a.calls[1].opts.policy)
  end)
end)

describe("intent_dispatcher.dispatch survivors", function()
  it("treats a bare intent table without a wrapper as the intent", function()
    local game = _choice_game()
    local entry = intent_dispatcher.dispatch(game, {
      kind = "need_choice",
      choice_spec = { kind = "probe", options = {}, meta = {} },
    })
    assert.is_not_nil(entry)
    assert.equals("probe", entry.kind)
  end)

  it("routes a need_choice intent to open_choice", function()
    local game = _choice_game()
    local entry = intent_dispatcher.dispatch(game, {
      intent = { kind = "need_choice", choice_spec = { kind = "probe", options = {}, meta = {} } },
    })
    assert.is_not_nil(entry)
    assert.equals("probe", entry.kind)
    assert.is_not_nil(game.turn.pending_choice)
  end)

  it("requires both need_choice kind and a choice_spec to open a choice", function()
    local game = _choice_game()
    local result = intent_dispatcher.dispatch(game, {
      intent = { kind = "unknown_kind", choice_spec = { kind = "probe", options = {}, meta = {} } },
    })
    assert.is_nil(result)
    assert.is_nil(game.turn.pending_choice)
  end)

  it("requires a payload before routing a push_popup intent", function()
    local game = { popup_port = _recording_port() }
    local result = intent_dispatcher.dispatch(game, { intent = { kind = "push_popup" } })
    assert.is_nil(result)
  end)

  it("prefers popup_opts over opts when forwarding popup opts", function()
    local port_a = _recording_port()
    local game = { popup_port = port_a }
    intent_dispatcher.dispatch(game, {
      intent = {
        kind = "push_popup",
        payload = { message = "hi" },
        popup_opts = { tag = "primary" },
        opts = { tag = "secondary" },
      },
    })
    assert.equals("primary", port_a.calls[1].opts.tag)
  end)

  it("falls back to opts when popup_opts is absent", function()
    local port_a = _recording_port()
    local game = { popup_port = port_a }
    intent_dispatcher.dispatch(game, {
      intent = {
        kind = "push_popup",
        payload = { message = "hi" },
        opts = { tag = "secondary" },
      },
    })
    assert.equals("secondary", port_a.calls[1].opts.tag)
  end)
end)
