# 改进路线图（架构与目录层级）— monopoly

> 评审快照：`6e473b0`（2026-01-15）  
> 原则：遵循仓库 `AGENTS.md`（功能不变、优先删除/复用、避免无调用点抽象、每步改完自测）。

## 0. 路线图目标与验收口径

目标不是“推翻重构”，而是用**小步、可验证**的方式让下面三件事同时成立：

1. **读者可理解**：目录职责与依赖方向一眼明白（新同学能在 30 分钟内跑通）。
2. **规则可复现**：同 seed + 同 action 序列 ⇒ 同结果（回归/排错更可靠）。
3. **依赖可守护**：依赖规则难被绕过，CI 可阻断倒灌。

每个阶段的验收都应至少跑：

- `lua tests/deps_check.lua`
- `lua tests/regression.lua`

（如果本地有 `luac`，额外建议跑 `luac -p` 做语法检查。）

## 1. P0（当天可完成）：文档/脚本路径“止血”

### 1.1 修正 README 与文档漂移

**问题对应**

- `README.md` 中的 `src/app.lua`、`lua scripts/*` 与仓库实际不一致。
- `docs/eggy/eggy-migration-roadmap.zh-CN.md` 仍写 `src/app.lua` 作为规则层入口。

**建议动作（择一或组合）**

- A) 只改文档：统一把命令与文件引用改为 `tests/*`、`src/game.lua`、`src/gameplay/app/bootstrap/init.lua`，并同步修正 `docs/eggy/eggy-migration-roadmap.zh-CN.md` 的 `src/app.lua`。
- B) 保留旧路径兼容：新增 `scripts/deps_check.lua` 与 `scripts/regression.lua` 作为“薄入口”，内部直接 `dofile("tests/xxx.lua")`（仅当你确实需要兼容旧文档/旧 CI）。

**验收**

- README 的所有命令在仓库根目录可直接运行并成功。
- 文档引用的文件在仓库中真实存在。

## 2. P1（低风险可渐进）：强化依赖守护（DIP 的“护栏”）

### 2.1 让 `deps_check` 更难被绕过

**现状**

- `tests/deps_check.lua` 已把模块名映射为路径并检查 `dofile/loadfile`，但仍依赖字符串扫描，且只匹配 `src/` 前缀。

**建议动作（增量增强，保持简单）**

- 把 `require("adapters.*")` 这类无 `src.` 前缀的模块名归一到 `src/` 目录下再判断，减少绕过空间。
- 对明显的动态拼接 `require` 保持告警（至少提示“可能绕过规则”）。

**验收**

- `deps_check` 仍是纯 Lua、无需额外依赖。
- 新增一两个“故意违规”的临时分支能被脚本抓到（验证后撤回临时代码），例如 `require("adapters.love2d...")`。

### 2.2 明确“允许依赖”的白名单

**现状**

- `tests/deps_check.lua` 顶部已明确列出允许依赖方向。

**建议动作**

- README 改为引用该处规则，避免重复维护与漂移。

**验收**

- 规则描述与实际脚本一致，避免“文档说一套、脚本跑另一套”。

## 3. P2（中等改动，收益高）：收敛“状态单一来源”（Store vs 运行态）

> 目标：把“可存档/可复现”的叙述变成事实；减少“两套状态并存”的理解成本。

### 3.1 明确 overlays 的归属（Store 还是 Board）

**现状**

- store 初始化包含 `board.overlays`，但运行时主要写 `Board.overlays`；UI 展示也优先读 runtime。

**建议决策（必须先选一个方向）**

- 方向 A（推荐，符合可存档）：把 overlays 也写入 store，Board 只做读写代理或缓存。
- 方向 B（接受非存档）：从 store 初始化里移除 overlays，明确 overlays 是运行态派生/不保证持久化（并同步更新文档叙述）。

**验收**

- 选定方向后：同一份状态在“读取路径”上只有一个权威来源（避免 runtime/store 互相打架）。

### 3.2 去掉 Tile 的“重复状态字段”或补齐同步

**现状**

- 运行态 tile 状态以 store 为准（`Tile.get_state`），但 `Tile` 结构体仍保留 `owner_id/level` 与依赖其字段的方法。

**建议动作（按最小改动）**

- 若确认这些字段/方法没有调用点：删除或内聚到真正使用 store 的实现（优先删）。
- 若未来确实需要：把方法改为显式接收 `game/store` 或 `tile_state`，不要读 `tile.owner_id/tile.level`（避免双源）。

**验收**

- `rg` 搜索不再出现“读 tile.owner_id/tile.level”与“读 store tile state”两种并行写法。

## 4. P3（可选，分期）：减少“并行小状态机键”，复用 Choice

### 4.1 收敛 `turn.*_prompt` 键

**现状**

- `rent_prompt/tax_prompt/market_prompt/post_action` 等键与 `pending_choice` 并存，且由 domain/app 多处共同维护。

**建议动作（渐进）**

- 把 prompt 的“决策结果”直接写入 `pending_choice.meta` 或由 `ChoiceResolver` 执行“继续逻辑”，减少依赖“再次进入同一个 effect 读取 turn.* 键”的模式。
- 保持行为不变：仍然是“需要选择则挂起，不选择不推进”。

**验收**

- `turn` 域里的临时键数量减少，且每个键的生命周期由单一模块维护。

## 5. P4（长期）：定义更清晰的“组合根（Composition Root）”

**现状**

- `src/game.lua` 同时承担“装配 + 领域写操作 + 流程驱动入口”，职责偏重。

**建议动作**

- 不要新增大层/大抽象；优先做“搬家与删冗余”：
  - 把装配相关逻辑尽量收敛到 `src/gameplay/app/bootstrap/*` 或一个明确的“装配文件”（是否叫 `app.lua` 由你决定，但要与 README 一致）。
  - `Game` 保持为“运行时门面”，减少与装配强耦合的细节代码。

**验收**

- 读 `main.lua` 能清楚看到：入口装配在哪里、UI 适配层在哪里、规则推进从哪里开始。

---

## 附：推荐的执行顺序（最小阻力）

1) P0 文档止血（马上提升可读性）  
2) P1 加固 deps_check（马上提升“可守护性”）  
3) P2 选定 overlays/Tile 的单一来源策略（提升“可存档/可复现可信度”）  
4) 其余项按需求推进（迁移蛋仔/扩规则时再做 P3/P4）
