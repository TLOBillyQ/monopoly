local OasisRuntime = require("src.adapters.oasis.oasis_runtime")
local Game = require("src.game")

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

local function make_node()
  return {
    SetText = function(self, text)
      self.text = text
    end,
    SetVisibility = function(self, visible)
      self.visible = visible
    end,
    SetIsEnabled = function(self, enabled)
      self.enabled = enabled
    end,
  }
end

local function make_root(names)
  local widgets = {}
  for _, name in ipairs(names) do
    widgets[name] = make_node()
  end
  return {
    widgets = widgets,
    GetWidgetFromName = function(self, name)
      return self.widgets[name]
    end,
  }
end

local root = make_root({
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
  "panel_tile_title",
  "tile_detail_name",
  "tile_detail_price",
  "tile_detail_level",
  "tile_detail_owner",
  "tile_detail_roadblock",
  "tile_detail_mine",
  "panel_log_title",
  "panel_log_body",
  "btn_next",
  "btn_auto",
  "btn_restart",
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
})

OasisRuntime.on_begin_play({
  ui_root = root,
  game_factory = create_game,
})
print("[OasisAdapter] init ok")

OasisRuntime.on_ui_event({ event_name = "ui_button", id = "next" })
OasisRuntime.on_tick(0.1)
print("[OasisAdapter] tick ok")
