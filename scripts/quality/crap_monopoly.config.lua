return {
  project_name = "Monopoly",
  project_root = "../..",
  source_roots = { "src" },
  coverage = {
    lanes = { "behavior" },
    adapter = "crap_monopoly_adapter.lua",
  },
}
