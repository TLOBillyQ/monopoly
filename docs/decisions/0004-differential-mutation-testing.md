---
kind: adr
status: accepted
owner: architecture
last_verified: 2026-05-22
---
# ADR 0004 — Differential Mutation Testing 范围与契约

**Status**: Proposed (2026-05-21, 等待 specifier 写 Gherkin + 用户确认)
**Trigger**: specifier 50-differential-mutation-testing-design.md
**Related**: `vendor/mutate4lua` @ `75d4203`, `docs/guides/mutation-testing.md`, `tools/quality/mutate.lua`

---

## 上下文（Why）

specifier 把"per-function manifest 跳过未变更函数"作为**新 feature** 提交设计请求。
但 vendored `mutate4lua` 在 2026-05 已经实装了：

- `--[[ mutate4lua-manifest ... ]]` 文件尾 manifest 块（`internal/manifest.lua`）
- FNV-1a 64-bit token-normalized hash（`util.fnv1a64` + `scanner.build_scopes`）
- AST/lexer-based function + chunk scope 划分（`internal/scanner.lua`）
- Differential-by-default + `--mutate-all` 覆盖开关（`engine._changed_scope_lookup`）
- `--update-manifest` 显式重写子命令
- Pass-only 写入策略：有 survived/timeout 不刷 manifest

并已在 `src/rules/market/effects.lua` 落地一份 `version=1` manifest 尾。

因此本 ADR 不是设计新 feature，而是**确认已存在契约 + 关闭真实缺口 + 锁定边界**，
为 specifier 写 Gherkin acceptance 提供基线。

---

## 决策（What）

### D1 — 不重新设计，复用上游实现

放弃 specifier 列出的 9 个"选型"问题；上游已用以下方式回答：

| 维度 | 既定答案 | 证据 |
|---|---|---|
| Manifest 语法 | `key=value`，scope.N.field=value，文件尾 `--[[ mutate4lua-manifest ... ]]` 块 | `internal/manifest.lua` |
| Hash 算法 | FNV-1a 64-bit，token-stream（空格/注释/格式已被规范化掉） | `util.fnv1a64`, `scanner.build_scopes:144` |
| 函数边界 | Lexer + 块栈，覆盖 `function` / `local function` / `M.foo = function` / `function M.foo` / `M:foo` / 匿名（`anonymous@<line>`）+ 顶层 `chunk:<file>` 兜底 | `internal/scanner.lua:86-148` |
| Hash 输入归一化 | Token 值串接，单空格分隔；不归一化原文 | 同上 |
| 写入策略 | 仅当 lane 全 kill（survived=0 且 timeout=0）且未使用 `--lines` 时刷 manifest；显式 `--update-manifest` 始终刷 | `engine._write_manifest_update` |
| 边界 - 新增函数 | hash 不匹配 → 必 mutate | `_changed_scope_lookup` |
| 边界 - 删除函数 | 仅遍历当前 scope，静默丢失旧 entry，无 warn | `_build_manifest_scopes` |
| 边界 - 模块顶层 | 作为 `chunk:<relative_file>` scope 与 function 同等对待 | `scanner.build_scopes:87-96` |
| CLI 默认 | `mutate <file>` 即差分；`--mutate-all` 显式全量；无 `--check` 验证模式 | `cli._parse_args` |
| lint/CRAP/encoding/dry 冲突 | 无 — 没有质量工具特殊解析文件尾或块注释（已 grep 验证） | `tools/quality/{lint,crap,encoding,dry}.lua` |

### D2 — 用户三条范围锁照旧

- 仅源码变异 pipeline（不动 Gherkin mutator）
- Manifest 写文件尾，不开 sidecar
- 改上游 `vendor/mutate4lua` + bump submodule，不在项目侧加 wrapper

### D3 — 三个真实缺口需要单独解决

**G1（必做）** 上游无测试套件。 *Update 2026-05-23: 已闭环*。`vendor/mutate4lua` 当前 gitlink `e960131` 携带 `spec: restore busted suite covering manifest/scanner/engine`——36 个 busted case 覆盖 manifest round-trip / scanner / engine 三件套，本地复测 36/36 PASS（0.43s）。原架构师对"上游差分逻辑无测试兜底"的担忧解除。
`vendor/mutate4lua` 历史提交 `1e53719 cleanup: remove docs, tests, build + add
manifest v2 scope tracking` 删除了上游 spec。引入差分逻辑后没有 round-trip /
scope-stability / migration 测试托底，任何 engine 改动都是裸奔。

**行动**：specifier 写一份 Gherkin 锁定下方契约（D5）；同时建议在
`vendor/mutate4lua/spec/` 恢复一套 busted spec（最小集见 D5），由 coder 推到上游。

**G2（必做）** README + `docs/guides/mutation-testing.md` 漂移。
上游 README 仍提 `make test` 和已被删除的差分 mutation flag（vendor
`aaea942` 后语义改为默认按 manifest 跳过未修改 scope，无需显式 flag）；
项目侧 guide `docs/guides/mutation-testing.md` 历史亦引用该 flag。

**行动**：coder 一次 PR 同步两边文档；与 G1 解耦，可并行。

**G3（必做）** Bootstrap rollout 策略。
目前只有 `src/rules/market/effects.lua` 有 manifest，其余文件首次 mutate 仍要付
全量代价。建议加一个 `tools/quality/mutate.lua --bootstrap-all` 或独立脚本，遍历
`src/` 调 `engine.update_manifest` 一次性写入，顺手把 effects.lua 的 v1 升 v2。

