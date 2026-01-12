# 代码库层级结构审查与迁移计划（`src/`）

日期：2026-01-12

> 目标：审查当前代码库的层级结构，指出不合理点，并给出一个可分阶段落地、低风险的迁移计划。
>
> 范围：`src/`、`main.lua`、`scripts/deps_check.lua`、`scripts/regression.lua`。
>
> 约束：优先以“结构与可维护性”为目标，不改玩法与交互语义。

---

## 0. TL;DR（结论摘要）

- 当前 `src/` 已具备“规则层（`src/gameplay`）与 UI 适配（`src/adapters/love2d`）隔离”的雏形，并且已有 `scripts/deps_check.lua` 作为约束工具；这是一个很好的基础。
- 主要结构风险集中在 **层级边界不够清晰** 与 **命名/归属不一致**：
	- `src/gameplay/domain/*` 出现了对 `src/gameplay/app/*`（Choice/Resolver）的直接依赖，导致 domain 不再是纯规则层。
	- `src/gameplay/domain/chance.lua` 通过 `require("src.gameplay.app.landing_resolver")` 反向依赖应用编排层，容易形成“胶水逻辑散落”。
	- `Store` 目前更像“给 UI / choice 用的快照”，并非单一事实来源（SoT）；`App` 同时维护了对象态（`board/players/rng`）与 store 快照（`store.state`），存在漂移风险。
- 迁移计划建议以“**小步 PR + 兼容 shim**”推进：先把 domain 对 app 的依赖切断（不改玩法），再把 store 从“快照”逐步扶正为“单一事实来源”。

---

## 1. 现状概览：目录分层与职责

以当前仓库为准（`rewrite2` 分支）。

### 1.1 目录结构（摘要）

```text
src/
	app.lua
	adapters/
		love2d/
			love_layer.lua
			board_renderer.lua
			panel_renderer.lua
			modal.lua
			ui_state.lua
			...
	bootstrap/
		board_factory.lua
	config/
		constants.lua
		map.lua
		tiles.lua
		chance_cards.lua
		items.lua
		roles.lua
	core/
		board.lua
		tile.lua
		player.lua
		dice.lua
		inventory.lua
	gameplay/
		ui.lua
		app/
			flow.lua
			landing_resolver.lua
			choice.lua
			choice_resolver.lua
			services/
			turn/
		domain/
			effect.lua
			landing.lua
			land.lua
			chance.lua
			item.lua
		infra/
			rng.lua
			store.lua
			sync.lua
	util/
		logger.lua
		random.lua
```

### 1.2 入口与组合（Composition Root）

- `main.lua`：设置 `package.path`，创建 `App`，并挂载 `src.adapters.love2d.love_layer`。
- `src/app.lua`：构建 `board/players/rng/store/services`，并创建 `TurnManager`；属于“组合根 + 运行时聚合对象（game）”。

### 1.3 已有的边界约束（很重要）

`scripts/deps_check.lua` 当前约束：

- `src/gameplay/**` 不能 `require("src.adapters.*")`（规则层不直接依赖 UI 适配器）。
- `src/gameplay/app/services/**` 之间不能互相 `require`（避免 service 形成网状依赖，改用 `game.services.*`）。

这两条规则是后续迁移落地的“护栏”，建议继续扩展而不是废弃。

---

## 2. 结构审查：问题清单（按优先级）

### P0：domain 反向依赖 app（边界破坏）

现象（示例）：

- `src/gameplay/domain/item.lua` 直接 `require("src.gameplay.app.choice")`，并在道具效果中打开选择（例如导弹卡选择目标格）。
- `src/gameplay/domain/chance.lua` 为了“移动后触发落地结算”，通过 `get_landing_resolver()` 动态 `require("src.gameplay.app.landing_resolver")`。

风险：

- domain 层失去“纯规则”属性，测试与复用成本上升（domain 需要 app/choice/store 才能运行）。
- 应用编排逻辑（如何等待 UI、如何恢复流程）散落在 domain 中，后续引入更多交互点会迅速扩散。

建议方向：

- `domain` 只产出“规则决定/结果（decision/result）”，由 `app` 负责把结果转成 choice（打开 UI、等待输入、恢复状态机）。
- 需要 UI 的地方引入“端口（port）”/回调，但端口应定义在 domain 或 domain 上层的稳定边界，而实现留在 adapter。

### P0：Store 不是单一事实来源（SoT），状态可能漂移

现状：

- `game` 同时维护对象态：`game.board`（Tile 对象数组）、`game.players`（Player 对象）、`game.rng`（可变 state）。
- `game.store` 维护一份快照态：`turn.pending_choice/phase/choice_seq` 等用于流程与 UI；`board.tiles/players/rng` 也会快照写入，但依赖 `game:commit_state()` 这种手动同步。

