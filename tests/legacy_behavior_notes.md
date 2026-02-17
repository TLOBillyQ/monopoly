# legacy behavior notes

记录旧测试行为在新测试架构下的解释与兼容策略。

## 端口契约（平铺 -> 分组）

- 旧平铺端口（例如 `apply_input_lock`）不再是主契约。
- 新主契约以 `turn/types.lua` 的分组键为准：`modal/anim/ui_sync/debug/state`。
- 迁移期间通过 `tests/runner/legacy_adapter.lua` 兼容旧 suites，避免一次性中断。

## legacy 执行入口

- legacy 兼容执行已切到完整 suite：`gameplay`、`presentation_ui`。
- `tests/suites/*_registry.lua` 与切片入口文件已删除，不再维护索引切片机制。

## 失败定位

- 新 runner 输出格式：`[layer/domain] case_id`。
- 旧 suite 通过 legacy adapter 归类到 `layer=legacy`，便于后续分批迁移。

## smoke 脚本

- `tests/internal/gameplay_loop_no_ui.lua` 已改为分组端口注入，避免 fallback no-op 假绿。
- `tests/internal/dep_rules.lua` 仍保留为独立校验脚本。
