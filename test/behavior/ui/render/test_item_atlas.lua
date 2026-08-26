-- #293 批3 pin:src/ui/render/widgets/item_atlas.lua 的幸存者分四簇:
-- ① 卡片格刷新链(_refresh_card 的 item 存在性分支、纹理应用、显隐、
--    touch 开关,经 ui/runtime 双桩捕获击杀);
-- ② 分页箭头链(_refresh_page_arrows 的 page_count/page_index 比较与
--    双向箭头显隐);
-- ③ 放大卡链(show_enlarged 的 image_key 缺失早退、纹理应用、overlay
--    显隐与 close_blank touch);
-- ④ 隐藏链(hide_enlarged 的 overlay 整体隐藏)。
-- refs 走真实 asset_context 链(state.runtime_asset_context 直供),runtime 经
-- deps.runtime 直桩(query_nodes 双节点路径),assert 消息类幸存者为等价。

local lu = require("luaunit")

local item_atlas_view = require("src.ui.render.widgets.item_atlas")
local nodes = require("src.ui.schema.item_atlas")

local _PAGE_SIZE = #nodes.card_images

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _env()
  local env = { visible = {}, touch = {}, textures = {}, global_calls = {} }
  env.runtime = {
    query_nodes = function(node_name)
      return { "n1_" .. node_name, "n2_" .. node_name }
    end,
    query_node = function(node_name)
      return "n_" .. node_name
    end,
    set_node_texture_keep_size = function(node, image_key)
      env.textures[#env.textures + 1] = { node = node, image_key = image_key }
    end,
  }
  env.deps = { runtime = env.runtime }
  env.ui = {
    set_visible = function(_, node_name, visible)
      env.visible[#env.visible + 1] = { node_name = node_name, visible = visible }
    end,
    -- #544 退役钉:global 广播变体已拆除;若被重新引入,调用落入 global_calls
    -- 并打破放大/隐藏用例的零调用断言(旁观者泄漏即由广播变体造成)。
    set_visible_global = function(_, node_name, visible)
      env.global_calls[#env.global_calls + 1] = { "set_visible_global", node_name, visible }
    end,
    set_touch_enabled = function(_, node_name, enabled)
      env.touch[#env.touch + 1] = { node_name = node_name, enabled = enabled }
    end,
    set_touch_enabled_global = function(_, node_name, enabled)
      env.global_calls[#env.global_calls + 1] = { "set_touch_enabled_global", node_name, enabled }
    end,
  }
  return env
end

local function _state(env, images)
  return {
    ui = env.ui,
    runtime_asset_context = { refs = { images = images or {} } },
  }
end

local function _catalog(first_id, count)
  local catalog = {}
  for i = 1, count do
    catalog[i] = { id = tostring(first_id + i - 1) }
  end
  return catalog
end

local function _visible_for(env, node_name)
  for _, call in ipairs(env.visible) do
    if call.node_name == node_name then
      return call.visible
    end
  end
  return "unset"
end

TestItemAtlas = {}

function TestItemAtlas:test_refresh_page_applies_textures_and_visibility_for_first_page()
  -- 首版主契约:在场道具格应用纹理并可见,空格隐藏;touch 跟随 has_item。
  -- L31 image_key 直取链、L42/L62/L64/L67 调用换 nil、L60 item 换 nil
  -- (在场道具当空格处理)与 L59 has_item 的 ~= -> == 在此击杀。
  local env = _env()
  local images = { ["1001"] = "img_1001", ["1002"] = "img_1002" }
  local catalog = _catalog(1001, 16)
  item_atlas_view.refresh_page(_state(env, images), catalog, 1, env.deps)

  _assert_eq(#env.textures, 2 * 2, "two present cards must apply two textures each")
  _assert_eq(env.textures[1].image_key, "img_1001", "first card must apply its image key")
  _assert_eq(env.textures[3].image_key, "img_1002", "second card must apply its image key")
  for slot = 1, 2 do
    _assert_eq(_visible_for(env, nodes.card_images[slot]), true, "present card " .. slot .. " must be visible")
  end
  for slot = 1, 2 do
    local found = false
    for _, call in ipairs(env.touch) do
      if call.node_name == nodes.card_images[slot] then
        _assert_eq(call.enabled, true, "present card touch must be enabled")
        found = true
      end
    end
    _assert_eq(found, true, "present card touch must be set")
  end
  _assert_eq(_visible_for(env, nodes.page_prev), false, "first page must hide the prev arrow")
  _assert_eq(_visible_for(env, nodes.page_next), true, "first page must show the next arrow")
end

function TestItemAtlas:test_refresh_page_hides_empty_slots_and_disables_their_touch()
  -- 空格契约:目录不足一页时尾部槽位必须隐藏且 touch 关。
  local env = _env()
  local images = { ["1001"] = "img_1001" }
  local catalog = _catalog(1001, 5)
  item_atlas_view.refresh_page(_state(env, images), catalog, 1, env.deps)
  for slot = 6, _PAGE_SIZE do
    _assert_eq(_visible_for(env, nodes.card_images[slot]), false, "empty slot " .. slot .. " must be hidden")
    local found = false
    for _, call in ipairs(env.touch) do
      if call.node_name == nodes.card_images[slot] then
        _assert_eq(call.enabled, false, "empty slot touch must be disabled")
        found = true
      end
    end
    _assert_eq(found, true, "empty slot touch must be set")
  end
end

function TestItemAtlas:test_refresh_page_second_page_uses_offset_catalog_slots()
  -- L89 `(page_index - 1) * PAGE_SIZE` 的 - -> + 与 L92 槽位取数:第二页
  -- 的槽 1 必须取 catalog[PAGE_SIZE + 1] 起。
  local env = _env()
  local images = { ["1009"] = "img_1009" }
  local catalog = _catalog(1001, 16)
  item_atlas_view.refresh_page(_state(env, images), catalog, 2, env.deps)

  _assert_eq(env.textures[1].image_key, "img_1009", "page two slot one must be catalog[PAGE_SIZE+1]")
  _assert_eq(_visible_for(env, nodes.page_prev), true, "second page must show the prev arrow")
  _assert_eq(_visible_for(env, nodes.page_next), false, "second page must hide the next arrow")
end

function TestItemAtlas:test_refresh_page_hides_both_arrows_on_out_of_range_page()
  -- L72 `page_count > 1` 的 > -> >=(单页目录在第 2 页误显 prev):页数
  -- 不足时两个箭头都必须隐藏。
  local env = _env()
  local catalog = _catalog(1001, 8)
  item_atlas_view.refresh_page(_state(env, {}), catalog, 2, env.deps)
  _assert_eq(_visible_for(env, nodes.page_prev), false, "single-page catalog must hide prev even at page two")
  _assert_eq(_visible_for(env, nodes.page_next), false, "single-page catalog must hide next at page two")
end

function TestItemAtlas:test_show_enlarged_applies_texture_and_shows_overlay()
  -- 放大主契约:有图道具应用纹理(enlarged_card 双节点)、overlay 三节点
  -- 显 true、close_blank touch 开。L31 链、L104 `== nil` 的 == -> ~=、
  -- L110/L118 调用换 nil、L25 `visible == true` 的 == -> ~= 在此击杀。
  -- #544:显隐/触摸必须走 per-role 变体,global 广播变体零调用。
  local env = _env()
  item_atlas_view.show_enlarged(_state(env, { ["2001"] = "img_2001" }), "2001", env.deps)
  _assert_eq(#env.textures, 2, "enlarged card must apply its texture to matched nodes")
  _assert_eq(env.textures[1].image_key, "img_2001", "enlarged image key")
  for _, node_name in ipairs({ nodes.enlarged_card, nodes.close_hint_label, nodes.close_blank }) do
    _assert_eq(_visible_for(env, node_name), true, "overlay node " .. node_name .. " must be shown")
  end
  local blank_touch = nil
  for _, call in ipairs(env.touch) do
    if call.node_name == nodes.close_blank then
      blank_touch = call.enabled
    end
  end
  _assert_eq(blank_touch, true, "close blank must be touchable while enlarged")
  _assert_eq(#env.global_calls, 0, "enlarged overlay must not use global broadcast variants (#544)")
end

function TestItemAtlas:test_show_enlarged_returns_early_without_image()
  -- 无图道具必须整体不落纹理、不显 overlay。
  local env = _env()
  item_atlas_view.show_enlarged(_state(env, {}), "9999", env.deps)
  _assert_eq(#env.textures, 0, "missing image must not apply a texture")
  _assert_eq(#env.visible, 0, "missing image must not show the overlay")
end

function TestItemAtlas:test_show_enlarged_texture_failure_carries_context()
  -- #541:放大卡贴图推送失败时,冒出的错误文本须含宿主原文 + image_key
  -- + 节点名 + 道具 id,事后仅凭日志即可分辨失败现场。
  local env = _env()
  env.runtime.set_node_texture_keep_size = function()
    error("host_push_exploded")
  end
  local ok, err = pcall(item_atlas_view.show_enlarged, _state(env, { ["2001"] = "img_2001" }), "2001", env.deps)
  lu.assertEvalToTrue(ok == false, "texture push failure must propagate")
  for _, fragment in ipairs({ "host_push_exploded", "img_2001", "2001", nodes.enlarged_card }) do
    lu.assertEvalToTrue(tostring(err):find(fragment, 1, true) ~= nil,
      "error text must carry '" .. fragment .. "': " .. tostring(err))
  end
end

function TestItemAtlas:test_hide_enlarged_hides_overlay_and_disables_touch()
  -- 隐藏主契约:overlay 三节点显 false、close_blank touch 关。
  -- #544:隐藏同样不得走 global 广播变体。
  local env = _env()
  item_atlas_view.hide_enlarged(_state(env, {}))
  for _, node_name in ipairs({ nodes.enlarged_card, nodes.close_hint_label, nodes.close_blank }) do
    _assert_eq(_visible_for(env, node_name), false, "overlay node " .. node_name .. " must be hidden")
  end
  local blank_touch = nil
  for _, call in ipairs(env.touch) do
    if call.node_name == nodes.close_blank then
      blank_touch = call.enabled
    end
  end
  _assert_eq(blank_touch, false, "close blank must lose touch while hidden")
  _assert_eq(#env.global_calls, 0, "hide enlarged must not use global broadcast variants (#544)")
end

return TestItemAtlas

--[[ mutate4lua-manifest
version=4
projectHash=dfc50a50f5eab8c5
scope.0.id=chunk:test/behavior/ui/render/test_item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=217
scope.0.semanticHash=73f67dd2420e2c9e
scope.1.id=function:_assert_eq
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=21
scope.1.semanticHash=c598c40f568cc607
scope.2.id=function:_env
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=54
scope.2.semanticHash=e8ec55eb9c6b3073
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=49b05d91b28a7d49
scope.4.id=function:<anonymous>#2
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=31
scope.4.semanticHash=807d1caaf433dd3e
scope.5.id=function:<anonymous>#3
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=34
scope.5.semanticHash=7a0e7309f215c561
scope.6.id=function:<anonymous>#4
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=f0b3cbcea46f9d1e
scope.7.id=function:<anonymous>#5
scope.7.kind=function
scope.7.startLine=43
scope.7.endLine=45
scope.7.semanticHash=ee89f7adcfc10588
scope.8.id=function:<anonymous>#6
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=48
scope.8.semanticHash=f0b3cbcea46f9d1e
scope.9.id=function:<anonymous>#7
scope.9.kind=function
scope.9.startLine=49
scope.9.endLine=51
scope.9.semanticHash=ee89f7adcfc10588
scope.10.id=function:_state
scope.10.kind=function
scope.10.startLine=56
scope.10.endLine=61
scope.10.semanticHash=ed9d4381f1949dae
scope.11.id=function:_catalog
scope.11.kind=function
scope.11.startLine=63
scope.11.endLine=69
scope.11.semanticHash=516b9fecefb009b2
scope.12.id=function:_visible_for
scope.12.kind=function
scope.12.startLine=71
scope.12.endLine=78
scope.12.semanticHash=18a30a84862b170d
scope.13.id=function:TestItemAtlas:test_refresh_page_applies_textures_and_visibility_for_first_page
scope.13.kind=function
scope.13.startLine=82
scope.13.endLine=109
scope.13.semanticHash=af35480853df1398
scope.14.id=function:TestItemAtlas:test_refresh_page_hides_empty_slots_and_disables_their_touch
scope.14.kind=function
scope.14.startLine=111
scope.14.endLine=128
scope.14.semanticHash=d96fa3c743388369
scope.15.id=function:TestItemAtlas:test_refresh_page_second_page_uses_offset_catalog_slots
scope.15.kind=function
scope.15.startLine=130
scope.15.endLine=141
scope.15.semanticHash=6cf1208be02e76db
scope.16.id=function:TestItemAtlas:test_refresh_page_hides_both_arrows_on_out_of_range_page
scope.16.kind=function
scope.16.startLine=143
scope.16.endLine=151
scope.16.semanticHash=212a7306c2e6ab5c
scope.17.id=function:TestItemAtlas:test_show_enlarged_applies_texture_and_shows_overlay
scope.17.kind=function
scope.17.startLine=153
scope.17.endLine=173
scope.17.semanticHash=2b280eb3e3f27d4d
scope.18.id=function:TestItemAtlas:test_show_enlarged_returns_early_without_image
scope.18.kind=function
scope.18.startLine=175
scope.18.endLine=181
scope.18.semanticHash=dad2139b38273898
scope.19.id=function:TestItemAtlas:test_show_enlarged_texture_failure_carries_context
scope.19.kind=function
scope.19.startLine=183
scope.19.endLine=196
scope.19.semanticHash=dbe5de362cfb072d
scope.20.id=function:env.runtime.set_node_texture_keep_size
scope.20.kind=function
scope.20.startLine=187
scope.20.endLine=189
scope.20.semanticHash=b1f16ed07f03ac7a
scope.21.id=function:TestItemAtlas:test_hide_enlarged_hides_overlay_and_disables_touch
scope.21.kind=function
scope.21.startLine=198
scope.21.endLine=214
scope.21.semanticHash=61e89576d439c702
]]
