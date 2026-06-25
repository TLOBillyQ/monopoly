local M = {}

M.STATE_MISSING = "missing"
M.STATE_CORRUPT = "corrupt"
M.STATE_V1 = "v1"
M.STATE_V2 = "v2"
M.STATE_BOOTSTRAP_ONLY = "bootstrap_only"
M.STATE_CURRENT = "current"
M.STATE_DRIFTED = "drifted"

M.BOOTSTRAP_WRITTEN = "written"
M.BOOTSTRAP_MIGRATED = "migrated"
M.BOOTSTRAP_UNCHANGED = "unchanged"
M.BOOTSTRAP_SKIPPED = "skipped"

M.REASON_BOOTSTRAP_ONLY = "bootstrap_only"
M.REASON_EXPLICIT_UPDATE = "explicit_update"
M.REASON_LINES_MODE = "lines_mode"
M.REASON_SURVIVED = "survived"
M.REASON_TIMEOUT = "timeout"
M.REASON_PASS = "pass"

require("quality.mutation_manifest_policy.classifier")(M)
require("quality.mutation_manifest_policy.bootstrap")(M)
require("quality.mutation_manifest_policy.decision")(M)

return M
