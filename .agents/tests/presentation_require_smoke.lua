-- presentation require smoke (run: lua .agents/tests/presentation_require_smoke.lua)
local modules = {
  "src.presentation.api.UIView",
  "src.presentation.api.UIEventHandlers",
  "src.presentation.api.UIRuntimePort",
  "src.presentation.render.BoardView",
  "src.presentation.render.MarketView",
  "src.presentation.render.TileRenderer",
  "src.presentation.render.BoardScene",
  "src.presentation.render.ActionAnim",
  "src.presentation.render.MoveAnim",
  "src.presentation.render.BuildingEffects",
  "src.presentation.render.UIStatus3DLayer",
  "src.presentation.ui.UIPanel",
  "src.presentation.ui.UIPanelPresenter",
  "src.presentation.ui.UIModalPresenter",
  "src.presentation.ui.UIChoice",
  "src.presentation.state.UIModel",
  "src.presentation.state.UIModelProjection",
  "src.presentation.state.UIModelPanelBuilder",
  "src.presentation.state.UIRoleContext",
  "src.presentation.state.UIRoleAvatar",
  "src.presentation.interaction.UIEventRouter",
  "src.presentation.interaction.UICanvasCoordinator",
  "src.presentation.interaction.UIModalStateCoordinator",
  "src.presentation.interaction.UIInputLockPolicy",
  "src.presentation.interaction.UIRoleControlLockPolicy",
  "src.presentation.interaction.UIChoiceRoutePolicy",
  "src.presentation.shared.UIAliases",
  "src.presentation.shared.UIEvents",
  "src.presentation.shared.PlayerColors",
  "src.presentation.shared.MarketLayout",
  "src.ui.UIView",
  "src.ui.UIEventHandlers",
  "src.ui.UIRuntimePort",
  "src.ui.BoardView",
  "src.ui.MarketView",
  "src.ui.TileRenderer",
  "src.ui.BoardScene",
  "src.ui.ActionAnim",
  "src.ui.MoveAnim",
  "src.ui.BuildingEffects",
  "src.ui.UIStatus3DLayer",
  "src.ui.UIPanel",
  "src.ui.UIPanelPresenter",
  "src.ui.UIModalPresenter",
  "src.ui.UIChoice",
  "src.ui.UIModel",
  "src.ui.UIModelProjection",
  "src.ui.UIModelPanelBuilder",
  "src.ui.UIRoleContext",
  "src.ui.UIRoleAvatar",
  "src.ui.UIEventRouter",
  "src.ui.UICanvasCoordinator",
  "src.ui.UIModalStateCoordinator",
  "src.ui.UIInputLockPolicy",
  "src.ui.UIRoleControlLockPolicy",
  "src.ui.UIChoiceRoutePolicy",
  "src.ui.UIAliases",
  "src.ui.UIEvents",
  "src.ui.PlayerColors",
  "src.ui.MarketLayout",
}

local ok_count = 0
for _, mod in ipairs(modules) do
  local ok, err = pcall(require, mod)
  if not ok then
    error("require failed: " .. mod .. ": " .. tostring(err))
  end
  ok_count = ok_count + 1
end

print("All requires passed:", ok_count)
