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
  local zoom_id = reaper.NamedCommandLookup("_SWS_TOGZOOMTTHIDE")
  local zoomed = reaper.GetToggleCommandState(zoom_id)
  if click then
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

-- Compute [min_time, max_time] of items on the selected track
local function track_items_bounds(tr)
  local n = r.CountTrackMediaItems(tr)
  if n == 0 then return nil end
  local tmin, tmax = math.huge, -math.huge
  for i = 0, n-1 do
    local it  = r.GetTrackMediaItem(tr, i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    tmin = math.min(tmin, pos)
    tmax = math.max(tmax, pos + len)
  end
  if tmax < tmin then return nil end
  return tmin, tmax
end

-- val: 0..127  | curve: 0.5..2 (feel), default 1.0
function ZoomBetweenTightAndFitTrack(val, curve)
  local tr = r.GetSelectedTrack(0,0); if not tr then return end
  local tmin, tmax = track_items_bounds(tr); if not tmin then return end

  -- Ensure the selected track is vertically visible
  r.Main_OnCommand(40913, 0) -- Track: vertical scroll selected into view

  local span = math.max(tmax - tmin, 0.010)    -- guard against zero-length
  local t = math.max(0, math.min(val or 0, 127)) / 127.0
  curve = curve or 1.0

  -- Zoom width interpolation (log/exponential for good feel)
  -- min_w: "very zoomed in" (~0.05% of span, but not <1ms)
  local min_w = math.max(span / 2000.0, 0.001)
  local max_w = span                                -- fit exactly all items
  local width = min_w * ((max_w/min_w) ^ (t ^ curve))

  -- Keep view centered on the items' center while changing width
  local center = 0.5 * (tmin + tmax)
  local left   = math.max(0, center - 0.5 * width)
  local right  = left + width

  r.PreventUIRefresh(1)
  r.GetSet_ArrangeView2(0, true, 0, 0, left, right)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
end

function M.onArrangeSlider(ctx, val, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        ZoomBetweenTightAndFitTrack(val)
    end
    if idx == 2 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 3 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 4 then
        ZoomBetweenTightAndFitTrack(val)
    end
end

return M
