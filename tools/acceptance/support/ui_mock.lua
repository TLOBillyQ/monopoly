local presentation_ports = require("src.ui.ports")

local ui_mock = {}

-- Build the in-memory ui + presentation_runtime stub shared by render-asserting
-- step files. Returns the state table that step handlers pass to coord modules,
-- plus a captures table the assertions inspect.
--
-- Options:
--   with_buttons (boolean, default false): also captures set_button +
--     set_touch_enabled. Atlas-style panels leave it off; skin-shop turns it on.
--
-- Captures layout:
--   visibility[node_name]   -> boolean (set_visible last value)
--   labels[node_name]       -> string  (set_label last value)
--   textures[node]          -> string  (set_node_texture_keep_size key)
--   button_text[node_name]  -> string  (set_button last value)    -- with_buttons
--   button_touch[node_name] -> boolean (set_touch_enabled value)  -- with_buttons
function ui_mock.build_render_state(opts)
  opts = opts or {}
  local captures = {
    visibility = {},
    labels = {},
    textures = {},
  }
  local ui = {
    set_visible = function(_, name, visible)
      captures.visibility[name] = visible == true
    end,
    set_label = function(_, name, text)
      captures.labels[name] = text
    end,
  }
  if opts.with_buttons then
    captures.button_text = {}
    captures.button_touch = {}
    ui.set_button = function(_, name, text)
      captures.button_text[name] = text
    end
    ui.set_touch_enabled = function(_, name, enabled)
      captures.button_touch[name] = enabled == true
    end
  end
  local fake_runtime = {
    query_node = function(name) return name end,
    set_node_texture_keep_size = function(node, key)
      captures.textures[node] = key
    end,
  }
  local state = {
    ui = ui,
    ui_refs = { images = {}, skins = {} },
    presentation_runtime = { runtime = fake_runtime },
    gameplay_loop_ports = presentation_ports.build(),
  }
  return state, captures
end

return ui_mock
