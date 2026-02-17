local function _run_gameplay_loop_no_ui_smoke()
  dofile("tests/internal/gameplay_loop_no_ui.lua")
end

return {
  layer = "integration",
  domain = "internal_gameplay_loop_no_ui",
  cases = {
    {
      id = "given_headless_loop_when_run_smoke_then_tick_ok",
      desc = "gameplay_loop_no_ui smoke script must pass",
      run = _run_gameplay_loop_no_ui_smoke,
    },
  },
}
