local ring_map = require("Config.Maps.RingMapBuilder")

return ring_map.build({
  tile_ids = { 35, 1, 2, 3, 4, 39, 44, 40, 38 },
  start_id = 35,
  market_id = 39,
})
