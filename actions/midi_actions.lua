-- midi_actions.lua
local r = reaper
local M = {}

function M.onMIDINotes(ctx)
  -- Example: quantize selected notes to grid
  local ed = ctx.hwnd or r.MIDIEditor_GetActive()
  if not ed then return end
  r.MIDIEditor_OnCommand(ed, 40659) -- Quantize notes
end

function M.onMIDICCLane(ctx)
  -- Example: smooth CCs
  local ed = ctx.hwnd or r.MIDIEditor_GetActive()
  if not ed then return end
  r.MIDIEditor_OnCommand(ed, 40037) -- Edit: Reduce CC events (placeholder)
end

function M.onMIDIEditor(ctx)
  -- Fallback for other MIDI editor areas
  local ed = ctx.hwnd or r.MIDIEditor_GetActive()
  if not ed then return end
  r.MIDIEditor_OnCommand(ed, 40435) -- Select all notes
end

return M
