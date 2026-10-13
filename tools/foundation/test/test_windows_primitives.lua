-- Native Windows public primitive regressions; also runnable directly with Lua.
package.path = package.path .. ";./tools/?.lua"
local runtime = dofile("tools/foundation/runtime_path_ops.lua")
local env = require("foundation.env")
local fs = require("foundation.fs")
local proc = require("foundation.proc")
local path = require("foundation.path")
local shell = require("foundation.shell")

TestWindowsPrimitives = {}

function TestWindowsPrimitives:test_real_cwd_ignores_msys_pwd()
  local cwd = runtime.current_dir()
  assert(cwd:match("^%a:/"), "cwd must be a native absolute drive path: " .. cwd)
  assert(cwd == env.current_dir(), "bootstrap and process cwd must agree")
  assert(runtime.path_exists(cwd .. "/tools/tools.lock"), "cwd must load the real project")
end

function TestWindowsPrimitives:test_native_files_round_trip_discover_copy_and_remove()
  local root = env.make_temp_path("native_中文 space", "")
  local ok, err = xpcall(function()
    assert(fs.write_file(root .. "/source/子目录/a.lua", "hello\0中文"))
    assert(fs.ensure_dir(root .. "/source/empty"))
    assert(fs.ensure_dir(root .. "/src"))
    assert(fs.ensure_dir(root .. "/test"))
    assert(fs.write_file(root .. "/tools/tools.lock", "{}"))
    local bootstrap = dofile("tools/foundation/bootstrap.lua")
    assert(bootstrap.resolve(root .. "/tools/probe.lua").repo_root == root)
    assert(fs.append_file(root .. "/source/子目录/a.lua", "!"))
    assert(fs.copy_tree(root .. "/source", root .. "/copy"))
    assert(fs.is_dir(root .. "/copy/empty"))
    assert(fs.read_file(root .. "/copy/子目录/a.lua") == "hello\0中文!")
    local files = assert(proc.collect_lua_files(root .. "/copy"))
    assert(#files == 1 and files[1] == root .. "/copy/子目录/a.lua")
    assert(fs.copy_file(files[1], root .. "/binary copy.lua"))
    assert(fs.read_file(root .. "/binary copy.lua") == "hello\0中文!")
  end, debug.traceback)
  assert(fs.remove_path(root))
  assert(not fs.path_exists(root))
  assert(ok, err)
end

function TestWindowsPrimitives:test_real_process_arguments_output_exit_and_stdin()
  local root = env.make_temp_path("process_中文 space", "")
  local ok, err = xpcall(function()
    local script = root .. "/probe.lua"
    assert(fs.write_file(script, [[
for i = 1, #arg do io.write(arg[i], "\n") end
io.write(io.read("*a"))
io.stdout:flush()
io.stderr:write("stderr\n")
os.exit(7)
]]))
    assert(fs.write_file(root .. "/input.txt", "stdin\n"))
    local result = proc.run_command({ "lua", script, "", "中文 space", 'quote"and&pipe|', "%PATH%", "bang!caret^", "tail\\" }, { cwd = root, stdin_path = root .. "/input.txt" })
    assert(not result.ok and result.code == 7, "real exit 7 must be preserved: " .. result.output)
    assert(result.output:gsub("\r\n", "\n") == '\n中文 space\nquote"and&pipe|\n%PATH%\nbang!caret^\ntail\\\nstdin\nstderr\n', result.output)
    assert(proc.command_exists("lua"))
    assert(not proc.command_exists("missing_native_command_72"))
    local missing = proc.run_command({ "missing_native_command_72" })
    assert(not missing.ok and missing.code ~= 0 and missing.output ~= "")
    local success = proc.run_command({ "lua", "-e", 'io.write("ok")' })
    assert(success.ok and success.code == 0 and success.output == "ok", success.output)
  end, debug.traceback)
  assert(fs.remove_path(root))
  assert(ok, err)
end

function TestWindowsPrimitives:test_empty_discovery_and_native_cli_startup()
  local root = env.make_temp_path("empty_中文 space", "")
  assert(fs.ensure_dir(root))
  local files, err = proc.collect_lua_files(root)
  assert(fs.remove_path(root))
  assert(files and #files == 0, err)
  local result = proc.run_command({ "lua", "tools/cli.lua", "spec-lane", "--help" })
  assert(result.ok and result.code == 0, result.output)
  assert(result.output:find("profile", 1, true), result.output)
end

function TestWindowsPrimitives:test_empty_registered_suite_fails()
  local root = env.make_temp_path("zero_cases_73", "")
  assert(fs.write_file(root .. "/test_empty.lua", "return {}\n"))
  local result = proc.run_command({ "lua", "tools/packages/luaunit_runner/runner.lua", "--", root .. "/test_empty.lua" })
  assert(fs.remove_path(root))
  assert(not result.ok and result.output:find("cases=0", 1, true), result.output)
end

function TestWindowsPrimitives:test_spec_lane_accepts_serial_and_rejects_empty_execution()
  local opts, err = require("packages.spec_lane.spec_lane_args").parse({ "--profile", "guards", "--serial" })
  assert(opts and opts.serial, err)
end

function TestWindowsPrimitives:test_project_cache_exposes_native_dll_modules()
  local helper = dofile("tools/foundation/package_path_helper.lua")
  helper.install_luarocks_tree_paths({ repo_root = "C:/project" })
  assert(package.cpath:find("C:/project/.toolcache/luarocks/lib/lua/5.4/?.dll", 1, true))
end

function TestWindowsPrimitives:test_selected_interpreter_rejects_non_lua_override()
  local result = proc.run_command('set "LUA54_BIN=cmd.exe" && lua -e "package.path=package.path..\';./tools/?.lua\'; assert(require(\'packages.luaunit_runner.lua54\').detect_lua54()==nil)"')
  assert(result.ok, result.output)
end

function TestWindowsPrimitives:test_tooling_discovers_retained_native_test_roots()
  local roots, err = require("packages.spec_lane.spec_lane_tools").discover_test_roots()
  assert(roots and #roots > 0, err)
  local found = {}
  for _, root in ipairs(roots) do found[root] = true end
  assert(found["tools/foundation/test"] and found["tools/packages/acceptance/test"])
end

function TestWindowsPrimitives:test_verify_forwards_native_flags_without_literal_quotes()
  local result = proc.run_command({ "lua", "tools/cli.lua", "verify", "--ticket73-unknown" })
  assert(result.code == 2, result.output)
  assert(result.output:find("unknown flag: --ticket73-unknown", 1, true), result.output)
end

function TestWindowsPrimitives:test_windows_path_shapes_and_string_command()
  assert(path.resolve_path("C:\\中文 space\\root", "..\\file.lua") == "C:/中文 space/file.lua")
  assert(path.simplify_path("//server/share/a/../b") == "//server/share/b")
  local root = env.make_temp_path("shell_中文 space", "")
  assert(fs.ensure_dir(root))
  local command = shell.wrap_command_with_cwd(shell.build_command({ "lua", "-e", 'io.write("中文 ok")' }), root)
  local result = proc.run_command(command)
  assert(fs.remove_path(root))
  assert(result.ok and result.output == "中文 ok", result.output)
end

if arg and arg[0]:match("test_windows_primitives.lua$") then
  for name, test in pairs(TestWindowsPrimitives) do
    test()
    print("PASS " .. name)
  end
end
return TestWindowsPrimitives
