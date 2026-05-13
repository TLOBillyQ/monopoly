local choice_route_policy = require("src.config.choice.route_policy")

local policy = {}

policy.resolve_explicit_route = choice_route_policy.resolve_explicit_route
policy.is_secondary_confirm_choice = choice_route_policy.is_secondary_confirm_choice
policy.resolve = choice_route_policy.resolve
policy.resolve_explicit_requires_confirm = choice_route_policy.resolve_explicit_requires_confirm
policy.requires_confirm = choice_route_policy.requires_confirm

return policy
