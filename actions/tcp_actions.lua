-- arrange_actions.lua
local r = reaper
local M = {}

function M.onTrack(ctx)
  -- Example: select track under mouse
  if ctx.track then
    r.SetOnlyTrackSelected(ctx.track)
  end
end

function M.onTcpSelector(ctx, click, val)
  -- Example: select track under mouse
  if click then
        r.Main_OnCommand(40113, 1) -- Prev track
    return
  end
    if val>0 then
        r.Main_OnCommand(40285, val) --Next track 
    end
    if val<0 then
        r.Main_OnCommand(40286, val) -- Prev track
    end
  --id = reaper.NamedCommandLookup("_SWS_VZOOMFIT")
  --r.Main_OnCommand(id, val) -- Envelope: Set shape: linear
end

function M.onTcpRotary(ctx, val, idx)
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

function M.onTcpPad(ctx, idx)
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

function M.onTcpSlider(ctx, val, idx)
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

        r.Main_OnCommand(40297, 0) -- Envelope: Insert point at current position
        local id = reaper.NamedCommandLookup("_BR_SEL_TCP_TRACK_MOUSE")
        r.Main_OnCommand(id, val) -- Envelope: Set shape: linear
        id = reaper.NamedCommandLookup("_SWS_VZOOMFIT")
        r.Main_OnCommand(id, val) -- Envelope: Set shape: linear
        --r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
end

return M
