local store_class = require("src.core.Store")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local choice_manager = require("src.game.choice.ChoiceManager")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _build_game()
  local store = store_class:new({ turn = {} })
  local game = {
    store = store,
  }
  function game:dispatch_action(action)
    local pending = self.store:get({ "turn", "pending_choice" })
    if pending then
      choice_manager.resolve(self, pending, action)
    end
  end
  return game
end

local game = _build_game()
local choice = {
  id = 1,
  kind = "contract_choice",
  options = { { id = "ok", label = "OK" } },
  allow_cancel = true,
}
game.store:set({ "turn", "pending_choice" }, choice)

local state = {
  pending_choice = choice,
  pending_choice_elapsed = 0,
  pending_choice_id = choice.id,
  ui_dirty = false,
}

local res = turn_dispatch.dispatch_action(game, state, {
  type = "choice_cancel",
  choice_id = 2,
})
_assert_eq(res.status, "rejected", "reject mismatched choice_id")
_assert_eq(state.pending_choice_id, choice.id, "pending_choice_id kept")
_assert_eq(game.store:get({ "turn", "pending_choice" }).id, choice.id, "pending choice kept")

res = turn_dispatch.dispatch_action(game, state, {
  type = "choice_select",
  choice_id = choice.id,
  option_id = "bad",
})
_assert_eq(res.status, "applied", "invalid option still dispatched")
_assert_eq(game.store:get({ "turn", "pending_choice" }).id, choice.id, "invalid option keeps pending")

res = turn_dispatch.dispatch_action(game, state, {
  type = "choice_cancel",
  choice_id = choice.id,
})
_assert_eq(res.status, "applied", "cancel applied")
_assert_eq(game.store:get({ "turn", "pending_choice" }), nil, "pending cleared after cancel")
_assert_eq(state.pending_choice, nil, "state cleared after cancel")

print("Contract turn_choice_protocol passed")
