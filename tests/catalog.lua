local bootstrap = require("tests.bootstrap")

local M = {}

local domain_behavior_modules = {
  "suites.domain.camera_helper",
  "suites.domain.chance",
  "suites.domain.land",
  "suites.domain.item",
  "suites.domain.item_availability_matrix",
  "suites.domain.movement",
  "suites.domain.landing",
  "suites.domain.market",
  "suites.domain.paid_currency",
  "suites.domain.config_sanity",
  "suites.domain.global_aliases",
  "suites.domain.clear_obstacles_branch_walk",
  "suites.domain.vehicle_helper",
  "suites.domain.board_init_crap_coverage",
  "suites.domain.board_direction_utils_crap_coverage",
  "suites.domain.board_direction_crap_coverage",
  "suites.domain.board_direction_collect_crap_coverage",
  "suites.domain.board_query_crap_coverage",
  "suites.domain.resolver_crap_coverage",
  "suites.domain.mine_effect_crap_coverage",
  "suites.domain.item_availability_rent_response_crap_coverage",
  "suites.domain.item_availability_trigger_timing_crap_coverage",
  "suites.domain.item_preconsume_crap_coverage",
  "suites.domain.host_context_crap_coverage",
  "suites.domain.remote_priority_crap_coverage",
  "suites.domain.ring_map_direction_crap_coverage",
  "suites.domain.boundary_assertions_t36",
  "suites.domain.state_adapter_coverage",
  "suites.domain.loop_ports_coverage",
  "suites.domain.runtime_ports_coverage",
  "suites.domain.tick_clock_coverage",
  "suites.domain.runtime_state_coverage",
  "suites.domain.validator_coverage",
  "suites.domain.tip_queue_coverage",
  "suites.domain.direction_coverage",
  "suites.domain.roll_coverage",
  "suites.domain.logger_coverage",
  "suites.domain.game_state_coverage",
  "suites.domain.loop_ports_extended_coverage",
  "suites.domain.action_anim_wait_coverage",
  "suites.domain.loop_runtime_coverage",
  "suites.domain.items_phase_coverage",
  "suites.domain.landing_visual_hold_coverage",
  "suites.domain.land_resolve_coverage",
  "suites.domain.deity_ops_coverage",
  "suites.domain.contract_helper_coverage",
  "suites.domain.log_formatter_coverage",
  "suites.domain.log_queue_coverage",
  "suites.domain.decision_engine_coverage",
  "suites.domain.action_selector_coverage",
  "suites.domain.callback_registry_coverage",
  "suites.domain.tick_timeout_coverage",
  "suites.domain.turn_timer_policy_coverage",
  "suites.domain.vehicle_runtime_source_coverage",
  "suites.domain.inventory_coverage",
  "suites.domain.availability_coverage",
  "suites.domain.session_script_coverage",
}

local runtime_behavior_modules = {
  "suites.runtime.startup_profile",
  "suites.runtime.config_reset_isolation",
  "suites.runtime.test_profile_resolver",
  "suites.runtime.test_profile_bootstrap_core",
  "suites.runtime.test_profile_bootstrap_scenarios",
  "suites.runtime.misc_vehicle_runtime_source",
  "suites.runtime.misc",
}

local gameplay_behavior_modules = {
  "suites.gameplay.turn_flow.phase_transitions",
  "suites.gameplay.turn_flow.pre_move",
  "suites.gameplay.choices.timeout",
  "suites.gameplay.choices.validation",
  "suites.gameplay.choices.market",
  "suites.gameplay.choices.session",
  "suites.gameplay.choices.purchase",
  "suites.gameplay.ui_sync.gates",
  "suites.gameplay.ui_sync.feedback",
  "suites.gameplay.auto_runner.policies",
  "suites.gameplay.items.strategy",
  "suites.gameplay.items.post_effects",
  "suites.gameplay.bankruptcy.elimination",
  "suites.gameplay.bankruptcy.session",
  "suites.gameplay.bankruptcy.tile_owner",
  "suites.gameplay.runtime.asset_handlers",
  "suites.gameplay.runtime.game_factory",
  "suites.gameplay.runtime.context",
  "suites.gameplay.movement.dice",
  "suites.gameplay.movement.camera",
  "suites.gameplay.turn_flow.intent_dispatch",
  "suites.gameplay.runtime.coroutine",
  "suites.gameplay.turn_flow.interrupts",
  "suites.gameplay.auto_runner.timeout",
  "suites.gameplay.ui_sync.prompts",
  "suites.gameplay.items.startup",
  "suites.gameplay.items.passive",
  "suites.gameplay.movement.relocation",
  "suites.gameplay.movement.obstacles",
  "suites.gameplay.movement.executor",
}

