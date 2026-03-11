# CRAP Report

`scripts/crap.lua` 是仓库里的 Lua 版 CRAP 热点工具。它参考 Crap4j 的核心思路：把函数复杂度和动态测试覆盖率合成一个分数，用来排出“最该先重构/补测”的函数热点。

它不是新的 guard，也不会替代 `tests/behavior.lua`、`tests/contract.lua` 或 `lua tests/guard.lua`。它回答的问题更窄：当前 `src/**/*.lua` 里，哪些函数既复杂、又缺少测试触达，因此最危险。

## 为什么单独做一套工具

本仓库已经有 `arch_view`、文本护栏和回归测试，但它们更关注“边界是否正确”“行为是否回归”。CRAP 工具补的是另一个维度：在这些边界都还活着的时候，哪一批函数正在积累维护成本。

本实现遵守当前仓库的现实约束：

- 只依赖本机 `lua` / `luac`
- 不引入 LuaRocks、Busted 或 C 模块
- 复用现有 `tests.catalog` 与 `TestHarness`
- 默认即使所选测试 lane 失败，也照样产出报告，避免当前已知红线让工具完全不可用

## 命令

在仓库根目录执行：

    lua scripts/crap.lua report --out tmp/crap_report.json --top 20

这里的 `tmp/...` 不是仓库内相对目录，而是 CRAP CLI 约定的“逻辑临时目录别名”。它会自动映射到当前系统的临时目录：

- Windows：`%TEMP%/monopoly_crap/...`
- macOS：`$TMPDIR/monopoly_crap/...`

如果你想覆盖这个默认位置，可以先设置 `MONOPOLY_CRAP_TMP`。

默认行为：

- 作用域：`src/**/*.lua`
- lane：`behavior`
- mode：沿用 `tests/behavior.lua` 的 `auto/dev/release_trimmed` 解析

如果你还想把 contract 测试的动态触达一起算进去：

    lua scripts/crap.lua report --lane behavior --lane contract --out tmp/crap_report.json

如果你希望测试 lane 失败时让命令返回非零退出码：

    lua scripts/crap.lua report --strict-tests --out tmp/crap_report.json

导出静态 viewer：

    lua scripts/crap.lua

无参数时，`crap.lua` 会直接生成并打开静态 viewer，等价于：

    lua scripts/crap.lua viewer --out-dir tmp/crap_view --open

这里的 `tmp/...` 仍然是 CRAP CLI 的临时目录别名，不是仓库内 `./tmp/...`。

    lua scripts/crap.lua viewer

显式执行 `viewer` 但不带 `--out-dir` 时，也会默认导出到 `tmp/crap_view`；不过它不会像无参数入口那样自动打开浏览器。

如果已经有导出的 JSON，可直接复用：

    lua scripts/crap.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view

命令完成后会打印实际输出路径；打开打印出来的 `index.html` 即可查看，不需要本地服务。

## 分数与数据来源

复杂度来自 `luac -p -l` 的函数字节码清单。工具按函数 proto 的行号范围收口函数，再用条件/循环相关 opcode 对应的源码行数计算复杂度，公式固定为：

    complexity = 1 + decision_line_count

覆盖率来自动态行命中。工具在运行 behavior/contract suite 时通过 `debug.sethook(..., "l")` 记录命中的 `src/**/*.lua` 行号，再把函数的可执行行与命中行求交，得到函数级行覆盖率。

CRAP 分数公式固定为：

    complexity^2 * (1 - coverage)^3 + complexity

这里的 `coverage` 是 0 到 1 之间的小数，不是百分比字符串。

## 如何读报告

终端会先输出 lane 状态和前几个热点函数。JSON / viewer 里主要看三个字段：

- `complexity`：函数内部的决策密度
- `coverage`：该函数可执行行中，被所选测试 lane 实际触达的比例
- `crap`：综合风险分数，越高越该优先处理

viewer 里当前固定三档风险色：

- `< 10`：`low`
- `10 - 30`：`warning`
- `> 30`：`critical`

这不是“是否允许合并”的硬标准，只是默认排序带。

## 当前边界

v1 只分析 `src/**/*.lua` 的函数，不给 `tests/`、`scripts/`、`vendor/` 打分。它关注的是生产逻辑热点，不是测试脚本或治理脚本本身。

另外，v1 采用“函数级行覆盖率”，不是分支覆盖率。原因不是理论更优，而是它在 Lua 5.1 + 零额外依赖 + 现有 TestHarness 架构下最稳妥、最可重复。
