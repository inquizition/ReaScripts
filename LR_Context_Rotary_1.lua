-- ContextRouter.lua
-- Routes to imported functions based on mouse/cursor context.

local r = reaper

-- ---------- Config ----------
local base = r.GetResourcePath() .. "/actions"  -- change if you want
local modules = {
  arrange   = base .. "/arrange_actions.lua",
  midi      = base .. "/midi_actions.lua",
  envelope  = base .. "/envelope_actions.lua",
  fallback  = base .. "/fallback_actions.lua",
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

-- Gather rich context using SWS if available
local function get_ctx()
  local ctx = {
    window   = nil,
    segment  = nil,
    details  = nil,
    hwnd     = nil,
    item     = nil,
    take     = nil,
    env      = nil,
    env_pt   = nil,
    track    = nil,
    midi_ed  = nil,
  }

  if sws_ok() then
    ctx.window, ctx.segment, ctx.details = r.BR_GetMouseCursorContext()
    ctx.item   = r.BR_GetMouseCursorContext_Item()
    ctx.take   = r.BR_GetMouseCursorContext_Take()
    ctx.env, ctx.env_pt = r.BR_GetMouseCursorContext_Envelope()
    ctx.track  = r.BR_GetMouseCursorContext_Track()
    ctx.hwnd   = r.BR_GetMouseCursorContext_MIDIEditor() -- nil if not in MIDI editor
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

  return ctx
end

-- ---------- Dispatch ----------
local function dispatch()
  local ctx = get_ctx()

  local A  = import(modules.arrange)
  local M  = import(modules.midi)
  local E  = import(modules.envelope)
  local FB = import(modules.fallback)

  -- Priority: MIDI editor > Envelope > Item > Track > Fallback
  if ctx.is_midi then
    -- More granular MIDI routing using SWS details if present
    local d = ctx.details or ""
    if d:find("cc_lane") and M.onMIDICCLane then return M.onMIDICCLane(ctx) end
    if d:find("notes")   and M.onMIDINotes then   return M.onMIDINotes(ctx)   end
    if M.onMIDIEditor then return M.onMIDIEditor(ctx) end
    if FB.fallback then return FB.fallback(ctx) end
    return
  end

  if ctx.on_env then
    if E.onEnvelopePoint and ctx.env_pt then return E.onEnvelopePoint(ctx) end
    if E.onEnvelope and ctx.env then return E.onEnvelope(ctx) end
    if FB.fallback then return FB.fallback(ctx) end
    return
  end

  if ctx.has_item and A.onItem then
    return A.onItem(ctx)
  end

  if ctx.on_track and A.onTrack then
    return A.onTrack(ctx)
  end

  if A.onArrange and ctx.is_arrange then
    return A.onArrange(ctx)
  end

  if FB.fallback then
    return FB.fallback(ctx)
  end
end

r.Undo_BeginBlock()
dispatch()
r.Undo_EndBlock("ContextRouter", -1)
