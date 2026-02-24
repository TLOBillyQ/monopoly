# 托管按钮无法连续开关问题分析与解决方案

## 问题描述

托管按钮目前无法连续开关。玩家点击托管按钮开启托管后，再次点击无法关闭托管。

## 根本原因分析

### 1. 代码位置

问题位于 `src/presentation/ui/UIPanelPresenter.lua:46`：

```lua
function panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model, local_role_id)
  -- ...
  local auto_enabled = false
  if local_role_id ~= nil then
    auto_enabled = ctx ~= nil and ctx.role_id == local_role_id
  else
    auto_enabled = ctx and ctx.is_player_role == true or false
  end
  -- ...
  local allow_touch = auto_enabled  -- <-- 问题所在
  ui_touch_policy.set_auto_controls_touch(ui, allow_touch, controls)
end
```

### 2. 问题分析

`auto_enabled` 变量的含义是**"当前角色是否是本地角色"**，而非**"托管功能是否已启用"**。

当 `allow_touch = auto_enabled` 时：
- 如果当前角色匹配本地角色，`allow_touch = true`，托管按钮可点击
- 如果当前角色不匹配本地角色，`allow_touch = false`，托管按钮被禁用触控

这导致了问题：当玩家开启托管后，某些情况下（如角色上下文解析变化），`ctx.role_id` 可能与 `local_role_id` 不匹配，导致托管按钮被错误地禁用。

### 3. 与输入锁策略的冲突

`UIInputLockPolicy.apply` 明确将托管按钮设为输入锁的例外：

```lua
-- 业务例外：托管开关与调试开关在输入锁期间仍允许切换。
ui_touch_policy.set_auto_controls_touch(ui, true)
```

但 `UIPanelPresenter.render_auto_controls_for_role` 在 UI 刷新时可能会覆盖这一设置，将托管按钮禁用。

### 4. 竞争条件

在 `GameplayLoop.tick` 中：
1. `refresh_from_dirty` 调用 `UIPanelPresenter.refresh`，进而调用 `render_auto_controls_for_role`
2. 随后可能调用 `apply_input_lock`

如果 `render_auto_controls_for_role` 设置了 `allow_touch = false`，而 `apply_input_lock` 因条件未满足未被调用，托管按钮将保持禁用状态。

## 解决方案

### 修改方案

将 `UIPanelPresenter.lua` 第 46 行：

```lua
local allow_touch = auto_enabled
```

改为：

```lua
local allow_touch = true
```

### 理由

1. **托管按钮应始终可点击**：托管按钮是输入锁的例外，玩家应随时能切换托管状态
2. **与其他代码一致**：`UIInputLockPolicy.apply` 明确将托管按钮设为始终可点击
3. **语义正确**：`allow_touch` 控制的是按钮是否可交互，而不是托管是否启用

### 代码变更

```lua
function panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model, local_role_id)
  assert(ui ~= nil, "missing ui")
  local controls = ui.auto_control_nodes or { ui_nodes.buttons.auto, ui_nodes.labels.auto }
  local auto_enabled = false
  if local_role_id ~= nil then
    auto_enabled = ctx ~= nil and ctx.role_id == local_role_id
  else
    auto_enabled = ctx and ctx.is_player_role == true or false
  end
  local panel = ui_model and ui_model.panel or nil
  local labels_by_player = panel and panel.auto_label_by_player or nil
  local display_player_id = ctx and ctx.display_player_id or nil
  local auto_label = nil
  if labels_by_player and display_player_id ~= nil then
    auto_label = labels_by_player[display_player_id]
  end
  if not auto_label then
    auto_label = panel and panel.auto_label or nil
  end
  if auto_label and ui.set_label then
    ui:set_label(ui_nodes.labels.auto, auto_label)
  end
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
  local allow_touch = true  -- 托管按钮始终可点击
  ui_touch_policy.set_auto_controls_touch(ui, allow_touch, controls)
end
```

## 验证步骤

1. 启动游戏进入对局
2. 点击托管按钮开启托管（按钮应显示激活状态）
3. 立即再次点击托管按钮关闭托管（按钮应恢复正常状态）
4. 重复多次开关托管，验证可以连续切换
5. 在动画播放期间（输入锁开启）尝试开关托管，验证仍然有效

## 相关文件

- `src/presentation/ui/UIPanelPresenter.lua` - 主要修改文件
- `src/presentation/interaction/UIInputLockPolicy.lua` - 输入锁策略（已正确实现）
- `src/presentation/interaction/UITouchPolicy.lua` - 触控策略工具
