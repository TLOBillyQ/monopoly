describe("runtime_refs (config data)", function()
  it("loads all reference tables under debug hook", function()
    package.loaded["src.config.content.runtime_ref_images"] = nil
    package.loaded["src.config.content.runtime_refs"] = nil
    local refs = require("src.config.content.runtime_refs")
    assert(type(refs) == "table", "expected table")
    assert(type(refs.images) == "table", "expected images table")
    assert(refs.images["2007"] == 1767508539, "expected action-universal item art id")
    assert(type(refs.audio) == "table", "expected audio table")
    assert(type(refs.effects) == "table", "expected effects table")
    assert(type(refs.board_feedback) == "table", "expected board_feedback table")
    assert(type(refs.skins) == "table", "expected skins table")
    assert(refs.default_creature == 1, "default creature fallback must match the base Eggy creature id")
    assert(type(refs.synthetic_ai) == "table", "expected synthetic_ai table")
  end)

  it("pins board feedback runtime references", function()
    package.loaded["src.config.content.runtime_refs"] = nil
    local refs = require("src.config.content.runtime_refs")
    local expected = {
      item_stop_highlight = {
        effect_id_ref = "item_stop_highlight",
        scale = 1.8,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
      },
      upgrade_land_smoke = {
        effect_id_ref = "upgrade_land_smoke",
        sound_id_ref = "cash_receive",
        scale = 3.0,
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
      },
      cash_burst = {
        effect_id_ref = "cash_burst",
        sound_id_ref = "cash_receive",
        scale = 1.6,
        duration = 0.6,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_cash_fx_head_offset",
        allow_missing_resource = true,
      },
      mountain_stun = {
        effect_id_ref = "mountain_stun",
        sound_id_ref = "mountain_stun",
        scale = 1.6,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
      },
      hospital_shock = {
        effect_id_ref = "hospital_shock",
        sound_id_ref = "hospital_shock",
        scale = 1.8,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
      },
      mine_blast = {
        effect_id_ref = "mine_blast",
        sound_id_ref = "mine_blast",
        scale = 2.0,
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
      },
      tax_wave = {
        effect_id_ref = "tax_wave",
        sound_id_ref = "tax_wave",
        scale = 1.6,
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
      },
      rich_deity = {
        effect_id_ref = "rich_deity",
        scale = 1.4,
        duration = 2.0,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_one",
        allow_missing_resource = true,
      },
      angel_deity = {
        effect_id_ref = "angel_deity",
        scale = 1.4,
        duration = 2.0,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_one",
        allow_missing_resource = true,
      },
      move_step_pounce = {
        sound_id_ref = "move_step_pounce",
        duration = 0.4,
        volume = 0.9,
        allow_missing_resource = true,
      },
      bankruptcy_slam = {
        effect_id_ref = "bankruptcy_slam",
        sound_id_ref = "bankruptcy_slam",
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
      },
      generic_negative = {
        sound_id_ref = "generic_negative",
        duration = 0.8,
        volume = 1.0,
        allow_missing_resource = true,
      },
      turn_started = {
        sound_id_ref = "turn_started",
        duration = 0.8,
        volume = 1.0,
        allow_missing_resource = true,
      },
    }

    for key, fields in pairs(expected) do
      local actual = assert(refs.board_feedback[key], "missing board feedback cue: " .. key)
      for field, value in pairs(fields) do
        assert(actual[field] == value,
          "board feedback " .. key .. "." .. field .. " mismatch: " .. tostring(actual[field]))
      end
    end

    local followup = refs.board_feedback.upgrade_land_smoke.followup_sounds[1]
    assert(followup.delay == 0.6, "upgrade smoke followup delay mismatch")
    assert(followup.sound_id_ref == "turn_started", "upgrade smoke followup sound mismatch")
    assert(followup.duration == 1.0, "upgrade smoke followup duration mismatch")
    assert(followup.volume == 1.0, "upgrade smoke followup volume mismatch")
  end)

  it("pins synthetic ai runtime references", function()
    package.loaded["src.config.content.runtime_refs"] = nil
    local refs = require("src.config.content.runtime_refs")
    local synthetic_ai = refs.synthetic_ai

    assert(synthetic_ai.names[1] == "红绒绒", "synthetic ai name 1 mismatch")
    assert(synthetic_ai.names[2] == "黄澄澄", "synthetic ai name 2 mismatch")
    assert(synthetic_ai.names[3] == "蓝盖盖", "synthetic ai name 3 mismatch")
    assert(synthetic_ai.names[4] == "紫圈圈", "synthetic ai name 4 mismatch")
    assert(synthetic_ai.unit_keys[1] == 9000601, "synthetic ai unit key 1 mismatch")
    assert(synthetic_ai.unit_keys[2] == 9000602, "synthetic ai unit key 2 mismatch")
    assert(synthetic_ai.unit_keys[3] == 9000603, "synthetic ai unit key 3 mismatch")
    assert(synthetic_ai.unit_keys[4] == 9000604, "synthetic ai unit key 4 mismatch")
    assert(synthetic_ai.unit_keys[5] == 9000605, "synthetic ai unit key 5 mismatch")
    assert(synthetic_ai.unit_keys[6] == 9000607, "synthetic ai unit key 6 mismatch")
  end)
end)
