-- #293 批3 pin:src/ui/render/board/building_effects.lua 的幸存者:
-- 清除链(残留 group 销毁、组表清空、文本复位、返回 true)与生成链
-- (create_unit_group 直调、组表记录、文本应用、prefab 缺键/未知等级早退)。
-- 桩 deps.host_runtime(经 host_runtime_resolver 直通,不 patch 模块)、
-- math.Vector3 覆写为带 __add 的夹具向量(pos + offset 才可算)。
-- 断言消息类幸存者为等价,不在击杀目标内。

local lu = require("luaunit")
local vec3 = require("test.fixtures.vec3")

local building_effects = require("src.ui.render.board.building_effects")
local prefab = require("Data.Prefab")

local _saved_vector3 = math.Vector3
local _saved_ref_key = prefab.group["一级建筑"]

local _captured = nil

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _text_objects()
  local text = {}
  local entry = {
    set_billboard_text = function(value)
      text[#text + 1] = value
    end,
  }
  return text, entry
end

local function _deps()
  return {
    host_runtime = {
      destroy_unit_with_children = function(handle, destroy_children)
        _captured.destroy[#_captured.destroy + 1] = { handle = handle, destroy_children = destroy_children }
      end,
      create_unit_group = function(group_id, pos, quaternion)
        _captured.create[#_captured.create + 1] = { group_id = group_id, pos = pos, quaternion = quaternion }
        return "new_unit"
      end,
    },
  }
end

local function _scene()
  local text, entry = _text_objects()
  _captured.txt = text
  return {
    building_unit_groups = {},
    buildings = {
      [1] = {
        get_position = function()
          return { x = 0.0, y = 0.0, z = 0.0 }
        end,
      },
    },
    building_txt = { [1] = entry },
  }
end

TestBuildingEffects = {}

function TestBuildingEffects:setUp()
  _captured = { destroy = {}, create = {}, txt = {} }
  -- __add 夹具:pos(普通表) + offset(夹具向量) 走 b 的元方法。
  math.Vector3 = function(x, y, z)
    return vec3.with_add(x, y, z)
  end
end

function TestBuildingEffects:tearDown()
  math.Vector3 = _saved_vector3
  prefab.group["一级建筑"] = _saved_ref_key
end

function TestBuildingEffects:test_clear_building_units_destroys_existing_group_and_resets_text()
  -- L24 `type(groups) == "table" and groups[i]` 的 and->or(残留组必销毁)
  -- 与 destroy 调用/组表清空/文本复位/return true 各链:清除必须落
  -- destroy(handle, true)、组槽置空、billboard 复位为空白。
  local scene = _scene()
  scene.building_unit_groups[1] = "old_unit"
  local result = building_effects.clear_building_units(scene, 1, _deps())
  _assert_eq(#_captured.destroy, 1, "existing group must be destroyed")
  _assert_eq(_captured.destroy[1].handle, "old_unit", "destroy must target the stored handle")
  _assert_eq(_captured.destroy[1].destroy_children, true, "destroy must clear children")
  _assert_eq(scene.building_unit_groups[1], nil, "group slot must be cleared")
  _assert_eq(_captured.txt[1], "  ", "billboard text must be reset to blank")
  _assert_eq(result, true, "clear must report success")
end

function TestBuildingEffects:test_clear_building_units_skips_destroy_when_no_group()
  -- L24 `and` -> `or`(groups 表恒真):组槽缺失时不得误销毁;文本复位
  -- 仍然要执行。
  local scene = _scene()
  local result = building_effects.clear_building_units(scene, 1, _deps())
  _assert_eq(#_captured.destroy, 0, "missing group must not destroy")
  _assert_eq(_captured.txt[1], "  ", "billboard reset must still run")
  _assert_eq(result, true, "clear must still report success")
end

function TestBuildingEffects:test_clear_building_units_tolerates_missing_groups_table()
  -- 组表整体缺失时不得撞 nil 索引,文本复位与返回 true 照常。
  local scene = _scene()
  scene.building_unit_groups = nil
  local result = building_effects.clear_building_units(scene, 1, _deps())
  _assert_eq(#_captured.destroy, 0, "nil groups table must not destroy")
  _assert_eq(_captured.txt[1], "  ", "billboard reset must still run")
  _assert_eq(result, true, "clear must still report success")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_creates_group_records_and_applies_text()
  -- 生成链主契约:clear 旧组 -> create_unit_group(真实 prefab id, pos+offset,
  -- 传入四元数) -> 组槽记录新句柄 -> billboard 写等级文案 -> 返回 true。
  -- 顺带击杀 L62 clear 调用换 nil(旧组不销毁)与 L66 get_position 换 nil
  -- (pos 为 nil 时 pos+offset 撞错)。
  local scene = _scene()
  scene.building_unit_groups[1] = "old_unit"
  local deps = _deps()
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 1, deps)
  _assert_eq(result, true, "upgrade spawn must succeed")
  _assert_eq(#_captured.destroy, 1, "stale group must be cleared first")
  _assert_eq(_captured.destroy[1].handle, "old_unit", "stale handle must be destroyed")
  _assert_eq(#_captured.create, 1, "unit group must be created")
  local created = _captured.create[1]
  _assert_eq(created.group_id, prefab.group["一级建筑"], "prefab group id must be used")
  _assert_eq(created.quaternion, "root_q", "root quaternion must pass through")
  _assert_eq(created.pos.x, 0.0, "spawn position x")
  _assert_eq(created.pos.y, 1.5, "spawn position must carry the level offset")
  _assert_eq(scene.building_unit_groups[1], "new_unit", "group slot must record the new handle")
  -- 生成链先经 clear 复位(txt[1] = "  "),等级文案是最后一次写入。
  _assert_eq(_captured.txt[#_captured.txt], "一级建筑", "billboard must show the level ref key")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_returns_false_when_create_fails()
  -- L94 `unit == nil` 的 == -> ~=:create_unit_group 返回 nil 时生成必须
  -- 报失败,不得误记录。
  local scene = _scene()
  local deps = {
    host_runtime = {
      create_unit_group = function()
        return nil
      end,
    },
  }
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 1, deps)
  _assert_eq(result, false, "failed create must report failure")
  _assert_eq(scene.building_unit_groups[1], nil, "failed create must not record a group")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_returns_false_without_building()
  -- L63 `buildings[i] == nil` 的 == -> ~=(变异体对 nil 建筑继续索引撞错):
  -- 建筑缺失时生成必须早退 false,不落任何创建。
  local scene = _scene()
  scene.buildings = {}
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 1, _deps())
  _assert_eq(result, false, "missing building must report failure")
  _assert_eq(#_captured.create, 0, "missing building must not create")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_returns_false_without_prefab_group()
  -- L68 prefab.group[ref_key] 换 nil 与 L69 `group_id == nil` 的 == -> ~=:
  -- prefab 缺键时生成必须早退 false。
  local scene = _scene()
  prefab.group["一级建筑"] = nil
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 1, _deps())
  _assert_eq(result, false, "missing prefab group must report failure")
  _assert_eq(#_captured.create, 0, "missing prefab group must not create")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_uses_level_two_ref_key()
  -- L40 `[2] = "二级建筑"` 换 nil:二级生成必须用真实的二级 prefab 键。
  local scene = _scene()
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 2, _deps())
  _assert_eq(result, true, "level two spawn must succeed")
  _assert_eq(_captured.create[1].group_id, prefab.group["二级建筑"], "level two ref key must be used")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_uses_level_three_ref_key()
  -- L41 `[3] = "三级建筑"` 换 nil:三级生成必须用真实的三级 prefab 键。
  local scene = _scene()
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 3, _deps())
  _assert_eq(result, true, "level three spawn must succeed")
  _assert_eq(_captured.create[1].group_id, prefab.group["三级建筑"], "level three ref key must be used")
end

function TestBuildingEffects:test_spawn_upgrade_building_units_returns_false_for_unknown_level()
  -- L45 `coords == nil` 的 == -> ~= 与 L74 `return nil` -> return offset:
  -- 未知等级无偏移时生成必须早退 false。
  local scene = _scene()
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 4, _deps())
  _assert_eq(result, false, "unknown level must report failure")
  _assert_eq(#_captured.create, 0, "unknown level must not create")
end

function TestBuildingEffects:test_apply_text_skips_when_text_object_lacks_method()
  -- L82 `txt and txt.set_billboard_text` 的 and -> or(变异体对无方法的
  -- 文本对象撞 nil 调用):文本对象缺 set_billboard_text 时须跳过不落文案。
  local scene = _scene()
  scene.building_txt[1] = {}
  local result = building_effects.spawn_upgrade_building_units(scene, "root_q", 1, 1, _deps())
  _assert_eq(result, true, "spawn must still succeed without a text method")
  _assert_eq(#_captured.txt, 0, "text object without method must not be called")
end

return TestBuildingEffects
