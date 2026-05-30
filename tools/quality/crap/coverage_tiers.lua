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
    {
      name = "ui_surface",
      threshold = 0.65,
      includes = { "src/ui/" },
    },
  },
}
