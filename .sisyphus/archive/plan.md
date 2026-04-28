# 可行性研究：Eggy 项目用 busted 作为 BDD 测试 runner

## Context

**目标**：用户为后续 Eggy 项目开发确立最佳测试工作流，硬需求是 **BDD 风格**（describe/it/spy/stub/mock）。本研究判断能否用 busted 替代 monopoly 当前的自写 harness，并给出落地方案。

**结论**：**可以上 busted。** 主要阻塞已逐一排除：
- ✅ **Lua 版本**：busted master CI 显式覆盖 5.1/5.2/5.3/5.4/5.5/LuaJIT。Eggy 官方版本 **Lua 5.4** 是 busted 一等基线。
- ✅ **Eggy 宿主伪造**：busted 的 `--helper=PATH` 机制就是为这个设计的，monopoly `tests/support/test_env.lua` 的 700 行可直接搬到 `spec/helper.lua`。
- ✅ **runtime ports 自动重装**：用 busted 的 `before_each` 全局 hook 实现，比 `with_patches` 更显式。
- ✅ **warn 体检**：busted 自定义 output handler 订阅 `testStart/testEnd` 事件，可移植 `log_capture` 的聚合逻辑。
- ⚠ **mutate4lua / crap4lua 适配**：现有 vendor 适配器假设 `require("TestHarness") + require("tests.catalog")`，要重写成从 busted 拿 suite 树。**这是工作量集中点。**
- ✅ **TAP/JUnit/JSON 输出**：busted 内置，无需自写。

**附带发现（独立于 harness 选型）**：monopoly `.luarc.json` 与本地 `lua -v` 都是 **Lua 5.5**，但 Eggy 生产环境是 **Lua 5.4**——存在版本不一致。建议在引入 busted 时顺手把项目对齐到 Lua 5.4，让测试与生产同版本。

### 用户决策（2026-04-28）

- **Lua 版本**：对齐到 **Lua 5.4**（与 Eggy 生产一致）。
- **迁移范围**：monopoly 从 **contract lane 试点**（13 suite / 68 case），**不**全面迁移 137 suite。
- **本计划当前范围**：阶段 0（5.4 对齐）+ 阶段 1（contract lane 试点）+ 阶段 2（mutate/crap 适配器）。阶段 3-5 暂列为"后续评估"，等阶段 1+2 验证经验后再决定。

---

## 1. 关键事实核查

### 1.1 busted 能力清单（核查后修正）

| 维度 | 实际能力 | 来源 |
|---|---|---|
| Lua 版本 | CI matrix `["5.5", "5.4", "5.3", "5.2", "5.1", "luajit"]` | `.github/workflows/busted.yml` master 分支 |
| 最新版 | 2.3.0（2026-01-07） | luarocks |
| rockspec 依赖 | `lua >= 5.1`、`luassert >= 1.9.0-1`、`say >= 1.4-1`、`penlight >= 1.15.0` 等 | `busted-scm-1.rockspec` |
| 内置 output handler | utfTerminal / plainTerminal / **TAP** / json / **junit** / gtest / sound | rockspec `build.modules` |
| Helper 机制 | `--helper=PATH` 在所有测试前加载，可注入全局 stub / mock | busted 文档 |
| 自定义 output handler | `-o thing.lua`，订阅 `testStart/testEnd/suiteStart/suiteEnd/error/...` | busted 文档 |
| 生命周期 | `setup/teardown/before_each/after_each`（含 lazy 变体） | busted 文档 |
| 测试发现 | 默认 glob `*_spec.lua`，可 `-p PATTERN` 改 | busted 文档 |
| Mock | `luassert.spy/stub/mock`（busted 自动注入 `assert.spy` 等） | luassert |

### 1.2 Eggy / 项目 Lua 版本现状

| 位置 | 值 | 备注 |
|---|---|---|
| Eggy 官方文档 | **Lua 5.4** | https://u5-creator.s3.game.163.com/manual/pc_md/lua/lua_eggy.html "蛋仔支持的 Lua 版本为 5.4" |
| monopoly `.luarc.json` | `runtime.version: "Lua 5.5"` | LuaLS 提示版本，**与生产不一致** |
| monopoly `.luacheckrc` | `std = "lua54"` | luacheck 只支持到 lua54，本身没问题 |
| monopoly 本地解释器 | `lua -v` → Lua 5.5.0 | 本地跑测试用，**与生产不一致** |

→ **建议**：未来 Eggy 项目（含 monopoly 自身）应统一用 Lua 5.4，与 Eggy 生产对齐。

---

## 2. monopoly 自写 harness 的资产分布

抽离哪些可重用、哪些要重写：

