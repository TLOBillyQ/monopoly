-- 验收步骤绑定聚合器（消费仓数据面，测试极简化决策 / #192 / #193）。
-- 验收引擎 tools/packages/acceptance/steps.lua 按约定 dofile 本文件，把返回的
-- handlers 并入 builtin（mutator_status）之上。
-- 各域绑定一 feature 域一文件，用 packages.acceptance.step_dsl 书写；新增域在
-- _MODULES 里加一行。合并冲突（同句面两处定义）由 dsl.merge 直接报错。

local dsl = require("packages.acceptance.step_dsl")

local _MODULES = {
  "common",
  "setup",
  "dice",
  "movement",
  "turn_flow",
  "economy",
  "market",
  "market_cash",
  "paid_currency",
  "bankruptcy",
  "endgame",
  "leaderboard",
  "role_attribute_coins",
  "achievements",
  "sign_in",
  "share_task",
  "action_log_toggle",
  "items",
  "chance",
  "deities",
  "item_atlas",
  "unusable_card_tip",
  "skin_shop",
  "base_screen",
  "panel_interrupt",
  "card_reveal_broadcast",
  "auto_button_share",
  "share_button",
  "like_collect_subscribe",
  "item_slot_highlight_replay",
}

local _DIR = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$")

local handlers = {}
for _, name in ipairs(_MODULES) do
  handlers = dsl.merge(handlers, dofile(_DIR .. "/" .. name .. ".lua"), name)
end

return handlers
