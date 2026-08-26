-- ui 层入口：二次确认屏状态深模块。实现放在共享的 state 层
-- （src.state.pending_confirmation），因为 turn 层的目标选择超时子系统
-- （target_select_timer / force_skip）也需要观察、清除同一状态，而 turn
-- 不允许依赖 ui（arch 规则 turn_no_ui）。ui 内部一律经本模块引用。
return require("src.state.pending_confirmation")

--[[ mutate4lua-manifest
version=4
projectHash=3b0feaeaac242cda
scope.0.id=chunk:src/ui/state/pending_confirmation.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=6
scope.0.semanticHash=9564605355558545
]]
