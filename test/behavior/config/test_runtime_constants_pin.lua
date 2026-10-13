require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- runtime_constants 完整性 pin:#293 复核——6 个 vec3/quat 常量被 nil 替换或
-- 负号被移除存活,根因是测试从不读这些常量。结构性断言(非 nil + 关键分量)
-- 一次性击杀全部位点。

local runtime_constants = require("src.config.gameplay.runtime_constants")

describe("TestRuntimeConstantsPin", function()

  it("test_every_constant_is_present", function()
    for name, value in pairs(runtime_constants) do
      luassert.truthy(value ~= nil, name .. " should be present")
    end
  end)

  it("test_vec_and_quat_constants_carry_their_components", function()
    luassert.truthy(runtime_constants.q_left.y == -180, "q_left should face -180 degrees; got " .. tostring(runtime_constants.q_left.y))
    luassert.truthy(runtime_constants.entity_pool_park_pos.y == -9999, "park position should sit at -9999; got " .. tostring(runtime_constants.entity_pool_park_pos.y))
    luassert.truthy(runtime_constants.v3_zero.x == 0 and runtime_constants.v3_zero.y == 0
      and runtime_constants.v3_zero.z == 0, "v3_zero should be the origin")
    luassert.truthy(runtime_constants.v3_one.x == 1 and runtime_constants.v3_one.y == 1
      and runtime_constants.v3_one.z == 1, "v3_one should be unit")
  end)

end)
