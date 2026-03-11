# 子系统速查表

本文档解释各子系统"是什么、做什么、不做什么"，让 agent 在落笔前快速判断代码归属。放置规则的权威文档是 `docs/architecture/boundaries.md`；本文只做口语化补充，不重复规则细节。

## 速查表

| 子系统路径 | 职责一句话 | 不属于这里的事 |
|---|---|---|
| `src/game/scheduler/` | 协程调度细节：创建、推进、超时与 AFK 时钟驱动 | 游戏规则判断、UI 通知 |
| `src/game/flow/output_adapters/` | turn use case 内部输出桥：把流程产出接回 `intent_dispatcher` 或 `ui_runtime` | 宿主能力实现、跨用例共享逻辑 |
| `src/game/core/player/` | 玩家状态：资金、道具、位置等领域数据持有者 | 业务规则（不能引用 systems） |
| `src/game/core/ai/` | AI agent：决策策略，产出 action | 回合推进细节（委托给 flow） |
| `src/game/core/runtime/` | `Game` 聚合根与 `CompositionRoot` 装配 | 破产结算等业务规则（已迁出） |
| `src/game/systems/movement/` | 移动规则：步数计算、格子推进 | UI 节点名、Canvas 切换 |
| `src/game/systems/land/` | 地块规则：落地触发、地块状态 | 宿主 API 调用 |
| `src/game/systems/market/` | 黑市规则：商品配置、交易逻辑 | UI 渲染、宿主 API |
| `src/game/systems/items/` | 道具规则：使用条件、效果产出 | UI 节点、Canvas 切换 |
| `src/game/systems/chance/` | 机会卡规则：抽取、效果定义 | 宿主 API 调用 |
| `src/game/systems/effects/` | 效果规则：buff/debuff 施加与结算 | UI 渲染 |
| `src/game/systems/choices/` | 选择规则：choice spec 生成与校验 | 展示层业务推断 |
| `src/game/systems/commerce/` | 收费规则：过路费计算、交易结算 | UI 节点名 |
| `src/game/systems/vehicle/` | 载具规则：乘坐条件、移动变体 | Canvas 切换 |
| `src/game/systems/endgame/` | 破产/胜负判定：结算条件与结果产出 | UI 渲染、宿主 API |
| `src/game/systems/board/` | 棋盘状态：格子布局与全局棋盘查询 | 业务规则触发 |
| `src/infrastructure/runtime/` | Eggy 宿主真实实现：事件桥、运行时上下文、默认 runtime ports | 游戏逻辑、UI 渲染 |
| `src/app/bootstrap/` | 装配层：安装端口别名、读取启动参数、拼接 `CompositionRoot` | 业务规则、宿主能力实现 |
| `src/core/` | 跨层共享：日志、数值工具、配置访问、宿主广义契约（`ports/`） | Eggy 全局对象直读、UI 节点操作 |
| `src/presentation/input/` | 输入事件 → turn action 映射 | 业务推断（不自行判断 choice 语义） |
| `src/presentation/model/` | UI model 构建与只读查询辅助 | 写状态、触发副作用 |
| `src/presentation/view/` | Canvas / widgets / render 输出 | 业务逻辑、输入处理 |
| `src/presentation/runtime/` | 展示侧 runtime adapter、canvas store、UI 事件桥接 | 游戏规则 |

## 放置决策速查

**你在写"回合推进到下一步应该做什么"** → 放 `src/game/flow/`

**你在写"某个玩法规则业务上允许什么、产出什么"** → 放 `src/game/systems/` 对应子目录

**你在写"某个 ViewModel 怎么渲染到 UI 节点"** → 放 `src/presentation/view/`

**你在写"输入事件怎么变成 turn action"** → 放 `src/presentation/input/`

**你在写"程序启动时把哪条宿主能力接成端口"** → 放 `src/app/bootstrap/`

**你在写"这些宿主能力的具体实现"** → 放 `src/infrastructure/runtime/`

**你在写"宿主/运行时广义能力的窄契约"** → 放 `src/core/ports/`

**你在写"玩法规则向外请求的业务能力契约"** → 放 `src/game/ports/`

**你在写"协程的创建、推进或超时"** → 放 `src/game/scheduler/`

**你在写"玩家资金/位置/道具等状态字段"** → 放 `src/game/core/player/`

**你在写"AI 如何做决策"** → 放 `src/game/core/ai/`

**一个模块既想碰业务规则又想碰宿主/UI 细节** → 先停下来拆边界，不要新增跨层混合模块
