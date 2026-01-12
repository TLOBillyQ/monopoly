# 代码库层级结构审查与迁移计划（`src/`）

日期：2026-01-12

> 目标：审查当前代码库的层级结构，指出不合理点，并给出一个可分阶段落地、低风险的迁移计划。
>
> 范围：`src/`、`main.lua`、`scripts/deps_check.lua`、`scripts/regression.lua`。
>
> 约束：优先以“结构与可维护性”为目标，不改玩法与交互语义。

---

## 1. 现状结论（基于事实与脚本验证）

- 入口链路清晰：`main.lua` → `src/app.lua`（组装/注入）→ `src/visual/love_layer.lua`（Love2D 适配）。
- 分层约束已被工具化：`lua scripts/deps_check.lua` 通过。
- 基础回归可执行：`lua scripts/regression.lua` 通过。
- 当前关键依赖方向是正确的：
  - `src/gameplay/**` 不 `require src/visual/**`。
  - `src/gameplay/services/**` 未出现 service 之间直接 `require("src.gameplay.services.*")`（依赖通过 `game.services` 注入获取）。

---

## 2. 不合理点（需要迁移/收敛的地方）

### 2.1 `src/core` 不是“纯核心模型层”

- `src/core/board.lua` 直接读取 `src/config/map.lua`、`src/config/tiles.lua` 来构建棋盘。
- `src/core/player.lua` / `src/core/inventory.lua` 直接依赖 `src/config/constants.lua`。

影响：
- `core` 的“可复用/可测试”属性被默认配置绑定；未来想做多地图/多规则或纯单元测试时，会被隐式依赖拖累。

### 2.2 道具逻辑存在“双入口/双实现”的结构噪音

- `src/gameplay/effects/item.lua` 和 `src/gameplay/services/item_service.lua` 同时承载大量道具相关逻辑；并且 `item_service.lua` 后半段把大量 API 转发给 `ItemEffects`。

影响：
- 维护成本高：读者难判断“权威实现在哪里”。
- 潜在死代码：`item_service.lua` 前半段可能成为遗留实现，变更半径变大。

### 2.3 `src/gameplay` 同层级承载“规则/流程/基础设施/端口”

- 当前平铺：`effects/*`（规则）、`turn/* + flow + services/*`（流程/用例）、`store/sync/rng`（infra）、`ui.lua`（端口封装）。

影响：
- 结构可读性下降，后续演进容易继续“堆平铺文件”，边界变模糊。

### 2.4 可复现性存在隐性回退路径

- `src/util/random.lua`、`src/core/dice.lua` 在未传 `rng` 时会回落到 `math.random`。

影响：
- 只要新逻辑误用（漏传 `rng`），就会破坏“固定 seed 可复现”。

---

## 3. 目标分层（推荐的依赖方向）

> 这不是强制重命名方案，而是“边界拉直”的目标状态。

- 叶子层：`src/config`、`src/util`
  - 只提供数据与工具；不依赖 `gameplay`/`visual`。
- 领域模型：`src/core`
  - 只放纯结构与纯算法；不读取 `src/config/*`（由外部注入）。
- 规则/用例：`src/gameplay`
  - 依赖 `core/config/util`；不依赖 `visual`。
- 适配器：`src/visual`
  - 依赖 `config/util`；通过 `game` 与 `ui_hooks` 驱动交互；不反向 `require gameplay`。

---

## 4. 迁移计划（可分 PR，低风险落地）

### 阶段 1：先消“双入口”（道具逻辑单一权威源）

目标：明确“道具逻辑唯一权威源”，把结构噪音压下去。

做法（二选一，推荐 A）：
- A（推荐）：保留 `src/gameplay/effects/item.lua` 为权威实现；将 `src/gameplay/services/item_service.lua` 收敛成薄封装（仅暴露接口并转发到 `ItemEffects`），并删除/迁走其前半段遗留实现。
- B：反过来，将 `effects/item.lua` 并入 `services/item_service.lua`，并把所有调用统一为 `game.services.item`。

验收：
- `lua scripts/deps_check.lua` 通过。
- `lua scripts/regression.lua` 通过。
- `src/gameplay/choice_resolver.lua` 的 item 分支只走一个入口（避免一部分走 `ItemEffects`，另一部分走 `ItemService`）。

### 阶段 2：把“读配置的构建”从 `core` 拆出去

目标：让 `src/core` 变成真正的“模型/算法层”。

做法：
- 新增世界/工厂层（例如 `src/bootstrap/board_factory.lua` 或 `src/gameplay/world_factory.lua`）：负责读取 `src/config/map.lua`、`src/config/tiles.lua` 并构建 `Board`。
- 调整 `core/board.lua`：
  - 只接收构建后的 `path/tile_lookup/branches` 等数据，或 `Board.new(cfg)` 但 cfg 由工厂提供；
  - `core` 内不再 `require src.config.*`。

验收：
- `src/core/**` 不再 `require src.config.*`。
- 回归与依赖自检继续通过。

### 阶段 3：给 `gameplay` 内部分包，但保持旧路径兼容

目标：让“规则/用例/基础设施/端口”一眼可见，避免继续平铺。

做法（渐进式，避免大范围改动）：
- 新目录建议：
  - `src/gameplay/infra/`：`rng.lua`、`store.lua`、`sync.lua`
  - `src/gameplay/domain/`：`effect.lua` + 规则定义（可逐步迁 `effects/*`）
  - `src/gameplay/app/`：`services/*`、`turn/*`、`flow.lua`、`landing_resolver.lua`、`choice*`
- 为控制变更半径：在旧路径保留“转发壳文件”（旧文件内容仅 `return require("new.path")`）。

验收：
- 自检脚本继续通过。
- require 改动局部、可回滚。

### 阶段 4（可选）：将 `visual` 明确为 adapter 命名

- 可将 `src/visual` 迁至 `src/adapters/love2d/*`，并保留 `src/visual/*` 作为转发壳。
- 这一步偏“语义清晰/长期收益”，不建议在高频迭代期硬推。

---

## 5. 建议的验收标准（结构层面）

- 分层不倒退：`scripts/deps_check.lua` 继续作为 CI/自检门禁。
- 可复现不倒退：固定 seed + 同 action 序列，结果一致；避免新增 `math.random` 回退路径。
- 核心边界清晰：`src/core` 不直接读取 `src/config/*`（由组装/工厂提供）。
- 单一权威：同一领域（如道具）只有一个“权威实现入口”，其余仅是适配/转发。
