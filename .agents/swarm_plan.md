# 怪兽卡与导弹卡的启动场景和覆盖补齐

## Summary

当前怪兽卡、导弹卡的基础配置、注册和 domain 冒烟都已经存在，但还缺两块关键收口：

- 缺少可直接复现这两张卡的独立启动场景，`items_target_disrupt` 只是给卡，不是可用来启动验证的定向场景。
- 覆盖不对称：导弹有部分动画桥接断言，怪兽没有；两张卡都没有通过“启动 profile -> 选目标 -> 动画/后续效果”这条完整链路做回归。导弹如果继续参与“动画后提交结果”的规则，也需要把这个契约测死。

本次实现按“新增专用 startup profile + 补齐 runtime/domain/architecture/gameplay 四层覆盖”处理。`items_target_disrupt` 保留为汇总型道具分组 profile，不再承担怪兽/导弹的场景化验证职责。

## Key Changes

### 1. 新增两个专用启动场景

在 `Config/testing/test_profiles.lua` 新增：

- `scenario_monster_staging`
  - 当前玩家仅持有 1 张怪兽卡
  - 前后 3 格内至少有 1 个敌方建筑目标
  - 不预置路障、地雷、乘客，场景只验证“选楼拆楼”
- `scenario_missile_staging`
  - 当前玩家仅持有 1 张导弹卡
  - 前后 3 格内有 1 个敌方建筑目标
  - 目标格预置路障、地雷、至少 1 名玩家占位，确保“拆楼 + 清障碍 + 送医”同场景可复现

这两个 profile 都使用默认地图，不引入新地图或新启动入口。

### 2. runtime 启动配置测试改为显式覆盖怪兽/导弹场景

扩展现有 runtime profile suite，分别断言：

- `scenario_monster_staging` 的玩家位置、背包、目标地块 owner/level 都按预期生效
- `scenario_missile_staging` 除上述外，还要断言目标格上的路障、地雷、占位玩家也被正确 bootstrap
- 保留现有 `all_item_group_profiles_cover_all_items_once` 之类分组测试；新场景不计入“每张卡只出现一次”的 item-group 统计

同时补 1 条 startup policy / release-qa 可接受新 profile 名的回归，避免 profile 只加在配置里却没被启动链路接受。

### 3. 怪兽/导弹执行结果统一补齐集成契约

两张卡继续共用 `demolish_target` choice kind，不引入 `missile_target` 新分支。实现与测试都按这个契约收口。

- 怪兽卡：
  - 保持现有同步拆楼语义
  - 必须显式产出 `monster` action_anim
  - 不产出 `after_action_anim`
- 导弹卡：
  - 保持现有 `missile` action_anim
  - 建筑摧毁、路障/地雷清理可在导弹命中时完成
  - 送医相关的状态提交改为走现有 `after_action_anim -> move_followup.apply_location_effects`
  - 不新增独立位移动画；导弹动画本身就是提交门槛
  - 这样测试上可以明确约束：导弹动画结束前，不写入住院停留等展示驱动状态；动画结束后才提交

这部分需要在导弹执行结果里返回 `after_action_anim = { next_state = "move_followup", next_args = { mode = "apply_location_effects", ... } }`，形状与现有流放卡一致。

### 4. 补齐四层测试覆盖

- `runtime/test_profiles`
  - 新增 monster/missile 两个 profile 的 bootstrap 断言
- `domain/item`
  - 怪兽卡：打开 `demolish_target`、拆楼成功、`action_anim.kind == "monster"`、无 `after_action_anim`
  - 导弹卡：打开 `demolish_target`、拆楼/清障成功、`action_anim.kind == "missile"`、存在 `after_action_anim`
  - 导弹卡新增“动画前后”断言：
    - 动画前：目标玩家 `stay_turns == 0`
    - 执行 `move_followup` 后：目标玩家进入医院停留
- `architecture/cross_module_contract`
  - 在现有 `missile` bridge 断言旁边补 `monster`，确保 `action_anim.play` 对两种 kind 都有稳定桥接
- `gameplay`
  - 用新 startup profile 跑完整使用链路，而不是只直调底层 apply
  - 怪兽：验证从启动场景到目标选择再到建筑销毁的完整流程
  - 导弹：验证从启动场景到目标选择、导弹动画等待、followup 送医提交的完整流程

## Interface Changes

- 新增内部 startup profile 名：
  - `scenario_monster_staging`
  - `scenario_missile_staging`
- 不新增对外 UI API
- 内部执行结果约定补充：
  - 怪兽卡继续只返回 `action_anim`
  - 导弹卡新增 `after_action_anim`，复用现有 `move_followup.apply_location_effects`
- `demolish_target` 继续作为怪兽卡/导弹卡共享的 choice kind；不新增 `missile_target`

## Test Plan

至少覆盖这些场景：

- 启动 `scenario_monster_staging` 后，玩家持有且仅持有怪兽卡，目标建筑在 3 格范围内
- 启动 `scenario_missile_staging` 后，玩家持有且仅持有导弹卡，目标格建筑/路障/地雷/占位玩家全部存在
- 怪兽卡使用后只拆楼，不送医，不产生 followup
- 导弹卡使用后会摧毁建筑并清理该格障碍
- 导弹卡动画结束前不提交医院停留状态
- 导弹卡 followup 执行后才提交住院状态
- `action_anim.play` 对 `monster`、`missile` 都能稳定分发到对应 bridge
- release-qa 模式下显式传入新 profile 名时，启动链路能接受并进入 profile bootstrap

## Assumptions

- “启动配置”按“测试/QA 启动 profile”处理，不改生产道具配置、商店配置或运行时资源映射，因为这些已存在。
- `items_target_disrupt` 继续保留为汇总型 profile，不把怪兽/导弹的专用场景塞回这个 profile。
- 导弹卡不新增独立角色位移动画；本次只把“送医状态提交时机”挂到现有导弹 action_anim 之后。
- 怪兽卡与导弹卡继续共用 `demolish_target` 目标选择协议。
