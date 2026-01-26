local Modal = {}

function Modal.new()
  local m = {
    queue = {},
    active = nil,
  }
  return setmetatable(m, { __index = Modal })
end

local function activate(modal)
  if not modal.active and #modal.queue > 0 then
    modal.active = table.remove(modal.queue, 1)
  end
end

function Modal:push(entry)
  table.insert(self.queue, entry)
  activate(self)
end

function Modal:update()
  if not self.active then
    activate(self)
  end
end

function Modal:dismiss()
  if self.active and self.active.on_close then
    self.active.on_close()
  end
  self.active = nil
  activate(self)
end

local function button_rect(w, h)
  local btn_w = 120
  local btn_h = 38
  local btn_x = (w - btn_w) * 0.5
  local btn_y = h * 0.58
  return { x = btn_x, y = btn_y, w = btn_w, h = btn_h, r = 8 }
end

function Modal:mousepressed(x, y)
  if not self.active then
    return false
  end
  local w, h = love.graphics.getDimensions()
  local btn = button_rect(w, h)
  if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
    if self.active.on_confirm then
      self.active.on_confirm()
    end
    self:dismiss()
  end
  return true
end

function Modal:keypressed(key)
  if not self.active then
    return false
  end
  if key == "space" or key == "return" or key == "escape" then
    if self.active.on_confirm and (key == "space" or key == "return") then
      self.active.on_confirm()
    end
    self:dismiss()
    return true
  end
  return false
end

function Modal:draw(ui)
  if not self.active then
    return
  end
  local w, h = love.graphics.getDimensions()
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local box_w = math.min(460, w * 0.6)
  local box_h = 220
  local box_x = (w - box_w) * 0.5
  local box_y = (h - box_h) * 0.35

  love.graphics.setColor(ui.palette.panel)
  love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 12, 12)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 12, 12)

  love.graphics.setColor(ui.palette.text)
  love.graphics.setFont(ui.fonts.title)
  love.graphics.printf(self.active.title or "提示", box_x + 18, box_y + 16, box_w - 36, "left")

  love.graphics.setFont(ui.fonts.body)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf(self.active.body or "", box_x + 18, box_y + 64, box_w - 36, "left")

  if self.active.buttons then
    local btn_y = box_y + box_h - 64
    local total = #self.active.buttons
    for i, b in ipairs(self.active.buttons) do
      local bw = 120
      local bh = 36
      local gap = 16
      local start_x = box_x + (box_w - (bw * total + gap * (total - 1))) * 0.5
      local bx = start_x + (i - 1) * (bw + gap)
      local by = btn_y
      love.graphics.setColor(0.3, 0.5, 0.35)
      love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
      love.graphics.setColor(ui.palette.panel_border)
      love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
      love.graphics.setColor(ui.palette.text)
      love.graphics.setFont(ui.fonts.small)
      love.graphics.printf(b.label, bx, by + 8, bw, "center")
      b._rect = { x = bx, y = by, w = bw, h = bh }
    end
  end

  local btn = button_rect(w, h)
  love.graphics.setColor(0.3, 0.5, 0.35)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, btn.r, btn.r)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, btn.r, btn.r)
  love.graphics.setColor(ui.palette.text)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.printf(self.active.button_text or "知道了", btn.x, btn.y + 10, btn.w, "center")
end


function Modal:click_buttons(x, y)
  if not self.active or not self.active.buttons then
    return false
  end
  for _, b in ipairs(self.active.buttons) do
    local r = b._rect
    if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
      if b.on_click then
        b.on_click()
      end
      self:dismiss()
      return true
    end
  end
  return false
end


function Modal:confirm()
  if not self.active then
    return false
  end
  if self.active.on_confirm then
    self.active.on_confirm()
  end
  self:dismiss()
  return true
end


function Modal:press_button(index)
  if not self.active or not self.active.buttons then
    return false
  end
  local target = self.active.buttons[index or 1] or self.active.buttons[1]
  if not target then
    return false
  end
  if target.on_click then
    target.on_click()
  end
  self:dismiss()
  return true
end

return Modal