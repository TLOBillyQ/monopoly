--- 文件级环境隔离原语(LuaUnit 迁移基础设施),#428 后收窄为 globals-only。
---
--- 历史:旧自研兼容层 core.lua 的 _snapshot/_restore 对齐 busted 默认 per-file
--- insulate,每 spec 文件前后浅快照/恢复 _G + package.loaded(缺失时
--- behavior-smoke 全量 3600 例中有 131 例假红——遗留 DSL 时代的裁定);本
--- runner 统一后置执行,另按类装回「加载完成后」的环境快照。
---
--- #428 定位结论:per-file 抹除 package.loaded 会让下一个文件的 require 把同
--- 一棵依赖树整树重新加载(实测单 worker 500 个唯一模块重复加载数万次,占车
--- 道 CPU 约 70%);而逐类装回的又是各文件加载时刻的错落快照,会把后加载文
--- 件的模块逐出缓存再重 require,造成跨类模块实例身份分叉(choice 屏注册表
--- 假红）。当前原生 LuaUnit 套件不依赖这套模块级隔离：
---   - 加载期无副作用跨文件泄漏,模块实例按标准 require 语义全进程共享;
---   - 测试期的模块态补丁走 with_patches / 显式 save-restore(如
---     test_screens_registry 的 tearDown),#217 基线守卫视补;
---   - behavior / guards / contract / tooling 四车道全部实测全绿。
--- 因此隔离面收窄为只快照/恢复 _G(spec 顶层引入的全局不跨文件、跨类泄漏),
--- package.loaded 快照/恢复整体退场。

local M = {}

--- 浅快照当前 _G。
function M.snapshot_globals()
  local globals = {}
  for k, v in pairs(_G) do
    globals[k] = v
  end
  return { globals = globals }
end

--- 让 _G 精确匹配快照:快照没有的键删除,快照有的键装回。
function M.apply_globals(snap)
  for k in pairs(_G) do
    if snap.globals[k] == nil then
      _G[k] = nil
    end
  end
  for k, v in pairs(snap.globals) do
    _G[k] = v
  end
end

return M