local presentation_behavior_modules = {
  "suites.runtime.runtime_bootstrap",
  "suites.presentation.presentation_ui_timing_anim",
  "suites.presentation.presentation_ui_model_dispatch",
  "suites.presentation.presentation_ui_interaction",
  "suites.presentation.presentation_ui_role_slots",
  "suites.presentation.presentation_ui_touch_policy",
  "suites.presentation.presentation_market_confirm_flow",
  "suites.presentation.presentation_popup_visibility",
  "suites.presentation.presentation_action_anim_effect_routes",
  "suites.presentation.presentation_action_anim_tip_text",
  "suites.presentation.presentation_action_anim_overlay_units",
  "suites.presentation.presentation_board_feedback",
  "suites.presentation.presentation_move_anim_sequence",
  "suites.presentation.presentation_move_anim_actor_modes",
  "suites.presentation.presentation_move_anim_teleport_and_vehicle",
  "suites.presentation.presentation_board_sync",
  "suites.presentation.presentation_ui_event_handlers",
  "suites.presentation.presentation_ui_event_bindings",
  "suites.presentation.presentation_player_colors",
  "suites.presentation._presentation_action_status_choice_routes",
  "suites.presentation._presentation_action_status_target_pick",
  "suites.presentation._presentation_action_status_action_log",
  "suites.presentation._presentation_action_status_market_panel",
  "suites.presentation._presentation_action_status_item_slots",
  "suites.presentation._presentation_action_status_action_anim",
  "suites.presentation._presentation_action_status_status3d",
  "suites.presentation._presentation_action_status_popup_modal",
  "suites.presentation._presentation_action_status_player_panels",
  "suites.presentation.gameplay_t6_characterization",
  "suites.presentation.gameplay_t5_characterization",
  -- T8: Re-enabled T2 characterization tests for final CRAP cleanup
  "suites.presentation.status3d_roadblock_crap_coverage",
  "suites.presentation.effect_track_crap_coverage",
  "suites.presentation.anchors_sequence_crap_coverage",
  "suites.presentation.mine_trigger_crap_coverage",
}

local behavior_modules = {}
for _, module_name in ipairs(domain_behavior_modules) do
  behavior_modules[#behavior_modules + 1] = module_name
end
for _, module_name in ipairs(runtime_behavior_modules) do
  behavior_modules[#behavior_modules + 1] = module_name
end
for _, module_name in ipairs(gameplay_behavior_modules) do
  behavior_modules[#behavior_modules + 1] = module_name
end
for _, module_name in ipairs(presentation_behavior_modules) do
  behavior_modules[#behavior_modules + 1] = module_name
end

local contract_modules = {
  -- kept as tooling-support stubs: required by tooling lane suites for tooling_tests field
  "suites.architecture.script_tools_contract",
  "suites.architecture.scrap4lua_contract",
}

local tooling_modules = {
  "suites.architecture.arch_view_snapshot_tooling_contract",
  "suites.architecture.arch_view_live_tooling_contract",
  "suites.architecture.crap_tooling_contract",
  "suites.architecture.mutate4lua_tooling_contract",
  "suites.architecture.loc_scan_tooling_contract",
  "suites.architecture.script_tools_io_tooling_contract",
  "suites.architecture.script_tools_mutate_tooling_contract",
  "suites.architecture.script_tools_process_tooling_contract",
  "suites.architecture.scrap4lua_tooling_contract",
  "suites.architecture.script_tools_tooling",  -- 从 script_tools_contract 分离出的重型 tooling 测试
  "suites.architecture.busted_infra_tooling",  -- T8: meta-test 验证 busted infra 完整性
}

local guard_scripts = {
  { name = "dep_rules", module_name = "guards.dep_rules", path = "tests/guards/dep_rules.lua" },
  { name = "gameplay_loop_no_ui", module_name = "guards.gameplay_loop_no_ui", path = "tests/guards/gameplay_loop_no_ui.lua" },
  { name = "forbidden_globals", module_name = "guards.forbidden_globals", path = "tests/guards/forbidden_globals.lua" },
  { name = "arch_view_guard", module_name = "guards.arch_view_guard", path = "tests/guards/arch_view_guard.lua" },
  { name = "repo_hygiene", module_name = "guards.repo_hygiene", path = "tests/guards/repo_hygiene.lua" },
  { name = "fixed_type", module_name = "guards.fixed_type_guard", path = "tests/guards/fixed_type_guard.lua" },
}

local function _clone_case(test)
  if type(test) == "function" then
    return {
      name = nil,
      run = test,
      tags = {},
    }
  end
  local clone = {}
  for key, value in pairs(test or {}) do
    clone[key] = value
  end
  clone.tags = clone.tags or {}
  return clone
end

local function _clone_suite(module_name, suite, layer, kind)
  local clone = {
    name = suite.name,
    layer = suite.layer or layer,
    kind = suite.kind or kind,
    tests = {},
    module_name = module_name,
  }
  local source_tests = suite.tests or suite
  for _, test in ipairs(source_tests or {}) do
    local case = _clone_case(test)
    clone.tests[#clone.tests + 1] = case
  end
  return clone
end

local function _load_modules(module_names, layer, kind)
  local suites = {}
  for _, module_name in ipairs(module_names or {}) do
    local suite = require(module_name)
    suites[#suites + 1] = _clone_suite(module_name, suite, layer, kind)
  end
  return suites
end

M.behavior_suites = behavior_modules
M.contract_suites = contract_modules
M.tooling_suites = tooling_modules
M.guard_scripts = guard_scripts

function M.load_behavior_suites()
  bootstrap.install_package_paths()
  local suites = _load_modules(M.behavior_suites, "behavior", "suite")
  return suites
end

function M.load_contract_suites()
  bootstrap.install_package_paths()
  return _load_modules(M.contract_suites, "contract", "contract")
end

function M.load_tooling_suites()
  bootstrap.install_package_paths()
  return _load_modules(M.tooling_suites, "tooling", "tooling")
end

function M.load_all_suites()
  local suites = M.load_behavior_suites()
  local contract_suites = M.load_contract_suites()
  for _, suite in ipairs(contract_suites) do
    suites[#suites + 1] = suite
  end
  return suites
end

return M
