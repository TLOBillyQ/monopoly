---
kind: spec
status: draft
owner: specifier
---

# 质量工具 LuaJIT + Filter 模式统一

## 背景

dry4lua 采用的 LuaJIT + filter 模式被确认为最优方案。
本规格定义将 arch_view、scrap4lua、crap4lua、mutate4lua 四个工具
统一到同一模式的目标行为。

## 模式定义

每个 4lua 质量工具必须满足以下约束：

1. **纯 Lua 实现**：核心逻辑全部用 Lua 编写，无 Go / C 二进制依赖。
2. **LuaJIT 兼容**：所有代码可在 LuaJIT 2.1 下运行，不依赖 Lua 5.3+ 独有 API
   （`utf8` 标准库、`string.pack/unpack`、整数除法 `//`、位运算符 `& | ~ << >>`）。
   `goto` 和 `math.tointeger` 在 LuaJIT 2.1 中可用。
3. **Filter Wrapper**：`tools/quality/<tool>.lua` 仅做 bootstrap + 委托 vendor CLI，
   不超过 30 行有效代码（空行 / 注释不计）。所有业务逻辑在 vendor 内部。
4. **CLI 路径输入**：优先通过 CLI 参数接收路径；配置文件仅用于语义必需的声明
  （架构规则、collection 定义、coverage adapter）。
5. **文件发现**：统一使用 `common.collect_files` 或 `io.popen("find")`。

## 参考基线：dry4lua

```
tools/quality/dry.lua        — 21 行 wrapper（bootstrap + require cli + run）
vendor/dry4lua/lib/           — 纯 Lua：lexer → scope → analysis → cli
CLI: luajit tools/quality/dry.lua [--threshold N] [--min-lines N] [path...]
文件发现: io.popen("find") 在 analysis.lua 内部
```

---

## 工具一：arch_view

### 现状

- 纯 Lua，已接近达标
- JSON 配置（`tools/quality/arch/config.json`）定义架构规则 — 语义必需，保留
- `utf8` 模块用于 viewer 渲染（host.lua:167）— 需要 fallback
- `math.tointeger` 已有 nil guard
- Wrapper 101 行，含 `check` 子命令的 filter 逻辑和 violation 格式化

### 目标行为

- `luajit tools/quality/arch.lua check` 与 `lua tools/quality/arch.lua check` 输出一致
- `luajit tools/quality/arch.lua` (viewer) 正常工作
- Wrapper ≤ 30 行有效代码
- `check` 子命令的 filter 逻辑和 violation 格式化移入 vendor

### 变更范围

1. Wrapper 精简：`check` filter + violation 输出移入 `vendor/arch_view/`
2. LuaJIT 兼容：`utf8` 调用增加 `pcall` guard 或 pure-Lua fallback
3. 配置文件保留（JSON），不变

### 验收标准

| # | 标准 | 验证方式 |
|---|------|----------|
| A1 | `luajit tools/quality/arch.lua check` 退出码与 `lua` 版一致 | 两次运行比较退出码 |
| A2 | `luajit tools/quality/arch.lua check` 输出与 `lua` 版一致 | diff 比较 stdout/stderr |
| A3 | Wrapper 有效代码行 ≤ 30 | `grep -cve '^\s*$' -e '^\s*--' tools/quality/arch.lua` |
| A4 | vendor 内无 `utf8.codepoint` 裸调用（均有 pcall guard 或 fallback） | grep 检查 |

---

## 工具二：scrap4lua

### 现状

- 纯 Lua，LuaJIT 兼容（`goto` 在 JIT 2.1 可用）
- Lua 配置（`tools/quality/scrap/config.lua`）定义 collection — 语义必需，保留
- Wrapper 230 行，含 arg parsing、path resolution、tmp 路径映射

### 目标行为

- `luajit tools/quality/scrap.lua index` 与 `lua` 版输出一致
- 所有子命令（index / find / clusters / viewer）通过 LuaJIT 可运行
- Wrapper ≤ 30 行有效代码
- arg parsing、path resolution、help text 移入 vendor CLI

### 变更范围

