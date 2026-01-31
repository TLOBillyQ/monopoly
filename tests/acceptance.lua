dofile("tests/test_bootstrap.lua")

local function run(path)
  io.stdout:write("[acceptance] " .. path .. "\n")
  dofile(path)
end

local scripts = {
  "tests/deps_check.lua",
  "tests/eggy_memory_audit.lua",
  "tests/eggy_event_names_test.lua",
  "tests/ui_missing_impl_audit.lua",
  "tests/registry_extension_test.lua",
  "tests/classutils_refactor_test.lua",
  "tests/entry_smoke_test.lua",
  "tests/regression.lua",
}

for _, path in ipairs(scripts) do
  run(path)
end

print("ok - acceptance suite")
