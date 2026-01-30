local function run(path)
  io.stdout:write("[acceptance] " .. path .. "\n")
  dofile(path)
end

local scripts = {
  "tests/deps_check.lua",
  "tests/registry_extension_test.lua",
  "tests/classutils_refactor_test.lua",
  "tests/regression.lua",
}

for _, path in ipairs(scripts) do
  run(path)
end

print("ok - acceptance suite")
