-- 道具槽拒绝提示的唯一发射口。裁定住 item_slot_click，这里只做「拒因 → 投递」。
-- 拒绝反馈是私人反馈：带 role_id 只投给点击者，宿主端解析不出 role 再回落广播
-- （见 src/app/init.lua 的 presenter）。
local tip_queue = require("src.foundation.tips")
local denial_cfg = require("src.config.content.item_slot_denial")

local M = {}

-- tip_output_port 缺位时回落到 tip_queue 直投（同 event_feed_adapter）。
local function _enqueue(runtime_game, intent)
  local port = runtime_game and runtime_game.tip_output_port or nil
  if port and type(port.enqueue) == "function" then
    return port.enqueue(runtime_game, intent)
  end
  return tip_queue.enqueue(intent)
end

function M.emit(runtime_game, actor_role_id, item_id, reason)
  return _enqueue(runtime_game, {
    text = denial_cfg.text_for_reason(reason),
    duration = denial_cfg.DURATION,
    dedupe_key = denial_cfg.dedupe_key(actor_role_id, item_id, reason),
    role_id = actor_role_id,
    source = "turn.item_slot",
  })
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=f04e42d02c99fcef
scope.0.id=chunk:src/turn/actions/item_slot_denial_tip.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=e546e23aa1af7025
scope.1.id=function:_enqueue
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=16
scope.1.semanticHash=04ba2e555f7470a6
scope.2.id=function:M.emit
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=fd65c58c24fd5e15
]]
