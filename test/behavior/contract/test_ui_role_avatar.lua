-- Behavior-lane coverage for src.ui.view.role_avatar image-key sanitation and
-- role-getter resolution. The convention contract (0 sentinel vs negative) also
-- lives in test/contract/test_ui_role_avatar.lua; these cases pin the full guard
-- surface (nil / non-integer / non-positive / valid, plus resolve_from_role).
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local role_avatar = require("src.ui.view.role_avatar")
local logger = require("src.foundation.log")

TestUiRoleAvatar = {}

function TestUiRoleAvatar:test_sanitize_image_key_covers_nil_non_integer_non_positive_and_valid_keys()
  local warns = 0
  _with_patches({
    { target = logger, key = "warn", value = function() warns = warns + 1 end },
  }, function()
    _assert_eq(role_avatar.sanitize_image_key(nil), nil, "nil key resolves to nil without warning")
    _assert_eq(role_avatar.sanitize_image_key({}), nil, "non-integer key resolves to nil")
    _assert_eq(role_avatar.sanitize_image_key(-3), nil, "negative key resolves to nil")
    _assert_eq(role_avatar.sanitize_image_key(0), nil, "zero key resolves to nil without warning")
    _assert_eq(role_avatar.sanitize_image_key(5), 5, "positive integer key passes through")
  end)
  lu.assertEvalToTrue(warns >= 2, "non-integer and negative keys should each warn (got " .. warns .. ")")
end

function TestUiRoleAvatar:test_resolve_from_role_guards_missing_role_missing_getter_and_getter_errors()
  _assert_eq(role_avatar.resolve_from_role(nil), nil, "nil role resolves to nil")
  _assert_eq(role_avatar.resolve_from_role({}), nil, "role without get_head_icon resolves to nil")
  _assert_eq(role_avatar.resolve_from_role({ get_head_icon = function() error("boom") end }), nil,
    "a throwing getter is swallowed to nil")
  _assert_eq(role_avatar.resolve_from_role({ get_head_icon = function() return 9 end }), 9,
    "a valid getter resolves the sanitized key")
end

function TestUiRoleAvatar:test_sanitize_one_key_is_still_valid()
  -- 杀 L35 `as_int <= 0` 的 0->1:key=1 是合法正整数,不得被误判进非正分支。
  _assert_eq(role_avatar.sanitize_image_key(1), 1, "key 1 should pass through")
end

function TestUiRoleAvatar:test_sanitize_zero_never_warns()
  -- 杀 L36 内层 `as_int < 0` 的 <-><= 与 0->1:key=0 必须静默返回 nil,
  -- 不能触发 warn。用字符串 "0" 输入——其去重槽 "string:0" 与 covers 测试
  -- 的数字 0 槽("number:0")不同,变异触发 warn 后可观测(顺序耦合隔离)。
  local warns = 0
  _with_patches({
    { target = logger, key = "warn", value = function() warns = warns + 1 end },
  }, function()
    _assert_eq(role_avatar.sanitize_image_key("0"), nil, "zero key resolves to nil")
  end)
  _assert_eq(warns, 0, "zero key must not warn")
end

function TestUiRoleAvatar:test_invalid_key_warn_deduplicates_and_pins_payload()
  -- 杀 L22 warned_values[key]=true 的 true->false(去重失效)与 L23 消息->nil:
  -- 同值重复必须只 warn 一次,且载荷首参钉死。
  local warns = {}
  _with_patches({
    { target = logger, key = "warn", value = function(...)
      warns[#warns + 1] = { ... }
    end },
  }, function()
    -- 用独特无效值 -99,避免消耗 -1 的 warn 去重槽(与 negative 测试顺序耦合)。
    role_avatar.sanitize_image_key(-99)
    role_avatar.sanitize_image_key(-99)
  end)
  _assert_eq(#warns, 1, "repeated invalid key should warn only once")
  _assert_eq(warns[1][1], "头像ImageKey解析失败:", "warn payload label should be pinned")
end

function TestUiRoleAvatar:test_tostring_failure_falls_back_safely()
  -- 杀 L12 "<tostring failed>"->nil:__tostring 抛错的值必须走兜底串,
  -- 不能让 `type:..text` 拼接撞 nil。
  local bad_value = setmetatable({}, {
    __tostring = function()
      error("boom")
    end,
  })
  local ok = false
  _with_patches({
    { target = logger, key = "warn", value = function() end },
  }, function()
    ok = pcall(role_avatar.sanitize_image_key, bad_value)
  end)
  _assert_eq(ok, true, "a tostring-throwing value must not crash the sanitizer")
end


return TestUiRoleAvatar
