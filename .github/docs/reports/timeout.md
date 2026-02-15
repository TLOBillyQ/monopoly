# 超时规则

本模块管理两类超时：选择超时和弹窗超时。

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `constants.action_timeout_seconds` | 10 | 全局超时上限（秒） |
| `gameplay_rules.auto_choice_min_visible_seconds` | 3.0 | 托管玩家选择最小展示时长（秒） |
| `gameplay_rules.auto_popup_min_visible_seconds` | 3.0 | 托管玩家弹窗最小展示时长（秒） |

## 超时禁用

*给定* action_timeout_seconds <= 0
*当* 调用任意超时 “下一步” 函数
*那么*  清零所有计时状态，不执行任何超时逻辑

## 选择超时（step_choice_timeout）

### 新选择出现时重置计时

*给定* 一个待处理选择 pending_choice 存在
*当* 该选择是首次出现（ID 与当前记录不同）
*那么*  记录该选择，将 pending_choice_elapsed 重置为 0，
     并调用 opts.on_pending_choice 回调通知上层

### 选择消失时清零

*给定* pending_choice 不再存在
*当* 执行 “下一步”
*那么*  清空 pending_choice、pending_choice_id，将 elapsed 归零

### 选择未激活时清零

*给定* pending_choice 存在但 opts.is_choice_active 返回 false
*当* 执行 “下一步”
*那么*  将 elapsed 和 pending_choice_id 归零，不触发超时

### 托管快速超时

*给定* 选择处于激活状态
  *且* 累计时间 elapsed >= auto_choice_min_visible_seconds（3秒）
  *且* 选择的所有者是（agent.is_auto_player）
*当* 执行 “下一步”
*那么*  通过 opts.build_action 构建动作并立即执行，
     关闭选择界面，重置 elapsed 为 0

### 通用超时

*给定* 选择处于激活状态
  *且* 累计时间 elapsed >= action_timeout_seconds（10秒）
  *且* 未被托管玩家快速超时提前处理
*当* 执行 “下一步”
*那么*  通过 opts.build_action 构建动作并执行（该动作必须非 nil），
     关闭选择界面，重置 elapsed 为 0

### 默认动作构建

*给定* 需要为选择构建超时默认动作
*当* agent.auto_action_for_choice 返回有效动作
*那么*  使用该智能动作

*给定* 需要为选择构建超时默认动作
*当* agent.auto_action_for_choice 返回 nil
*那么*  选择 choice.options[1]（第一个选项）

## 弹窗超时（step_modal_timeout）

### 弹窗未激活时清零

*给定* opts.is_active 返回 false
*当* 执行 “下一步”
*那么*  将 ui_modal_elapsed 和 ui_modal_ref 归零

### 弹窗切换时重置

*给定* 弹窗处于激活状态
  *且* 当前弹窗引用（opts.get_ref）与上次记录不同
*当* 执行 “下一步”
*那么*  更新 ui_modal_ref，将 ui_modal_elapsed 重置为 0

### 托管玩家弹窗缩短超时

*给定* 弹窗处于激活状态（popup_active = true，input_blocked = false）
  *且* 弹窗所有者是托管玩家
  *且* auto_popup_min_visible_seconds > 0
*当* 通过 opts.get_timeout_seconds 获取超时时长
*那么*  返回 auto_popup_min_visible_seconds（3秒）作为超时时长

### 非托管玩家弹窗使用默认超时

*给定* 弹窗处于激活状态
  *且* 弹窗所有者不是托管玩家（或无法确定）
*当* 通过 opts.get_timeout_seconds 获取超时时长
*那么*  返回 nil，回退到 action_timeout_seconds（10秒）

### 弹窗超时触发

*给定* 弹窗处于激活状态
  *且* 累计时间 ui_modal_elapsed >= 当前超时时长
*当* 执行 “下一步”
*那么*  调用 opts.on_timeout（默认关闭弹窗），重置 elapsed 为 0

## 状态字段

### 选择超时
- `state.pending_choice` — 当前待处理选择对象
- `state.pending_choice_id` — 当前选择 ID（检测变化用）
- `state.pending_choice_elapsed` — 累计等待秒数

### 弹窗超时
- `state.ui_modal_ref` — 当前弹窗引用标识（检测变化用）
- `state.ui_modal_elapsed` — 累计显示秒数
