# 子系统速查

## 路径 → 职责

| 路径 | 职责 | 不属于这里 |
|------|------|-----------|
| `src/turn/loop/` | 协程调度：创建、推进、超时 | 游戏规则、UI 通知 |
| `src/computer/` | 中性 AI 策略：自动玩家判断、目标选择、自动 choice | 回合推进、宿主调用 |
| `src/turn/output/` | turn use case 内部输出桥：接回 `intent_dispatcher` / `ui_runtime` | 宿主能力、跨用例共享 |
| `src/player/` | 玩家状态：资金、道具、位置 | 业务规则（不引用 `src/rules`） |
| `src/state/` | 运行时状态：game state、turn state、runtime namespace | 业务规则、UI 直接写入 |
| `src/rules/board/` | 棋盘规则：格子布局与全局查询 | 业务规则触发以外的 UI 逻辑 |
| `src/rules/effects/` | buff/debuff 施加与结算 | UI 渲染 |
| `src/rules/land/` | 地块规则：落地触发、地块状态 | 宿主 API |
| `src/rules/market/` | 黑市规则：商品配置、交易逻辑 | UI 渲染、宿主 API |
| `src/rules/items/` | 道具规则：使用条件、效果产出 | UI 节点、Canvas 切换 |
| `src/rules/chance/` | 机会卡规则：抽取、效果 | 宿主 API |
| `src/rules/choices/` | choice spec 生成与校验 | 展示层业务推断 |
| `src/rules/commerce/` | 收费规则：过路费、交易结算 | UI 节点名 |
| `src/rules/vehicle/` | 载具规则：乘坐条件、移动变体 | Canvas 切换 |
| `src/rules/endgame/` | 破产/胜负判定与结算 | UI 渲染、宿主 API |
| `src/rules/board/` | 棋盘状态：格子布局与全局查询 | 业务规则触发 |
| `src/infrastructure/runtime/` | Eggy 宿主实现：事件桥、运行时上下文、默认 runtime ports、seam exception | 游戏逻辑、UI 渲染 |
| `src/app/bootstrap/` | 装配：安装端口别名、读取启动参数 | 业务规则、宿主能力实现 |
| `src/core/` | 跨层共享：日志、数值工具、配置访问、宿主广义契约 | Eggy 全局对象直读、UI 节点操作 |
| `src/ui/runtime/` | 展示共享 seam：`runtime_state` / `landing_visual_hold` / `host_bridge` 窄桥接 | controller 装配、render/input 逻辑 |
| `src/presentation/runtime/ports/` | presentation grouped ports / runtime adapter 真源 | gameplay 规则、宿主底层实现 |
| `src/presentation/schema/` | 纯展示 schema：节点名、contract、布局常量 | 状态写入、事件桥、输入语义 |
| `src/presentation/input/` | 输入事件 → turn action 映射 | 业务推断 |
| `src/presentation/model/` | UI model 构建与只读查询 | 写状态、触发副作用 |
| `src/presentation/view/` | Canvas / widgets / render 输出 | 业务逻辑、输入处理 |
| `src/presentation/runtime/` | 展示侧 runtime adapter、canvas store、UI 事件桥 | 游戏规则 |

## 放置决策速查

- 回合推进下一步 → `src/turn/`
- 玩法规则业务逻辑 → `src/rules/` 对应子目录
- ViewModel 渲染 → `src/presentation/view/`
- 节点名 / 画布 contract / 布局常量 → `src/presentation/schema/`
- 展示共享 seam / 运行时窄桥接 → `src/ui/runtime/`
- 展示 runtime grouped ports / adapter → `src/presentation/runtime/ports/`
- 输入事件 → turn action → `src/presentation/input/`
- 宿主能力接入端口 → `src/app/bootstrap/`
- 宿主能力实现 → `src/infrastructure/runtime/`
- 宿主/运行时广义契约 → `src/core/ports/`
- 玩法规则业务能力契约 → `src/rules/ports/`
- 协程创建/推进/超时 → `src/turn/loop/`
- 自动玩家策略与目标选择 → `src/computer/`
- 玩家资金/位置/道具字段 → `src/player/`

> 模块同时涉及业务规则和宿主/UI 细节时，先拆边界，不新增跨层混合模块。
