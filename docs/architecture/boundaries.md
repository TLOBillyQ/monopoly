# 目录语义与边界约定

这份说明用于固定本仓库在本轮重构后的目录语义，避免后续开发再次把运行时细节、用例编排和 UI 推断混回同一层。它不是新的设计提案，而是当前代码已经落地后的职责清单。

## 为什么需要这份文档

本仓库经历了六个阶段的边界收口后，很多“以前能混着写”的路径已经被主动切断：`src/core` 不再承接 Eggy 宿主全局读取，`src/game/flow` 不再直接写 UI 状态，`src/presentation` 也不再依赖 `choice.kind/meta` 自行推断业务语义。如果没有一份稳定的目录导读，下一位开发者很容易因为目录名误解而把旧耦合重新写回来。

## 当前目录应该怎样理解

`src/app` 是最外层装配区。这里负责把运行时端口、bootstrap 安装逻辑和测试场景拼起来。它可以依赖别的层，因为它本身就是“程序如何启动”的细节层。

`src/core` 是跨玩法共享的稳定策略与小型契约层。这里允许放日志、数值工具、配置访问器、领域无关的 route policy，以及“被内层依赖的端口定义”。这里不应该直接读取 Eggy 全局对象，也不应该塞入具体 UI 结点或支付面板逻辑。

`src/game/flow` 是用例编排层。这里负责一回合怎么推进、意图怎么分发、输入怎么校验、输出端口怎么发射。它可以协调 `src/game/systems` 的业务模块，但不应该回头操作 UI 细节或宿主运行时对象图。

`src/game/systems` 是玩法业务层。这里放黑市、道具、地块、机会卡、移动、破产结算、胜负判定等规则本身。规则模块可以生成 choice spec、popup payload、动画请求等稳定输出模型，但不应该自己决定 UI 节点名、Canvas 切换方式或宿主 API 调用顺序。

`src/game/runtime` 与 `src/infrastructure/runtime` 一起承担运行时适配职责。前者现在只保留贴近 gameplay 的 adapter，例如 `AutoPlayPortAdapter`、`BankruptcyPortAdapter` 这类“把端口实现接成 `src/game/ports/*` 契约”的实现；`src/game/core/runtime` 只保留 `Game` 聚合根与装配代码，不再承接破产结算、胜负判定这类业务规则；历史回合执行器被收拢到 `src/game/turn_engine/`，它是 deprecated/frozen 的历史执行器容器，不是新的常规分层目录，当前仍由 `src/game/core/runtime/composition_root.lua` 承接装配，后续只做替换式退休、不再扩展新职责；协程调度细节则收拢到 `src/game/scheduler/`。后者承接运行时上下文、事件桥和默认 runtime ports 这类更外层的宿主细节；`src/app/bootstrap/runtime_install` 则只负责安装别名和装配。当前 `src/core/runtime_facade/runtime_context.lua`、`src/core/runtime_facade/runtime_event_bridge.lua`、`src/core/runtime_ports/default_ports.lua` 已退休并删除；调用方统一直接引用 `src/infrastructure/runtime/*` 真实实现。以后只要看到新的 Eggy API 调用需求，优先判断它是不是应该留在那里，而不是回写到 `src/core` 或 `src/game/flow`。

`src/presentation` 是展示适配层。其中 `src/presentation/adapter/` 表达展示侧 adapter，`src/presentation/widgets/` 表达可复用 UI 组件，`canvas/` 保留页面级 presenter 与页面行为。它负责把 `ui_model`、choice view、popup view、market view 渲染成具体 UI，并处理输入事件到 turn action 的映射。它可以解释 ViewModel，但不应该再根据 `choice.kind`、`choice.meta` 或商品配置自行补业务语义。

`src/presentation/read_model` 目前仍是 presentation 的一部分，不是独立 CQRS 查询层。它的职责是给 UI 组装轻量只读辅助数据；如果未来出现更明确的跨界查询需求，再考虑把它提升为独立 adapter。

## 这轮重构后形成的硬边界

第一，choice 的路由、确认文案、item slot 语义、target picker 语义、market 分页状态，都应由用例层显式输出。presentation 最多做通用 fallback，不再新增业务推断。

第二，choice 的拥有者必须通过显式字段传递，例如 `owner_role_id` 或 target picker 专用字段，而不是让展示层或校验层反查 `meta.player_id`。

第三，market 的 session 状态属于用例输出的一部分。`active_tab`、`page_index`、`page_count` 应挂在显式字段上，由 `ChoiceSession` 维护，而不是靠 `meta` 给 UI 做兜底。

第四，凡是宿主 API、支付面板、编辑器导出、运行时上下文、事件桥和默认 runtime ports 这类“离开 Eggy 就不存在”的逻辑，都应停留在 `src/infrastructure/runtime` 或 `src/app/bootstrap` 一侧，不再回流到内层目录。

第五，`game.bankruptcy_feedback_port` 是 `src/game/ports/bankruptcy_feedback_port.lua` 的宿主回调装配点，用来承接“破产后地块被清空”这类展示反馈；systems 通过该 Port 发出稳定语义，具体如何更新场景或 UI，由外层 adapter 决定。

第六，`src/game/flow/output_adapters/legacy_output_mirror.lua` 已退休并删除；UI runtime 状态以 `state.ui_runtime` 为唯一真源，不再维护 root-state 镜像兼容层。

## 后续新增代码时的放置规则

如果你在写“回合推进到下一步应该做什么”，优先放进 `src/game/flow`。

如果你在写“某个玩法规则在业务上允许什么、产出什么”，优先放进 `src/game/systems`。

如果你在写“某个 ViewModel 应该怎么渲染到 UI 节点”，优先放进 `src/presentation`。

如果你在写“程序启动时把哪条宿主能力接成端口”，优先放进 `src/app/bootstrap`；如果你在写“这些宿主能力的具体实现长什么样”，优先放进 `src/infrastructure/runtime`。

如果一个模块既想碰业务规则，又想碰宿主/UI 细节，先停下来拆边界，不要再新增跨层混合模块。
