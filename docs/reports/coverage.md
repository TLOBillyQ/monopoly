# Coverage Report

`tools/quality/coverage.lua` 用 `busted -c` 触发 luacov instrumentation，统计 `src/{core,rules,turn,state,player,computer}` 6 个核心目录的 line coverage。它与 `tools/quality/crap.lua` 是两条独立流水线：crap 关注"复杂度 × 反测试"风险热点，coverage 关注"哪些行根本没跑过"。

如果你想先看整个质量面里 `coverage` 和 `behavior / contract / guard / arch_view / crap` 的分工，先读 `docs/architecture/quality-map.md`。

## 命令

```
lua5.5 tools/quality/coverage.lua
```
无参数：跑 `behavior + contract + guards` 三个 profile，输出聚合报告到 `tmp/coverage.md`，门槛 90%。

```
lua5.5 tools/quality/coverage.lua --threshold=85 --out=tmp/coverage_baseline.md
```
自定义聚合门槛与输出路径。

```
lua5.5 tools/quality/coverage.lua --profiles=guards --threshold=0 --out=tmp/coverage_dryrun.md
```
单 profile 快速跑（适合调试）。多 profile 用逗号分隔。

```
lua5.5 tools/quality/coverage.lua --quiet
```
抑制 busted/luacov 进度日志，只输出错误与最终报告。

```
lua5.5 tools/quality/coverage.lua --reuse-stats --out=tmp/coverage_replay.md
```
跳过 busted 重跑，直接用现有 `luacov.stats.out` 重新生成报告。用于诊断报告解析问题或调参 threshold/out 时避免重复 30s 测试开销。

> **运行时绑定**：脚本必须在 Lua 5.5 下执行（项目主运行时）。busted/luacov shim 通过环境变量 `LUA55_BIN` / `BUSTED_BIN` / `LUACOV_BIN` 显式指定，未设置时按 `/opt/homebrew/bin/lua5.5` → `/usr/local/bin/lua5.5` → PATH 顺序探测，并通过 `luarocks --lua-version=5.5 list --porcelain` 解析 busted/luacov 安装位置。

## 输出

聚合 markdown 报告包含：

1. **Per-Directory Summary**：6 个核心目录的 hits / miss / total / coverage
2. **Aggregate**：6 目录合并后的总覆盖率（与门槛比较的判定值）
3. **Per-File Detail**：按覆盖率升序排列的所有文件，便于定位补测优先级
4. **Result**：`PASS` / `FAIL`（基于聚合 vs threshold）

中间产物：`luacov.stats.out`（hook 累积数据）+ `luacov.report.out`（luacov 完整文本报告）。两者均已 gitignore。

## 何时跑

| 场景 | 命令 |
|------|------|
| 提交前快速核查（仅 guards） | `lua5.5 tools/quality/coverage.lua --profiles=guards --threshold=0 --out=tmp/coverage_quick.md` |
| 完整 baseline | `lua5.5 tools/quality/coverage.lua --out=tmp/coverage_baseline.md` |
| 大重构后回归 | 比对前后两份 `tmp/coverage_*.md` 的 Per-Directory Summary |
| CI gate（≥90% 阈值生效后） | `lua5.5 tools/quality/coverage.lua` 或 `verify-full` step 7 |

## 与其他工具的关系

- **crap4lua** (`tools/quality/crap.lua`)：复杂度 × 测试覆盖度合成；coverage.lua 不替代 crap，二者并存。
- **arch_view** (`tools/quality/arch.lua`)：架构边界静态扫描，与 line coverage 无关。
- **mutate4lua** (`tools/quality/mutate.lua`)：变异测试，验证测试质量；coverage 通过不代表 mutation score 通过。
- **behavior/contract/guards spec**：coverage 数据来源于这三条 lane 的合并执行；新增测试在哪个 lane 由测试性质决定（见 `docs/architecture/quality-map.md`）。

## 禁用范围

排除 `src/{app,host,ui,config}/`、`tests/`、`spec/`、`tools/`、`vendor/`：这些目录或为 adapters/UI 实现细节，或为测试与工具链本身。详见 `.luacov` 顶部 include/exclude 列表。

## 故障排查

| 现象 | 原因 | 处理 |
|------|------|------|
| `luacov.stats.out` 0B | helper hook 未生效或 double-init | 检查 `spec/helper.lua` 的 `LUACOV` 守卫；确认未在 helper 内裸 `require("luacov")` |
| `Cannot locate lua5.5 binary` | 项目运行时未安装 | `brew install lua@5.5` 或设置 `LUA55_BIN` |
| `Cannot locate busted/luacov for Lua 5.5` | rocks-5.5 缺包 | `luarocks --lua-version=5.5 install busted luacov luafilesystem` |
| Aggregate 显著低于预期 | profile 漏跑 / `.luacov` include pattern 不匹配 | 比对 `luacov.report.out` 末尾 Summary，排查 include/exclude |
| 单文件出现两份不同覆盖率 | luacov 用 `./src/x.lua` 与 `src/x.lua` 两种 key 各记一份（不同 `package.path` 解析路径所致） | parser 已在 `parse_luacov_report` 内按归一化路径去重，保留 hits 较多的那份；用 `--reuse-stats` 重跑核对 |
