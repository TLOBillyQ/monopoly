require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- 可选槽位签名的规范派生直测(#594)。这个派生是「集合是否变了」的唯一口径,
-- 重放记忆(ui.state)与阶段推进重置(ui.coord)都按它比对,故单独钉住。
require("test.support.shared_support")
local pickable_signature = require("src.ui.state.item_slot_pickable_signature")

local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
describe("TestItemSlotPickableSignature", function()
it("test_signature_joins_pickable_indices_with_comma", function()
  -- kills table.concat 分隔符 "," -> nil:多槽位签名会从 "1,2" 塌成 "12"。
  _assert_eq(pickable_signature.of({ true, true, false }), "1,2",
    "multiple pickable slots join with a comma")
  _assert_eq(pickable_signature.of({ false, true, false }), "2",
    "a single pickable slot yields its bare index")
  _assert_eq(pickable_signature.of({ false, false }), "",
    "no pickable slots yield an empty signature")
end)

it("test_signature_keeps_ascending_slot_order", function()
  -- 签名是集合的规范形式:同一集合必须只有一种字符串,否则两侧比对会假变化。
  _assert_eq(pickable_signature.of({ false, true, false, true }), "2,4",
    "pickable indices stay in ascending slot order")
end)

it("test_signature_is_free_of_cross_call_residue", function()
  -- 曾经的实现复用一张池化表;长集合后紧跟短集合会拖出残留尾巴。
  _assert_eq(pickable_signature.of({ true, true, true }), "1,2,3",
    "a long pickable set signs every index")
  _assert_eq(pickable_signature.of({ true }), "1",
    "a following short set must not inherit the previous tail")
end)

end)
