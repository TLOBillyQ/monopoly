-- Project acceptance entrypoint generator (issue #132).
--
-- The portable acceptance4lua generator emits specs bound to whichever runtime
-- module it is told to use, defaulting to its own. This project's step handlers
-- rely on the shape dispatch in `packages.acceptance.runtime`, so every
-- generated spec — regenerate, single-feature runs, and the mutation probe —
-- must be bound to it. This module is the one place that binding is decided.

local fs_lib = require("foundation.fs")
local generator = require("acceptance4lua.generator")
local json = require("acceptance4lua.json")

local entrypoint = {}

entrypoint.runtime_module = "packages.acceptance.runtime"

-- Same contract as acceptance4lua's generator.generate_file: read the JSON IR,
-- write the generated spec plus its metadata. Returns true or (nil, error).
function entrypoint.generate_file(ir_path, output_path)
  local content, err = fs_lib.read_file(ir_path)
  if content == nil then
    return nil, err
  end

  local ok, ir_or_err = pcall(json.decode, content)
  if not ok then
    return nil, ir_or_err
  end

  return generator.write_generated(ir_or_err, output_path, {
    ir_path = ir_path,
    runtime_module = entrypoint.runtime_module,
    -- acceptance4lua 的 generator 默认 step 模块名是中性的 "steps";本项目的
    -- step handlers 在 packages.acceptance.steps,必须显式绑定保持生成物不变。
    steps_module = "packages.acceptance.steps",
  })
end

return entrypoint
