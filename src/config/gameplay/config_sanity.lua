local runtime_assets = require("src.config.runtime_assets")

local config_sanity = {}

local validated = false

local function _validate_runtime_assets()
  local result = runtime_assets.validate_catalog()
  if result.ok == true then
    return
  end
  local first = result.errors and result.errors[1] or nil
  error((first and first.message) or "runtime asset catalog invalid", 0)
end

function config_sanity.validate()
  if validated then
    return true
  end
  _validate_runtime_assets()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity

--[[ mutate4lua-manifest
version=2
projectHash=1a44d454e44c1863
scope.0.id=chunk:src/config/gameplay/config_sanity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=b8910ce5c54ccfe0
scope.1.id=function:_assert_ref_exists:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=16
scope.1.semanticHash=d95ef37805d092f8
scope.2.id=function:_validate_cue_ref:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=6076047b37814919
scope.3.id=function:_validate_board_feedback_audio_refs:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=51
scope.3.semanticHash=ea7a44b9b96982e1
scope.4.id=function:config_sanity.validate:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=60
scope.4.semanticHash=31c31a04901a254b
scope.5.id=function:config_sanity.reset_for_tests:62
scope.5.kind=function
scope.5.startLine=62
scope.5.endLine=64
scope.5.semanticHash=105c5f919a1e81e3
]]
