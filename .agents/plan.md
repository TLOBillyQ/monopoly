-  # Plan: show_tips 去冗余与独立队列化

    ## Summary

    - 现状的根问题不是“某几个 tip 重复”，而是 logger 同时承担了事件日志、tip 队列、宿主 presenter、调
      度器四个职责，导致日志副作用直接变成 tip，且回合等待也反查 logger：src/core/utils/
      logger.lua:16、src/turn/waits/await.lua:375、src/turn/policies/timer_policy.lua:178。
    - 本次按你锁定的产品决策落地：保留 action log + tip 双通道；同地块路障+地雷只出 1 条汇总 tip；tip
      仍可阻塞，但只阻塞切回合前；去重按语义键。
    - 方案不执行 .agents/plan.md 那个“大一统新事件系统硬切”；这里只做一次外科式拆分：把 tip 从 logger/
      gameplay 里剥出来，先变成独立队列系统，再迁移当前 tip 生产者。

    ## Public API / Contract Changes

    - 新增纯队列契约模块 src/core/utils/tip_queue.lua，只负责：
        - enqueue(intent)
        - has_blocking_pending(phase_name)
        - clear()
        - configure_runtime(adapter)
    - intent 统一字段拍板为：
        - text
        - duration
        - dedupe_key
        - blocks_inter_turn
        - source
        - chain_key
    - 语义去重规则拍板为：同一 dedupe_key 在 active/queued 生命周期内采用 first-wins；后续重复项直接丢
      弃，不刷新文案、不延长时长。
    - logger 退回“日志系统”本职：删除 tip 队列职责，logger.event(...) 只写 event feed，不再隐式弹
      tip；logger.clear() 不再清理 tip 队列。
    - src/host/eggy/init.lua:19 保留 show_tips(text, duration) 兼容入口，但它只作为队列适配入口；新增
      结构化 enqueue_tip(intent)；Presenter 方向固定为 host_runtime.show_tips/enqueue_tip -> tip_queue
      -> GlobalAPI.show_tips，禁止反向回调。

    ## Tasks

    ### T1a: 冻结独立 tip 队列契约

    - depends_on: []
    - location: src/core/utils/logger.lua:16
    - description: 新建纯 tip_queue 策略模块，内聚 FIFO、语义去重、blocks_inter_turn、chain_key、epoch
      取消；明确 logger 不再拥有 tip 状态、scheduler、presenter。
    - validation: logger 不再暴露 tip 生命周期能力；tip 队列的 reset/clear 由独立模块接管。

    ### T1b: 先补队列级契约测试

    - depends_on: [T1a]
    - location: tests/suites/runtime/misc_logger.lua:10
    - description: 先把 tip 队列测试独立出来，再做调用方迁移；覆盖 FIFO、semantic dedupe、blocking/
      non-blocking、phase gating、clear 后 stale timeout 不回放。
    - validation: 新 tip 队列测试先红后绿；不依赖 logger 旧行为。

    ### T2: 接好外层 runtime adapter

    - depends_on: [T1a, T1b]
    - location: src/app/bootstrap/init.lua:13, src/host/eggy/init.lua:19, src/ui/runtime/
      host_bridge.lua:27
    - description: 由 bootstrap 把 GlobalAPI.show_tips 和 SetTimeOut 注入 tip_queue；tip_queue 本体不
      直接碰 Eggy 全局。保留 show_tips(text, duration) 兼容入口，默认映射为 blocks_inter_turn=false 的
      简单 tip；新增 enqueue_tip(intent) 给结构化调用方。
    - validation: 兼容调用不递归、不双发；queue core 不直接依赖 GlobalAPI/SetTimeOut。

    ### T3: 审计并迁移现有 tip 生产者

    - depends_on: [T2]
    - location: src/ui/render/action_anim.lua:197, src/ui/ctl/event_handlers.lua:240, src/ui/ctl/
      event_bindings.lua:12, src/ui/ctl/canvas_event_router.lua:77, src/ui/render/
      anim_unit_overlay.lua:47
    - description: 先列一份 allowlist/denylist。allowlist 保留：显式用户动画 tip、黑市购买失败、局部诊
      断 tip、障碍链汇总 tip。denylist 删除：logger.event -> tip 这种“日志即提示”的副作用。所有保留项
      统一改走结构化 enqueue_tip(intent)。
    - validation: gameplay/rules/turn 层不再因为 logger.event(...) 自动弹 tip；仅 allowlist 源继续产出
      tip。

    ### T4: 把回合阻塞改成“相位感知的 tip gate”

    - depends_on: [T2]
    - location: src/turn/waits/await.lua:375, src/turn/policies/timer_policy.lua:178
    - description: 用 tip_queue.has_blocking_pending("inter_turn") 替换 logger.has_pending_tips()；只
      有 inter_turn 会看 blocking tip，其他 phase 完全不感知 tip 队列。
    - validation: blocking tip 只会阻塞切回合前；non-blocking tip 不影响 choice、landing、action anim
      等 gameplay 流程。

    ### T5: 做路障+地雷链路的单条汇总 tip

    - depends_on: [T2, T3]
    - location: src/ui/render/action_anim.lua:197, src/rules/effects/mine_effect.lua:39, src/rules/
      items/roadblock.lua:216
    - description: 用 chain_key = turn/player_id/tile_index 关联同链路障碍提示；roadblock_trigger 在确
      认后续同链 mine_trigger 时只登记链路、不发 tip；mine_trigger 负责发唯一汇总 tip。详细 action log
      保持原样，不合并、不删减。
    - validation: 同地块连续触发时只出 1 条汇总 tip；不同地块、不同链路、不同回合不误合并。

    ### T6: 回归测试与旧耦合清理

    - depends_on: [T3, T4, T5]
    - location: tests/suites/gameplay/gameplay_obstacle_chain_order.lua:90, tests/suites/gameplay/
      gameplay_coroutine.lua:468, tests/suites/gameplay/gameplay_cases.lua:3370
    - description: 更新 logger/runtime/startup/support 夹具；把“inter-turn 因 tip 队列阻塞”的断言迁移
      到新 tip queue；补一条同地块障碍链只弹 1 条汇总 tip 的集成测试；扫描并清掉 logger.show_tip /
      logger.has_pending_tips 残留引用。
    - validation: obstacle chain 仍保持原动画顺序与完整 action log，但 tip 只有 1 条；inter-turn 仍只
      对 blocking tip 生效；旧 logger tip API 引用为 0。

    ## Parallel Waves

    - Wave 1: T1a
    - Wave 2: T1b, T2
    - Wave 3: T3, T4
    - Wave 4: T5
    - Wave 5: T6

    ## Test Plan

    - 队列单测：FIFO、semantic dedupe、mixed blocking/non-blocking、phase gating、clear 后 stale
      timeout 不回放。
    - 兼容单测：host_runtime.show_tips 与 bootstrap presenter 链路不递归、不双发。
    - 展示层回归：src/ui/render/action_anim.lua:197 的显式 tip 改走队列；src/ui/ctl/
      event_handlers.lua:240 的黑市失败仍只有 1 条 tip；本地诊断 tip 仍可显示。
    - gameplay 回归：src/turn/waits/await.lua:375 与 src/turn/policies/timer_policy.lua:178 只在
      inter_turn 看 blocking tip；tests/suites/gameplay/gameplay_obstacle_chain_order.lua:90 保持日志
      完整、tip 变单条。
    - logger 回归：event feed 仍完整，但 logger.event(...) 不再隐式产出 tip。

    ## Assumptions

    - 本轮只做 tip 系统拆分，不顺手推进 .agents/plan.md 的全仓事件系统硬切。
    - show_tips(text, duration) 暂时保留为兼容适配入口，但业务 tip 生产者统一迁到结构化
      enqueue_tip(intent)。
    - “重复”优先按同语义事件治理，而不是按字符串硬匹配；因此 dedupe_key/chain_key 是本次方案的强约束。
    - 阻塞策略固定为：仅切回合前等待 blocking tip；其他阶段不因 tip 队列暂停。

    ## 进度

    - [x] 2026-03-23 17:00 - T1a 完成：新增 `src/core/utils/tip_queue.lua`，`logger` 已剥离 tip 状态与 event 侧自动弹 tip，`logger.event(...)` 只写 event feed。
    - [x] 2026-03-23 17:00 - 已做最小验证：`luac.exe -p src/core/utils/logger.lua`、`luac.exe -p src/core/utils/tip_queue.lua`、`lua.cmd` 队列去重/阻塞探针、`lua.cmd` logger event 无 tip 探针。
    - [x] 2026-03-23 17:20 - T1b 完成：新增 `tests/suites/runtime/misc_tip_queue.lua`，把 FIFO、semantic dedupe、blocking/non-blocking、phase gating、clear 后 stale timeout 不回放收口到独立队列测试；`misc_logger` 只保留 logger 自身职责断言。
    - [x] 2026-03-23 17:20 - 已做行为回归：`lua tests/behavior.lua`，当前只剩 3 个失败，全部落在后续任务范围内（`item.steal_*` allowlist tip、`await_inter_turn_wait_blocks_until_tip_queue_drains`）。

    ## 意外与发现

    - 观察：现有测试夹具仍会调用 `logger.set_tip_presenter(nil)` 和 `logger.set_scheduler(nil)`；为了不让旧夹具残留 runtime，`tip_queue.configure_runtime` 需要支持显式清空 presenter/scheduler。
      证据：`lua.cmd` 探针通过，且 `logger.event(...)` 不再触发 tip。
    - 观察：`## Parallel Waves` 里把 `T1b, T2` 放同一波，但 `T2` 明确依赖 `T1b`，实际执行顺序必须是 `T1b -> T2`。
      证据：当前计划的 `depends_on: [T1a, T1b]` 与波次描述不一致。
    - 观察：`T1b` 完成后 `lua tests/behavior.lua` 只剩 3 个失败，说明队列拆分本身已稳定，剩余都是 allowlist tip 迁移与 inter-turn gate 语义未接好。
      证据：失败列表仅剩 `tests/suites/domain/item.lua` 两条 tip 用例和 `tests/suites/gameplay/gameplay_coroutine.lua` 一条 inter-turn 用例。

    ## 决策日志

    - 决策：T1a 先保留 `logger.show_tip`、`logger.set_tip_presenter`、`logger.set_scheduler` 作为薄转发，但把实际 tip 生命周期状态迁到 `tip_queue`。
      理由：先切 ownership，再在后续任务里迁移调用方，能把变更面压到最小。
      日期/作者：2026-03-23 / Codex
    - 决策：T1b 不再给 `logger` 追加新的 tip 行为测试，而是把队列契约独立到 `misc_tip_queue`，并把 `misc_logger` 收缩回 event feed / runtime clock / event buffer。
      理由：避免后续清理 `logger.show_tip`、`logger.has_pending_tips` 时被旧测试绑住，符合“logger 退回日志系统本职”的目标。
      日期/作者：2026-03-23 / Codex

    ## 结果与复盘

    - T1a 已把 tip 生命周期从 logger 中抽出，logger 现在专注于 event feed、时间戳和 event buffer。
    - T1b 已把队列语义钉死为独立测试面，后续迁移调用方时不再需要借 logger 间接验证。
    - 下一步进入 T2，把宿主 `show_tips/enqueue_tip` 适配到 `tip_queue`，再接 T3/T4 收掉剩余行为失败。

    2026-03-23 17:00: 本次更新把 tip 状态、调度和展示从 `src/core/utils/logger.lua` 拆到 `src/core/utils/tip_queue.lua`，原因是先冻结独立队列契约，再让后续任务只处理调用方迁移。
    2026-03-23 17:20: 本次更新补上 `tip_queue` 独立测试并收缩 `misc_logger`，原因是先把队列行为固定住，再让后续适配与迁移只关注调用边界。
