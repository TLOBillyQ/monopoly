# 本项目
- 仅维护 Eggy 平台适配：`src/adapters/eggy/`。
- 运行代码在 `src/`，核心规则在 `src/core/` 与 `src/gameplay/`；入口 `main.lua`、`src/game.lua`。
- `src/config/` 为 `design/*.xlsx` 导出产物。
- Eggy API 检索：先看 `docs/eggy/api/`，再按关键词查 `docs/eggy/EggyAPI.lua`（deprecated 不用）。
- LuaAPI 与 EggyAPI 必然存在，不写可空判断。
- 常用命令：`export_xlsx.bat`、`lua tests/deps_check.lua`、`lua tests/regression.lua`。
