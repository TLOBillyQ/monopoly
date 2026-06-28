-- base_screen step-handler support: lookup tables for Chinese step tokens.
--
-- Behavior-preserving extraction of the Gherkin-keyed lookup tables out of
-- base_screen/context.lua so the support layer is split into focused seams.
-- Pure data: each table maps a Chinese step token used by the feature files to
-- a constant. No side effects; depends only on the base schema node names.

local base_nodes = require("src.ui.schema.base")

local state_tables = {}

state_tables.SKIN_ENTRY_NODES = {
  ["按钮"] = base_nodes.skin_button,
  ["文字"] = base_nodes.skin_label,
}

state_tables.AUXILIARY_ENTRY_NODES = {
  ["道具图鉴"] = base_nodes.gallery_button,
  ["托管按钮"] = base_nodes.auto_button,
  ["行动日志"] = base_nodes.action_log_button,
}

state_tables.OPTIONAL_ACTION_KIND_BY_NAME = {
  ["道具槽位"] = "item_phase_passive",
  ["选择控件"] = "item_phase_passive",
  ["落地选择"] = "landing_optional_effect",
}

state_tables.FOLLOWUP_BY_OPTIONAL_ACTION = {
  ["道具槽位"] = "投骰移动落地流程",
  ["选择控件"] = "必经流程",
  ["落地选择"] = "回合清理流程",
}

state_tables.BLOCKING_STATE_BY_NAME = {
  ["选择弹窗"] = true,
  ["二次确认弹窗"] = true,
  ["目标选择"] = true,
  ["黑市界面"] = true,
  ["弹窗提示"] = true,
  ["行动动画"] = true,
  ["移动动画"] = true,
  ["落地视觉等待"] = true,
}

state_tables.STAGE_STATE_BY_NAME = {
  ["扣留等待"] = true,
  ["医院等待"] = true,
  ["山路等待"] = true,
  ["回合间等待"] = true,
  ["游戏结束"] = true,
  ["空可选行动阶段"] = true,
}

return state_tables