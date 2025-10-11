
local r = reaper
local M = {}

function M.setFocus(ctx)
  local zoom_id = reaper.NamedCommandLookup("_SWS_TOGZOOMTTHIDE")
  local zoomed = reaper.GetToggleCommandState(zoom_id)
    if zoomed == 1 then
        r.Main_OnCommand(zoom_id, 1) --
        r.Main_OnCommand(40110, 1) --
    end
    if zoomed == 0 then
        r.Main_OnCommand(zoom_id, 1) --
    end
end

function M.moveOnFocused(ctx, val)
    local id

    if(ctx.item ~= nil) then
        if val > 0 then
            r.Main_OnCommand(40375, 1) -- Item: Move to next transient
        end
        if val < 0 then
            r.Main_OnCommand(40376, 1) -- Item: Move to previous transient
        end
    end

    if(ctx.on_env_sel) then
        if val > 0 then
            id = reaper.NamedCommandLookup("_SWS_BRMOVEEDITSELNEXTENV")
            r.Main_OnCommand(id, val) -- Envelope: 
        end
        if val < 0 then
            id = reaper.NamedCommandLookup("_SWS_BRMOVEEDITSELPREVENV")
            r.Main_OnCommand(id, val) -- Envelope: 
        end 
    end

    -- Fall back movement
    if val < 0 then
        r.ShowConsoleMsg(string.format("Move left!\n"))
        if val < -2 then
            id = r.NamedCommandLookup("_SWS_MOVECUR5MSLEFT")
        else
            id = r.NamedCommandLookup("_SWS_MOVECUR1MSLEFT")
        end
        r.Main_OnCommand(id, 1) --
    end
    if val > 0 then
        r.ShowConsoleMsg(string.format("Move right!\n"))
        if val > 1 then
            id = r.NamedCommandLookup("_SWS_MOVECUR5MSRIGHT")
        else
            id = r.NamedCommandLookup("_SWS_MOVECUR1MSRIGHT")
        end
        r.Main_OnCommand(id, 1) --
    end
end

return M