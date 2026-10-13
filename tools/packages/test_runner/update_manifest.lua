--- Explicit registration tool: new files are legacy until deliberately migrated.
local bootstrap = dofile("tools/foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local filename = env.repo_root .. "/tools/packages/test_runner/backend_manifest.lua"
local chunk = loadfile(filename)
local manifest = chunk and chunk() or { legacy = {}, busted = {} }
local migrated = {}
for _, path in ipairs(manifest.busted) do migrated[path] = true end
local files = {}
local profiles = dofile("tools/packages/spec_lane/spec_profiles.lua")
for _, name in ipairs({ "contract", "guards", "behavior", "tooling" }) do
  for _, root in ipairs(profiles[name].ROOT) do
    for _, path in ipairs(require("foundation.spec_sharding").discover_spec_files(root)) do
      path = path:gsub("\\", "/")
      if path:sub(1, #env.repo_root + 1) == env.repo_root .. "/" then path = path:sub(#env.repo_root + 2) end
      files[path] = true
    end
  end
end
local lists = { legacy = {}, busted = {} }
for path in pairs(files) do
  local backend = migrated[path] and "busted" or "legacy"
  lists[backend][#lists[backend] + 1] = path
end
local file = assert(io.open(filename, "wb"))
file:write("-- Temporary exhaustive file-identity registry. No content-based dispatch.\nreturn {\n")
for _, backend in ipairs({ "legacy", "busted" }) do
  table.sort(lists[backend])
  file:write("  " .. backend .. " = {\n")
  for _, path in ipairs(lists[backend]) do file:write(string.format("    %q,\n", path)) end
  file:write("  },\n")
end
file:write("}\n"); file:close()
print(string.format("registered legacy=%d busted=%d", #lists.legacy, #lists.busted))