风险：

- UI 读取的数据来源不统一（有的读 `game.players`，有的读 `store`），未来读档/回放/断线恢复会难做。
- “快照忘记更新”会产生隐性 bug（逻辑正确但 UI/choice 元信息不一致）。

建议方向：

- 明确路线：要么承认 `store` 只是“UI/回放辅助快照”，那就把写入点集中并做自动化；
- 更推荐：逐步把 `store` 扶正为 SoT：规则更新写 store，渲染/适配从 store 同步（`sync_all` + 差量事件）。

### P1：`src/gameplay/ui.lua` 命名误导（但设计思路正确）

`src/gameplay/ui.lua` 实际是“UI 端口封装”（`ui_hooks.push_popup/request_choice`），属于 DIP 中的 port。

问题在于：

- 文件名叫 `ui.lua` 容易让人误以为“规则层依赖 UI”。

建议方向：

- 迁移到 `src/gameplay/ports/ui_port.lua`（或 `src/ports/ui.lua`），并保留旧路径的 shim 导出，避免一次性改全仓 require。

### P1：模块命名空间与 `package.path` 约定需要固化

当前几乎所有 require 都使用 `require("src....")`，并依赖 `package.path` 中的 `?.lua`。

建议：

- 在文档与脚本中明确“模块命名约定”：统一使用 `src.` 前缀；
- 后续若要迁移为无前缀（`require("gameplay...")`），应视为独立迁移项（不建议与结构迁移混在同一阶段）。

### P2：`core/` 与 `gameplay/domain/` 的边界需更清晰

当前：

- `core` 含 `board/tile/player/dice/inventory`（偏“运行时实体 + 数据结构”）。
- `gameplay/domain` 含 effect/landing/land/chance/item（偏“规则动作/结算”）。

建议：

- `core` 作为“通用领域模型与算法”应尽量不依赖 `gameplay/app`；
- `gameplay/domain` 作为“规则集合”应只依赖 `core` + `config` + `ports`（而不是依赖 `app` 的 choice/resolver）。

---

## 3. 目标结构（迁移后理想边界）

这里的“目标结构”尽量不推翻现有目录，而是补齐边界，让代码可持续增长。

### 3.1 建议的分层（语义层）

- **Entry / Composition Root**：创建 game、注入依赖、绑定 adapter
	- `main.lua`、`src/app.lua`、`src/bootstrap/*`
- **Gameplay App（编排层）**：状态机/回合流程/choice 生命周期/服务编排
	- `src/gameplay/app/*`
- **Gameplay Domain（规则层）**：effect/结算/规则判断与执行（不直接打开 UI，不直接依赖 app）
	- `src/gameplay/domain/*`
- **Ports（接口层/依赖倒置点）**：UI、日志、时间、存档等
	- `src/gameplay/ports/*`（推荐新增）
- **Adapters（实现层）**：Love2D UI、输入、渲染、自动运行
	- `src/adapters/love2d/*`
- **Infra（基础设施）**：store/rng/sync（可在 `src/gameplay/infra` 保持不动，也可上提到 `src/infra`）
	- `src/gameplay/infra/*`

### 3.2 依赖规则（硬性）

- `gameplay/domain` 只能依赖：`core`、`config`、`util`、`gameplay/ports`、`gameplay/infra`（如确有需要）
- `gameplay/app` 可以依赖：`gameplay/domain`、`gameplay/infra`、`gameplay/ports`、`core`、`util`
- `adapters/love2d` 可以依赖：`gameplay/ports`（实现 hooks）、读取 `store` 做展示；不反向被 `gameplay/*` require

> 这能把“可测试的规则”与“不可避免的 UI 复杂度”隔离。

---

## 4. 分阶段迁移计划（小步、可回滚、不改玩法）

### 总体策略

- 每个阶段都必须保证：`scripts/deps_check.lua` 通过，`scripts/regression.lua` 通过。
- 采用“**兼容 shim 文件**”降低 require 大规模改动风险：
	- 旧路径文件保留 1～2 个版本，内部只 `return require("new.path")`。
	- 等全仓更新完成再删除 shim。

### Phase 0（0.5～1 天）：把规则写进工具与文档

目标：迁移不动代码逻辑，只增加护栏。

- 在 `docs/reviews/structure-review-and-migration-plan.zh-CN.md` 固化：目标边界、目录职责、PR 自查清单（本文件完成后即达成）。
- 扩展 `scripts/deps_check.lua`：新增一条（建议）
	- `src/gameplay/domain/**` 不允许 require `src.gameplay.app.*`

