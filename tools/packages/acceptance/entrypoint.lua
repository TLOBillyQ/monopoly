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
function entrypoint.metadata_path_for(output_path, feature_path)
  local path = require("foundation.path")
  -- Full SHA-256 bounds the filename while preserving identity in the document.
  return path.join_path(path.parent_dir(output_path), "metadata",
    require("acceptance4lua.spec_hash").sha256(tostring(feature_path)) .. ".json")
end

function entrypoint.generate_file(ir_path, output_path)
  local content, err = fs_lib.read_file(ir_path)
  if content == nil then
    return nil, err
  end

  local ok, ir_or_err = pcall(json.decode, content)
  if not ok then
    return nil, ir_or_err
  end

  local feature_path = require("acceptance4lua.source").path_from_ir(ir_or_err) or "feature"
  local metadata_path = entrypoint.metadata_path_for(output_path, feature_path)
  local existing = fs_lib.read_raw(metadata_path)
  if existing then
    local decoded_ok, metadata = pcall(json.decode, existing)
    if not decoded_ok or type(metadata) ~= "table" or metadata.feature_path ~= feature_path then
      return nil, "metadata identity conflict: " .. metadata_path
    end
  end
  local generated = generator.generate(ir_or_err, {
    runtime_module = entrypoint.runtime_module,
    steps_module = "packages.acceptance.steps",
  })
  local written, write_err = fs_lib.write_file(output_path, generated)
  if not written then return nil, write_err end
  return fs_lib.write_file(metadata_path, json.encode({
    schema_version = 1,
    feature_path = feature_path,
    ir_path = ir_path,
    implementation_hash = require("acceptance4lua.spec_hash").compute_generated_files_hash({ output_path }),
    hash_scope = "generated_files",
    generated_files = { output_path },
  }))
end

return entrypoint
