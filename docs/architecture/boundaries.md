# 目录边界约定

> **See also**：架构治理路线图 → [`governance_roadmap.md`](governance_roadmap.md)（物理目录与逻辑层错位、6 条 exception 治理动作）

## 目录职责

| 目录 | 职责 | 不允许 |
|------|------|--------|
| `src/app` | 装配：拼接运行时端口、bootstrap | — |
| `src/core` | 跨玩法共享：日志、数值工具、配置访问、runtime 广义契约 | 直读 Eggy 全局对象；UI 节点或支付面板逻辑 |
| `src/turn` | 用例编排：回合推进、意图分发、输入校验、输出端口发射 | 操作 UI 细节或宿主运行时对象 |
| `src/rules` | 玩法规则：黑市、道具、地块、机会卡、移动、破产、胜负 | UI 节点名、Canvas 切换、宿主 API 调用 |
| `src/computer` | 中性 AI 策略：自动出牌、目标选择、自动 choice 决策 | 回合调度、宿主 API |
| `src/turn/output` | 回合输出适配：intent_dispatcher、state_adapter | 承接业务规则 |
| `src/host` | 宿主细节：运行时上下文、事件桥、默认 runtime ports、显式 seam exception | — |
| `src/ui` | 展示共享 seam：`state`、`landing_visual_hold`、`host_bridge` 这类窄桥接 | controller 装配、Canvas 渲染、输入路由 |
| `src/ui/ports` | 展示运行时装配：grouped ports、state callback、runtime event bridge、bootstrap | 游戏规则、宿主底层实现 |
| `src/ui/schema` | 展示 schema：canvas 节点名、contract 常量、布局清单 | 写状态、宿主调用、输入路由 |
| `src/ui` | 展示适配：input 映射、UI model 查询、Canvas 渲染、UI 事件桥接 | 根据 `choice.kind`/`meta`/商品配置自行推断业务语义 |

`src/turn/output/` 属于 `turn`，不是独立 runtime 目录。其中 `intent_dispatcher`、`state_adapter` 只服务 turn use case 输出，不承载宿主能力。

## Port 命名规则

| 后缀 | 含义 | 示例 |
|------|------|------|
| `*.lua`（目录内短名） | 单一窄接口契约 | `bankruptcy_feedback.lua` |
| `ports.lua` | 包入口 bundle / grouped ports 装配 | `runtime/ports.lua` |
| `ports/*.lua` | bundle 叶子模块，文件名用目录内短名 | `presentation/runtime/ports/anim.lua` |
| `*_port_adapter.lua` | 外层对某契约的实现 | `paid_purchase_port_adapter.lua` |

`*_ports.lua`、`*_port.lua` 旧命名不再作为 canonical 文件名；本轮为硬切，不保留旧兼容文件。

**三类 Port 目录：**

- `src/core/ports/` — 宿主/运行时广义契约，gameplay 无关
- `src/rules/ports/` — systems-facing 注入契约，允许业务名词
- `src/turn/loop/ports.lua` — turn use case 局部 override，不是通用 Port 层

## 硬边界（不可违反）

1. **choice 语义显式输出**：路由、确认文案、item slot、target picker、market 分页状态由用例层显式输出，presentation 只做通用 fallback。
2. **choice 归属显式传递**：通过 `owner_role_id` 等显式字段传递，不允许展示层反查 `meta.player_id`。
3. **market session 状态**：`active_tab`、`page_index`、`page_count` 挂在 `ChoiceSession` 显式字段，不靠 `meta` 兜底。
4. **宿主逻辑不回流内层**：Eggy API、支付面板、运行时上下文、事件桥只能在 `src/host` 或 `src/app`。
5. **破产反馈通过端口**：systems 通过 `src/rules/ports/bankruptcy_feedback.lua` 发出语义，UI 更新由外层 adapter 决定。
6. **root-state 镜像已退休**：`legacy_output_mirror.lua` 已删除，UI 状态以 `state.ui_runtime` 为唯一真源。
7. **loop_ports 拼装权限**：只有 `src/app/*`、`src/turn/loop/*` 与测试夹具可直接拼装 `loop_ports` override。
8. **架构边界可执行真源**：`tools/quality/arch/config.json`。
9. **零模块级循环依赖**：无白名单，任意新循环直接让 `arch_view` 护栏失败。
10. **presentation schema 纯只读**：`src/ui/schema` 只能承载节点名、画布常量与布局定义；运行时编排与渲染留在 `ui`。

## 放置速查

- 回合推进 → `src/turn`
- 玩法业务规则 → `src/rules`
- ViewModel 渲染 → `src/ui`
- 纯展示节点/schema → `src/ui/schema`
- 展示共享 seam / UI runtime 窄桥接 → `src/ui`
- 展示 runtime adapter / grouped ports 装配 → `src/ui/ports`
- 宿主能力接入端口 → `src/app`；实现 → `src/host`
- 宿主/运行时广义契约 → `src/core/ports/`
- 玩法规则业务能力契约 → `src/rules/ports/`
- 回合循环临时 override → `src/turn/loop/ports.lua`

> 模块同时涉及业务规则和宿主/UI 细节时，先拆边界，不新增跨层混合模块。