验收：

- `lua scripts/deps_check.lua`
- `lua scripts/regression.lua`

### Phase 1（1～2 天）：切断 domain → app 的直接依赖（不改玩法）

目标：让 `src/gameplay/domain/*` 回到“纯规则/纯动作定义”，choice 由 app 层统一负责。

建议落地方式（两种择一，优先 A）：

- A) **domain 返回“意图（intent）”**
	- 例：`ItemEffects.use_missile(...)` 不再 `Choice.open`，而是返回 `{ kind="need_choice", choice_spec=... }`
	- `ItemService`/`ChoiceResolver` 在 app 层把 intent 转成 `Choice.open`。
- B) **domain 接收 chooser 回调**
	- 例：`use_missile(game, player, distance, choose_target_fn)`，由 app 层传入一个函数决定 target。
	- UI 开启与等待仍在 app。

同时处理：

- `ChanceEffects` 中 `move_forward/move_backward` 不应直接调用 `LandingResolver`；改由 app 层（例如 `LandingResolver` 或 `Turn` 脚本）把“移动 + 落地”串起来。

验收：

- `scripts/deps_check.lua` 新增规则后仍通过
- `scripts/regression.lua` 行为不变

### Phase 2（2～4 天）：明确 Store 的角色，并统一读写路径

目标：减少“双状态源（对象态 + store）”的漂移风险。

推荐路线（渐进式）：

- 先把所有与流程相关的数据（phase、pending_choice、choice_seq、turn_count、current_player_index）完全收敛到 store。
- 对 `board/players/rng`：
	- 要么明确为“只读快照给 UI/回放”（并把 `commit_state()` 的调用点收敛到 Turn 末尾/关键事件），
	- 要么逐步把规则写入 store（最终 SoT）。

本阶段的“结构性改造”重点是：

- 把 store 写入点集中（例如集中在 `TurnManager` 或每个 phase 结束时），避免散落。
- `sync_all` 的职责写清楚：
	- 读档/重建时全量对齐 UI
	- 正常推进时可做差量（可选）

验收：

- UI 展示与 choice 元信息不漂移（重点覆盖：落地可选项、导弹选择、自动播放）
- `scripts/regression.lua` 覆盖用例全部通过

### Phase 3（可选，按需要）：目录/命名收敛与长期治理

目标：把“概念上的边界”变成“目录上的边界”。

- 新增 `src/gameplay/ports/` 并迁移：
	- `src/gameplay/ui.lua` → `src/gameplay/ports/ui_port.lua`（保留 shim）
- 若决定上提 infra：
	- `src/gameplay/infra/*` → `src/infra/*`（保留 shim）
- 清理文档与工具中的陈旧路径（例如若存在 `src/visual/*` 的历史表述，统一为 `src/adapters/love2d/*`）

验收：

- deps_check 规则与目录一致
- 新同事按目录即可理解边界（无需读大量代码才能判断依赖是否合法）

---

## 5. 风险、回滚与验收

### 5.1 主要风险

- require 路径改动导致运行时找不到模块（Lua 在运行时才报错）。
- domain/app 拆分时把“等待 UI 的语义”改坏（例如本来应该等待，但自动处理了/或者反过来）。
- store 与对象态同步点改动导致 UI 显示与逻辑不一致。

### 5.2 风险控制手段（推荐）

- 所有“路径迁移”都保留 shim：旧模块文件仅一行 `return require("new.path")`。
- 每个阶段至少补一条 regression 用例（只要覆盖本次改动的边界即可）。
- 每次 PR 必跑：
	- `lua scripts/deps_check.lua`
	- `lua scripts/regression.lua`

### 5.3 回滚策略

- 任何阶段都不删除旧模块路径（至少保留一个版本），发现问题可直接回退到 shim 指向旧实现。
- 若 Phase 2 牵涉 store/同步，优先用 feature flag（例如 `game.store_is_sot`）隔离，避免一次性切换。

---

## 6. PR 自查清单（强制）

- 是否新增/修改了 `src/gameplay/domain/*` 对 `src.gameplay.app.*` 的依赖？（应为否）
- 是否新增/修改了 `src/gameplay/*` 对 `src.adapters.*` 的依赖？（应为否）
- `scripts/deps_check.lua` 是否通过？
- `scripts/regression.lua` 是否通过？
- 若改动涉及 choice：是否处理了 stale choice（过期选择被拦截）？

---

## 7. 附录：与现有脚本的对应关系

- 依赖护栏：`scripts/deps_check.lua`
- 回归护栏：`scripts/regression.lua`
- Love2D 入口：`main.lua` + `src/adapters/love2d/love_layer.lua`

