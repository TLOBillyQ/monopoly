local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local gameplay_read_port = require("src.ui.pres.gameplay_read_port")
local land_pricing = require("src.rules.land.pricing")
local choice_builder = require("src.ui.pres.choice_builder")

local function _test_total_land_invested_matches_domain_pricing()
  local tile = {
    price = 300,
    upgrade_costs = { 100, 150, 220 },
    rents = { 30, 80, 160, 300 },
  }
  local levels = { -1, 0, 1, 2, 3, 4, 7 }
  for _, level in ipairs(levels) do
    local expected = land_pricing.total_invested(tile, level)
    local actual = gameplay_read_port.total_land_invested(tile, level)
    _assert_eq(actual, expected, "read model total_invested must match domain pricing at level " .. tostring(level))
  end
end

local function _test_total_land_invested_handles_missing_costs_like_domain()
  local tile = { price = 500 }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 3), land_pricing.total_invested(tile, 3),
    "read model should match domain when upgrade_costs missing")
end

local function _test_total_land_invested_caps_by_upgrade_cost_length()
  local tile = {
    price = 100,
    upgrade_costs = { 10, 20 },
  }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 8), 130,
    "read model should cap invested total by available upgrade_costs")
  _assert_eq(land_pricing.total_invested(tile, 8), 130,
    "domain pricing should keep the same cap behavior")
end

local function _test_total_land_invested_handles_sparse_upgrade_cost_entries()
  local tile = {
    price = 200,
    upgrade_costs = { 10, nil, 40 },
  }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 3), land_pricing.total_invested(tile, 3),
    "read model should match domain for sparse upgrade costs")
end

local function _test_choice_view_builds_phase_title_and_option_fields()
  local view = choice_builder.build_choice_view({
    id = 7,
    kind = "item_phase_choice",
    title = "请选择",
    body_lines = { "第一行", "第二行" },
    options = {
      {
        id = 2001,
        label = "路障卡",
        can_buy = true,
        requires_pre_confirm = true,
        pre_confirm_kind = "secondary_confirm",
        confirm_title = "确认使用",
        confirm_body = "确认文案",
      },
    },
    allow_cancel = false,
    cancel_label = "返回",
    route_key = "base_inline",
  }, {
    game = {
      turn = {
        item_phase_active = "pre_action",
      },
    },
  })

  _assert_eq(view.title, "[行动前] 请选择", "choice view should prefix item phase label")
  _assert_eq(view.body, "第一行\n第二行", "choice view should join body_lines")
  _assert_eq(view.allow_cancel, false, "choice view should preserve explicit allow_cancel")
  _assert_eq(view.cancel_label, "返回", "choice view should preserve cancel label")
  _assert_eq(view.route_key, "base_inline", "choice view should copy explicit fields")
  _assert_eq(view.options[1].requires_pre_confirm, true, "choice view should copy pre-confirm marker")
  _assert_eq(view.options[1].confirm_title, "确认使用", "choice view should copy confirm title")
end

local function _test_choice_view_defaults_body_and_option_labels()
  local view = choice_builder.build_choice_view({
    id = 8,
    kind = "remote",
    body = "正文",
    options = {
      { id = 3 },
    },
  }, {
    game = {
      turn = {},
    },
    body_lines_only = true,
  })

  _assert_eq(view.title, "请选择", "choice view should default missing title")
  _assert_eq(view.body, "", "body_lines_only should ignore pending.body")
  _assert_eq(view.cancel_label, "取消", "choice view should default cancel label")
  _assert_eq(view.allow_cancel, true, "choice view should allow cancel by default")
  _assert_eq(view.options[1].label, "3", "choice view should default option label from raw option")
  _assert_eq(view.options[1].id, 3, "choice view should preserve option id")
end

return {
  name = "read_model_contract",
  tests = {
    { name = "total_land_invested_matches_domain_pricing", run = _test_total_land_invested_matches_domain_pricing },
    { name = "total_land_invested_handles_missing_costs_like_domain", run = _test_total_land_invested_handles_missing_costs_like_domain },
    { name = "total_land_invested_caps_by_upgrade_cost_length", run = _test_total_land_invested_caps_by_upgrade_cost_length },
    { name = "total_land_invested_handles_sparse_upgrade_cost_entries", run = _test_total_land_invested_handles_sparse_upgrade_cost_entries },
    { name = "choice_view_builds_phase_title_and_option_fields", run = _test_choice_view_builds_phase_title_and_option_fields },
    { name = "choice_view_defaults_body_and_option_labels", run = _test_choice_view_defaults_body_and_option_labels },
  },
}
