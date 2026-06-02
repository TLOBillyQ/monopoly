---
name: promote-dev-to-main
description: 将 noisy 的 dev / origin/dev 工作树整理成 main / origin/main 的线性功能提交。触发：dev 提交 main、promote dev to main、拉直 dev、整理 swarm-forge 历史、去掉 merge 噪声、按功能重组提交。不用于：普通 feature 开发、代码 review、单纯检查 main/dev 文件树是否一致。
---

# Promote Dev To Main

把 `dev` 当作 swarm-forge 工作分支，把 `main` 当作人工整理后的发布历史分支。核心规则：

**提交的是 dev 的文件树，不是 dev 的提交图。**

不要 `git merge dev`。不要用 dev 的 merge 历史决定范围。范围以 `origin/main..origin/dev` 的 tree diff 为准，`git log` 只作辅助理解。

如果当前本地 `dev` 领先 `origin/dev`，先把本地 `dev` 推到 `origin/dev`，再 promote。不要在未推送的本地 tree 和远端 tree 之间猜目标。

## 前置

先读 repo 指令：

- `AGENTS.md`
- `CLAUDE.md`
- `/Users/billyq/.codex/RTK.md`

本 repo 命令必须用 `rtk ...`。

先刷新并确认干净：

```bash
rtk git fetch origin --prune
rtk git status --short --branch -uall
rtk git rev-parse --abbrev-ref HEAD
rtk git rev-list --left-right --count origin/dev...dev
rtk git rev-parse origin/main origin/dev origin/main^{tree} origin/dev^{tree}
rtk git diff --exit-code --stat origin/main..origin/dev
```

如果工作树不干净，停止。不要 stash、reset、clean、checkout 来隐藏用户工作。

如果当前分支是 `dev`，且 `rtk git rev-list --left-right --count origin/dev...dev` 显示右侧非 0、左侧为 0，说明本地 `dev` 只领先远端。先推送本地 `dev`：

```bash
old_dev="$(rtk git rev-parse origin/dev)"
rtk git push --force-with-lease=dev:"$old_dev" origin dev
rtk git fetch origin --prune
rtk git diff --exit-code dev..origin/dev
```

如果左右两侧都非 0，说明 `dev` 与 `origin/dev` 已分叉，停止并要求用户决定是否先整理 `dev`。如果当前不在 `dev`，但本地 `dev` 领先 `origin/dev`，也停止并要求用户确认是否切到 `dev` 推送。

## No-op

如果 `origin/main^{tree}` 和 `origin/dev^{tree}` 一样，直接报告 no-op。

历史不同是正常的。`rtk git rev-list --left-right --count origin/dev...origin/main` 很大也不代表要 promotion；tree 相同就不要重写 `main`。

## Promotion

tree 不同时：

1. 从当前 `origin/main` 创建并推送回滚分支。

```bash
timestamp="$(rtk date +%Y%m%d-%H%M%S)"
rtk git branch "backup/main-before-dev-promote-$timestamp" origin/main
rtk git push -u origin "backup/main-before-dev-promote-$timestamp"
```

2. 创建临时分支，把 dev 文件树展开为 main 后的未暂存 diff。

```bash
rtk git switch -c codex/promote-dev-to-main origin/dev
rtk git reset --soft origin/main
rtk git reset
```

此时 `HEAD` 在 `origin/main`，工作树是 `origin/dev` 的最终文件树。

3. 按精确路径 stage，避免误收 ignored 本地杂项。

```bash
rtk git diff --name-status origin/main..origin/dev
rtk git status --short -uall
```

只有确认目标 tree 里确实需要的 ignored 文件，才用 `rtk git add -f <path>`，例如特定 `agent_context/**` 证据文件。

## 提交组织

优先 5-10 个提交，按功能组织，不按 agent / worktree / merge 顺序组织。

建议顺序：

1. `feat(...)`：用户可见功能、玩法、宿主接线、UI 行为。
2. `feat(acceptance)` / `test(...)`：Gherkin、behavior spec、property spec、mutation closure。
3. `feat(mutate)` / `feat(quality)`：mutation tooling、CRAP gate、verify 管线。
4. `refactor(src)`：行为不变的 runtime / UI 重构。
5. `docs(context)`：ADR、backlog、报告、`agent_context/**`。
6. `chore(swarm)`：swarm-forge 脚本、agent 启动参数、操作胶水。

同一文件横跨多个主题时，放到最利于 review 的主题提交里。不要为了完美拆分而做高风险 hunk split。

## 验证

动 `main` 前证明临时分支等价于 dev：

```bash
rtk git diff --exit-code origin/dev..HEAD
rtk git diff --exit-code HEAD..origin/dev
rtk git log --merges --oneline origin/main..HEAD
```

最后一条应为空。

跑验证：

```bash
rtk verify
```

如果变更包含 `tools/{quality,acceptance,shared,ops}/**`：

```bash
rtk busted --run tooling
```

## 推送

推前再次 fetch，用显式 lease：

```bash
rtk git fetch origin --prune
old_main="$(rtk git rev-parse origin/main)"
rtk git branch -f main HEAD
rtk git push --force-with-lease=main:"$old_main" origin main
rtk git switch main
rtk git branch -d codex/promote-dev-to-main
```

最终确认：

```bash
rtk git status --short --branch -uall
rtk git rev-list --left-right --count origin/main...main
rtk git rev-parse origin/main origin/dev origin/main^{tree} origin/dev^{tree}
rtk git diff --exit-code origin/dev..origin/main
```

## 汇报

汇报以下内容：

- no-op 还是已推送。
- 新 `main` hash。
- backup 分支名和旧 `main` hash。
- 整理后的提交列表。
- 实际跑过的验证命令和结果。
- `origin/main` 与 `origin/dev` 文件树是否一致。

不要声称测试通过，除非本轮真的跑过。
