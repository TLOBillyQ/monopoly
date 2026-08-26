-- 可选槽位签名的规范派生直测(#594)。这个派生是「集合是否变了」的唯一口径,
-- 重放记忆(ui.state)与阶段推进重置(ui.coord)都按它比对,故单独钉住。
local support = require("test.support.shared_support")
local pickable_signature = require("src.ui.state.item_slot_pickable_signature")

local _assert_eq = support.assert_eq

TestItemSlotPickableSignature = {}

function TestItemSlotPickableSignature:test_signature_joins_pickable_indices_with_comma()
  -- kills table.concat 分隔符 "," -> nil:多槽位签名会从 "1,2" 塌成 "12"。
  _assert_eq(pickable_signature.of({ true, true, false }), "1,2",
    "multiple pickable slots join with a comma")
  _assert_eq(pickable_signature.of({ false, true, false }), "2",
    "a single pickable slot yields its bare index")
  _assert_eq(pickable_signature.of({ false, false }), "",
    "no pickable slots yield an empty signature")
end

function TestItemSlotPickableSignature:test_signature_keeps_ascending_slot_order()
  -- 签名是集合的规范形式:同一集合必须只有一种字符串,否则两侧比对会假变化。
  _assert_eq(pickable_signature.of({ false, true, false, true }), "2,4",
    "pickable indices stay in ascending slot order")
end

function TestItemSlotPickableSignature:test_signature_is_free_of_cross_call_residue()
  -- 曾经的实现复用一张池化表;长集合后紧跟短集合会拖出残留尾巴。
  _assert_eq(pickable_signature.of({ true, true, true }), "1,2,3",
    "a long pickable set signs every index")
  _assert_eq(pickable_signature.of({ true }), "1",
    "a following short set must not inherit the previous tail")
end

return TestItemSlotPickableSignature
