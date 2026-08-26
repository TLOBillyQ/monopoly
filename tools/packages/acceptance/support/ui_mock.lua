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
    runtime_asset_context = { refs = { images = {}, skins = {} } },
    presentation_runtime = { runtime = fake_runtime },
    gameplay_loop_ports = presentation_ports.build(),
  }
  return state, captures
end

return ui_mock

--[[ mutate4lua-manifest
version=4
projectHash=9f52a801e8e5e0ff
scope.0.id=chunk:tools/packages/acceptance/support/ui_mock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=22199f0dafc45f7c
scope.1.id=function:ui_mock.build_render_state
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=57
scope.1.semanticHash=f845332dc29fb30f
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=29
scope.2.semanticHash=113c32d64405a907
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=32
scope.3.semanticHash=4218fa0408531805
scope.4.id=function:ui.set_button
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=4218fa0408531805
scope.5.id=function:ui.set_touch_enabled
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=42
scope.5.semanticHash=113c32d64405a907
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=45
scope.6.semanticHash=eba5730cfa182143
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=48
scope.7.semanticHash=8f61438f251acaa2
]]
