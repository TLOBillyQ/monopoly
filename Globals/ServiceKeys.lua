local SERVICE_KEY = {
  movement = 1 << 0,
  market = 1 << 1,
  bankruptcy = 1 << 2,
  choice = 1 << 3,
}

SERVICE_KEY.all = SERVICE_KEY.movement | SERVICE_KEY.market | SERVICE_KEY.bankruptcy | SERVICE_KEY.choice

return SERVICE_KEY
