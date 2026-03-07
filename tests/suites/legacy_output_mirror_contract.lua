local support = require("TestSupport")
local _assert_eq = support.assert_eq

local use_case_output_port = require("src.game.flow.output_adapters.UseCaseOutputPort")
local legacy_output_mirror = require("src.game.flow.output_adapters.LegacyOutputMirror")

local function _test_base_output_ports_stay_runtime_only()
  local output = use_case_output_port.build_base_output_ports()
  local state = {}
  local changed = output.invalidate_ui(state)
  _assert_eq(changed, true, "base output should still mark ui dirty")
  _assert_eq(state.ui_dirty, nil, "base output should not write legacy ui_dirty")
  _assert_eq(state.ui_runtime and state.ui_runtime.ui_dirty, true, "base output should write ui_runtime only")
end

local function _test_legacy_output_mirror_no_longer_writes_root_legacy_state()
  local output = legacy_output_mirror.wrap(use_case_output_port.build_runtime_output_ports())
  local state = {
    ui_dirty = false,
    ui_model = { stale = true },
    pending_choice = { stale = true },
    pending_choice_id = 99,
    pending_choice_elapsed = 10,
    ui_modal_elapsed = 12,
    ui_modal_ref = "stale",
  }

  output.invalidate_ui(state)
  output.sync_ui_model(state, { fresh = true })
  output.sync_pending_choice(state, { id = 7 }, { choice_id = 7, elapsed_seconds = 3 })
  output.sync_modal_timer(state, { ref = "modal", elapsed_seconds = 5 })
  output.clear_pending_choice(state)

  _assert_eq(state.ui_dirty, false, "legacy mirror should not write root ui_dirty")
  _assert_eq(state.ui_model.stale, true, "legacy mirror should not overwrite root ui_model")
  _assert_eq(state.pending_choice.stale, true, "legacy mirror should not overwrite root pending_choice")
  _assert_eq(state.pending_choice_id, 99, "legacy mirror should not overwrite root pending_choice_id")
  _assert_eq(state.pending_choice_elapsed, 10, "legacy mirror should not overwrite root pending_choice_elapsed")
  _assert_eq(state.ui_modal_elapsed, 12, "legacy mirror should not overwrite root ui_modal_elapsed")
  _assert_eq(state.ui_modal_ref, "stale", "legacy mirror should not overwrite root ui_modal_ref")
end

return {
  name = "legacy_output_mirror_contract",
  tests = {
    { name = "base_output_ports_stay_runtime_only", run = _test_base_output_ports_stay_runtime_only },
    { name = "legacy_output_mirror_no_longer_writes_root_legacy_state", run = _test_legacy_output_mirror_no_longer_writes_root_legacy_state },
  },
}
