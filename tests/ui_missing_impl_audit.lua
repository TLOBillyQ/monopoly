local ok, ui_data = pcall(require, "Data.ui_data")
if not ok or type(ui_data) ~= "table" then
  io.stderr:write("[ui-missing] failed to require Data.ui_data\n")
  os.exit(1)
end

local EggyLayerUI = require("src.adapters.eggy.eggy_layer_ui")
local MarketUI = require("src.adapters.eggy.market_ui")

local function add(set, name)
  if name and name ~= "" then
    set[name] = true
  end
end

local function add_list(set, list)
  for _, name in ipairs(list or {}) do
    add(set, name)
  end
end

local function build_alias_map()
  local map = {
    choice_option_1 = "choice_option1",
    choice_option_2 = "choice_option2",
    choice_option_3 = "choice_option3",
    choice_option_4 = "choice_option4",
  }
  for i = 1, 10 do
    map["market_item_button_" .. tostring(i)] = "market_item_button" .. tostring(i)
    map["market_item_label_" .. tostring(i)] = "market_item_label_" .. tostring(i)
    map["market_item_frame_" .. tostring(i)] = "market_item_frame_" .. tostring(i)
  end
  return map
end

local function build_used_nodes()
  local used = {}
  local ui_state = EggyLayerUI.build_ui_state()
  add_list(used, ui_state.item_slots)
  add(used, ui_state.choice and ui_state.choice.root)
  add(used, ui_state.choice and ui_state.choice.title)
  add(used, ui_state.choice and ui_state.choice.body)
  add(used, ui_state.choice and ui_state.choice.cancel)
  add_list(used, ui_state.choice and ui_state.choice.option_buttons)
  add(used, ui_state.popup and ui_state.popup.root)
  add(used, ui_state.popup and ui_state.popup.title)
  add(used, ui_state.popup and ui_state.popup.body)
  add(used, ui_state.popup and ui_state.popup.confirm)

  add(used, "panel_title")
  add(used, "panel_turn")
  for i = 1, 4 do
    add(used, "panel_player_" .. tostring(i) .. "_name")
    add(used, "panel_player_" .. tostring(i) .. "_cash")
    add(used, "panel_player_" .. tostring(i) .. "_land_count")
    add(used, "panel_player_" .. tostring(i) .. "_detail")
  end
  add(used, "btn_next")
  add(used, "btn_auto")

  add(used, MarketUI.container)
  add(used, MarketUI.confirm_button)
  add(used, MarketUI.cancel_button)
  add(used, MarketUI.price_label)
  add(used, MarketUI.selected_card)
  add(used, MarketUI.icon_placeholder)
  add_list(used, MarketUI.item_buttons)
  add_list(used, MarketUI.item_labels)
  add_list(used, MarketUI.item_frames)

  return used
end

local alias_map = build_alias_map()
local allowed_missing = {
  panel_player_1_land_count = true,
  panel_player_4_land_count = true,
}
local used = build_used_nodes()
local ui_names = {}
local ui_types = {}

for _, entry in pairs(ui_data) do
  local name = entry[1]
  local kind = entry[2]
  if name then
    ui_names[name] = true
    ui_types[name] = kind
  end
end

local missing_in_ui_data = {}
local blocking_missing = {}
local alias_hits = {}
for name in pairs(used) do
  if not ui_names[name] then
    local alias = alias_map[name]
    if alias and ui_names[alias] then
      alias_hits[name] = alias
    else
      table.insert(missing_in_ui_data, name)
      if not allowed_missing[name] then
        table.insert(blocking_missing, name)
      end
    end
  end
end

local missing_in_adapter = {}
for name in pairs(ui_names) do
  if not used[name] then
    table.insert(missing_in_adapter, name)
  end
end

table.sort(missing_in_ui_data)
table.sort(missing_in_adapter)

io.stdout:write("[ui-missing] MissingInUiData:\n")
for _, name in ipairs(missing_in_ui_data) do
  io.stdout:write("  - " .. name .. "\n")
end

io.stdout:write("[ui-missing] MissingInAdapter:\n")
for _, name in ipairs(missing_in_adapter) do
  io.stdout:write("  - " .. name .. " (" .. tostring(ui_types[name]) .. ")\n")
end

io.stdout:write("[ui-missing] AliasHits:\n")
for name, alias in pairs(alias_hits) do
  io.stdout:write("  - " .. name .. " -> " .. alias .. "\n")
end

if #blocking_missing > 0 then
  os.exit(1)
end
