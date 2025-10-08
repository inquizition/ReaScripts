-- arrange_actions.lua
local r = reaper
local M = {}

function M.onItem(ctx)
  -- Example: toggle item mute
  if ctx.item then
    local m = r.GetMediaItemInfo_Value(ctx.item, "B_MUTE")
    r.SetMediaItemInfo_Value(ctx.item, "B_MUTE", (m == 1) and 0 or 1)
    r.UpdateArrange()
  end
end

function M.onTrack(ctx)
  -- Example: select track under mouse
  if ctx.track then
    r.SetOnlyTrackSelected(ctx.track)
  end
end

function M.onArrange(ctx)
  -- Example: nudge edit cursor by grid
  r.Main_OnCommand(40647, 0) -- Item: Nudge right by grid (as a placeholder action)
end

function M.onArrangeSelector(ctx, click, val)
  -- Example: select track under mouse
  if click then
        r.Main_OnCommand(40528, 1) -- Item: Nudge right by grid (as a placeholder action)
        r.Main_OnCommand(41173, 1) -- Item: Nudge right by grid (as a placeholder action)
        id = reaper.NamedCommandLookup("_SWS_TOGZOOMIONLYHIDE")
        r.Main_OnCommand(id, val) -- Envelope: Set shape: linear
    return
  end
  
    if val > 0 then
        r.Main_OnCommand(40375, 1) -- Item: Move to next transient
    end
    if val < 0 then
        r.Main_OnCommand(40376, 1) -- Item: Move to previous transient
    end
end

function M.onArrangeRotary(ctx, val, idx)
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

function M.onArrangePad(ctx, idx)
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

function M.onArrangeSlider(ctx, val, idx)
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
