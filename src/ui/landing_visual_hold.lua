local effect_track = require("src.ui.render.support.effect_track")
local impl = require("src.state.landing_visual_hold")
impl.set_post_release_hook(function() effect_track.await_all() end)
return impl