**行动**：specifier 写 spec → coder 实现 → 一次性 commit 全部 manifest。

**Addendum (2026-05-23)**: `tools/quality/mutate_bootstrap.lua` 已落地、commit
`f4bb6356` 给 349 个 src 文件批量写了 manifest 尾块。但 bootstrap 走的是
"读 AST → 算 hash → 追加 manifest"路径，**不跑 mutation 测试**。差分模式的
"hash 匹配则跳过"规则默认 hash 是**全 kill 验证的副产物**——bootstrap 出来
的 hash 满足匹配但没经过验证。结果：bootstrap 之后的文件，首次差分 mutate
显示 "no mutation sites" 不代表覆盖，只代表"hash 还没漂"。

2026-05-23 抽样 8 个 acceptance-coupled src 文件 `--mutate-all`，全部出 survivor：

| File | total | survived | kill rate |
|---|---|---|---|
| src/foundation/log.lua | 183 | 43 | 76.5% |
| src/foundation/number.lua | 80 | 17 | 78.8% |
| src/foundation/ports/runtime_ports.lua | 40 | 15 | 62.5% |
| src/turn/phases/roll.lua | 47 | 5 | 89.4% |
| src/rules/items/inventory.lua | 54 | 11 | 79.6% |
| src/ui/coord/item_atlas.lua | 69 | 4 | 94.2% |
| src/ui/coord/skin_panel.lua | 136 | 11 | 91.9% |
| src/ui/input/dispatch/view_command.lua | 127 | 59 | 53.5% |

165 个 mutant 被差分模式假装"已覆盖"。

**工作流铁律（落到 `docs/guides/mutation-testing.md` 的"Bootstrap 不等于覆盖证明"）**：
bootstrap 写过 manifest 的文件，首次纳入差分流水前必须 `--mutate-all` 一遍；
全 kill 自动写回 verified manifest，有 survivor 走 busted spec 闭杀直到全 kill。

不修代码（不改 mutate_bootstrap.lua 或 mutate4lua 的 manifest 语义），靠工作流
铁律 + 文档约束。理由：D1 保留上游 manifest 写策略不变，D4 N1 保留 "survived
不写 manifest"，新增 verified=true/false 状态机的杠杆 < 文档化的杠杆。

### D4 — 两个边界明确**不解决**

**N1** 失败 mutation 不进 manifest。
Survived/timeout 不写 manifest 是当前契约，**保留**。manifest 是 pass-record，
不是状态机。survived 信息由 `--json` 输出和 CI artifact 承载，不混进文件尾。

**N2** Hash 仅对源码、不感知 spec。
`spec/foo_spec.lua` 变强而 `src/foo.lua` 不变时差分跳过它。**保留当前契约**。
替代方案（把 spec 集合 hash 进 scope hash）会让 spec helper 改动触发全仓
re-mutate，代价远大于收益。文档化即可，由后续手动 deep sweep 兜底（D6）。

### D5 — Specifier 需写的最小 Gherkin 集（差分契约锁定）

1. **Round-trip**：`--update-manifest` 后立刻 `mutate`，零变异，manifest 不变。
2. **空白编辑**：reformat / 加空行 → 下次 mutate 仍跳过（token-stream 不变）。
3. **语义编辑**：改 scope S 内一个 `==` 为 `~=` → 只重测 S，其他 scope 跳过。
4. **`--mutate-all`**：完全忽略 manifest，全 scope 变异。
5. **Survived 不刷**：mutation lane 有一个 survived → manifest 字节级不变。
6. **删除函数**：从 src/X.lua 删 F → 通过的 pass-write 不再含 F 的 entry。
7. **新增函数**：在 src/X.lua 加 G → mutate 包含 G 的 sites；pass 后 manifest 含 G。
8. **`--lines` 不刷**：`mutate --lines 12` 无论 pass/fail 都不动 manifest。
9. **v1 → v2 迁移**：在 `src/rules/market/effects.lua`（当前 v1）上 pass 后，
   文件尾改写为 v2 且语义保留（scope.id / scope.semanticHash 不变）。

边界用例（specifier 可选裁剪）：损坏 manifest body、未知 version 号、
manifest 与源码 scope 数量不对齐时的恢复策略。

### D6 — 周期性 full sweep 维持人工触发

不引入 CI cron。差分跳过偶有 false negative（hash 碰撞 / 上游 engine bug /
spec-only 改动）是已接受的代价，发版前手工 `--mutate-all` deep sweep 即可。
源码增长到 `src/` Lua 文件 > 50 时再评估自动化。

---

## 后果（Consequences）

**正向**：
- specifier 直接对**既存契约**写 Gherkin，不再从 0 选型
- 上游引入的 differential 行为有锁，下次 engine 改动有回归基线
- 文档对齐后，用户读到的 CLI flag 集合与实际可用集合一致
- Bootstrap 一次性写入后，CI 首次跑某文件就是差分模式

**代价**：
- 上游 spec 补回（G1）是非零工作，coder 需要熟悉 mutate4lua 内部
- `--bootstrap-all` 会产生一次大体量 manifest commit（数十文件尾追加），review 噪声
- 选择不感知 spec 变化（N2）后，团队需明白 "改 spec 不会自动触发 mutation 复跑"

---

## 相关任务

- specifier：基于 D5 写 Gherkin acceptance（feature: differential mutation testing）
- coder：执行 G1（恢复上游 spec）+ G2（同步文档）+ G3（bootstrap 脚本）
- 用户：拍 D4 的两条**不解决**项是否接受
