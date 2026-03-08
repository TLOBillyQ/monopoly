# Arch View

`arch_view` 是本仓库的静态架构扫描器。它只分析 `src/**/*.lua` 的模块级 `require` 依赖，负责三件事：生成依赖图、按层投影视图、校验声明式边界规则。它不替代 `tests/internal/legacy_path_guard.lua`、`tests/internal/forbidden_globals.lua` 这类文本护栏；这些脚本仍负责旧路径、宿主全局 API 与运行时禁用语法的检查。

## 真源与边界

结构性依赖规则的唯一真源是 `scripts/architecture/monopoly_architecture.lua`。这里声明了 source roots、组件归类、抽象 Port 规则、禁止依赖边界和当前允许存在的循环基线。`tests/internal/dep_rules.lua` 现在保留文本模式护栏与 growth budget，不再重复维护模块级 `require` 边界。

当前基线化的 3 个循环依赖只是“暂时允许存在并防止继续扩张”，不是合理性的背书。`arch_view` 会在两种情况下失败：出现新的循环/扩大已有循环，或者某个基线循环消失后配置未同步更新。

## 命令

在仓库根目录运行：

    lua scripts/architecture/arch_view_cli.lua check

这会扫描 `src/`，执行边界校验，并在失败时用非零退出码结束。`tests/internal/arch_view_guard.lua` 与 `tests/regression.lua` 使用的就是这套能力。

    lua scripts/architecture/arch_view_cli.lua scan --out /tmp/monopoly_architecture.json

这会导出完整机器可读数据，包含 `graph`、`modules`、`layout`、`views` 与 `check`。

    lua scripts/architecture/arch_view_cli.lua viewer --out-dir /tmp/monopoly_arch_view

这会导出静态 viewer：`index.html`、`script.js`、`styles.css`、`architecture.json`、`architecture_data.js`。打开 `index.html` 即可查看，不需要本地服务。

## Viewer 读法

根视图直接展示 `app`、`core`、`game`、`infrastructure`、`presentation` 五个顶层子树。点击非叶子节点会继续下钻；点击叶子节点会在右侧看到源码、内部依赖、外部依赖、组件、层级、抽象标记与循环标记。

红色节点或红色边表示该节点子树或该聚合边中包含当前循环依赖。绿色节点表示它包含抽象契约，目前主要对应 `src.core.ports.*` 与 `src.game.ports.*`。
