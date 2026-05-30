local tables = require("src.foundation.tables")

local use_skip_choice = {}

local function _build_confirm_body(body_lines)
  return tables.join_or_default(body_lines, "\n", "请再确认一次")
end

function use_skip_choice.build(kind, title, body_lines, meta, labels)
  labels = labels or {}
  local owner_role_id = meta and meta.player_id or nil
  local skip_label = labels.skip or "放弃"
  return {
    kind = kind,
    owner_role_id = owner_role_id,
    route_key = "secondary_confirm",
    requires_confirm = true,
    title = title,
    body_lines = body_lines,
    options = {
      { id = "use", label = labels.use or "使用" },
      { id = "skip", label = skip_label },
    },
    allow_cancel = true,
    cancel_label = skip_label,
    confirm_title = labels.confirm_title or title,
    confirm_body = labels.confirm_body or _build_confirm_body(body_lines),
    meta = meta,
  }
end

return use_skip_choice

--[[ mutate4lua-manifest
version=2
projectHash=4b64ce6d339fda8a
scope.0.id=chunk:src/rules/choice/use_skip_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=2bd4b9b65e89880b
scope.1.id=function:_build_confirm_body:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=18d168b3977c7d17
scope.2.id=function:use_skip_choice.build:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=30
scope.2.semanticHash=15d5ac8190a338d1
]]
