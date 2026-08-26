-- Player 初始化锚定：auto_share_panel_shown 必须由真实 Player 对象初始化
-- （默认 false，attrs 可恢复）；控制模式由 src.player.control 初始化，旧托管
-- 字段（auto / auto_source）与幽灵 AI 字段（ai）不得残留。dispatch 侧 spec
-- 全用手搓 stub 表，字段名写错/漏初始化照样绿；本 spec 用真实 Player 钉住。
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local player_class = require("src.player.actions.player")
local control = require("src.player.control")
local constants = require("src.config.content.constants")

local function _new_player(attrs)
  local merged = { id = 1, name = "P1", constants = constants }
  for k, v in pairs(attrs or {}) do
    merged[k] = v
  end
  return player_class:new(merged)
end

TestPlayerInit = {}

function TestPlayerInit:test_initializes_auto_share_panel_shown_to_false_by_default()
  local player = _new_player()
  _assert_eq(player.auto_share_panel_shown, false, "default must be false")
end

function TestPlayerInit:test_restores_auto_share_panel_shown_from_attrs()
  _assert_eq(_new_player({ auto_share_panel_shown = true }).auto_share_panel_shown, true,
    "attrs true must restore as true")
  _assert_eq(_new_player({ auto_share_panel_shown = false }).auto_share_panel_shown, false,
    "attrs false must restore as false")
end

function TestPlayerInit:test_initializes_a_human_player_in_direct_control()
  local player = _new_player()
  _assert_eq(control.is_delegated(player), false, "new human must not be delegated")
  _assert_eq(control.is_afk_delegated(player), false, "new human must not be AFK delegated")
  _assert_eq(control.is_computer_controlled(player), false, "new human must be directly controlled")
end

function TestPlayerInit:test_initializes_a_replacement_computer_in_direct_control()
  local player = _new_player({ is_ai = true })
  _assert_eq(control.is_replacement_computer(player), true, "is_ai true must mark a replacement computer")
  _assert_eq(control.is_delegated(player), false, "a replacement computer must not be delegated")
  _assert_eq(control.is_computer_controlled(player), true, "a replacement computer must be computer controlled")
end

function TestPlayerInit:test_does_not_keep_legacy_auto_or_ghost_ai_fields()
  local player = _new_player({ is_ai = true, auto = true, auto_source = "afk", ai = true })
  _assert_eq(player.auto, nil, "legacy auto switch must be gone")
  _assert_eq(player.auto_source, nil, "legacy auto source must be gone")
  _assert_eq(player.ai, nil, "ghost ai field must be gone")
end

-- 初始状态字段锚定:stay_turns / deity / pending_dice_multiplier 的缺省值
-- 被回合逻辑直接消费,数值变异(0→1 / ""→nil)必须钉住(#293)。
function TestPlayerInit:test_initial_status_fields_match_the_defaults()
  local player = _new_player()
  _assert_eq(player.status.stay_turns, 0, "stay_turns must start at 0")
  _assert_eq(player.status.deity.type, "", "deity type must start as the empty string")
  _assert_eq(player.status.deity.remaining, 0, "deity remaining must start at 0")
  _assert_eq(player.status.pending_dice_multiplier, 1, "dice multiplier must start at 1")
end


return TestPlayerInit
