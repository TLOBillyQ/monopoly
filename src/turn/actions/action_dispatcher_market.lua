-- market 域 handler：黑市翻页/页签导航。handle_force_skip（choice 强制跳过，走
-- src.turn.deadlines）与黑市无关，因同属「choice 级旁路处理」且体量过小不值得
-- 单开模块而收在这里；回迁/改名需同步 manifest 与多个 dispatch spec，暂以本注释
-- 明示收录口径。
local validator = require("src.turn.actions.validator")
local market_service = require("src.rules.market")
local force_resolve = require("src.turn.deadlines")
local ctx_mod = require("src.turn.actions.context")

local market_handlers = {}

function market_handlers.apply_market_navigation(game, state, action, ctx, choice)
  if not choice or choice.kind ~= "market_buy" then
    return false
  end
  if not validator.validate(action, { game = game, choice = choice }) then
    return false
  end
  if not market_service.choice.apply_navigation(game, choice, action) then
    return false
  end
  ctx.output_ports.sync_pending_choice(state, choice)
  return true
end

function market_handlers.handle_market_navigation(game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not market_handlers.apply_market_navigation(game, state, action, ctx, choice) then
    return { status = "rejected" }
  end
  return { status = "applied" }
end

function market_handlers.handle_force_skip(game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  force_resolve.force_skip(game, state, choice, action.reason or "dispatch")
  return { status = "applied" }
end

return market_handlers

--[[ mutate4lua-manifest
version=4
projectHash=4ed354ae9426569a
scope.0.id=chunk:src/turn/actions/action_dispatcher_market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=b70a9ea1008ce590
scope.1.id=function:market_handlers.apply_market_navigation
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=24
scope.1.semanticHash=1b85e39678a6459a
scope.2.id=function:market_handlers.handle_market_navigation
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=32
scope.2.semanticHash=174e9ac98c64f26d
scope.3.id=function:market_handlers.handle_force_skip
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=38
scope.3.semanticHash=a6997301f4e04fe1
]]