| 模块 | LOC | 性质 | 在 busted 方案里 |
|---|---|---|---|
| `tests/TestHarness.lua` | 212 | 通用 runner | **删除**，busted 替代 |
| `tests/catalog.lua` | 239 | 显式 require 列表 | **重写为 spec 文件 glob** 或保留作为 mutate/crap 适配桥 |
| `tests/bootstrap.lua` | ~100 | path 装配 | 搬到 `spec/helper.lua` |
| `tests/support/test_env.lua` | 177 | **Eggy 宿主伪造** | 搬到 `spec/helper.lua` 不变 |
| `tests/support/shared_support.lua` | 536 | runtime ctx 装配 + `with_patches` + `assert_eq` | runtime ctx 装配搬 helper；`with_patches` 改 `before_each`；删 `assert_eq`（用 luassert） |
| `tests/support/log_capture.lua` | ~200 | warn 体检机制 | 搬成自定义 output handler |
| `tests/support/tooling_parallel.lua` | 422 | 子进程并行 | **保留独立**，包成 busted CLI plugin 或继续走自写入口 |
| `tests/support/wall_clock.lua` 等 | ~200 | 计时 | 搬到 helper |
| 137 个 suite 文件 | ~2000+ | `tests = {{name, run}}` 形态 | **形态改写为 `describe/it`**（最大工作量） |
| fixtures / DSL builder | ~1500 | 项目数据特定 | 不动，被 spec 引用 |
| `tools/quality/mutate/driver.lua` | — | 收覆盖喂 mutate4lua | **重写适配** busted suite 树 |
| `tools/quality/crap/adapter.lua` | — | 收覆盖喂 crap4lua | **重写适配** |

---

## 3. 推荐方案：busted 全栈 + 模板化

### 3.1 工作流图（未来 Eggy 项目）

```
新 Eggy 项目 → 复制 eggy-busted-template/
  ├─ spec/
  │   ├─ helper.lua              （Eggy 宿主伪造 + path 装配，busted --helper 加载）
  │   ├─ env_runtime.lua         （runtime ports 装配函数，被 helper 的 before_each 调用）
  │   └─ log_warns_handler.lua   （自定义 output handler，warn 白名单体检）
  ├─ spec/behavior/*_spec.lua    （describe/it 行为用例）
  ├─ spec/contract/*_spec.lua    （describe/it 契约用例）
  ├─ src/                        （项目代码）
  ├─ .busted                     （配置：lanes、helper 路径、output handler）
  ├─ rockspec / .luarocks        （声明 lua = 5.4，依赖 busted/luassert）
  ├─ docs/architecture/quality_map.md
  └─ docs/architecture/behavior_warns.md
```

### 3.2 `.busted` 配置（核心）

```lua
return {
  default = {
    helper = "spec/helper.lua",
    output = "spec/log_warns_handler.lua",
    pattern = "_spec",
  },
  behavior = {
    helper = "spec/helper.lua",
    output = "spec/log_warns_handler.lua",
    ROOT = { "spec/behavior" },
  },
  contract = {
    helper = "spec/helper.lua",
    output = "TAP",        -- contract lane 走 TAP，方便 CI
    ROOT = { "spec/contract" },
  },
  ci = {
    helper = "spec/helper.lua",
    output = "junit",      -- 写 JUnit XML 给 IDE / CI
    Xoutput = "junit-output.xml",
  },
}
```

调用：`busted --run=behavior` / `busted --run=contract` / `busted --run=ci`。

### 3.3 `spec/helper.lua`（Eggy 宿主伪造 + 全局 hook）

骨架：

```lua
-- 1. path 装配（搬自 tests/bootstrap.lua）
local function install_paths() ... end
install_paths()

-- 2. Eggy 宿主伪造（搬自 tests/support/test_env.lua install_defaults，原样）
GameAPI = GameAPI or {}
UIManager = UIManager or {}
LuaAPI = LuaAPI or {}
LuaAPI.rand = LuaAPI.rand or function() return math.random() end
Enums = Enums or {}; Enums.BuffState = Enums.BuffState or {}
math.tofixed = math.tofixed or function(v) return v end
math.Vector3 = math.Vector3 or { New = function(x,y,z) return {x=x,y=y,z=z} end }
math.Quaternion = math.Quaternion or {...}
SetTimeOut = SetTimeOut or function() end
-- 等等

-- 3. runtime ports 装配函数
local env_runtime = require("spec.env_runtime")

-- 4. busted 全局 hook：每个 case 前重置 runtime context + 随机种子
local busted = require("busted")
busted.subscribe({"file", "start"}, function() env_runtime.refresh() end)
busted.subscribe({"test", "start"}, function()
  math.randomseed(1)
  env_runtime.refresh()  -- 替代 with_patches 的自动重装
end)
```

### 3.4 `spec/log_warns_handler.lua`（warn 体检 output handler）

