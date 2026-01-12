# 代码库层级结构审查与迁移计划（src/）

日期：2026-01-12

> 目标：审查当前代码库的层级结构，指出不合理点，并给出一个可分阶段落地、低风险的迁移计划。
> 范围：src/、main.lua、scripts/deps_check.lua、scripts/regression.lua。
> 约束：优先以结构与可维护性为目标，不改玩法与交互语义，关注代码行数，尽最大可能降低代码量。

---

## 现状速览

- 入口与运行：main.lua 负责配置 package.path 与启动 [src.adapters.love2d.love_layer](src/adapters/love2d/love_layer.lua)，默认工厂在 [src/app.lua](src/app.lua) 构建整个游戏实例。
- 核心域模型：Board、Tile、Player、Inventory 等放在 [src/core](src/core)，但命名上更像领域层；配置在 [src/config](src/config)。
- 应用层：流程、决策与回合管理集中在 [src/gameplay/app](src/gameplay/app)，包含服务（services）、流程（turn/*）、解析器（choice_resolver、landing_resolver）。
- 领域层：道具、地块、效果等定义在 [src/gameplay/domain](src/gameplay/domain)。
- 基础设施：RNG、Store、Sync 在 [src/gameplay/infra](src/gameplay/infra)。
- 适配层：LOVE2D 渲染与 UI 状态在 [src/adapters/love2d](src/adapters/love2d)。
- 脚本：依赖规则自检在 [scripts/deps_check.lua](scripts/deps_check.lua)，回归检查在 [scripts/regression.lua](scripts/regression.lua)。

## 主要问题

- 领域层命名与位置不一致：Player/Board 位于 core，与 gameplay/domain 分离，阅读和分层规则不统一。
- 应用层 God Object：App 既负责状态存储、事件日志、玩家与棋盘初始化，又承担领域写操作，缺少用例级 API，难以替换或测试局部逻辑。
- Store/RNG 下探耦合弱：Store 的更新路径分散在 App 与各服务；RNG 暴露内部状态，生命周期靠手动注入和同步。
- 依赖方向易失控：虽有 deps_check，但默认不在 CI/预提交执行；services 之间的交互缺乏端口抽象，未来扩展新服务时容易相互 require。
- UI 入口耦合：App 对 ui_enabled 等标记有显式分支，LOVE2D 适配层通过 LoveLayer 直接持有 game 实例，未通过端口限制交互面。
- 配置散落：角色、卡牌、地图等配置集中在 config，但生成 Board/Player 的逻辑在 App/BoardFactory，耦合了构建与配置，难以做不同地图或模式的组合。

## 迁移原则

- 分层清晰：domain（纯数据与规则）→ app/usecase（流程编排与副作用指挥）→ infra（存储、随机、事件总线等）→ adapters（UI/平台），确保依赖只向下。
- 渐进式移动：先收口接口与依赖检查，再逐步搬迁文件与命名，确保 regression 脚本始终可跑。
- 减少写点：写状态只能通过少数用例/API，Store 更新集中管理，便于观察与回溯。
- 保持行为不变：所有迁移阶段均依赖 scripts/regression.lua 验证。

## 分阶段迁移计划

### Phase 0：防护与基线（1-2 天）

- 在 CI/预提交中添加 scripts/deps_check.lua 和 scripts/regression.lua，要求 PR 必须通过。
- 抽取简要架构文档到 docs/deepfuture（本文件即基线）。
- 给 App/服务添加最小级别的接口注释，明确输入/输出与副作用。

### Phase 1：命名与目录收敛（1-2 天）

- 将 [src/core](src/core) 并入 [src/gameplay/domain](src/gameplay/domain)（或重命名为 domain/core），保持 require 路径兼容期（导出别名模块）。
- BoardFactory 移到 gameplay/app/factories，并引入 interface：BoardFactory.create(opts) 仅产出纯数据 Board，不依赖 UI。
- 在 App.new 中仅保留组装逻辑，将玩家/棋盘/overlay 初始构建拆为独立纯函数（gameplay/app/bootstrap）。

### Phase 2：应用层收口（3-4 天）

- 引入 GameUsecase/API 层：例如 game.usecases.turn.start、roll、land、end，封装当前 turn_manager 操作，对 UI 暴露有限接口。
- 将 Store 更新集中到单一 update 模块（gameplay/app/state），App 不再直接 set；服务通过 state API 写入。
- RNG 生命周期托管到 infra/rng_manager，提供 snapshot/restore API，去除对 _store 的直接引用。
- 为服务定义端口（interfaces）并通过 game.services 注入，避免 require 彼此；保留 deps_check 规则但改为通过端口名单白名单。

### Phase 3：UI 适配层解耦（2-3 天）

- 在 gameplay/ports 中定义 UI 交互契约（展示选择、动画回调等），LoveLayer 仅实现端口。
- ui_enabled 分支移出 App；由端口实现决定是否需要等待用户输入。
- 抽离渲染数据投影模块（presenter），输入为 store/state 快照，输出为 UI 模型，减少 UI 对 domain 的直读。

### Phase 4：配置与模式化（2-3 天）

- Map/角色/卡牌配置按模式拆分：config/maps/*、config/roles/*，BoardFactory 支持 opts.mode 选择配置组合。
- 支持 seed、玩家预设等通过单一 config 对象传入 App.new，入口 main.lua 仅负责解析配置与选择适配层。
- 为脚本与回归测试增加“最小地图”配置，缩短测试时间并覆盖分支。

## 落地清单与衡量

- 防护：CI 执行 deps_check 与 regression，新增失败会阻断合并。
- 结构：core → domain 搬迁完成，require 兼容别名保留至少一个版本周期。
- 应用层：Store 写入路径收敛至单文件，services 之间无直接 require。
- UI：所有用户交互通过 ports/ui_port，LoveLayer 不再直接访问 game 内部结构。
- 配置：BoardFactory 接受模式化配置，入口参数化。

## 风险与缓解

- 文件搬迁导致 require 断裂：提供别名模块与一轮双写期，并依赖 deps_check 捕获遗漏。
- 回归缺失：每步迁移后运行 scripts/regression.lua，必要时补充针对新接口的测试用例。
- 行为微调风险：严格禁止在迁移阶段修改玩法语义；若必须改动，需在 PR 中列出行为差异并补充测试。
