local property = require("spec.support.property")
local shared_support = require("spec.support.shared_support")
local market_view = require("src.ui.render.market")
local market_layout = require("src.ui.schema.market_layout")
local runtime_state = require("src.state.runtime")

local function _new_state(balance)
  local labels = {}
  local visible = {}
  local state = {
    ui = {
      set_label = function(_, name, text) labels[name] = text end,
      set_visible = function(_, name, flag) visible[name] = flag == true end,
      set_touch_enabled = function() end,
      query_node = function() return {} end,
    },
  }
  shared_support.bind_ui_runtime(state)
  runtime_state.set_ui_model(state, { current_player_cash = balance })
  return state, labels, visible
end

local function _gen_balance(rng)
  return rng:int(-1000000, 1000000)
end

local function _assert_cash_display(balance)
  local state, labels, visible = _new_state(balance)

  market_view.refresh_cash_display(state)

  assert(labels[market_layout.cash_text_label] == "现金",
    "cash caption must stay static")
  assert(labels[market_layout.cash_amount_label] == tostring(balance),
    "cash amount label must render the current-player balance")
  assert(visible[market_layout.cash_text_label] == true,
    "cash caption must be visible")
  assert(visible[market_layout.cash_amount_label] == true,
    "cash amount must be visible")
end

describe("market cash display properties", function()
  it("renders any current-player balance into the amount label while keeping the caption static", function()
    property.for_all(_gen_balance, _assert_cash_display)
  end)
end)