骨架（订阅 busted 事件 + 复用 `log_capture` 聚合逻辑）：

```lua
return function(options)
  local handler = require("busted.outputHandlers.base")(options)
  local log_capture = require("tests.support.log_capture")  -- 复用现有模块
  local warn_whitelist = require("docs.architecture.behavior_warns_data")
  local case_buffer

  handler.testStart = function(element, parent)
    case_buffer = log_capture.capture()
  end

  handler.testEnd = function(element, parent, status, trace)
    local summary = log_capture.collect_summary(case_buffer)
    -- 按 behavior_warns.md 白名单过滤
    -- 非白名单 warn → 加入 errors / pendings
  end

  handler.suiteEnd = function()
    -- 打印 [warn] suppressed xN <line> 等聚合行
  end

  busted.subscribe({"test", "start"}, handler.testStart)
  busted.subscribe({"test", "end"}, handler.testEnd)
  busted.subscribe({"suite", "end"}, handler.suiteEnd)
  return handler
end
```

### 3.5 spec 文件形态示例

```lua
-- spec/behavior/chance_card_spec.lua
describe("chance card", function()
  local game

  before_each(function()
    game = require("tests.support.shared_support").new_game()
  end)

  it("is mandatory effect entrypoint", function()
    -- ...
    assert.are.same(expected_state, game.state)
    assert.has_no.errors(function() game:apply_chance() end)
  end)

  it("rejects invalid card id", function()
    assert.has_error(function() game:apply_chance("bogus") end, "invalid card")
  end)
end)
```

### 3.6 mutate4lua / crap4lua 适配（核心难点）

现有 driver 直接 `require("TestHarness") + require("tests.catalog")` 拿 suite 列表 + run_all 函数，挂 `debug.sethook("l")` 收行覆盖。busted 没有"列出所有 suite + 程序化跑"的等价 API，需要写适配层：

```lua
-- tools/quality/mutate/busted_adapter.lua（新写）
local function discover_specs(lane)
  -- glob spec/<lane>/**/*_spec.lua
end

local function run_with_coverage(spec_files, on_test)
  -- 用 busted 的 standalone_loader 加载 spec
  -- subscribe testStart 启动 debug.sethook
  -- subscribe testEnd 关闭 hook 并 emit 覆盖
  -- 调 busted runner with output=null
end

return { discover_specs = discover_specs, run_with_coverage = run_with_coverage }
```

实际可行性：busted 的 `busted.runner` 可被程序化调用，`standalone_loader` 模块导出能加载 spec 文件并构建 suite tree。`mediator_lua` 事件总线允许外部订阅。**工作量约 200-400 行，是迁移的最大单点风险。**

---

## 4. 阶段化落地（针对 monopoly 现有项目）

### 阶段 0：版本对齐（1 天，独立任务）

把 monopoly 从 Lua 5.5 切到 Lua 5.4，与 Eggy 生产对齐。

| 步骤 | 命令 / 文件 |
|---|---|
| 装 Lua 5.4 | `brew install lua@5.4`（macOS）/ winget（Windows） |
| 改 `.luarc.json` | `runtime.version: "Lua 5.4"` |
| 跑现有测试套件验证无回归 | `lua5.4 tests/behavior.lua` 等四条 lane |

### 阶段 1：busted 引入与单 lane 试点（1-2 周）

**只在 contract lane 试点**（68 case，最小集，且 lane 入口本来就用 `quiet_reporter` + `capture_logs`，最容易迁移）：

| 步骤 | 文件 |
|---|---|
| 装 busted + luassert | `luarocks install busted luassert` |
| 写 `spec/helper.lua` | 搬 `tests/support/test_env.lua` + `bootstrap.lua` 内容 |
| 写 `spec/env_runtime.lua` | 抽 `_refresh_runtime_context_for_tests` |
| 写 `.busted` | 配置 contract lane |
| 把 13 个 contract suite 改写为 `*_spec.lua` 形态 | `spec/contract/*_spec.lua`（68 case） |
| 验证 | `busted --run=contract` 全绿，`busted --run=contract -o junit` 写出 XML |

**保持现状**：behavior / guard / tooling 仍走 `tests/TestHarness.lua`。

### 阶段 2：mutate / crap 适配器（1 周，关键路径）

写 `tools/quality/mutate/busted_adapter.lua` 和 `tools/quality/crap/busted_adapter.lua`，让两个 vendor 工具也能从 busted 拿覆盖率。验证：

```bash
lua tools/quality/mutate.lua --lane contract --runner busted --dry-run
```

如阶段 2 受阻，**不要进阶段 3**，把 contract lane 留在 busted 但 mutate/crap 暂回退到 lane=behavior（仍走旧 harness）。

### 阶段 3-5：后续评估（不在本计划范围）

