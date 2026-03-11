# 子系统速查

## 路径 → 职责

| 路径 | 职责 | 不属于这里 |
|------|------|-----------|
| `src/game/scheduler/` | 协程调度：创建、推进、超时、AFK 时钟 | 游戏规则、UI 通知 |
| `src/game/ai/` | 中性 AI 策略：自动玩家判断、目标选择、自动 choice | 回合推进、宿主调用 |
| `src/game/flow/output_adapters/` | turn use case 内部输出桥：接回 `intent_dispatcher` / `ui_runtime` | 宿主能力、跨用例共享 |
| `src/game/core/player/` | 玩家状态：资金、道具、位置 | 业务规则（不引用 systems） |
| `src/game/core/ai/` | AI 兼容入口：为旧调用点转发到 `src/game/ai/` | 扩展新的策略实现 |
| `src/game/core/runtime/` | `Game` 聚合根与 `CompositionRoot` 装配 | 破产结算等业务规则 |
| `src/game/systems/movement/` | 移动规则：步数、格子推进 | UI 节点名、Canvas 切换 |
| `src/game/systems/land/` | 地块规则：落地触发、地块状态 | 宿主 API |
| `src/game/systems/market/` | 黑市规则：商品配置、交易逻辑 | UI 渲染、宿主 API |
| `src/game/systems/items/` | 道具规则：使用条件、效果产出 | UI 节点、Canvas 切换 |
| `src/game/systems/chance/` | 机会卡规则：抽取、效果 | 宿主 API |
| `src/game/systems/effects/` | buff/debuff 施加与结算 | UI 渲染 |
| `src/game/systems/choices/` | choice spec 生成与校验 | 展示层业务推断 |
| `src/game/systems/commerce/` | 收费规则：过路费、交易结算 | UI 节点名 |
| `src/game/systems/vehicle/` | 载具规则：乘坐条件、移动变体 | Canvas 切换 |
| `src/game/systems/endgame/` | 破产/胜负判定与结算 | UI 渲染、宿主 API |
| `src/game/systems/board/` | 棋盘状态：格子布局与全局查询 | 业务规则触发 |
| `src/infrastructure/runtime/` | Eggy 宿主实现：事件桥、运行时上下文、默认 runtime ports | 游戏逻辑、UI 渲染 |
| `src/app/bootstrap/` | 装配：安装端口别名、读取启动参数 | 业务规则、宿主能力实现 |
| `src/core/` | 跨层共享：日志、数值工具、配置访问、宿主广义契约 | Eggy 全局对象直读、UI 节点操作 |
| `src/presentation/schema/` | 纯展示 schema：节点名、contract、布局常量 | 状态写入、事件桥、输入语义 |
| `src/presentation/input/` | 输入事件 → turn action 映射 | 业务推断 |
| `src/presentation/model/` | UI model 构建与只读查询 | 写状态、触发副作用 |
| `src/presentation/view/` | Canvas / widgets / render 输出 | 业务逻辑、输入处理 |
| `src/presentation/runtime/` | 展示侧 runtime adapter、canvas store、UI 事件桥 | 游戏规则 |

## 放置决策速查

- 回合推进下一步 → `src/game/flow/`
- 玩法规则业务逻辑 → `src/game/systems/` 对应子目录
- ViewModel 渲染 → `src/presentation/view/`
- 节点名 / 画布 contract / 布局常量 → `src/presentation/schema/`
- 输入事件 → turn action → `src/presentation/input/`
- 宿主能力接入端口 → `src/app/bootstrap/`
- 宿主能力实现 → `src/infrastructure/runtime/`
- 宿主/运行时广义契约 → `src/core/ports/`
- 玩法规则业务能力契约 → `src/game/ports/`
- 协程创建/推进/超时 → `src/game/scheduler/`
- 自动玩家策略与目标选择 → `src/game/ai/`
- 玩家资金/位置/道具字段 → `src/game/core/player/`
- AI 兼容入口 → `src/game/core/ai/`

> 模块同时涉及业务规则和宿主/UI 细节时，先拆边界，不新增跨层混合模块。
