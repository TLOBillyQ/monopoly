-- eimage.lua branch-dense coverage: 颜色/贴图更新的 client_role 定向分支、全角色广播分支与 reset_size 开关。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local EImage = require("src.ui.manager.eimage")
local support = require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown,共享 local role_a/role_b 收成 self 字段,用例数与改写前一致(9 例)。

TestEImage = {}

function TestEImage:setUp()
  support.clear_context()
  support.install_host_math()
  self.role_a = support.make_role(1)
  self.role_b = support.make_role(2)
end

function TestEImage:tearDown()
  support.clear_context()
  support.restore_host_math()
end

function TestEImage:test_init_defaults_color_texture_and_transition_time()
  local image = EImage:new(501, "img")

  lu.assertEvalToTrue(image.image_color == 0xffffff, "new image color should default to white")
  lu.assertEvalToTrue(image.image_texture == -1, "new image texture should default to -1")
  lu.assertEvalToTrue(image.transition_time == 0.0, "new image transition_time should default to 0.0")
end

function TestEImage:test_image_color_targets_only_the_client_role_and_carries_transition_time()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(502, "img")
  image.transition_time = 0.25

  image.image_color = 0x123456

  local calls = support.calls_of(self.role_a, "set_image_color")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_image_color once")
  lu.assertEvalToTrue(calls[1].args[1] == 502, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == 0x123456, "host call should carry the new color")
  lu.assertEvalToTrue(calls[1].args[3] == 0.25, "host call should carry the transition time")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the color update")
  lu.assertEvalToTrue(image.image_color == 0x123456, "image_color getter should report the stored value")
end

function TestEImage:test_image_color_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(503, "img")

  image.image_color = 0x00ff00

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_image_color")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 0x00ff00, "every role should receive the color update")
    lu.assertEvalToTrue(calls[1].args[3] == 0.0, "every role should receive the default transition time")
  end
end

function TestEImage:test_image_texture_keeps_size_for_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(504, "img")

  image.image_texture = 88

  local calls = support.calls_of(self.role_a, "set_image_texture_by_key_with_auto_resize")
  lu.assertEvalToTrue(#calls == 1, "client role should receive the texture call once")
  lu.assertEvalToTrue(calls[1].args[1] == 504, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == 88, "host call should carry the texture key")
  lu.assertEvalToTrue(calls[1].args[3] == false, "setting image_texture should not reset size")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the texture update")
  lu.assertEvalToTrue(image.image_texture == 88, "image_texture getter should report the stored value")
end

function TestEImage:test_image_texture_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(505, "img")

  image.image_texture = 9

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_image_texture_by_key_with_auto_resize")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 9, "every role should receive the texture update")
    lu.assertEvalToTrue(calls[1].args[3] == false, "broadcast texture update should not reset size")
  end
end

function TestEImage:test_set_texture_keep_size_stores_the_key_without_resetting_size()
  support.install_roles({ self.role_a })
  local image = EImage:new(506, "img")

  image:set_texture_keep_size(11)

  local calls = support.calls_of(self.role_a, "set_image_texture_by_key_with_auto_resize")
  lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 11, "texture key should be pushed to the host")
  lu.assertEvalToTrue(calls[1].args[3] == false, "keep-size should pass reset_size=false")
  lu.assertEvalToTrue(image.image_texture == 11, "texture key should be stored on the node")
end

function TestEImage:test_set_texture_native_size_resets_size()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(507, "img")

  image:set_texture_native_size(12)

  local calls = support.calls_of(self.role_a, "set_image_texture_by_key_with_auto_resize")
  lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 12, "texture key should be pushed to the client role")
  lu.assertEvalToTrue(calls[1].args[3] == true, "native-size should pass reset_size=true")
  lu.assertEvalToTrue(image.image_texture == 12, "texture key should be stored on the node")
end

function TestEImage:test_reset_size_replays_the_current_texture_with_reset_flag_for_all_roles()
  support.install_roles({ self.role_a, self.role_b })
  local image = EImage:new(508, "img")
  image:set_texture_keep_size(13)

  image:reset_size()

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_image_texture_by_key_with_auto_resize")
    lu.assertEvalToTrue(#calls == 2, "reset_size should issue a second texture call per role")
    lu.assertEvalToTrue(calls[2].args[2] == 13, "reset_size should replay the stored texture key")
    lu.assertEvalToTrue(calls[2].args[3] == true, "reset_size should pass reset_size=true")
  end
end

function TestEImage:test_transition_time_setter_stores_the_fixed_value_without_host_calls()
  support.install_roles({ self.role_a })
  local image = EImage:new(509, "img")

  image.transition_time = 1.5

  lu.assertEvalToTrue(image.transition_time == 1.5, "transition_time getter should report the stored value")
  lu.assertEvalToTrue(#self.role_a.calls == 0, "setting transition_time alone should not touch the host")
end


return TestEImage
