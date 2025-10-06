-- fallback_actions.lua
local r = reaper
local M = {}

function M.fallback(ctx)
  -- Last-resort action when nothing else matched
  r.ShowConsoleMsg("ContextRouter: no specific context matched.\n")
end

return M
