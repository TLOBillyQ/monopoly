local choice_route_policy = require("src.config.choice.route_policy")

local policy = {}

function policy.resolve_explicit_route(choice)
  return choice_route_policy.resolve_explicit_route(choice)
end

function policy.is_secondary_confirm_choice(choice)
  return choice_route_policy.is_secondary_confirm_choice(choice)
end

function policy.resolve(choice)
  return choice_route_policy.resolve(choice)
end

function policy.resolve_explicit_requires_confirm(choice_or_screen)
  return choice_route_policy.resolve_explicit_requires_confirm(choice_or_screen)
end

function policy.requires_confirm(choice_or_screen)
  return choice_route_policy.requires_confirm(choice_or_screen)
end

return policy
