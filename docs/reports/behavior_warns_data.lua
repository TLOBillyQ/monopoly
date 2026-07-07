-- 单源真值：behavior warn 白名单
-- 与 docs/reports/behavior-warns.md 同步
--
-- 匹配规则：去掉日志时间与 [warn] 前缀后做前缀匹配
-- 条目按类别分组，每条只需覆盖共同前缀，不必列举完整消息
return {
  whitelist = {
    -- ── 测试环境：Eggy 宿主组件 / 运行时桩不可用 ──
    ["[Eggy]"] = true,
    ["[entity_pool]"] = true,
    ["[tip_output_port]"] = true,
    ["[tip_queue]"] = true,
    ["ctrl_unit missing BuffStateComp:"] = true,
    ["missing Enums."] = true,
    ["status3d missing remaining-text node:"] = true,
    ["status3d unit missing create_scene_ui_bind_unit:"] = true,

    -- ── 测试环境：音效 / 反馈资源不可用 ──
    ["board_feedback skip play_3d_sound:"] = true,
    ["board_feedback skip play_sfx_by_key:"] = true,

    -- ── 测试环境：黑市购买桩 ──
    ["market paid goods mapping missing:"] = true,
    ["market paid purchase blocked:"] = true,

    -- ── 反面测试：故意触发的权限 / 校验拒绝 ──
    ["auto intent missing actor_role_id"] = true,
    ["choice action blocked by actor check:"] = true,
    ["choice action mismatch:"] = true,
    ["choice action missing actor_role_id:"] = true,
    ["choice action without pending choice:"] = true,
    ["choice route fallback to base_inline:"] = true,
    ["close_popup ignored: popup not active"] = true,
    ["invalid choice option:"] = true,
    ["invalid item option:"] = true,
    ["item slot denied by availability:"] = true,
    ["item_slot click ignored:"] = true,
    ["missing item_id:"] = true,
    ["没有可选择的目标玩家"] = true,
    ["目标玩家不在可选列表中:"] = true,
    ["目标玩家无效:"] = true,
    ["remote_select without choice"] = true,
    ["role->player 映射失败"] = true,
    ["toggle_action_log missing role event channel:"] = true,
    ["ui intent rejected:"] = true,
    ["view_command port missing, intent dropped:"] = true,
    ["ui_button actor_role_id not mapped:"] = true,
    ["ui_button blocked by actor check:"] = true,
    ["ui_button missing actor_role_id:"] = true,
    ["ui_button missing current_role_id:"] = true,

    -- ── 测试自身机制：spec 合成 warn 文案（保留前缀，src 禁用）──
    ["spec_synthetic"] = true,
  }
}
