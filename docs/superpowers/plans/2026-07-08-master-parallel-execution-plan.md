# 架构深化 —— 主并行执行计划（7 候选编排）

> **For agentic workers / swarm orchestrator:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development` 分派各候选流,用 `superpowers:using-git-worktrees` 做隔离。这是**程序级编排计划**——它不重复各候选的 task 级代码(那些在各自 plan 里,DRY),只负责「哪些候选可同时跑、怎么隔离、怎么合并、怎么设 barrier」。步骤用 `- [ ]` 复选框跟踪。

**Goal:** 把架构评审 7 个候选中**剩余 6 个安全核心**（②P2 / ③ / ④ / ⑤ / ⑥ / ⑦）以**最大并行**、零冲突地落地——它们经核证**文件面两两不相交**,可在隔离 worktree 中并行执行,合并后走单一语义 barrier。

**Architecture:** 每个候选 = 一条 stream,在独立 git worktree 里执行自己 plan 的内部 task DAG（各含 pin→改→gate→commit）。stream 之间因文件不相交而无文本冲突;编排层只做 fan-out（分派）→ join（合并）→ barrier（合并态整仓门禁 + 验收）。分两波（Wave）以保持合并批次可审、并让第一波先趟平 worktree/harness。

**Tech Stack:** Lua 5.4；busted；git worktree 隔离；`make verify`（完整门禁）+ `make acceptance`（验收）。

## Global Constraints

- **每条 stream 必须在独立 worktree**执行（`git worktree add`）。原因：并行 `make verify` 会改文件、并发 `git commit` 会争抢 `.git/index.lock`——worktree 各有独立 index，隔离二者。禁止两条 stream 在同一工作树并行改源码。
- **协调红线**：任何 stream **不得编辑共享 spec-support**（`spec/support/scenario_suites/shared/`、`spec/support/shared_support.lua`）或 `tools/`——这些是唯一可能跨 stream 撞车的面。若某候选执行中发现必须改它们,**停下上报编排层**,退出并行、串行处理该项。
- **各候选的 manifest 刷新 / `make acceptance` 在其自身 plan 的收尾 task 内完成**（都是 per-file / gitignored 生成物,不跨 stream 冲突）。编排层只在 Wave barrier 再跑一次合并态的 `make verify && make acceptance`。
- 不改 `EggyAPI.lua`、`tools/acceptance/generated/*`。
- `src/` 禁用 `tonumber`/`type=="number"`（各候选 plan 已含）。
- **设计先行项不在本计划范围**：④⑤⑥⑦ 各自的「后续半」（await 跨层裸读横扫、pending choice 生命周期 deep module、UI Phase C 大 canvas、skin legacy seam 拆除）需先过 `brainstorming`+`codebase-design`,列入文末 backlog,不并行执行。

---

## 程序全景（7 候选状态）

| # | 候选 | plan 文件 | 状态 | 安全核心触及目录 |
|---|---|---|---|---|
| ① | 金币结算 | `2026-07-08-coin-settlement-deep-module.md` | ✅ 已执行+验收 | rules/commerce, rules/{land,chance,items} |
| ② | 购买结算 P1 | `2026-07-08-candidate-2-purchase-settlement.md` | ✅ 已执行 | rules/market |
| ②P2 | 去 finish_choice 泄漏 | `2026-07-08-candidate-2-phase2-settlement-leak.md` | ⏳ 待执行 | **rules/market + rules/choice_handlers** |
| ③ | 回合序列微映射 | `2026-07-08-candidate-3-phase-wait-dedup.md` | ⏳ 待执行 | **turn/phases {roll,registry,start}** |
| ④ | waits.blocking | `2026-07-08-candidate-4-waits-blocking.md` | ⏳ 待执行 | **turn/waits(blocking新)+turn/phases(land)+turn/loop** |
| ⑤ | pending choice scope | `2026-07-08-candidate-5-pending-choice-lifecycle.md` | ⏳ 待执行 | **turn/deadlines+turn/waits(choice_tracking)** |
| ⑥ | UI 选择屏 | `2026-07-08-candidate-6-ui-screen-modules.md` | ⏳ 待执行 | **ui/** |
| ⑦ | 皮肤购买折叠 | `2026-07-08-candidate-7-skin-purchase-collapse.md` | ⏳ 待执行 | **app/** |

**本计划编排 6 条待执行 stream：②P2 / ③ / ④ / ⑤ / ⑥ / ⑦。**

---

## 跨候选文件冲突矩阵（权威 —— 本计划的核心产物）

已用 `grep` 抽出每个 plan 的 `Create/Modify/Delete` src 文件集并做交集：**即便把「被引用/模板文件」也算进去,没有任何 src 文件出现在两个候选 plan 里**（`uniq -d` 为空）。

| stream | 新建 | 改动 src | 顶层目录 |
|---|---|---|---|
| ②P2 | `rules/market/purchase_settlement.lua` | `rules/market/{choice,auto}.lua`, `rules/choice_handlers/market.lua` | rules/ |
| ③ | — | `turn/phases/{roll,registry,start}.lua` | turn/phases/ |
| ④ | `turn/waits/blocking.lua` | `turn/phases/land.lua`, `turn/loop/tick_flow.lua` | turn/ |
| ⑤ | `turn/deadlines/choice_scope.lua` | `turn/waits/choice_tracking.lua`, `turn/deadlines/choice_resolution.lua` | turn/ |
| ⑥ | `ui/screens/*.lua`, `ui/screens/registry.lua` | `ui/{coord,render,input,state,view}/…` | ui/ |
| ⑦ | — | `app/host_install.lua`（删 `app/host_integrations/skin_purchase.lua`） | app/ |

**硬冲突（同一文件被两候选写）= 0。** 唯二共享**目录**（非文件）：
- `turn/phases/`：③ 改 `{roll,registry,start}`，④ 改 `land` → **文件不相交**，worktree 合并无文本冲突。
- `turn/waits/`：④ 新建 `blocking`，⑤ 改 `choice_tracking` → **文件不相交**。

**软耦合（非文件冲突，但需留意）：**
1. **④⑤ 共用 `turn/` 测试面**（`spec/behavior/turn/*`、`turn_flow` 场景套）。文件可并行合并,但若合并态某 turn_flow 测试红,归因需两者一起看 → 建议同一 barrier 内一起验。
2. **③↔④ 都动 `turn/phases/`**（不同文件）。建议**不同波**执行,让 `turn/phases/` 不被两条 stream 同时编辑（纯保险,非硬性）。
3. **共享 spec-support**：见 Global Constraints 红线——任何 stream 若被迫改它,退出并行。

---

## 执行 DAG（推荐 2 波）

```
Wave 1  ├─ ⑦  app/            ─┐
(disjoint,│─ ②P2 rules/market/ ─┼─→ Barrier-1 (合并3流 → make verify && make acceptance)
 小核) └─ ③  turn/phases/roll… ─┘
                                    │
Wave 2  ├─ ④  turn/waits+phases/land ─┐
(turn 对 │─ ⑤  turn/deadlines+waits    ─┼─→ Barrier-2 (合并3流 → make verify && make acceptance)
 +ui)  └─ ⑥  ui/                     ─┘
                                    │
                                 Master join → push
```

**为何 2 波（而非一次 6 并发）：**
- Wave 1 三流分属 app/ / rules/market/ / turn/phases(roll,registry,start)——**完全不相交、都是小安全核**,先跑趟平 worktree+分派+合并流程。
- Wave 2 放 turn 对（④⑤,共用 turn 测试面,一起 barrier 便于归因）+ ⑥（ui/,独立,面最大）。把 ③（turn/phases）与 ④（turn/phases/land）分到不同波,`turn/phases/` 永不被并发编辑（软耦合 #2 的保险）。
- **可选 Wave-max**：因文件全不相交,有信心的操作者可一次并发全 6 条,收敛到单一 barrier。代价是合并批次大、turn_flow 若红归因难。**默认走 2 波。**

**各候选内部并行性**（来自各 plan 的「并行执行编排」节,编排层照搬）：
- ②P2：5 task 线性（settlement→adapter→auto→删 outcome+迁 spec→barrier）——**stream 内串行**。
- ③：Task1/2/3 fan-out（三文件）+Task4 barrier——**stream 内可再并行**（收益小,面小）。
- ④：建 blocking(串行前置)→land+tick_flow 并行→barrier。
- ⑤：建 choice_scope(串行前置)→两处委托并行→barrier。
- ⑥：registry seam 试点(串行)→player/secondary 屏并行→barrier。
- ⑦：pin→unwire→delete **硬串行**。

> 编排建议：**stream 之间并行**（worktree 隔离）拿主要收益;stream **内部**的再并行（③⑥的屏级 fan-out）按操作者算力与 concurrency cap 决定,非必须。

---

## Task 1：准备编排底座（分支 + worktree 约定）

**Files:** 无源码改动;建 worktree。

**Interfaces:** Produces：每条 stream 一个 `.worktrees/<stream>` 工作树 + `arch/<stream>` 分支,均从当前 `main`（`f1fe41cd` 之后）切出。

- [ ] **Step 1：确认基线干净**

Run: `git -C /Users/billyq/Dev/work/monopoly status --short && git rev-parse --short HEAD`
Expected: 空(clean) + 当前 HEAD（含全部 7 份 plan 文档）。

- [ ] **Step 2：为 Wave 1 三流建 worktree**

```bash
cd /Users/billyq/Dev/work/monopoly
for s in c7-skin c2p2-market c3-phasewait; do
  git worktree add ".worktrees/$s" -b "arch/$s"
done
git worktree list
```
Expected: 三个 worktree 列出,各在 `arch/*` 分支、HEAD 同 main。

- [ ] **Step 3：Commit（记录编排底座,可选)**

无源码变更;worktree/分支是本地态。跳过 commit,直接进 Wave 1。

---

## Task 2：Wave 1 fan-out —— ⑦ / ②P2 / ③ 并行执行

**Files:** 各 stream 在自己 worktree 改自己的文件（见冲突矩阵）。

**Interfaces:** Consumes：Task 1 的三个 worktree。Produces：三个 `arch/*` 分支各自绿 + 已 commit。

- [ ] **Step 1：分派三个 worktree-隔离 subagent（同一条消息 fan-out）**

给每个 subagent 的指令模板（替换 `<PLAN>` / `<WORKTREE>`）：

> 你在 worktree `<WORKTREE>`（已在 `arch/<stream>` 分支）执行实施计划 `docs/superpowers/plans/<PLAN>`。**只在这个 worktree 内工作**。逐 task 照 plan 执行：先跑 pin/失败测试,再改,每 task 结尾按 plan 跑 `make verify` 并 `git commit`。**不得编辑 `spec/support/scenario_suites/shared/`、`spec/support/shared_support.lua`、`tools/`**——若发现必须改,停下并在最终回复里上报「需退出并行」。全部 task 绿后返回：分支名 + 每 task 的 verify 结果 + 是否触发上报。

分派：
- ⑦ → `<WORKTREE>=.worktrees/c7-skin`，`<PLAN>=2026-07-08-candidate-7-skin-purchase-collapse.md`
- ②P2 → `<WORKTREE>=.worktrees/c2p2-market`，`<PLAN>=2026-07-08-candidate-2-phase2-settlement-leak.md`
- ③ → `<WORKTREE>=.worktrees/c3-phasewait`，`<PLAN>=2026-07-08-candidate-3-phase-wait-dedup.md`

- [ ] **Step 2：等三条 stream 全部返回「全绿 + 未触发上报」**

若任一 stream 上报「需退出并行」（撞共享 support 或发现计划与代码不符）：**暂停该 stream,单独串行处理**,其余两条继续。

- [ ] **Step 3：各 stream 自证（抽查,非替代其内部 gate）**

对每个 worktree：

Run: `git -C .worktrees/<stream> log --oneline main..HEAD && (cd .worktrees/<stream> && make verify 2>&1 | tail -2)`
Expected: 有该候选的 commit 链 + `[verify] PASS failed=0`。

---

## Task 3：Barrier-1 —— 合并 Wave 1 三流 + 合并态整仓门禁

**Files:** 合并到 `main`（或集成分支 `arch/integration`）。

**Interfaces:** Consumes：⑦/②P2/③ 三分支。Produces：合并态、整仓 `make verify` + `make acceptance` 双绿。

- [ ] **Step 1：合并三分支（不同文件,应无文本冲突）**

```bash
cd /Users/billyq/Dev/work/monopoly
git merge --no-ff arch/c7-skin arch/c2p2-market arch/c3-phasewait -m "merge: Wave 1 架构深化 —— ⑦皮肤折叠 + ②P2去泄漏 + ③微映射"
```
Expected: 干净合并（octopus 或逐个）。若报冲突 → 停,说明冲突矩阵有漏,人工核对该文件。

- [ ] **Step 2：合并态整仓门禁**

Run: `make verify`
Expected: `[verify] PASS failed=0`。**若红**：多半是跨 stream 语义交互（文件不冲突≠语义不交互）——按红的测试定位是哪两条 stream 的交界,回退最小一条重做。

- [ ] **Step 3：合并态验收**

Run: `make acceptance`
Expected: `RESULT: N ok`（`skin_shop`/`skin_persistence`/`market_cash`/`turn_flow` 均不回归）。

- [ ] **Step 4：清理 Wave 1 worktree**

```bash
git worktree remove .worktrees/c7-skin && git worktree remove .worktrees/c2p2-market && git worktree remove .worktrees/c3-phasewait
git branch -d arch/c7-skin arch/c2p2-market arch/c3-phasewait
```

- [ ] **Step 5：Commit（合并已是 commit;无额外改动）**

Barrier 若因红做了修正,`git commit` 修正;否则 Step 1 的 merge commit 即产物。

---

## Task 4：Wave 2 fan-out —— ④ / ⑤ / ⑥ 并行执行

**Files:** 各 stream 在自己 worktree 改自己的文件。

**Interfaces:** Consumes：Barrier-1 后的 `main`。Produces：三个 `arch/*` 分支各自绿 + 已 commit。

- [ ] **Step 1：从合并后 main 建 Wave 2 worktree**

```bash
cd /Users/billyq/Dev/work/monopoly
for s in c4-blocking c5-choicescope c6-uiscreens; do
  git worktree add ".worktrees/$s" -b "arch/$s"
done
```

- [ ] **Step 2：分派三个 worktree-隔离 subagent（同 Task 2 Step 1 模板）**

- ④ → `.worktrees/c4-blocking`，`2026-07-08-candidate-4-waits-blocking.md`
- ⑤ → `.worktrees/c5-choicescope`，`2026-07-08-candidate-5-pending-choice-lifecycle.md`
- ⑥ → `.worktrees/c6-uiscreens`，`2026-07-08-candidate-6-ui-screen-modules.md`

> **软耦合提醒（写进 ④⑤ subagent 指令）**：④ 与 ⑤ 都动 `turn/`,文件不相交但共用 `turn_flow` 测试面。各自 worktree 内 `make verify` 必绿方可返回;合并归因留给 Barrier-2。

- [ ] **Step 3：等三条 stream 全绿返回 + 抽查自证**（同 Task 2 Step 2-3）

Run: `for s in c4-blocking c5-choicescope c6-uiscreens; do echo "== $s =="; git -C .worktrees/$s log --oneline main..HEAD; (cd .worktrees/$s && make verify 2>&1 | tail -1); done`
Expected: 各分支有 commit 链 + verify PASS。

---

## Task 5：Barrier-2 —— 合并 Wave 2 三流 + 合并态门禁

**Files:** 合并到 `main`。

**Interfaces:** Consumes：④/⑤/⑥ 三分支。Produces：全 6 候选安全核心落地、整仓双绿。

- [ ] **Step 1：合并三分支**

```bash
cd /Users/billyq/Dev/work/monopoly
git merge --no-ff arch/c4-blocking arch/c5-choicescope arch/c6-uiscreens -m "merge: Wave 2 架构深化 —— ④阻塞判定 + ⑤choice scope + ⑥UI选择屏"
```
Expected: 干净合并。turn/waits/ 下 ④(blocking) 与 ⑤(choice_tracking) 不同文件,无冲突。

- [ ] **Step 2：合并态整仓门禁（重点看 turn_flow）**

Run: `make verify`
Expected: `[verify] PASS failed=0`。**若红且落在 `turn_flow`/`turn` 面**：④⑤ 语义交界（如 blocking 判定与 choice tracking 对同一 `game.turn.*` 的读写序）——按红测定位,必要时把 ④⑤ 改为串行（先合 ④、验绿、再合 ⑤）。

- [ ] **Step 3：合并态验收**

Run: `make acceptance`
Expected: `RESULT: N ok`。

- [ ] **Step 4：清理 worktree + 分支**

```bash
for s in c4-blocking c5-choicescope c6-uiscreens; do git worktree remove ".worktrees/$s" && git branch -d "arch/$s"; done
git worktree list
```

---

## Task 6：Master join —— 全量复核 + 推送

**Files:** 无改动;终局验证。

- [ ] **Step 1：全 6 候选安全核心在场性复核**

Run: `git log --oneline main | grep -iE "coin_settlement|purchase_result|purchase_settlement|phase_wait|blocking|choice_scope|screen|skin" | head -20`
Expected: 能看到 ①②③④⑤⑥⑦ 各自的落地 commit。

- [ ] **Step 2：终局整仓门禁 + 验收（合并态权威一跑）**

Run: `make verify && make acceptance`
Expected: 两者 PASS。

- [ ] **Step 3：deletion-test 全景复核（口头）**

逐候选确认其 plan 的 deletion-test 现成立：coin_settlement / purchase_result / purchase_settlement / phase_wait.resolve_result / waits.blocking / choice_scope / screen registry / skin 折叠——删任一深模块,复杂度在 N 个 caller 重新冒出。

- [ ] **Step 4：推送（若远端存在且用户确认）**

Run: `git push origin main`
Expected: 推送成功。**外向操作,执行前确认用户授权。**

---

## Risk Register

| 风险 | 触发 | 缓解 |
|---|---|---|
| 合并态语义交互（文件不冲突但运行时交界） | ④⑤ 对 `game.turn.*` 读写序；②P2 与 turn 的 choice 分发 | Barrier 的 `make verify` 是权威;红则该 Wave 内回退最小一条改串行 |
| stream 撞共享 spec-support | 某候选发现必须改 `scenario_suites/shared` | Global Constraints 红线:退出并行、串行该项 |
| 计划与代码漂移 | 某 plan 的 old→new 与真实代码对不上（评审后代码变过） | subagent 上报;编排层暂停该 stream,人工核 plan |
| worktree/index 争用 | 误在同一工作树并行 | 强制 worktree 隔离(Task 1) |
| ⑥ registry 循环 require | ⑥ Phase A seam | ⑥ plan 已含规避方案 + 门禁报环预案;⑥ 独立于其它 stream,失败不阻塞 Wave 2 的 ④⑤ |
| ③④ 同波 turn/phases 编辑 | 若走 Wave-max | 默认 2 波已把二者分开;走 Wave-max 时接受该保险失效 |

---

## 设计先行 Backlog（本计划范围外,需 brainstorming/codebase-design）

- ②「finish_choice 泄漏」的更深一步（若 P2 后仍有残留 shim）——P2 已覆盖主体。
- ③ 声明式 phase graph（分支 + wait 夹层结构）。
- ④ 跨 4 层 `game.turn.*` 裸读横扫（13 文件）→ 通用阻塞 seam。
- ⑤ pending choice 生命周期 deep module + 另 3 对孪生统一（owner 归一 / dispatch 通路）。
- ⑥ Phase C 大 canvas 面（market/skin_panel/item_atlas/item_slots/popup 各带 coordinator）。
- ⑦ legacy `_start_via_legacy_adapter` seam 拆除（被 cosmetics spec + skin_shop 验收钉,Level B）。

---

## Self-Review

**1. 覆盖：** 6 条待执行 stream（②P2/③/④/⑤/⑥/⑦）各有 Wave + barrier;①②P1 已完成标注;设计先行项显式移出范围。✅

**2. Placeholder 扫描：** 编排步骤给了确切 `git worktree` / `git merge` / `make verify` 命令与预期输出;task 级代码不重复（DRY,指向各候选 plan）。无 TODO/TBD。✅

**3. 一致性：** 冲突矩阵基于 `grep` 抽取的真实文件集 + `uniq -d` 验证零重复;波次划分与「各候选内部并行性」一致（stream 内串/并按各 plan）。turn/waits 软耦合在 ④⑤ 分派指令与 Barrier-2 都点到。✅

**已知局限（handoff 要说）：** ① 本计划假设各候选 plan 的 old→new 与当前代码仍吻合——若评审后代码漂移,stream 会上报,非本计划能预判;② 「文件不相交」保证无**文本**冲突,不保证无**语义**交互,故每 Barrier 的整仓 `make verify` 不可省;③ Wave-max 更快但放弃 ③④ 分波保险与小批次归因,仅在高信心下用。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-master-parallel-execution-plan.md`.

这是**程序级并行编排计划**,composes 6 份候选 plan。核心结论：**6 条剩余安全核心文件面两两不相交,可 worktree 隔离并行,唯需每波末整仓 barrier 兜语义交互**。

两种执行方式：
**1. 编排器驱动（推荐）** — 按 Wave 1 → Barrier-1 → Wave 2 → Barrier-2 → Master join;每波 fan-out 3 个 worktree-隔离 subagent,barrier 由编排层合并+整仓门禁。可用 `Workflow` 把「fan-out→join→barrier」写成脚本自动化。
**2. 保守串行** — 放弃并行,按 ⑦→②P2→③→④→⑤→⑥ 逐个 plan 执行,每个 merge 后 barrier。慢但归因最清。

选哪个？（若选并行,我可直接起 Wave 1 的三个 worktree-隔离 subagent。）