阶段 1+2 完成并稳定运行 2-4 周后，再根据实际经验评估以下后续步骤是否启动。**当前不做**：

- **阶段 3：behavior lane 迁移**（120 个 suite / ~900 case，预计 2-4 周）。机械化改写可行性、回归风险都待阶段 1 实测后再判断。
- **阶段 4：guard / tooling lane**。guard 的 `M.run() -> {ok, message}` 协议与 BDD 不匹配；tooling 的子进程并行 422 行是项目特定。**倾向于保留独立入口长期共存**，不强迁。
- **阶段 5：抽离 `eggy-busted-template` 模板仓库**。等阶段 1+2 在 monopoly 验证完，把 `spec/helper.lua` + `log_warns_handler.lua` + `.busted` + 文档模板抽出，给后续新 Eggy 项目复制即用。

---

## 5. 风险与回退点

| 风险 | 触发条件 | 回退策略 |
|---|---|---|
| Lua 5.4 与 5.5 行为差异 | 阶段 0 跑测试出现 5.5 特有 API 调用失败 | 找出违例点改写；无法改写则项目继续用 5.5（接受测试 vs 生产不同步） |
| busted 与 Eggy 宿主伪造冲突 | 阶段 1 helper 加载后某些 case 行为异常 | 用 `with_patches` 风格的 setup/teardown 显式注入；不要依赖 helper 的隐式全局 |
| mutate/crap 适配器写不出来 | 阶段 2 卡壳超 1 周 | 保留 `tests/TestHarness.lua` 作为 mutate/crap 的兼容入口（只 require 行为/契约 spec，不实际跑），让 driver 仍能走旧路径 |
| 137 suite 机械迁移失真 | 阶段 3 出现大量回归 | 暂停迁移，把已迁文件留在 busted、未迁文件留在旧 harness，长期共存 |
| warn output handler 输出不及旧 `log_capture` 清晰 | 阶段 1 末验收时发现 warn 体检漏报/误报 | 输出 handler 加 `--verbose` 模式打印原始 capture buffer 供调试 |

---

## 6. 验证

### 阶段 1 验收

| 命令 | 期望 |
|---|---|
| `busted --run=contract` | 68 case 全绿，stdout 显示 BDD 风格输出 |
| `busted --run=contract -o TAP` | 输出符合 TAP 13 spec |
| `busted --run=contract -o junit -Xoutput=junit.xml` | 写出 JUnit XML，IDE Test Explorer 可加载 |
| `busted --run=contract --filter="rejects"` | 只跑 name 含 "rejects" 的 case |
| `lua tests/behavior.lua` | 行为 lane 仍全绿（旧 harness 不动） |
| `lua tools/quality/arch.lua check` | 无新边界违例 |

### 阶段 2 验收

| 命令 | 期望 |
|---|---|
| `lua tools/quality/mutate.lua --lane contract --runner busted --dry-run` | 列出 spec/contract/ 下的 spec 文件，无报错 |
| `lua tools/quality/mutate.lua --lane contract --runner busted` | 完整变异跑通，覆盖率喂给 vendor/mutate4lua 无错 |
| `lua tools/quality/crap.lua --lane contract --runner busted` | crap4lua 收到合法覆盖输入 |

### 阶段 0 验收

| 命令 | 期望 |
|---|---|
| `lua -v` | `Lua 5.4.x` |
| `lua tests/behavior.lua` | 全绿（5.4 下与 5.5 同等通过率） |
| `lua tests/contract.lua` | 全绿 |
| `lua tests/guard.lua` | 全绿 |
| `lua tests/tooling.lua` | 全绿 |
| `lua tools/quality/lint.lua` | 无新违例 |

---

## 7. 不做（明确边界）

- **本计划只覆盖 contract lane**：behavior / guard / tooling 在阶段 1+2 期间继续走 `tests/TestHarness.lua` 旧路径，不动。
- **不引入 BDD 之外的 spec 风格**（如 xUnit）：风格统一比"用啥都行"重要。
- **不混跑两套 runner 在同一 lane**：contract lane 完全切到 busted；其他 lane 完全留在旧 harness。lane 级隔离，不允许 lane 内并存。
- **阶段 3-5 当前不启动**：见 §4 末尾，待阶段 1+2 经验后再评估。

Sources:
- [busted - Elegant Lua unit testing](https://lunarmodules.github.io/busted/)
- [busted CI workflow (master)](https://raw.githubusercontent.com/lunarmodules/busted/master/.github/workflows/busted.yml)
- [busted rockspec](https://raw.githubusercontent.com/lunarmodules/busted/master/busted-scm-1.rockspec)
- [蛋仔工坊 Lua 简介](https://u5-creator.s3.game.163.com/manual/pc_md/lua/lua_eggy.html)
- [LuaUnit GitHub](https://github.com/bluebird75/luaunit)
