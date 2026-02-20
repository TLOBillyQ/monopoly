local ring_map = require("Config.Maps.RingMapBuilder")

return ring_map.build({
  tile_ids = { 35, 1, 38, 36, 40, 44, 39, 2 },
  start_id = 35,
  market_id = 39,
})
