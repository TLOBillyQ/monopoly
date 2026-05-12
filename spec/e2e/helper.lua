--- Lean busted helper for the e2e lane.
---
--- Unlike spec/helper.lua, this does NOT install Eggy fakes or refresh the
--- runtime context — e2e specs talk to a real editor instance via the
--- editor_cli bridge, so the in-process Lua state stays minimal.

require("spec.bootstrap")
