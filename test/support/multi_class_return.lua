-- test/support/multi_class_return.lua
--
-- 多类 spec 文件的 mutate 车道统一返回（#283 多类文件 return 首类假幸存方向）。
-- 正常车道扫 _G 收全部 Test* 类；mutate 内建 runner 只跑 spec return 的表且把它
-- 当单类展开，因此多类文件只 return 首类时其余类用例在变异车道完全不执行。
-- 此处把多个类表合并成一张扁平返回表，每个 test* 方法跑所属类 setUp/tearDown，
-- 每类共享一个以原类为 __index 的实例（与正常车道跨用例共享语义一致）。

local M = {}

--- @param ... table 测试类表
--- @return table 合并后的返回表
function M.merge(...)
  local classes = { ... }
  local merged = {}
  for _, cls in ipairs(classes) do
    if type(cls) ~= "table" then
      error("multi_class_return.merge: class must be table, got " .. type(cls), 2)
    end
    local setUp = cls.setUp
    local tearDown = cls.tearDown
    local inst = setmetatable({}, { __index = cls })
    for k, v in pairs(cls) do
      if type(v) == "function" and k:match("^test") then
        if merged[k] ~= nil then
          error("multi_class_return.merge: duplicate test name across classes: " .. k, 2)
        end
        local own_fn = v
        merged[k] = function(self, ...)
          if setUp then setUp(inst) end
          local results = { pcall(own_fn, inst, ...) }
          if tearDown then tearDown(inst) end
          if not results[1] then error(results[2], 0) end
          local count = 0
          for _ in pairs(results) do count = count + 1 end
          return table.unpack(results, 2, count)
        end
      end
    end
  end
  return merged
end

return M
