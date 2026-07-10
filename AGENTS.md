# AGENTS.md

See [CLAUDE.md](CLAUDE.md) — single source of truth for agent instructions in this repo.

## 命令约定（RTK · Rust Token Killer）

- 所有 dev / git 命令一律用 `rtk` 前缀执行以省 token：
  - `git status` → `rtk git status`
  - `git diff`   → `rtk git diff`
  - `git log`    → `rtk git log`
- 例外：`rtk gain` / `rtk discover` / `rtk proxy <cmd>` 直接调，不再套 `rtk`。
- 前提：`rtk` 已在 PATH（不确定时先 `which rtk` 确认）。
