---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-30
---
# ADR 0015 — Acceptance 生成物不再版本控制，入口重生成

**Status**: Stable (2026-05-30；`make acceptance` 冷路径实证 531 ok，重生成 byte-identical)
**Trigger**: specifier 路由（用户指示，handoff `acceptance-generated-vcs`）——`tools/acceptance/generated/*`（22 个 busted 验收 spec、~812KB）继续 track 还是改为 gitignore + 入口重生成。多周期反复出现「生成物陈旧 → 新场景静默不跑」的漂移 bug。
**Related**: [ADR 0009](0009-acceptance-pipeline-spec-alignment.md)（规约层差分突变 / stamp / manifest）、[ADR 0004](0004-differential-mutation-testing.md)（源代码层 mutate4lua）、`tools/acceptance/run_acceptance.lua`、`memory/project_acceptance_pipeline_spec_gap.md`

---

## 上下文（Why）

`tools/acceptance/generated/*` 是纯生成物：`.feature` → `acceptance4lua` parser → generator → 内嵌 `embedded_ir` 的 busted spec。CLAUDE.md 明令不可手改、从 feature/generator 源头更新——完全可确定性重新派生。

但 `busted --run acceptance`（`.busted` profile `acceptance` 的 ROOT = `tools/acceptance/generated`）**直接消费已提交文件，运行时不重生成**。后果是一整类漂移 bug：每次改 feature 都要人手补一次「重生成」提交，漏掉就 = 生成物陈旧 = 新场景**静默不跑**（验收计数看着正常）。本仓最近多个周期反复踩此坑（skin_shop / skin_persistence 新场景在生成物重生成前不计入验收）。

关键事实：
- `make verify`（smoke + full）**不跑 acceptance lane**，generated 目录与 verify 无关。
- 单 feature 开发已有 `tools/acceptance/run_acceptance.lua` 即时 parse+generate+run——确定性重生成路径已存在、可复用。
- 没有任何阻塞式「生成物 vs feature」漂移守卫存在（所以陈旧才会静默）。

## 决策（What）

**D1 — `tools/acceptance/generated/` 改为 gitignore + 入口重生成。**

生成物是 build 输出，不是真相源。真相源 = `features/*.feature` + step handlers。删除已提交生成物，入口前确定性重生成。消灭整类「生成物陈旧」漂移 bug + ~812KB + 高 churn（skin_shop 单次重生成曾 = 1725 行 diff）+ 合并冲突面。

**D2 — 入口 = `make acceptance`。**

```makefile
acceptance:
	lua tools/acceptance/regenerate.lua   # features -> tools/acceptance/generated/
	busted --run acceptance               # ROOT 不变，消费刚重生成的文件
```

`make` 目标声明 `.PHONY`（否则 root 的 `acceptance/` 目录让 make 误判 up-to-date）。`.busted` 的 acceptance ROOT **不变**（仍 `tools/acceptance/generated`），重生成原地填充，最小化改动面。**裸 `busted --run acceptance` 不再开箱即用**（fresh checkout 该目录为空）——这是入口契约的有意改变，所有文档/agent 验收命令改用 `make acceptance`。

**D3 — 重生成 = 显式 registry，非派生命名。**

`tools/acceptance/acceptance_features.lua` 声明 22 条 `{feature, generated}` 映射，是验收套件**范围**的真相源（取代「已提交文件集合」这个隐式范围）。命名非统一（多数 `<basename>_acceptance_spec.lua`，但 `chinese_gherkin_acceptance.feature` → `chinese_gherkin_acceptance_spec.lua`），故显式登记而非 naive transform。`tools/acceptance/regenerate.lua` 读 registry，逐条 `gherkin_parser.write_json_file` → `generator.generate_file`，JSON IR 落 gitignored 的 `build/acceptance/`。确定性已实证：重生成对已提交版 byte-identical（0 文件 diff）。

**D4 — ADR 0009 的 stamp/manifest 机制不受影响（澄清 specifier 假设）。**

specifier 路由文档假设此举可能让 `feature_stamp`/`spec_hash` 漂移守卫「失去存在理由」。**核实后纠正**：ADR 0009 的 `# mutation-stamp:` + `# acceptance-mutation-manifest` 是**规约层差分突变**机制（`gherkin-mutator` 跳过未变 feature 用），内嵌在 `.feature` 文件里、且 `.feature` 仍 track。它**不是**「生成物 vs feature」漂移守卫——这类守卫从不存在（所以陈旧才静默）。gitignore 生成物**不触及** ADR 0009，stamp/manifest 照常工作。

**D5 — 突变两层均不受影响。**

- 规约层（ADR 0009）：Gherkin example 突变作用于 `.feature`，stamp/manifest 内嵌 `.feature`，非 generated。
- 源代码层（ADR 0004）：mutate4lua 作用于 `src/*.lua`，manifest 内嵌 src footer，非 generated。
- 生成物的 `metadata/`（generator 的 `generated_files` implementation_hash，ADR 0009 Addendum 2026-05-27）本就已 gitignore，重生成时一并产出。

## 后果（Consequences）

**正向**：
- 消灭整类「生成物陈旧 → 新场景静默不跑」漂移 bug，单一真相源 = `.feature`。
- 去 ~812KB + 高 churn + 合并冲突面 + 人手「重生成」提交。
- 验收套件范围从隐式（文件集合）升级为显式 registry。

**代价 / 契约变更**：
- 裸 `busted --run acceptance` 不再开箱即用，必须先重生成；统一入口 `make acceptance`。文档/CLAUDE.md/verify skill 已同步。
- fresh checkout / CI 复现依赖 `acceptance4lua` 子模块（已 init）+ 一次重生成（全 22 feature ~数秒）。

**风险**：
- agent / CI 仍跑裸 `busted --run acceptance` 会得到空套件假绿——靠文档 + `make acceptance` 收敛；后续若需可加「ROOT 为空即 fail」哨兵。
- 新 feature 入验收套件需在 registry 加一行（否则不跑）——显式但需记得；registry 注释已说明。

## 验证结果

| 项 | 结果 |
|---|---|
| `make acceptance` 冷路径（先删生成物） | 重生成 22 → `busted --run acceptance` 531 ok · 0 FAIL · 0 error ✅ |
| 重生成 vs 旧已提交生成物 | byte-identical（0 文件 diff）✅ |
| `make verify`（full） | 不含 acceptance lane，不受影响 ✅ |
