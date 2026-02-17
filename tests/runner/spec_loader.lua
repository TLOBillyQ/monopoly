local spec_loader = {}

local function _base_specs()
  return {
    require("contract.ports_contract_spec"),
    require("unit.runtime_phase_flags_spec"),
    require("unit.action_button_timer_spec"),
    require("integration.turn_phase_anim_spec"),
    require("integration.visual_input_lock_spec"),
    require("integration.internal_dep_rules_spec"),
    require("integration.internal_gameplay_loop_no_ui_spec"),
    require("regression.gameplay_main_flow_spec"),
    require("regression.modal_choice_timeout_spec"),
    require("regression.chance"),
    require("regression.land"),
    require("regression.item"),
    require("regression.movement"),
    require("regression.landing"),
    require("regression.market"),
    require("regression.paid_currency"),
    require("regression.presentation_ui"),
    require("regression.presentation_ui_action_anim"),
    require("regression.gameplay"),
    require("regression.misc"),
  }
end

local function _append_all(target, items)
  for _, item in ipairs(items or {}) do
    target[#target + 1] = item
  end
end

function spec_loader.collect_all()
  local specs = {}
  _append_all(specs, _base_specs())
  return specs
end

return spec_loader
