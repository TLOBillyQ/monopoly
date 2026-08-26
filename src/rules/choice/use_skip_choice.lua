local tables = require("src.foundation.tables")

local use_skip_choice = {}

local function _build_confirm_body(body_lines)
  return tables.join_or_default(body_lines, "\n", "请再确认一次")
end

-- 文案默认值集中在这里,build 只负责组装 choice 形状。
local function _resolve_labels(labels, title, body_lines)
  return {
    use = labels.use or "使用",
    skip = labels.skip or "放弃",
    confirm_title = labels.confirm_title or title,
    confirm_body = labels.confirm_body or _build_confirm_body(body_lines),
  }
end

function use_skip_choice.build(kind, title, body_lines, meta, labels)
  local text = _resolve_labels(labels or {}, title, body_lines)
  local owner_role_id = meta and meta.player_id or nil
  return {
    kind = kind,
    owner_role_id = owner_role_id,
    route_key = "secondary_confirm",
    requires_confirm = true,
    title = title,
    body_lines = body_lines,
    options = {
      { id = "use", label = text.use },
      { id = "skip", label = text.skip },
    },
    allow_cancel = true,
    cancel_label = text.skip,
    confirm_title = text.confirm_title,
    confirm_body = text.confirm_body,
    meta = meta,
  }
end

return use_skip_choice

--[[ mutate4lua-manifest
version=4
projectHash=93d2b1e686d99d80
scope.0.id=chunk:src/rules/choice/use_skip_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=71d1ade1df734cc3
scope.1.id=function:_build_confirm_body
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=d76a4ff5b8cece45
scope.2.id=function:_resolve_labels
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=17
scope.2.semanticHash=fcbc739820e33a8b
scope.3.id=function:use_skip_choice.build
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=39
scope.3.semanticHash=b99fa49a9d9379ec
]]
