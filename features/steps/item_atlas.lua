-- 道具图鉴绑定(features/v102/item_atlas.feature):走 src.ui 公开面 + ui_mock
-- 渲染捕获,目录经 configure_catalog_for_tests 注入。
local dsl = require("packages.acceptance.step_dsl")
local item_atlas = require("src.ui.screens.item_atlas")
local atlas_nodes = require("src.ui.schema.item_atlas")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local ui_mock = require("packages.acceptance.support.ui_mock")
local number_utils = require("src.foundation.number")
local eq, truthy = dsl.eq, dsl.truthy
local PAGE_SIZE = atlas_nodes.page_size
local function _make_catalog(count) local catalog = {} for i = 1, count do catalog[i] = { id = "item_" .. i, name = "道具" .. i, description = "描述" .. i } end return catalog end
local function _state(w)
  if not w.atlas_state then
    local state, captures = ui_mock.build_render_state()
    w.atlas_state = state
    w.atlas_visibility, w.atlas_labels, w.atlas_textures =
      captures.visibility, captures.labels, captures.textures
    if not w.atlas_catalog_injected then item_atlas.reset_for_tests() end
    for _, item in ipairs(item_atlas.catalog or {}) do
      state.runtime_asset_context.refs.images[tostring(item.id)] = "tex_" .. tostring(item.id)
    end
  end
  return w.atlas_state
end
local function _atlas(w) return _state(w).ui.item_atlas end
local function _act(w, action) item_atlas.handle_action(_state(w), action, w.ui_role_id or 1) end
local function _slot_item(w, slot) local atlas = _atlas(w) return item_atlas.catalog[(atlas.page_index - 1) * PAGE_SIZE + slot], atlas end
local function _selected_matches_slot(w, a, check_field)
  local item, atlas = _slot_item(w, a["槽位"])
  if not item then return nil, "槽位 " .. tostring(a["槽位"]) .. " 无道具" end
  if check_field and not item[check_field] then return nil, "道具缺 " .. check_field end
  return eq(atlas.selected_item_id, item.id, "选中道具")
