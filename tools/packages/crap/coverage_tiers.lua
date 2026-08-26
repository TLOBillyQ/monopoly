return {
  tiers = {
    {
      name = "core_logic",
      threshold = 0.75,
      includes = {
        "src/app/",
        "src/computer/",
        "src/config/",
        "src/foundation/",
        "src/player/",
        "src/rules/",
        "src/state/",
        "src/turn/",
      },
    },
    {
      name = "host_bridge",
      threshold = 0.60,
      includes = { "src/host/" },
    },
    -- ADR 0029: src/ui/manager/ is a host-EUI adapter sub-layer inside ui,
    -- not independent UI business logic. It is allowed to call GameAPI/LuaAPI
    -- directly, so it needs its own tier with the same threshold as host_bridge.
    -- Place this tier before ui_surface so manager files match here first.
    {
      name = "ui_host_adapter",
      threshold = 0.60,
      includes = { "src/ui/manager/" },
    },
    {
      name = "ui_surface",
      threshold = 0.65,
      includes = { "src/ui/" },
    },
  },
}
