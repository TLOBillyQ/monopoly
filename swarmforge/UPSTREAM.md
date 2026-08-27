# SwarmForge 上游同步记录

同步边界元数据 —— 按 ADR 0059，上游资产由自己的执行/同步边界管理，不并入
docs 叙事白名单。本文件只记录同步进度与下次同步步骤，不改动任何上游资产。
上游仓库：https://github.com/unclebob/swarm-forge

## 双源映射

- `four-pack` 分支 → pack 资产：`swarmforge.conf`、`roles/*.prompt`、
  `constitution.prompt`、`constitution/articles/local-workflow.prompt`。
- `main` 分支 → 共享资产：`constitution/articles/{engineering,handoffs,workflow}.prompt`、
  `handoff-protocol.md`、`close-swarm`；以及运行时 `swarmforge/scripts/`
  （gitignored，`swarm` wrapper 首跑按上游 README 从 main 归档拉取）。
- 本地定制面（不得污染上游原文）：`constitution/articles/project.prompt`、
  `constitution/articles/local-engineering.prompt`（Lua/Eggy 形状）、
  `swarmforge.conf` 角色后端行（claude ≠ 上游 codex）；`swarm`/`close-swarm`
  的 `#387 &!;` 补丁（上游修复后自动空转）。

## 最近一次同步

- 日期：2026-08-27
- `four-pack` @ `83f8193` "Do not re-forward an architect merge."（未变动，pack 面无差异）
- `main` @ `60e9280` "Find completed retry notes and replace colliding completes."
  （8e83a09..60e9280 共 7 笔：审计目录清理与澄清应答受理、逐文档 Attention
  评审与被驳回 handoff 转审计重试、get-swarm-forge PATH 稳定化、pack 安装不再
  覆盖宿主文件与共享 constitution、Playwright dashboard 测试并入 bb test、
  已完成重试笔记归并与 complete 冲突替换）。
- 版本化变更：无 —— 共享 3 个 article、`handoff-protocol.md` 与 `close-swarm`
  与 main tip 逐字一致，本地定制面原样保留。
- 运行时：`swarmforge/scripts/` 重拉至 main tip（47 项，新增
  `ready_for_next_guard.bb` 与 `pack_web_test.bb`，15 个既有脚本/dashboard
  有差异）；`#387` 命中 1 处已落（`swarmforge.bb:500`）。

## 下次同步步骤

1. `git ls-remote https://github.com/unclebob/swarm-forge.git` 取 `four-pack`、`main` 最新 SHA。
2. 浅克隆两个分支：`git clone --depth 1 -b four-pack <url> /tmp/sf4`、`... -b main <url> /tmp/sfmain`。
3. 逐文件 `diff` 对齐（pack 4 角色 + conf + constitution.prompt + local-workflow；
   shared 3 article + handoff-protocol + close-swarm），本地定制面原样保留。
4. 刷新运行时：`rm -rf swarmforge/scripts`，按 `swarm` wrapper setup 段从 main 归档重拉
   scripts 与 shared-articles，再落 `#387`（`grep -q '&!;' swarmforge/scripts/swarmforge.bb` 则 sed 替换）。
5. `lua tools/cli.lua verify`；改出后按需真机冒烟（见 #557）。