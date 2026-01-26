local UIState = require("src.adapters.love2d.ui_state")
local Layout = require("src.adapters.love2d.layout")
local BoardRenderer = require("src.adapters.love2d.board_renderer")
local PanelRenderer = require("src.adapters.love2d.panel_renderer")
local Presenter = require("src.adapters.core.presenter")
local AdapterLayer = require("src.adapters.core.adapter_layer")
local logger = require("src.util.logger")

local LoveRuntime = {}

function LoveRuntime.install(LoveLayer)
  function LoveLayer:layout()
    local store_state = self.game.store.state
    local winner_name = self.game.winner_names
    if not winner_name and self.game.winner then
      winner_name = self.game.winner.name
    end
    local view = Presenter.present(store_state, {
      game = self.game,
      last_turn = self.game.last_turn,
      finished = self.game.finished,
      winner_name = winner_name,
    })
    Layout.apply(self.ui, view)
  end

  function LoveLayer:is_inside(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
  end

  function LoveLayer:update_hover_tile(mx, my)
    self.ui.hover_tile = nil
    if not self.game then
      return
    end
    local half_cell = (self.ui.board.cell_size or self.ui.tile_radius * 2) * 0.5
    for idx, pos in ipairs(self.ui.board.positions) do
      local dx = mx - pos.x
      local dy = my - pos.y
      if math.abs(dx) <= half_cell and math.abs(dy) <= half_cell then
        self.ui.hover_tile = idx
        return
      end
    end
  end

  function LoveLayer:load()
    love.window.setMode(1600, 960, { resizable = true, minwidth = 1200, minheight = 800 })
    love.window.setTitle("蛋仔大富翁 (Love2D)")
    UIState.build_fonts(self.ui)
    self:build_item_index()
    self:set_game(self:new_game())
    self:layout()
  end

  function LoveLayer:resize()
    self:layout()
  end

  function LoveLayer:update(dt)
    if not self.game then
      return
    end
    local mx, my = love.mouse.getPosition()
    self:update_hover_tile(mx, my)

    AdapterLayer.step_auto_runner(self, dt, {
      modal_active = self.modal.active ~= nil,
      modal_buttons = self.modal.active and self.modal.active.buttons,
      game_finished = self.game and self.game.finished,
    })

    AdapterLayer.step_choice_timeout(self, dt, {
      is_choice_active = function(layer)
        return layer.pending_choice and layer.modal.active
      end,
      on_pending_choice = function(layer, pending)
        if not layer.modal.active then
          layer:open_choice_modal(pending)
        end
      end,
      build_action = function(_, choice)
        local first = choice.options and choice.options[1]
        if first then
          return { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
        end
        if choice.allow_cancel ~= false then
          return { type = "choice_cancel", choice_id = choice.id }
        end
        return nil
      end,
    })

    AdapterLayer.step_modal_timeout(self, dt, {
      is_active = function(layer)
        local active = layer.modal and layer.modal.active
        return active and not active._pending_choice_id
      end,
      get_ref = function(layer)
        local active = layer.modal and layer.modal.active
        return active and (active._pending_choice_id or active._popup_seq or active.title or active.body or active)
      end,
      on_timeout = function(layer)
        if layer.modal and layer.modal.active then
          layer.modal:confirm()
        end
      end,
    })

    self:step_move_anim(dt)

    self.modal:update()
  end

  function LoveLayer:mousepressed(x, y, button)
    if button ~= 1 then
      return
    end
    if self.modal:click_buttons(x, y) or self.modal:mousepressed(x, y) then
      return
    end
    for _, btn in ipairs(self.ui.buttons) do
      if self:is_inside(x, y, btn) then
        self:handle_ui_button(btn.id)
        return
      end
    end

    if self.ui.hover_tile then
      self.ui.selected_tile = self.ui.hover_tile
    end
  end

  function LoveLayer:keypressed(key)
    if self.modal.active and self.modal:keypressed(key) then
      return
    end
    if key == "space" or key == "return" then
      self:step_turn()
    elseif key == "a" then
      self.ui.auto_play = not self.ui.auto_play
      self.auto_runner:set_enabled(self.ui.auto_play)
      self.auto_runner:reset_timer()
      self:_sync_auto_player(self.ui.auto_play)
    elseif key == "r" then
      self:set_game(self:new_game())
      self:layout()
    elseif key == "escape" then
      love.event.quit()
    end
  end

  function LoveLayer:draw()
    local game = self.game
    local ui = self.ui

    local store_state = game.store.state
    local winner_name = game.winner_names
    if not winner_name and game.winner then
      winner_name = game.winner.name
    end
    local view = Presenter.present(store_state, {
      game = game,
      last_turn = game.last_turn,
      finished = game.finished,
      winner_name = winner_name,
    })
    view.player_positions = self:build_move_anim_positions()

    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(ui.palette.bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.2, 0.25, 0.3, 0.2)
    love.graphics.circle("fill", ui.board.center.x - 120, ui.board.center.y - 80, ui.board.size * 0.45)
    love.graphics.setColor(0.2, 0.3, 0.25, 0.15)
    love.graphics.circle("fill", ui.board.center.x + 140, ui.board.center.y + 90, ui.board.size * 0.4)

    BoardRenderer.draw(ui, view)
    PanelRenderer.draw(ui, view, ui.buttons, self.item_name_by_id)
    self.modal:draw(ui)

    if view and view.finished then
      love.graphics.setColor(0, 0, 0, 0.45)
      love.graphics.rectangle("fill", 0, 0, w, h)
      love.graphics.setFont(ui.fonts.title)
      love.graphics.setColor(ui.palette.text)
      local winner = view.winner_name or "无人"
      love.graphics.printf("游戏结束，胜者: " .. winner, 0, h * 0.45, w, "center")
    end
  end

  local function build_move_anim_path(anim)
    local path = {}
    if anim and anim.from_index then
      path[#path + 1] = anim.from_index
    end
    if anim and anim.visited then
      for _, idx in ipairs(anim.visited) do
        path[#path + 1] = idx
      end
    end
    if anim and anim.to_index and path[#path] ~= anim.to_index then
      path[#path + 1] = anim.to_index
    end
    return path
  end

  function LoveLayer:step_move_anim(dt)
    if not (self.game and self.game.store) then
      self.move_anim_state = nil
      return
    end
    local phase = self.game.store:get({ "turn", "phase" })
    local anim = self.game.store:get({ "turn", "move_anim" })
    local seq = anim and anim.seq or nil
    if phase ~= self.move_anim_log_phase or seq ~= self.move_anim_log_seq then
      logger.info("move_anim 观察 phase=", tostring(phase), " seq=", tostring(seq))
      self.move_anim_log_phase = phase
      self.move_anim_log_seq = seq
    end
    if phase ~= "wait_move_anim" then
      self.move_anim_state = nil
      return
    end
    if not anim or not anim.seq then
      self.move_anim_state = nil
      return
    end

    local state = self.move_anim_state
    if not state or state.seq ~= anim.seq then
      state = {
        seq = anim.seq,
        elapsed = 0,
        duration = 1,
        player_id = anim.player_id,
        path = build_move_anim_path(anim),
        sent = false,
      }
      self.move_anim_state = state
    end

    state.elapsed = state.elapsed + (dt or 0)
    if state.elapsed >= state.duration and not state.sent then
      state.sent = true
      self.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
    end
  end

  function LoveLayer:build_move_anim_positions()
    local state = self.move_anim_state
    if not state or not state.player_id or not state.path or #state.path == 0 then
      return nil
    end
    local duration = state.duration or 1
    local t = 1
    if duration > 0 then
      t = math.min(state.elapsed / duration, 1)
    end
    local path = state.path
    if #path == 1 then
      local pos = self.ui.board.positions[path[1]]
      if not pos then
        return nil
      end
      return { [state.player_id] = { x = pos.x, y = pos.y } }
    end

    local segments = #path - 1
    local seg_value = t * segments
    local seg_index = math.floor(seg_value) + 1
    if seg_index > segments then
      seg_index = segments
    end
    local seg_t = seg_value - (seg_index - 1)
    local from_idx = path[seg_index]
    local to_idx = path[seg_index + 1]
    local from = from_idx and self.ui.board.positions[from_idx] or nil
    local to = to_idx and self.ui.board.positions[to_idx] or nil
    if not (from and to) then
      return nil
    end
    local x = from.x + (to.x - from.x) * seg_t
    local y = from.y + (to.y - from.y) * seg_t
    return { [state.player_id] = { x = x, y = y } }
  end

  function LoveLayer:attach()
    function love.load()
      self:load()
    end

    function love.resize()
      self:resize()
    end

    function love.update(dt)
      self:update(dt)
    end

    function love.mousepressed(x, y, button)
      self:mousepressed(x, y, button)
    end

    function love.keypressed(key)
      self:keypressed(key)
    end

    function love.draw()
      self:draw()
    end
  end

  return LoveLayer
end

return LoveRuntime
