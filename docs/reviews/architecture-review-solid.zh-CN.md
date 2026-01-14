# 架构与目录层级评审（SOLID）— monopoly

> 评审快照：`34ea479`（2026-01-14）  
> 范围：目录结构、模块边界、依赖方向、关键流程（入口/回合/落地/选择/UI适配）  
> 方法：按现有代码与自检脚本（`tests/deps_check.lua`）的真实约束，结合 SOLID 原则给出结论与风险点。

## 1. 当前目录结构（事实描述）

```
main.lua                       # 入口：配置 package.path + 装配 Love2D 适配层
src/
  adapters/love2d/             # LÖVE2D 适配器：渲染/输入/弹窗/自动推进
  config/                      # 表驱动配置：地图/地块/道具/常量等
  core/                        # 核心对象：Board/Player/Tile/Dice/Inventory
  gameplay/
    ai/                        # AI 决策
    app/                       # 应用层：回合编排、choice、landing_resolver、services、turn phases
    domain/                    # 领域规则：effect 容器、落地效果、道具逻辑、地产结算等
    infra/                     # 基础设施：RNG、Store
    ports/                     # 端口：UI port（规则层对 UI 的最小依赖）
  util/                        # 通用工具：logger/random/tables
tests/
  deps_check.lua               # 依赖方向自检
  regression.lua               # 回归用例
```

### 关键依赖方向（现状）

- 入口（`main.lua`）→ `src/game.lua`（游戏对象装配 + 对外 API）→ `src/gameplay/app/**`（流程编排）
- `src/gameplay/**` → `src/gameplay/ports/ui_port.lua`（通过 `game.ui_port` 调用 UI 端口）
- `src/adapters/love2d/**` → 依赖 gameplay/core/config（允许），并实现/挂载 `game.ui_port`
- `tests/deps_check.lua` 约束：
  - `src/gameplay/**` 禁止 require `src/adapters.*`
  - `src/gameplay/domain/**` 禁止 require `src.gameplay.app.*`
  - `src/gameplay/app/services/**` 禁止互相 require

## 2. 总体结论

**整体结构已接近六边形/端口-适配器思路**：规则推进在 `src/gameplay/app/**`，UI 通过 `src/gameplay/ports/ui_port.lua` 间接调用适配层；并且有依赖自检（`tests/deps_check.lua`）帮助维持方向。

但目前存在几类“架构漂移/边界模糊”的点，会降低可维护性与可复现/可存档的可信度：

- 文档与目录/脚本路径存在不一致（README、注释、文档引用）。
- 依赖自检对“模块命名风格”敏感，存在绕过空间。
- Store“单一事实来源”尚未完全落实：部分运行态状态仍停留在对象内（例如 overlays）。
- 一些领域规则文件同时承担“规则 + UI 选择/提示状态机”的职责（SRP 边界偏粗）。

## 3. SOLID 逐条评审（结合现有实现）

### S — 单一职责（SRP）

做得好的地方：

- 回合阶段拆分清晰：`src/gameplay/app/turn/*.lua` 每个 phase 单文件，`src/gameplay/app/services/turn_manager.lua` 只做编排。
- effect 容器（`src/gameplay/domain/effect.lua`）把“可用性判定/执行”抽成统一入口，降低落地逻辑的分支复杂度。

主要问题（职责偏重/边界混合）：

- `src/game.lua` 同时负责：装配（bootstrap + store/rng/player 绑定）、运行态派发（`dispatch_action/advance_turn`）、以及一批“写 store 的领域操作”（`set_tile_owner/...`）——更像“God Object/Façade + Composition Root”的混合体。
- `src/gameplay/domain/land.lua` 在地产结算中直接管理 `turn.rent_prompt/tax_prompt` 的状态机数据；与 `src/gameplay/app/choice_resolver.lua` 强耦合（需要二次进入同一个 effect 才能读取决策并继续）。
- `src/gameplay/domain/landing.lua` 聚合了多类 tile 的落地效果（起点/道具/机会/医院/深山/黑市/地雷），并混入 UI intent（push popup / need choice）。它本质是“落地效果注册表 + 若干具体实现”。

影响：

- 规则变更时更容易牵一发动全身（尤其是“提示/选择”相关的异步继续逻辑）。
- domain 文件里出现较多与 app/choice 的协议细节（choice kind、store turn.* 的键），阅读成本上升。

### O — 开闭原则（OCP）

做得好的地方：

- “效果”扩展点明确：通过往 `defs` 增加条目即可扩展（`src/gameplay/domain/landing.lua` + `src/gameplay/domain/land.lua` 的合并方式也便于聚合）。
- 道具行为有映射表：`src/gameplay/domain/item_executor.lua` 用 `item_handlers[item_id]` 映射，扩展入口清晰。

可改进点（当前仍需要修改既有文件的地方）：

- 新增 tile 类型/新 prompt 逻辑通常需要改动 `landing.lua`/`land.lua`/`choice_resolver.lua` 多处；扩展路径不够“局部化”。
- `get_service(ctx, key)` 在多个文件里重复出现（`landing.lua`、`land.lua` 等），说明依赖注入形式不统一，扩展时容易出现“某处取 services、某处取 game.services”的分叉。

