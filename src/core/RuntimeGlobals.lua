local runtime_context = require("src.core.RuntimeContext")

local ctx = runtime_context.current()
assert(ctx ~= nil, "missing RuntimeContext.current")
runtime_context.install_globals(ctx)
