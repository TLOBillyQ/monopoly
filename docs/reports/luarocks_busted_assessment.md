# 损益评估：引入 LuaRocks + Busted BDD 工作流

> 日期：2026-03-09

## Context

三周架构收口完成后，代码库具备 385 项回归检查、68 个测试模块、~16,847 行测试代码。本报告评估是否值得引入 LuaRocks（包管理）和 Busted（BDD 测试框架）来改造开发工作流。

## 现状快照

### 运行时约束（不可协商）

项目运行在 **Eggy（蛋仔派对）游戏引擎沙箱** 内：
- Lua 5.4，非 LuaJIT
- 沙箱移除 `io`、`os`、大部分 `package`、`debug` 模块
- `require` 仅允许从 `script` 目录加载，无 `package.cpath`（不能加载 C 模块）
- 宿主注入全局 API：`GameAPI`、`LuaAPI`、`UIManager`、`math.Vector3` 等
- 生产环境 **永远不会有 LuaRocks**

### 现有测试基础设施

| 组件 | 文件 | 行数 | 职责 |
| --- | --- | --- | --- |
| TestHarness | `tests/TestHarness.lua` | 97 | 执行引擎：xpcall + 日志捕获 + 报告 |
| TestSupport | `tests/TestSupport.lua` | 376 | 游戏专属 helper：new_game、with_patches、choice 解析 |
| catalog | `tests/catalog.lua` | 175 | 51 behavior + 12 contract + 5 guard 模块注册 |
| suite_builder | `tests/suites/gameplay/suite_builder.lua` | — | gameplay 用例工厂 |
| test_env | `tests/support/test_env.lua` | 152 | Eggy 全局 mock：Vector3、GameAPI、UIManager |
| log_capture | `tests/support/log_capture.lua` | 73 | print 拦截与聚合 |
| guard 脚本 | `tests/guards/*.lua` | ~300+ | 静态分析：dep_rules、legacy_path、forbidden_globals |

特点：确定性执行（`randomseed(1)`）、per-test 全局补丁与清理、三层运行器（behavior / contract / guard）、模式条件过滤（dev / release_trimmed）。

## 成本

### 1. 迁移量巨大且收益为零的部分

guard 脚本（5 个）和架构契约（12 个）**不是单元测试**——它们扫描文件系统、分析 require 依赖图、检查命名规则。Busted 对此没有任何对应概念。这 17 个模块必须保留原有机制，形成**双测试引擎并存**。

### 2. 68 个模块 / 16,847 行需要重写语法

从 `{name, run=function() ... end}` 改成 `describe/it` 是纯语法变换。实际测试逻辑（`new_game()` → 操作 → 断言）完全不变。这是高投入、零功能收益的搬运工作。

### 3. Busted 依赖链

busted → penlight → lua-term → mediator_lua → luassert → say → luasystem。每个都是潜在版本冲突点。CI 需要额外安装 LuaRocks + busted（当前 CI 仅 `apt-get install lua5.4`，一步到位）。

### 4. TestSupport 无法替代

`with_patches()`、`new_game(opts)`、`open_choice()`、`resolve_landing_with_choices()` 是 376 行游戏领域专用的 helper。无论用 busted 还是 TestHarness，这些代码一行不少。Busted 的 spy/stub/mock 不能替代 `with_patches()`——后者做的是 Eggy 全局 API 的临时替换与恢复，不是普通函数 stub。

### 5. 环境割裂

LuaRocks 只能在开发机和 CI 上运行。生产 Eggy 沙箱永远没有它。这意味着新增一个"仅存在于测试侧"的包管理工具链；当前仓库已经不再保留 npm 依赖。

## 收益

| 收益 | 真实价值 |
| --- | --- |
| `describe/it` 语法更易读 | 轻微。当前 `{name, run}` 模式已足够清晰 |
| Busted 内置 mock/spy | 不替代 `with_patches()`；对 Eggy 全局 mock 无帮助 |
| 更好的断言消息 | 可以在现有 `assert_eq` 上加格式化，10 行改动 |
| tag 过滤 | catalog.lua 已有 `disabled_in` 和 mode 过滤 |
| 社区标准 | 团队稳定，无外部 Lua 开发者入职需求 |
| 异步测试支持 | 当前用协程调度器，busted 的 async 模型不兼容 |

## 替代方案：低成本演进

如果想获得 BDD 语法的可读性，**不需要引入 busted**。在 TestHarness 上加一层薄封装即可：

```lua
-- tests/support/bdd.lua (~30 行)
local function describe(name, fn)
  local cases = {}
  local before_each_fn
  function it(case_name, case_fn)
    cases[#cases + 1] = { name = name .. " " .. case_name, run = function()
      if before_each_fn then before_each_fn() end
      case_fn()
    end}
  end
  function before_each(fn) before_each_fn = fn end
  fn()
  return cases
end
```

这样新测试可以用 `describe/it` 写，旧测试不动，catalog 照常注册，guard 不受影响，CI 零变化，依赖为零。

## 结论

**不建议引入 LuaRocks + Busted。** 损益比约为 **3:1 负面**。

| 维度 | 判定 |
| --- | --- |
| 迁移成本 | 极高（16,847 行 + CI + 双引擎） |
| 运行时兼容性 | 不兼容生产环境 |
| 实际功能提升 | 接近零（核心 helper 不可替代） |
| 风险 | 依赖链、版本冲突、环境割裂 |
| 替代路径 | 30 行 BDD 封装即可获得语法收益 |

如果确实想改善测试体验，推荐方向是：

1. 加 `describe/it` 薄封装（~30 行，零依赖）
2. 增强 `assert_eq` 的失败消息格式化（~10 行）
3. 这两项改动不破坏现有 385 项回归
