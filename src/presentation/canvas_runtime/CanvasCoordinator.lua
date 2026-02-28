local legacy = require("src.presentation.interaction.UICanvasCoordinator")

local coordinator = {}

coordinator.CANVAS_BASE = legacy.CANVAS_BASE
coordinator.CANVAS_ALWAYS_SHOW = legacy.CANVAS_ALWAYS_SHOW
coordinator.CANVAS_PLAYER_CHOICE = legacy.CANVAS_PLAYER_CHOICE
coordinator.CANVAS_TARGET_CHOICE = legacy.CANVAS_TARGET_CHOICE
coordinator.CANVAS_REMOTE_CHOICE = legacy.CANVAS_REMOTE_CHOICE
coordinator.CANVAS_BUILDING_CHOICE = legacy.CANVAS_BUILDING_CHOICE
coordinator.CANVAS_MARKET = legacy.CANVAS_MARKET
coordinator.CANVAS_POPUP = legacy.CANVAS_POPUP
coordinator.CANVAS_BANKRUPTCY = legacy.CANVAS_BANKRUPTCY
coordinator.CANVAS_DEBUG = legacy.CANVAS_DEBUG

function coordinator.switch(ui, target)
  return legacy.switch(ui, target)
end

function coordinator.switch_for_role(ui, target, role)
  return legacy.switch_for_role(ui, target, role)
end

function coordinator.resolve_popup_return_canvas(ui)
  return legacy.resolve_popup_return_canvas(ui)
end

function coordinator.resolve_canvas_after_popup(ui, target)
  return legacy.resolve_canvas_after_popup(ui, target)
end

return coordinator
