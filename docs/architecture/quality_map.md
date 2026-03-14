# 测试与静态分析地图

这份文档回答三个问题：

1. 现在仓库有哪些质量入口。
2. 每条入口在守什么，不守什么。
3. 本地该先跑哪条，通常要等多久。

> 基线日期：2026-03-14（Asia/Shanghai，本机实测）。耗时会随 case 数、日志量、冷启动状态变化。

## 六块质量面

| 入口 | 类型 | 主要回答的问题 | 当前本地耗时参考 |
|------|------|----------------|------------------|
| `lua tests/behavior.lua` | 行为回归 | 改动后真实玩法 / UI 行为有没有坏 | 约 `0.4s` |
| `lua tests/contract.lua` | 契约回归 | 端口、边界、读模型、架构契约有没有漂移 | 热启动常见 `14s-20s`，冷启动可到 `~29s` |
| `lua tests/guard.lua` | 文本护栏 | 有没有出现明确禁用写法、旧路径、越界依赖文本痕迹 | 约 `1.3s` |
| `lua scripts/arch.lua check` | 静态架构扫描 | `src/**/*.lua` 的模块依赖图是否违反边界、产生循环 | 约 `0.2s` |
| `lua scripts/crap.lua report --lane behavior --out tmp/crap_report.json` | 风险热点分析 | 哪些函数复杂且覆盖不足，应该先补测或重构 | 约 `9s-10s` |
| `lua scripts/mutate.lua src/foo.lua --scan` | 单文件变异测试 | 这个文件现有测试是否真能杀掉简单错误 | 目标文件和 lane 差异很大；默认先按 `behavior` 估算 |

建议把它们分成两层理解：

- `tests/*` 负责确认“功能/契约还是不是对的”。
- `guard + arch_view + crap` 负责确认“结构/风险有没有继续变坏”。

## 当前规模

| 入口 | 当前规模 | 备注 |
|------|----------|------|
| `behavior` | `49` 个 suite，`992` 个 case | 其中 `8` 个 case 在特定 mode 下禁用 |
| `contract` | `13` 个 suite，`103` 个 case | 当前最明显的耗时大头 |
| `guard` | `4` 个 script | `dep_rules`、`gameplay_loop_no_ui`、`forbidden_globals`、`arch_view_guard` |
| `arch_view` | 扫描 `src/**/*.lua` | 不扫 `tests/`、`scripts/`、`vendor/` |
| `crap` | 当前 behavior lane 分析 `2588` 个函数 | 只给 `src/**/*.lua` 打分 |
| `mutate4lua` | 每次只盯 `1` 个 `src/**/*.lua` 文件 | 诊断工具，不进默认回归 |

## 每条入口具体看什么

### `behavior`

- 入口：`tests/behavior.lua`
- 来源：`tests/catalog.lua` 中的 `behavior_suites`
- 覆盖面：`domain / runtime / gameplay / presentation`
- 适用时机：改了玩法规则、UI 行为、回合推进、运行时胶水，先跑它
- 不适合：证明架构边界没漂移；那是 `contract / guard / arch_view` 的工作

### `contract`

- 入口：`tests/contract.lua`
- 来源：`tests/catalog.lua` 中的 `contract_suites`
- 关注点：读模型、架构护栏、窄 Port、UI gate、runtime ports、脚本工具契约
- 适用时机：改了跨层接口、装配、端口、架构脚本、展示契约，先跑它
- 特点：不是业务玩法回归，而是“接口和边界别偷偷变形”

### `guard`

- 入口：`tests/guard.lua`
- 当前子项：
  - `dep_rules`：文本级硬边界、禁用旧路径、禁用少量跨子系统依赖
  - `gameplay_loop_no_ui`：`gameplay loop` 在最小 runtime 下不直接依赖 UI 对象
  - `forbidden_globals`：禁用 `tonumber`、`type(...) == "number"`、`rawget` 等仓库级禁令
  - `arch_view_guard`：把 `arch_view` 的检查结果接入 guard lane
- 适用时机：想快速知道有没有出现“明确不允许的写法”

### `arch_view`

- 入口：`lua scripts/arch.lua check`
- 文档：`docs/architecture/arch_view.md`
- 工具代码：`vendor/arch_view/`
- Monopoly 规则真源：`scripts/arch/config.lua`
- Monopoly 提交态快照：`scripts/arch/viewer/*`
- 检查内容：
  - 模块级 `require` 依赖边界
  - 未分类模块
  - 模块级循环依赖
  - projection/view 级反馈环
- 与 `guard` 的分工：
  - `arch_view` 看结构化依赖图
  - `guard` 看文本级禁令和个别仓库硬规则

