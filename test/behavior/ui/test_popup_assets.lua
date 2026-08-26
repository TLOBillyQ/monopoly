-- #293 批3 pin:src/ui/coord/popup_assets.lua 的 14 个幸存者分四簇:
-- 卡片 image_key 直取链(L19/L30)、破产文案字段链(L67)、角色头像解析链
-- (L3/L98/L101/L105/L108/L119)、节点显隐链(L133/L138/L161)。
-- 策略:桩 runtime_ports / role_avatar / runtime 同表函数 + ui 双显存桩直测。

local lu = require("luaunit")
local popup_assets = require("src.ui.coord.popup_assets")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_avatar = require("src.ui.view.role_avatar")
local runtime = require("src.ui.render.support.runtime_ui")
local runtime_assets = require("src.config.runtime_assets")

local _saved_resolve_role = runtime_ports.resolve_role
local _saved_resolve_from_role = role_avatar.resolve_from_role
local _saved_sanitize = role_avatar.sanitize_image_key
local _saved_keep_size = runtime.set_node_texture_keep_size
local _saved_native_size = runtime.set_node_texture_native_size

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local _captured = nil

local function _ui_state()
  local ui = {
    popup_screen = { card = { name = "popup_card" } },
    bankruptcy_screen = { avatar = { name = "bankruptcy_avatar" } },
    query_node = function(_, name)
      return { name = name }
    end,
    set_visible = function(_, name, visible)
      _captured.visible[#_captured.visible + 1] = { name = name, visible = visible }
    end,
  }
  return { ui = ui }
end

TestPopupAssets = {}

function TestPopupAssets:setUp()
  _captured = { textures = {}, visible = {} }
  runtime_ports.resolve_role = function(player_id)
    return { id = player_id, name = "角色" }
  end
  role_avatar.resolve_from_role = function(role)
    return "avatar_role_key"
  end
  runtime.set_node_texture_keep_size = function(node, key)
    _captured.textures[#_captured.textures + 1] = key
  end
  runtime.set_node_texture_native_size = function(node, key)
    _captured.textures[#_captured.textures + 1] = key
  end
end

function TestPopupAssets:tearDown()
  runtime_ports.resolve_role = _saved_resolve_role
  role_avatar.resolve_from_role = _saved_resolve_from_role
  role_avatar.sanitize_image_key = _saved_sanitize
  runtime.set_node_texture_keep_size = _saved_keep_size
  runtime.set_node_texture_native_size = _saved_native_size
  runtime_assets.reset_for_tests()
end

function TestPopupAssets:test_set_popup_card_image_uses_payload_image_key()
  -- L19 `payload.image_key ~= nil` 的 ~= -> == 与 L30 `_payload_image_key(...)`
  -- 换 nil:payload 显式 image_key 必须直取。
  popup_assets.set_popup_card_image(_ui_state(), { image_key = "popup_key" })
  _assert_eq(_captured.textures[1], "popup_key", "payload image key must be applied")
end

function TestPopupAssets:test_resolve_bankruptcy_text_prefers_payload_text()
  -- L67 `payload and payload[key] or nil` 的 and->or(整表进 value)与
  -- payload[key] 换 nil:文案优先级 text > reason > player_name > 默认。
  _assert_eq(popup_assets.resolve_bankruptcy_text({ text = "破产啦" }), "破产啦",
    "payload text must win")
  _assert_eq(popup_assets.resolve_bankruptcy_text({ reason = "没地了" }), "没地了",
    "payload reason must back the text")
  _assert_eq(popup_assets.resolve_bankruptcy_text({ player_name = "甲" }), "甲 破产出局",
    "player name must back the reason")
  _assert_eq(popup_assets.resolve_bankruptcy_text({}), "破产出局",
    "empty payload must use the default label")
  -- L67 `value ~= nil and value ~= ""` 的 and->or 与 `~= ""` -> `~= nil`:
  -- 空串字段必须当缺失处理,不能原样透出。
  _assert_eq(popup_assets.resolve_bankruptcy_text({ text = "" }), "破产出局",
    "empty text must fall through to the default label")
end

function TestPopupAssets:test_set_bankruptcy_avatar_image_resolves_from_role()
  -- L3 require 换 nil(撞 nil 索引)、L98 `not player_id` 的 not 删除、
  -- L101 resolve_role 换 nil、L105 `role == nil` 的 == -> ~=、
  -- L108 resolve_from_role 换 nil、L119 双层调用换 nil:
  -- 有 player_id 无 avatar_key 时必须走角色头像链。
  local state = _ui_state()
  popup_assets.set_bankruptcy_avatar_image(state, { player_id = "p1" })
  _assert_eq(_captured.textures[1], "avatar_role_key", "role avatar key must be applied")
end

function TestPopupAssets:test_set_bankruptcy_avatar_image_prefers_payload_avatar_key()
  -- payload 显式 avatar_key 优先于角色链(sanitize 后仍须胜出)。
  role_avatar.sanitize_image_key = function(value)
    return "sanitized:" .. tostring(value)
  end
  local state = _ui_state()
  popup_assets.set_bankruptcy_avatar_image(state, { avatar_key = "avatar_payload_key", player_id = "p1" })
  _assert_eq(_captured.textures[1], "sanitized:avatar_payload_key", "payload avatar key must win")
end

function TestPopupAssets:test_set_bankruptcy_avatar_image_shows_empty_placeholder()
  -- L161 `show_when_empty` 实参 true -> false:无头像来源时必须显示空占位。
  runtime_assets.configure_for_tests({
    refs = { images = { Empty = "EMPTY_IMAGE" } },
  })
  local state = _ui_state()
  popup_assets.set_bankruptcy_avatar_image(state, {})
  _assert_eq(_captured.textures[1], "EMPTY_IMAGE", "empty placeholder must be applied")
  _assert_eq(_captured.visible[1].visible, true, "empty placeholder must be visible")
end

function TestPopupAssets:test_set_popup_card_image_hides_node_when_no_key_available()
  -- L133 `ui:set_visible(node_name, false)` 的 false -> true:无任何可用
  -- 图片键(含空占位键也缺失)时节点必须隐藏。清空 refs 让 empty_image
  -- 拿不到 Empty 键,把流程逼进 else 分支。
  runtime_assets.configure_for_tests({
    refs = { images = {} },
  })
  local state = _ui_state()
  popup_assets.set_popup_card_image(state, {})
  _assert_eq(_captured.visible[1].visible, false, "node without image must be hidden")
end

function TestPopupAssets:test_set_popup_card_image_tolerates_missing_card_node()
  -- L138 `not ui or not screen or not node_name` 的 or->and(后位):卡片节点
  -- 缺失时基线直接返回,变异体放行后仍会落纹理。
  local state = { ui = { popup_screen = {} } }
  popup_assets.set_popup_card_image(state, { image_key = "popup_key" })
  lu.assertEvalToTrue(#_captured.textures == 0, "missing card node must not apply a texture")
end

return TestPopupAssets
