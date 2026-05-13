---
kind: contract
status: stable
owner: architecture
last_verified: 2026-05-04
---
# 目录边界约定

> **See also**：架构决策 → [`../decisions/0001-seven-layer-with-foundation.md`](../decisions/0001-seven-layer-with-foundation.md)（七层模型与各层职责）；分层模型 → [`layer-model.md`](layer-model.md)。

## 目录职责

| 目录 | 职责 | 不允许 |
|------|------|--------|
| `src/app` | 装配：拼接运行时端口、bootstrap、game_state class-level mixin 安装 | — |
| `src/foundation` | 横切基础设施基座：log、lang、identity、events、ports、coordination | 直读 Eggy 全局对象；UI 节点或支付面板逻辑；依赖任何上层 |
| `src/turn` | 用例编排：回合推进、意图分发、输入校验、输出端口发射 | 操作 UI 细节或宿主运行时对象 |
| `src/rules` | 玩法规则：黑市、道具、地块、机会卡、移动、破产、胜负、choice 注册与 resolve | UI 节点名、Canvas 切换、宿主 API 调用 |
| `src/computer` | 中性 AI 策略：自动出牌、目标选择、自动 choice 决策 | 回合调度、宿主 API |
| `src/state` | L7 状态层：游戏根对象、玩家持久数据、棋盘数据、回合状态、视觉冻结-释放打包（`visual_hold/`）、UI runtime 数据访问 | 依赖 player/rules/turn/ui/host/app（任何上层） |
| `src/config` | L7 配置层：内容（地图/瓷砖/集市）、玩法常量（timing/event_kinds 等）、choice contract / route_policy | 依赖任何上层 |
| `src/turn/output` | 回合输出适配：intent_dispatcher、state_adapter | 承接业务规则 |
| `src/host` | 宿主细节：运行时上下文、事件桥、默认 runtime ports、显式 seam exception（`global_aliases`） | — |
| `src/ui` | 顶层 wrapper（`visual_hold`、`host_bridge`）+ 内部子视图（input/view/render/coord/state/ports/schema/utils） | controller 装配、Canvas 渲染、输入路由（这些下沉到各子视图） |
| `src/ui/state` | 纯 UI 状态容器：runtime（state.runtime seam）、canvas_store、modal、visual_hold（顶层 wrapper） | 持有跨 render/coord/input 的反向引用 |
| `src/ui/coord` | UI 协调器：actor_context / ui_state / ui_runtime / event_state / event_handlers / canvas_event_router 等 | — |
| `src/ui/view` | 数据投影：role_context、各 slice、panel_builder | 写状态 |
| `src/ui/render` | 渲染：board / market / move_anim / status3d / widgets / render_pipeline | 输入路由 |
| `src/ui/ports` | 展示运行时装配：grouped ports、state callback、runtime event bridge、bootstrap | 游戏规则、宿主底层实现 |
| `src/ui/schema` | 展示 schema：canvas 节点名、contract 常量、布局清单 | 写状态、宿主调用、输入路由 |
| `src/ui/input` | 输入分发：canvas_route / dispatch / event_intents | 反向写状态（通过 ports 走） |
| `src/ui/utils` | UI 内部工具：`with_client_role` 等 | — |

`src/turn/output/` 属于 `turn`，不是独立 runtime 目录。其中 `intent_dispatcher`、`state_adapter` 只服务 turn use case 输出，不承载宿主能力。

## Rules 子系统速查

| 目录 | 职责 |
|------|------|
| `src/rules/board/` | 棋盘布局与全局查询 |
| `src/rules/effects/` | buff/debuff 施加与结算 |
| `src/rules/land/` | 地块规则：落地触发、地块状态 |
| `src/rules/market/` | 黑市规则：商品配置、交易逻辑 |
| `src/rules/items/` | 道具规则：使用条件、效果产出 |
| `src/rules/chance/` | 机会卡规则：抽取、效果 |
| `src/rules/choice/` | choice 注册、resolve 与共享语义 |
| `src/rules/choice_handlers/` | choice action 到规则效果的分发 |
| `src/rules/commerce/` | 收费规则：过路费、交易结算 |
| `src/rules/vehicle/` | 载具规则：乘坐条件、移动变体 |
| `src/rules/endgame/` | 破产、胜负判定与结算 |
| `src/rules/ports/` | 玩法规则业务能力契约 |

## Port 命名规则

| 后缀 | 含义 | 示例 |
|------|------|------|
| `*.lua`（目录内短名） | 单一窄接口契约 | `bankruptcy_feedback.lua` |
| `ports.lua` | 包入口 bundle / grouped ports 装配 | `runtime/ports.lua` |
| `ports/*.lua` | bundle 叶子模块，文件名用目录内短名 | `src/ui/ports/anim.lua` |
| `*_port_adapter.lua` | 外层对某契约的实现 | `paid_purchase_port_adapter.lua` |

`*_ports.lua`、`*_port.lua` 旧命名不再作为 canonical 文件名；本轮为硬切，不保留旧兼容文件。

**三类 Port 目录：**

- `src/foundation/ports/` — 宿主/运行时广义契约，gameplay 无关（`runtime_ports`、`action_anim`）
- `src/rules/ports/` — rules-facing 注入契约，允许业务名词
- `src/turn/loop/ports.lua` — turn use case 局部 override，不是通用 Port 层

## 硬边界（不可违反）

1. **choice 语义显式输出**：路由、确认文案、item slot、target picker、market 分页状态由用例层显式输出，UI 只做通用 fallback。
2. **choice 归属显式传递**：通过 `owner_role_id` 等显式字段传递，不允许展示层反查 `meta.player_id`。
3. **market session 状态**：`active_tab`、`page_index`、`page_count` 挂在 `ChoiceSession` 显式字段，不靠 `meta` 兜底。
4. **宿主逻辑不回流内层**：Eggy API、支付面板、运行时上下文、事件桥只能在 `src/host` 或 `src/app`。
5. **破产反馈通过端口**：rules 通过 `src/rules/ports/bankruptcy_feedback.lua` 发出语义，UI 更新由外层 adapter 决定。
6. **root-state 镜像已退休**：`legacy_output_mirror.lua` 已删除，UI 状态以 `state.ui_runtime` 为唯一真源。
7. **loop_ports 拼装权限**：只有 `src/app/*`、`src/turn/loop/*` 与测试夹具可直接拼装 `loop_ports` override。
8. **架构边界可执行真源**：`tools/quality/arch/config.json`。
9. **零模块级循环依赖**：无白名单，任意新循环直接让 `arch_view` 护栏失败。
10. **UI schema 纯只读**：`src/ui/schema` 只能承载节点名、画布常量与布局定义；运行时编排与渲染留在 `ui`。

## 放置速查

- 回合推进 → `src/turn`
- 玩法业务规则 → `src/rules`
- ViewModel 渲染 → `src/ui`
- 纯展示节点/schema → `src/ui/schema`
- 展示共享 seam / UI runtime 窄桥接 → `src/ui`
- 展示 runtime adapter / grouped ports 装配 → `src/ui/ports`
- 宿主能力接入端口 → `src/app`；实现 → `src/host`
- 宿主/运行时广义契约 → `src/foundation/ports/`
- 玩法规则业务能力契约 → `src/rules/ports/`
- 回合循环临时 override → `src/turn/loop/ports.lua`

> 模块同时涉及业务规则和宿主/UI 细节时，先拆边界，不新增跨层混合模块。