### `crap`

- 入口：`lua scripts/crap.lua report ...` / `lua scripts/crap.lua viewer ...`
- 文档：`docs/architecture/crap_report.md`
- 性质：不是纯静态分析，而是“静态复杂度 + 动态覆盖率”混合
- 数据来源：
  - 复杂度：`luac -p -l`
  - 覆盖率：测试 lane 运行时 `debug.sethook(..., "l")`
- 适用时机：需要给“先补测还是先重构”排序
- 不适合：单独做合并 gate；它依赖测试 lane 质量

现在的 CLI 入口由 `scripts/crap.lua` 负责兼容，核心实现来自子模块 `vendor/crap4lua/`，默认项目配置在 `scripts/quality/crap_monopoly.config.lua`，Monopoly lane 适配在 `scripts/quality/crap_monopoly_adapter.lua`：

- `report`：生成 JSON 报告
- `viewer`：导出静态页面
- 无参数：默认等价于 `viewer --out-dir tmp/crap_view --open`

### `mutate4lua`

- 入口：`lua scripts/mutate.lua <file.lua> ...`
- 文档：`docs/architecture/mutate4lua.md`
- 性质：单文件变异测试；看“测试有没有真正卡住错误”，不是看“代码有没有被执行到”
- 数据来源：
  - 变异点：`vendor/mutate4lua/` 的 Lua lexer / scanner
  - 覆盖率：`scripts/quality/mutate_monopoly_driver.lua` 运行 lane 时的 `debug.sethook(..., "l")`
- 适用时机：怀疑某个文件 assertion 太松、准备做高风险重构、想验证 characterization tests 是否够硬
- 不适合：日常全量 gate；它本来就是按文件诊断

现在的 CLI 入口由 `scripts/mutate.lua` 负责兼容，核心实现来自子模块 `vendor/mutate4lua/`，Monopoly 的默认 lane 适配在 `scripts/quality/mutate_monopoly_driver.lua`：

- 默认 lane：`behavior`
- 显式可选：`--lane contract`
- 上游原生参数继续透传，例如 `--scan`、`--since-last-run`、`--mutate-all`

## 按问题选命令

| 你现在想回答的问题 | 先跑什么 |
|--------------------|----------|
| 功能有没有坏 | `lua tests/behavior.lua` |
| 跨层接口或读模型有没有漂移 | `lua tests/contract.lua` |
| 有没有出现明确禁用写法 | `lua tests/guard.lua` |
| 依赖图有没有越界或成环 | `lua scripts/arch.lua check` |
| 哪些函数最值得先补测/重构 | `lua scripts/crap.lua report --lane behavior --out tmp/crap_report.json` |
| 某个文件的测试是不是只是“跑到了”而不是“断严了” | `lua scripts/mutate.lua src/foo.lua --scan` 然后再决定是否真正跑 mutation |

## 常用命令套餐

### 快速本地冒烟

```sh
lua scripts/arch.lua check
lua tests/guard.lua
lua tests/behavior.lua
```

适合高频本地回归，通常约 `2s`。

### 架构/契约检查

```sh
lua tests/contract.lua
lua scripts/arch.lua check
```

适合改 Port、边界、装配、读模型之后跑。通常约 `15s-21s`，冷启动更慢。

### 热点分析

```sh
lua scripts/crap.lua report --lane behavior --out tmp/crap_report.json
lua scripts/crap.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view
```

适合重构前排优先级。通常约 `10s`。

### 单文件变异诊断

```sh
lua scripts/mutate.lua src/core/utils/role_id.lua --scan
lua scripts/mutate.lua src/core/utils/role_id.lua --since-last-run
```

适合先看一个文件值不值得做 mutation，再决定是否跑完整变异回合。耗时主要取决于目标文件的变异点数量和所选 lane。

### 完整质量回归

```sh
lua tests/behavior.lua
lua tests/contract.lua
lua tests/guard.lua
lua scripts/arch.lua check
lua scripts/crap.lua report --lane behavior --out tmp/crap_report.json
```

当前机器按经验可按 `30s-35s` 预估；若 `contract` 冷启动或日志量上升，会更慢。

## 使用上的默认建议

- 改业务逻辑或 UI，默认先跑 `behavior`。
- 改端口、契约、装配、边界，默认先跑 `contract + arch_view`。
- 改目录结构或依赖方向，默认先跑 `guard + arch_view`。
- 做 CRAP 清理时，默认先看 behavior lane；只有明确需要时再叠加 contract lane。
- 做 mutation 时，默认从单个 `src/*.lua` 文件开始，并优先用 `behavior` lane。