end
local function _vis(node, expect_visible, label) return function(w) return eq(w.atlas_visibility[node] == true, expect_visible, label) end end
local defs = {
  ["道具目录共有<道具数:int>种道具"] = function(w, a) item_atlas.configure_catalog_for_tests(_make_catalog(a["道具数"])) w.atlas_catalog_injected = true return true end,
  ["玩家打开道具图鉴"] = function(w) item_atlas.open(_state(w), w.ui_role_id or 1) return true end,
  ["玩家关闭道具图鉴"] = function(w) item_atlas.close(_state(w), w.ui_role_id or 1) return true end,
  ["道具图鉴屏幕已开启"] = function(w) return truthy(_atlas(w) and _atlas(w).open, "图鉴开启") end,
  ["道具图鉴屏幕已关闭"] = function(w) local atlas = w.atlas_state and _atlas(w) return truthy(not (atlas and atlas.open), "图鉴关闭") end,
  ["触发基础屏图鉴按钮"] = function(w)
    for _, spec in ipairs(base_intents.build(_state(w))) do
      if spec.name == base_nodes.gallery_button then
        local intent = spec.build_intent()
        intent.actor_role_id = w.ui_role_id or 1
        view_command.dispatch(w.atlas_state, intent)
        return true
      end
    end
    return nil, "base canvas 未注册 gallery_button 路由"
  end,
  ["玩家选中第<槽位:int>格道具"] = function(w, a) _act(w, { type = "select", slot_index = a["槽位"] }) return true end,
  ["玩家点击空白区域关闭放大卡牌"] = function(w) _act(w, "dismiss") return true end,
  ["玩家翻到图鉴下一页"] = function(w) _act(w, "next") return true end,
  ["玩家翻到图鉴上一页"] = function(w) _act(w, "prev") return true end,
  ["当前选中道具为第<槽位:int>格对应道具"] = function(w, a) return _selected_matches_slot(w, a) end,
  ["当前选中道具ID为<选中道具>"] = function(w, a) return eq(_atlas(w).selected_item_id, tostring(a["选中道具"] or ""), "选中道具ID") end,
  ["放大卡牌已展示"] = function(w) return truthy(_atlas(w).selected_item_id, "放大卡牌") end,
  ["放大卡牌已隐藏"] = function(w) return eq(_atlas(w) and _atlas(w).selected_item_id, nil, "放大卡牌") end,
  ["放大卡牌显示第<槽位:int>格道具的名称"] = function(w, a) return _selected_matches_slot(w, a, "name") end,
  ["放大卡牌显示第<槽位:int>格道具的描述"] = function(w, a) return _selected_matches_slot(w, a, "description") end,
  ["无道具被选中"] = function(w) return eq(_atlas(w) and _atlas(w).selected_item_id, nil, "选中状态") end,
  ["当前页面展示<槽位数:int>个道具槽位"] = function(w, a) local count = 0 for slot = 1, PAGE_SIZE do if _slot_item(w, slot) then count = count + 1 end end return eq(count, a["槽位数"], "当前页槽位数") end,
  ["图鉴总页数为<总页数:int>"] = function(_, a) return eq(number_utils.page_count(#item_atlas.catalog, PAGE_SIZE), a["总页数"], "总页数") end,
  ["道具目录末页展示<末页槽位数:int>个道具槽位"] = function(_, a) local remainder = #item_atlas.catalog % PAGE_SIZE local actual = remainder == 0 and math.min(#item_atlas.catalog, PAGE_SIZE) or remainder return eq(actual, a["末页槽位数"], "末页槽位数") end,
  ["图鉴打开角色ID为<验证角色ID:int>"] = function(w, a) return eq(_atlas(w).role_id, a["验证角色ID"], "图鉴角色ID") end,
  ["当前图鉴页码为1"] = function(w) return eq(_atlas(w).page_index, 1, "页码") end,
  ["当前图鉴页码为<页码:int>"] = function(w, a) return eq(_atlas(w).page_index, a["页码"], "页码") end,
  ["图鉴卡片渲染数为<卡片渲染数:int>个"] = function(w, a) local count = 0 for slot = 1, PAGE_SIZE do if w.atlas_visibility[atlas_nodes.card_images[slot]] == true then count = count + 1 end end return eq(count, a["卡片渲染数"], "可见卡片数") end,
  ["图鉴卡牌槽位<槽位:int>当前贴图为道具<道具ID>的图"] = function(w, a)
    _state(w)
    local node = atlas_nodes.card_images[a["槽位"]]
    if node == nil then return nil, "槽位 " .. tostring(a["槽位"]) .. " 无卡牌节点" end
    local expected = w.atlas_state.runtime_asset_context.refs.images[tostring(a["道具ID"] or "")]
    if expected == nil then return nil, "道具 " .. tostring(a["道具ID"]) .. " 未注册贴图" end
    return eq(w.atlas_textures[node], expected, "槽位" .. tostring(a["槽位"]) .. "贴图")
  end,
  ["图鉴静态文本未被改写"] = function(w)
    -- 节点名以 Data/UIManagerNodes.lua 为准: 底框_1 带下划线,底框2 不带。
    for _, node in ipairs({ "图鉴_图鉴文本", "图鉴_图鉴底框_1", "图鉴_图鉴底框2" }) do
      if w.atlas_labels[node] ~= nil then
        return nil, node .. " 文字被改写为: " .. tostring(w.atlas_labels[node])
      end
    end
    return true
  end,
}
for sentence, spec in pairs({
  ["图鉴关闭提示已展示"] = { atlas_nodes.close_hint_label, true },
  ["图鉴关闭提示已隐藏"] = { atlas_nodes.close_hint_label, false },
  ["图鉴空白关闭层已展示"] = { atlas_nodes.close_blank, true },
  ["图鉴空白关闭层已隐藏"] = { atlas_nodes.close_blank, false },
  ["图鉴上一页箭头已展示"] = { atlas_nodes.page_prev, true },
  ["图鉴上一页箭头已隐藏"] = { atlas_nodes.page_prev, false },
  ["图鉴下一页箭头已展示"] = { atlas_nodes.page_next, true },
  ["图鉴下一页箭头已隐藏"] = { atlas_nodes.page_next, false },
}) do
  defs[sentence] = _vis(spec[1], spec[2], sentence)
end
return dsl.steps(defs, { name = "item_atlas" })
