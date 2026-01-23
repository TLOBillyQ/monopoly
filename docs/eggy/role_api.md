# 角色（Role）API 用法文档

本文档介绍 Eggy 平台的玩家角色（Role）相关接口，覆盖玩家信息、成就与积分、存档、UI、镜头、音效、商城与结果面板等常用能力。

---

## 核心类型

### RoleID
- **类型**：`integer`
- **说明**：玩家 ID

### Role
- **类型**：`Role`
- **说明**：玩家对象，常见来源为事件回调或 `GameAPI.get_role(RoleID)`

### Vector3
- **类型**：`{x: Fixed, y: Fixed, z: Fixed, pitch: Fixed, yaw: Fixed}`
- **说明**：三维坐标与朝向，用于动态文本、存档点等

### ENode / ELabel / EImage / EButton / EProgressbar / EInputField
- **类型**：UI 节点类型
- **说明**：UI 控制相关接口使用的节点 ID 类型（详见 UI 相关文档）

---

## API 说明

### 成就与积分

#### Role.add_achievement_progress(event_id, add_count)
增加成就进度。

**参数**：
- `event_id`：`Achievement` - 成就 ID
- `add_count`：`integer` - 增加值

---

#### Role.get_achievement_progress(event_id)
获取成就进度。

**参数**：
- `event_id`：`Achievement`

**返回值**：`integer`

---

#### Role.set_achievement_progress(event_id, count)
设置成就进度。

**参数**：
- `event_id`：`Achievement`
- `count`：`integer`

---

#### Role.is_achievement_completed(event_id)
判断成就是否完成。

**参数**：
- `event_id`：`Achievement`

**返回值**：`boolean`

---

#### Role.add_score(add_score)
增加玩家积分。

**参数**：
- `add_score`：`integer`

---

#### Role.get_score()
获取玩家积分。

**返回值**：`integer`

---

#### Role.set_score(score)
设置玩家积分。

**参数**：
- `score`：`integer`

---

### 存档与进度

#### Role.has_saved_archive()
是否存在存档。

**返回值**：`boolean`

---

#### Role.get_archive_by_type(archive_type, key)
读取存档数据（按类型）。

**参数**：
- `archive_type`：`Archive`
- `key`：`string`

**返回值**：`any`

---

#### Role.set_archive_by_type(archive_type, key, val)
写入存档数据（按类型）。

**参数**：
- `archive_type`：`Archive`
- `key`：`string`
- `val`：`any`

---

#### Role.get_archive_sheetid(key)
读取存档表格 ID。

**参数**：
- `key`：`string`

**返回值**：`SheetID | nil`

---

#### Role.set_archive_sheetid(key, val)
写入存档表格 ID。

**参数**：
- `key`：`string`
- `val`：`SheetID`

---

#### Role.set_archive_point(position, priority, direction)
设置存档点。

**参数**：
- `position`：`Vector3`
- `priority`：`integer` - 优先级
- `direction`：`Vector3` - 朝向

---

### 玩家信息与状态

#### Role.get_roleid()
获取玩家 ID。

**返回值**：`RoleID`

---

#### Role.get_name()
获取玩家名称。

**返回值**：`string`

---

#### Role.get_head_icon()
获取头像资源信息。

**返回值**：`string | integer | nil`

---

#### Role.get_camp()
获取玩家阵营。

**返回值**：`Camp`

---

#### Role.is_online()
玩家是否在线。

**返回值**：`boolean`

---

#### Role.is_watch_mode()
是否处于观战模式。

**返回值**：`boolean`

---

#### Role.is_won() / Role.is_lost()
获取胜负状态。

**返回值**：`boolean`

---

#### Role.is_map_liked() / Role.is_map_favorited()
玩家是否点赞/收藏当前地图。

**返回值**：`boolean`

---

#### Role.is_gallery_vip() / Role.is_pass_premium_vip()
玩家 VIP 状态。

