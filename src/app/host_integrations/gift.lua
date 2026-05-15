local gift = {
  host_pending = true,
  skin_product_id = 5005,
  threshold = 100,
}

-- TODO_HOST_INTEGRATION: connect host gift counter and unlock callback.
function gift.is_unlocked()
  return false
end

function gift.resolve_reward()
  return {
    kind = "skin",
    product_id = gift.skin_product_id,
    threshold = gift.threshold,
    unlocked = gift.is_unlocked(),
  }
end

return gift
