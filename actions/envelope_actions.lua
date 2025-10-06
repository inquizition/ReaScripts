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

function M.onEnvelopeSelector(ctx, click, val)
  -- Example: select track under mouse
  if click then
    r.SetOnlyTrackSelected(ctx.track)
    return
  end
  
  r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
end

function M.onEnvelopeRotary(ctx, val, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 2 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 3 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 4 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 5 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 6 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 7 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 8 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
end

function M.onEnvelopePad(ctx, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        r.SetOnlyTrackSelected(ctx.track)    
    end
    if idx == 2 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 3 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 4 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 5 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 6 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 7 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 8 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
end

function M.onEnvelopeSlider(ctx, val, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 2 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 3 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 4 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
end

return M
