# move.lua 转向补充可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，所有调整都必须保持该规范。

## 目的 / 全局视角

本改动的目标是在棋子移动时补齐“先转向再移动”的行为，并把移动动画模块改成更清晰的命名并接入 gameplay 的 move_anim 流程。完成后，`src/adapters/eggy/move_anim.lua` 负责单步移动动画，`turn_move` 写入的 `move_anim` 数据会被 Eggy 适配层消费并触发动画，角色会先朝向 `v3_dir` 再执行 `start_move_by_direction`，避免出现移动方向与朝向不一致的情况。验收方式是运行 Demo（或触发 `move_anim` 流程的场景）观察棋子在移动前转向，并且 Lua 回归测试保持通过。

## 进度

- [x] (2026-01-28 01:10Z) 创建转向计划并确认 `move_anim.one_step` 的调用链。
- [x] (2026-01-28 01:20Z) 在 `move_anim.one_step` 中补齐朝向设置逻辑。
- [x] (2026-01-28 01:35Z) 兼容 yaw 角度转换函数，避免运行时缺失。
- [x] (2026-01-28 02:05Z) 重命名 move.lua 为 move_anim.lua 并更新引用。
- [x] (2026-01-28 02:12Z) 接入 gameplay 的 move_anim 数据到 Eggy 适配层动画播放。
- [ ] (2026-01-28 02:20Z) 运行 Lua 测试与 Demo 验收并记录结果。
- [ ] (2026-01-28 01:40Z) 补齐 Lua 运行环境或在可运行环境补跑测试与截图。

## 意外与发现

当前环境缺少 `lua` 运行时，执行 `lua tests/deps_check.lua` 返回 “Command 'lua' not found”。需要在具备 Lua 的环境补跑测试。
尝试使用 `apt-get` 安装 Lua 时因权限不足失败；同时仓库内未包含 `bin/windows/Game.exe`，当前环境无法直接运行 Demo 截图。

## 决策日志

- 决策：优先使用 `LifeEntity.set_direction` 设置朝向，缺失时回退到 `Unit.set_orientation`。
  理由：`set_direction` 能直接用方向向量设置角色面向，最符合 move.lua 语义；回退到 `set_orientation` 可覆盖仅暴露 Unit 接口的对象。
  日期/作者：2026-01-28 / Codex
- 决策：使用 `math.atan2` 计算 yaw 并配合 `math.rad_to_deg` 转角度。
  理由：引擎接口 `math.Quaternion(pitch, yaw, roll)` 使用角度值，现有宏中也以度数创建四元数。
  日期/作者：2026-01-28 / Codex
- 决策：在 `math.rad_to_deg` 缺失时回退到 `math.deg` 或手动换算。
  理由：避免运行时未实现 `math.rad_to_deg` 导致转向逻辑失败。
  日期/作者：2026-01-28 / Codex
- 决策：在适配层接入 `move_anim` 时使用回调返回动画时长，并由适配层延迟派发 move_anim_done。
  理由：保证 gameplay 等待动画完成后再继续流程，避免视觉与逻辑不同步。
  日期/作者：2026-01-28 / Codex

## 结果与复盘

已完成转向逻辑实现并兼容角度转换，待在可运行 Lua 的环境中执行测试与 Demo 验收。完成后需要补充测试输出与视觉验收记录，同时提供 UI 截图证据。

## 背景与导读

移动演示逻辑位于 `src/adapters/eggy/move_anim.lua`，由 `src/adapters/eggy/init.lua` 的延迟回调触发 `move_anim.one_step`。Gameplay 的 `turn_move.lua` 会写入 `move_anim` 数据并进入 `wait_move_anim`，适配层需读取该数据并播放移动动画。`move_anim.one_step` 通过 `G.tiles` 计算起止位置与移动时长，并调用 `G.unit[player_id].start_move_by_direction` 执行移动。本改动在移动前补齐朝向设置，并接入 `move_anim` 数据驱动，保持现有移动时长与路径计算不变。

## 工作计划

先确认 `move_anim.one_step` 的输入为 `v3_dir` 且来自棋盘移动方向，然后在 `src/adapters/eggy/move_anim.lua` 中插入朝向设置逻辑。优先调用 `unit.set_direction(v3_dir)`，如果不存在则通过 `math.atan2` 计算 yaw，调用 `unit.set_orientation(math.Quaternion(0, yaw_deg, 0))`。随后在 `src/adapters/eggy/eggy_layer.lua` 中消费 `move_anim` 数据并触发 `move_anim.one_step`，实现 gameplay -> 适配层的移动动画接入。保持 `start_move_by_direction` 的调用参数与时长计算不变。最后补跑 Lua 测试并执行 Demo 验证棋子转向效果。

## 具体步骤

在仓库根目录执行：

1. 定位 `move_anim.one_step` 实现并确认调用入口：
     rg -n "move_anim" src/adapters/eggy
2. 修改 `src/adapters/eggy/move_anim.lua`，在 `start_move_by_direction` 前插入朝向设置逻辑（`set_direction` 或 `set_orientation`）。
3. 修改 `src/adapters/eggy/eggy_layer.lua`，在 `AdapterLayer.step_move_anim` 回调中调用 `move_anim.one_step`。
4. 运行测试：
     lua tests/deps_check.lua
     lua tests/regression.lua
5. 启动 Demo（如 `bin/windows/Game.exe` 或现有演示入口），观察棋子在移动前转向正确。

## 验证与验收

运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`，预期输出包含 “Dependency self-check passed” 与 “All regression checks passed”。启动 Demo 后，触发 `move_anim`（例如 `src/adapters/eggy/init.lua` 的延迟调用或回合移动），观察棋子在移动前朝向 `v3_dir`，移动过程中方向一致。

## 可重复性与恢复

改动影响 `src/adapters/eggy/move_anim.lua`、`src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/core/adapter_layer.lua`，无数据迁移。若出现行为异常，可通过 `git checkout -- <file>` 回滚；测试命令可重复执行，不影响运行环境。

## 产物与备注

产物包括 `src/adapters/eggy/move_anim.lua` 的转向逻辑更新，以及 Eggy 适配层对 `move_anim` 的接入。

    -- 新增逻辑示例（片段）
    local unit = G.unit[player_id]
    if unit.set_direction then
        unit.set_direction(v3_dir)
    end

## 接口与依赖

依赖 `LifeEntity.set_direction(face_dir)` 或 `Unit.set_orientation(rot)`；数学转换使用 `math.atan2` 与 `math.rad_to_deg`，四元数构造使用 `math.Quaternion(pitch, yaw, roll)`。移动仍由 `start_move_by_direction(direction, duration)` 驱动，`WALK_SPEED` 等常量继续来自 `src/adapters/eggy/macro.lua`。适配层通过 `AdapterLayer.step_move_anim` 读取 gameplay 的 `move_anim` 数据并驱动动画。

附记：首次创建本计划，用于补齐 move.lua 转向行为与验收路径。
