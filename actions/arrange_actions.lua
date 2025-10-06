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

return M
