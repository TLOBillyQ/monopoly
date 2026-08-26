local lu = require("luaunit")
local support = require("test.support.shared_support")
local card_reveal = require("src.rules.ports.card_reveal")
local land_presenter = require("src.rules.land.presenter")

local _assert_eq = support.assert_eq

-- card_reveal 是纯契约 port(ADR 0017,#165 / #329):实现由装配侧
-- configure 注入(host_install / 测试基线 / acceptance step 绑定),本文件
-- 不反向依赖 rules 内部实现。测试用假实现钉转发契约——每个动词参数/返回值
-- 原样穿透,不叠加规则结论;未注入实现时调用必须当场报错,装配遗漏即刻暴露。

local function _fake_impl(seen)
  return {
    push_land_popup = function(game, title, text, opts)
      seen.push = { game = game, title = title, text = text, opts = opts }
      return "popup_ret"
    end,
    queue_gain_reveal = function(game, player, item_id, opts)
      seen.queue = { game = game, player = player, item_id = item_id, opts = opts }
      return "queue_ret"
    end,
    bankruptcy_text = function(player, opts)
      seen.bankruptcy = { player = player, opts = opts }
      return "破产文案"
    end,
  }
end

TestCardRevealPort = {}

function TestCardRevealPort:setUp()
  card_reveal.reset_for_tests()
end

function TestCardRevealPort:test_push_land_popup_forwards_to_the_configured_impl()
  local seen = {}
  card_reveal.configure(_fake_impl(seen))
  local game, opts = { g = 1 }, { o = 1 }
  local ret = card_reveal.push_land_popup(game, "标题", "正文", opts)
  _assert_eq(ret, "popup_ret", "return value must pass through")
  _assert_eq(seen.push.game, game, "game must pass through")
  _assert_eq(seen.push.title, "标题", "title must pass through")
  _assert_eq(seen.push.text, "正文", "text must pass through")
  _assert_eq(seen.push.opts, opts, "opts must pass through")
end

function TestCardRevealPort:test_queue_gain_reveal_forwards_to_the_configured_impl()
  local seen = {}
  card_reveal.configure(_fake_impl(seen))
  local game, player, opts = { g = 2 }, { p = 1 }, { o = 2 }
  local ret = card_reveal.queue_gain_reveal(game, player, 2001, opts)
  _assert_eq(ret, "queue_ret", "return value must pass through")
  _assert_eq(seen.queue.game, game, "game must pass through")
  _assert_eq(seen.queue.player, player, "player must pass through")
  _assert_eq(seen.queue.item_id, 2001, "item_id must pass through")
  _assert_eq(seen.queue.opts, opts, "opts must pass through")
end

function TestCardRevealPort:test_bankruptcy_text_forwards_to_the_configured_impl()
  local seen = {}
  card_reveal.configure(_fake_impl(seen))
  local player, opts = { p = 2 }, { o = 3 }
  local ret = card_reveal.bankruptcy_text(player, opts)
  _assert_eq(ret, "破产文案", "text must pass through")
  _assert_eq(seen.bankruptcy.player, player, "player must pass through")
  _assert_eq(seen.bankruptcy.opts, opts, "opts must pass through")
end

local function _expect_error(fragment, fn)
  local ok, err = pcall(fn)
  lu.assertEvalToTrue(ok == false, "call should raise")
  lu.assertEvalToTrue(
    tostring(err):find(fragment, 1, true) ~= nil,
    "error should mention: " .. tostring(fragment) .. ", got: " .. tostring(err)
  )
end

function TestCardRevealPort:test_calls_without_a_configured_impl_error_loudly()
  _expect_error("missing card_reveal implementation", function()
    card_reveal.push_land_popup({}, "标题", "正文")
  end)
  _expect_error("missing card_reveal implementation", function()
    card_reveal.queue_gain_reveal({}, {}, 2001)
  end)
  _expect_error("missing card_reveal implementation", function()
    card_reveal.bankruptcy_text({})
  end)
end

function TestCardRevealPort:test_reset_for_tests_clears_the_configured_impl()
  card_reveal.configure(_fake_impl({}))
  card_reveal.reset_for_tests()
  _expect_error("missing card_reveal implementation", function()
    card_reveal.push_land_popup({}, "标题", "正文")
  end)
end

function TestCardRevealPort:test_configure_rejects_an_impl_missing_verbs()
  _expect_error("missing push_land_popup", function()
    card_reveal.configure({ queue_gain_reveal = function() end })
  end)
  _expect_error("missing queue_gain_reveal", function()
    card_reveal.configure({ push_land_popup = function() end })
  end)
  _expect_error("missing bankruptcy_text", function()
    card_reveal.configure({
      push_land_popup = function() end,
      queue_gain_reveal = function() end,
    })
  end)
end

function TestCardRevealPort:test_configure_rejects_a_non_table_impl()
  _expect_error("invalid card_reveal implementation", function()
    card_reveal.configure(nil)
  end)
end

function TestCardRevealPort:test_is_configured_reflects_the_configuration_state()
  lu.assertEvalToTrue(card_reveal.is_configured() == false, "a fresh port starts unconfigured")
  card_reveal.configure(_fake_impl({}))
  lu.assertEvalToTrue(card_reveal.is_configured() == true, "a configured port reports configured")
  card_reveal.reset_for_tests()
  lu.assertEvalToTrue(card_reveal.is_configured() == false, "reset returns to unconfigured")
end

function TestCardRevealPort:test_push_popup_returns_false_without_game()
  -- #293:presenter.push_popup 的 nil-game 守卫 false→true 变异未测。
  _assert_eq(land_presenter.push_popup(nil, "标题", "正文"), false,
    "push_popup without a game should return false")
end


return TestCardRevealPort
