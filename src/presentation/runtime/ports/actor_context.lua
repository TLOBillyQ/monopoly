local actor_context = require("src.ui.ctl.actor_context")

local actor_context_ports = {}

function actor_context_ports.build()
  return {
    resolve_local_actor_role_id = function(state)
      return actor_context.resolve_local_actor_role_id(state)
    end,
    resolve_role_by_id = function(role_id)
      return actor_context.resolve_role_by_id(role_id)
    end,
  }
end

return actor_context_ports
