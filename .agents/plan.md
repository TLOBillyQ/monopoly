# Legacy Cleanup Closeout

## Summary

兼容层/转发清理目标已经满足：仓库内不再存在旧生产命名空间 `src.app` / `src.presentation` / `src.game` / `src.infrastructure` / `Config.` 的代码引用，也不再保留对应旧目录。当前不需要再执行新的迁移动作；只需要把这次结果视为最终状态并持续用现有校验守住。

## Key Changes

- Canonical 顶层已稳定为 `src/entry`、`src/host/eggy`、`src/ui`、`src/turn`、`src/player`、`src/computer`、`src/rules`、`src/state`、`src/config`、`src/core`。
- 旧兼容树已清空：`src/app`、`src/presentation`、`src/game`、`src/infrastructure` 不再保留 shim 或转发文件。
- 部署入口已跟随迁移：`main.lua` 现在走 `src.entry.init`，`scripts/deploy.lua` 继续部署 `Config/` 与 `src/`，测试 profile 默认地图模块已切到 `src.config.content.maps.default_map`。
- 文档与架构产物已跟随迁移：`docs/architecture/arch_view.md`、`docs/architecture/layer-model.md`、`scripts/arch/config.lua`、`scripts/arch/viewer/architecture.json`、`scripts/arch/viewer/architecture_data.js` 都已经反映新结构。
- 测试/contract 已跟随迁移：`tests/guards/dep_rules.lua`、`tests/suites/architecture/arch_view_contract.lua`、以及依赖旧别名的 characterization helper 已更新到新命名空间。

## Validation

- 旧残留归零检查：
  - `rg -n 'src\.(app|presentation|game|infrastructure)|Config\.' .`
  - `find src -type d \( -path 'src/app*' -o -path 'src/presentation*' -o -path 'src/game*' -o -path 'src/infrastructure*' \)`
- 基线校验：
  - `lua scripts/arch.lua check`
  - `lua tests/guard.lua`
  - `lua tests/behavior.lua`
  - `lua tests/contract.lua`
- 部署/入口回归：
  - 保持 `main.lua` -> `src.entry.init`
  - 保持 `scripts/deploy.lua` 输出的 `src/` 和 `Config/` 可直接部署

## Assumptions

- 顶层 `Config/` 继续作为部署产物的一部分保留，不再把它视为“旧生产命名空间残留”；约束仅针对代码中的旧模块引用与旧源码树。
- `scripts/arch/viewer/*` 属于可提交的生成产物，应在结构调整后重新生成并提交，而不是忽略。
- 后续若新增模块，只允许写入新顶层命名空间；若再出现旧命名空间引用，应视为回归并由现有 guard/contract 直接拦截。