**返回值**：`boolean`

---

#### Role.is_subscribed_map_author()
是否订阅了地图作者。

**返回值**：`boolean`

---

#### Role.get_voice_volume()
获取语音音量。

**返回值**：`Fixed`

---

### 控制与观战

#### Role.get_ctrl_unit()
获取当前控制单位。

**返回值**：`Unit`

---

#### Role.set_role_ctrl_enabled(enable)
开启或关闭角色控制。

**参数**：
- `enable`：`boolean`

---

#### Role.enter_watch_mode(camp_limit, exit_visible)
进入观战模式。

**参数**：
- `camp_limit`：`CampID` - 阵营限制
- `exit_visible`：`boolean` - 退出按钮是否显示

---

#### Role.exit_watch_mode()
退出观战模式。

---

### 镜头与画面

#### Role.get_camera_direction() / Role.get_camera_rotation()
获取镜头方向/旋转。

**返回值**：`Vector3`

---

#### Role.reset_camera(reset_angle, reset_bind, reset_point, reset_prop_pitch)
重置镜头状态。

---

#### Role.set_camera_rotation_by_direction(target_dir, duration)
将镜头旋转到指定方向。

**参数**：
- `target_dir`：`Vector3`
- `duration`：`Fixed`

---

#### Role.set_camera_bind_mode(mode)
设置镜头绑定模式（详见枚举）。

---

#### Role.set_camera_draggable(draggable)
设置镜头是否可拖拽。

---

#### Role.set_camera_lock_position(pos)
锁定镜头位置。

---

#### Role.set_camera_projection_type(projection_type)
设置镜头投影类型（详见枚举）。

---

#### Role.set_camera_property(property, value)
设置镜头属性（详见枚举）。

---

#### Role.pause_camera_motor() / Role.resume_camera_motor() / Role.stop_camera_motor()
暂停/恢复/停止镜头马达。

---

#### Role.shake_camera(shake_type, shake_max_amplitude, shake_time, shake_source, shake_frequency, shake_time_decay, shake_effect_scope, shake_undamped_scope, shake_distance_decay)
镜头震动。

---

### UI 控制

#### Role.set_uipreset_visible(ui, visible)
设置 UI 预设整体可见性。

---

#### Role.set_node_visible(node, visible) / Role.set_node_touch_enabled(node, touch_enabled)
设置节点可见性与触摸。

---

#### Role.set_ui_opacity(node, opacity)
设置节点透明度。

---

#### Role.set_button_enabled(button, enabled)
设置按钮可用性。

---

#### Role.set_button_text(button, text) / set_button_text_color(button, text_color)
设置按钮文本与颜色。

---

#### Role.set_button_font_size(key, font_size)
设置按钮字体大小。

---

#### Role.set_button_normal_image(button, image_key) / set_button_pressed_image(button, image_key)
设置按钮图片。

---

#### Role.set_label_text(label, text)
设置文本内容。

---

#### Role.set_label_color(label, color, transition_time)
设置文本颜色。

---

#### Role.set_label_font(label, font_key) / set_label_font_size(label, font_size, transition_time)
设置文本字体与字号。

---

#### Role.set_label_background_color(label, color, transition_time)
设置文本背景颜色。

---

#### Role.set_label_background_opacity(label, opacity, transition_time)
设置文本背景透明度。

---

#### Role.set_label_outline_enabled(label, enable)
启用文本描边。

---

#### Role.set_label_outline_color(label, color) / set_label_outline_width(label, width)
设置描边颜色/宽度。

---

#### Role.set_label_shadow_enabled(label, enable)
启用文本阴影。

---

#### Role.set_label_shadow_color(label, color)
设置阴影颜色。

---

#### Role.set_label_shadow_x_offset(label, offset) / set_label_shadow_y_offset(label, offset)
设置阴影偏移。

---

#### Role.unbind_label_text(label)
解除文本绑定。

---

