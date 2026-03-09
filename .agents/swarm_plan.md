- # 测试目录清理与优化方案

  ## 摘要
  - 当前 `tests/` 实际混合了 5 类职责：运行入口、共享脚手架、夹具、架构/文本 guard、行为/契约 suite。目录共有 56 个文件；suite 清单装载 468 个 case，默认 `lua tests/regression.lua` 在 `release_trimmed` 下执行 466 个检查并通过，但通过路径输出噪声过大，失败定位成本偏高。
  - 主要维护热点已经很明确：`gameplay/gameplay.lua` 3126 行并配套 `registry.lua` 与 4 个 slice 壳；`presentation_ui_action_status_part1/2/3.lua` 合计 4837 行并配套聚合壳；`presentation_ui_popup_market.lua` 1048 行；`presentation_ui_action_anim.lua` 961 行。
  - 推荐目标不是改测试语义，而是重做测试“装配方式”：保留 `lua tests/regression.lua` 兼容入口和现有断言结果不变，把测试目录重组为可发现、可分层、可独立运行、可低噪声失败定位的结构。

  ## 关键改动
  1. 重做 runner 与清单真源
  - 新增 `tests/bootstrap.lua`，统一处理 `package.path`、随机种子、测试环境初始化；删除各 runner/guard 文件里重复的 `package.path = package.path .. ...` 拼接。
  - 新增 `tests/catalog.lua` 作为唯一真源，拆成 `behavior_suites`、`contract_suites`、`guard_scripts` 三组；`tests/regression.lua` 只负责 `bootstrap -> behavior -> contract -> guard` 的顺序调度。
  - 保留 `tests/suites/manifest.lua` 一个兼容周期，让它转发到 `catalog.lua`；下一轮清掉所有直接依赖后再删除。
  - Suite 接口统一为 `{ name, layer, kind, tests = {...} }`；case 接口统一为 `{ name, run, disabled_in = { release_trimmed = true }, tags = {...} }`，把当前 `regression.lua` 里按 suite/test 名硬编码过滤的逻辑迁到 case metadata。

  2. 拆共享脚手架，收口 helper 边界
  - `TestHarness.lua` 下沉为 `tests/support/harness.lua`，接口改为 `run_all(suites, opts)`；`opts` 至少支持 `filter`, `reporter`, `capture_logs`。
  - `TestSupport.lua` 按职责拆成 `tests/support/assertions.lua`、`tests/support/patches.lua`、`tests/support/factories/game_factory.lua`、`tests/support/factories/ui_factory.lua`、`tests/support/runtime_helpers.lua`、`tests/support/scenario_helpers.lua`。
  - `tests/internal/guard_support.lua` 迁到 `tests/support/guards/guard_support.lua`；guard 不再挂在 `internal` 这个误导性目录下。
  - 迁移期间保留 `tests/TestSupport.lua` 兼容 facade，但新 suite 禁止继续 require 这个大而全入口；所有大文件拆分完成后删掉 facade。

  3. 按行为簇拆掉巨型 suite，不再保留壳文件
  - `gameplay/gameplay.lua` 直接拆成 7 个真实 suite：`gameplay_bankruptcy_and_tile_owner.lua`、`gameplay_intent_dispatch.lua`、`gameplay_runtime_context.lua`、`gameplay_turn_loop.lua`、`gameplay_auto_runner.lua`、`gameplay_afk_host.lua`、`gameplay_visual_feedback.lua`。
  - 删除 `tests/suites/gameplay/registry.lua` 与 4 个 slice 壳；manifest/case 名字直接来自真实 suite，不再靠索引区间维护。
  - `presentation_ui_action_status_part1/2/3.lua` 改成 9 个真实 suite：`presentation_choice_routes.lua`、`presentation_target_pick.lua`、`presentation_action_log_and_role_context.lua`、`presentation_market_panel.lua`、`presentation_item_slots.lua`、`presentation_action_queue.lua`、`presentation_role_control_lock.lua`、`presentation_status3d_and_turn_effects.lua`、`presentation_popup_and_modal_renderers.lua`、`presentation_player_panels.lua`。
  - 删除 `presentation_ui_action_status.lua` 这个聚合壳；catalog 直接登记拆分后的 suite。
  - `presentation_ui_popup_market.lua` 拆成 `presentation_popup_visibility.lua`、`presentation_ui_touch_policy.lua`、`presentation_market_confirm_flow.lua`、`presentation_market_panel_state.lua`。
  - `presentation_ui_action_anim.lua` 拆成 `presentation_action_anim_core.lua`、`presentation_board_feedback.lua`、`presentation_overlay_compute.lua`。
  - 拆分原则固定：按行为边界拆，不按平均行数切；拆完后不保留“仅转发/仅聚合”的 suite 壳文件。

  4. 把 guard 从“回归尾巴”升级成独立测试车道
  - `dep_rules.lua`、`legacy_path_guard.lua`、`forbidden_globals.lua`、`gameplay_loop_no_ui.lua`、`arch_view_guard.lua` 迁到 `tests/guards/`，保留 CLI 入口能力，但不再放在 `tests/internal/`。
  - `guard_scripts_contract.lua` 继续保留在 contract lane，职责只验证 guard 本身的判定逻辑；真正的 guard 执行放到 guard lane。
  - `architecture_guard_contract.lua`、`arch_view_contract.lua`、`usecase_boundary_contract.lua`、`runtime_ports_contract.lua` 统一归到 contract lane；behavior lane 只放玩法/展示/运行时行为。

  5. 降低通过路径噪声，提升失败可读性
  - `harness` 默认捕获单 case 日志；通过时只打印进度点和摘要，失败时回放该 case 的缓冲日志；`MONO_TEST_VERBOSE=1` 时才输出全量日志。
  - 对当前大量重复的 market mapping / host capability warning 只做计数摘要，不做逐行回显；guard 失败仍保持原始错误文本。
  - 清掉 runner 注释和路径漂移，例如旧的 `.agents/tests/...` 文案，避免继续误导调用方式。

  ## 重要接口变化
  - `tests/catalog.lua` 成为 suite/guard 注册真源。
  - `tests/support/harness.lua` 暴露 `run_all(suites, opts)`，替代当前固定输出行为。
  - Suite table 新增 `layer`、`kind`；case table 新增 `disabled_in`、`tags`。
  - `lua tests/regression.lua` 保持兼容，不要求调用方改命令。

  ## 测试与验收
  - 迁移前后默认 `lua tests/regression.lua` 都必须为绿；当前基线是默认模式输出 `All regression checks passed (466)`。如果数量变化，只能来自 catalog 显式记录的 case 重分类，不能是丢 case。
  - 新增 `behavior`、`contract`、`guard` 三个独立入口，各自可单跑，也能被 `regression.lua` 串起来。
  - 做一次故意失败演练：验证通过路径不回放日志、失败路径只回放失败 case 的缓冲日志。
  - 做一次 inventory 对账：原 `gameplay.lua`、`presentation_ui_action_status_*`、`presentation_ui_popup_market.lua`、`presentation_ui_action_anim.lua` 的 case 名称全部可在新 catalog 中一一映射。
  - 结构验收固定为两条：不再存在 wrapper-only suite；单个 suite 文件不再超过约 800 行，support 文件不再承担多领域职责。

  ## 假设与默认决策
  - 本轮只清理测试目录与 runner，不改 `src/` 生产逻辑语义。
  - 新文件与新模块命名全部使用 `snake_case`；helper 代码继续遵守 `forbidden_globals` 与 `lua_env` 约束，不引入 `tonumber`、`type(...) == "number"` 这类违规写法。
  - 清理过程不回退当前工作树里的未提交修改；如果迁移命中正在被改的 suite，先新增新 suite 并切 catalog，再删除旧入口，避免直接覆盖他人改动。