1. Wrapper 精简：arg parsing + path resolution + help 移入 `vendor/scrap4lua/`
2. `_default_tmp_root` / `_resolve_cli_path` 逻辑移入 vendor CLI，
   wrapper 只传入 Monopoly-specific 默认值（config path、tmp env var name）
3. 配置文件保留（Lua），不变

### 验收标准

| # | 标准 | 验证方式 |
|---|------|----------|
| S1 | `luajit tools/quality/scrap.lua index --out /tmp/test.json` 退出码 0 | 运行验证 |
| S2 | 输出 JSON 与 `lua` 版结构一致 | diff 比较 |
| S3 | Wrapper 有效代码行 ≤ 30 | grep 计数 |
| S4 | `luajit tools/quality/scrap.lua --help` 正常显示 | 运行验证 |

---

## 工具三：crap4lua

### 现状

- Go 二进制（`crap4lua`）处理：luac 字节码解析、复杂度计算、CRAP 评分、HTML viewer
- Lua bridge 处理：配置加载、coverage 收集（`debug.sethook`）
- Wrapper 992 行，含全部 CLI 路由和 Go 二进制交互

### 目标行为

- 移除 Go 二进制依赖
- 核心分析逻辑纯 Lua 实现：
  - **luac 字节码解析**：调用 `luac -p -l <file>` 解析文本输出提取函数边界和指令行
  - **复杂度**：`1 + decision_line_count`
    （decision opcodes: EQ, LT, LE, TEST, TESTSET, FORLOOP, FORPREP, TFORLOOP）
  - **CRAP 评分**：`complexity² × (1 - coverage)³ + complexity`
  - **HTML viewer**：模板替换生成静态页面
- 保留所有现有子命令：report / collect / viewer / summary / dry-run
- Wrapper ≤ 30 行
- LuaJIT 兼容

### CLI 接口（保持不变）

```
luajit tools/quality/crap.lua report [--lane NAME] [--runner NAME] [--out FILE] [--top N]
luajit tools/quality/crap.lua collect [--lane NAME] [--runner NAME] --out FILE
luajit tools/quality/crap.lua dry-run [--lane NAME] [--runner NAME]
luajit tools/quality/crap.lua viewer [--in-json FILE] [--out-dir DIR] [--open]
luajit tools/quality/crap.lua summary [--in-json FILE] [--tier-config FILE] [--gate]
luajit tools/quality/crap.lua   （裸调用 = report + viewer --open）
```

### 变更范围

1. **新增** `vendor/crap4lua/lib/` 纯 Lua 模块：
   - luac 输出解析器（函数边界 + 可执行行 + decision 行）
   - 复杂度 & CRAP 计算
   - report JSON 生成
   - HTML viewer 生成（模板 + JSON 内嵌）
2. **保留** 现有 Lua coverage bridge（`debug.sethook` 机制不变）
3. **删除** Go 二进制相关：`ensure_binary`、`_launcher_source`、binary 调用链路
4. Wrapper 精简到 bootstrap + 委托

### 验收标准

| # | 标准 | 验证方式 |
|---|------|----------|
| C1 | `go` / `crap4lua` 二进制不在调用链中 | grep vendor + wrapper 无 binary 引用 |
| C2 | `luajit tools/quality/crap.lua report --out /tmp/crap.json` 退出码 0 | 运行验证 |
| C3 | report JSON 包含 `functions` 数组，每项有 `crap_score` / `complexity` / `hit_line_count` / `executable_line_count` | JSON 结构检查 |
| C4 | `luajit tools/quality/crap.lua summary --gate` 行为与现有一致 | 对比运行 |
| C5 | `luajit tools/quality/crap.lua viewer --open` 生成 HTML | 检查输出文件 |
| C6 | Wrapper 有效代码行 ≤ 30 | grep 计数 |
| C7 | `luac` 命令不存在时报清晰错误（依赖外部 luac） | 测试错误路径 |

### 设计约束

- `luac -p -l` 是外部命令依赖，与 LuaJIT 的 `luajit -bl` 格式不同。
  初版使用 `luac`（与 Go 版行为一致）；后续可扩展支持 `luajit -bl`。
