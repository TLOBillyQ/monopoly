local resolve = require("src.turn.phases.land.resolve")

return {
  run = resolve.phase_land,
  _resolve_wait_state = resolve.resolve_wait_state,
  _phase_land = resolve.phase_land,
}
