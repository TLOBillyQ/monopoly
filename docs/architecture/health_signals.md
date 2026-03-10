# 健康信号与周检入口

这份文档把当前仓库已经存在的健康信号收口成一份可执行的周检清单。它的目标不是生成新的 dashboard，而是让新手只靠这一个文件，就能知道每周应该跑哪些命令、每条信号回答什么问题、看到什么结果才算健康。

## 为什么需要这份文档

当前仓库已经有很多健康信号，但它们散落在不同位置。`MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua` 会汇总 behavior、contract 与 guard 三条车道；`scripts/analysis/analyze_loc.py` 会观察 `src/` 与 `tests/` 最近两天的 LOC 变化。如果没有统一入口，后来者很容易只盯着某一个指标，例如纯 LOC 下降，却忽略真正更重要的边界稳定性和回归结果。

## 本周必须看的核心信号

第一组信号是全量回归与护栏：

    MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua

这条命令回答的问题是：当前工作树在全局上是否仍然满足回归、依赖边界和护栏要求。这里的护栏现在是“硬边界”集合：`arch_view` 看结构依赖，`dep_rules` 看宿主 API/退休桥接/UI 旁路，`legacy_path_guard` 看旧模块 id 回流，`forbidden_globals` 看运行时禁用语法。健康时应至少看到：

    All regression checks passed (416)
    All regression checks passed (62)
    dep_rules ok
    legacy_path_guard ok
    gameplay_loop_no_ui ok

如果这里失败，优先修复，不要继续看 LOC 趋势或做目录整理。

第二组信号是架构与契约检查：

    lua tests/contract.lua

这条命令回答的问题是：`output_adapters/`、gameplay loop output、choice contract、窄 Port 注入等边界是否仍然稳定。只要动到 `src/game/flow/output_adapters/`、`docs/architecture/*`、`choice_contract` 或 runtime 输出桥，这条 lane 都应该先跑。

第三组信号是 UI 热点回归：

    MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua

这条命令回答的问题是：市场弹窗、玩家面板、choice 路由、target picker、market/popup/pending choice UI 行为是否仍然稳定。它不是纯展示测试，而是当前最直接的 behavior 热点守门。

## LOC 观察只作为辅助信号

LOC 仍然可以看，但只能作为辅助观察项，不能单独驱动重构决策。运行命令：

    python3 scripts/analysis/analyze_loc.py

这条命令会更新 `scripts/analysis/loc_data.json` 与 `scripts/analysis/loc_trend.png`，展示最近两天 `src/` / `tests/` 的变化趋势。它回答的问题是：热点文件和测试总体是在膨胀、收缩，还是保持稳定；它不能回答边界是否正确、契约是否清晰、回归是否安全。

如果 LOC 上升，但 `regression`、architecture suite 和热点 suite 继续稳定通过，而且新增代码是在换取更清晰的边界或更强的测试，这不应自动被视为退化。只有当 LOC 增长同时伴随边界漂移、重复逻辑回流、或测试覆盖下降时，才值得把它当成问题。

## 建议的周检顺序

先跑全量回归：

    MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua

再跑架构与契约：

    lua tests/contract.lua

如果本周改了 presentation 热点，再补跑：

    MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua

最后再看 LOC 趋势：

    python3 scripts/analysis/analyze_loc.py

这个顺序的原则是：先判断“是否安全”，再看“是否优雅”。回归和边界永远优先于 LOC 图表。

## CRAP 报告是诊断信号，不是周检 gate

如果本周需要判断“哪些函数最值得优先补测或拆分”，运行：

    lua scripts/quality/crap_cli.lua report --out tmp/crap_report.json --top 20

这条命令不会替代 regression / contract / guard。它更像热点雷达：把 `src/**/*.lua` 里复杂度高、同时动态测试触达不足的函数排出来。默认 lane 是 `behavior`，因此它反映的是“当前行为回归到底摸到了哪些函数”，而不是完整证明。

如果要看可视化结果，再执行：

    lua scripts/quality/crap_cli.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view

打开 `tmp/crap_view/index.html` 就能按模块和函数查看热点。因为当前仓库的 `behavior` / `contract` 基线本身并非全绿，所以这条工具默认即使 lane 失败也会继续产出报告；只有显式加 `--strict-tests`，才会把测试失败升级为命令失败。

## 什么时候才值得迁 `output_adapters/`

默认不要因为目录名不完美就迁 `src/game/flow/output_adapters/`。只有同时看到以下至少一类信号，才值得重新评估：

- 这些文件开始承载宿主细节，而不再只是 turn use case 本地输出桥。
- 调用面明显扩到多个非 turn 用例，导致 `flow` 本地桥接语义不再成立。
- `src/game/runtime/*_port_adapter.lua` 与 `src/game/flow/output_adapters/*.lua` 出现稳定职责重叠，后来者已经难以区分。
- 相关 architecture suite 无法再用当前目录语义解释，必须靠额外口头约定才能理解。

在这些条件出现前，优先补文档、补测试、补 health signal，而不是做目录手术。
