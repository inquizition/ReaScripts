-- item_actions.lua
local r = reaper
local M = {}

function M.item_nudge_volume(ctx, val)
  -- Last-resort action when nothing else matched
  ---r.ShowConsoleMsg("ContextRouter: no specific context matched.\n")
  if val < 0 then
    r.Main_OnCommand(41925, 1) -- Envelope: 
  end
  if val > 0 then
    r.Main_OnCommand(41924, 1) -- Envelope: 
  end
end

return M