#### Role.set_image_texture_by_key_with_auto_resize(image, image_key, reset_size)
设置图片资源并自动调整尺寸。

---

#### Role.set_image_texture_with_auto_resize(image, image_path, reset_size)
设置图片路径并自动调整尺寸。

---

#### Role.set_image_color(image, image_color, transition_time)
设置图片颜色。

---

#### Role.set_input_field_text(input_field, text)
设置输入框内容。

---

#### Role.set_progressbar_current(progress_bar, current)
设置进度条当前值。

---

#### Role.set_progressbar_max(progress_bar, max) / set_progressbar_min(progress_bar, min)
设置进度条上下限。

---

#### Role.set_progressbar_transition(progress_bar, current, transition_time)
设置进度条过渡动画。

---

#### Role.unbind_progressbar_current(progress_bar) / unbind_progressbar_max(progress_bar)
解除进度条绑定。

---

#### Role.set_animation_state(node, animation_name, state)
设置 UI 动画状态。

---

#### Role.reset_animation(node)
重置 UI 动画。

---

#### Role.play_ui_effect(effect_node) / Role.stop_ui_effect(effect_node)
播放/停止 UI 特效。

---

#### Role.show_tips(content, duration)
弹出提示文本。

---

#### Role.show_dynamic_text(text, pos, color, duration, anim_type)
显示动态文字。

---

#### Role.show_bag_panel(visible)
显示/隐藏背包面板。

---

#### Role.show_like_panel()
显示点赞面板。

---

#### Role.show_ultimate_ability_panel(keep_time)
显示必杀技面板。

---

### 音效与震动

#### Role.play_2d_sound_with_params(event_id, duration, volume, speed)
播放 2D 音效。

---

#### Role.stop_2d_sound(sound_instance_id)
停止 2D 音效。

---

#### Role.play_screen_sfx(sfx_key, duration, rate)
播放屏幕特效。

---

#### Role.play_montage(montage_key, start_time, play_to_end, play_time)
播放剧情动画。

---

#### Role.stop_montage(montage_key, has_black_screen)
停止剧情动画。

---

#### Role.skip_current_montage(has_black_screen)
跳过当前剧情动画。

---

#### Role.start_vibration(vibrate_type, vibrate_count, vibrate_interval)
触发震动。

---

#### Role.set_voice_volume_sync_enabled(enabled)
语音音量是否同步。

---

### 商城与广告

#### Role.set_goods_panel_visible(visible)
显示/隐藏商城面板。

---

#### Role.set_goods_visible(goods_key, visible)
控制商品在商城中的展示。

---

#### Role.show_goods_purchase_panel(raw_goods_id, show_time)
弹出指定商品购买界面。

---

#### Role.play_advertisement_with_event(success_event, fail_event, ad_tag, success_data, fail_data)
播放广告并监听成功/失败事件。

---

### 角色效果与可见性

#### Role.set_unit_visible(unit, is_visible)
设置单位可见性。

---

#### Role.set_unit_mask(unit, color)
设置单位遮罩颜色。

---

#### Role.set_unit_outline(unit, width, color)
设置单位描边。

---

#### Role.set_unit_fresnel(unit, fresnel_scale, color, intensity)
设置单位菲涅耳效果。

---

#### Role.set_unit_fresnel_gradual(unit, fresnel_scale, color, intensity, duration)
渐变设置菲涅耳效果。

---

#### Role.disable_unit_mask(unit) / Role.disable_unit_outline(unit) / Role.disable_unit_fresnel(unit)
关闭单位效果。

---

#### Role.set_unit_see_through_enabled(unit, enabled)
开启或关闭透视显示。

---

#### Role.set_name_visible(visible)
设置玩家名是否可见。

---

### 结果与投票

#### Role.win() / Role.lose()
触发胜利/失败结算。

---

#### Role.game_win_and_show_result_panel() / Role.game_lose_and_show_result_panel()
触发胜负并展示结算面板。

---

