ShopManager = {}

---@enum ShopManager.Status
ShopManager.Status = {
    COMING_OFF_SOON = 0,     -- 即将下架
    NORMAL = 1,              -- 正常
    COMING_ON_SOON = 2,      -- 即将上架
    OFF_SALE = 3,            -- 已下架
}
