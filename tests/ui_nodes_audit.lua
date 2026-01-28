local function load_ui_names()
  local ok, nodes = pcall(require, "Data.ui_data")
  if not ok or type(nodes) ~= "table" then
    io.stderr:write("[ui-audit] failed to require Data.ui_data\n")
    os.exit(1)
  end
  local names = {}
  for _, entry in pairs(nodes) do
    if type(entry) == "table" then
      local name = entry[1]
      if type(name) == "string" and name ~= "" then
        names[name] = true
      end
    end
  end
  return names
end

local function resolve_ui_name(name)
  return name
end

local function build_required_logical_names()
  local required = {
    "panel_title",
    "panel_turn",
    "panel_current_title",
    "panel_current_name",
    "panel_current_role",
    "panel_current_phase",
    "panel_current_dice",
    "panel_players_title",
    "panel_player_1",
    "panel_player_1_detail",
    "panel_player_2",
    "panel_player_2_detail",
    "panel_player_3",
    "panel_player_3_detail",
    "panel_player_4",
    "panel_player_4_detail",
    "panel_item_slots",
    "item_slot_1",
    "item_slot_2",
    "item_slot_3",
    "item_slot_4",
    "item_slot_5",
    "panel_tile_title",
    "tile_detail_name",
    "tile_detail_price",
    "tile_detail_level",
    "tile_detail_owner",
    "tile_detail_roadblock",
    "tile_detail_mine",
    "btn_next",
    "btn_auto",
    "btn_restart",
    "panel_log_title",
    "panel_log_body",
    "modal_choice",
    "choice_title",
    "choice_body",
    "choice_cancel",
    "choice_option_1",
    "choice_option_2",
    "choice_option_3",
    "choice_option_4",
    "modal_popup",
    "popup_title",
    "popup_body",
    "popup_confirm",
    "popup_confirm_alt",
    "popup_card",
    "btn_auto_label",
    "panel_player_1_info",
    "panel_player_1_avatar",
    "panel_player_1_cash",
    "panel_player_1_land_count",
    "panel_player_1_base",
    "panel_player_1_base_color",
    "panel_player_2_info",
    "panel_player_2_avatar",
    "panel_player_2_cash",
    "panel_player_2_land_count",
    "panel_player_2_base",
    "panel_player_2_base_color",
    "panel_player_3_info",
    "panel_player_3_avatar",
    "panel_player_3_cash",
    "panel_player_3_land_count",
    "panel_player_3_base",
    "panel_player_3_base_color",
    "panel_player_4_info",
    "panel_player_4_avatar",
    "panel_player_4_cash",
    "panel_player_4_land_count",
    "panel_player_4_base",
    "panel_player_4_base_color",
    "loading_screen",
    "loading_tip",
    "base_screen",
    "overlay_mask",
    "background_rect",
  }

  -- Board tiles: presenter uses 45 tiles in the demo map.
  for i = 1, 45 do
    required[#required + 1] = "tile_" .. tostring(i)
  end

  return required
end

local function append_market_requirements(required)
  local ok, market = pcall(require, "src.adapters.eggy.market_ui")
  if not ok or type(market) ~= "table" then
    return required
  end
  local function add(name)
    if type(name) == "string" and name ~= "" then
      required[#required + 1] = name
    end
  end
  add(market.container)
  add(market.confirm_button)
  add(market.cancel_button)
  add(market.price_label)
  add(market.selected_card)
  add(market.icon_placeholder)
  if type(market.item_buttons) == "table" then
    for _, name in ipairs(market.item_buttons) do
      add(name)
    end
  end
  if type(market.item_labels) == "table" then
    for _, name in ipairs(market.item_labels) do
      add(name)
    end
  end
  if type(market.item_frames) == "table" then
    for _, name in ipairs(market.item_frames) do
      add(name)
    end
  end
  return required
end

local function audit()
  local ui_names = load_ui_names()
  local required = build_required_logical_names()
  required = append_market_requirements(required)

  local missing_logical = {}
  local missing_resolved = {}
  local seen = {}

  for _, logical in ipairs(required) do
    if not seen[logical] then
      seen[logical] = true
      local resolved = resolve_ui_name(logical)
      if not ui_names[resolved] then
        missing_logical[#missing_logical + 1] = logical
        missing_resolved[#missing_resolved + 1] = resolved
      end
    end
  end

  if #missing_logical == 0 then
    print("[ui-audit] ok: all required nodes/events are present (directly or via mapping)")
    return
  end

  print("[ui-audit] missing logical nodes/events: " .. tostring(#missing_logical))
  for i = 1, #missing_logical do
    print(string.format("  - %s -> %s", missing_logical[i], missing_resolved[i]))
  end
  os.exit(1)
end

audit()
