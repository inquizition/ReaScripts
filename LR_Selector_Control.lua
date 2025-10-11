-- ContextRouter.lua
-- Routes to imported functions based on mouse/cursor context.

local r = reaper

-- ---------- Config ----------
local base = r.GetResourcePath() .. "\\Scripts\\ReaScripts\\actions"  -- change if you want
local modules = {
  arrange   = base .. "/arrange_actions.lua",
  midi      = base .. "/midi_actions.lua",
  envelope  = base .. "/envelope_actions.lua",
  fallback  = base .. "/fallback_actions.lua",
  tcp       = base .. "/tcp_actions.lua",
  focus_handler = base .. "/focus_handler.lua",
}

-- ---------- Utils ----------
local function import(path)
  local chunk, err = loadfile(path)
  if not chunk then
    r.ShowMessageBox("Load error:\n" .. tostring(err), "ContextRouter", 0)
    return {}
  end
  local ok, mod = pcall(chunk)
  if not ok then
    r.ShowMessageBox("Runtime error:\n" .. tostring(mod), "ContextRouter", 0)
    return {}
  end
  if type(mod) ~= "table" then
    -- allow modules that set globals; return _G so caller can still index
    return _G
  end
  return mod
end

local function sws_ok()
  return r.BR_GetMouseCursorContext ~= nil
end

local function valid_env(env)  return env and r.ValidatePtr2(0, env,  "TrackEnvelope*") end
local function valid_tr(tr)    return tr  and r.ValidatePtr2(0, tr,   "MediaTrack*") end
local function valid_item(it)  return it  and r.ValidatePtr2(0, it,   "MediaItem*") end
local function valid_take(tk)  return tk  and r.ValidatePtr2(0, tk,   "MediaItem_Take*") end

-- Gather rich context using SWS if available
local function get_ctx()
  local ctx = {
    window = "", segment = "", details = "",
    item = nil, take = nil, env = nil, env_pt = nil, track = nil,
    track_sel = r.GetSelectedTrack(0, 0),          -- ✅ pass args
    env_sel   = r.GetSelectedEnvelope(0),
    hwnd = nil,
  }
  --local ctx = {
  --  window   = nil,
  --  segment  = nil,
  --  details  = nil,
  --  hwnd     = nil,
  --  item     = nil,
  --  take     = nil,
  --  env      = nil,
  --  env_pt   = nil,
  --  env_sel  = nil,
  --  track    = nil,
  --  track_sel = nil,
  --  midi_ed  = nil,
  --}

  if sws_ok() then
    local w, s, d = r.BR_GetMouseCursorContext()
    ctx.window  = w or ""
    ctx.segment = s or ""
    ctx.details = d or ""
    ctx.item    = r.BR_GetMouseCursorContext_Item()
    ctx.take    = r.BR_GetMouseCursorContext_Take()
    ctx.env, ctx.env_pt = r.BR_GetMouseCursorContext_Envelope()
    ctx.track   = r.BR_GetMouseCursorContext_Track()
    -- ctx.hwnd = r.BR_GetMouseCursorContext_MIDIEditor() -- may be nil
  else
    -- Fallback: crude domain detection if SWS is missing
    ctx.hwnd = r.MIDIEditor_GetActive()
    if ctx.hwnd then
      ctx.window = "midi_editor"
    else
      ctx.window = "arrange"
    end
  end

  -- Convenience flags
  ctx.is_midi     = (ctx.window == "midi_editor") or (ctx.take and r.TakeIsMIDI(ctx.take))
  ctx.is_arrange  = (ctx.window == "arrange")
  ctx.has_item    = (ctx.item ~= nil)
  ctx.on_env      = (ctx.segment == "envelope" or ctx.env ~= nil)
  ctx.on_track    = (ctx.segment == "track" and not ctx.has_item and not ctx.on_env)
  ctx.on_env_sel  = (ctx.env_sel ~= nil)
  ctx.on_track_sel= (ctx.track_sel ~= nil)
  ctx.on_tcp      = (ctx.window == "tcp")

  return ctx
end

-- ---------- Dispatch ----------
local function dispatch()

  -- Returns contextual information about the script, typically MIDI/OSC input values.
  -- val will be set to a relative or absolute value depending on mode (=0: absolute mode, >0: relative modes).
  -- resolution=127 for 7-bit resolution, =16383 for 14-bit resolution.
  -- sectionID, and cmdID will be set to -1 if the script is not part of the action list.
  -- mode, resolution and val will be set to -1 if the script was not triggered via MIDI/OSC.
  -- contextstr may be empty or one of:
  
  
  --     midi:XX[:YY] (one or two bytes hex)
  --     [wheel|hwheel|mtvert|mthorz|mtzoom|mtrot|mediakbd]:flags
  --     key:flags:keycode
  --     osc:/msg[:f=FloatValue|:s=StringValue]
  --     KBD_OnMainActionEx
  
  -- (flags may include V=virtkey, S=shift, A=alt/option, C=control/command, W=win/control)
  is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
  local ctx = get_ctx()

    -- Debug print
  reaper.ShowConsoleMsg(string.format(
    "Window: %s\nSegment: %s\nDetails: %s\nItem: %s\nTrack: %s\nEnvelope: %s\nTrack Selected: %s\nEnvelope Selected: %s\n\n",
    tostring(ctx.window),
    tostring(ctx.segment),
    tostring(ctx.details),
    ctx.item and "yes" or "no",
    ctx.track and "yes" or "no",
    ctx.env and "yes" or "no",
    ctx.track_sel and "yes" or "no",
    ctx.env_sel and "yes" or "no"
  ))
  reaper.ShowConsoleMsg(string.format("Knob val: %s\n", tostring(val)))

  local A  = import(modules.arrange)
  local B  = import(modules.tcp)
  local M  = import(modules.midi)
  local E  = import(modules.envelope)
  local FB = import(modules.fallback)
  local FH = import(modules.focus_handler)

  local zoom_id = reaper.NamedCommandLookup("_SWS_TOGZOOMTTHIDE")
  local focused = reaper.GetToggleCommandState(zoom_id)

  if focused == 1 then
    reaper.ShowConsoleMsg(string.format("Focused track!\n"))
    FH.moveOnFocused(ctx, val)
    return
  end

  if val>0 then
      r.Main_OnCommand(40285, val) --Next track 
  end
  if val<0 then
      r.Main_OnCommand(40286, val) -- Prev track
  end
 
  if FB.fallback then
    return FB.fallback(ctx)
  end
end

r.Undo_BeginBlock()
dispatch()
r.Undo_EndBlock("ContextRouter", -1)
