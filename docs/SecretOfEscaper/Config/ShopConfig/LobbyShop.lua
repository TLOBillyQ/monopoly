require 'Manager.ShopManager.__init'
local Status = ShopManager.Status

---@type Config.LobbyShop[]
local LobbyShop = {
    {
        type = "item_config",
        code = "flash_light",
        buy_price = 4500,
        status = Status.NORMAL
    },
    {
        type = "item_config",
        code = "machete",
        buy_price = 8000,
        status = Status.COMING_ON_SOON
    },
    {
        type = "item_config",
        code = "fish_spear",
        buy_price = 8000,
        status = Status.COMING_ON_SOON
    },
    {
        type = "item_config",
        code = "shotgun",
        buy_price = 8000,
        status = Status.NORMAL
    },
    {
        type = "item_config",
        code = "medical_box",
        buy_price = 8000,
        status = Status.COMING_ON_SOON
    },
    {
        type = "item_config",
        code = "camera",
        buy_price = 8000,
        status = Status.COMING_ON_SOON
    },
    {
        type = "item_config",
        code = "shovel",
        buy_price = 8000,
        status = Status.NORMAL
    },
    {
        type = "item_config",
        code = "steel_gloves",
        buy_price = 8000,
        status = Status.COMING_ON_SOON
    }
}

return LobbyShop