#### Role.start_level_vote(level_key)
发起关卡投票。

---

### 其他

#### Role.consume_commodity(commodity_id, num)
消耗道具。

---

#### Role.has_commodity(commodity_id) / Role.get_commodity_count(commodity_id)
检查道具/道具数量。

---

#### Role.send_track_data_change(track_data_key, change_num)
上报埋点数据变化。

---

#### Role.send_ui_custom_event(event_name, data)
发送 UI 自定义事件。

---

#### Role.set_battle_shop_visible(battle_shop_id, visible)
显示/隐藏战斗商店。

---

#### Role.set_blind_corner(enable, strength, color)
设置黑角效果。

---

#### Role.set_bagslot_related_lifeentity(bag_slot, life_entity)
绑定背包槽位与生命体。

---

## 事件

### EVENT.ANY_ROLE_SCORE_UPDATE
任意玩家积分变化事件。

**事件类型**：全局触发器事件  
**回调参数**：
- `role`：`Role` - 触发玩家
- `old_role_score`：`integer`
- `new_role_score`：`integer`

---

### EVENT.SPEC_ROLE_ACHIEVEMENT_COMPLETE
指定玩家完成成就事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID` - 目标玩家

**回调参数**：
- `role`：`Role`
- `achieve_id`：`Achievement`

---

### EVENT.SPEC_ROLE_ACHIEVEMENT_REWARD_GAIN
指定玩家领取成就奖励事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`
- `_achievement`：`Achievement`

**回调参数**：
- `role`：`Role`
- `achieve_id`：`Achievement`

---

### EVENT.SPEC_ROLE_CAMP_CHANGE
指定玩家阵营变化事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`

**回调参数**：
- `role`：`Role`
- `camp_before_change`：`Camp`
- `camp_after_change`：`Camp`

---

### EVENT.SPEC_ROLE_EXIT_GAME
指定玩家离开游戏事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`

**回调参数**：
- `role`：`Role`

---

### EVENT.SPEC_ROLE_GAME_LOSE / EVENT.SPEC_ROLE_GAME_WIN
指定玩家失败/胜利事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`

**回调参数**：
- `role`：`Role`

---

### EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_FAILURE / EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_SUCCESS
指定玩家播放广告失败/成功事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`
- `_ad_tag`：`string`

---

### EVENT.SPEC_ROLE_PURCHASE_GOODS
指定玩家成功购买商品事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`

**回调参数**：
- `role`：`Role`
- `goods_id`：`UgcGoods`

---

### EVENT.SPEC_ROLE_VOICE_VOLUME_CHANGE
语音音量变化事件。

**事件类型**：全局触发器事件  
**注册参数**：
- `_role`：`RoleID`

**回调参数**：
- `voice_volume`：`Fixed`

---

## 注意事项

1. **本地玩家调用**：UI、镜头、音效等接口通常需要在本地玩家 `Role` 上调用
2. **UI 节点类型**：传入的节点类型必须与控件类型匹配，避免无效调用
3. **镜头与震动**：镜头控制与震动属于强干预效果，建议加条件或限时撤销
4. **存档一致性**：存档 key/类型需与策划约定一致，避免覆盖其它系统数据
5. **事件主体**：Role 相关事件多为全局触发器事件，注册时注意传入 RoleID

---

## 组合示例

目标：为指定玩家加分并监听积分变化，触发提示。

```lua
Role.add_score(10)

LuaAPI.global_register_trigger_event(
    {EVENT.ANY_ROLE_SCORE_UPDATE},
    function(event_name, actor, data)
        GlobalAPI.show_tips("积分变化: " .. data.new_role_score, 2.0)
    end
)
```

---

## 相关文档

- `docs/eggy/goods_api.md`
- `docs/eggy/event_api.md`
- `docs/eggy/ui_manager_lib.md`
- `docs/eggy/api/07_unit_entities.md`
- `docs/eggy/api/09_events.md`
