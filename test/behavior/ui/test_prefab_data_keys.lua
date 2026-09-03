local lu = require("luaunit")

TestPrefabDataKeys = {}

-- Data/Prefab.lua 是编辑器导出件,sync-data 字节原样回同步。地雷 prefab id 曾三次
-- 随导出漂移(1266f212 / fbd6fbf6 / 本次),真机表现是静默不生成。这里把 src 实际
-- 读取的 unit 键钉在仓内数据上:导出器再变脸时 verify 直接红,而不是真机才发现。
local UNIT_KEYS_READ_BY_SRC = { "地雷A", "路障", "导弹", "清障机器人" }

function TestPrefabDataKeys:test_unit_keys_read_by_src_exist_in_exported_prefab()
  local prefab = require("Data.Prefab")
  lu.assertEvalToTrue(type(prefab.unit) == "table", "Data/Prefab.lua must export a unit table")
  for _, key in ipairs(UNIT_KEYS_READ_BY_SRC) do
    lu.assertEvalToTrue(prefab.unit[key] ~= nil,
      "Data/Prefab.lua unit table lost key " .. key .. " (editor export drift?)")
  end
end

return TestPrefabDataKeys
