local store_class = require("src.core.Store")
local intent_dispatcher = require("src.game.intent.IntentDispatcher")
local monopoly_event = require("src.game.game.MonopolyEvents")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

local function _build_game()
  local store = store_class:new({ turn = {} })
  local pushed = {}
  local ui_port = {
    push_popup = function(_, payload)
      table.insert(pushed, payload)
    end,
  }
  return {
    store = store,
    ui_port = ui_port,
    pushed = pushed,
  }
end

_with_patches({
  {
    key = "TriggerCustomEvent",
    value = function(name, payload)
      _G.__intent_events = _G.__intent_events or {}
      table.insert(_G.__intent_events, { name = name, payload = payload })
    end,
  },
}, function()
  _G.__intent_events = {}
  local game = _build_game()

  local entry = intent_dispatcher.open_choice(game, {
    kind = "contract_choice",
    options = { { id = "a", label = "A" } },
  })

  _assert_eq(entry.id, 1, "choice id")
  _assert_eq(entry.title, "请选择", "choice title default")
  _assert_eq(entry.allow_cancel, true, "choice allow_cancel default")
  _assert_eq(entry.cancel_label, "取消", "choice cancel_label default")

  local stored = game.store:get({ "turn", "pending_choice" })
  _assert_eq(stored.id, entry.id, "pending choice stored")

  local event = _G.__intent_events[1]
  _assert_eq(event.name, monopoly_event.resolve_intent("need_choice"), "need_choice event")

  intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = { title = "T", body = "B" },
  })

  _assert_eq(#game.pushed, 1, "popup pushed")
  local popup_event = _G.__intent_events[2]
  _assert_eq(popup_event.name, monopoly_event.resolve_intent("push_popup"), "push_popup event")
end)

print("Contract intent_dispatcher passed")
