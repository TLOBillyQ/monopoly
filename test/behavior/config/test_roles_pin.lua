-- roles 配置完整性 pin:#293 复核——9 个 name/prototype/description 字符串
-- 被 nil 替换存活,根因是测试从不读这些字段。结构断言(全部非空字符串)
-- 一次击杀全部位点。
local lu = require("luaunit")

local roles = require("src.config.content.roles")

TestRolesPin = {}

function TestRolesPin:test_every_role_carries_complete_fields()
  lu.assertEvalToTrue(#roles == 3, "role catalog should hold three roles")
  for _, role in ipairs(roles) do
    lu.assertEvalToTrue(type(role.id) == "number", "role id should be numeric")
    lu.assertEvalToTrue(type(role.name) == "string" and role.name ~= "",
      "role name should be a non-empty string")
    lu.assertEvalToTrue(type(role.prototype) == "string" and role.prototype ~= "",
      "role prototype should be a non-empty string")
    lu.assertEvalToTrue(type(role.description) == "string" and role.description ~= "",
      "role description should be a non-empty string")
  end
end

function TestRolesPin:test_known_role_names_are_pinned()
  lu.assertEvalToTrue(roles[1].name == "丁垒" and roles[1].prototype == "丁磊",
    "role 1 name/prototype are pinned")
  lu.assertEvalToTrue(roles[2].name == "麻花藤" and roles[2].prototype == "马化腾",
    "role 2 name/prototype are pinned")
  lu.assertEvalToTrue(roles[3].name == "菜好鱼" and roles[3].prototype == "蔡浩宇",
    "role 3 name/prototype are pinned")
end

return TestRolesPin
