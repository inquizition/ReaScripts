-- envelope_actions.lua
local r = reaper
local M = {}

function M.onEnvelopePoint(ctx)
  -- Example: set point shape to linear
  if ctx.env then
    r.Main_OnCommand(40548, 0) -- Envelope: Set shape: linear
  end
end

function M.onEnvelope(ctx)
  -- Example: insert point at edit cursor
  r.Main_OnCommand(40332, 0) -- Envelope: Insert point at current position
end

return M
