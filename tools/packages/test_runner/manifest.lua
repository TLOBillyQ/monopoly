--- File identities are the only dispatch discriminator.
local M = {}
function M.partition(manifest, files, root)
  local assigned, selected, seen = {}, { legacy = {}, busted = {} }, {}
  for _, backend in ipairs({ "legacy", "busted" }) do
    assert(type(manifest[backend]) == "table", "missing backend list: " .. backend)
    for _, file in ipairs(manifest[backend]) do
      assert(type(file) == "string", "invalid backend identity")
      assert(not assigned[file], "duplicate backend identity: " .. file)
      assigned[file] = backend
    end
  end
  for _, file in ipairs(files) do
    file = file:gsub("\\", "/")
    if root and file:sub(1, #root + 1) == root .. "/" then file = file:sub(#root + 2) end
    assert(not seen[file], "duplicate selected identity: " .. file)
    assert(assigned[file], "unregistered backend identity: " .. file)
    seen[file] = true
    selected[assigned[file]][#selected[assigned[file]] + 1] = file
  end
  return selected
end
return M
