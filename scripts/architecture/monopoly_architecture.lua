return {
  source_roots = { "src" },
  component_rules = {
    { name = "app", match = { "^src%.app%..+" }, component = "app" },
    { name = "core", match = { "^src%.core%..+" }, component = "core" },
    { name = "presentation", match = { "^src%.presentation%..+" }, component = "presentation" },
    { name = "game_flow", match = { "^src%.game%.flow%..+" }, component = "game_flow" },
    { name = "game_systems", match = { "^src%.game%.systems%..+", "^src%.game%.ports%..+" }, component = "game_systems" },
    { name = "game_ai", match = { "^src%.game%.core%.ai%..+" }, component = "game_ai" },
    { name = "state", match = {
      "^src%.game%.core%.player%..+",
      "^src%.game%.core%.runtime%.game$",
    }, component = "state" },
    { name = "game_runtime", match = {
      "^src%.game%.runtime%..+",
      "^src%.game%.scheduler%..+",
      "^src%.game%.core%.runtime%..+",
      "^src%.game%.legacy%..+",
    }, component = "game_runtime" },
    { name = "infrastructure", match = { "^src%.infrastructure%..+" }, component = "infrastructure" },
  },
  abstract_rules = {
    { name = "core_ports", match = { "^src%.core%.ports%..+" } },
    { name = "game_ports", match = { "^src%.game%.ports%..+" } },
  },
  forbidden_dependency_rules = {
    {
      name = "presentation_input_no_game",
      description = "interaction layer must not require src.game.* directly",
      from = { "^src%.presentation%.input%..+" },
      to = { "^src%.game%..+" },
    },
    {
      name = "core_ports_no_gameplay",
      description = "core runtime contracts must stay gameplay-agnostic",
      from = { "^src%.core%.ports%..+" },
      to = { "^src%.game%.systems%..+", "^src%.game%.flow%..+", "^src%.game%.ports%..+" },
    },
    {
      name = "game_ports_no_flow_local_bundle",
      description = "game ports must stay systems-facing contracts; loop_ports is flow-local",
      from = { "^src%.game%.ports%..+" },
      to = { "^src%.game%.flow%.turn%.loop_ports$" },
    },
    {
      name = "game_core_player_no_flow",
      description = "game core player state must not depend on src.game.flow.* directly",
      from = { "^src%.game%.core%.player%..+" },
      to = { "^src%.game%.flow%..+" },
    },
    {
      name = "game_core_player_no_systems",
      description = "game core player state must not depend on src.game.systems.* directly",
      from = { "^src%.game%.core%.player%..+" },
      to = { "^src%.game%.systems%..+" },
    },
    {
      name = "systems_no_flow",
      description = "systems layer must not depend on src.game.flow.* directly",
      from = { "^src%.game%.systems%..+" },
      to = { "^src%.game%.flow%..+" },
    },
    {
      name = "systems_no_core_runtime",
      description = "systems layer must not depend on game.core.runtime directly",
      from = { "^src%.game%.systems%..+" },
      to = { "^src%.game%.core%.runtime%..+" },
    },
  },
  cycle_baseline = {},
}
