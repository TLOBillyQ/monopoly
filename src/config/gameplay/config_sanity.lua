local constants = require("src.config.content.constants")
local number_utils = require("src.foundation.number")

-- 运行资产目录校验器由装配侧注入(#328):config_sanity 只声明「需要一份目录校验
-- 结果」,不反向依赖 config.runtime_assets——拆 config.gameplay ↔ runtime_assets
-- 投影环,依赖方向单一化(config → runtime_assets)。注入的校验器返回
-- validate_catalog 同款结果表 {ok=bool, errors={...}};未注入时跳过目录校验
-- (目录校验是装配侧职责)。
local runtime_asset_validator = nil

local config_sanity = {}

local validated = false

function config_sanity.configure_runtime_asset_validator(validator)
  runtime_asset_validator = validator
end

-- 税率的取值域是配置的不变量,不是结算代码的:tax_rules 依赖 (0, 1] 才能保证
-- floor(cash * rate) 不超过余额,进而让「本次税额」与实际扣款一致。
-- 把这条约束钉在配置边界上,结算侧就不必再写不可达的兜底钳制。
local function _validate_tax_rate()
  local rate = constants.tax_rate
  if number_utils.is_numeric(rate) and rate > 0 and rate <= 1 then
    return
  end
  error("tax_rate must be a number in (0, 1]; got " .. tostring(rate), 0)
end

-- 取校验结果的第一个错误消息:无 errors 表或无消息时回落通用文案。
local function _first_error_message(result)
  local first = result.errors and result.errors[1] or nil
  return (first and first.message) or "runtime asset catalog invalid"
end

local function _validate_runtime_assets()
  if runtime_asset_validator == nil then
    return
  end
  local result = runtime_asset_validator()
  if result.ok == true then
    return
  end
  error(_first_error_message(result), 0)
end

function config_sanity.validate()
  if validated then
    return true
  end
  _validate_tax_rate()
  _validate_runtime_assets()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity

--[[ mutate4lua-manifest
version=4
projectHash=9df4d0fa07a9a7fd
scope.0.id=chunk:src/config/gameplay/config_sanity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=1e7c25224c4dd29d
scope.1.id=function:config_sanity.configure_runtime_asset_validator
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=139af97e09c42e84
scope.2.id=function:_validate_tax_rate
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=28
scope.2.semanticHash=78b5317b09824136
scope.3.id=function:_first_error_message
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=34
scope.3.semanticHash=94bfe4bf4e1ca2a4
scope.4.id=function:_validate_runtime_assets
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=45
scope.4.semanticHash=a6b017ffa01af21e
scope.5.id=function:config_sanity.validate
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=55
scope.5.semanticHash=23b6ce640fe9aa53
scope.6.id=function:config_sanity.reset_for_tests
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=59
scope.6.semanticHash=fdef1f983e0b1d09
]]
