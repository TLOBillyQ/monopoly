-- runtime_constants 完整性 pin:#293 复核——6 个 vec3/quat 常量被 nil 替换或
-- 负号被移除存活,根因是测试从不读这些常量。结构性断言(非 nil + 关键分量)
-- 一次性击杀全部位点。
local lu = require("luaunit")

local runtime_constants = require("src.config.gameplay.runtime_constants")

TestRuntimeConstantsPin = {}

function TestRuntimeConstantsPin:test_every_constant_is_present()
  for name, value in pairs(runtime_constants) do
    lu.assertEvalToTrue(value ~= nil, name .. " should be present")
  end
end

function TestRuntimeConstantsPin:test_vec_and_quat_constants_carry_their_components()
  lu.assertEvalToTrue(runtime_constants.q_left.y == -180,
    "q_left should face -180 degrees; got " .. tostring(runtime_constants.q_left.y))
  lu.assertEvalToTrue(runtime_constants.entity_pool_park_pos.y == -9999,
    "park position should sit at -9999; got " .. tostring(runtime_constants.entity_pool_park_pos.y))
  lu.assertEvalToTrue(runtime_constants.v3_zero.x == 0 and runtime_constants.v3_zero.y == 0
    and runtime_constants.v3_zero.z == 0, "v3_zero should be the origin")
  lu.assertEvalToTrue(runtime_constants.v3_one.x == 1 and runtime_constants.v3_one.y == 1
    and runtime_constants.v3_one.z == 1, "v3_one should be unit")
end

return TestRuntimeConstantsPin
