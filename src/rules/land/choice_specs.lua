local use_skip_choice = require("src.rules.choice.use_skip_choice")
local number_utils = require("src.foundation.number")

local land_choice_specs = {}

local function _decorate_secondary_confirm(choice, title, body)
  choice.route_key = "secondary_confirm"
  choice.requires_confirm = true
  choice.allow_cancel = true
  choice.cancel_label = "不用"
  choice.confirm_title = title
  choice.confirm_body = body
  return choice
end

function land_choice_specs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  if card_kind == "strong" then
    local body = "支付 " .. number_utils.format_integer_part(total_value) .. " 强制购入 " .. tile_name
    local choice = use_skip_choice.build(
      "rent_card_prompt",
      "是否使用强征卡",
      { body },
      { player_id = player_id, tile_id = tile_id, card_kind = card_kind },
      { skip = "不用" }
    )
    return _decorate_secondary_confirm(choice, "强征卡", body)
  end
  return use_skip_choice.build(
    "rent_card_prompt",
    "是否使用免费卡",
    { "免除本次租金" },
    { player_id = player_id, tile_id = tile_id, card_kind = card_kind },
    {
      skip = "不用",
      confirm_title = "免费卡",
      confirm_body = "这次要用免费卡吗？",
    }
  )
end

function land_choice_specs.tax_prompt(player_id)
  local choice = use_skip_choice.build(
    "tax_card_prompt",
    "是否使用免税卡",
    { "使用免税卡可免除本次税金" },
    { player_id = player_id },
    { skip = "不用" }
  )
  return _decorate_secondary_confirm(choice, "税务局", "这次要用免税卡吗？")
end

return land_choice_specs

--[[ mutate4lua-manifest
version=4
projectHash=5e20374afa1fecb3
scope.0.id=chunk:src/rules/land/choice_specs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=e6f7b8351b90d7cb
scope.1.id=function:_decorate_secondary_confirm
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=76e4ddbc52554aab
scope.2.id=function:land_choice_specs.rent_prompt
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=39
scope.2.semanticHash=054f8834ef19ca42
scope.3.id=function:land_choice_specs.tax_prompt
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=50
scope.3.semanticHash=d622db8d2bc44c5e
]]
