local gameplay_read_port = require("src.ui.pres.gameplay_read_port")
local land_pricing = require("src.rules.land.pricing")
local choice_builder = require("src.ui.pres.choice_builder")

describe("read_model_contract", function()
  it("total_land_invested_matches_domain_pricing", function()
    local tile = {
      price = 300,
      upgrade_costs = { 100, 150, 220 },
      rents = { 30, 80, 160, 300 },
    }
    local levels = { -1, 0, 1, 2, 3, 4, 7 }
    for _, level in ipairs(levels) do
      local expected = land_pricing.total_invested(tile, level)
      local actual = gameplay_read_port.total_land_invested(tile, level)
      assert.equals(expected, actual, "read model total_invested must match domain pricing at level " .. tostring(level))
    end
  end)

  it("total_land_invested_handles_missing_costs_like_domain", function()
    local tile = { price = 500 }
    assert.equals(
      land_pricing.total_invested(tile, 3),
      gameplay_read_port.total_land_invested(tile, 3),
      "read model should match domain when upgrade_costs missing"
    )
  end)

  it("total_land_invested_caps_by_upgrade_cost_length", function()
    local tile = {
      price = 100,
      upgrade_costs = { 10, 20 },
    }
    assert.equals(130, gameplay_read_port.total_land_invested(tile, 8),
      "read model should cap invested total by available upgrade_costs")
    assert.equals(130, land_pricing.total_invested(tile, 8),
      "domain pricing should keep the same cap behavior")
  end)

  it("total_land_invested_handles_sparse_upgrade_cost_entries", function()
    local tile = {
      price = 200,
      upgrade_costs = { 10, nil, 40 },
    }
    assert.equals(
      land_pricing.total_invested(tile, 3),
      gameplay_read_port.total_land_invested(tile, 3),
      "read model should match domain for sparse upgrade costs"
    )
  end)

  it("choice_view_builds_phase_title_and_option_fields", function()
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

    assert.equals("[行动前] 请选择", view.title, "choice view should prefix item phase label")
    assert.equals("第一行\n第二行", view.body, "choice view should join body_lines")
    assert.equals(false, view.allow_cancel, "choice view should preserve explicit allow_cancel")
    assert.equals("返回", view.cancel_label, "choice view should preserve cancel label")
    assert.equals("base_inline", view.route_key, "choice view should copy explicit fields")
    assert.equals(true, view.options[1].requires_pre_confirm, "choice view should copy pre-confirm marker")
    assert.equals("确认使用", view.options[1].confirm_title, "choice view should copy confirm title")
  end)

  it("choice_view_defaults_body_and_option_labels", function()
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

    assert.equals("请选择", view.title, "choice view should default missing title")
    assert.equals("", view.body, "body_lines_only should ignore pending.body")
    assert.equals("取消", view.cancel_label, "choice view should default cancel label")
    assert.equals(true, view.allow_cancel, "choice view should allow cancel by default")
    assert.equals("3", view.options[1].label, "choice view should default option label from raw option")
    assert.equals(3, view.options[1].id, "choice view should preserve option id")
  end)
end)
