local UIBridge = {}
UIBridge.__index = UIBridge

local function resolve_widget(root, name)
  if not (root and name) then
    return nil
  end
  if type(root) == "table" then
    if root.widgets and root.widgets[name] then
      return root.widgets[name]
    end
    if root[name] ~= nil then
      return root[name]
    end
  end
  if root.GetWidgetFromName then
    return root:GetWidgetFromName(name)
  end
  if root.get_widget_from_name then
    return root:get_widget_from_name(name)
  end
  if root.get_widget then
    return root:get_widget(name)
  end
  return nil
end

local function set_text(node, text)
  if not node then
    return
  end
  if node.SetText then
    node:SetText(text or "")
    return
  end
  if node.set_text then
    node:set_text(text or "")
    return
  end
  if node.SetLabelText then
    node:SetLabelText(text or "")
    return
  end
  if type(node) == "table" then
    node.text = text or ""
  end
end

function UIBridge.new(root)
  return setmetatable({ root = root, nodes = {} }, UIBridge)
end

function UIBridge:get_node(name)
  if not name then
    return nil
  end
  if self.nodes[name] ~= nil then
    return self.nodes[name]
  end
  local node = resolve_widget(self.root, name)
  self.nodes[name] = node
  return node
end

function UIBridge:set_label(name, text)
  set_text(self:get_node(name), text)
end

function UIBridge:set_button(name, text)
  set_text(self:get_node(name), text)
end

function UIBridge:set_visible(name, visible)
  local node = self:get_node(name)
  if not node then
    return
  end
  local flag = visible and true or false
  if node.SetVisibility then
    if _G.ESlateVisibility and ESlateVisibility.Visible and ESlateVisibility.Collapsed then
      node:SetVisibility(flag and ESlateVisibility.Visible or ESlateVisibility.Collapsed)
    else
      node:SetVisibility(flag)
    end
    return
  end
  if node.set_visible then
    node:set_visible(flag)
    return
  end
  if type(node) == "table" then
    node.visible = flag
  end
end

function UIBridge:set_touch_enabled(name, enabled)
  local node = self:get_node(name)
  if not node then
    return
  end
  local flag = enabled and true or false
  if node.SetIsEnabled then
    node:SetIsEnabled(flag)
    return
  end
  if node.SetTouchEnabled then
    node:SetTouchEnabled(flag)
    return
  end
  if node.set_enabled then
    node:set_enabled(flag)
    return
  end
  if type(node) == "table" then
    node.enabled = flag
  end
end

return UIBridge