### L — 里氏替换（LSP）

项目基本不使用继承/子类型替换；主要体现为“表/函数约定”的替换：

- UI 端口通过“鸭子类型”检查（`port.push_popup/request_choice/play_animation`）。这符合 Lua 风格，但缺点是“接口契约”靠运行时发现。

建议（仅作为评审点）：

- 继续保持“最小接口 + 运行时检查”，但建议把“端口契约”写到一处文档里，并在回归/自检中覆盖（避免适配层改了方法签名后静默失效）。

### I — 接口隔离（ISP）

做得好的地方：

- 规则层对 UI 的依赖面非常小：`src/gameplay/ports/ui_port.lua` 只有 `push_popup/request_choice/play_animation` 三类能力（且允许缺省）。

潜在问题：

- `game.ui_port` 既是“是否有 UI”的开关，又是具体 UI 实现，所有能力都挂在同一个 port 上；当后续出现“非交互 UI（只展示）”或“录制/回放 UI（不弹窗）”时，可能需要在一个 port 上堆更多方法。

评审建议：

- 现阶段接口已经足够小，不建议为了 ISP 再拆更多 port；优先通过“choice + intent”维持最小面。

### D — 依赖倒置（DIP）

做得好的地方：

- gameplay 通过 port 间接调用 UI，避免直接依赖 `src/adapters/**`，并有脚本自检（`tests/deps_check.lua`）。
- RNG 状态通过 `src/gameplay/infra/rng.lua` 写回 store（`rng._store = store`），满足“可复现”的基础方向。

主要风险点：

- **依赖自检可被命名风格绕过**：`tests/deps_check.lua` 只检查 `require("src.adapters.*")` 这类前缀；若有人写 `require("adapters.love2d...")`、`dofile(...)` 或其他路径方式，规则可能失效。
- Store 的“单一事实来源”仍不完全：例如 overlays（路障/地雷）主要存在于 `Board.overlays`（`src/core/board.lua`），UI 展示也优先读 runtime（`src/adapters/love2d/presenter.lua`），而 `store.state.board.overlays` 目前看不到完整的更新链路。

## 4. 目录层级与边界问题清单（可执行）

### 4.1 文档/脚本路径漂移（高优先级）

- `README.md` 提到 `src/app.lua`，但仓库中不存在该文件（当前装配主要在 `src/game.lua` + `src/gameplay/app/bootstrap/init.lua`）。
- `README.md` 提到 `lua scripts/deps_check.lua` / `lua scripts/regression.lua`，但实际脚本位于 `tests/deps_check.lua` / `tests/regression.lua`。
- `tests/deps_check.lua`、`tests/regression.lua` 顶部注释仍写 `run with: lua scripts/...`。
- `docs/eggy/eggy-migration-roadmap.zh-CN.md` 引用了不存在的 `docs/architecture-review.zh-CN.md`。

### 4.2 “core vs gameplay/domain”边界可读性（中优先级）

- `src/core/player.lua` 依赖 `src.util.logger`、`src.config.constants` 且接收 `game` 做破产/移动等操作（例如 `send_to_hospital/apply_hospital_effects`），这使 `core` 更像“领域模型”而不是“可复用的纯核心库”。对读者来说，“哪些规则在 core，哪些在 gameplay/domain”不够一眼清晰。

### 4.3 状态单一来源（中优先级）

- Tile 的运行态状态以 store 为准（`src/core/tile.lua: Tile.get_state`），但 `Tile.from_config` 仍保留 `owner_id/level` 字段与若干方法（`can_upgrade/current_rent/...`）使用的是对象字段。当前代码大量使用 store state（例如 `src/gameplay/domain/land.lua`），容易形成“两套状态字段并存”的心智负担。
- overlays 的持久化语义不清晰：store 里有 `board.overlays` 初始化，但运行时修改主要在 `Board.overlays`。

### 4.4 选择/提示状态机分散（中优先级）

- `pending_choice` 机制很好，但同时还存在 `turn.market_prompt`、`turn.rent_prompt`、`turn.tax_prompt` 等“并行的小状态机键”；并且由 domain/app 多处共同维护。

## 5. 保持现状的优势（不应轻易改掉的点）

- `tests/deps_check.lua` 的“反依赖倒灌”约束非常关键：建议继续保留，并尽量增强而非削弱。
- phase 拆分 + Flow（`src/gameplay/app/flow.lua`）让流程推进非常可读，可作为后续扩展基础。
- UI port + Choice 的交互模型（“需要选择就挂起，选择后恢复”）非常适合可回放/回归测试。

## 6. 建议的改进方向（概要）

> 具体路线图见：`docs/reviews/architecture-improvement-roadmap.zh-CN.md`

- 先修复文档/脚本路径漂移，保证“读文档能跑通命令”。
- 强化依赖自检：减少对 require 命名风格的依赖（至少做到“不容易绕过”）。
- 明确 store 的责任边界：决定 overlays 等运行态状态是否进入 store；保持“单一事实来源”的叙述与实现一致。
- 收敛 choice/prompt 的状态键：优先复用 `pending_choice`，减少 `turn.*_prompt` 类旁路状态。

