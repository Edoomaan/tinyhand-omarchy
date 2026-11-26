-- PROTOTYPE: nested Hyprland used only for the overlay spike.
hl.monitor({ output = "", mode = "1280x800", position = "0x0", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true }, animations = { enabled = false } })

-- Gated binds while edooman-tinyhand-pointer overlay is open
local tinyhand_layers = 0
local tinyhand_binds = {}
local function tinyhand_bind_alive(keybind)
  return keybind ~= nil and tostring(keybind) ~= "HL.Keybind(expired)"
end

hl.on("layer.opened", function(layer)
  if layer.namespace == "edooman-tinyhand-pointer" then
    tinyhand_layers = tinyhand_layers + 1
    if tinyhand_layers == 1 then
      if not tinyhand_bind_alive(tinyhand_binds["alt_up"]) then
        tinyhand_binds["alt_up"] = hl.bind("Alt_L", hl.dsp.exec_cmd("omarchy-shell shell call edooman-tinyhand interactUp ''"), { release = true, transparent = true, ignore_mods = true, non_consuming = true })
      end
      if not tinyhand_bind_alive(tinyhand_binds["shift_down"]) then
        tinyhand_binds["shift_down"] = hl.bind("Shift_L", hl.dsp.exec_cmd("omarchy-shell shell call edooman-tinyhand shiftDown ''"), { transparent = true, ignore_mods = true, non_consuming = true })
      end
      if not tinyhand_bind_alive(tinyhand_binds["shift_up"]) then
        tinyhand_binds["shift_up"] = hl.bind("Shift_L", hl.dsp.exec_cmd("omarchy-shell shell call edooman-tinyhand shiftUp ''"), { release = true, transparent = true, ignore_mods = true, non_consuming = true })
      end
      for _, b in pairs(tinyhand_binds) do
        if tinyhand_bind_alive(b) then b:set_enabled(true) end
      end
    end
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace == "edooman-tinyhand-pointer" and tinyhand_layers > 0 then
    tinyhand_layers = tinyhand_layers - 1
    if tinyhand_layers == 0 then
      for _, b in pairs(tinyhand_binds) do
        if tinyhand_bind_alive(b) then b:set_enabled(false) end
      end
    end
  end
end)
