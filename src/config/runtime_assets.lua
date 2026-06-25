local images = require("src.config.runtime_assets.images")
local synthetic = require("src.config.runtime_assets.synthetic")
local board_feedback = require("src.config.runtime_assets.board_feedback")
local validation = require("src.config.runtime_assets.validation")
local state = require("src.config.runtime_assets.state")

local runtime_assets = {}

local function _copy_exports(source, names)
  for _, name in ipairs(names) do
    runtime_assets[name] = source[name]
  end
end

_copy_exports(images, {
  "image_for_item",
  "image_for_chance_card",
  "image_for_skin_card",
  "empty_image",
  "image_for_popup_card",
  "image_for_market_item",
  "image_for_market_rarity",
  "startup_item_slot_icon",
  "skin_model_for_product",
  "default_skin_model",
})

_copy_exports(synthetic, {
  "synthetic_ai_profile",
  "synthetic_ai_unit_key_pool",
})

runtime_assets.board_feedback_cue = board_feedback.board_feedback_cue
runtime_assets.validate_catalog = validation.validate_catalog
runtime_assets.compat_refs = state.compat_refs
runtime_assets.asset_context = state.asset_context
runtime_assets.configure_for_tests = state.configure_for_tests
runtime_assets.reset_for_tests = state.reset_for_tests

return runtime_assets

--[[ mutate4lua-manifest
version=2
projectHash=051e310383b19681
scope.0.id=chunk:src/config/runtime_assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=48e44e6241e614ac
]]