- coverage 收集必须在宿主 Lua 进程内运行（`debug.sethook`），
  不能移到 LuaJIT 子进程。report 可以后处理。

---

## 工具四：mutate4lua

### 现状

- Go 二进制（`mutate4lua-engine`）处理：变异生成、测试编排、工作区隔离、manifest
- Lua 已有：lexer（268 行）、scanner（315 行）、manifest（87 行）— 覆盖变异发现全流程
- Go 独占功能：并行 worker 调度、workspace 复制 + 变异注入、timeout 管理、JSON 输出
- Wrapper 263 行

### 目标行为

- 移除 Go 二进制依赖
- 现有 Lua lexer / scanner / manifest 作为核心，补充：
  - **测试编排**：对每个变异位点 — 复制工作区 → 注入变异 → 运行测试 → 收集结果
  - **工作区隔离**：`cp -r` 到临时目录，变异后运行测试命令
  - **超时管理**：baseline 时间 × timeout_factor
  - **JSON / text 输出**
- 保留所有现有子命令：mutate / scan / update-manifest / index-suites
- Wrapper ≤ 30 行
- LuaJIT 兼容

### CLI 接口（保持不变）

```
luajit tools/quality/mutate.lua <file.lua> [--lane behavior|contract] [--runner harness|busted]
luajit tools/quality/mutate.lua <file.lua> --scan
luajit tools/quality/mutate.lua <file.lua> --update-manifest
luajit tools/quality/mutate.lua --index-suites [--lane NAME]
luajit tools/quality/mutate.lua <file.lua> --dry-run
```

### 变更范围

1. **新增** `vendor/mutate4lua/lua/mutate4lua/` 模块：
   - engine.lua — 测试编排主循环（替代 Go engine）
   - workspace.lua — 目录复制 + 变异源文件注入
   - reporter.lua — JSON / text 输出格式化
2. **复用** 现有 lexer / scanner / manifest（无需改动）
3. **删除** Go 二进制相关：`engine_bridge.lua` 的 binary 解析、`ensure_binary`
4. Wrapper 精简到 bootstrap + 委托

### 执行模型

- 初版采用**顺序执行**（一次一个变异），不要求并行 worker。
  理由：LuaJIT 没有原生并行子进程管理；顺序执行正确性优先。
- `--max-workers N` 参数保留但初版忽略（等价于 `--max-workers 1`）。
- 后续可通过 shell 级并行（多个 `luajit` 子进程）恢复并行能力。

### 验收标准

| # | 标准 | 验证方式 |
|---|------|----------|
| M1 | `go` / `mutate4lua-engine` 二进制不在调用链中 | grep 检查 |
| M2 | `luajit tools/quality/mutate.lua src/xxx.lua --scan` 发现变异位点数量与 Go 版一致 | 选取 3 个源文件对比 |
| M3 | `luajit tools/quality/mutate.lua src/xxx.lua` 正确执行变异测试并报告 killed/survived | 运行验证 |
| M4 | `luajit tools/quality/mutate.lua src/xxx.lua --update-manifest` 写入 manifest 块 | 检查源文件尾部 |
| M5 | `luajit tools/quality/mutate.lua --index-suites` 正常列出 suites | 运行验证 |
| M6 | Wrapper 有效代码行 ≤ 30 | grep 计数 |
| M7 | 工作区临时目录在测试结束后清理 | 检查 /tmp 或 .mutate4lua/cache |
| M8 | 测试超时正确触发（baseline × timeout_factor） | 构造慢测试验证 |

---

## 执行顺序建议

1. **arch_view** — 改动最小，验证 LuaJIT 兼容 + wrapper 精简模式
2. **scrap4lua** — 同类改动，巩固模式
3. **crap4lua** — 需新增 Lua 模块替代 Go 二进制
4. **mutate4lua** — 需新增测试编排逻辑，复杂度最高

## 不在范围

- 并行 worker 支持（mutate4lua 初版顺序执行）
- `luajit -bl` 作为 `luac -p -l` 的替代（crap4lua 初版用 luac）
- 修改 dry4lua 本身
- 修改 vendor 工具的对外 API / JSON 输出格式
