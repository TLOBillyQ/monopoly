-- 项目叙事文档显式白名单。技能、工具契约、Gherkin 与上游资产由各自车道负责。

return {
  allowed_paths = {
    ["docs/agents/issue-tracker.md"] = true,
    ["docs/agents/triage-labels.md"] = true,
    ["docs/agents/domain.md"] = true,
    ["docs/architecture.md"] = true,
    -- uml ir 推演覆盖文件(ADR 0070 / #99):仓根 policy.edn 是生成物,:proposals/:omit 存这里。
    ["docs/architecture.proposals.edn"] = true,
    ["docs/decisions.md"] = true,
  },
  retired_dirs = {
    "docs/inventory",
    "docs/reviews",
    "docs/superpowers",
    "docs/prototypes",
  },
}
